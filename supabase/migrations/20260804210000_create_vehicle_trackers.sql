-- Migration to create vehicle_trackers table for GPS tracker integration (AIKA168 and future providers)
CREATE TABLE IF NOT EXISTS public.vehicle_trackers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    vehicle_id UUID REFERENCES public.vehicles(id) ON DELETE CASCADE,
    partner_vehicle_id UUID REFERENCES public.partner_vehicles(id) ON DELETE CASCADE,
    vehicle_application_id UUID REFERENCES public.partner_vehicle_applications(id) ON DELETE CASCADE,
    partner_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    operator_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    provider TEXT NOT NULL DEFAULT 'aika168',
    device_identifier TEXT NOT NULL,
    encrypted_password TEXT,
    connection_status TEXT NOT NULL DEFAULT 'pending_verification',
    last_latitude DOUBLE PRECISION,
    last_longitude DOUBLE PRECISION,
    last_speed DOUBLE PRECISION,
    last_ignition BOOLEAN,
    last_location_at TIMESTAMPTZ,
    last_sync_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Unique index to prevent 1 tracker (device_identifier) from being active on multiple vehicles simultaneously
CREATE UNIQUE INDEX IF NOT EXISTS idx_active_vehicle_trackers_device 
ON public.vehicle_trackers (device_identifier) 
WHERE connection_status != 'disconnected';

-- Indexes for fast lookups
CREATE INDEX IF NOT EXISTS idx_vehicle_trackers_vehicle_id ON public.vehicle_trackers (vehicle_id);
CREATE INDEX IF NOT EXISTS idx_vehicle_trackers_partner_vehicle_id ON public.vehicle_trackers (partner_vehicle_id);
CREATE INDEX IF NOT EXISTS idx_vehicle_trackers_application_id ON public.vehicle_trackers (vehicle_application_id);
CREATE INDEX IF NOT EXISTS idx_vehicle_trackers_partner_id ON public.vehicle_trackers (partner_id);

-- Enable Row Level Security (RLS)
ALTER TABLE public.vehicle_trackers ENABLE ROW LEVEL SECURITY;

-- Allow partners and operators to view their own vehicle trackers
CREATE POLICY "Partners and operators can view their own vehicle trackers"
ON public.vehicle_trackers FOR SELECT
USING (
    partner_id = auth.uid() 
    OR operator_id = auth.uid() 
    OR EXISTS (
        SELECT 1 FROM public.users WHERE id = auth.uid() AND role IN ('admin', 'operator')
    )
);

-- Allow partners and operators to insert/update/delete their own vehicle trackers
CREATE POLICY "Partners and operators can manage their own vehicle trackers"
ON public.vehicle_trackers FOR ALL
USING (
    partner_id = auth.uid() 
    OR operator_id = auth.uid() 
    OR EXISTS (
        SELECT 1 FROM public.users WHERE id = auth.uid() AND role IN ('admin', 'operator')
    )
);
