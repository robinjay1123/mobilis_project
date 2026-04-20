-- Create filter_words table for message filtering
BEGIN;

CREATE TABLE IF NOT EXISTS public.filter_words (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  word TEXT NOT NULL UNIQUE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  created_by UUID REFERENCES public.users(id) ON DELETE SET NULL
);

-- Create indexes for efficient querying
CREATE INDEX IF NOT EXISTS idx_filter_words_word ON public.filter_words(word);
CREATE INDEX IF NOT EXISTS idx_filter_words_created_at ON public.filter_words(created_at DESC);

COMMIT;
