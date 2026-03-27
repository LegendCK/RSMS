-- =============================================================================
-- Migration: 20260327_sales_looks_thumbnail
-- 2026-03-27
--
-- Adds optional main cover image source for curated looks.
-- =============================================================================

ALTER TABLE public.sales_looks
    ADD COLUMN IF NOT EXISTS thumbnail_source TEXT;
