-- Enable Supabase Realtime for core app tables used by live manager/customer sync.
-- Idempotent: only adds tables that are not already in supabase_realtime publication.

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'orders'
  ) then
    execute 'alter publication supabase_realtime add table public.orders';
  end if;

  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'inventory_discrepancies'
  ) then
    execute 'alter publication supabase_realtime add table public.inventory_discrepancies';
  end if;

  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'boutique_events'
  ) then
    execute 'alter publication supabase_realtime add table public.boutique_events';
  end if;

  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'wishlist_items'
  ) then
    execute 'alter publication supabase_realtime add table public.wishlist_items';
  end if;

  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'inventory'
  ) then
    execute 'alter publication supabase_realtime add table public.inventory';
  end if;

  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'transfers'
  ) then
    execute 'alter publication supabase_realtime add table public.transfers';
  end if;
end
$$;
