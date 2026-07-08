-- ============================================================================
-- 013_wertschaetzungsgrad.sql
-- Wertschätzungsgrad des Schlusssatzes (Christoph-Matrix)
-- ============================================================================
-- Steuert die Tonalität des gewählten Schlusssatzes:
--   standard | wertschaetzender | top (Top-Mitarbeitende / Best Case)
--
-- Der konkrete Satz kommt aus dem TS-Katalog `lib/phrases/schlusssaetze.ts`
-- (eine Quelle für Engine + Formular-Vorschau). Diese Spalte hält die Wahl
-- pro Zeugnis fest, damit Neu-Generieren dieselbe Variante liefert.
--
-- Idempotent; manuell in Prod einspielen (SQL-Editor, Projekt „zeugnix").
-- ----------------------------------------------------------------------------

do $$ begin
  create type wertschaetzungsgrad as enum ('standard', 'wertschaetzender', 'top');
exception when duplicate_object then null; end $$;

alter table public.certificates
  add column if not exists wertschaetzungsgrad wertschaetzungsgrad not null default 'standard';
