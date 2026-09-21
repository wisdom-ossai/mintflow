"""
Plaid integration service.
Handles link token creation, public token exchange, and transaction sync.
User banking credentials NEVER pass through this service.
Access tokens are Fernet-encrypted at rest. Sync cursors are persisted per account.
"""
from __future__ import annotations

import hashlib
import logging
import time
from datetime import datetime, timezone
from decimal import Decimal
from typing import Optional

import plaid
from jose import jwk, jwt
from jose.exceptions import JWTError
from plaid.api import plaid_api
from plaid.model.country_code import CountryCode
from plaid.model.item_public_token_exchange_request import ItemPublicTokenExchangeRequest
from plaid.model.item_remove_request import ItemRemoveRequest
from plaid.model.link_token_create_request import LinkTokenCreateRequest
from plaid.model.link_token_create_request_user import LinkTokenCreateRequestUser
from plaid.model.products import Products
from plaid.model.accounts_get_request import AccountsGetRequest
from plaid.model.transactions_sync_request import TransactionsSyncRequest
from plaid.model.webhook_verification_key_get_request import WebhookVerificationKeyGetRequest
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.crypto import decrypt_secret, encrypt_secret
from app.models.models import (
    Account,
    AccountType,
    Transaction,
    TransactionSource,
    TransactionType,
    User,
)
from app.schemas.schemas import TransactionCreate

logger = logging.getLogger(__name__)
settings = get_settings()

# Cache Plaid webhook JWKs by kid (keys rotate infrequently).
_webhook_jwk_cache: dict[str, dict] = {}


def _get_plaid_env():
    env_map = {
        "sandbox": plaid.Environment.Sandbox,
        "development": plaid.Environment.Development,
        "production": plaid.Environment.Production,
    }
    return env_map.get(settings.PLAID_ENV, plaid.Environment.Sandbox)


def get_plaid_client() -> plaid_api.PlaidApi:
    configuration = plaid.Configuration(
        host=_get_plaid_env(),
        api_key={
            "clientId": settings.PLAID_CLIENT_ID,
            "secret": settings.PLAID_SECRET,
        },
    )
    api_client = plaid.ApiClient(configuration)
    return plaid_api.PlaidApi(api_client)


def _access_token(account: Account) -> str:
    token = decrypt_secret(account.plaid_access_token)
    if not token:
        raise ValueError(f"Account {account.id} has no Plaid access token")
    return token


PLAID_ACCOUNT_TYPE_MAP = {
    "depository": AccountType.bank,
    "credit": AccountType.credit_card,
    "investment": AccountType.bank,
    "loan": AccountType.bank,
    "other": AccountType.bank,
}


async def create_link_token(user_id: str) -> dict:
    client = get_plaid_client()
    request = LinkTokenCreateRequest(
        products=[Products("transactions")],
        client_name="Mintflow",
        country_codes=[CountryCode("US")],
        language="en",
        user=LinkTokenCreateRequestUser(client_user_id=user_id),
        webhook=settings.PLAID_WEBHOOK_URL or None,
    )
    try:
        response = client.link_token_create(request)
        return {
            "link_token": response["link_token"],
            "expiration": response["expiration"].isoformat(),
        }
    except plaid.ApiException as e:
        logger.error("Plaid link token creation failed: %s", e)
        raise


