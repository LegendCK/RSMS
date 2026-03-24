-- Migration: Service Ticket Photos Storage Bucket & Policies
-- Adds a storage bucket for service ticket intake photos and RLS policies.

-- 1. Create the storage bucket (if it doesn't exist)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'service-ticket-photos',
    'service-ticket-photos',
    true,
    10485760,  -- 10 MB max per file
    ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/heic']
)
ON CONFLICT (id) DO NOTHING;

-- 2. Storage RLS policies

-- Allow authenticated users to upload photos
CREATE POLICY "Authenticated users can upload ticket photos"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'service-ticket-photos');

-- Allow anyone to read photos (public bucket)
CREATE POLICY "Public read access to ticket photos"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'service-ticket-photos');

-- Allow staff to update/overwrite photos
CREATE POLICY "Staff can update ticket photos"
ON storage.objects FOR UPDATE
TO authenticated
USING (bucket_id = 'service-ticket-photos')
WITH CHECK (bucket_id = 'service-ticket-photos');

-- Allow staff to delete photos
CREATE POLICY "Staff can delete ticket photos"
ON storage.objects FOR DELETE
TO authenticated
USING (bucket_id = 'service-ticket-photos');

-- 3. Ensure service_tickets.intake_photos column exists (it should already from the base schema)
-- This is a safety check — DO NOTHING if the column already exists.
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'service_tickets' AND column_name = 'intake_photos'
    ) THEN
        ALTER TABLE service_tickets ADD COLUMN intake_photos TEXT[] DEFAULT '{}';
    END IF;
END
$$;

-- 4. Index for faster client-based ticket lookups (used by customer profile view)
CREATE INDEX IF NOT EXISTS idx_service_tickets_client_id
ON service_tickets (client_id)
WHERE client_id IS NOT NULL;

-- 5. Index for faster store-based ticket lookups
CREATE INDEX IF NOT EXISTS idx_service_tickets_store_id
ON service_tickets (store_id);

-- 6. Ensure customers can SELECT their own service tickets (for the customer profile view)
-- Check if policy already exists before creating
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE tablename = 'service_tickets'
        AND policyname = 'Customers can view their own tickets'
    ) THEN
        EXECUTE 'CREATE POLICY "Customers can view their own tickets"
        ON service_tickets FOR SELECT
        TO authenticated
        USING (
            client_id = auth.uid()
        )';
    END IF;
END
$$;
