"""Goals Seed cap constant matches product (1 goal on free)."""
from app.api.v1.endpoints.goals import _SEED_GOAL_CAP


def test_seed_goal_cap_is_one():
    assert _SEED_GOAL_CAP == 1
