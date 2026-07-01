-- ============================================================================
-- 007_storage_logos.sql
-- ----------------------------------------------------------------------------
-- Legt den Storage-Bucket fuer Firmenlogos an und setzt die noetigen
-- RLS-Policies auf storage.objects. Ohne diese Policies schlaegt der
-- Logo-Upload mit "new row violates row-level security policy" fehl, auch
-- wenn der Bucket "public" ist (public = nur Lesen ist oeffentlich).
--
-- Idempotent: kann beliebig oft ausgefuehrt werden.
-- Pfad-Konvention: <user_id>/<dateiname>  -> jeder Nutzer schreibt nur in
-- seinen eigenen Ordner.
-- ============================================================================

-- 1. Bucket anlegen (falls nicht vorhanden), oeffentlich lesbar
insert into storage.buckets (id, name, public)
values ('company-logos', 'company-logos', true)
on conflict (id) do update set public = true;

-- 2. Policies (drop + create => idempotent)

-- Oeffentliches Lesen (Logos erscheinen im Briefkopf / in der Vorschau)
drop policy if exists "company-logos public read" on storage.objects;
create policy "company-logos public read"
  on storage.objects for select
  using (bucket_id = 'company-logos');

-- Eingeloggte Nutzer duerfen NUR in ihren eigenen Ordner hochladen
drop policy if exists "company-logos auth insert" on storage.objects;
create policy "company-logos auth insert"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'company-logos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- ... aendern (upsert)
drop policy if exists "company-logos auth update" on storage.objects;
create policy "company-logos auth update"
  on storage.objects for update to authenticated
  using (
    bucket_id = 'company-logos'
    and (storage.foldername(name))[1] = auth.uid()::text
  )
  with check (
    bucket_id = 'company-logos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- ... und loeschen
drop policy if exists "company-logos auth delete" on storage.objects;
create policy "company-logos auth delete"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'company-logos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- Done.
