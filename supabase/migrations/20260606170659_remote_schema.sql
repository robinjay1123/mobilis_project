


SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH SCHEMA "vault";






CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "vector" WITH SCHEMA "public";






CREATE OR REPLACE FUNCTION "public"."get_operator_booking_vehicles"("p_vehicle_ids" "uuid"[]) RETURNS TABLE("id" "uuid", "brand" "text", "model" "text", "year" integer, "owner_id" "uuid", "vehicle_name" "text", "price_per_day" numeric)
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  SELECT
    v.id,
    v.brand::text,
    v.model::text,
    v.year,
    v.owner_id,
    v.vehicle_name::text,
    v.price_per_day
  FROM public.vehicles v
  WHERE v.id = ANY(COALESCE(p_vehicle_ids, ARRAY[]::uuid[]))
    AND (
      public.is_operator_user()
      OR v.owner_id = auth.uid()
      OR v.operator_id = auth.uid()
    );
$$;


ALTER FUNCTION "public"."get_operator_booking_vehicles"("p_vehicle_ids" "uuid"[]) OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."bookings" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "renter_id" "uuid",
    "vehicle_id" "uuid",
    "actual_return_time" timestamp without time zone,
    "total_price" numeric,
    "overtime_fee" numeric DEFAULT 0,
    "driver_requested" boolean DEFAULT false,
    "status" "text" DEFAULT 'pending'::"text",
    "created_at" timestamp without time zone DEFAULT "now"(),
    "with_driver" boolean DEFAULT false,
    "driver_id" "uuid",
    "approved_at" timestamp without time zone,
    "rejected_at" timestamp without time zone,
    "rejection_reason" "text",
    "driver_assigned_at" timestamp without time zone,
    "start_date" timestamp without time zone,
    "end_date" timestamp without time zone,
    "pickup_location" "text",
    "dropoff_location" "text",
    "conversation_created" boolean DEFAULT false,
    "operator_notes" "text",
    "updated_at" timestamp without time zone DEFAULT "now"(),
    "total_cost" numeric(12,2),
    "picked_up_at" timestamp with time zone,
    "returned_at" timestamp with time zone,
    "completed_at" timestamp with time zone,
    "start_at" timestamp with time zone,
    "end_at" timestamp with time zone,
    "operator_id" "uuid"
);


ALTER TABLE "public"."bookings" OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_operator_bookings"() RETURNS SETOF "public"."bookings"
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  SELECT b.*
  FROM public.bookings b
  WHERE public.is_operator_user()
     OR b.vehicle_id IN (
       SELECT v.id
       FROM public.vehicles v
       WHERE v.owner_id = auth.uid()
          OR v.operator_id = auth.uid()
     )
  ORDER BY b.created_at DESC
  LIMIT 100;
$$;


ALTER FUNCTION "public"."get_operator_bookings"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_new_auth_user"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  insert into public.users (
    id,
    name,
    email,
    phone,
    role,
    status,
    created_at
  )
  values (
    new.id,
    coalesce(
      new.raw_user_meta_data ->> 'full_name',
      new.raw_user_meta_data ->> 'name',
      split_part(new.email, '@', 1)
    ),
    new.email,
    new.raw_user_meta_data ->> 'phone',
    coalesce(new.raw_user_meta_data ->> 'role', 'renter'),
    'active',
    now()
  )
  on conflict (id) do update
  set
    email = excluded.email,
    phone = coalesce(excluded.phone, public.users.phone),
    role = coalesce(excluded.role, public.users.role);

  return new;
end;
$$;


ALTER FUNCTION "public"."handle_new_auth_user"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_admin_user"() RETURNS boolean
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.users
    WHERE id = auth.uid()
      AND role = 'admin'
  );
$$;


ALTER FUNCTION "public"."is_admin_user"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_assigned_driver_for_vehicle"("p_vehicle_id" "uuid") RETURNS boolean
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.bookings b
    WHERE b.vehicle_id = p_vehicle_id
      AND b.driver_id = auth.uid()
  );
$$;


ALTER FUNCTION "public"."is_assigned_driver_for_vehicle"("p_vehicle_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_operator_user"() RETURNS boolean
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.users
    WHERE role = 'operator'
      AND (
        id = auth.uid()
        OR lower(email) = lower(auth.jwt() ->> 'email')
      )
  );
$$;


ALTER FUNCTION "public"."is_operator_user"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_user_blocked"("user_id" "uuid") RETURNS boolean
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  RETURN (
    SELECT is_blocked FROM public.users 
    WHERE id = user_id
  );
END;
$$;


ALTER FUNCTION "public"."is_user_blocked"("user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_vehicle_available_for_booking"("p_vehicle_id" "uuid", "p_start_date" timestamp with time zone, "p_end_date" timestamp with time zone, "p_exclude_booking_id" "uuid" DEFAULT NULL::"uuid") RETURNS boolean
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  SELECT NOT EXISTS (
    SELECT 1
    FROM public.bookings b
    WHERE b.vehicle_id = p_vehicle_id
      AND (p_exclude_booking_id IS NULL OR b.id <> p_exclude_booking_id)
      AND lower(COALESCE(b.status, 'pending')) NOT IN (
        'cancelled',
        'canceled',
        'rejected',
        'completed'
      )
      AND b.start_at IS NOT NULL
      AND b.end_at IS NOT NULL
      AND p_start_date < b.end_at
      AND p_end_date > b.start_at
  );
$$;


ALTER FUNCTION "public"."is_vehicle_available_for_booking"("p_vehicle_id" "uuid", "p_start_date" timestamp with time zone, "p_end_date" timestamp with time zone, "p_exclude_booking_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_vehicle_operator"("vehicle_id" "uuid") RETURNS boolean
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.vehicles
    WHERE id = vehicle_id
      AND (owner_id = auth.uid() OR operator_id = auth.uid())
  );
$$;


ALTER FUNCTION "public"."is_vehicle_operator"("vehicle_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_vehicle_owner"("vehicle_id" "uuid") RETURNS boolean
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.vehicles
    WHERE id = vehicle_id
      AND owner_id = auth.uid()
  );
$$;


ALTER FUNCTION "public"."is_vehicle_owner"("vehicle_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."prevent_overlapping_bookings"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
  IF NEW.vehicle_id IS NULL OR NEW.start_at IS NULL OR NEW.end_at IS NULL THEN
    RETURN NEW;
  END IF;

  IF NEW.end_at <= NEW.start_at THEN
    RAISE EXCEPTION 'End time must be after start time'
      USING ERRCODE = '23514';
  END IF;

  IF lower(COALESCE(NEW.status, 'pending')) IN (
    'cancelled',
    'canceled',
    'rejected',
    'completed'
  ) THEN
    RETURN NEW;
  END IF;

  IF NOT public.is_vehicle_available_for_booking(
    NEW.vehicle_id,
    NEW.start_at,
    NEW.end_at,
    CASE WHEN TG_OP = 'UPDATE' THEN NEW.id ELSE NULL END
  ) THEN
    RAISE EXCEPTION 'Selected dates are unavailable for bookings'
      USING ERRCODE = '23P01';
  END IF;

  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."prevent_overlapping_bookings"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
begin
  new.updated_at = now();
  return new;
end;
$$;


ALTER FUNCTION "public"."set_updated_at"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."sync_user_verification_status"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  UPDATE public.users
  SET
    verification_status = NEW.verification_status,
    id_verified = (NEW.verification_status = 'verified')
  WHERE id = NEW.user_id;

  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."sync_user_verification_status"() OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."bookmarks" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "vehicle_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."bookmarks" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."conversation_participants" (
    "conversation_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "joined_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."conversation_participants" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."conversations" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "is_group" boolean DEFAULT false,
    "booking_id" "uuid",
    "user_id" "uuid",
    "other_user_id" "uuid",
    "status" "text" DEFAULT 'active'::"text",
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."conversations" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."conversations_backup" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user1_id" "uuid",
    "user2_id" "uuid",
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE "public"."conversations_backup" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."driver_availability_schedule" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "driver_id" "uuid" NOT NULL,
    "day_of_week" character varying,
    "start_time" time without time zone,
    "end_time" time without time zone,
    "date" "date",
    "is_available" boolean DEFAULT true,
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE "public"."driver_availability_schedule" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."driver_documents" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "driver_id" "uuid" NOT NULL,
    "document_type" character varying NOT NULL,
    "file_url" character varying NOT NULL,
    "issue_date" "date" NOT NULL,
    "expiry_date" "date" NOT NULL,
    "status" character varying DEFAULT 'pending'::character varying,
    "admin_notes" "text",
    "verified_at" timestamp without time zone,
    "verified_by" "uuid",
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "updated_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE "public"."driver_documents" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."driver_earnings" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "driver_id" "uuid" NOT NULL,
    "trip_id" "uuid",
    "trip_fee" numeric(10,2) NOT NULL,
    "commission_percentage" numeric(5,2) DEFAULT 15,
    "commission_amount" numeric(10,2),
    "net_earnings" numeric(10,2),
    "payout_status" character varying DEFAULT 'pending'::character varying,
    "paid_at" timestamp without time zone,
    "payout_method" character varying,
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE "public"."driver_earnings" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."driver_job_assignments" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "booking_id" "uuid" NOT NULL,
    "driver_id" "uuid" NOT NULL,
    "status" character varying DEFAULT 'pending_offer'::character varying,
    "offered_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "replied_at" timestamp without time zone,
    "trip_fee" numeric(10,2) DEFAULT 0,
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "updated_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE "public"."driver_job_assignments" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."driver_tier_history" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "driver_id" "uuid" NOT NULL,
    "old_tier" character varying(50),
    "new_tier" character varying(50) NOT NULL,
    "reason" character varying(255),
    "created_at" timestamp without time zone DEFAULT "now"()
);


ALTER TABLE "public"."driver_tier_history" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."driver_trips" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "booking_id" "uuid" NOT NULL,
    "driver_id" "uuid" NOT NULL,
    "pickup_location" character varying,
    "pickup_time" timestamp without time zone,
    "dropoff_location" character varying,
    "dropoff_time" timestamp without time zone,
    "status" character varying DEFAULT 'pending'::character varying,
    "distance_km" double precision,
    "duration_minutes" integer,
    "renter_rating" double precision,
    "renter_comment" "text",
    "driver_comment" "text",
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "updated_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE "public"."driver_trips" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."drivers" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "verification_status" character varying DEFAULT 'pending'::character varying,
    "license_number" character varying NOT NULL,
    "license_expiry" "date" NOT NULL,
    "license_verified" boolean DEFAULT false,
    "nbi_verified" boolean DEFAULT false,
    "nbi_file_url" character varying,
    "driver_tier" character varying DEFAULT 'standard'::character varying,
    "rating" double precision DEFAULT 0.0,
    "total_trips" integer DEFAULT 0,
    "preferred_days" character varying,
    "preferred_areas" character varying,
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "updated_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "tier" "text",
    "license_url" "text",
    CONSTRAINT "status_check" CHECK ((("verification_status")::"text" = ANY ((ARRAY['pending'::character varying, 'approved'::character varying, 'rejected'::character varying])::"text"[]))),
    CONSTRAINT "tier_check" CHECK ((("driver_tier")::"text" = ANY ((ARRAY['standard'::character varying, 'professional'::character varying, 'elite'::character varying])::"text"[])))
);


