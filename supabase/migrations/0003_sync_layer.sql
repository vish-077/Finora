-- ============================================================================
-- FINORA — Multi-Device Sync Layer
-- 1. budgets table (was missing — budgets were device-local only)
-- 2. deleted_at tombstones so deletes propagate between devices
-- 3. (user_id, updated_at) indexes for delta pulls
-- 4. realtime publication so a change on device A pushes to device B
-- Run in Supabase Dashboard → SQL Editor, or via the Supabase CLI.
-- ============================================================================

-- ── BUDGETS ─────────────────────────────────────────────────────────────────
create table if not exists public.budgets (
    id          uuid primary key default uuid_generate_v4(),
    user_id     uuid not null references auth.users (id) on delete cascade,
    category_id uuid not null references public.categories (id) on delete cascade,
    month       int  not null check (month between 1 and 12),
    year        int  not null check (year between 2000 and 2100),
    amount      numeric(14, 2) not null check (amount >= 0),
    created_at  timestamptz not null default now(),
    updated_at  timestamptz not null default now(),
    deleted_at  timestamptz
);

-- One live budget per category per month.
create unique index if not exists budgets_unique_period
    on public.budgets (user_id, category_id, month, year)
    where deleted_at is null;

create index if not exists budgets_user_id_idx on public.budgets (user_id);

drop trigger if exists budgets_set_updated_at on public.budgets;
create trigger budgets_set_updated_at
    before update on public.budgets
    for each row execute function public.set_updated_at();

alter table public.budgets enable row level security;

drop policy if exists "budgets_select_own" on public.budgets;
create policy "budgets_select_own" on public.budgets
    for select using (auth.uid() = user_id);

drop policy if exists "budgets_insert_own" on public.budgets;
create policy "budgets_insert_own" on public.budgets
    for insert with check (auth.uid() = user_id);

drop policy if exists "budgets_update_own" on public.budgets;
create policy "budgets_update_own" on public.budgets
    for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "budgets_delete_own" on public.budgets;
create policy "budgets_delete_own" on public.budgets
    for delete using (auth.uid() = user_id);

-- ── TOMBSTONES ──────────────────────────────────────────────────────────────
-- A hard DELETE is invisible to a delta pull: the other device simply never
-- sees the row again and keeps its stale copy forever. Soft-delete instead.
alter table public.categories add column if not exists deleted_at timestamptz;
alter table public.expenses   add column if not exists deleted_at timestamptz;
alter table public.accounts   add column if not exists deleted_at timestamptz;

-- ── DELTA-PULL INDEXES ──────────────────────────────────────────────────────
-- Every sync is `where user_id = ? and updated_at > cursor order by updated_at`.
create index if not exists categories_sync_idx on public.categories (user_id, updated_at);
create index if not exists expenses_sync_idx   on public.expenses   (user_id, updated_at);
create index if not exists accounts_sync_idx   on public.accounts   (user_id, updated_at);
create index if not exists budgets_sync_idx    on public.budgets    (user_id, updated_at);

-- ── REALTIME ────────────────────────────────────────────────────────────────
-- Lets device B react the moment device A writes, instead of waiting for a
-- foreground/refresh trigger. RLS still applies to realtime payloads.
do $$
begin
    if not exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
        create publication supabase_realtime;
    end if;
end $$;

-- `add table` errors if the table is already published, so guard each one.
do $$
declare
    t text;
begin
    foreach t in array array['categories', 'expenses', 'accounts', 'budgets'] loop
        if not exists (
            select 1 from pg_publication_tables
            where pubname = 'supabase_realtime'
              and schemaname = 'public'
              and tablename = t
        ) then
            execute format('alter publication supabase_realtime add table public.%I', t);
        end if;
    end loop;
end $$;

-- Realtime only ships the full old-row on delete/update when REPLICA IDENTITY
-- is FULL; we only need the id + user_id filter, so DEFAULT is enough.
