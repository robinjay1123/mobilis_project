-- ============================================================================
-- MOBILIS DATABASE MIGRATION: Decouple partner_vehicles and vehicles tables
-- 1. Synchronize partner_vehicles schema with all standard vehicle columns.
-- 2. Add owner_name & owner_role to vehicles table for Operator fleet attribution.
-- 3. Migrate any partner vehicles from vehicles table to partner_vehicles table.
-- 4. Backfill owner_name for existing Operator vehicles in vehicles table.
-- 5. Clean up partner records from vehicles table.
-- ============================================================================

-- Step 1: Ensure all standard columns exist on partner_vehicles table
ALTER TABLE IF EXISTS public.partner_vehicles 
  ADD COLUMN IF NOT EXISTS vehicle_name text,
  ADD COLUMN IF NOT EXISTS application_status text DEFAULT 'approved',
  ADD COLUMN IF NOT EXISTS owner_name text,
  ADD COLUMN IF NOT EXISTS owner_role text DEFAULT 'partner',
  ADD COLUMN IF NOT EXISTS category text DEFAULT 'Partner Vehicle',
  ADD COLUMN IF NOT EXISTS vehicle_type text DEFAULT 'Partner Vehicle',
  ADD COLUMN IF NOT EXISTS description text,
  ADD COLUMN IF NOT EXISTS color text,
  ADD COLUMN IF NOT EXISTS location text,
  ADD COLUMN IF NOT EXISTS latitude double precision,
  ADD COLUMN IF NOT EXISTS longitude double precision,
  ADD COLUMN IF NOT EXISTS is_posted boolean DEFAULT true,
  ADD COLUMN IF NOT EXISTS rating double precision DEFAULT 0.0,
  ADD COLUMN IF NOT EXISTS rating_count integer DEFAULT 0,
  ADD COLUMN IF NOT EXISTS updated_at timestamp with time zone DEFAULT now();

-- Update vehicle_name for existing partner_vehicles where it's NULL
UPDATE public.partner_vehicles
SET vehicle_name = TRIM(CONCAT(COALESCE(brand, ''), ' ', COALESCE(model, '')))
WHERE vehicle_name IS NULL OR vehicle_name = '';

-- Step 2: Ensure owner_name and owner_role exist on vehicles table
ALTER TABLE IF EXISTS public.vehicles 
  ADD COLUMN IF NOT EXISTS owner_name text,
  ADD COLUMN IF NOT EXISTS owner_role text DEFAULT 'operator';

-- Step 3: Backfill owner_name for existing Operator vehicles in vehicles table
UPDATE public.vehicles v
SET 
  owner_role = 'operator',
  owner_name = COALESCE(
    (
      SELECT 'Operator ' || NULLIF(TRIM(p.full_name), '') 
      FROM public.profiles p 
      WHERE p.id = v.owner_id
      LIMIT 1
    ),
    (
      SELECT 'Operator ' || NULLIF(TRIM(u.full_name), '') 
      FROM public.users u 
      WHERE u.id = v.owner_id
      LIMIT 1
    ),
    'PSDC Operator'
  )
WHERE v.owner_name IS NULL OR v.owner_name = '' OR v.owner_name = 'PSDC Operator';

-- Step 4: Backfill owner_name for partner_vehicles from partners / profiles
UPDATE public.partner_vehicles pv
SET 
  owner_role = 'partner',
  owner_name = COALESCE(
    pv.owner_name,
    (
      SELECT NULLIF(TRIM(pt.business_name), '')
      FROM public.partners pt
      WHERE pt.id = pv.partner_id
      LIMIT 1
    ),
    (
      SELECT NULLIF(TRIM(p.full_name), '')
      FROM public.partners pt
      JOIN public.profiles p ON p.id = pt.user_id
      WHERE pt.id = pv.partner_id
      LIMIT 1
    ),
    'Mobilis Partner'
  ),
  application_status = COALESCE(pv.application_status, 'approved')
WHERE pv.owner_name IS NULL OR pv.owner_name = '';

-- Step 5: Migrate any partner vehicles mistakenly inserted into vehicles table
-- For any row in vehicles with owner_role = 'partner' or linked via partner_vehicles.vehicle_id
DO $$
DECLARE
  v_rec RECORD;
  v_partner_id uuid;
  v_pv_id uuid;