async def exchange_public_token(
    db: AsyncSession,
    user_id: str,
    public_token: str,
    institution_name: Optional[str] = None,
) -> list[Account]:
    client = get_plaid_client()

    exchange_request = ItemPublicTokenExchangeRequest(public_token=public_token)
    exchange_response = client.item_public_token_exchange(exchange_request)
    access_token = exchange_response["access_token"]
    item_id = exchange_response["item_id"]
    encrypted_token = encrypt_secret(access_token)

    accounts_request = AccountsGetRequest(access_token=access_token)
    accounts_response = client.accounts_get(accounts_request)

    created_accounts: list[Account] = []

    for plaid_account in accounts_response["accounts"]:
        account_id = plaid_account["account_id"]

        result = await db.execute(
            select(Account).where(Account.plaid_account_id == account_id)
        )
        existing = result.scalar_one_or_none()
        if existing:
            existing.plaid_access_token = encrypted_token
            existing.plaid_item_id = item_id
            created_accounts.append(existing)
            continue

        plaid_type = str(plaid_account["type"]).lower()
        account_type = PLAID_ACCOUNT_TYPE_MAP.get(plaid_type, AccountType.bank)

        balances = plaid_account.get("balances") or {}
        balance = balances.get("current")
        credit_limit = balances.get("limit")

        account = Account(
            user_id=user_id,
            plaid_account_id=account_id,
            plaid_item_id=item_id,
            plaid_access_token=encrypted_token,
            name=plaid_account.get("name") or "Account",
            institution_name=institution_name,
            account_type=account_type,
            balance=Decimal(str(balance)) if balance is not None else None,
            credit_limit=Decimal(str(credit_limit)) if credit_limit is not None else None,
            outstanding_balance=(
                Decimal(str(balance))
                if account_type == AccountType.credit_card and balance is not None
                else None
            ),
            last_synced_at=datetime.now(timezone.utc),
        )
        db.add(account)
        await db.flush()
        created_accounts.append(account)

    return created_accounts


def _plaid_amount_to_decimal(raw_amount) -> Decimal:
    """Plaid amounts must never pass through float."""
    return Decimal(str(raw_amount)).copy_abs()


async def sync_transactions(
    db: AsyncSession,
    account: Account,
) -> dict:
    """
    Sync via /transactions/sync with a persisted cursor.
    Processes added, modified, and removed batches.
    """
    from app.services.transaction_service import create_transaction

    client = get_plaid_client()
    access_token = _access_token(account)

    user_result = await db.execute(select(User).where(User.id == account.user_id))
    user = user_result.scalar_one_or_none()
    allow_ai = bool(user and user.has_feature("ai_categorization"))

    added_count = 0
    modified_count = 0
    removed_count = 0
    cursor = account.plaid_sync_cursor or ""

    has_more = True
    while has_more:
        kwargs = {"access_token": access_token, "count": 500}
        if cursor:
            kwargs["cursor"] = cursor
        sync_request = TransactionsSyncRequest(**kwargs)
        try:
            response = client.transactions_sync(sync_request)
        except plaid.ApiException as e:
            logger.error("Plaid sync failed for account %s: %s", account.id, e)
            break

        for plaid_tx in response["added"]:
            plaid_tx_id = plaid_tx["transaction_id"]
            existing = await db.execute(
                select(Transaction).where(Transaction.plaid_transaction_id == plaid_tx_id)
            )
            if existing.scalar_one_or_none():
                continue

            raw_amount = plaid_tx["amount"]
            amount = _plaid_amount_to_decimal(raw_amount)
            # Plaid: positive = money out (expense), negative = money in (income)
            is_debit = Decimal(str(raw_amount)) > 0
            tx_type = TransactionType.expense if is_debit else TransactionType.income
            merchant = (
                plaid_tx.get("merchant_name")
                or plaid_tx.get("name")
                or "Unknown"
            )
            payload = TransactionCreate(
                amount=amount,
                transaction_type=tx_type,
                description=plaid_tx.get("name"),
                merchant_name=merchant,
                date=datetime.fromisoformat(str(plaid_tx["date"])),
                account_id=str(account.id),
            )
            await create_transaction(
                db=db,
                user_id=str(account.user_id),
                payload=payload,
                source=TransactionSource.plaid,
                allow_ai=allow_ai,
                plaid_transaction_id=plaid_tx_id,
            )
            added_count += 1

        for plaid_tx in response["modified"]:
            plaid_tx_id = plaid_tx["transaction_id"]
            result = await db.execute(
                select(Transaction).where(Transaction.plaid_transaction_id == plaid_tx_id)
            )
            tx = result.scalar_one_or_none()
            if not tx:
                continue
            raw_amount = plaid_tx["amount"]
            amount = _plaid_amount_to_decimal(raw_amount)
            is_debit = Decimal(str(raw_amount)) > 0
            tx.amount = amount
            tx.transaction_type = (
                TransactionType.expense if is_debit else TransactionType.income
            )
            tx.description = plaid_tx.get("name")
            tx.merchant_name = (
                plaid_tx.get("merchant_name") or plaid_tx.get("name") or tx.merchant_name
            )
            tx.date = datetime.fromisoformat(str(plaid_tx["date"]))
            modified_count += 1

        for removed in response["removed"]:
            result = await db.execute(
                select(Transaction).where(
                    Transaction.plaid_transaction_id == removed["transaction_id"]
                )
            )
            tx = result.scalar_one_or_none()
            if tx:
                await db.delete(tx)
                removed_count += 1

        has_more = bool(response["has_more"])
        cursor = response["next_cursor"]

    account.plaid_sync_cursor = cursor
    account.last_synced_at = datetime.now(timezone.utc)
    # Re-encrypt legacy plaintext tokens on successful sync.
    if account.plaid_access_token and not str(account.plaid_access_token).startswith("enc:v1:"):
        account.plaid_access_token = encrypt_secret(access_token)

    # Refresh recurring merchant detection when new txs arrive.
    if added_count or modified_count:
        try:
            from app.services.recurring_service import detect_and_upsert_recurring

            await detect_and_upsert_recurring(db, str(account.user_id))
        except Exception as e:
            logger.warning("Recurring detect after sync failed: %s", e)

    return {
        "added": added_count,
        "modified": modified_count,
        "removed": removed_count,
    }


