-- Support driver pickup/return actions, operator notifications, and booking
-- group chat lifecycle.

BEGIN;

CREATE TABLE IF NOT EXISTS public.notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES public.users(id) ON DELETE CASCADE,
  title text NOT NULL,
  message text,
  body text,
  type text DEFAULT 'general',
  data jsonb,
  is_read boolean DEFAULT false,
  created_at timestamp with time zone DEFAULT now()
);

ALTER TABLE IF EXISTS public.notifications
  ADD COLUMN IF NOT EXISTS title text,
  ADD COLUMN IF NOT EXISTS message text,
  ADD COLUMN IF NOT EXISTS body text,
  ADD COLUMN IF NOT EXISTS type text DEFAULT 'general',
  ADD COLUMN IF NOT EXISTS data jsonb,
  ADD COLUMN IF NOT EXISTS is_read boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS created_at timestamp with time zone DEFAULT now();

CREATE INDEX IF NOT EXISTS idx_notifications_user_created
  ON public.notifications(user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_notifications_user_unread
  ON public.notifications(user_id, is_read);

CREATE TABLE IF NOT EXISTS public.conversations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id uuid REFERENCES public.bookings(id) ON DELETE CASCADE,
  user_id uuid REFERENCES public.users(id) ON DELETE SET NULL,
  other_user_id uuid REFERENCES public.users(id) ON DELETE SET NULL,
  status text DEFAULT 'active',
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.conversation_participants (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id uuid REFERENCES public.conversations(id) ON DELETE CASCADE,
  user_id uuid REFERENCES public.users(id) ON DELETE CASCADE,
  joined_at timestamp with time zone DEFAULT now()
);

ALTER TABLE IF EXISTS public.messages
  ADD COLUMN IF NOT EXISTS content text,
  ADD COLUMN IF NOT EXISTS is_read boolean DEFAULT false;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'messages'
      AND column_name = 'recipient_id'
  ) THEN
    ALTER TABLE public.messages
      ALTER COLUMN recipient_id DROP NOT NULL;
  END IF;
END $$;

ALTER TABLE IF EXISTS public.conversations
  ADD COLUMN IF NOT EXISTS status text DEFAULT 'active',
  ADD COLUMN IF NOT EXISTS updated_at timestamp with time zone DEFAULT now();

CREATE INDEX IF NOT EXISTS idx_conversations_booking_id
  ON public.conversations(booking_id);

DO $$
BEGIN
  IF to_regclass('public.conversation_participants') IS NOT NULL THEN
    IF NOT EXISTS (
      SELECT 1
      FROM pg_constraint
      WHERE conname = 'conversation_participants_unique_user'
        AND conrelid = 'public.conversation_participants'::regclass
    ) THEN
      ALTER TABLE public.conversation_participants
        ADD CONSTRAINT conversation_participants_unique_user
        UNIQUE (conversation_id, user_id);
    END IF;
  END IF;
END $$;

DROP POLICY IF EXISTS bookings_update_driver_assigned ON public.bookings;
CREATE POLICY bookings_update_driver_assigned
  ON public.bookings
  FOR UPDATE
  TO authenticated
  USING (
    driver_id = auth.uid()
    AND lower(COALESCE(status, 'pending')) IN ('approved', 'confirmed', 'active')
  )
  WITH CHECK (
    driver_id = auth.uid()
    AND lower(COALESCE(status, 'pending')) IN ('active', 'completed')
  );

DROP POLICY IF EXISTS notifications_select_own ON public.notifications;
CREATE POLICY notifications_select_own
  ON public.notifications
  FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS notifications_update_own ON public.notifications;
CREATE POLICY notifications_update_own
  ON public.notifications
  FOR UPDATE
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS notifications_insert_authenticated ON public.notifications;
CREATE POLICY notifications_insert_authenticated
  ON public.notifications
  FOR INSERT
  TO authenticated
  WITH CHECK (true);

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.conversation_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS conversations_select_participant ON public.conversations;
CREATE POLICY conversations_select_participant
  ON public.conversations
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.conversation_participants cp
      WHERE cp.conversation_id = public.conversations.id
        AND cp.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS conversations_insert_authenticated ON public.conversations;
CREATE POLICY conversations_insert_authenticated
  ON public.conversations
  FOR INSERT
  TO authenticated
  WITH CHECK (true);

DROP POLICY IF EXISTS conversations_update_participant ON public.conversations;
CREATE POLICY conversations_update_participant
  ON public.conversations
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.conversation_participants cp
      WHERE cp.conversation_id = public.conversations.id
        AND cp.user_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.conversation_participants cp
      WHERE cp.conversation_id = public.conversations.id
        AND cp.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS conversation_participants_select_own_conversations ON public.conversation_participants;
CREATE POLICY conversation_participants_select_own_conversations
  ON public.conversation_participants
  FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS conversation_participants_insert_authenticated ON public.conversation_participants;
CREATE POLICY conversation_participants_insert_authenticated
  ON public.conversation_participants
  FOR INSERT
  TO authenticated
  WITH CHECK (true);

DROP POLICY IF EXISTS messages_select_conversation_participant ON public.messages;
CREATE POLICY messages_select_conversation_participant
  ON public.messages
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.conversation_participants cp
      WHERE cp.conversation_id = messages.conversation_id
        AND cp.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS messages_insert_conversation_participant ON public.messages;
CREATE POLICY messages_insert_conversation_participant
  ON public.messages
  FOR INSERT
  TO authenticated
  WITH CHECK (
    sender_id = auth.uid()
    AND EXISTS (
      SELECT 1
      FROM public.conversation_participants cp
      WHERE cp.conversation_id = messages.conversation_id
        AND cp.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS messages_update_conversation_participant ON public.messages;
CREATE POLICY messages_update_conversation_participant
  ON public.messages
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.conversation_participants cp
      WHERE cp.conversation_id = messages.conversation_id
        AND cp.user_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.conversation_participants cp
      WHERE cp.conversation_id = messages.conversation_id
        AND cp.user_id = auth.uid()
    )
  );

NOTIFY pgrst, 'reload schema';

COMMIT;
