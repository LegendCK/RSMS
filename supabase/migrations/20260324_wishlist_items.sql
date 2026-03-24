-- Customer wishlist storage (backend source of truth)

create table if not exists public.wishlist_items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (user_id, product_id)
);

create index if not exists idx_wishlist_items_user_id
  on public.wishlist_items(user_id);

create index if not exists idx_wishlist_items_product_id
  on public.wishlist_items(product_id);

alter table public.wishlist_items enable row level security;

-- Authenticated users can only view their own wishlist items.
drop policy if exists wishlist_items_select_own on public.wishlist_items;
create policy wishlist_items_select_own
  on public.wishlist_items
  for select
  to authenticated
  using (user_id = auth.uid());

-- Authenticated users can only insert their own wishlist items.
drop policy if exists wishlist_items_insert_own on public.wishlist_items;
create policy wishlist_items_insert_own
  on public.wishlist_items
  for insert
  to authenticated
  with check (user_id = auth.uid());

-- Authenticated users can only remove their own wishlist items.
drop policy if exists wishlist_items_delete_own on public.wishlist_items;
create policy wishlist_items_delete_own
  on public.wishlist_items
  for delete
  to authenticated
  using (user_id = auth.uid());
