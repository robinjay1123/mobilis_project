-- Ensure PostgREST can embed messages under conversations by adding the missing
-- FK relationship: messages.conversation_id -> conversations.id.

BEGIN;

DO $$
BEGIN
  IF to_regclass('public.messages') IS NOT NULL
     AND to_regclass('public.conversations') IS NOT NULL THEN
    IF NOT EXISTS (
      SELECT 1
      FROM pg_constraint
      WHERE conname = 'messages_conversation_id_fkey'
        AND conrelid = 'public.messages'::regclass
    ) THEN
      ALTER TABLE public.messages
        ADD CONSTRAINT messages_conversation_id_fkey
        FOREIGN KEY (conversation_id)
        REFERENCES public.conversations(id)
        ON DELETE CASCADE;
    END IF;
  END IF;
END $$;

NOTIFY pgrst, 'reload schema';

COMMIT;

