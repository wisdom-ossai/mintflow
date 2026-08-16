"""
Flowra AI Service — Claude API integration.

Three functions:
  1. categorize_transaction()  — merchant → category + is_need
  2. generate_monthly_insight() — transactions → narrative insights
  3. generate_notification_copy() — context → personalized push copy

Cost optimizations:
  - Merchant cache checked before every Claude call
  - Insights generated once per period and cached in DB
  - Notifications batched — max one call per user per day
  - User identifiers NEVER sent to Claude
"""
import json
import logging
from decimal import Decimal
from typing import Optional

import anthropic

from app.core.config import get_settings
from app.schemas.schemas import InsightContent, InsightItem

logger = logging.getLogger(__name__)
settings = get_settings()

_client: Optional[anthropic.Anthropic] = None


def get_anthropic_client() -> anthropic.Anthropic:
    global _client
    if _client is None:
        _client = anthropic.Anthropic(api_key=settings.ANTHROPIC_API_KEY)
    return _client


# ─── System prompts ────────────────────────────────────────────────────────

CATEGORIZATION_SYSTEM = """You are a financial transaction classifier for a personal finance app.

Your job: given a merchant name and transaction amount, return a JSON object with:
- "category": one of [Food & Dining, Groceries, Transport, Housing, Health, Entertainment, Shopping, Education, Utilities, Subscriptions, Travel, Personal Care, Savings, Other]
- "is_need": true if this is a necessity (rent, groceries, utilities, transport to work, medicine), false if it's discretionary (restaurants, entertainment, shopping, subscriptions)
- "confidence": 0.0 to 1.0

Rules:
- Groceries (Whole Foods, Kroger, Walmart grocery) = need
- Restaurants, bars, coffee shops = want
- Streaming services (Netflix, Spotify) = want
- Gym memberships = want (unless user has medical need — default want)
- Rent, mortgage = need
- Uber/Lyft for commuting = need; for going out = want (default need)
- Health insurance, prescriptions, doctor = need
- Clothing at Zara, H&M, etc = want
- Amazon depends: default want unless clearly household supplies

Respond ONLY with valid JSON. No explanation, no markdown.

Example:
{"category": "Food & Dining", "is_need": false, "confidence": 0.95}"""


INSIGHT_SYSTEM = """You are Flowra, a warm and honest personal finance coach. Your tone is:
- Encouraging, not preachy
- Specific, not vague
- Honest about problems, but never harsh
- Celebratory of wins, no matter how small

You receive a user's monthly spending summary (anonymized — no names or account numbers).
Return a JSON object with this exact structure:
{
  "summary": "One sentence overview of the month",
  "insights": [
    {
      "type": "positive|warning|info",
      "title": "Short title (max 8 words)",
      "body": "2-3 sentence explanation with specific numbers",
      "action_label": "Optional CTA text",
      "action_type": "Optional: set_budget|review_subscriptions|reduce_category|null"
    }
  ],
  "recommendations": [
    {
      "type": "recommendation",
      "title": "Short action title",
      "body": "Specific, actionable recommendation with dollar amounts",
      "action_label": "Optional CTA",
      "action_type": "Optional action type"
    }
  ]
}

Generate 3-5 insights and 2-3 recommendations.
Use ONLY data provided. Never fabricate numbers.
Respond ONLY with valid JSON."""


NOTIFICATION_SYSTEM = """You write short, warm push notification copy for a personal finance app.
Max 110 characters including spaces.
Tone: friendly, direct, never alarming unless genuinely urgent.
No emojis. Just clear, human text.
Respond ONLY with the notification text — no quotes, no JSON, no explanation."""


# ─── Categorization ────────────────────────────────────────────────────────

async def categorize_transaction(
    merchant_name: str,
    amount: Decimal,
) -> dict:
    """
    Ask Claude to categorize a transaction.
    Returns {"category": str, "is_need": bool, "confidence": float}

    Caller is responsible for checking/updating the merchant cache first.
    """
    client = get_anthropic_client()

    prompt = f'Merchant: "{merchant_name}"\nAmount: ${amount}'

    try:
        response = client.messages.create(
            model=settings.CLAUDE_MODEL,
            max_tokens=100,
            system=CATEGORIZATION_SYSTEM,
            messages=[{"role": "user", "content": prompt}],
        )
        raw = response.content[0].text.strip()
        result = json.loads(raw)
        return {
            "category": result.get("category", "Other"),
            "is_need": bool(result.get("is_need", False)),
            "confidence": float(result.get("confidence", 0.8)),
        }
    except (json.JSONDecodeError, KeyError, anthropic.APIError) as e:
        logger.error(f"Categorization failed for merchant '{merchant_name}': {e}")
        return {"category": "Other", "is_need": False, "confidence": 0.0}


# ─── Monthly Insights ──────────────────────────────────────────────────────

