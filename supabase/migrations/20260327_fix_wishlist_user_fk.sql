-- Fix wishlist ownership FK for registered customers.
-- Customers exist in auth.users (+ public.clients), not necessarily in public.users.
-- The wishlist row-level policy already keys ownership to auth.uid(), so FK should match auth.users(id).

alter table public.wishlist_items
  drop constraint if exists wishlist_items_user_id_fkey;

alter table public.wishlist_items
  add constraint wishlist_items_user_id_fkey
  foreign key (user_id) references auth.users(id) on delete cascade;

