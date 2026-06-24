-- ============================================================================
-- zeugnix.ch – Bearbeiteter Zeugnistext (Migration 005)
-- ----------------------------------------------------------------------------
-- Die Text-Speicher-Route (/api/certificates/[id]/text, Auto-Save im Editor)
-- schreibt edited_text + Metadaten, die im Schema (001) fehlten. Ohne diese
-- Spalten scheitert das Speichern manueller Bearbeitungen mit
--   "Could not find the 'edited_text' column of 'certificates'".
--
-- Hinweis: app/(authed)/app/certificates/[id]/page.tsx liest cert.edited_text
-- (displayText = edited_text || generated_text), die PDF-Route ebenfalls.
--
-- Idempotent: add column if not exists.
-- Ausführung: Supabase Dashboard → SQL Editor → einfügen → Run
-- ============================================================================

alter table public.certificates add column if not exists edited_text text;
alter table public.certificates add column if not exists text_last_edited_at timestamptz;
alter table public.certificates add column if not exists text_last_edited_by_user_id uuid references public.profiles(id) on delete set null;

-- Done.
