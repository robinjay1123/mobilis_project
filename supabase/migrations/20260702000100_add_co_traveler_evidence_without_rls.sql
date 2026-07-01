alter table public.bookings
  add column if not exists co_traveler_signature_text text,
  add column if not exists co_traveler_signature_url text,
  add column if not exists co_traveler_valid_id_url text,
  add column if not exists co_traveler_selfie_url text;
