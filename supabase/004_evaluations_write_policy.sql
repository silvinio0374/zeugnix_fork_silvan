-- ============================================================================
-- zeugnix.ch – Schreibrechte für evaluations (Migration 004)
-- ----------------------------------------------------------------------------
-- Das Schema (001) hatte für die Tabelle evaluations nur eine SELECT-Policy.
-- Die Selbst-Beurteilung (/api/certificates/[id]/evaluate-self) schreibt aber
-- als eingeloggter User (nicht Service Role) in evaluations und löscht
-- vorherige Einträge. Ohne INSERT/DELETE-Policy schlägt das fehl mit:
--   "new row violates row-level security policy for table 'evaluations'".
--
-- Regel: Ein Mitglied darf Beurteilungen genau dann schreiben/löschen, wenn es
-- Zugriff auf das zugehörige Zeugnis hat – identische Bedingung wie die
-- bestehende Leseregel "Members can read evaluations".
--
-- Idempotent: drop policy if exists ... vor create.
-- Ausführung: Supabase Dashboard → SQL Editor → einfügen → Run
-- ============================================================================

drop policy if exists "Members can insert evaluations" on public.evaluations;
create policy "Members can insert evaluations" on public.evaluations
  for insert with check (
    exists (
      select 1 from public.certificates cert
      join public.companies c on c.id = cert.company_id
      where cert.id = evaluations.certificate_id
      and (
        c.created_by_user_id = auth.uid()
        or exists (select 1 from public.company_members m where m.company_id = c.id and m.user_id = auth.uid())
      )
    )
  );

drop policy if exists "Members can delete evaluations" on public.evaluations;
create policy "Members can delete evaluations" on public.evaluations
  for delete using (
    exists (
      select 1 from public.certificates cert
      join public.companies c on c.id = cert.company_id
      where cert.id = evaluations.certificate_id
      and (
        c.created_by_user_id = auth.uid()
        or exists (select 1 from public.company_members m where m.company_id = c.id and m.user_id = auth.uid())
      )
    )
  );

-- Done.
