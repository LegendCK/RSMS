-- =============================================================================
-- Product Warranty Policies
-- Stores admin-managed warranty coverage rules per product.
-- =============================================================================

create table if not exists public.product_warranty_policies (
    product_id uuid primary key references public.products(id) on delete cascade,
    coverage_months integer not null check (coverage_months >= 0 and coverage_months <= 120),
    eligible_services text[] not null default '{}',
    created_by uuid null references public.users(id) on delete set null,
    updated_by uuid null references public.users(id) on delete set null,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create index if not exists idx_product_warranty_policies_updated_at
    on public.product_warranty_policies(updated_at desc);

alter table public.product_warranty_policies enable row level security;

drop policy if exists "Warranty policies read by authenticated" on public.product_warranty_policies;
create policy "Warranty policies read by authenticated"
on public.product_warranty_policies
for select
to authenticated
using (true);

drop policy if exists "Warranty policies managed by backoffice roles" on public.product_warranty_policies;
create policy "Warranty policies managed by backoffice roles"
on public.product_warranty_policies
for all
to authenticated
using (
    exists (
        select 1 from public.users
        where users.id = auth.uid()
          and users.role in ('corporate_admin', 'boutique_manager', 'sales_associate', 'service_technician')
    )
)
with check (
    exists (
        select 1 from public.users
        where users.id = auth.uid()
          and users.role in ('corporate_admin', 'boutique_manager', 'sales_associate', 'service_technician')
    )
);

create or replace function public.set_product_warranty_policies_updated_at()
returns trigger
language plpgsql
as $$
begin
    new.updated_at = now();
    return new;
end;
$$;

drop trigger if exists trg_product_warranty_policies_updated_at on public.product_warranty_policies;
create trigger trg_product_warranty_policies_updated_at
before update on public.product_warranty_policies
for each row
execute function public.set_product_warranty_policies_updated_at();

