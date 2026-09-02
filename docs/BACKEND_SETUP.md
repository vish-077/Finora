# Backend setup (required for cross-device sync)

Finora is local-first: it works offline, and a background sync engine mirrors
your data to Supabase so the same account shows the same figures on every
device. **If the server has no tables, data never leaves the device** — which is
why an account looks empty on a second device or after switching accounts.

## Current status of this project

Checked against `https://obuoiftuwcaniqljkcva.supabase.co`:

| Check | Result |
| --- | --- |
| Host resolves | ✅ yes (`104.18.38.10`) |
| Auth API reachable | ✅ yes (`/auth/v1/health` responds) |
| `expenses` table | ❌ **missing** (`PGRST205`) |
| `categories` table | ❌ **missing** |
| `budgets` table | ❌ **missing** |
| `accounts` table | ❌ **missing** |

**The project is alive but has no schema.** Step 2 is the blocker for
cross-device sync — until the migrations run, every push fails with
"Could not find the table", so nothing can ever reach the server and a second
device has nothing to pull.

Re-run these checks any time:

```bash
curl -s -o /dev/null -w "%{http_code}\n" "$SUPABASE_URL/rest/v1/expenses?select=id&limit=1" -H "apikey: $SUPABASE_ANON_KEY"
```

`404` = table missing (run the migrations). `200` or `401` = table exists.

---

## 1. Project credentials

Already configured in `.env` for this project. For a new one: **Project
Settings → API** → copy **Project URL** → `SUPABASE_URL` and the
**anon / public key** → `SUPABASE_ANON_KEY`.

The anon key is safe to ship — row-level security is what protects the data.
Never put the **service_role** key in the app. Fully restart after editing
`.env`; it is read once at startup, so hot reload is not enough.

## 2. Apply the database schema — REQUIRED, currently missing

The migrations in `supabase/migrations/` create the tables, row-level security
policies and sync triggers the app expects.

With the Supabase CLI:

```bash
supabase link --project-ref <your-ref>
supabase db push
```

Or paste each file, in numeric order, into the dashboard SQL editor:

1. `0001_expense_module.sql`
2. `0002_accounts_module.sql`
3. `0003_sync_layer.sql`

Sync will fail with "relation does not exist" until this is done.

## 3. Email (Gmail) auth — Supabase only, no Google Cloud

Auth uses Supabase email/password with a strict `@gmail.com` policy. There is
no Google OAuth and no Google Cloud project involved.

**Registration sends a confirmation email, and the account cannot be signed
into until that link is opened.** This is the single most common cause of
"invalid email or password" on a correct password: the account exists but is
unconfirmed, and Supabase deliberately returns the same generic error for both
cases so addresses cannot be enumerated.

Supabase's built-in SMTP sends only **2-3 emails per hour**. While testing you
have two options:

- **Keep confirmation on** (production-like): register, open the link in the
  inbox, then sign in. Watch the hourly limit.
- **Turn confirmation off** (fastest for testing): **Authentication → Sign In /
  Providers → Email** → disable **Confirm email**. New accounts are then usable
  immediately. Existing unconfirmed users can be confirmed by hand in
  **Authentication → Users**.

For real volume, attach your own SMTP provider under **Project Settings → Auth →
SMTP Settings** to lift the limit.

Guest / test mode is unaffected — it is deliberately local-only and never syncs.

---

## 4. Verify it works

1. Sign in on device A, add an expense.
2. Confirm the sync chip in the top bar settles (not "pending").
3. Check **Table Editor → expenses** in the dashboard — the row should be
   there with your `user_id`.
4. Sign in as the same account on device B. The expense should appear after the
   first sync.

If step 3 shows nothing, the data is still local-only: check the app logs for
push failures, confirm the migrations ran, and confirm RLS policies exist.

## Recovering data that appears "lost"

Rows written while the backend was unreachable live in the local outbox
(`finora_sync_queue`) and the local mirror boxes. As of the sign-out retention fix,
**sign-out no longer deletes either** — they upload the next time that account
signs in on that device.

The caveat: data lost *before* that fix, on a build that cleared those boxes on
sign-out, is not recoverable. It was never on the server and the local copy was
erased. Only data still on the device can be rescued, so point that device at a
working backend and sign in with the same account before reinstalling or
clearing app storage.
