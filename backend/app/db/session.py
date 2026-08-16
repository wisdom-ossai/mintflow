from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine, async_sessionmaker
from supabase import create_client, Client
from app.core.config import get_settings

settings = get_settings()

# ─── Async SQLAlchemy engine ───────────────────────────────────────────────
engine = create_async_engine(
    settings.DATABASE_URL,
    echo=settings.is_development,
    pool_size=10,
    max_overflow=20,
    pool_pre_ping=True,
)

AsyncSessionLocal = async_sessionmaker(
    engine,
    class_=AsyncSession,
    expire_on_commit=False,
    autocommit=False,
    autoflush=False,
)


async def get_db() -> AsyncSession:
    async with AsyncSessionLocal() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()


# ─── Supabase admin client (service role — server only) ───────────────────
_supabase_admin: Client | None = None


def get_supabase() -> Client:
    return create_client(
        settings.SUPABASE_URL,
        settings.SUPABASE_SERVICE_ROLE_KEY,
    )


def supabase_admin() -> Client:
    """Lazy admin client so unit imports do not require a valid key."""
    global _supabase_admin
    if _supabase_admin is None:
        _supabase_admin = get_supabase()
    return _supabase_admin