async def remove_plaid_item(access_token_ciphertext: str) -> None:
    """Invalidate a Plaid Item (revokes access token). Best-effort."""
    try:
        token = decrypt_secret(access_token_ciphertext)
        if not token:
            return
        client = get_plaid_client()
        client.item_remove(ItemRemoveRequest(access_token=token))
    except Exception as e:
        logger.warning("Plaid item_remove failed: %s", e)


async def revoke_user_plaid_items(db: AsyncSession, user_id: str) -> None:
    result = await db.execute(
        select(Account).where(
            Account.user_id == user_id,
            Account.plaid_access_token.is_not(None),
        )
    )
    accounts = result.scalars().all()
    seen_items: set[str] = set()
    for account in accounts:
        item_key = account.plaid_item_id or account.id
        if item_key in seen_items:
            continue
        seen_items.add(item_key)
        await remove_plaid_item(account.plaid_access_token)


def _get_webhook_jwk(kid: str) -> dict:
    if kid in _webhook_jwk_cache:
        return _webhook_jwk_cache[kid]
    client = get_plaid_client()
    response = client.webhook_verification_key_get(
        WebhookVerificationKeyGetRequest(key_id=kid)
    )
    key = response["key"]
    # plaid SDK may return a model — normalize to dict
    if hasattr(key, "to_dict"):
        key = key.to_dict()
    _webhook_jwk_cache[kid] = key
    return key


def verify_plaid_webhook(plaid_verification: str | None, body: bytes) -> bool:
    """
    Verify Plaid-Verification JWT per Plaid docs:
    ES256 JWK, iat within 5 minutes, body SHA-256 matches claim.
    """
    if not plaid_verification:
        return False
    try:
        header = jwt.get_unverified_header(plaid_verification)
        if header.get("alg") != "ES256":
            return False
        kid = header.get("kid")
        if not kid:
            return False
        key_dict = _get_webhook_jwk(kid)
        public_key = jwk.construct(key_dict, algorithm="ES256")
        claims = jwt.decode(
            plaid_verification,
            public_key,
            algorithms=["ES256"],
            options={"verify_aud": False},
        )
        iat = claims.get("iat")
        if iat is None or abs(time.time() - float(iat)) > 300:
            return False
        expected_hash = claims.get("request_body_sha256")
        actual_hash = hashlib.sha256(body).hexdigest()
        return bool(expected_hash) and actual_hash == expected_hash
    except (JWTError, Exception) as e:
        logger.warning("Plaid webhook verification failed: %s", e)
        return False
