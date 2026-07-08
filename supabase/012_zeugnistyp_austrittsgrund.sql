-- ============================================================================
-- 012_zeugnistyp_austrittsgrund.sql
-- Datenmodell: Zeugnistyp und Austrittsgrund sauber trennen (Christoph-Matrix)
-- ============================================================================
-- Bisher vermischte das flache `certificate_type`-Enum zwei Dimensionen:
-- den eigentlichen Zeugnistyp (Schluss/Zwischen) und den Anlass/Austrittsgrund
-- bzw. die Wechsel-Umstände. Diese Migration trennt sie:
--
--   zeugnis_typ     schluss | zwischen | arbeitsbestaetigung
--   austrittsgrund  wunsch_an | wunsch_ag | einvernehmen   (nur bei Schluss)
--   optin_*         stapelbare Zusätze: Bedauern, Reorganisation,
--                   Vorgesetztenwechsel, interner Wechsel
--
-- Additiv & rückwärtskompatibel: die alte `type`-Spalte bleibt bestehen und
-- wird von der App weiterhin (abgeleitet) geschrieben, bis Engine/Vorschau in
-- späteren Phasen auf die neuen Felder umgestellt sind. Nichts bricht.
--
-- Idempotent: mehrfaches Ausführen ist gefahrlos.
-- Manuell in Prod einspielen (SQL-Editor, Projekt „zeugnix"), NICHT beim Deploy.
-- ----------------------------------------------------------------------------

-- 1. Neue Enums -------------------------------------------------------------
do $$ begin
  create type zeugnis_typ as enum ('schluss', 'zwischen', 'arbeitsbestaetigung');
exception when duplicate_object then null; end $$;

do $$ begin
  create type austrittsgrund as enum ('wunsch_an', 'wunsch_ag', 'einvernehmen');
exception when duplicate_object then null; end $$;

-- 2. 'arbeitsbestaetigung' auch dem Legacy-Enum hinzufügen, damit die
--    abgeleitete `type`-Spalte diesen Typ ab Phase 2 halten kann.
--    (Wird in dieser Migration NICHT verwendet – add value ist autocommit.)
alter type certificate_type add value if not exists 'arbeitsbestaetigung';

-- 3. Neue Spalten -----------------------------------------------------------
alter table public.certificates
  add column if not exists zeugnis_typ zeugnis_typ;
alter table public.certificates
  add column if not exists austrittsgrund austrittsgrund;
alter table public.certificates
  add column if not exists optin_bedauern boolean not null default false;
alter table public.certificates
  add column if not exists optin_reorg boolean not null default false;
alter table public.certificates
  add column if not exists optin_vorgesetztenwechsel boolean not null default false;
alter table public.certificates
  add column if not exists optin_interner_wechsel boolean not null default false;

-- 4. Backfill bestehender Zeilen aus `type` (nur wo zeugnis_typ noch leer) ----
--    Mapping (mit Silvan abgestimmt, Christoph-Matrix):
--      schluss                      -> Schluss
--      reorganisation               -> Schluss + Wunsch AG + Opt-in Reorg
--      wunsch_mitarbeiter(in)       -> Schluss + Wunsch AN
--      zwischen                     -> Zwischen
--      funktionswechsel             -> Zwischen
--      vorgesetztenwechsel          -> Zwischen + Opt-in Vorgesetztenwechsel
--      interner_wechsel             -> Zwischen + Opt-in interner Wechsel
update public.certificates set
  zeugnis_typ = (case type
    when 'schluss'             then 'schluss'
    when 'reorganisation'      then 'schluss'
    when 'wunsch_mitarbeiter'  then 'schluss'
    when 'wunsch_mitarbeiterin' then 'schluss'
    when 'zwischen'            then 'zwischen'
    when 'funktionswechsel'    then 'zwischen'
    when 'vorgesetztenwechsel' then 'zwischen'
    when 'interner_wechsel'    then 'zwischen'
    else 'zwischen'
  end)::zeugnis_typ,
  austrittsgrund = (case type
    when 'wunsch_mitarbeiter'   then 'wunsch_an'
    when 'wunsch_mitarbeiterin' then 'wunsch_an'
    when 'reorganisation'       then 'wunsch_ag'
    else null
  end)::austrittsgrund,
  optin_reorg               = (type = 'reorganisation'),
  optin_vorgesetztenwechsel = (type = 'vorgesetztenwechsel'),
  optin_interner_wechsel    = (type = 'interner_wechsel')
where zeugnis_typ is null;
