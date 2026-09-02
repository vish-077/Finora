-- ============================================================================
-- FINORA — Expense Module Migration
-- Tables: categories, expenses  (+ RLS, indexes, default-category seeding)
-- Run in Supabase Dashboard → SQL Editor, or via the Supabase CLI.
-- ============================================================================

-- ── Extensions ──────────────────────────────────────────────────────────────
create extension if not exists "uuid-ossp";

-- ── CATEGORIES ──────────────────────────────────────────────────────────────
create table if not exists public.categories (
    id          uuid primary key default uuid_generate_v4(),
    user_id     uuid not null references auth.users (id) on delete cascade,
    name        text not null,
    icon        text not null default 'category',
    color       text not null default '#3498DB',
    type        text not null default 'expense'
                    check (type in ('income', 'expense')),
    created_at  timestamptz not null default now(),
    updated_at  timestamptz not null default now()
);

create index if not exists categories_user_id_idx on public.categories (user_id);

-- ── EXPENSES ────────────────────────────────────────────────────────────────
create table if not exists public.expenses (
    id                uuid primary key default uuid_generate_v4(),
    user_id           uuid not null references auth.users (id) on delete cascade,
    title             text not null,
    amount            numeric(14, 2) not null check (amount >= 0),
    category_id       uuid references public.categories (id) on delete set null,
    payment_method    text not null default 'cash'
                          check (payment_method in
                              ('cash','upi','creditCard','debitCard','wallet','bankTransfer')),
    transaction_type  text not null default 'expense'
                          check (transaction_type in ('income','expense','transfer')),
    notes             text,
    transaction_date  timestamptz not null default now(),
    created_at        timestamptz not null default now(),
    updated_at        timestamptz not null default now()
);

create index if not exists expenses_user_id_idx on public.expenses (user_id);
create index if not exists expenses_txn_date_idx on public.expenses (user_id, transaction_date desc);
create index if not exists expenses_category_idx on public.expenses (category_id);

-- ── updated_at trigger ──────────────────────────────────────────────────────
create or replace function public.set_updated_at()
returns trigger as $$
begin
    new.updated_at = now();
    return new;
end;
$$ language plpgsql;

drop trigger if exists categories_set_updated_at on public.categories;
create trigger categories_set_updated_at
    before update on public.categories
    for each row execute function public.set_updated_at();

drop trigger if exists expenses_set_updated_at on public.expenses;
create trigger expenses_set_updated_at
    before update on public.expenses
    for each row execute function public.set_updated_at();

-- ── ROW LEVEL SECURITY ──────────────────────────────────────────────────────
alter table public.categories enable row level security;
alter table public.expenses  enable row level security;

-- categories policies (users see/modify only their own rows)
drop policy if exists "categories_select_own" on public.categories;
create policy "categories_select_own" on public.categories
    for select using (auth.uid() = user_id);

drop policy if exists "categories_insert_own" on public.categories;
create policy "categories_insert_own" on public.categories
    for insert with check (auth.uid() = user_id);

drop policy if exists "categories_update_own" on public.categories;
create policy "categories_update_own" on public.categories
    for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "categories_delete_own" on public.categories;
create policy "categories_delete_own" on public.categories
    for delete using (auth.uid() = user_id);

-- expenses policies
drop policy if exists "expenses_select_own" on public.expenses;
create policy "expenses_select_own" on public.expenses
    for select using (auth.uid() = user_id);

drop policy if exists "expenses_insert_own" on public.expenses;
create policy "expenses_insert_own" on public.expenses
    for insert with check (auth.uid() = user_id);

drop policy if exists "expenses_update_own" on public.expenses;
create policy "expenses_update_own" on public.expenses
    for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "expenses_delete_own" on public.expenses;
create policy "expenses_delete_own" on public.expenses
    for delete using (auth.uid() = user_id);

-- ── DEFAULT CATEGORIES on signup ────────────────────────────────────────────
-- Seeds a fresh set of default categories whenever a new auth user is created.
create or replace function public.seed_default_categories()
returns trigger as $$
begin
    insert into public.categories (user_id, name, icon, color, type) values
        (new.id, 'Food',          'restaurant',      '#FF5722', 'expense'),
        (new.id, 'Transport',     'directions_car',  '#3498DB', 'expense'),
        (new.id, 'Shopping',      'shopping_bag',    '#E74C3C', 'expense'),
        (new.id, 'Medical',       'local_hospital',  '#27AE60', 'expense'),
        (new.id, 'Bills',         'receipt_long',    '#1ABC9C', 'expense'),
        (new.id, 'Education',     'school',          '#E67E22', 'expense'),
        (new.id, 'Entertainment', 'movie',           '#9B59B6', 'expense'),
        (new.id, 'Travel',        'flight',          '#00BCD4', 'expense'),
        (new.id, 'Investment',    'trending_up',     '#2ECC71', 'income'),
        (new.id, 'Salary',        'payments',        '#2ECC71', 'income');
    return new;
end;
$$ language plpgsql security definer;

drop trigger if exists on_auth_user_created_seed_categories on auth.users;
create trigger on_auth_user_created_seed_categories
    after insert on auth.users
    for each row execute function public.seed_default_categories();

-- ── REALTIME ────────────────────────────────────────────────────────────────
-- Add tables to the realtime publication (ignore if already added).
do $$
begin
    begin
        alter publication supabase_realtime add table public.expenses;
    exception when duplicate_object then null;
    end;
    begin
        alter publication supabase_realtime add table public.categories;
    exception when duplicate_object then null;
    end;
end $$;
