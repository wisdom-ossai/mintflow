"""
Seed script — inserts system-level default categories.
Run once during initial setup: python scripts/seed_categories.py
"""
import asyncio
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.db.session import AsyncSessionLocal
from app.models.models import Category
from sqlalchemy import select

DEFAULT_CATEGORIES = [
    {"name": "Food & Dining",     "icon": "fork_knife",    "color": "#E05A40"},
    {"name": "Groceries",         "icon": "shopping_cart", "color": "#2EAD6A"},
    {"name": "Transport",         "icon": "car",           "color": "#4A6CF7"},
    {"name": "Housing",           "icon": "home",          "color": "#7B5CF0"},
    {"name": "Health",            "icon": "heart",         "color": "#E91E63"},
    {"name": "Entertainment",     "icon": "play_circle",   "color": "#FF9800"},
    {"name": "Shopping",          "icon": "bag",           "color": "#EDB93A"},
    {"name": "Education",         "icon": "book",          "color": "#00BCD4"},
    {"name": "Utilities",         "icon": "bolt",          "color": "#607D8B"},
    {"name": "Subscriptions",     "icon": "refresh",       "color": "#9C27B0"},
    {"name": "Travel",            "icon": "plane",         "color": "#03A9F4"},
    {"name": "Personal Care",     "icon": "sparkles",      "color": "#F06292"},
    {"name": "Savings",           "icon": "piggy_bank",    "color": "#1D9256"},
    {"name": "Income",            "icon": "trending_up",   "color": "#2EAD6A"},
    {"name": "Other",             "icon": "dots",          "color": "#888780"},
]


async def seed():
    async with AsyncSessionLocal() as db:
        for cat_data in DEFAULT_CATEGORIES:
            result = await db.execute(
                select(Category).where(
                    Category.name == cat_data["name"],
                    Category.user_id.is_(None),
                )
            )
            if not result.scalar_one_or_none():
                db.add(Category(
                    name=cat_data["name"],
                    icon=cat_data["icon"],
                    color=cat_data["color"],
                    is_custom=False,
                ))
                print(f"  ✓ Added category: {cat_data['name']}")
            else:
                print(f"  – Skipped (exists): {cat_data['name']}")

        await db.commit()
        print("\nCategories seeded successfully.")


if __name__ == "__main__":
    asyncio.run(seed())