async def generate_monthly_insight(
    period_key: str,
    total_income: Decimal,
    total_spent: Decimal,
    total_saved: Decimal,
    budget_amount: Optional[Decimal],
    needs_total: Decimal,
    wants_total: Decimal,
    spending_by_category: list[dict],
    prev_month_spent: Optional[Decimal] = None,
    prev_month_saved: Optional[Decimal] = None,
) -> InsightContent:
    """
    Generate AI narrative insights for a user's month.
    IMPORTANT: No user identifiers in the prompt.
    """
    client = get_anthropic_client()

    # Build anonymized summary for Claude
    category_lines = "\n".join([
        f"  - {c['name']}: ${c['total']:.2f} ({c['pct']:.0f}%) — {'need' if c.get('is_need') else 'want'}"
        for c in sorted(spending_by_category, key=lambda x: x["total"], reverse=True)[:10]
    ])

    prev_context = ""
    if prev_month_spent is not None:
        delta = float(total_spent - prev_month_spent)
        direction = "more" if delta > 0 else "less"
        prev_context = f"\nCompared to last month: spent ${abs(delta):.2f} {direction}"
        if prev_month_saved is not None:
            saved_delta = float(total_saved - prev_month_saved)
            prev_context += f", saved ${abs(saved_delta):.2f} {'more' if saved_delta > 0 else 'less'}"

    budget_context = ""
    if budget_amount:
        pct = float(total_spent / budget_amount * 100)
        remaining = float(budget_amount - total_spent)
        budget_context = f"\nMonthly budget: ${budget_amount:.2f}\nBudget used: {pct:.0f}% (${remaining:.2f} remaining)"

    prompt = f"""Month: {period_key}

Income: ${total_income:.2f}
Total spent: ${total_spent:.2f}
Total saved: ${total_saved:.2f}
Savings rate: {float(total_saved / total_income * 100) if total_income > 0 else 0:.1f}%
Needs: ${needs_total:.2f} ({float(needs_total / total_spent * 100) if total_spent > 0 else 0:.0f}%)
Wants: ${wants_total:.2f} ({float(wants_total / total_spent * 100) if total_spent > 0 else 0:.0f}%){budget_context}{prev_context}

Spending by category:
{category_lines}"""

    try:
        response = client.messages.create(
            model=settings.CLAUDE_MODEL,
            max_tokens=1500,
            system=INSIGHT_SYSTEM,
            messages=[{"role": "user", "content": prompt}],
        )
        raw = response.content[0].text.strip()
        data = json.loads(raw)

        return InsightContent(
            summary=data["summary"],
            insights=[InsightItem(**i) for i in data.get("insights", [])],
            recommendations=[InsightItem(**r) for r in data.get("recommendations", [])],
            generated_at=period_key,
        )
    except (json.JSONDecodeError, KeyError, anthropic.APIError) as e:
        logger.error(f"Insight generation failed for period {period_key}: {e}")
        return InsightContent(
            summary="Your spending summary is being prepared.",
            insights=[],
            recommendations=[],
            generated_at=period_key,
        )


# ─── Notification Copy ─────────────────────────────────────────────────────

async def generate_notification_copy(
    notification_type: str,
    total_spent: Decimal,
    budget_amount: Optional[Decimal],
    days_remaining: int,
    top_category: Optional[str] = None,
    top_category_amount: Optional[Decimal] = None,
    prev_week_spent: Optional[Decimal] = None,
    this_week_spent: Optional[Decimal] = None,
) -> str:
    """
    Generate personalized push notification text.
    Returns a string ≤ 110 characters.
    Falls back to template if Claude fails.
    """
    client = get_anthropic_client()

    remaining = float(budget_amount - total_spent) if budget_amount else None
    pct_used = float(total_spent / budget_amount * 100) if budget_amount else None

    context_parts = [f"Notification type: {notification_type}"]
    context_parts.append(f"Total spent this month: ${total_spent:.2f}")
    if budget_amount:
        context_parts.append(f"Monthly budget: ${budget_amount:.2f} ({pct_used:.0f}% used, ${remaining:.2f} left)")
    context_parts.append(f"Days remaining in month: {days_remaining}")
    if top_category and top_category_amount:
        context_parts.append(f"Top spending category: {top_category} (${top_category_amount:.2f})")
    if prev_week_spent and this_week_spent:
        delta = float(this_week_spent - prev_week_spent)
        direction = "more" if delta > 0 else "less"
        context_parts.append(f"This week vs last week: ${abs(delta):.2f} {direction}")

    prompt = "\n".join(context_parts)

    try:
        response = client.messages.create(
            model=settings.CLAUDE_MODEL,
            max_tokens=60,
            system=NOTIFICATION_SYSTEM,
            messages=[{"role": "user", "content": prompt}],
        )
        copy = response.content[0].text.strip().strip('"')
        return copy[:110]  # hard cap
    except anthropic.APIError as e:
        logger.error(f"Notification copy generation failed: {e}")
        return _notification_fallback(notification_type, total_spent, budget_amount, days_remaining)


def _notification_fallback(
    notification_type: str,
    total_spent: Decimal,
    budget_amount: Optional[Decimal],
    days_remaining: int,
) -> str:
    """Template fallback when Claude API is unavailable."""
    templates = {
        "daily_summary": f"Today's summary ready. You've spent ${total_spent:.2f} this month.",
        "budget_80": f"Heads up — you've used 80% of your budget with {days_remaining} days left.",
        "budget_exceeded": "You've gone over your monthly budget. Time to review your spending.",
        "weekly_digest": "Your weekly spending digest is ready to review.",
        "monthly_report": "Your monthly report is ready. See how November went.",
        "ai_nudge": "Flowra spotted something in your spending. Take a look.",
    }
    return templates.get(notification_type, "Check your Flowra summary.")