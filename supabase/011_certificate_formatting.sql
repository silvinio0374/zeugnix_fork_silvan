-- ============================================================================
-- zeugnix.ch – Rich-Text-Formatierung + Firmen-Stil-Default (Migration 011)
-- ----------------------------------------------------------------------------
-- Feature: "Word-artiger" Editor. Der Zeugnis-Body wird künftig als Tiptap-JSON
-- gespeichert (Präsentations-Wahrheit mit Schrift/Farbe/Fett pro Textstelle),
-- während certificates.edited_text die KLARTEXT-Projektion bleibt und
-- unverändert den Echtheits-Hash speist (Formatierung ändert den Hash nie).
--
--   - certificates.formatted_content: Tiptap-JSON des Body (nullable; fehlt es,
--     rendert PDF/Vorschau über den bisherigen Plain-Text-Pfad als Fallback).
--   - companies.default_certificate_font_family / _text_color: Basis-Stil pro
--     Gesellschaft, der in neue Zeugnisse vorbelegt und pro Zeugnis über die
--     Marks im JSON überschrieben werden kann.
--
-- Idempotent: "add column if not exists" – mehrfaches Ausführen ist gefahrlos.
-- Ausführung: Supabase Dashboard -> SQL Editor -> einfügen -> Run
-- ============================================================================

alter table public.certificates
  add column if not exists formatted_content jsonb;

alter table public.companies
  add column if not exists default_certificate_font_family text;
alter table public.companies
  add column if not exists default_certificate_text_color text;

-- Done.
