-- BRA-887 — non-superuser application role so Postgres RLS actually applies.
--
-- The row-level-security policies on call_records/budgets (atlas-gateway
-- migration e4b8c2d6f1a9) only take effect for a NON-superuser role: Postgres
-- superusers bypass RLS entirely, and the table owner bypasses it unless the
-- table is FORCE'd (it is) — but the gateway must still connect as a plain role.
--
-- `atlas` (POSTGRES_USER) stays the superuser/owner used to run migrations and
-- the seeder (both must bypass RLS — to run DDL and to seed cross-tenant rows).
-- The gateway *runtime* connects as `atlas_app` (see ATLAS_DB_URL), so its
-- reads of call_records are scoped by the per-connection GUC `atlas.api_key_id`.
--
-- Runs once, at fresh DB init (docker-entrypoint-initdb.d), BEFORE Alembic has
-- created any table — so privileges are granted via ALTER DEFAULT PRIVILEGES:
-- every table/sequence `atlas` creates afterward (i.e. via the migrations)
-- auto-grants DML to `atlas_app`. To (re)create the role on an existing data
-- volume, recreate it: `docker compose -f local/compose.dev.yaml down -v`.

CREATE ROLE atlas_app LOGIN PASSWORD 'atlas_app' NOSUPERUSER;  -- local-only dev credential; not a secret

GRANT USAGE ON SCHEMA public TO atlas_app;

ALTER DEFAULT PRIVILEGES FOR ROLE atlas IN SCHEMA public
    GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO atlas_app;

ALTER DEFAULT PRIVILEGES FOR ROLE atlas IN SCHEMA public
    GRANT USAGE, SELECT ON SEQUENCES TO atlas_app;
