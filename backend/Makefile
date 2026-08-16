.PHONY: dev test migrate seed lint docker-build

# ─── Virtual environment ───────────────────────────────────────────────────
VENV := .venv/bin

# ─── Local development ─────────────────────────────────────────────────────
dev:
	$(VENV)/uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

# ─── Docker ────────────────────────────────────────────────────────────────
docker-up:
	docker compose up --build

docker-down:
	docker compose down

docker-build:
	docker build -t flowra-api:latest .

# ─── Database ──────────────────────────────────────────────────────────────
migrate:
	$(VENV)/alembic upgrade head

migrate-new:
	$(VENV)/alembic revision --autogenerate -m "$(name)"

migrate-down:
	$(VENV)/alembic downgrade -1

seed:
	$(VENV)/python scripts/seed_category.py

rls:
	@echo "Run scripts/superbase_rls.sql in the Supabase SQL editor"

# ─── Tests ─────────────────────────────────────────────────────────────────
test:
	$(VENV)/pytest tests/ -v

test-unit:
	$(VENV)/pytest tests/unit/ -v

test-cov:
	$(VENV)/pytest tests/ --cov=app --cov-report=term-missing --cov-report=html

# ─── Code quality ──────────────────────────────────────────────────────────
lint:
	$(VENV)/ruff check app/ tests/
	$(VENV)/mypy app/ --ignore-missing-imports

format:
	$(VENV)/ruff format app/ tests/

# ─── Setup ─────────────────────────────────────────────────────────────────
install:
	$(VENV)/pip install -r requirements.txt

setup: install migrate seed
	@echo "\n✓ Flowra backend ready. Run 'make dev' to start."