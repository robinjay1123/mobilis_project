alter table "public"."drivers" drop constraint "status_check";

alter table "public"."drivers" drop constraint "tier_check";

alter table "public"."user_verifications" drop constraint "verification_status_check";

alter table "public"."drivers" add constraint "status_check" CHECK (((verification_status)::text = ANY ((ARRAY['pending'::character varying, 'approved'::character varying, 'rejected'::character varying])::text[]))) not valid;

alter table "public"."drivers" validate constraint "status_check";

alter table "public"."drivers" add constraint "tier_check" CHECK (((driver_tier)::text = ANY ((ARRAY['standard'::character varying, 'professional'::character varying, 'elite'::character varying])::text[]))) not valid;

alter table "public"."drivers" validate constraint "tier_check";

alter table "public"."user_verifications" add constraint "verification_status_check" CHECK (((verification_status)::text = ANY ((ARRAY['pending'::character varying, 'verified'::character varying, 'rejected'::character varying])::text[]))) not valid;

alter table "public"."user_verifications" validate constraint "verification_status_check";