BEGIN
  FOR v_rec IN 
    SELECT v.* 
    FROM public.vehicles v
    WHERE v.owner_role = 'partner'
       OR v.id IN (SELECT vehicle_id FROM public.partner_vehicles WHERE vehicle_id IS NOT NULL)
  LOOP
    -- Check if partner_vehicles already has a matching record by plate_number or vehicle_id
    SELECT id INTO v_pv_id 
    FROM public.partner_vehicles 
    WHERE vehicle_id = v_rec.id 
       OR (plate_number = v_rec.plate_number AND plate_number IS NOT NULL AND plate_number != '')
    LIMIT 1;

    IF v_pv_id IS NOT NULL THEN
      -- Update existing partner_vehicles record
      UPDATE public.partner_vehicles
      SET 
        vehicle_name = COALESCE(v_rec.vehicle_name, TRIM(CONCAT(v_rec.brand, ' ', v_rec.model))),
        brand = COALESCE(brand, v_rec.brand),
        model = COALESCE(model, v_rec.model),
        year = COALESCE(year, v_rec.year),
        seats = COALESCE(seats, v_rec.seats),
        price_per_day = COALESCE(price_per_day, v_rec.price_per_day),
        price_per_hour = COALESCE(price_per_hour, v_rec.price_per_hour),
        fuel_type = COALESCE(fuel_type, v_rec.fuel_type),
        transmission = COALESCE(transmission, v_rec.transmission),
        category = COALESCE(category, v_rec.category),
        vehicle_type = COALESCE(vehicle_type, v_rec.vehicle_type),
        description = COALESCE(description, v_rec.description),
        color = COALESCE(color, v_rec.color),
        location = COALESCE(location, v_rec.location),
        latitude = COALESCE(latitude, v_rec.latitude),
        longitude = COALESCE(longitude, v_rec.longitude),
        application_status = 'approved',
        status = 'available',
        is_available = true,
        is_posted = true,
        owner_role = 'partner'
      WHERE id = v_pv_id;
    ELSE
      -- Resolve partner_id from partners table
      SELECT id INTO v_partner_id FROM public.partners WHERE user_id = v_rec.owner_id LIMIT 1;
      IF v_partner_id IS NULL THEN
        SELECT id INTO v_partner_id FROM public.partners LIMIT 1;
      END IF;

      IF v_partner_id IS NOT NULL THEN
        INSERT INTO public.partner_vehicles (
          partner_id,
          vehicle_name,
          brand,
          model,
          year,
          plate_number,
          seats,
          price_per_day,
          price_per_hour,
          fuel_type,
          transmission,
          category,
          vehicle_type,
          description,
          color,
          location,
          latitude,
          longitude,
          is_available,
          is_posted,
          status,
          application_status,
          owner_name,
          owner_role,
          created_at
        ) VALUES (
          v_partner_id,
          COALESCE(v_rec.vehicle_name, TRIM(CONCAT(v_rec.brand, ' ', v_rec.model))),
          v_rec.brand,
          v_rec.model,
          v_rec.year,
          v_rec.plate_number,
          COALESCE(v_rec.seats, 5),
          COALESCE(v_rec.price_per_day, 0),
          COALESCE(v_rec.price_per_hour, 0),
          COALESCE(v_rec.fuel_type, 'Gasoline'),
          COALESCE(v_rec.transmission, 'Manual'),
          COALESCE(v_rec.category, 'Partner Vehicle'),
          COALESCE(v_rec.vehicle_type, 'Partner Vehicle'),
          v_rec.description,
          v_rec.color,
          v_rec.location,
          v_rec.latitude,
          v_rec.longitude,
          true,
          true,
          'available',
          'approved',
          COALESCE(v_rec.owner_name, 'Mobilis Partner'),
          'partner',
          COALESCE(v_rec.created_at, now())
        )
        RETURNING id INTO v_pv_id;
      END IF;
    END IF;

    -- Update any vehicle_images to point to partner_vehicle_id
    IF v_pv_id IS NOT NULL THEN
      UPDATE public.vehicle_images 
      SET partner_vehicle_id = v_pv_id 
      WHERE vehicle_id = v_rec.id AND partner_vehicle_id IS NULL;
    END IF;
  END LOOP;

  -- Clean up partner vehicles from vehicles table so vehicles is SOLELY for Operator / PSDC fleet
  DELETE FROM public.vehicles 
  WHERE owner_role = 'partner'
     OR id IN (SELECT vehicle_id FROM public.partner_vehicles WHERE vehicle_id IS NOT NULL);

END $$;

-- Step 6: Verify final counts
SELECT 'operator_vehicles_in_vehicles' AS table_type, count(*) FROM public.vehicles
UNION ALL
SELECT 'partner_vehicles_in_partner_vehicles' AS table_type, count(*) FROM public.partner_vehicles;
