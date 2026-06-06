-- Force PostgREST to reload newly added relationships and policies.
NOTIFY pgrst, 'reload schema';