ALTER TABLE "public"."drivers" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."filter_words" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "word" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    "created_by" "uuid"
);


ALTER TABLE "public"."filter_words" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."message_flags" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "message_id" "uuid",
    "conversation_id" "uuid" NOT NULL,
    "sender_id" "uuid" NOT NULL,
    "flag_reason" "text" NOT NULL,
    "message_content" "text",
    "risk_score" numeric(3,2),
    "risk_level" "text",
    "status" "text" DEFAULT 'pending_review'::"text" NOT NULL,
    "admin_notes" "text",
    "created_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    "reviewed_at" timestamp with time zone,
    CONSTRAINT "message_flags_risk_level_check" CHECK (("risk_level" = ANY (ARRAY['low'::"text", 'medium'::"text", 'high'::"text"]))),
    CONSTRAINT "message_flags_status_check" CHECK (("status" = ANY (ARRAY['pending_review'::"text", 'confirmed'::"text", 'dismissed'::"text"])))
);


ALTER TABLE "public"."message_flags" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."messages" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "conversation_id" "uuid",
    "sender_id" "uuid" NOT NULL,
    "booking_id" "uuid",
    "message" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "is_auto_generated" boolean DEFAULT false,
    "content" "text",
    "is_read" boolean DEFAULT false
);


ALTER TABLE "public"."messages" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."messages_backup" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "sender_id" "uuid",
    "receiver_id" "uuid",
    "booking_id" "uuid",
    "message" "text",
    "created_at" timestamp without time zone DEFAULT "now"()
);


ALTER TABLE "public"."messages_backup" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."notifications" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid",
    "title" "text",
    "message" "text",
    "is_read" boolean DEFAULT false,
    "created_at" timestamp without time zone DEFAULT "now"(),
    "body" "text",
    "type" "text" DEFAULT 'general'::"text",
    "data" "jsonb"
);


ALTER TABLE "public"."notifications" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."partner_vehicle_applications" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "partner_id" "uuid" NOT NULL,
    "partner_vehicle_id" "uuid",
    "status" "text" DEFAULT 'pending'::"text" NOT NULL,
    "submitted_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "verified_by" "uuid",
    "verified_at" timestamp without time zone,
    "or_document_url" character varying,
    "cr_document_url" character varying,
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "updated_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "application_status" "text",
    "brand" "text",
    "model" "text",
    "year" integer,
    "plate_number" "text",
    "price_per_day" numeric,
    "price_per_hour" numeric,
    "vehicle_photo_url" "text",
    "rejection_reason" "text",
    "reviewed_at" timestamp without time zone,
    "created_vehicle_id" "uuid",
    "seats" integer DEFAULT 5,
    "fuel_type" "text" DEFAULT 'Gasoline'::"text",
    "transmission" "text" DEFAULT 'Manual'::"text",
    CONSTRAINT "partner_vehicle_applications_status_check" CHECK (("status" = ANY (ARRAY['pending'::"text", 'approved'::"text", 'rejected'::"text"])))
);


ALTER TABLE "public"."partner_vehicle_applications" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."partner_vehicle_documents" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "partner_vehicle_application_id" "uuid" NOT NULL,
    "document_type" "text",
    "file_url" "text",
    "uploaded_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "updated_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE "public"."partner_vehicle_documents" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."partner_vehicles" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "partner_id" "uuid" NOT NULL,
    "brand" "text",
    "model" "text",
    "year" integer,
    "plate_number" "text",
    "seats" integer,
    "price_per_day" numeric,
    "price_per_hour" numeric,
    "status" "text" DEFAULT 'available'::"text" NOT NULL,
    "created_at" timestamp without time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp without time zone DEFAULT "now"() NOT NULL,
    "vehicle_id" "uuid",
    "fuel_type" "text" DEFAULT 'Gasoline'::"text",
    "transmission" "text" DEFAULT 'Manual'::"text",
    CONSTRAINT "partner_vehicles_status_check" CHECK (("status" = ANY (ARRAY['available'::"text", 'pending'::"text", 'disabled'::"text", 'sold'::"text"])))
);


ALTER TABLE "public"."partner_vehicles" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."partners" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid",
    "business_name" "text",
    "address" "text",
    "verification_status" "text" DEFAULT 'pending'::"text",
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "business_address" "text",
    "business_phone" "text",
    CONSTRAINT "partners_verification_status_check" CHECK (("verification_status" = ANY (ARRAY['pending'::"text", 'approved'::"text", 'rejected'::"text"])))
);


ALTER TABLE "public"."partners" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."profiles" (
    "id" "uuid" NOT NULL,
    "role" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "full_name" "text",
    "phone" "text",
    "address" "text",
    "avatar_url" "text",
    CONSTRAINT "profiles_role_check" CHECK (("role" = ANY (ARRAY['renter'::"text", 'driver'::"text", 'partner'::"text"])))
);


ALTER TABLE "public"."profiles" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."ratings_backup" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "booking_id" "uuid",
    "renter_id" "uuid",
    "vehicle_rating" integer,
    "driver_rating" integer,
    "comment" "text",
    "created_at" timestamp without time zone DEFAULT "now"()
);


ALTER TABLE "public"."ratings_backup" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."renter_documents" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "renter_id" "uuid" NOT NULL,
    "document_type" "text" NOT NULL,
    "document_number" "text",
    "document_url" "text" NOT NULL,
    "status" "text" DEFAULT 'pending'::"text" NOT NULL,
    "reviewer_id" "uuid",
    "reviewed_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."renter_documents" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."renters" (
    "id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "full_name" "text",
    "phone" "text",
    "address" "text",
    "avatar_url" "text",
    "user_id" "uuid"
);


ALTER TABLE "public"."renters" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."transactions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "booking_id" "uuid",
    "amount" numeric,
    "commission" numeric,
    "partner_earnings" numeric,
    "operator_earnings" numeric,
    "created_at" timestamp without time zone DEFAULT "now"()
);


ALTER TABLE "public"."transactions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."user_documents" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "profile_id" "uuid" NOT NULL,
    "document_type" "text" NOT NULL,
    "document_number" "text",
    "document_url" "text" NOT NULL,
    "status" "text" DEFAULT 'pending'::"text" NOT NULL,
    "reviewer_id" "uuid",
    "reviewed_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "user_documents_status_check" CHECK (("status" = ANY (ARRAY['pending'::"text", 'approved'::"text", 'rejected'::"text"])))
);


ALTER TABLE "public"."user_documents" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."user_verifications" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "id_document_url" character varying(500),
    "verification_status" character varying(50) DEFAULT 'pending'::character varying,
    "rejection_reason" "text",
    "created_at" timestamp without time zone DEFAULT "now"(),
    "verified_at" timestamp without time zone,
    "id_type" "text",
    "id_number" "text",
    "full_name" "text",
    "location" "text",
    "phone" "text",
    "face_match_percentage" numeric(5,2),
    "verified_by" "uuid",
    CONSTRAINT "verification_status_check" CHECK ((("verification_status")::"text" = ANY ((ARRAY['pending'::character varying, 'verified'::character varying, 'rejected'::character varying])::"text"[])))
);


ALTER TABLE "public"."user_verifications" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."users" (
    "id" "uuid" NOT NULL,
    "name" "text" NOT NULL,
    "email" "text",
    "phone" "text",
    "role" "text",
    "status" "text" DEFAULT 'active'::"text",
    "latitude" numeric,
    "longitude" numeric,
    "created_at" timestamp without time zone DEFAULT "now"(),
    "is_driver" boolean DEFAULT false,
    "is_available" boolean DEFAULT false,
    "full_name" "text",
    "application_status" "text",
    "id_verified" boolean DEFAULT false,
    "verification_status" "text",
    "off_platform_flag_count" integer DEFAULT 0,
    "is_blocked" boolean DEFAULT false,
    "location" "text",
    CONSTRAINT "users_role_check" CHECK (("role" = ANY (ARRAY['admin'::"text", 'operator'::"text", 'partner'::"text", 'driver'::"text", 'renter'::"text"])))
);


ALTER TABLE "public"."users" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."vehicle_applications" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "partner_id" "uuid",
    "brand" "text",
    "model" "text",
    "year" integer,
    "plate_number" "text",
    "seats" integer,
    "price_per_day" numeric,
    "price_per_hour" numeric,
    "status" "text" DEFAULT 'pending'::"text",
    "submitted_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "verified_by" "uuid",
    "verified_at" timestamp without time zone,
    "or_document_url" character varying,
    "cr_document_url" character varying,
    CONSTRAINT "vehicle_applications_status_check" CHECK (("status" = ANY (ARRAY['pending'::"text", 'approved'::"text", 'rejected'::"text"])))
);


ALTER TABLE "public"."vehicle_applications" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."vehicle_availability_backup" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "vehicle_id" "uuid",
    "date" "date",
    "is_available" boolean DEFAULT true
);


ALTER TABLE "public"."vehicle_availability_backup" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."vehicle_documents" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "vehicle_application_id" "uuid",
    "document_type" "text",
    "file_url" "text",
    "uploaded_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE "public"."vehicle_documents" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."vehicle_images" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "vehicle_id" "uuid",
    "image_url" "text",
    "display_order" integer DEFAULT 0,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."vehicle_images" OWNER TO "postgres";


COMMENT ON TABLE "public"."vehicle_images" IS 'Store multiple images for each vehicle in gallery format';



COMMENT ON COLUMN "public"."vehicle_images"."display_order" IS 'Order of images in gallery (0-indexed)';



