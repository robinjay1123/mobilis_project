# Supabase Auto-Migration Setup

This repository is configured to auto-apply Supabase migrations when files under `supabase/migrations/` are pushed to `main`.

Current baseline migration file:

- `supabase/migrations/20260418120000_initial_public_schema.sql`

## 1) Configure GitHub Secrets

In your GitHub repository settings, add:

- `SUPABASE_ACCESS_TOKEN`
- `SUPABASE_PROJECT_REF`
- `SUPABASE_DB_PASSWORD`

## 2) Set your project ref

Update `supabase/config.toml`:

- Replace `project_id = "your-project-ref"` with your real project ref.

## 3) Create a migration from your current SQL file

PowerShell:

```powershell
./scripts/new_supabase_migration.ps1 -Name "initial_public_schema"
```

This copies `supabase/migrations/20260418120000_initial_public_schema.sql` into `supabase/migrations/<timestamp>_<name>.sql`.

## 4) Push to main

Commit and push. The workflow at `.github/workflows/supabase-migrate.yml` will run:

1. `supabase link`
2. `supabase db push --linked`

## Notes

- This is migration-based automation, not "run SQL on every save".
- Keep all new DB changes in new files under `supabase/migrations/`.
- If you edit files outside `supabase/migrations/`, CI will not apply those DB changes.
