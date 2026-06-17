-- Fix partner vehicle approval links.
-- partner_vehicle_applications.partner_id stores users.id.
-- partner_vehicles.partner_id stores partners.id.
-- Therefore application -> partner vehicle must link by partner_vehicle_id only.

alter table if exists public.partner_vehicle_applications
  drop constraint if exists partner_vehicle_applications_partner_vehicle_fk;

alter table if exists public.partner_vehicle_applications
  drop constraint if exists partner_vehicle_applications_partner_vehicle_id_fkey;

alter table if exists public.partner_vehicle_applications
  add constraint partner_vehicle_applications_partner_vehicle_id_fkey
  foreign key (partner_vehicle_id)
  references public.partner_vehicles(id)
  on delete set null;

alter table if exists public.vehicle_images
  add column if not exists partner_vehicle_id uuid;

alter table if exists public.vehicle_images
  drop constraint if exists vehicle_images_partner_vehicle_id_fkey;

alter table if exists public.vehicle_images
  add constraint vehicle_images_partner_vehicle_id_fkey
  foreign key (partner_vehicle_id)
  references public.partner_vehicles(id)
  on delete cascade;

create index if not exists idx_vehicle_images_partner_vehicle_id
  on public.vehicle_images(partner_vehicle_id);
