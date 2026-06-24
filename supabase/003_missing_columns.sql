-- ============================================================================
-- zeugnix.ch – Fehlende Spalten ergänzen (Migration 003)
-- ----------------------------------------------------------------------------
-- Das App-Formular schreibt Felder, die im ursprünglichen Schema (001) fehlten:
--   - companies: Kontaktdaten (website, phone, email) und die beiden
--     unterzeichnenden Personen (signatory_1/2_name + _role)
--   - employees: date_of_birth (Geburtsdatum, für Einleitungssatz)
--
-- Ohne diese Spalten scheitert "Firma anlegen" mit
--   "Could not find the 'email' column of 'companies' in the schema cache".
--
-- Idempotent: "add column if not exists" – mehrfaches Ausführen ist gefahrlos.
--
-- Ausführung: Supabase Dashboard → SQL Editor → einfügen → Run
-- ============================================================================

-- companies: Kontaktdaten + Unterzeichnende
alter table public.companies add column if not exists website text;
alter table public.companies add column if not exists phone text;
alter table public.companies add column if not exists email text;
alter table public.companies add column if not exists signatory_1_name text;
alter table public.companies add column if not exists signatory_1_role text;
alter table public.companies add column if not exists signatory_2_name text;
alter table public.companies add column if not exists signatory_2_role text;

-- employees: Geburtsdatum
alter table public.employees add column if not exists date_of_birth date;

-- Done.
