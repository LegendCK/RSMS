-- =============================================================================
-- RSMS Barcode Scanning System – Database Migration
-- Phase 1: Real-Time Scanning
-- =============================================================================
-- Tables: product_items, scan_sessions, scan_logs
-- Includes: barcode generation helper, performance index, RLS policies
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. product_items
--    One row per physical item. Each row has a UNIQUE barcode.
-- ---------------------------------------------------------------------------
create table if not exists product_items (
    id            uuid        primary key default gen_random_uuid(),
    product_id    uuid        not null references products(id) on delete cascade,
    barcode       text        not null unique,
    serial_number text,
    status        text        not null default 'IN_STOCK'
                              check (status in ('IN_STOCK','SOLD','RESERVED','DAMAGED')),
    store_id      uuid,
    created_at    timestamptz not null default now()
);

comment on table product_items is
    'Serialized physical items. Each row represents one physical product with a unique barcode.';

comment on column product_items.barcode is
    'Unique barcode in format RSMS-<10 char random>. Generated at insert time.';

comment on column product_items.status is
    'Lifecycle status of the physical item: IN_STOCK, SOLD, RESERVED, DAMAGED.';

-- ---------------------------------------------------------------------------
-- 2. Barcode generation helper function
--    Generates a unique RSMS-XXXXXXXXXX barcode.
--    Usage: select generate_rsms_barcode();
-- ---------------------------------------------------------------------------
create or replace function generate_rsms_barcode()
returns text
language sql
as $$
    select 'RSMS-' || upper(substr(md5(gen_random_uuid()::text), 1, 10));
$$;

comment on function generate_rsms_barcode is
    'Generates a unique RSMS-prefixed barcode string for product_items.';

-- ---------------------------------------------------------------------------
-- 3. Performance index on barcode column
--    All iOS barcode lookups hit this index.
-- ---------------------------------------------------------------------------
create index if not exists idx_product_items_barcode
    on product_items(barcode);

-- ---------------------------------------------------------------------------
-- 4. scan_sessions
--    One row per scanning session (IN stocktake, OUT dispatch, AUDIT check).
-- ---------------------------------------------------------------------------
create table if not exists scan_sessions (
    id         uuid        primary key default gen_random_uuid(),
    type       text        not null
                           check (type in ('IN','OUT','AUDIT')),
    started_at timestamptz not null default now(),
    ended_at   timestamptz,
    status     text        not null default 'ACTIVE'
                           check (status in ('ACTIVE','COMPLETED','CANCELLED'))
);

comment on table scan_sessions is
    'Tracks scanning sessions initiated by Inventory Controllers.';

-- ---------------------------------------------------------------------------
-- 5. scan_logs
--    One row per individual scan event within a session.
-- ---------------------------------------------------------------------------
create table if not exists scan_logs (
    id         uuid        primary key default gen_random_uuid(),
    barcode    text        not null,
    session_id uuid        not null references scan_sessions(id) on delete cascade,
    scanned_at timestamptz not null default now()
);

comment on table scan_logs is
    'Audit log of every barcode scan event within a session.';

create index if not exists idx_scan_logs_session_id
    on scan_logs(session_id);

create index if not exists idx_scan_logs_barcode
    on scan_logs(barcode);

-- ---------------------------------------------------------------------------
-- 6. Row Level Security
--    Phase 1: simple authenticated access.
--    Role-based restrictions can be layered on in a future migration.
-- ---------------------------------------------------------------------------

-- product_items RLS
alter table product_items enable row level security;

create policy "Allow authenticated users to read product_items"
    on product_items for select
    using (auth.role() = 'authenticated');

create policy "Allow authenticated users to insert product_items"
    on product_items for insert
    with check (auth.role() = 'authenticated');

create policy "Allow authenticated users to update product_items"
    on product_items for update
    using (auth.role() = 'authenticated');

-- scan_sessions RLS
alter table scan_sessions enable row level security;

create policy "Allow authenticated users to manage scan_sessions"
    on scan_sessions for all
    using (auth.role() = 'authenticated');

-- scan_logs RLS
alter table scan_logs enable row level security;

create policy "Allow authenticated users to manage scan_logs"
    on scan_logs for all
    using (auth.role() = 'authenticated');
