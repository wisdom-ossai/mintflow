-- ═══════════════════════════════════════════════════════════════════════════
-- Flowra — Supabase Row Level Security (RLS) Policies
-- Run this in the Supabase SQL editor after running Alembic migrations.
-- ═══════════════════════════════════════════════════════════════════════════

-- Enable RLS on all user-facing tables
ALTER TABLE users                  ENABLE ROW LEVEL SECURITY;
ALTER TABLE accounts               ENABLE ROW LEVEL SECURITY;
ALTER TABLE transactions           ENABLE ROW LEVEL SECURITY;
ALTER TABLE categories             ENABLE ROW LEVEL SECURITY;
ALTER TABLE budgets                ENABLE ROW LEVEL SECURITY;
ALTER TABLE insights               ENABLE ROW LEVEL SECURITY;
ALTER TABLE notification_preferences ENABLE ROW LEVEL SECURITY;

-- merchant_cache is global (no RLS needed — no user data)

-- ─── Users ───────────────────────────────────────────────────────────────
-- Users can only read and update their own row
CREATE POLICY "users_select_own"
  ON users FOR SELECT
  USING (auth.uid()::text = id);

CREATE POLICY "users_update_own"
  ON users FOR UPDATE
  USING (auth.uid()::text = id);

CREATE POLICY "users_delete_own"
  ON users FOR DELETE
  USING (auth.uid()::text = id);

-- ─── Accounts ────────────────────────────────────────────────────────────
CREATE POLICY "accounts_select_own"
  ON accounts FOR SELECT
  USING (auth.uid()::text = user_id);

CREATE POLICY "accounts_insert_own"
  ON accounts FOR INSERT
  WITH CHECK (auth.uid()::text = user_id);

CREATE POLICY "accounts_update_own"
  ON accounts FOR UPDATE
  USING (auth.uid()::text = user_id);

CREATE POLICY "accounts_delete_own"
  ON accounts FOR DELETE
  USING (auth.uid()::text = user_id);

-- ─── Transactions ─────────────────────────────────────────────────────────
CREATE POLICY "transactions_select_own"
  ON transactions FOR SELECT
  USING (auth.uid()::text = user_id);

CREATE POLICY "transactions_insert_own"
  ON transactions FOR INSERT
  WITH CHECK (auth.uid()::text = user_id);

CREATE POLICY "transactions_update_own"
  ON transactions FOR UPDATE
  USING (auth.uid()::text = user_id);

CREATE POLICY "transactions_delete_own"
  ON transactions FOR DELETE
  USING (auth.uid()::text = user_id);

-- ─── Categories ───────────────────────────────────────────────────────────
-- Users can see system categories (user_id IS NULL) and their own custom ones
CREATE POLICY "categories_select_own_or_system"
  ON categories FOR SELECT
  USING (user_id IS NULL OR auth.uid()::text = user_id);

CREATE POLICY "categories_insert_own"
  ON categories FOR INSERT
  WITH CHECK (auth.uid()::text = user_id);

CREATE POLICY "categories_update_own"
  ON categories FOR UPDATE
  USING (auth.uid()::text = user_id);

CREATE POLICY "categories_delete_own"
  ON categories FOR DELETE
  USING (auth.uid()::text = user_id AND is_custom = TRUE);

-- ─── Budgets ──────────────────────────────────────────────────────────────
CREATE POLICY "budgets_select_own"
  ON budgets FOR SELECT
  USING (auth.uid()::text = user_id);

CREATE POLICY "budgets_insert_own"
  ON budgets FOR INSERT
  WITH CHECK (auth.uid()::text = user_id);

CREATE POLICY "budgets_update_own"
  ON budgets FOR UPDATE
  USING (auth.uid()::text = user_id);

CREATE POLICY "budgets_delete_own"
  ON budgets FOR DELETE
  USING (auth.uid()::text = user_id);

-- ─── Insights ─────────────────────────────────────────────────────────────
CREATE POLICY "insights_select_own"
  ON insights FOR SELECT
  USING (auth.uid()::text = user_id);

CREATE POLICY "insights_insert_own"
  ON insights FOR INSERT
  WITH CHECK (auth.uid()::text = user_id);

CREATE POLICY "insights_update_own"
  ON insights FOR UPDATE
  USING (auth.uid()::text = user_id);

-- ─── Notification Preferences ─────────────────────────────────────────────
CREATE POLICY "notif_prefs_select_own"
  ON notification_preferences FOR SELECT
  USING (auth.uid()::text = user_id);

CREATE POLICY "notif_prefs_insert_own"
  ON notification_preferences FOR INSERT
  WITH CHECK (auth.uid()::text = user_id);

CREATE POLICY "notif_prefs_update_own"
  ON notification_preferences FOR UPDATE
  USING (auth.uid()::text = user_id);

CREATE POLICY "notif_prefs_delete_own"
  ON notification_preferences FOR DELETE
  USING (auth.uid()::text = user_id);

-- ─── Performance indexes (run after RLS setup) ────────────────────────────
CREATE INDEX IF NOT EXISTS idx_transactions_user_date
  ON transactions (user_id, date DESC);

CREATE INDEX IF NOT EXISTS idx_transactions_merchant
  ON transactions (merchant_name);

CREATE INDEX IF NOT EXISTS idx_merchant_cache_name
  ON merchant_cache (merchant_name);

CREATE INDEX IF NOT EXISTS idx_insights_user_period
  ON insights (user_id, period_key);

CREATE INDEX IF NOT EXISTS idx_accounts_plaid_id
  ON accounts (plaid_account_id)
  WHERE plaid_account_id IS NOT NULL;