CREATE TABLE IF NOT EXISTS "public"."vehicles" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "owner_id" "uuid",
    "owner_role" "text",
    "vehicle_name" "text",
    "brand" "text",
    "model" "text",
    "year" integer,
    "plate_number" "text",
    "price_per_day" numeric,
    "price_per_hour" numeric,
    "latitude" numeric,
    "longitude" numeric,
    "status" "text" DEFAULT 'available'::"text",
    "created_at" timestamp without time zone DEFAULT "now"(),
    "is_available" boolean DEFAULT false,
    "category" "text" DEFAULT 'Standard'::"text",
    "vehicle_type" "text" DEFAULT 'Sedan'::"text",
    "description" "text",
    "color" "text",
    "seats" integer DEFAULT 4,
    "rating" numeric DEFAULT 4.5,
    "search_text" "tsvector",
    "operator_id" "uuid",
    "is_posted" boolean DEFAULT false NOT NULL,
    "location" "text",
    "transmission" "text" DEFAULT 'Manual'::"text",
    "fuel_type" "text" DEFAULT 'Gasoline'::"text",
    CONSTRAINT "vehicles_owner_role_check" CHECK (("owner_role" = ANY (ARRAY['operator'::"text", 'partner'::"text"])))
);


ALTER TABLE "public"."vehicles" OWNER TO "postgres";


ALTER TABLE ONLY "public"."bookings"
    ADD CONSTRAINT "bookings_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."bookmarks"
    ADD CONSTRAINT "bookmarks_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."conversation_participants"
    ADD CONSTRAINT "conversation_participants_new_pkey" PRIMARY KEY ("conversation_id", "user_id");



ALTER TABLE ONLY "public"."conversation_participants"
    ADD CONSTRAINT "conversation_participants_unique_user" UNIQUE ("conversation_id", "user_id");



ALTER TABLE ONLY "public"."conversations"
    ADD CONSTRAINT "conversations_new_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."conversations_backup"
    ADD CONSTRAINT "conversations_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."driver_availability_schedule"
    ADD CONSTRAINT "driver_availability_schedule_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."driver_documents"
    ADD CONSTRAINT "driver_documents_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."driver_earnings"
    ADD CONSTRAINT "driver_earnings_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."driver_job_assignments"
    ADD CONSTRAINT "driver_job_assignments_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."driver_tier_history"
    ADD CONSTRAINT "driver_tier_history_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."driver_trips"
    ADD CONSTRAINT "driver_trips_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."drivers"
    ADD CONSTRAINT "drivers_license_number_key" UNIQUE ("license_number");



ALTER TABLE ONLY "public"."drivers"
    ADD CONSTRAINT "drivers_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."drivers"
    ADD CONSTRAINT "drivers_user_id_key" UNIQUE ("user_id");



ALTER TABLE ONLY "public"."filter_words"
    ADD CONSTRAINT "filter_words_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."filter_words"
    ADD CONSTRAINT "filter_words_word_key" UNIQUE ("word");



ALTER TABLE ONLY "public"."message_flags"
    ADD CONSTRAINT "message_flags_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."messages"
    ADD CONSTRAINT "messages_new_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."messages_backup"
    ADD CONSTRAINT "messages_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."notifications"
    ADD CONSTRAINT "notifications_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."partner_vehicle_applications"
    ADD CONSTRAINT "partner_vehicle_applications_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."partner_vehicle_documents"
    ADD CONSTRAINT "partner_vehicle_documents_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."partner_vehicles"
    ADD CONSTRAINT "partner_vehicles_partner_id_id_uniq" UNIQUE ("partner_id", "id");



ALTER TABLE ONLY "public"."partner_vehicles"
    ADD CONSTRAINT "partner_vehicles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."partners"
    ADD CONSTRAINT "partners_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."ratings_backup"
    ADD CONSTRAINT "ratings_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."renter_documents"
    ADD CONSTRAINT "renter_documents_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."renter_documents"
    ADD CONSTRAINT "renter_documents_renter_id_document_type_document_url_key" UNIQUE ("renter_id", "document_type", "document_url");



ALTER TABLE ONLY "public"."renters"
    ADD CONSTRAINT "renters_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."renters"
    ADD CONSTRAINT "renters_user_id_key" UNIQUE ("user_id");



ALTER TABLE ONLY "public"."transactions"
    ADD CONSTRAINT "transactions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."user_documents"
    ADD CONSTRAINT "user_documents_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."user_verifications"
    ADD CONSTRAINT "user_verifications_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."user_verifications"
    ADD CONSTRAINT "user_verifications_user_id_key" UNIQUE ("user_id");



ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "users_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."vehicle_applications"
    ADD CONSTRAINT "vehicle_applications_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."vehicle_availability_backup"
    ADD CONSTRAINT "vehicle_availability_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."vehicle_documents"
    ADD CONSTRAINT "vehicle_documents_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."vehicle_images"
    ADD CONSTRAINT "vehicle_images_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."vehicles"
    ADD CONSTRAINT "vehicles_pkey" PRIMARY KEY ("id");



CREATE INDEX "bookings_operator_id_idx" ON "public"."bookings" USING "btree" ("operator_id");



CREATE INDEX "idx_availability_driver_id" ON "public"."driver_availability_schedule" USING "btree" ("driver_id");



CREATE INDEX "idx_bookings_completed_at" ON "public"."bookings" USING "btree" ("completed_at");



CREATE INDEX "idx_bookings_driver_id" ON "public"."bookings" USING "btree" ("driver_id");



CREATE INDEX "idx_bookings_end_at" ON "public"."bookings" USING "btree" ("end_at");



CREATE INDEX "idx_bookings_end_date" ON "public"."bookings" USING "btree" ("end_date");



CREATE INDEX "idx_bookings_picked_up_at" ON "public"."bookings" USING "btree" ("picked_up_at");



CREATE INDEX "idx_bookings_renter_id" ON "public"."bookings" USING "btree" ("renter_id");



CREATE INDEX "idx_bookings_returned_at" ON "public"."bookings" USING "btree" ("returned_at");



CREATE INDEX "idx_bookings_start_at" ON "public"."bookings" USING "btree" ("start_at");



CREATE INDEX "idx_bookings_start_date" ON "public"."bookings" USING "btree" ("start_date");



CREATE INDEX "idx_bookings_status" ON "public"."bookings" USING "btree" ("status");



CREATE INDEX "idx_bookings_vehicle_id" ON "public"."bookings" USING "btree" ("vehicle_id");



CREATE INDEX "idx_bookings_with_driver" ON "public"."bookings" USING "btree" ("with_driver");



CREATE INDEX "idx_bookmarks_user_id" ON "public"."bookmarks" USING "btree" ("user_id");



CREATE INDEX "idx_bookmarks_vehicle_id" ON "public"."bookmarks" USING "btree" ("vehicle_id");



CREATE INDEX "idx_conversations_booking_id" ON "public"."conversations" USING "btree" ("booking_id");



CREATE INDEX "idx_driver_docs_driver_id" ON "public"."driver_documents" USING "btree" ("driver_id");



CREATE INDEX "idx_driver_docs_type" ON "public"."driver_documents" USING "btree" ("document_type");



CREATE INDEX "idx_driver_documents_driver_id" ON "public"."driver_documents" USING "btree" ("driver_id");



CREATE INDEX "idx_driver_documents_status" ON "public"."driver_documents" USING "btree" ("status");



CREATE INDEX "idx_driver_trips_booking_id" ON "public"."driver_trips" USING "btree" ("booking_id");



CREATE INDEX "idx_driver_trips_driver_id" ON "public"."driver_trips" USING "btree" ("driver_id");



CREATE INDEX "idx_drivers_tier" ON "public"."drivers" USING "btree" ("driver_tier");



CREATE INDEX "idx_drivers_user_id" ON "public"."drivers" USING "btree" ("user_id");



CREATE INDEX "idx_drivers_verification_status" ON "public"."drivers" USING "btree" ("verification_status");



CREATE INDEX "idx_earnings_driver_id" ON "public"."driver_earnings" USING "btree" ("driver_id");



CREATE INDEX "idx_earnings_payout_status" ON "public"."driver_earnings" USING "btree" ("payout_status");



CREATE INDEX "idx_filter_words_created_at" ON "public"."filter_words" USING "btree" ("created_at" DESC);



CREATE INDEX "idx_filter_words_word" ON "public"."filter_words" USING "btree" ("word");



CREATE INDEX "idx_job_assignments_booking_id" ON "public"."driver_job_assignments" USING "btree" ("booking_id");



CREATE INDEX "idx_job_assignments_driver_id" ON "public"."driver_job_assignments" USING "btree" ("driver_id");



CREATE INDEX "idx_job_assignments_status" ON "public"."driver_job_assignments" USING "btree" ("status");



CREATE INDEX "idx_message_flags_created_at" ON "public"."message_flags" USING "btree" ("created_at" DESC);



CREATE INDEX "idx_message_flags_sender_id" ON "public"."message_flags" USING "btree" ("sender_id");



CREATE INDEX "idx_message_flags_status" ON "public"."message_flags" USING "btree" ("status");



CREATE INDEX "idx_messages_auto_generated" ON "public"."messages" USING "btree" ("is_auto_generated") WHERE ("is_auto_generated" = true);



CREATE INDEX "idx_messages_conversation_id" ON "public"."messages" USING "btree" ("conversation_id");



CREATE INDEX "idx_notifications_user_created" ON "public"."notifications" USING "btree" ("user_id", "created_at" DESC);



CREATE INDEX "idx_notifications_user_unread" ON "public"."notifications" USING "btree" ("user_id", "is_read");



CREATE INDEX "idx_partner_vehicle_applications_application_status" ON "public"."partner_vehicle_applications" USING "btree" ("application_status");



CREATE INDEX "idx_partner_vehicle_applications_fuel_type" ON "public"."partner_vehicle_applications" USING "btree" ("fuel_type");



CREATE INDEX "idx_partner_vehicle_applications_partner_id" ON "public"."partner_vehicle_applications" USING "btree" ("partner_id");



CREATE INDEX "idx_partner_vehicles_fuel_type" ON "public"."partner_vehicles" USING "btree" ("fuel_type");



CREATE INDEX "idx_partner_vehicles_plate_number" ON "public"."partner_vehicles" USING "btree" ("plate_number");



CREATE INDEX "idx_partner_vehicles_vehicle_id" ON "public"."partner_vehicles" USING "btree" ("vehicle_id");



CREATE INDEX "idx_profiles_role" ON "public"."profiles" USING "btree" ("role");



CREATE INDEX "idx_tier_history_driver_id" ON "public"."driver_tier_history" USING "btree" ("driver_id");



CREATE INDEX "idx_user_documents_profile_id" ON "public"."user_documents" USING "btree" ("profile_id");



CREATE INDEX "idx_user_documents_status" ON "public"."user_documents" USING "btree" ("status");



CREATE INDEX "idx_user_verifications_created_at" ON "public"."user_verifications" USING "btree" ("created_at" DESC);



CREATE INDEX "idx_user_verifications_status" ON "public"."user_verifications" USING "btree" ("verification_status");



