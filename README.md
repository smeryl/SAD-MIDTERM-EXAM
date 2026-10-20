# Scholarship Monitoring and Academic Compliance System
SAD Midterm Lab Exam, Section A. Stack: HTML/CSS/JS + Supabase (Auth, Postgres, RLS, SQL functions).

## Setup
1. Create a Supabase project. In Authentication > Users, add `staff`, `scholar1`, `scholar2` (synthetic emails).
2. In the SQL Editor run, in order: `sql/01_schema.sql`, `02_rls.sql`, `03_functions.sql`, `04_seed.sql` (replace the three `<...-UUID>` values first).
3. Edit `config.js`: set `SUPABASE_URL` and `SUPABASE_ANON_KEY` (anon key only; never the service_role key).
4. Run locally: open the folder in VS Code and use Live Server, or `python -m http.server 8000`, then visit http://localhost:8000.
5. Optional hosting: GitHub Pages / Netlify.

## Design
- Access control is enforced by Row Level Security. Scholars read only their own rows; staff have no direct UPDATE, only the functions `verify_submission`, `evaluate_submission`, `decide_renewal`.
- Thresholds are read from the `programs` table. Deadline is 2026-10-30 17:00 Asia/Manila, inclusive.
- Verification status, compliance result, and renewal decision are separate columns.
- Assumption: a resubmission keeps the original timestamp.

## Env names
`SUPABASE_URL`, `SUPABASE_ANON_KEY` (in `config.js`).

## Known defects
List honestly here.

## Test accounts
Credentials were supplied privately to the instructor.
