-- ============================================================
-- Migration: orders_rls_and_default_store
-- Run this in: Supabase Dashboard → SQL Editor → New Query
-- ============================================================

-- ── 1. Default store (required FK for orders.store_id) ──────
INSERT INTO public.stores (name, address, city, country, is_active)
SELECT 'Maison Luxe Flagship', '1 Luxury Avenue', 'New York', 'US', true
WHERE NOT EXISTS (SELECT 1 FROM public.stores WHERE is_active = true);

-- ── 2. Orders SELECT policies for staff & customers ─────────
DROP POLICY IF EXISTS "Staff can view all orders"       ON public.orders;
DROP POLICY IF EXISTS "Customers can view own orders"   ON public.orders;
DROP POLICY IF EXISTS "Staff can view all order items"  ON public.order_items;
DROP POLICY IF EXISTS "Customers can view own order items" ON public.order_items;

-- Sales associates / managers / admins see every order
CREATE POLICY "Staff can view all orders"
ON public.orders FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.users u
    WHERE u.id = auth.uid()
    AND u.role IN (
      'sales_associate','boutique_manager','corporate_admin',
      'inventory_controller','service_technician','aftersales_specialist'
    )
  )
);

-- Customers see only their own orders
CREATE POLICY "Customers can view own orders"
ON public.orders FOR SELECT TO authenticated
USING (client_id = auth.uid());

-- Staff see all order line items
CREATE POLICY "Staff can view all order items"
ON public.order_items FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.orders o
    JOIN public.users u ON u.id = auth.uid()
    WHERE o.id = order_items.order_id
    AND u.role IN (
      'sales_associate','boutique_manager','corporate_admin',
      'inventory_controller','service_technician','aftersales_specialist'
    )
  )
);

-- Customers see their own order items
CREATE POLICY "Customers can view own order items"
ON public.order_items FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.orders o
    WHERE o.id = order_items.order_id
    AND o.client_id = auth.uid()
  )
);