CREATE INDEX "idx_user_verifications_user_id" ON "public"."user_verifications" USING "btree" ("user_id");



CREATE INDEX "idx_users_application_status" ON "public"."users" USING "btree" ("application_status");



CREATE INDEX "idx_users_role" ON "public"."users" USING "btree" ("role");



CREATE INDEX "idx_vehicle_images_order" ON "public"."vehicle_images" USING "btree" ("vehicle_id", "display_order");



CREATE INDEX "idx_vehicle_images_vehicle_id" ON "public"."vehicle_images" USING "btree" ("vehicle_id");



CREATE INDEX "idx_vehicles_brand" ON "public"."vehicles" USING "btree" ("brand");



CREATE INDEX "idx_vehicles_category" ON "public"."vehicles" USING "btree" ("category");



CREATE INDEX "idx_vehicles_color" ON "public"."vehicles" USING "btree" ("color");



CREATE INDEX "idx_vehicles_fuel_type" ON "public"."vehicles" USING "btree" ("fuel_type");



CREATE INDEX "idx_vehicles_is_posted" ON "public"."vehicles" USING "btree" ("is_posted");



CREATE INDEX "idx_vehicles_latitude" ON "public"."vehicles" USING "btree" ("latitude");



CREATE INDEX "idx_vehicles_location" ON "public"."vehicles" USING "btree" ("location");



CREATE INDEX "idx_vehicles_longitude" ON "public"."vehicles" USING "btree" ("longitude");



CREATE INDEX "idx_vehicles_model" ON "public"."vehicles" USING "btree" ("model");



CREATE INDEX "idx_vehicles_operator_id" ON "public"."vehicles" USING "btree" ("operator_id");



CREATE INDEX "idx_vehicles_owner_id" ON "public"."vehicles" USING "btree" ("owner_id");



CREATE INDEX "idx_vehicles_price_per_day" ON "public"."vehicles" USING "btree" ("price_per_day");



CREATE INDEX "idx_vehicles_price_per_hour" ON "public"."vehicles" USING "btree" ("price_per_hour");



CREATE INDEX "idx_vehicles_status_available" ON "public"."vehicles" USING "btree" ("status", "is_available");



CREATE INDEX "idx_vehicles_transmission" ON "public"."vehicles" USING "btree" ("transmission");



CREATE INDEX "idx_vehicles_vehicle_name" ON "public"."vehicles" USING "btree" ("vehicle_name");



CREATE INDEX "idx_vehicles_vehicle_type" ON "public"."vehicles" USING "btree" ("vehicle_type");



CREATE INDEX "partner_vehicle_applications_partner_id_idx" ON "public"."partner_vehicle_applications" USING "btree" ("partner_id");



CREATE INDEX "partner_vehicle_applications_vehicle_id_idx" ON "public"."partner_vehicle_applications" USING "btree" ("partner_vehicle_id");



CREATE INDEX "partner_vehicle_documents_application_id_idx" ON "public"."partner_vehicle_documents" USING "btree" ("partner_vehicle_application_id");



CREATE OR REPLACE TRIGGER "prevent_overlapping_bookings_trigger" BEFORE INSERT OR UPDATE OF "vehicle_id", "start_at", "end_at", "status" ON "public"."bookings" FOR EACH ROW EXECUTE FUNCTION "public"."prevent_overlapping_bookings"();



CREATE OR REPLACE TRIGGER "set_updated_at_renter_documents" BEFORE UPDATE ON "public"."renter_documents" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "set_updated_at_user_documents" BEFORE UPDATE ON "public"."user_documents" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trigger_sync_user_verification_status" AFTER INSERT OR UPDATE ON "public"."user_verifications" FOR EACH ROW EXECUTE FUNCTION "public"."sync_user_verification_status"();



ALTER TABLE ONLY "public"."bookings"
    ADD CONSTRAINT "bookings_driver_id_fkey" FOREIGN KEY ("driver_id") REFERENCES "public"."drivers"("user_id");



ALTER TABLE ONLY "public"."bookings"
    ADD CONSTRAINT "bookings_operator_id_fkey" FOREIGN KEY ("operator_id") REFERENCES "public"."users"("id") ON UPDATE CASCADE;



ALTER TABLE ONLY "public"."bookings"
    ADD CONSTRAINT "bookings_renter_id_fkey" FOREIGN KEY ("renter_id") REFERENCES "public"."users"("id");



ALTER TABLE ONLY "public"."bookings"
    ADD CONSTRAINT "bookings_vehicle_id_fkey" FOREIGN KEY ("vehicle_id") REFERENCES "public"."vehicles"("id");



ALTER TABLE ONLY "public"."bookmarks"
    ADD CONSTRAINT "bookmarks_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."bookmarks"
    ADD CONSTRAINT "bookmarks_vehicle_id_fkey" FOREIGN KEY ("vehicle_id") REFERENCES "public"."vehicles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."conversation_participants"
    ADD CONSTRAINT "conversation_participants_new_conversation_id_fkey" FOREIGN KEY ("conversation_id") REFERENCES "public"."conversations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."conversation_participants"
    ADD CONSTRAINT "conversation_participants_new_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."conversations"
    ADD CONSTRAINT "conversations_booking_id_fkey" FOREIGN KEY ("booking_id") REFERENCES "public"."bookings"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."conversations"
    ADD CONSTRAINT "conversations_other_user_id_fkey" FOREIGN KEY ("other_user_id") REFERENCES "public"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."conversations_backup"
    ADD CONSTRAINT "conversations_user1_id_fkey" FOREIGN KEY ("user1_id") REFERENCES "public"."users"("id");



ALTER TABLE ONLY "public"."conversations_backup"
    ADD CONSTRAINT "conversations_user2_id_fkey" FOREIGN KEY ("user2_id") REFERENCES "public"."users"("id");



ALTER TABLE ONLY "public"."conversations"
    ADD CONSTRAINT "conversations_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."driver_availability_schedule"
    ADD CONSTRAINT "driver_availability_schedule_driver_id_fkey" FOREIGN KEY ("driver_id") REFERENCES "public"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."driver_documents"
    ADD CONSTRAINT "driver_documents_driver_id_fkey" FOREIGN KEY ("driver_id") REFERENCES "public"."drivers"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."driver_documents"
    ADD CONSTRAINT "driver_documents_verified_by_fkey" FOREIGN KEY ("verified_by") REFERENCES "public"."users"("id");



ALTER TABLE ONLY "public"."driver_earnings"
    ADD CONSTRAINT "driver_earnings_driver_id_fkey" FOREIGN KEY ("driver_id") REFERENCES "public"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."driver_earnings"
    ADD CONSTRAINT "driver_earnings_trip_id_fkey" FOREIGN KEY ("trip_id") REFERENCES "public"."driver_trips"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."driver_job_assignments"
    ADD CONSTRAINT "driver_job_assignments_booking_id_fkey" FOREIGN KEY ("booking_id") REFERENCES "public"."bookings"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."driver_job_assignments"
    ADD CONSTRAINT "driver_job_assignments_driver_id_fkey" FOREIGN KEY ("driver_id") REFERENCES "public"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."driver_tier_history"
    ADD CONSTRAINT "driver_tier_history_driver_id_fkey" FOREIGN KEY ("driver_id") REFERENCES "public"."drivers"("user_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."driver_trips"
    ADD CONSTRAINT "driver_trips_booking_id_fkey" FOREIGN KEY ("booking_id") REFERENCES "public"."bookings"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."driver_trips"
    ADD CONSTRAINT "driver_trips_driver_id_fkey" FOREIGN KEY ("driver_id") REFERENCES "public"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."drivers"
    ADD CONSTRAINT "drivers_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."filter_words"
    ADD CONSTRAINT "filter_words_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."message_flags"
    ADD CONSTRAINT "message_flags_conversation_id_fkey" FOREIGN KEY ("conversation_id") REFERENCES "public"."conversations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."message_flags"
    ADD CONSTRAINT "message_flags_sender_id_fkey" FOREIGN KEY ("sender_id") REFERENCES "public"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."messages_backup"
    ADD CONSTRAINT "messages_booking_id_fkey" FOREIGN KEY ("booking_id") REFERENCES "public"."bookings"("id");



ALTER TABLE ONLY "public"."messages"
    ADD CONSTRAINT "messages_conversation_id_fkey" FOREIGN KEY ("conversation_id") REFERENCES "public"."conversations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."messages"
    ADD CONSTRAINT "messages_new_booking_id_fkey" FOREIGN KEY ("booking_id") REFERENCES "public"."bookings"("id");



ALTER TABLE ONLY "public"."messages"
    ADD CONSTRAINT "messages_new_conversation_id_fkey" FOREIGN KEY ("conversation_id") REFERENCES "public"."conversations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."messages"
    ADD CONSTRAINT "messages_new_sender_id_fkey" FOREIGN KEY ("sender_id") REFERENCES "public"."users"("id");



ALTER TABLE ONLY "public"."messages_backup"
    ADD CONSTRAINT "messages_receiver_id_fkey" FOREIGN KEY ("receiver_id") REFERENCES "public"."users"("id");



ALTER TABLE ONLY "public"."messages_backup"
    ADD CONSTRAINT "messages_sender_id_fkey" FOREIGN KEY ("sender_id") REFERENCES "public"."users"("id");



ALTER TABLE ONLY "public"."notifications"
    ADD CONSTRAINT "notifications_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id");



ALTER TABLE ONLY "public"."partner_vehicle_applications"
    ADD CONSTRAINT "partner_vehicle_applications_partner_id_fkey" FOREIGN KEY ("partner_id") REFERENCES "public"."users"("id");



