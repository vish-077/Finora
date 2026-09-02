-- ============================================================================
-- FINORA — Accounts & Wallets Migration (Phase 7)
-- Tables: accounts
-- Updates: add account_id to expenses
-- ============================================================================

-- ── ACCOUNTS ────────────────────────────────────────────────────────────────
create table if not exists public.accounts (
    id                   uuid primary key default uuid_generate_v4(),
    user_id              uuid not null references auth.users (id) on delete cascade,
    name                 text not null,
    type                 text not null default 'cash',
    bank_name            text,
    account_number_last4 text,
    currency             text not null default 'INR',
    opening_balance      numeric(14, 2) not null default 0,
    current_balance      numeric(14, 2) not null default 0,
    icon                 text not null default 'account_balance_wallet',
    color                text not null default '#3498DB',
    is_default           boolean not null default false,
    created_at           timestamptz not null default now(),
    updated_at           timestamptz not null default now()
);

create index if not exists accounts_user_id_idx on public.accounts (user_id);

-- ── ACCOUNTS triggers & RLS ─────────────────────────────────────────────────
drop trigger if exists accounts_set_updated_at on public.accounts;
create trigger accounts_set_updated_at
    before update on public.accounts
    for each row execute function public.set_updated_at();

alter table public.accounts enable row level security;

create policy "accounts_select_own" on public.accounts
    for select using (auth.uid() = user_id);

create policy "accounts_insert_own" on public.accounts
    for insert with check (auth.uid() = user_id);

create policy "accounts_update_own" on public.accounts
    for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "accounts_delete_own" on public.accounts
    for delete using (auth.uid() = user_id);

-- ── EXPENSES UPDATE ─────────────────────────────────────────────────────────
-- Add account_id to existing expenses table
alter table public.expenses 
add column if not exists account_id uuid references public.accounts (id) on delete set null;

create index if not exists expenses_account_idx on public.expenses (account_id);

-- ── DEFAULT ACCOUNT SEEDING ─────────────────────────────────────────────────
-- When a user is created, also seed a default 'Cash' account for them.
-- We'll modify the existing user creation trigger function to include account seeding.
create or replace function public.seed_default_categories_and_accounts()
returns trigger as $$
declare
    new_account_id uuid;
begin
    -- 1. Create Default Categories
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

    -- 2. Create Default Cash Account
    insert into public.accounts (user_id, name, type, icon, color, is_default, opening_balance, current_balance)
    values (new.id, 'Cash Wallet', 'cash', 'account_balance_wallet', '#2ECC71', true, 0, 0)
    returning id into new_account_id;

    return new;
end;
$$ language plpgsql security definer;

-- Rebind the trigger
drop trigger if exists on_auth_user_created_seed_categories on auth.users;
create trigger on_auth_user_created_seed_categories
    after insert on auth.users
    for each row execute function public.seed_default_categories_and_accounts();

-- ── REALTIME ────────────────────────────────────────────────────────────────
do $$
begin
    begin
        alter publication supabase_realtime add table public.accounts;
    exception when duplicate_object then null;
    end;
end $$;