ALTER TABLE ONLY "public"."partner_vehicle_applications"
    ADD CONSTRAINT "partner_vehicle_applications_partner_vehicle_fk" FOREIGN KEY ("partner_id", "partner_vehicle_id") REFERENCES "public"."partner_vehicles"("partner_id", "id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."partner_vehicle_applications"
    ADD CONSTRAINT "partner_vehicle_applications_verified_by_fkey" FOREIGN KEY ("verified_by") REFERENCES "public"."users"("id");



ALTER TABLE ONLY "public"."partner_vehicle_documents"
    ADD CONSTRAINT "partner_vehicle_documents_partner_vehicle_application_id_fkey" FOREIGN KEY ("partner_vehicle_application_id") REFERENCES "public"."partner_vehicle_applications"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."partner_vehicles"
    ADD CONSTRAINT "partner_vehicles_partner_id_fkey" FOREIGN KEY ("partner_id") REFERENCES "public"."partners"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."partner_vehicles"
    ADD CONSTRAINT "partner_vehicles_vehicle_id_fkey" FOREIGN KEY ("vehicle_id") REFERENCES "public"."vehicles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."partners"
    ADD CONSTRAINT "partners_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_id_fkey" FOREIGN KEY ("id") REFERENCES "public"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."ratings_backup"
    ADD CONSTRAINT "ratings_booking_id_fkey" FOREIGN KEY ("booking_id") REFERENCES "public"."bookings"("id");



ALTER TABLE ONLY "public"."ratings_backup"
    ADD CONSTRAINT "ratings_renter_id_fkey" FOREIGN KEY ("renter_id") REFERENCES "public"."users"("id");



ALTER TABLE ONLY "public"."renter_documents"
    ADD CONSTRAINT "renter_documents_renter_id_fkey" FOREIGN KEY ("renter_id") REFERENCES "public"."renters"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."renter_documents"
    ADD CONSTRAINT "renter_documents_reviewer_id_fkey" FOREIGN KEY ("reviewer_id") REFERENCES "public"."users"("id");



ALTER TABLE ONLY "public"."renters"
    ADD CONSTRAINT "renters_id_fkey" FOREIGN KEY ("id") REFERENCES "public"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."renters"
    ADD CONSTRAINT "renters_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id");



ALTER TABLE ONLY "public"."transactions"
    ADD CONSTRAINT "transactions_booking_id_fkey" FOREIGN KEY ("booking_id") REFERENCES "public"."bookings"("id");



ALTER TABLE ONLY "public"."user_documents"
    ADD CONSTRAINT "user_documents_profile_id_fkey" FOREIGN KEY ("profile_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_documents"
    ADD CONSTRAINT "user_documents_reviewer_id_fkey" FOREIGN KEY ("reviewer_id") REFERENCES "public"."users"("id");



ALTER TABLE ONLY "public"."user_verifications"
    ADD CONSTRAINT "user_verifications_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_verifications"
    ADD CONSTRAINT "user_verifications_verified_by_fkey" FOREIGN KEY ("verified_by") REFERENCES "public"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "users_id_fkey" FOREIGN KEY ("id") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."vehicle_applications"
    ADD CONSTRAINT "vehicle_applications_partner_id_fkey" FOREIGN KEY ("partner_id") REFERENCES "public"."partners"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."vehicle_applications"
    ADD CONSTRAINT "vehicle_applications_verified_by_fkey" FOREIGN KEY ("verified_by") REFERENCES "public"."users"("id");



ALTER TABLE ONLY "public"."vehicle_availability_backup"
    ADD CONSTRAINT "vehicle_availability_vehicle_id_fkey" FOREIGN KEY ("vehicle_id") REFERENCES "public"."vehicles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."vehicle_documents"
    ADD CONSTRAINT "vehicle_documents_vehicle_application_id_fkey" FOREIGN KEY ("vehicle_application_id") REFERENCES "public"."vehicle_applications"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."vehicle_images"
    ADD CONSTRAINT "vehicle_images_vehicle_id_fkey" FOREIGN KEY ("vehicle_id") REFERENCES "public"."vehicles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."vehicles"
    ADD CONSTRAINT "vehicles_operator_id_fkey" FOREIGN KEY ("operator_id") REFERENCES "public"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."vehicles"
    ADD CONSTRAINT "vehicles_owner_id_fkey" FOREIGN KEY ("owner_id") REFERENCES "public"."users"("id");



ALTER TABLE "public"."partner_vehicle_applications" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "partner_vehicle_applications_insert_own" ON "public"."partner_vehicle_applications" FOR INSERT TO "authenticated" WITH CHECK (("partner_id" = "auth"."uid"()));



CREATE POLICY "partner_vehicle_applications_select_admin_all" ON "public"."partner_vehicle_applications" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."users"
  WHERE (("users"."id" = "auth"."uid"()) AND ("users"."role" = 'admin'::"text")))));



CREATE POLICY "partner_vehicle_applications_select_own" ON "public"."partner_vehicle_applications" FOR SELECT TO "authenticated" USING (("partner_id" = "auth"."uid"()));



CREATE POLICY "partner_vehicle_applications_update_admin_all" ON "public"."partner_vehicle_applications" FOR UPDATE TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."users"
  WHERE (("users"."id" = "auth"."uid"()) AND ("users"."role" = 'admin'::"text"))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."users"
  WHERE (("users"."id" = "auth"."uid"()) AND ("users"."role" = 'admin'::"text")))));



CREATE POLICY "partner_vehicle_applications_update_own" ON "public"."partner_vehicle_applications" FOR UPDATE TO "authenticated" USING (("partner_id" = "auth"."uid"())) WITH CHECK (("partner_id" = "auth"."uid"()));



ALTER TABLE "public"."partner_vehicle_documents" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "partner_vehicle_documents_insert_admin_all" ON "public"."partner_vehicle_documents" FOR INSERT TO "authenticated" WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."users"
  WHERE (("users"."id" = "auth"."uid"()) AND ("users"."role" = 'admin'::"text")))));



CREATE POLICY "partner_vehicle_documents_select_admin_all" ON "public"."partner_vehicle_documents" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."users"
  WHERE (("users"."id" = "auth"."uid"()) AND ("users"."role" = 'admin'::"text")))));





ALTER PUBLICATION "supabase_realtime" OWNER TO "postgres";






ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."users";



GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_in"("cstring", "oid", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_in"("cstring", "oid", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_in"("cstring", "oid", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_in"("cstring", "oid", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_out"("public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_out"("public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_out"("public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_out"("public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_recv"("internal", "oid", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_recv"("internal", "oid", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_recv"("internal", "oid", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_recv"("internal", "oid", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_send"("public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_send"("public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_send"("public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_send"("public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_typmod_in"("cstring"[]) TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_typmod_in"("cstring"[]) TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_typmod_in"("cstring"[]) TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_typmod_in"("cstring"[]) TO "service_role";



GRANT ALL ON FUNCTION "public"."sparsevec_in"("cstring", "oid", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."sparsevec_in"("cstring", "oid", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."sparsevec_in"("cstring", "oid", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."sparsevec_in"("cstring", "oid", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."sparsevec_out"("public"."sparsevec") TO "postgres";
GRANT ALL ON FUNCTION "public"."sparsevec_out"("public"."sparsevec") TO "anon";
GRANT ALL ON FUNCTION "public"."sparsevec_out"("public"."sparsevec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sparsevec_out"("public"."sparsevec") TO "service_role";



GRANT ALL ON FUNCTION "public"."sparsevec_recv"("internal", "oid", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."sparsevec_recv"("internal", "oid", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."sparsevec_recv"("internal", "oid", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."sparsevec_recv"("internal", "oid", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."sparsevec_send"("public"."sparsevec") TO "postgres";
GRANT ALL ON FUNCTION "public"."sparsevec_send"("public"."sparsevec") TO "anon";
GRANT ALL ON FUNCTION "public"."sparsevec_send"("public"."sparsevec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sparsevec_send"("public"."sparsevec") TO "service_role";



GRANT ALL ON FUNCTION "public"."sparsevec_typmod_in"("cstring"[]) TO "postgres";
GRANT ALL ON FUNCTION "public"."sparsevec_typmod_in"("cstring"[]) TO "anon";
GRANT ALL ON FUNCTION "public"."sparsevec_typmod_in"("cstring"[]) TO "authenticated";
GRANT ALL ON FUNCTION "public"."sparsevec_typmod_in"("cstring"[]) TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_in"("cstring", "oid", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_in"("cstring", "oid", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."vector_in"("cstring", "oid", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_in"("cstring", "oid", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_out"("public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_out"("public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_out"("public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_out"("public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_recv"("internal", "oid", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_recv"("internal", "oid", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."vector_recv"("internal", "oid", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_recv"("internal", "oid", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_send"("public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_send"("public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_send"("public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_send"("public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_typmod_in"("cstring"[]) TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_typmod_in"("cstring"[]) TO "anon";
GRANT ALL ON FUNCTION "public"."vector_typmod_in"("cstring"[]) TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_typmod_in"("cstring"[]) TO "service_role";



GRANT ALL ON FUNCTION "public"."array_to_halfvec"(real[], integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."array_to_halfvec"(real[], integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."array_to_halfvec"(real[], integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."array_to_halfvec"(real[], integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."array_to_sparsevec"(real[], integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."array_to_sparsevec"(real[], integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."array_to_sparsevec"(real[], integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."array_to_sparsevec"(real[], integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."array_to_vector"(real[], integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."array_to_vector"(real[], integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."array_to_vector"(real[], integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."array_to_vector"(real[], integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."array_to_halfvec"(double precision[], integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."array_to_halfvec"(double precision[], integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."array_to_halfvec"(double precision[], integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."array_to_halfvec"(double precision[], integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."array_to_sparsevec"(double precision[], integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."array_to_sparsevec"(double precision[], integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."array_to_sparsevec"(double precision[], integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."array_to_sparsevec"(double precision[], integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."array_to_vector"(double precision[], integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."array_to_vector"(double precision[], integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."array_to_vector"(double precision[], integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."array_to_vector"(double precision[], integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."array_to_halfvec"(integer[], integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."array_to_halfvec"(integer[], integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."array_to_halfvec"(integer[], integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."array_to_halfvec"(integer[], integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."array_to_sparsevec"(integer[], integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."array_to_sparsevec"(integer[], integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."array_to_sparsevec"(integer[], integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."array_to_sparsevec"(integer[], integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."array_to_vector"(integer[], integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."array_to_vector"(integer[], integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."array_to_vector"(integer[], integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."array_to_vector"(integer[], integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."array_to_halfvec"(numeric[], integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."array_to_halfvec"(numeric[], integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."array_to_halfvec"(numeric[], integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."array_to_halfvec"(numeric[], integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."array_to_sparsevec"(numeric[], integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."array_to_sparsevec"(numeric[], integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."array_to_sparsevec"(numeric[], integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."array_to_sparsevec"(numeric[], integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."array_to_vector"(numeric[], integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."array_to_vector"(numeric[], integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."array_to_vector"(numeric[], integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."array_to_vector"(numeric[], integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_to_float4"("public"."halfvec", integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_to_float4"("public"."halfvec", integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_to_float4"("public"."halfvec", integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_to_float4"("public"."halfvec", integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec"("public"."halfvec", integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec"("public"."halfvec", integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec"("public"."halfvec", integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec"("public"."halfvec", integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_to_sparsevec"("public"."halfvec", integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_to_sparsevec"("public"."halfvec", integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_to_sparsevec"("public"."halfvec", integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_to_sparsevec"("public"."halfvec", integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_to_vector"("public"."halfvec", integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_to_vector"("public"."halfvec", integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_to_vector"("public"."halfvec", integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_to_vector"("public"."halfvec", integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."sparsevec_to_halfvec"("public"."sparsevec", integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."sparsevec_to_halfvec"("public"."sparsevec", integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."sparsevec_to_halfvec"("public"."sparsevec", integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."sparsevec_to_halfvec"("public"."sparsevec", integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."sparsevec"("public"."sparsevec", integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."sparsevec"("public"."sparsevec", integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."sparsevec"("public"."sparsevec", integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."sparsevec"("public"."sparsevec", integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."sparsevec_to_vector"("public"."sparsevec", integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."sparsevec_to_vector"("public"."sparsevec", integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."sparsevec_to_vector"("public"."sparsevec", integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."sparsevec_to_vector"("public"."sparsevec", integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_to_float4"("public"."vector", integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_to_float4"("public"."vector", integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."vector_to_float4"("public"."vector", integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_to_float4"("public"."vector", integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_to_halfvec"("public"."vector", integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_to_halfvec"("public"."vector", integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."vector_to_halfvec"("public"."vector", integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_to_halfvec"("public"."vector", integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_to_sparsevec"("public"."vector", integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_to_sparsevec"("public"."vector", integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."vector_to_sparsevec"("public"."vector", integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_to_sparsevec"("public"."vector", integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."vector"("public"."vector", integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."vector"("public"."vector", integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."vector"("public"."vector", integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector"("public"."vector", integer, boolean) TO "service_role";






















































































































































GRANT ALL ON FUNCTION "public"."binary_quantize"("public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."binary_quantize"("public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."binary_quantize"("public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."binary_quantize"("public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."binary_quantize"("public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."binary_quantize"("public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."binary_quantize"("public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."binary_quantize"("public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."cosine_distance"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."cosine_distance"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."cosine_distance"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."cosine_distance"("public"."halfvec", "public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."cosine_distance"("public"."sparsevec", "public"."sparsevec") TO "postgres";
GRANT ALL ON FUNCTION "public"."cosine_distance"("public"."sparsevec", "public"."sparsevec") TO "anon";
GRANT ALL ON FUNCTION "public"."cosine_distance"("public"."sparsevec", "public"."sparsevec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."cosine_distance"("public"."sparsevec", "public"."sparsevec") TO "service_role";



GRANT ALL ON FUNCTION "public"."cosine_distance"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."cosine_distance"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."cosine_distance"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."cosine_distance"("public"."vector", "public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_operator_booking_vehicles"("p_vehicle_ids" "uuid"[]) TO "anon";
GRANT ALL ON FUNCTION "public"."get_operator_booking_vehicles"("p_vehicle_ids" "uuid"[]) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_operator_booking_vehicles"("p_vehicle_ids" "uuid"[]) TO "service_role";



GRANT ALL ON TABLE "public"."bookings" TO "anon";
GRANT ALL ON TABLE "public"."bookings" TO "authenticated";
GRANT ALL ON TABLE "public"."bookings" TO "service_role";



GRANT ALL ON FUNCTION "public"."get_operator_bookings"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_operator_bookings"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_operator_bookings"() TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_accum"(double precision[], "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_accum"(double precision[], "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_accum"(double precision[], "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_accum"(double precision[], "public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_add"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_add"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_add"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_add"("public"."halfvec", "public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_avg"(double precision[]) TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_avg"(double precision[]) TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_avg"(double precision[]) TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_avg"(double precision[]) TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_cmp"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_cmp"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_cmp"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_cmp"("public"."halfvec", "public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_combine"(double precision[], double precision[]) TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_combine"(double precision[], double precision[]) TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_combine"(double precision[], double precision[]) TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_combine"(double precision[], double precision[]) TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_concat"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_concat"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_concat"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_concat"("public"."halfvec", "public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_eq"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_eq"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_eq"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_eq"("public"."halfvec", "public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_ge"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_ge"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_ge"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_ge"("public"."halfvec", "public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_gt"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_gt"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_gt"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_gt"("public"."halfvec", "public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_l2_squared_distance"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_l2_squared_distance"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_l2_squared_distance"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_l2_squared_distance"("public"."halfvec", "public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_le"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_le"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_le"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_le"("public"."halfvec", "public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_lt"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_lt"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_lt"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_lt"("public"."halfvec", "public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_mul"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_mul"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_mul"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_mul"("public"."halfvec", "public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_ne"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_ne"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_ne"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_ne"("public"."halfvec", "public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_negative_inner_product"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_negative_inner_product"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_negative_inner_product"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_negative_inner_product"("public"."halfvec", "public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_spherical_distance"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_spherical_distance"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_spherical_distance"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_spherical_distance"("public"."halfvec", "public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_sub"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_sub"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_sub"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_sub"("public"."halfvec", "public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."hamming_distance"(bit, bit) TO "postgres";
GRANT ALL ON FUNCTION "public"."hamming_distance"(bit, bit) TO "anon";
GRANT ALL ON FUNCTION "public"."hamming_distance"(bit, bit) TO "authenticated";
GRANT ALL ON FUNCTION "public"."hamming_distance"(bit, bit) TO "service_role";



GRANT ALL ON FUNCTION "public"."handle_new_auth_user"() TO "anon";
GRANT ALL ON FUNCTION "public"."handle_new_auth_user"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_new_auth_user"() TO "service_role";



GRANT ALL ON FUNCTION "public"."hnsw_bit_support"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."hnsw_bit_support"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."hnsw_bit_support"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."hnsw_bit_support"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."hnsw_halfvec_support"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."hnsw_halfvec_support"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."hnsw_halfvec_support"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."hnsw_halfvec_support"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."hnsw_sparsevec_support"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."hnsw_sparsevec_support"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."hnsw_sparsevec_support"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."hnsw_sparsevec_support"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."hnswhandler"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."hnswhandler"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."hnswhandler"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."hnswhandler"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."inner_product"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."inner_product"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."inner_product"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."inner_product"("public"."halfvec", "public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."inner_product"("public"."sparsevec", "public"."sparsevec") TO "postgres";
GRANT ALL ON FUNCTION "public"."inner_product"("public"."sparsevec", "public"."sparsevec") TO "anon";
GRANT ALL ON FUNCTION "public"."inner_product"("public"."sparsevec", "public"."sparsevec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."inner_product"("public"."sparsevec", "public"."sparsevec") TO "service_role";



GRANT ALL ON FUNCTION "public"."inner_product"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."inner_product"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."inner_product"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."inner_product"("public"."vector", "public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."is_admin_user"() TO "anon";
GRANT ALL ON FUNCTION "public"."is_admin_user"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_admin_user"() TO "service_role";



GRANT ALL ON FUNCTION "public"."is_assigned_driver_for_vehicle"("p_vehicle_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."is_assigned_driver_for_vehicle"("p_vehicle_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_assigned_driver_for_vehicle"("p_vehicle_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."is_operator_user"() TO "anon";
GRANT ALL ON FUNCTION "public"."is_operator_user"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_operator_user"() TO "service_role";



GRANT ALL ON FUNCTION "public"."is_user_blocked"("user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."is_user_blocked"("user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_user_blocked"("user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."is_vehicle_available_for_booking"("p_vehicle_id" "uuid", "p_start_date" timestamp with time zone, "p_end_date" timestamp with time zone, "p_exclude_booking_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."is_vehicle_available_for_booking"("p_vehicle_id" "uuid", "p_start_date" timestamp with time zone, "p_end_date" timestamp with time zone, "p_exclude_booking_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_vehicle_available_for_booking"("p_vehicle_id" "uuid", "p_start_date" timestamp with time zone, "p_end_date" timestamp with time zone, "p_exclude_booking_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."is_vehicle_operator"("vehicle_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."is_vehicle_operator"("vehicle_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_vehicle_operator"("vehicle_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."is_vehicle_owner"("vehicle_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."is_vehicle_owner"("vehicle_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_vehicle_owner"("vehicle_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."ivfflat_bit_support"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."ivfflat_bit_support"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."ivfflat_bit_support"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."ivfflat_bit_support"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."ivfflat_halfvec_support"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."ivfflat_halfvec_support"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."ivfflat_halfvec_support"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."ivfflat_halfvec_support"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."ivfflathandler"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."ivfflathandler"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."ivfflathandler"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."ivfflathandler"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."jaccard_distance"(bit, bit) TO "postgres";
GRANT ALL ON FUNCTION "public"."jaccard_distance"(bit, bit) TO "anon";
GRANT ALL ON FUNCTION "public"."jaccard_distance"(bit, bit) TO "authenticated";
GRANT ALL ON FUNCTION "public"."jaccard_distance"(bit, bit) TO "service_role";



GRANT ALL ON FUNCTION "public"."l1_distance"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."l1_distance"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."l1_distance"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."l1_distance"("public"."halfvec", "public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."l1_distance"("public"."sparsevec", "public"."sparsevec") TO "postgres";
GRANT ALL ON FUNCTION "public"."l1_distance"("public"."sparsevec", "public"."sparsevec") TO "anon";
GRANT ALL ON FUNCTION "public"."l1_distance"("public"."sparsevec", "public"."sparsevec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."l1_distance"("public"."sparsevec", "public"."sparsevec") TO "service_role";



GRANT ALL ON FUNCTION "public"."l1_distance"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."l1_distance"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."l1_distance"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."l1_distance"("public"."vector", "public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."l2_distance"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."l2_distance"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."l2_distance"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."l2_distance"("public"."halfvec", "public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."l2_distance"("public"."sparsevec", "public"."sparsevec") TO "postgres";
GRANT ALL ON FUNCTION "public"."l2_distance"("public"."sparsevec", "public"."sparsevec") TO "anon";
GRANT ALL ON FUNCTION "public"."l2_distance"("public"."sparsevec", "public"."sparsevec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."l2_distance"("public"."sparsevec", "public"."sparsevec") TO "service_role";



GRANT ALL ON FUNCTION "public"."l2_distance"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."l2_distance"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."l2_distance"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."l2_distance"("public"."vector", "public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."l2_norm"("public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."l2_norm"("public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."l2_norm"("public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."l2_norm"("public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."l2_norm"("public"."sparsevec") TO "postgres";
GRANT ALL ON FUNCTION "public"."l2_norm"("public"."sparsevec") TO "anon";
GRANT ALL ON FUNCTION "public"."l2_norm"("public"."sparsevec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."l2_norm"("public"."sparsevec") TO "service_role";



GRANT ALL ON FUNCTION "public"."l2_normalize"("public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."l2_normalize"("public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."l2_normalize"("public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."l2_normalize"("public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."l2_normalize"("public"."sparsevec") TO "postgres";
GRANT ALL ON FUNCTION "public"."l2_normalize"("public"."sparsevec") TO "anon";
GRANT ALL ON FUNCTION "public"."l2_normalize"("public"."sparsevec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."l2_normalize"("public"."sparsevec") TO "service_role";



GRANT ALL ON FUNCTION "public"."l2_normalize"("public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."l2_normalize"("public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."l2_normalize"("public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."l2_normalize"("public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."prevent_overlapping_bookings"() TO "anon";
GRANT ALL ON FUNCTION "public"."prevent_overlapping_bookings"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."prevent_overlapping_bookings"() TO "service_role";



GRANT ALL ON FUNCTION "public"."set_updated_at"() TO "anon";
GRANT ALL ON FUNCTION "public"."set_updated_at"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_updated_at"() TO "service_role";



GRANT ALL ON FUNCTION "public"."sparsevec_cmp"("public"."sparsevec", "public"."sparsevec") TO "postgres";
GRANT ALL ON FUNCTION "public"."sparsevec_cmp"("public"."sparsevec", "public"."sparsevec") TO "anon";
GRANT ALL ON FUNCTION "public"."sparsevec_cmp"("public"."sparsevec", "public"."sparsevec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sparsevec_cmp"("public"."sparsevec", "public"."sparsevec") TO "service_role";



GRANT ALL ON FUNCTION "public"."sparsevec_eq"("public"."sparsevec", "public"."sparsevec") TO "postgres";
GRANT ALL ON FUNCTION "public"."sparsevec_eq"("public"."sparsevec", "public"."sparsevec") TO "anon";
GRANT ALL ON FUNCTION "public"."sparsevec_eq"("public"."sparsevec", "public"."sparsevec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sparsevec_eq"("public"."sparsevec", "public"."sparsevec") TO "service_role";



GRANT ALL ON FUNCTION "public"."sparsevec_ge"("public"."sparsevec", "public"."sparsevec") TO "postgres";
GRANT ALL ON FUNCTION "public"."sparsevec_ge"("public"."sparsevec", "public"."sparsevec") TO "anon";
GRANT ALL ON FUNCTION "public"."sparsevec_ge"("public"."sparsevec", "public"."sparsevec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sparsevec_ge"("public"."sparsevec", "public"."sparsevec") TO "service_role";



GRANT ALL ON FUNCTION "public"."sparsevec_gt"("public"."sparsevec", "public"."sparsevec") TO "postgres";
GRANT ALL ON FUNCTION "public"."sparsevec_gt"("public"."sparsevec", "public"."sparsevec") TO "anon";
GRANT ALL ON FUNCTION "public"."sparsevec_gt"("public"."sparsevec", "public"."sparsevec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sparsevec_gt"("public"."sparsevec", "public"."sparsevec") TO "service_role";



GRANT ALL ON FUNCTION "public"."sparsevec_l2_squared_distance"("public"."sparsevec", "public"."sparsevec") TO "postgres";
GRANT ALL ON FUNCTION "public"."sparsevec_l2_squared_distance"("public"."sparsevec", "public"."sparsevec") TO "anon";
GRANT ALL ON FUNCTION "public"."sparsevec_l2_squared_distance"("public"."sparsevec", "public"."sparsevec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sparsevec_l2_squared_distance"("public"."sparsevec", "public"."sparsevec") TO "service_role";



GRANT ALL ON FUNCTION "public"."sparsevec_le"("public"."sparsevec", "public"."sparsevec") TO "postgres";
GRANT ALL ON FUNCTION "public"."sparsevec_le"("public"."sparsevec", "public"."sparsevec") TO "anon";
GRANT ALL ON FUNCTION "public"."sparsevec_le"("public"."sparsevec", "public"."sparsevec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sparsevec_le"("public"."sparsevec", "public"."sparsevec") TO "service_role";



GRANT ALL ON FUNCTION "public"."sparsevec_lt"("public"."sparsevec", "public"."sparsevec") TO "postgres";
GRANT ALL ON FUNCTION "public"."sparsevec_lt"("public"."sparsevec", "public"."sparsevec") TO "anon";
GRANT ALL ON FUNCTION "public"."sparsevec_lt"("public"."sparsevec", "public"."sparsevec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sparsevec_lt"("public"."sparsevec", "public"."sparsevec") TO "service_role";



GRANT ALL ON FUNCTION "public"."sparsevec_ne"("public"."sparsevec", "public"."sparsevec") TO "postgres";
GRANT ALL ON FUNCTION "public"."sparsevec_ne"("public"."sparsevec", "public"."sparsevec") TO "anon";
GRANT ALL ON FUNCTION "public"."sparsevec_ne"("public"."sparsevec", "public"."sparsevec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sparsevec_ne"("public"."sparsevec", "public"."sparsevec") TO "service_role";



GRANT ALL ON FUNCTION "public"."sparsevec_negative_inner_product"("public"."sparsevec", "public"."sparsevec") TO "postgres";
GRANT ALL ON FUNCTION "public"."sparsevec_negative_inner_product"("public"."sparsevec", "public"."sparsevec") TO "anon";
GRANT ALL ON FUNCTION "public"."sparsevec_negative_inner_product"("public"."sparsevec", "public"."sparsevec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sparsevec_negative_inner_product"("public"."sparsevec", "public"."sparsevec") TO "service_role";



GRANT ALL ON FUNCTION "public"."subvector"("public"."halfvec", integer, integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."subvector"("public"."halfvec", integer, integer) TO "anon";
GRANT ALL ON FUNCTION "public"."subvector"("public"."halfvec", integer, integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."subvector"("public"."halfvec", integer, integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."subvector"("public"."vector", integer, integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."subvector"("public"."vector", integer, integer) TO "anon";
GRANT ALL ON FUNCTION "public"."subvector"("public"."vector", integer, integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."subvector"("public"."vector", integer, integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."sync_user_verification_status"() TO "anon";
GRANT ALL ON FUNCTION "public"."sync_user_verification_status"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."sync_user_verification_status"() TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_accum"(double precision[], "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_accum"(double precision[], "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_accum"(double precision[], "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_accum"(double precision[], "public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_add"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_add"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_add"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_add"("public"."vector", "public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_avg"(double precision[]) TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_avg"(double precision[]) TO "anon";
GRANT ALL ON FUNCTION "public"."vector_avg"(double precision[]) TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_avg"(double precision[]) TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_cmp"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_cmp"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_cmp"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_cmp"("public"."vector", "public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_combine"(double precision[], double precision[]) TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_combine"(double precision[], double precision[]) TO "anon";
GRANT ALL ON FUNCTION "public"."vector_combine"(double precision[], double precision[]) TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_combine"(double precision[], double precision[]) TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_concat"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_concat"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_concat"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_concat"("public"."vector", "public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_dims"("public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_dims"("public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_dims"("public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_dims"("public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_dims"("public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_dims"("public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_dims"("public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_dims"("public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_eq"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_eq"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_eq"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_eq"("public"."vector", "public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_ge"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_ge"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_ge"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_ge"("public"."vector", "public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_gt"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_gt"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_gt"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_gt"("public"."vector", "public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_l2_squared_distance"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_l2_squared_distance"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_l2_squared_distance"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_l2_squared_distance"("public"."vector", "public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_le"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_le"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_le"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_le"("public"."vector", "public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_lt"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_lt"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_lt"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_lt"("public"."vector", "public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_mul"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_mul"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_mul"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_mul"("public"."vector", "public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_ne"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_ne"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_ne"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_ne"("public"."vector", "public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_negative_inner_product"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_negative_inner_product"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_negative_inner_product"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_negative_inner_product"("public"."vector", "public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_norm"("public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_norm"("public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_norm"("public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_norm"("public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_spherical_distance"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_spherical_distance"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_spherical_distance"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_spherical_distance"("public"."vector", "public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_sub"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_sub"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_sub"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_sub"("public"."vector", "public"."vector") TO "service_role";












GRANT ALL ON FUNCTION "public"."avg"("public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."avg"("public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."avg"("public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."avg"("public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."avg"("public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."avg"("public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."avg"("public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."avg"("public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."sum"("public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."sum"("public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."sum"("public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sum"("public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."sum"("public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."sum"("public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."sum"("public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sum"("public"."vector") TO "service_role";









GRANT ALL ON TABLE "public"."bookmarks" TO "anon";
GRANT ALL ON TABLE "public"."bookmarks" TO "authenticated";
GRANT ALL ON TABLE "public"."bookmarks" TO "service_role";



GRANT ALL ON TABLE "public"."conversation_participants" TO "anon";
GRANT ALL ON TABLE "public"."conversation_participants" TO "authenticated";
GRANT ALL ON TABLE "public"."conversation_participants" TO "service_role";



GRANT ALL ON TABLE "public"."conversations" TO "anon";
GRANT ALL ON TABLE "public"."conversations" TO "authenticated";
GRANT ALL ON TABLE "public"."conversations" TO "service_role";



GRANT ALL ON TABLE "public"."conversations_backup" TO "anon";
GRANT ALL ON TABLE "public"."conversations_backup" TO "authenticated";
GRANT ALL ON TABLE "public"."conversations_backup" TO "service_role";



GRANT ALL ON TABLE "public"."driver_availability_schedule" TO "anon";
GRANT ALL ON TABLE "public"."driver_availability_schedule" TO "authenticated";
GRANT ALL ON TABLE "public"."driver_availability_schedule" TO "service_role";



GRANT ALL ON TABLE "public"."driver_documents" TO "anon";
GRANT ALL ON TABLE "public"."driver_documents" TO "authenticated";
GRANT ALL ON TABLE "public"."driver_documents" TO "service_role";



GRANT ALL ON TABLE "public"."driver_earnings" TO "anon";
GRANT ALL ON TABLE "public"."driver_earnings" TO "authenticated";
GRANT ALL ON TABLE "public"."driver_earnings" TO "service_role";



GRANT ALL ON TABLE "public"."driver_job_assignments" TO "anon";
GRANT ALL ON TABLE "public"."driver_job_assignments" TO "authenticated";
GRANT ALL ON TABLE "public"."driver_job_assignments" TO "service_role";



GRANT ALL ON TABLE "public"."driver_tier_history" TO "anon";
GRANT ALL ON TABLE "public"."driver_tier_history" TO "authenticated";
GRANT ALL ON TABLE "public"."driver_tier_history" TO "service_role";



GRANT ALL ON TABLE "public"."driver_trips" TO "anon";
GRANT ALL ON TABLE "public"."driver_trips" TO "authenticated";
GRANT ALL ON TABLE "public"."driver_trips" TO "service_role";



GRANT ALL ON TABLE "public"."drivers" TO "anon";
GRANT ALL ON TABLE "public"."drivers" TO "authenticated";
GRANT ALL ON TABLE "public"."drivers" TO "service_role";



GRANT ALL ON TABLE "public"."filter_words" TO "anon";
GRANT ALL ON TABLE "public"."filter_words" TO "authenticated";
GRANT ALL ON TABLE "public"."filter_words" TO "service_role";



GRANT ALL ON TABLE "public"."message_flags" TO "anon";
GRANT ALL ON TABLE "public"."message_flags" TO "authenticated";
GRANT ALL ON TABLE "public"."message_flags" TO "service_role";



GRANT ALL ON TABLE "public"."messages" TO "anon";
GRANT ALL ON TABLE "public"."messages" TO "authenticated";
GRANT ALL ON TABLE "public"."messages" TO "service_role";



GRANT ALL ON TABLE "public"."messages_backup" TO "anon";
GRANT ALL ON TABLE "public"."messages_backup" TO "authenticated";
GRANT ALL ON TABLE "public"."messages_backup" TO "service_role";



GRANT ALL ON TABLE "public"."notifications" TO "anon";
GRANT ALL ON TABLE "public"."notifications" TO "authenticated";
GRANT ALL ON TABLE "public"."notifications" TO "service_role";



GRANT ALL ON TABLE "public"."partner_vehicle_applications" TO "anon";
GRANT ALL ON TABLE "public"."partner_vehicle_applications" TO "authenticated";
GRANT ALL ON TABLE "public"."partner_vehicle_applications" TO "service_role";



GRANT ALL ON TABLE "public"."partner_vehicle_documents" TO "anon";
GRANT ALL ON TABLE "public"."partner_vehicle_documents" TO "authenticated";
GRANT ALL ON TABLE "public"."partner_vehicle_documents" TO "service_role";



GRANT ALL ON TABLE "public"."partner_vehicles" TO "anon";
GRANT ALL ON TABLE "public"."partner_vehicles" TO "authenticated";
GRANT ALL ON TABLE "public"."partner_vehicles" TO "service_role";



GRANT ALL ON TABLE "public"."partners" TO "anon";
GRANT ALL ON TABLE "public"."partners" TO "authenticated";
GRANT ALL ON TABLE "public"."partners" TO "service_role";



GRANT ALL ON TABLE "public"."profiles" TO "anon";
GRANT ALL ON TABLE "public"."profiles" TO "authenticated";
GRANT ALL ON TABLE "public"."profiles" TO "service_role";



GRANT ALL ON TABLE "public"."ratings_backup" TO "anon";
GRANT ALL ON TABLE "public"."ratings_backup" TO "authenticated";
GRANT ALL ON TABLE "public"."ratings_backup" TO "service_role";



GRANT ALL ON TABLE "public"."renter_documents" TO "anon";
GRANT ALL ON TABLE "public"."renter_documents" TO "authenticated";
GRANT ALL ON TABLE "public"."renter_documents" TO "service_role";



GRANT ALL ON TABLE "public"."renters" TO "anon";
GRANT ALL ON TABLE "public"."renters" TO "authenticated";
GRANT ALL ON TABLE "public"."renters" TO "service_role";



GRANT ALL ON TABLE "public"."transactions" TO "anon";
GRANT ALL ON TABLE "public"."transactions" TO "authenticated";
GRANT ALL ON TABLE "public"."transactions" TO "service_role";



GRANT ALL ON TABLE "public"."user_documents" TO "anon";
GRANT ALL ON TABLE "public"."user_documents" TO "authenticated";
GRANT ALL ON TABLE "public"."user_documents" TO "service_role";



GRANT ALL ON TABLE "public"."user_verifications" TO "anon";
GRANT ALL ON TABLE "public"."user_verifications" TO "authenticated";
GRANT ALL ON TABLE "public"."user_verifications" TO "service_role";



GRANT ALL ON TABLE "public"."users" TO "anon";
GRANT ALL ON TABLE "public"."users" TO "authenticated";
GRANT ALL ON TABLE "public"."users" TO "service_role";



GRANT ALL ON TABLE "public"."vehicle_applications" TO "anon";
GRANT ALL ON TABLE "public"."vehicle_applications" TO "authenticated";
GRANT ALL ON TABLE "public"."vehicle_applications" TO "service_role";



GRANT ALL ON TABLE "public"."vehicle_availability_backup" TO "anon";
GRANT ALL ON TABLE "public"."vehicle_availability_backup" TO "authenticated";
GRANT ALL ON TABLE "public"."vehicle_availability_backup" TO "service_role";



GRANT ALL ON TABLE "public"."vehicle_documents" TO "anon";
GRANT ALL ON TABLE "public"."vehicle_documents" TO "authenticated";
GRANT ALL ON TABLE "public"."vehicle_documents" TO "service_role";



GRANT ALL ON TABLE "public"."vehicle_images" TO "anon";
GRANT ALL ON TABLE "public"."vehicle_images" TO "authenticated";
GRANT ALL ON TABLE "public"."vehicle_images" TO "service_role";



GRANT ALL ON TABLE "public"."vehicles" TO "anon";
GRANT ALL ON TABLE "public"."vehicles" TO "authenticated";
GRANT ALL ON TABLE "public"."vehicles" TO "service_role";









ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "service_role";































drop extension if exists "pg_net";

alter table "public"."drivers" drop constraint "status_check";

alter table "public"."drivers" drop constraint "tier_check";

alter table "public"."user_verifications" drop constraint "verification_status_check";

alter table "public"."drivers" add constraint "status_check" CHECK (((verification_status)::text = ANY ((ARRAY['pending'::character varying, 'approved'::character varying, 'rejected'::character varying])::text[]))) not valid;

alter table "public"."drivers" validate constraint "status_check";

alter table "public"."drivers" add constraint "tier_check" CHECK (((driver_tier)::text = ANY ((ARRAY['standard'::character varying, 'professional'::character varying, 'elite'::character varying])::text[]))) not valid;

alter table "public"."drivers" validate constraint "tier_check";

alter table "public"."user_verifications" add constraint "verification_status_check" CHECK (((verification_status)::text = ANY ((ARRAY['pending'::character varying, 'verified'::character varying, 'rejected'::character varying])::text[]))) not valid;

alter table "public"."user_verifications" validate constraint "verification_status_check";

CREATE TRIGGER on_auth_user_created AFTER INSERT ON auth.users FOR EACH ROW EXECUTE FUNCTION public.handle_new_auth_user();


  create policy "dev_allow_all_vehicle_images"
  on "storage"."objects"
  as permissive
  for all
  to public
using ((bucket_id = 'vehicle_images'::text))
with check ((bucket_id = 'vehicle_images'::text));



  create policy "driver_documents_delete_own_folder"
  on "storage"."objects"
  as permissive
  for delete
  to authenticated
using (((bucket_id = 'driver_documents'::text) AND ((storage.foldername(name))[1] = (auth.uid())::text)));



  create policy "driver_documents_insert_own_folder"
  on "storage"."objects"
  as permissive
  for insert
  to authenticated
with check (((bucket_id = 'driver_documents'::text) AND ((storage.foldername(name))[1] = (auth.uid())::text)));



  create policy "driver_documents_select_own_folder"
  on "storage"."objects"
  as permissive
  for select
  to authenticated
using (((bucket_id = 'driver_documents'::text) AND ((storage.foldername(name))[1] = (auth.uid())::text)));



  create policy "driver_documents_update_own_folder"
  on "storage"."objects"
  as permissive
  for update
  to authenticated
using (((bucket_id = 'driver_documents'::text) AND ((storage.foldername(name))[1] = (auth.uid())::text)))
with check (((bucket_id = 'driver_documents'::text) AND ((storage.foldername(name))[1] = (auth.uid())::text)));



  create policy "id_images_delete_own_folder"
  on "storage"."objects"
  as permissive
  for delete
  to authenticated
using (((bucket_id = 'id_images'::text) AND ((storage.foldername(name))[1] = 'verifications'::text) AND ((storage.foldername(name))[2] = (auth.uid())::text)));



  create policy "id_images_insert_own_folder"
  on "storage"."objects"
  as permissive
  for insert
  to authenticated
with check (((bucket_id = 'id_images'::text) AND ((storage.foldername(name))[1] = 'verifications'::text) AND ((storage.foldername(name))[2] = (auth.uid())::text)));



  create policy "id_images_select_own_folder"
  on "storage"."objects"
  as permissive
  for select
  to authenticated
using (((bucket_id = 'id_images'::text) AND ((storage.foldername(name))[1] = 'verifications'::text) AND ((storage.foldername(name))[2] = (auth.uid())::text)));



  create policy "id_images_update_own_folder"
  on "storage"."objects"
  as permissive
  for update
  to authenticated
using (((bucket_id = 'id_images'::text) AND ((storage.foldername(name))[1] = 'verifications'::text) AND ((storage.foldername(name))[2] = (auth.uid())::text)))
with check (((bucket_id = 'id_images'::text) AND ((storage.foldername(name))[1] = 'verifications'::text) AND ((storage.foldername(name))[2] = (auth.uid())::text)));



  create policy "partner_documents_delete_own_folder"
  on "storage"."objects"
  as permissive
  for delete
  to authenticated
using (((bucket_id = 'partner_documents'::text) AND ((storage.foldername(name))[1] = (auth.uid())::text)));



  create policy "partner_documents_insert_own_folder"
  on "storage"."objects"
  as permissive
  for insert
  to authenticated
with check (((bucket_id = 'partner_documents'::text) AND ((storage.foldername(name))[1] = (auth.uid())::text)));



  create policy "partner_documents_select_own_folder"
  on "storage"."objects"
  as permissive
  for select
  to authenticated
using (((bucket_id = 'partner_documents'::text) AND (((storage.foldername(name))[1] = (auth.uid())::text) OR (EXISTS ( SELECT 1
   FROM public.users
  WHERE ((users.id = auth.uid()) AND (users.role = 'admin'::text)))))));



  create policy "partner_documents_update_own_folder"
  on "storage"."objects"
  as permissive
  for update
  to authenticated
using (((bucket_id = 'partner_documents'::text) AND ((storage.foldername(name))[1] = (auth.uid())::text)))
with check (((bucket_id = 'partner_documents'::text) AND ((storage.foldername(name))[1] = (auth.uid())::text)));



