-- ==============================================================
-- zeugnix.ch – Ausstehende Migrationen 003 bis 011 (kombiniert)
-- Auf der PRODUKTIONS-DB (Patricks Supabase) im SQL-Editor Run.
-- Alle Teile idempotent -> gefahrlos wiederholt ausführbar.
-- ==============================================================


-- ###################### supabase/003_missing_columns.sql ######################
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


-- ###################### supabase/004_evaluations_write_policy.sql ######################
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


-- ###################### supabase/005_certificate_edited_text.sql ######################
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


-- ###################### supabase/006_security_hardening.sql ######################
-- ============================================================================
-- zeugnix.ch – Security-Hardening (Migration 006)
-- ----------------------------------------------------------------------------
-- Behebt Supabase-Database-Linter-Warnungen (alle Level WARN):
--
-- 1+2) function_search_path_mutable: handle_new_user() und set_updated_at()
--      hatten keinen fixierten search_path. Wir setzen ihn leer ('') – beide
--      Funktionen referenzieren ohnehin voll qualifiziert (public.profiles,
--      now() aus pg_catalog), funktionieren also unverändert.
--
-- 3+4) anon/authenticated_security_definer_function_executable: die
--      SECURITY-DEFINER-Trigger-Funktion handle_new_user() war zusätzlich als
--      REST-RPC für anon/authenticated aufrufbar. Wir entziehen das
--      EXECUTE-Recht. Der Trigger (on_auth_user_created) läuft davon
--      unabhängig weiter – Trigger benötigen kein EXECUTE-Grant.
--
-- Nicht per SQL behebbar (Dashboard):
-- 5) auth_leaked_password_protection -> Authentication → Policies aktivieren.
--    Unkritisch, da Login per Magic-Link (keine Passwörter).
--
-- Idempotent: ALTER/REVOKE sind wiederholbar.
-- Ausführung: Supabase Dashboard → SQL Editor → einfügen → Run
-- ============================================================================

-- 1+2) search_path fixieren
alter function public.handle_new_user() set search_path = '';
alter function public.set_updated_at() set search_path = '';

-- 3+4) EXECUTE-Recht der SECURITY-DEFINER-Funktion entziehen
revoke execute on function public.handle_new_user() from public;
revoke execute on function public.handle_new_user() from anon;
revoke execute on function public.handle_new_user() from authenticated;

-- Done.


-- ###################### supabase/007_storage_logos.sql ######################
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


-- ###################### supabase/008_certificate_archive.sql ######################
-- ============================================================================
-- zeugnix.ch – Zeugnis archivieren (Migration 008)
-- ----------------------------------------------------------------------------
-- Schritt 4 (Funktionslücken): Zeugnisse sollen entfernt werden können.
--   - Nicht-finalisierte Zeugnisse (Entwürfe etc.) werden hart gelöscht
--     (Route: DELETE /api/certificates/[id]). Kinder (evaluations,
--     manager_invitations) hängen per ON DELETE CASCADE dran.
--   - Finalisierte Zeugnisse bleiben als Rechtsdokument erhalten und werden
--     nur ARCHIVIERT (ausgeblendet) statt gelöscht. Dafür diese Spalte.
--
-- archived_at IS NULL  → aktiv (Standardansicht)
-- archived_at gesetzt  → archiviert (nur in der Archiv-Ansicht sichtbar)
--
-- Die bestehende RLS-Policy "Members can manage certificates" (for all) deckt
-- sowohl das UPDATE (Archivieren) als auch das DELETE bereits ab.
--
-- Idempotent: add column if not exists.
-- Ausführung: Supabase Dashboard → SQL Editor → einfügen → Run
-- ============================================================================

alter table public.certificates add column if not exists archived_at timestamptz;

-- Schneller Filter für die Standard-/Archiv-Ansicht.
create index if not exists idx_certificates_archived_at
  on public.certificates(archived_at);

-- Done.


-- ###################### supabase/009_seed_bausteine.sql ######################
-- 009_seed_bausteine.sql
-- AUTO-GENERIERT von scripts/import-bausteine.ts (Quelle: scripts/data/bausteine-zwischenzeugnis.txt
-- + LLM-Geschlechter-Tokenisierung in scripts/data/bausteine-tokenized.json).
-- 428 Bausteine, 36 Fähigkeiten. Gender='d' (Tokens {{m|f|d}} im Text).

begin;

-- 1) Alte Beurteilungs-Kategorien (Seed 002) deaktivieren – NICHT löschen, damit
--    finalisierte Zeugnisse (immutabler Text/Hash) gültig bleiben. subcategory='gesamt'
--    grenzt sie von neuen Skills mit gleichem Key (arbeitsqualitaet/zielerreichung) ab.
update public.phrase_blocks set active = false
 where category in ('fachliche_leistung', 'arbeitsweise', 'arbeitsqualitaet', 'zielerreichung', 'fuehrungsverhalten', 'verhalten')
   and subcategory = 'gesamt';

-- 2) Vorhandene Katalog-Bausteine entfernen (idempotenter Re-Run; berührt
--    einleitung/schluss nicht, da andere subcategory).
delete from public.phrase_blocks
 where subcategory in ('fuehrung', 'arbeitsbereitschaft_fachwissen', 'arbeitsweise_leistung', 'persoenliches_verhalten', 'unternehmertum');

-- 3) Neue Bausteine einfügen (signal_strength/tonality/warning_level/active = Defaults).
insert into public.phrase_blocks (category, subcategory, employee_type, gender, rating, variant, text) values
('vorbild', 'fuehrung', 'fuehrungskraft', 'd', 'ungenuegend', 1, '{vorname} {nachname} schätzen wir als Führungspersönlichkeit, {{dessen|deren|dessen/deren}} Führungsleistung auf Glaubwürdigkeit basiert.'),
('vorbild', 'fuehrung', 'fuehrungskraft', 'd', 'ungenuegend', 2, '{vorname} {nachname} erleben wir als {{Vorgesetzten|Vorgesetzte|Vorgesetzten/Vorgesetzte}}, {{der|die|der/die}} jeweils mit {{seinem|ihrem|seinem/ihrem}} Team solide Leistungen erbringt.'),
('vorbild', 'fuehrung', 'fuehrungskraft', 'd', 'genuegend', 1, '{vorname} {nachname} schätzen wir als zuverlässige Führungspersönlichkeit, {{dessen|deren|dessen/deren}} Führungsleistung auf Glaubwürdigkeit und Integrität basiert.'),
('vorbild', 'fuehrung', 'fuehrungskraft', 'd', 'genuegend', 2, '{vorname} {nachname} erleben wir als motivierte Führungskraft, die verantwortungsvoll handelt. Entscheidungen trifft {{er|sie|er/sie}} durchdacht, kommuniziert diese klar und nachvollziehbar.'),
('vorbild', 'fuehrung', 'fuehrungskraft', 'd', 'gut', 1, '{vorname} {nachname} schätzen wir als engagierte Führungspersönlichkeit, {{dessen|deren|dessen/deren}} vorbildliche Führungsleistung auf Glaubwürdigkeit und Integrität basiert.'),
('vorbild', 'fuehrung', 'fuehrungskraft', 'd', 'gut', 2, '{vorname} {nachname} schätzen wir als engagierte und integre Führungskraft, die vorausschauend, ziel- und umsetzungsorientiert sowie im Sinne unserer Wertekultur handelt. {{Er|Sie|Er/Sie}} verfügt über Selbstdisziplin und übernimmt stets Verantwortung. Entscheidungen trifft {{er|sie|er/sie}} gut durchdacht, kommuniziert diese zeitgerecht, klar und nachvollziehbar. Zudem überzeugt {{er|sie|er/sie}} durch {{seinen|ihren|seinen/ihren}} kooperativen Führungsstil.'),
('vorbild', 'fuehrung', 'fuehrungskraft', 'd', 'sehr_gut', 1, '{vorname} {nachname} schätzen wir als sehr engagierte Führungspersönlichkeit, {{dessen|deren|dessen/deren}} vorbildliche und beeindruckende Führungsleistung auf Glaubwürdigkeit und Integrität basiert.'),
('vorbild', 'fuehrung', 'fuehrungskraft', 'd', 'sehr_gut', 2, '{vorname} {nachname} schätzen wir als sehr engagierte und integre Führungskraft, die vorausschauend, ziel- und umsetzungsorientiert sowie im Sinne unserer Wertekultur denkt und agiert. {{Er|Sie|Er/Sie}} verfügt über einen hohen Grad an Selbstdisziplin und übernimmt stets Verantwortung. Entscheidungen trifft {{er|sie|er/sie}} bestens durchdacht und kommuniziert diese zeitgerecht, klar und nachvollziehbar. Zudem überzeugt {{er|sie|er/sie}} jederzeit durch {{sein|ihr|sein/ihr}} vorbildliches Engagement sowie durch {{seinen|ihren|seinen/ihren}} kooperativen, sach- und personenbezogenen Führungsstil.'),
('offenheit_vertrauen', 'fuehrung', 'fuehrungskraft', 'd', 'ungenuegend', 1, 'Durch {{sein|ihr|sein/ihr}} Interesse gegenüber den Anliegen {{seiner|ihrer|seiner/ihrer}} Mitarbeitenden schafft {{er|sie|er/sie}} ein angenehmes Arbeitsklima.'),
('offenheit_vertrauen', 'fuehrung', 'fuehrungskraft', 'd', 'ungenuegend', 2, 'Den Anliegen {{seiner|ihrer|seiner/ihrer}} Mitarbeitenden steht {vorname} {nachname} jeweils offen gegenüber.'),
('offenheit_vertrauen', 'fuehrung', 'fuehrungskraft', 'd', 'genuegend', 1, 'Durch {{sein|ihr|sein/ihr}} echtes Interesse gegenüber den Anliegen {{seiner|ihrer|seiner/ihrer}} Mitarbeitenden schafft {{er|sie|er/sie}} ein vertrauensvolles Arbeitsklima.'),
('offenheit_vertrauen', 'fuehrung', 'fuehrungskraft', 'd', 'genuegend', 2, 'Den Anliegen {{seiner|ihrer|seiner/ihrer}} Mitarbeitenden gegenüber ist {vorname} {nachname} jeweils offen. Durch {{seine|ihre|seine/ihre}} wertschätzende Haltung schafft {{er|sie|er/sie}} ein förderliches Arbeitsklima.'),
('offenheit_vertrauen', 'fuehrung', 'fuehrungskraft', 'd', 'gut', 1, 'Durch {{seine|ihre|seine/ihre}} Offenheit und echtes Interesse gegenüber den Anliegen {{seiner|ihrer|seiner/ihrer}} Mitarbeitenden schafft {{er|sie|er/sie}} ein vertrauensvolles und produktives Arbeitsklima.'),
('offenheit_vertrauen', 'fuehrung', 'fuehrungskraft', 'd', 'gut', 2, 'Als Führungskraft versteht {vorname} {nachname} es, {{seine|ihre|seine/ihre}} Mitarbeitenden entsprechend einzubeziehen und zielorientiert zu fördern. Durch {{seine|ihre|seine/ihre}} wertschätzende Haltung schafft {{er|sie|er/sie}} eine vertrauensvolle Basis der Zusammenarbeit sowie ein produktives Arbeitsklima. Vorschläge {{seiner|ihrer|seiner/ihrer}} Mitarbeitenden lässt {{er|sie|er/sie}} sinnvoll und angemessen in die Umsetzung {{seiner|ihrer|seiner/ihrer}} Ziele einfliessen.'),
('offenheit_vertrauen', 'fuehrung', 'fuehrungskraft', 'd', 'sehr_gut', 1, 'Durch Begeisterungsfähigkeit, Offenheit und echtes Interesse gegenüber den Anliegen {{seiner|ihrer|seiner/ihrer}} Mitarbeitenden schafft {{er|sie|er/sie}} ein vertrauensvolles und produktives Arbeitsklima.'),
('offenheit_vertrauen', 'fuehrung', 'fuehrungskraft', 'd', 'sehr_gut', 2, 'Als Führungskraft versteht {vorname} {nachname} es jederzeit bestens, alle Mitarbeitenden {{seines|ihres|seines/ihres}} Teams entsprechend ihrer Persönlichkeiten und Kompetenzen einzubeziehen und zielorientiert zu fördern. Durch {{seine|ihre|seine/ihre}} wertschätzende Haltung schafft {{er|sie|er/sie}} aktiv eine vertrauensvolle Basis der Zusammenarbeit sowie ein produktives Arbeitsklima. Vorschläge {{seiner|ihrer|seiner/ihrer}} Mitarbeitenden lässt {{er|sie|er/sie}} sinnvoll und angemessen in die Umsetzung {{seiner|ihrer|seiner/ihrer}} Ziele einfliessen.'),
('verantwortung_uebertragen', 'fuehrung', 'fuehrungskraft', 'd', 'ungenuegend', 1, 'Wir möchten erwähnen, dass {{er|sie|er/sie}} als {{Vorgesetzter|Vorgesetzte|Vorgesetzter/Vorgesetzte}} Aufgaben in massvollem Umfang delegiert.'),
('verantwortung_uebertragen', 'fuehrung', 'fuehrungskraft', 'd', 'ungenuegend', 2, 'Aufgaben delegiert {{er|sie|er/sie}} teilweise.'),
('verantwortung_uebertragen', 'fuehrung', 'fuehrungskraft', 'd', 'ungenuegend', 3, '{{Er|Sie|Er/Sie}} delegiert Aufgaben teils undifferenziert.'),
('verantwortung_uebertragen', 'fuehrung', 'fuehrungskraft', 'd', 'genuegend', 1, 'Wir schätzen, dass {{er|sie|er/sie}} als {{Vorgesetzter|Vorgesetzte|Vorgesetzter/Vorgesetzte}} Aufgaben in passendem Umfang delegiert.'),
('verantwortung_uebertragen', 'fuehrung', 'fuehrungskraft', 'd', 'genuegend', 2, 'Aufgaben delegiert {{er|sie|er/sie}} im richtigen Umfang.'),
('verantwortung_uebertragen', 'fuehrung', 'fuehrungskraft', 'd', 'genuegend', 3, '{{Er|Sie|Er/Sie}} delegiert Aufgaben besonnen.'),
('verantwortung_uebertragen', 'fuehrung', 'fuehrungskraft', 'd', 'gut', 1, 'Wir schätzen sehr, dass {{er|sie|er/sie}} als {{tüchtiger|tüchtige|tüchtiger/tüchtige}} {{Vorgesetzter|Vorgesetzte|Vorgesetzter/Vorgesetzte}} Aufgaben und Verantwortung in richtigem Umfang delegiert.'),
('verantwortung_uebertragen', 'fuehrung', 'fuehrungskraft', 'd', 'gut', 2, 'Aufgaben, Verantwortung und Kompetenzen delegiert {{er|sie|er/sie}} stets klar und im richtigen Umfang.'),
('verantwortung_uebertragen', 'fuehrung', 'fuehrungskraft', 'd', 'gut', 3, '{{Er|Sie|Er/Sie}} delegiert Aufgaben mit Sachverstand und Gespür.'),
('verantwortung_uebertragen', 'fuehrung', 'fuehrungskraft', 'd', 'sehr_gut', 1, 'Wir schätzen enorm, dass {{er|sie|er/sie}} als {{engagierter|engagierte|engagierter/engagierte}} {{Vorgesetzter|Vorgesetzte|Vorgesetzter/Vorgesetzte}} Aufgaben und Verantwortung vorbildlich und in angemessenem Umfang delegiert.'),
('verantwortung_uebertragen', 'fuehrung', 'fuehrungskraft', 'd', 'sehr_gut', 2, 'Aufgaben, Verantwortung und Kompetenzen delegiert {{er|sie|er/sie}} stets klar, ressourcenoptimiert und im richtigen Umfang.'),
('verantwortung_uebertragen', 'fuehrung', 'fuehrungskraft', 'd', 'sehr_gut', 3, '{{Er|Sie|Er/Sie}} delegiert Aufgaben mit grossem Sachverstand und Gespür.'),
('lenkung_arbeitsleistung', 'fuehrung', 'fuehrungskraft', 'd', 'ungenuegend', 1, '{{Er|Sie|Er/Sie}} fördert die Arbeitsleistung {{seiner|ihrer|seiner/ihrer}} Mitarbeitenden. Gleichzeitig unterstützt {{er|sie|er/sie}} durch geeignete Zielsetzungen.'),
('lenkung_arbeitsleistung', 'fuehrung', 'fuehrungskraft', 'd', 'ungenuegend', 2, 'Mit Unterstützung gelingt es {{ihm|ihr|ihm/ihr}}, {{seine|ihre|seine/ihre}} Mitarbeitenden zu Leistungen zu motivieren.'),
('lenkung_arbeitsleistung', 'fuehrung', 'fuehrungskraft', 'd', 'ungenuegend', 3, '{{Er|Sie|Er/Sie}} kann die Mitarbeitenden teilweise nur schwer motivieren und erteilt manchmal unzureichende Handlungsanweisungen.'),
('lenkung_arbeitsleistung', 'fuehrung', 'fuehrungskraft', 'd', 'genuegend', 1, '{{Er|Sie|Er/Sie}} fördert die Arbeitsleistung {{seiner|ihrer|seiner/ihrer}} Mitarbeitenden bewusst. Gleichzeitig unterstützt {{er|sie|er/sie}} durch erreichbare und messbare Zielsetzungen.'),
('lenkung_arbeitsleistung', 'fuehrung', 'fuehrungskraft', 'd', 'genuegend', 2, '{{Er|Sie|Er/Sie}} kann {{seine|ihre|seine/ihre}} Mitarbeitenden zu guten Leistungen motivieren und erteilt dabei nachvollziehbare Handlungsanweisungen.'),
('lenkung_arbeitsleistung', 'fuehrung', 'fuehrungskraft', 'd', 'genuegend', 3, '{{Er|Sie|Er/Sie}} kann die Mitarbeitenden motivieren und erteilt ausreichende Handlungsanweisungen.'),
('lenkung_arbeitsleistung', 'fuehrung', 'fuehrungskraft', 'd', 'gut', 1, '{{Er|Sie|Er/Sie}} fördert die Arbeitsleistung {{seiner|ihrer|seiner/ihrer}} Mitarbeitenden sehr bewusst. Gleichzeitig motiviert {{er|sie|er/sie}} durch anspruchsvolle, erreichbare und messbare Zielsetzungen.'),
('lenkung_arbeitsleistung', 'fuehrung', 'fuehrungskraft', 'd', 'gut', 2, 'Anhand klarer und erreichbarer Zielvorgaben motiviert {{er|sie|er/sie}} {{sein|ihr|sein/ihr}} Team stets zu guten Ergebnissen. Darüber hinaus versteht {{er|sie|er/sie}} es, allen Beteiligten nachvollziehbare Handlungsanweisungen zu erteilen.'),
('lenkung_arbeitsleistung', 'fuehrung', 'fuehrungskraft', 'd', 'gut', 3, '{{Er|Sie|Er/Sie}} kann die Mitarbeitenden zielbezogen motivieren und erteilt klare Handlungsanweisungen.'),
('lenkung_arbeitsleistung', 'fuehrung', 'fuehrungskraft', 'd', 'sehr_gut', 1, '{{Er|Sie|Er/Sie}} fördert die Arbeitsleistung {{seiner|ihrer|seiner/ihrer}} Mitarbeitenden bemerkenswert. Gleichzeitig motiviert {{er|sie|er/sie}} perfekt und umsichtig durch anspruchsvolle, erreichbare und messbare Zielsetzungen.'),
('lenkung_arbeitsleistung', 'fuehrung', 'fuehrungskraft', 'd', 'sehr_gut', 2, 'Anhand klarer und erreichbarer Zielvorgaben motiviert {{er|sie|er/sie}} {{sein|ihr|sein/ihr}} Team zu anhaltend sehr guten Ergebnissen. Darüber hinaus versteht {{er|sie|er/sie}} es bestens, allen Beteiligten nachvollziehbare Handlungsanweisungen zu erteilen.'),
('lenkung_arbeitsleistung', 'fuehrung', 'fuehrungskraft', 'd', 'sehr_gut', 3, '{{Er|Sie|Er/Sie}} versteht es, die Mitarbeitenden überzeugend und zielbezogen zu motivieren. {{Er|Sie|Er/Sie}} erteilt präzise, nachvollziehbare Handlungsanweisungen.'),
('aktives_change_management', 'fuehrung', 'fuehrungskraft', 'd', 'ungenuegend', 1, '{{Seine|Ihre|Seine/Ihre}} Mitarbeitenden unterstützt {{er|sie|er/sie}} gewissenhaft, sodass diese auf Veränderungen vorbereitet sind und angemessen damit umgehen können.'),
('aktives_change_management', 'fuehrung', 'fuehrungskraft', 'd', 'ungenuegend', 2, '{{Seine|Ihre|Seine/Ihre}} Mitarbeitenden unterstützt {{er|sie|er/sie}} bei Veränderungsprozessen, sodass diese Neuerungen akzeptieren können.'),
('aktives_change_management', 'fuehrung', 'fuehrungskraft', 'd', 'ungenuegend', 3, '{{Er|Sie|Er/Sie}} bevorzugt es meist, am Bestehenden festzuhalten.'),
('aktives_change_management', 'fuehrung', 'fuehrungskraft', 'd', 'genuegend', 1, '{{Seine|Ihre|Seine/Ihre}} Mitarbeitenden unterstützt {{er|sie|er/sie}} aufmerksam, sodass diese auf Veränderungen vorbereitet sind und gut damit umgehen können.'),
('aktives_change_management', 'fuehrung', 'fuehrungskraft', 'd', 'genuegend', 2, '{{Seine|Ihre|Seine/Ihre}} Mitarbeitenden unterstützt {{er|sie|er/sie}}, sodass diese auf Veränderungen vorbereitet sind und angemessen damit umgehen können.'),
('aktives_change_management', 'fuehrung', 'fuehrungskraft', 'd', 'genuegend', 3, '{{Er|Sie|Er/Sie}} hat wiederholt gute Ideen.'),
('aktives_change_management', 'fuehrung', 'fuehrungskraft', 'd', 'gut', 1, '{{Seine|Ihre|Seine/Ihre}} Mitarbeitenden unterstützt {{er|sie|er/sie}} aufmerksam und umsichtig, sodass diese rechtzeitig auf Veränderungen vorbereitet sind und mit Akzeptanz damit umgehen können.'),
('aktives_change_management', 'fuehrung', 'fuehrungskraft', 'd', 'gut', 2, '{{Seine|Ihre|Seine/Ihre}} Mitarbeitenden führt und unterstützt {{er|sie|er/sie}} bei Veränderungsprozessen umsichtig, sodass diese rechtzeitig auf Neuerungen vorbereitet sind und mit Akzeptanz damit umgehen können.'),
('aktives_change_management', 'fuehrung', 'fuehrungskraft', 'd', 'gut', 3, '{{Er|Sie|Er/Sie}} hat viele konkret umsetzbare Ideen.'),
('aktives_change_management', 'fuehrung', 'fuehrungskraft', 'd', 'sehr_gut', 1, '{{Seine|Ihre|Seine/Ihre}} Mitarbeitenden unterstützt {{er|sie|er/sie}} sehr aufmerksam und klug, sodass diese rechtzeitig auf Veränderungen bestens vorbereitet sind und mit grosser Akzeptanz damit umgehen können.'),
('aktives_change_management', 'fuehrung', 'fuehrungskraft', 'd', 'sehr_gut', 2, '{{Seine|Ihre|Seine/Ihre}} Mitarbeitenden führt und unterstützt {{er|sie|er/sie}} bei Veränderungsprozessen professionell und routiniert, sodass diese die Neuerungen aktiv mitunterstützen.'),
('aktives_change_management', 'fuehrung', 'fuehrungskraft', 'd', 'sehr_gut', 3, '{{Er|Sie|Er/Sie}} hat aussergewöhnlich viele erfolgreich umsetzbare Ideen.'),
('mitarbeiterfoerderung', 'fuehrung', 'fuehrungskraft', 'd', 'ungenuegend', 1, 'Ausserdem überlegt {{er|sie|er/sie}} sich mögliche Karriereperspektiven.'),
('mitarbeiterfoerderung', 'fuehrung', 'fuehrungskraft', 'd', 'ungenuegend', 2, '{{Er|Sie|Er/Sie}} zeigt {{seinen|ihren|seinen/ihren}} Mitarbeitenden Weiterbildungsmöglichkeiten auf.'),
('mitarbeiterfoerderung', 'fuehrung', 'fuehrungskraft', 'd', 'genuegend', 1, 'Ausserdem überlegt {{er|sie|er/sie}} sich Entwicklungsmöglichkeiten und mögliche Karriereperspektiven.'),
('mitarbeiterfoerderung', 'fuehrung', 'fuehrungskraft', 'd', 'genuegend', 2, '{{Er|Sie|Er/Sie}} versteht es, die Mitarbeitenden zu fördern und Weiterbildungsmöglichkeiten aufzuzeigen.'),
('mitarbeiterfoerderung', 'fuehrung', 'fuehrungskraft', 'd', 'gut', 1, 'Ausserdem plant {{er|sie|er/sie}} sinnvolle Entwicklungsmöglichkeiten und zeigt mögliche Karriereperspektiven auf.'),
('mitarbeiterfoerderung', 'fuehrung', 'fuehrungskraft', 'd', 'gut', 2, '{{Er|Sie|Er/Sie}} versteht es, die Talente {{seiner|ihrer|seiner/ihrer}} Mitarbeitenden zu erkennen und diese zu fördern. {{Er|Sie|Er/Sie}} ermöglicht auf die Funktion zugeschnittene Weiterbildungsmöglichkeiten und zeigt Entwicklungsperspektiven auf.'),
('mitarbeiterfoerderung', 'fuehrung', 'fuehrungskraft', 'd', 'sehr_gut', 1, 'Ausserdem plant {{er|sie|er/sie}} individuell zugeschnittene und sinnvolle Entwicklungsmöglichkeiten und zeigt interessante Karriereperspektiven auf.'),
('mitarbeiterfoerderung', 'fuehrung', 'fuehrungskraft', 'd', 'sehr_gut', 2, '{{Er|Sie|Er/Sie}} versteht es gekonnt, die Talente {{seiner|ihrer|seiner/ihrer}} Mitarbeitenden zu erkennen und diese entsprechend zu fördern. {{Er|Sie|Er/Sie}} ermöglicht auf die Funktion zugeschnittene Weiterbildungsmöglichkeiten und individuell interessante Entwicklungsperspektiven.'),
('wissensaustausch', 'fuehrung', 'fuehrungskraft', 'd', 'ungenuegend', 1, '{{Er|Sie|Er/Sie}} achtet in {{seinem|ihrem|seinem/ihrem}} Arbeitsbereich auf Zusammenarbeit und Informationsaustausch.'),
('wissensaustausch', 'fuehrung', 'fuehrungskraft', 'd', 'ungenuegend', 2, '{{Er|Sie|Er/Sie}} unterstützt in {{seinem|ihrem|seinem/ihrem}} Arbeitsbereich den Informationsaustausch.'),
('wissensaustausch', 'fuehrung', 'fuehrungskraft', 'd', 'ungenuegend', 3, '{{Er|Sie|Er/Sie}} achtet zu wenig auf einen ausreichenden Informations- und Wissensaustausch.'),
('wissensaustausch', 'fuehrung', 'fuehrungskraft', 'd', 'genuegend', 1, '{{Er|Sie|Er/Sie}} unterstützt in {{seinem|ihrem|seinem/ihrem}} Arbeitsbereich die Zusammenarbeit und den Informationsaustausch.'),
('wissensaustausch', 'fuehrung', 'fuehrungskraft', 'd', 'genuegend', 2, '{{Er|Sie|Er/Sie}} fördert den Informations- und Wissensaustausch.'),
('wissensaustausch', 'fuehrung', 'fuehrungskraft', 'd', 'genuegend', 3, '{{Er|Sie|Er/Sie}} achtet auf einen angemessenen Informations- und Wissensaustausch.'),
('wissensaustausch', 'fuehrung', 'fuehrungskraft', 'd', 'gut', 1, '{{Er|Sie|Er/Sie}} fördert im Unternehmen gezielt die Zusammenarbeit sowie einen wertvollen Informations- und Wissensaustausch.'),
('wissensaustausch', 'fuehrung', 'fuehrungskraft', 'd', 'gut', 2, '{{Er|Sie|Er/Sie}} fördert aktiv das Wissensmanagement durch einen sinnvollen Informations- und Wissensaustausch.'),
('wissensaustausch', 'fuehrung', 'fuehrungskraft', 'd', 'gut', 3, '{{Er|Sie|Er/Sie}} fördert einen wertvollen Informations- und Wissensaustausch.'),
('wissensaustausch', 'fuehrung', 'fuehrungskraft', 'd', 'sehr_gut', 1, '{{Er|Sie|Er/Sie}} fördert im Unternehmen gezielt und nachahmenswert die Zusammenarbeit sowie einen sehr wertvollen Informations- und Wissensaustausch.'),
('wissensaustausch', 'fuehrung', 'fuehrungskraft', 'd', 'sehr_gut', 2, '{{Er|Sie|Er/Sie}} fördert aktiv das Wissensmanagement durch einen gezielten und wertvollen Informations- und Wissensaustausch.'),
('wissensaustausch', 'fuehrung', 'fuehrungskraft', 'd', 'sehr_gut', 3, '{{Er|Sie|Er/Sie}} fördert gezielt einen sehr wertvollen Informations- und Wissensaustausch.'),
('strategieorientierung', 'fuehrung', 'fuehrungskraft', 'd', 'ungenuegend', 1, 'Visionen, Strategien und Ziele erläutert {{er|sie|er/sie}} den Vorgaben gemäss. Zudem bezieht {{er|sie|er/sie}} im Team entwickelte Ideen in die Entscheidungsfindung mit ein.'),
('strategieorientierung', 'fuehrung', 'fuehrungskraft', 'd', 'ungenuegend', 2, 'Strategien und Ziele erläutert {{er|sie|er/sie}} den Vorgaben gemäss.'),
('strategieorientierung', 'fuehrung', 'fuehrungskraft', 'd', 'genuegend', 1, 'Visionen, Strategien und Ziele erläutert {{er|sie|er/sie}} korrekt und schlüssig. Zudem bezieht {{er|sie|er/sie}} im Team entwickelte Ideen passend in die Entscheidungsfindung mit ein.'),
('strategieorientierung', 'fuehrung', 'fuehrungskraft', 'd', 'genuegend', 2, 'Strategien und Ziele erläutert {{er|sie|er/sie}} schlüssig und im Team entwickelte Ideen nimmt {{er|sie|er/sie}} in die Entscheidungsfindung mit auf.'),
('strategieorientierung', 'fuehrung', 'fuehrungskraft', 'd', 'gut', 1, 'Visionen, Strategien und Ziele erläutert {{er|sie|er/sie}} zuverlässig und umfassend. Zudem bezieht {{er|sie|er/sie}} im Team entwickelte Ideen klug in die Entscheidungsfindung mit ein.'),
('strategieorientierung', 'fuehrung', 'fuehrungskraft', 'd', 'gut', 2, 'Zudem denkt und handelt {{er|sie|er/sie}} strategisch, bezieht die jeweiligen Vorgaben mit ein und leitet die notwendigen Massnahmen auf {{seinen|ihren|seinen/ihren}} Verantwortungsbereich ab. Strategien und Ziele vermittelt {{er|sie|er/sie}} jeweils verständlich. Zudem integriert {{er|sie|er/sie}} im Team entwickelte Ideen in die Strategieorientierung.'),
('strategieorientierung', 'fuehrung', 'fuehrungskraft', 'd', 'sehr_gut', 1, 'Visionen, Strategien und Ziele erläutert {{er|sie|er/sie}} vortrefflich und umfassend. Zudem bezieht {{er|sie|er/sie}} im Team entwickelte Ideen in hervorragender Weise in die Entscheidungsfindung mit ein.'),
('strategieorientierung', 'fuehrung', 'fuehrungskraft', 'd', 'sehr_gut', 2, 'Zudem denkt und handelt {{er|sie|er/sie}} strategisch, bezieht die jeweiligen Vorgaben mit ein und leitet die notwendigen Massnahmen auf {{seinen|ihren|seinen/ihren}} Verantwortungsbereich ab. Strategien und Ziele vermittelt {{er|sie|er/sie}} jeweils vortrefflich. Zudem integriert {{er|sie|er/sie}} im Team entwickelte Ideen in hervorragender Weise in die Strategieorientierung.'),
('initiativ_fleiss', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'ungenuegend', 1, '{vorname} {nachname} zeigt Initiative und Fleiss in ausreichendem Masse.'),
('initiativ_fleiss', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'ungenuegend', 2, '{vorname} {nachname} erledigt die Arbeiten mehrheitlich auftragsgemäss.'),
('initiativ_fleiss', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'ungenuegend', 3, '{vorname} {nachname} fällt es teilweise schwer Initiative zu entwickeln und sich für {{seinen|ihren|seinen/ihren}} Aufgabenbereich zu engagieren.'),
('initiativ_fleiss', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'genuegend', 1, '{vorname} {nachname} zeigt Initiative und Fleiss.'),
('initiativ_fleiss', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'genuegend', 2, '{vorname} {nachname} erledigt die Arbeiten auftragsgemäss im Rahmen {{seines|ihres|seines/ihres}} Aufgabenbereichs.'),
('initiativ_fleiss', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'genuegend', 3, 'Mit der Initiative von {vorname} {nachname} und dem Engagement in {{seinem|ihrem|seinem/ihrem}} Aufgabenbereich sind wir zufrieden.'),
('initiativ_fleiss', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'gut', 1, '{vorname} {nachname} zeigt stets grosse Initiative und Fleiss.'),
('initiativ_fleiss', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'gut', 2, '{vorname} {nachname} ist initiativ und setzt sich vollumfänglich für {{seinen|ihren|seinen/ihren}} Aufgabenbereich ein.'),
('initiativ_fleiss', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'gut', 3, '{vorname} {nachname} ist initiativ und arbeitet mit Freude und Engagement in {{seinem|ihrem|seinem/ihrem}} Aufgabenbereich.'),
('initiativ_fleiss', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'sehr_gut', 1, '{vorname} {nachname} zeigt stets ausserordentliche Initiative und grossen Fleiss.'),
('initiativ_fleiss', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'sehr_gut', 2, '{vorname} {nachname} ist sehr initiativ und setzt sich überdurchschnittlich für {{seinen|ihren|seinen/ihren}} Aufgabenbereich ein.'),
('initiativ_fleiss', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'sehr_gut', 3, '{vorname} {nachname} ist äusserst initiativ und arbeitet mit viel Freude und grossem Engagement in {{seinem|ihrem|seinem/ihrem}} Aufgabenbereich.'),
('selbstaendigkeit_nach_eintritt', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'ungenuegend', 1, 'Nach einer Einarbeitungszeit arbeitet {{er|sie|er/sie}} selbständig und benötigt selten Unterstützung.'),
('selbstaendigkeit_nach_eintritt', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'ungenuegend', 2, 'Nach einer Einarbeitungszeit führt {{er|sie|er/sie}} die übertragenen Arbeiten mit fachlicher Unterstützung aus.'),
('selbstaendigkeit_nach_eintritt', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'genuegend', 1, 'Nach einer Einarbeitungszeit arbeitet {{er|sie|er/sie}} selbständig und findet sich in {{seinem|ihrem|seinem/ihrem}} Arbeitsbereich zurecht.'),
('selbstaendigkeit_nach_eintritt', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'genuegend', 2, 'Nach einer Einarbeitungszeit führt {{er|sie|er/sie}} die übertragenen Arbeiten pflichtbewusst aus und benötigt selten fachliche Unterstützung.'),
('selbstaendigkeit_nach_eintritt', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'gut', 1, 'Bereits nach kurzer Einarbeitungszeit arbeitet {{er|sie|er/sie}} sicher und selbständig.'),
('selbstaendigkeit_nach_eintritt', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'gut', 2, 'Bereits nach kurzer Einarbeitungszeit erledigt {{er|sie|er/sie}} {{seine|ihre|seine/ihre}} Aufgaben selbstständig. Dank {{seiner|ihrer|seiner/ihrer}} schnellen Auffassungsgabe erkennt {{er|sie|er/sie}} Zusammenhänge und kann sich auf neue Situationen einstellen.'),
('selbstaendigkeit_nach_eintritt', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'sehr_gut', 1, 'Bereits nach sehr kurzer Einarbeitungszeit erledigt {{er|sie|er/sie}} {{seine|ihre|seine/ihre}} Aufgaben vollkommen selbständig.'),
('selbstaendigkeit_nach_eintritt', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'sehr_gut', 2, 'Bereits nach kurzer Einarbeitungszeit erledigt {{er|sie|er/sie}} sämtliche Aufgaben sehr selbstständig. {{Er|Sie|Er/Sie}} zeichnet sich durch schnelle Auffassungsgabe aus, erkennt relevante Zusammenhänge und kann sich rasch auf neue Situationen einstellen.'),
('motivation_engagement', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'ungenuegend', 1, '{{Er|Sie|Er/Sie}} ist genügend motiviert und arbeitet sich erwartungsgemäss in neue Arbeitsgebiete ein.'),
('motivation_engagement', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'ungenuegend', 2, '{{Er|Sie|Er/Sie}} erledigt {{seine|ihre|seine/ihre}} Aufgaben erwartungsgemäss.'),
('motivation_engagement', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'ungenuegend', 3, '{{Er|Sie|Er/Sie}} lässt es teilweise am Engagement für {{sein|ihr|sein/ihr}} Arbeitsgebiet fehlen.'),
('motivation_engagement', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'genuegend', 1, '{{Er|Sie|Er/Sie}} ist motiviert und arbeitet sich mit Interesse in neue Arbeitsgebiete ein.'),
('motivation_engagement', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'genuegend', 2, '{{Er|Sie|Er/Sie}} setzt sich für {{seinen|ihren|seinen/ihren}} Aufgabenbereich ein und bearbeitet auch neue Arbeitsgebiete.'),
('motivation_engagement', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'genuegend', 3, '{{Er|Sie|Er/Sie}} engagiert sich für {{sein|ihr|sein/ihr}} Arbeitsgebiet.'),
('motivation_engagement', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'gut', 1, '{{Er|Sie|Er/Sie}} ist immer motiviert und arbeitet sich mit Engagement und Erfolg in neue Arbeitsgebiete ein.'),
('motivation_engagement', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'gut', 2, '{{Er|Sie|Er/Sie}} ist motiviert und setzt sich stets für {{seinen|ihren|seinen/ihren}} Aufgabenbereich ein. Mit Engagement bearbeitet {{er|sie|er/sie}} erfolgreich neue Arbeitsgebiete.'),
('motivation_engagement', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'gut', 3, '{{Er|Sie|Er/Sie}} engagiert sich vollumfänglich für {{sein|ihr|sein/ihr}} Arbeitsgebiet.'),
('motivation_engagement', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'sehr_gut', 1, '{{Er|Sie|Er/Sie}} ist immer hoch motiviert und arbeitet sich mit grossem Engagement und Erfolg in neue Arbeitsgebiete ein.'),
('motivation_engagement', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'sehr_gut', 2, '{{Er|Sie|Er/Sie}} ist hoch motiviert und setzt sich überdurchschnittlich für {{seinen|ihren|seinen/ihren}} Aufgabenbereich ein. Mit grossem Engagement bearbeitet {{er|sie|er/sie}} erfolgreich neue Arbeitsgebiete.'),
('motivation_engagement', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'sehr_gut', 3, '{{Er|Sie|Er/Sie}} engagiert sich überdurchschnittlich für {{sein|ihr|sein/ihr}} Arbeitsgebiet.'),
('unternehmensbeitrag', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'ungenuegend', 1, 'Aufgrund {{seiner|ihrer|seiner/ihrer}} Mitarbeit leistet {{er|sie|er/sie}} den erwarteten Beitrag in {{seinem|ihrem|seinem/ihrem}} Team.'),
('unternehmensbeitrag', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'ungenuegend', 2, 'Mit {{seinem|ihrem|seinem/ihrem}} Einsatz leistet {{er|sie|er/sie}} einen Beitrag im eigenen Verantwortungsbereich.'),
('unternehmensbeitrag', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'ungenuegend', 3, 'In {{seinem|ihrem|seinem/ihrem}} Denken und Handeln berücksichtigt {vorname} {nachname} übergeordnete Zielsetzungen der gesamten Organisation zu wenig konsequent, was sich auf die Ergebnisse im eigenen Verantwortungsbereich auswirkt.'),
('unternehmensbeitrag', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'genuegend', 1, 'Aufgrund {{seiner|ihrer|seiner/ihrer}} Mitarbeit leistet {{er|sie|er/sie}} einen angemessenen Beitrag in {{seinem|ihrem|seinem/ihrem}} Team.'),
('unternehmensbeitrag', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'genuegend', 2, 'Mit {{seinem|ihrem|seinem/ihrem}} Einsatz leistet {{er|sie|er/sie}} einen angemessenen Beitrag im eigenen Verantwortungsbereich.'),
('unternehmensbeitrag', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'genuegend', 3, 'In {{seinem|ihrem|seinem/ihrem}} Denken und Handeln berücksichtigt {vorname} {nachname} übergeordnete Zielsetzungen der gesamten Organisation und setzt sich für die Umsetzung und die Ergebnisse im eigenen Verantwortungsbereich ein.'),
('unternehmensbeitrag', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'gut', 1, 'Aufgrund {{seines|ihres|seines/ihres}} persönlichen Einsatzes leistet {{er|sie|er/sie}} einen achtbaren Beitrag zur Entwicklung unseres Unternehmens.'),
('unternehmensbeitrag', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'gut', 2, 'Aufgrund {{seines|ihres|seines/ihres}} persönlichen Einsatzes leistet {{er|sie|er/sie}} einen massgeblichen Beitrag zur Erfüllung der Aufträge. Dabei verhält {{er|sie|er/sie}} sich unterstützend, loyal und denkt mit.'),
('unternehmensbeitrag', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'gut', 3, '{{Sein|Ihr|Sein/Ihr}} Denken und Handeln richtet {vorname} {nachname} auf die Zielsetzungen der gesamten Organisation aus, und {{er|sie|er/sie}} übernimmt die Verantwortung für die Umsetzung und die Ergebnisse im eigenen Verantwortungsbereich.'),
('unternehmensbeitrag', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'sehr_gut', 1, 'Aufgrund {{seines|ihres|seines/ihres}} hohen persönlichen Einsatzes leistet {{er|sie|er/sie}} einen bedeutenden Beitrag zur Entwicklung unseres Unternehmens.'),
('unternehmensbeitrag', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'sehr_gut', 2, 'Aufgrund {{seines|ihres|seines/ihres}} hohen persönlichen Einsatzes leistet {{er|sie|er/sie}} einen bedeutenden Beitrag zur Erfüllung der Aufträge. Dabei verhält {{er|sie|er/sie}} sich sehr unterstützend, loyal und verfügt über eine interdisziplinäre Denkweise.'),
('unternehmensbeitrag', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'sehr_gut', 3, '{{Sein|Ihr|Sein/Ihr}} Denken und Handeln richtet {vorname} {nachname} konsequent auf die Zielsetzungen der gesamten Organisation aus, und {{er|sie|er/sie}} übernimmt die volle Verantwortung für die Umsetzung und die Ergebnisse im eigenen Verantwortungsbereich.'),
('berufserfahrung', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'ungenuegend', 1, '{vorname} {nachname} beherrscht {{sein|ihr|sein/ihr}} Arbeitsgebiet unseren Erwartungen entsprechend.'),
('berufserfahrung', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'ungenuegend', 2, '{vorname} {nachname} verfügt über erste Erfahrungen im Arbeitsgebiet.'),
('berufserfahrung', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'ungenuegend', 3, '{vorname} {nachname} weist eine begrenzte Erfahrung im Aufgabengebiet auf.'),
('berufserfahrung', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'genuegend', 1, '{vorname} {nachname} beherrscht {{sein|ihr|sein/ihr}} Arbeitsgebiet angemessen.'),
('berufserfahrung', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'genuegend', 2, '{vorname} {nachname} verfügt über die erforderliche Erfahrung im Arbeitsgebiet.'),
('berufserfahrung', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'genuegend', 3, '{vorname} {nachname} hat die nötige Erfahrung im Aufgabengebiet.'),
('berufserfahrung', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'gut', 1, '{vorname} {nachname} verfügt über umfassende Berufserfahrung und beherrscht {{seinen|ihren|seinen/ihren}} Arbeitsbereich sicher.'),
('berufserfahrung', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'gut', 2, '{vorname} {nachname} verfügt über eine umfangreiche Erfahrung im Aufgabengebiet.'),
('berufserfahrung', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'gut', 3, '{vorname} {nachname} hat eine umfangreiche Erfahrung in {{seinem|ihrem|seinem/ihrem}} Aufgabengebiet, vereinzelt auch in angrenzenden Fachbereichen.'),
('berufserfahrung', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'sehr_gut', 1, '{vorname} {nachname} verfügt über sehr grosse Berufserfahrung und beherrscht {{seinen|ihren|seinen/ihren}} Arbeitsbereich in jeder Weise umfassend, sicher und vollkommen.'),
('berufserfahrung', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'sehr_gut', 2, '{vorname} {nachname} verfügt über eine besonders umfangreiche Erfahrung im Aufgabengebiet sowie in Nachbardisziplinen. {{Er|Sie|Er/Sie}} teilt zudem {{sein|ihr|sein/ihr}} Wissen mit anderen Mitarbeitenden.'),
('berufserfahrung', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'sehr_gut', 3, '{vorname} {nachname} hat eine überdurchschnittliche Erfahrung in {{seinem|ihrem|seinem/ihrem}} Aufgabengebiet wie auch in angrenzenden Fachbereichen.'),
('fachliche_anforderungen', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'ungenuegend', 1, '{{Er|Sie|Er/Sie}} wird den fachlichen Anforderungen gerecht.'),
('fachliche_anforderungen', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'ungenuegend', 2, '{{Er|Sie|Er/Sie}} verfügt nur teilweise über das erforderliche Fachwissen.'),
('fachliche_anforderungen', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'genuegend', 1, '{{Er|Sie|Er/Sie}} stellt an sich selbst fachliche Anforderungen, die {{er|sie|er/sie}} erfüllt.'),
('fachliche_anforderungen', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'genuegend', 2, '{{Er|Sie|Er/Sie}} verfügt über ein abgerundetes Fachwissen.'),
('fachliche_anforderungen', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'gut', 1, '{{Er|Sie|Er/Sie}} stellt an sich selbst grosse fachliche Anforderungen, die {{er|sie|er/sie}} stets erfüllt.'),
('fachliche_anforderungen', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'gut', 2, '{{Er|Sie|Er/Sie}} verfügt über ein fundiertes Fachwissen.'),
('fachliche_anforderungen', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'sehr_gut', 1, '{{Er|Sie|Er/Sie}} stellt an sich selbst hohe fachliche Anforderungen, die {{er|sie|er/sie}} stets vollumfänglich erfüllt.'),
('fachliche_anforderungen', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'sehr_gut', 2, '{{Er|Sie|Er/Sie}} verfügt über ein hervorragendes, in die Tiefe gehendes Fachwissen.'),
('verantwortung_aufgabenbewaeltigung', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'ungenuegend', 1, 'Bei der Ausführung von Aufträgen zeigt {{er|sie|er/sie}} keine Unsicherheiten.'),
('verantwortung_aufgabenbewaeltigung', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'ungenuegend', 2, 'Die Auswirkungen {{seiner|ihrer|seiner/ihrer}} Handlungen kann {{er|sie|er/sie}} mehrheitlich einschätzen. {{Seine|Ihre|Seine/Ihre}} Aufträge führt {{er|sie|er/sie}} mit Unterstützung aus.'),
('verantwortung_aufgabenbewaeltigung', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'ungenuegend', 3, 'Probleme in {{seinem|ihrem|seinem/ihrem}} Verantwortungsbereich erkennt {{er|sie|er/sie}} nicht immer im erwarteten Ausmass und {{sein|ihr|sein/ihr}} Beitrag zu deren Lösung ist teilweise bescheiden.'),
('verantwortung_aufgabenbewaeltigung', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'ungenuegend', 4, 'Die Auswirkungen {{seiner|ihrer|seiner/ihrer}} Handlungen und die damit verbundenen Chancen und Risiken sind {{ihm|ihr|ihm/ihr}} manchmal nicht voll bewusst. Teilweise mangelt es {{ihm|ihr|ihm/ihr}} am notwendigen Verantwortungsbewusstsein.'),
('verantwortung_aufgabenbewaeltigung', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'genuegend', 1, 'Bei {{seinen|ihren|seinen/ihren}} Aufträgen übernimmt {{er|sie|er/sie}} Verantwortung und führt sie zum gewünschten Abschluss.'),
('verantwortung_aufgabenbewaeltigung', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'genuegend', 2, 'Die Auswirkungen {{seiner|ihrer|seiner/ihrer}} Handlungen kann {{er|sie|er/sie}} einschätzen. Bei {{seinen|ihren|seinen/ihren}} Aufträgen geht {{er|sie|er/sie}} verantwortungsbewusst vor und bringt diese zum Abschluss.'),
('verantwortung_aufgabenbewaeltigung', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'genuegend', 3, 'Probleme in {{seinem|ihrem|seinem/ihrem}} Verantwortungsbereich vermag {{er|sie|er/sie}} zu erkennen und zu beheben.'),
('verantwortung_aufgabenbewaeltigung', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'genuegend', 4, 'Die Auswirkungen {{seiner|ihrer|seiner/ihrer}} Handlungen kann {{er|sie|er/sie}} einschätzen und bezieht Chancen wie auch Risiken in {{seine|ihre|seine/ihre}} Überlegungen mit ein. {{Er|Sie|Er/Sie}} handelt verantwortungsvoll.'),
('verantwortung_aufgabenbewaeltigung', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'gut', 1, 'Jederzeit übernimmt {{er|sie|er/sie}} bei schwierigen Aufträgen Verantwortung und führt die Arbeiten mit Können zu einem gelungenen Abschluss.'),
('verantwortung_aufgabenbewaeltigung', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'gut', 2, 'Die Auswirkungen {{seiner|ihrer|seiner/ihrer}} Handlungen schätzt {{er|sie|er/sie}} realistisch ein und wägt Chancen wie auch Risiken ab. {{Er|Sie|Er/Sie}} übernimmt stets Verantwortung und führt Aufträge zum gewünschten Abschluss.'),
('verantwortung_aufgabenbewaeltigung', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'gut', 3, 'Probleme in {{seinem|ihrem|seinem/ihrem}} Aufgabenbereich erkennt {{er|sie|er/sie}} und liefert einen wesentlichen Beitrag zu deren Lösung.'),
('verantwortung_aufgabenbewaeltigung', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'gut', 4, 'Die Auswirkungen und Folgen {{seiner|ihrer|seiner/ihrer}} Handlungen schätzt {{er|sie|er/sie}} realistisch ein und wägt Chancen wie auch Risiken sorgfältig ab. {{Er|Sie|Er/Sie}} handelt durchdacht und verantwortungsvoll.'),
('verantwortung_aufgabenbewaeltigung', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'sehr_gut', 1, 'Jederzeit übernimmt {{er|sie|er/sie}} bei schwierigsten Aufträgen Verantwortung und führt die Arbeiten mit Geschick und Können zu einem hervorragenden Abschluss.'),
('verantwortung_aufgabenbewaeltigung', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'sehr_gut', 2, 'Die Auswirkungen {{seiner|ihrer|seiner/ihrer}} Handlungen schätzt {{er|sie|er/sie}} sehr realistisch ein und wägt Chancen wie auch Risiken situationsgerecht ab. {{Er|Sie|Er/Sie}} übernimmt stets Verantwortung und führt Aufträge zielsicher zu einem erfolgreichen Abschluss.'),
('verantwortung_aufgabenbewaeltigung', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'sehr_gut', 3, 'Probleme in {{seinem|ihrem|seinem/ihrem}} Verantwortungsbereich erkennt {{er|sie|er/sie}} sofort und findet eigenständig überzeugende Lösungen.'),
('verantwortung_aufgabenbewaeltigung', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'sehr_gut', 4, 'Die Tragweite und die Auswirkungen {{seiner|ihrer|seiner/ihrer}} Handlungen schätzt {{er|sie|er/sie}} realistisch ein und wägt Chancen wie auch Risiken jederzeit sorgfältig ab. {{Er|Sie|Er/Sie}} übernimmt stets für {{seine|ihre|seine/ihre}} Handlungen die volle Verantwortung.'),
('auffassungsgabe', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'ungenuegend', 1, 'Neues nimmt {{er|sie|er/sie}} auf und versucht es in {{seinem|ihrem|seinem/ihrem}} Aufgabengebiet umzusetzen.'),
('auffassungsgabe', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'ungenuegend', 2, 'Neues nimmt {{er|sie|er/sie}} auf und kann es unter Anleitung in {{seinem|ihrem|seinem/ihrem}} Aufgabengebiet umsetzen.'),
('auffassungsgabe', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'ungenuegend', 3, '{{Er|Sie|Er/Sie}} setzt erworbenes Wissen nicht mit dem gewünschten Erfolg in die Praxis um und findet sich in neuen Aufgaben nur mit Unterstützung zurecht.'),
('auffassungsgabe', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'genuegend', 1, 'Neues nimmt {{er|sie|er/sie}} gut auf und setzt es in {{seinem|ihrem|seinem/ihrem}} Aufgabengebiet um.'),
('auffassungsgabe', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'genuegend', 2, 'Neues Wissen vermag {{er|sie|er/sie}} gut in {{seinem|ihrem|seinem/ihrem}} Aufgabengebiet umzusetzen.'),
('auffassungsgabe', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'genuegend', 3, '{{Er|Sie|Er/Sie}} setzt erworbenes Wissen in die Praxis um und findet sich dank {{seiner|ihrer|seiner/ihrer}} Umsicht auch in neuen Aufgaben zurecht.'),
('auffassungsgabe', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'gut', 1, 'Neues kann {{er|sie|er/sie}} mit vorhandenem Wissen vernetzen, da {{er|sie|er/sie}} Aufgaben rasch erfasst.'),
('auffassungsgabe', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'gut', 2, 'Durch {{seine|ihre|seine/ihre}} rasche Auffassungsgabe und dank {{seinem|ihrem|seinem/ihrem}} analytischen Denkvermögen findet {{er|sie|er/sie}} schnell zu umsetzbaren Lösungen.'),
('auffassungsgabe', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'gut', 3, '{{Er|Sie|Er/Sie}} setzt erworbenes Wissen erfolgreich in die Praxis um und findet sich dank {{seiner|ihrer|seiner/ihrer}} guten Auffassungsgabe auch in neuen Aufgaben schnell zurecht.'),
('auffassungsgabe', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'sehr_gut', 1, 'Neues vernetzt {{er|sie|er/sie}} sehr schnell mit vorhandenem Wissen, da {{er|sie|er/sie}} komplexe Aufgaben denkbar rasch, gründlich und mit Leichtigkeit erfasst.'),
('auffassungsgabe', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'sehr_gut', 2, 'Durch {{seine|ihre|seine/ihre}} äusserst rasche Auffassungsgabe und dank {{seinem|ihrem|seinem/ihrem}} analytischen Denkvermögen findet {{er|sie|er/sie}} auch für schwierige Probleme schnell zu umsetzbaren Lösungen. Zudem besitzt {{er|sie|er/sie}} eine ausgesprochene Stärke im vernetzten Denken sowie im Antizipieren von Entwicklungen.'),
('auffassungsgabe', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'sehr_gut', 3, '{{Er|Sie|Er/Sie}} setzt erworbenes Wissen vorbildlich in die Praxis um und findet sich in neuen Aufgaben dank {{seiner|ihrer|seiner/ihrer}} ausgeprägten Auffassungsgabe leicht zurecht.'),
('auffassungsgabe', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'sehr_gut', 4, 'Auffassungsgabe'),
('innovation', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'ungenuegend', 1, 'Ferner überlegt {{er|sie|er/sie}} sich Neuerungen und bringt diese Ideen ein.'),
('innovation', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'ungenuegend', 2, 'Ferner stützt {{er|sie|er/sie}} sich auf Bestehendes.'),
('innovation', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'ungenuegend', 3, '{{Er|Sie|Er/Sie}} wirkt an Neuerungen zum Teil nur zögernd mit.'),
('innovation', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'genuegend', 1, 'Ferner bringt {{er|sie|er/sie}} eigene gute Ideen ein.'),
('innovation', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'genuegend', 2, 'Ferner bringt {{er|sie|er/sie}} Ideen ein.'),
('innovation', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'genuegend', 3, 'Ferner ist {{er|sie|er/sie}} interessiert an Neuerungen mitzuwirken.'),
('innovation', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'gut', 1, 'Ferner bringt {{er|sie|er/sie}} frische und umsetzbare Ideen ein.'),
('innovation', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'gut', 2, 'Ferner bringt {{er|sie|er/sie}} umsetzbare Ideen ein.'),
('innovation', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'gut', 3, 'Ferner wirkt {{er|sie|er/sie}} an Neuerungen gestaltend mit.'),
('innovation', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'sehr_gut', 1, 'Ferner bringt {{er|sie|er/sie}} innovative, zukunftweisende und umsetzbare Ideen ein.'),
('innovation', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'sehr_gut', 2, 'Ferner wirkt {{er|sie|er/sie}} an Neuerungen tatkräftig und gestaltend mit.'),
('ausdauer_belastbarkeit', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'ungenuegend', 1, 'Ausserdem ist {{er|sie|er/sie}} ein {{Mitarbeitender|Mitarbeitende|Mitarbeitende/r}}, {{der|die|der/die}} {{seine|ihre|seine/ihre}} Aufgaben grösstenteils gut bewältigt.'),
('ausdauer_belastbarkeit', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'ungenuegend', 2, 'Unter anspruchsvollen Arbeitsbedingungen vermag {{er|sie|er/sie}} den an {{ihn|sie|ihn/sie}} gestellten Anforderungen nicht immer nachzukommen.'),
('ausdauer_belastbarkeit', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'ungenuegend', 3, '{{Er|Sie|Er/Sie}} arbeitet ohne Zeitdruck zuverlässig.'),
('ausdauer_belastbarkeit', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'genuegend', 1, 'Ausserdem ist {{er|sie|er/sie}} ein {{belastbarer|belastbare|belastbare/r}} {{Mitarbeitender|Mitarbeitende|Mitarbeitende/r}}, {{der|die|der/die}} {{seine|ihre|seine/ihre}} Aufgaben in der Regel gut bewältigt.'),
('ausdauer_belastbarkeit', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'genuegend', 2, 'Auch unter anspruchsvollen Arbeitsbedingungen bewältigt {{er|sie|er/sie}} {{seine|ihre|seine/ihre}} Aufgaben zufriedenstellend.'),
('ausdauer_belastbarkeit', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'genuegend', 3, '{{Er|Sie|Er/Sie}} arbeitet auch bei gestiegenen Anforderungen gleichmässig und ausdauernd.'),
('ausdauer_belastbarkeit', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'gut', 1, 'Auch unter schwierigen Arbeitsbedingungen ist {{er|sie|er/sie}} ein {{ausdauernder|ausdauernde|ausdauernde/r}} und {{belastbarer|belastbare|belastbare/r}} {{Mitarbeitender|Mitarbeitende|Mitarbeitende/r}}, {{der|die|der/die}} alle Anforderungen stets gut bewältigt.'),
('ausdauer_belastbarkeit', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'gut', 2, 'Auch unter anspruchsvollen Arbeitsbedingungen ist {{er|sie|er/sie}} ein {{ausdauernder|ausdauernde|ausdauernde/r}} und {{belastbarer|belastbare|belastbare/r}} {{Mitarbeitender|Mitarbeitende|Mitarbeitende/r}}, {{der|die|der/die}} alle Anforderungen stets gut bewältigt.'),
('ausdauer_belastbarkeit', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'gut', 3, '{{Er|Sie|Er/Sie}} arbeitet auch bei hohen Anforderungen konzentriert und erbringt eine konstant gute Leistung.'),
('ausdauer_belastbarkeit', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'sehr_gut', 1, 'Auch unter schwierigen Arbeitsbedingungen ist {{er|sie|er/sie}} ein {{ausdauernder|ausdauernde|ausdauernde/r}} und ausserordentlich {{belastbarer|belastbare|belastbare/r}} {{Mitarbeitender|Mitarbeitende|Mitarbeitende/r}}, {{der|die|der/die}} allen Anforderungen stets sehr gut gewachsen ist.'),
('ausdauer_belastbarkeit', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'sehr_gut', 2, 'Auch unter anspruchsvollen Arbeitsbedingungen ist {{er|sie|er/sie}} ein {{ausdauernder|ausdauernde|ausdauernde/r}} und äusserst {{belastbarer|belastbare|belastbare/r}} {{Mitarbeitender|Mitarbeitende|Mitarbeitende/r}}, {{der|die|der/die}} alle Anforderungen stets sehr gut bewältigt. Dabei behält {{er|sie|er/sie}} die Übersicht und handelt überlegt.'),
('ausdauer_belastbarkeit', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'sehr_gut', 3, '{{Er|Sie|Er/Sie}} arbeitet auch bei höchsten Anforderungen sehr konzentriert und unermüdlich und erbringt eine hervorragende Leistung.'),
('fachkenntnisse_lernbereitschaft', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'ungenuegend', 1, '{vorname} {nachname} verfügt in {{seinem|ihrem|seinem/ihrem}} Gebiet über die nötigen Fachkenntnisse. Aufgrund {{seiner|ihrer|seiner/ihrer}} Lernbereitschaft kann {{er|sie|er/sie}} sich weiteres Wissen erarbeiten.'),
('fachkenntnisse_lernbereitschaft', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'ungenuegend', 2, '{vorname} {nachname} zeigt wenig Interesse an Weiterbildungsmöglichkeiten.'),
('fachkenntnisse_lernbereitschaft', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'ungenuegend', 3, 'Mit Entwicklungen im Berufsumfeld setzt {vorname} {nachname} sich nur teilweise auseinander und ist mit wichtigen Standards zu wenig vertraut.'),
('fachkenntnisse_lernbereitschaft', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'genuegend', 1, '{vorname} {nachname} verfügt in {{seinem|ihrem|seinem/ihrem}} Gebiet über fundierte Fachkenntnisse. Aufgrund {{seiner|ihrer|seiner/ihrer}} Lernbereitschaft kann {{er|sie|er/sie}} diese von Zeit zu Zeit erweitern.'),
('fachkenntnisse_lernbereitschaft', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'genuegend', 2, '{vorname} {nachname} verfügt in {{seinem|ihrem|seinem/ihrem}} Gebiet über ausreichende Fachkenntnisse. {{Er|Sie|Er/Sie}} bildet sich bei betrieblichem Bedarf weiter.'),
('fachkenntnisse_lernbereitschaft', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'genuegend', 3, 'Mit Entwicklungen im Berufsumfeld setzt {vorname} {nachname} sich auseinander und ist mit den aktuellen Standards vertraut.'),
('fachkenntnisse_lernbereitschaft', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'gut', 1, '{vorname} {nachname} verfügt über gute und fundierte Fachkenntnisse. {{Er|Sie|Er/Sie}} erweitert diese mit grosser Lernbereitschaft.'),
('fachkenntnisse_lernbereitschaft', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'gut', 2, '{vorname} {nachname} verfügt über gute und fundierte Fachkenntnisse. {{Er|Sie|Er/Sie}} erweitert diese fortlaufend, um auf dem neusten fachlichen Stand zu bleiben.'),
('fachkenntnisse_lernbereitschaft', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'gut', 3, 'Mit Entwicklungen im Berufsumfeld setzt {vorname} {nachname} sich auseinander und ist immer mit den aktuellen Standards vertraut.'),
('fachkenntnisse_lernbereitschaft', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'sehr_gut', 1, '{vorname} {nachname} verfügt über besonders umfassende und vielseitige Fachkenntnisse. {{Er|Sie|Er/Sie}} erweitert diese laufend mit grosser Lernbereitschaft.'),
('fachkenntnisse_lernbereitschaft', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'sehr_gut', 2, '{vorname} {nachname} verfügt über besonders umfassende und vielseitige Fachkenntnisse, welche {{er|sie|er/sie}} laufend mit grosser Lernbereitschaft erweitert, um jederzeit auf dem neusten fachlichen Stand zu bleiben. Darüber hinaus setzt {{er|sie|er/sie}} {{sein|ihr|sein/ihr}} hervorragendes Know-how stets effektiv und erfolgreich in der Praxis um.'),
('fachkenntnisse_lernbereitschaft', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'sehr_gut', 3, 'Mit Entwicklungen im Berufsumfeld setzt {vorname} {nachname} sich engagiert auseinander und ist immer mit den neuesten Standards vertraut.'),
('methodeneinsatz', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'ungenuegend', 1, 'Vorhandene Techniken wendet {{er|sie|er/sie}} den Vorgaben entsprechend in {{seiner|ihrer|seiner/ihrer}} Berufspraxis an.'),
('methodeneinsatz', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'ungenuegend', 2, 'Dem wirtschaftlichen, kostenbewussten und zweckmässigen Einsatz von Betriebsmitteln schenkt {{er|sie|er/sie}} teilweise zu wenig Beachtung.'),
('methodeneinsatz', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'genuegend', 1, 'Vorhandene Methoden und Techniken wendet {{er|sie|er/sie}} richtig in {{seiner|ihrer|seiner/ihrer}} Berufspraxis an.'),
('methodeneinsatz', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'genuegend', 2, 'Vorhandene Methoden, Mittel und Techniken wendet {{er|sie|er/sie}} an.'),
('methodeneinsatz', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'genuegend', 3, 'Betriebsmittel setzt {{er|sie|er/sie}} meistens wirtschaftlich, kostenbewusst und zweckmässig ein.'),
('methodeneinsatz', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'gut', 1, 'Vorhandene Methoden, Instrumente und Techniken wendet {{er|sie|er/sie}} wirksam in {{seiner|ihrer|seiner/ihrer}} Berufspraxis an.'),
('methodeneinsatz', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'gut', 2, 'Methoden, Mittel und Techniken wendet {{er|sie|er/sie}} jederzeit wirksam an.'),
('methodeneinsatz', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'gut', 3, 'Betriebsmittel setzt {{er|sie|er/sie}} wirtschaftlich, kostenbewusst und zweckmässig ein.'),
('methodeneinsatz', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'sehr_gut', 1, 'Vorhandene Methoden, Instrumente und Techniken wendet {{er|sie|er/sie}} jederzeit sehr wirksam in {{seiner|ihrer|seiner/ihrer}} Berufspraxis an.'),
('methodeneinsatz', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'sehr_gut', 2, 'Methoden, Mittel und Techniken wendet {{er|sie|er/sie}} jederzeit sehr wirksam an.'),
('methodeneinsatz', 'arbeitsbereitschaft_fachwissen', 'mitarbeiter', 'd', 'sehr_gut', 3, 'Betriebsmittel setzt {{er|sie|er/sie}} äusserst wirtschaftlich, kostenbewusst und zweckmässig ein.'),
('verlaesslichkeit_pflichtbewusstsein', 'arbeitsweise_leistung', 'mitarbeiter', 'd', 'ungenuegend', 1, '{vorname} {nachname} ist {{ein|eine|ein/eine}} {{pflichtbewusster|pflichtbewusste|pflichtbewusster/pflichtbewusste}} {{Mitarbeitender|Mitarbeitende|Mitarbeitende/r}}.'),
('verlaesslichkeit_pflichtbewusstsein', 'arbeitsweise_leistung', 'mitarbeiter', 'd', 'ungenuegend', 2, '{vorname} {nachname} ist {{ein|eine|ein/eine}} {{pflichtbewusster|pflichtbewusste|pflichtbewusster/pflichtbewusste}} {{Mitarbeitender|Mitarbeitende|Mitarbeitende/r}}.'),
('verlaesslichkeit_pflichtbewusstsein', 'arbeitsweise_leistung', 'mitarbeiter', 'd', 'ungenuegend', 3, '{vorname} {nachname} fühlt sich {{seiner|ihrer|seiner/ihrer}} Aufgabe und der Verwaltung nur bedingt verpflichtet.'),
('verlaesslichkeit_pflichtbewusstsein', 'arbeitsweise_leistung', 'mitarbeiter', 'd', 'genuegend', 1, '{vorname} {nachname} ist {{ein|eine|ein/eine}} {{pflichtbewusster|pflichtbewusste|pflichtbewusster/pflichtbewusste}} und {{verlässlicher|verlässliche|verlässlicher/verlässliche}} {{Mitarbeitender|Mitarbeitende|Mitarbeitende/r}}.'),
('verlaesslichkeit_pflichtbewusstsein', 'arbeitsweise_leistung', 'mitarbeiter', 'd', 'genuegend', 2, 'Wir lernten {vorname} {nachname} als {{einen|eine|einen/eine}} {{zuverlässigen|zuverlässige|zuverlässigen/zuverlässige}} {{Mitarbeiter|Mitarbeiterin|Mitarbeiter/in}} kennen, {{der|die|der/die}} sich {{seiner|ihrer|seiner/ihrer}} Aufgabe und der Verwaltung verpflichtet fühlt.'),
('verlaesslichkeit_pflichtbewusstsein', 'arbeitsweise_leistung', 'mitarbeiter', 'd', 'gut', 1, '{vorname} {nachname} ist {{ein|eine|ein/eine}} sehr {{konzentrierter|konzentrierte|konzentrierter/konzentrierte}}, {{pflichtbewusster|pflichtbewusste|pflichtbewusster/pflichtbewusste}} und {{verlässlicher|verlässliche|verlässlicher/verlässliche}} {{Mitarbeitender|Mitarbeitende|Mitarbeitende/r}}.'),
('verlaesslichkeit_pflichtbewusstsein', 'arbeitsweise_leistung', 'mitarbeiter', 'd', 'gut', 2, 'Wir schätzen {vorname} {nachname} als {{einen|eine|einen/eine}} {{pflichtbewussten|pflichtbewusste|pflichtbewussten/pflichtbewusste}} und {{verlässlichen|verlässliche|verlässlichen/verlässliche}} {{Mitarbeitenden|Mitarbeitende|Mitarbeitenden/Mitarbeitende}}.'),
('verlaesslichkeit_pflichtbewusstsein', 'arbeitsweise_leistung', 'mitarbeiter', 'd', 'gut', 3, 'Wir erleben {vorname} {nachname} als {{einen|eine|einen/eine}} {{wertvollen|wertvolle|wertvollen/wertvolle}} {{Mitarbeiter|Mitarbeiterin|Mitarbeiter/in}}, {{der|die|der/die}} sich in anerkennenswerter Weise {{seiner|ihrer|seiner/ihrer}} Aufgabe und der Verwaltung verpflichtet fühlt.'),
('verlaesslichkeit_pflichtbewusstsein', 'arbeitsweise_leistung', 'mitarbeiter', 'd', 'sehr_gut', 1, '{vorname} {nachname} ist {{ein|eine|ein/eine}} äusserst {{konzentrierter|konzentrierte|konzentrierter/konzentrierte}}, {{pflichtbewusster|pflichtbewusste|pflichtbewusster/pflichtbewusste}} und {{verlässlicher|verlässliche|verlässlicher/verlässliche}} {{Mitarbeitender|Mitarbeitende|Mitarbeitende/r}}.'),
('verlaesslichkeit_pflichtbewusstsein', 'arbeitsweise_leistung', 'mitarbeiter', 'd', 'sehr_gut', 2, 'Wir schätzen {vorname} {nachname} als {{einen|eine|einen/eine}} äusserst {{pflichtbewussten|pflichtbewusste|pflichtbewussten/pflichtbewusste}} und {{verlässlichen|verlässliche|verlässlichen/verlässliche}} {{Mitarbeitenden|Mitarbeitende|Mitarbeitenden/Mitarbeitende}}.'),
('verlaesslichkeit_pflichtbewusstsein', 'arbeitsweise_leistung', 'mitarbeiter', 'd', 'sehr_gut', 3, 'Wir erleben {vorname} {nachname} als {{einen|eine|einen/eine}} äusserst {{wertvollen|wertvolle|wertvollen/wertvolle}} {{Mitarbeiter|Mitarbeiterin|Mitarbeiter/in}}, {{der|die|der/die}} sich in unverkennbarer Weise {{seiner|ihrer|seiner/ihrer}} Aufgabe und der Verwaltung verpflichtet fühlt.'),
('selbstaendigkeit_sorgfalt_genauigkeit', 'arbeitsweise_leistung', 'mitarbeiter', 'd', 'ungenuegend', 1, '{{Er|Sie|Er/Sie}} arbeitet {{seinen|ihren|seinen/ihren}} Möglichkeiten entsprechend selbständig und findet sich in den gestellten Aufgaben zurecht.'),
('selbstaendigkeit_sorgfalt_genauigkeit', 'arbeitsweise_leistung', 'mitarbeiter', 'd', 'ungenuegend', 2, '{{Er|Sie|Er/Sie}} arbeitet {{seinen|ihren|seinen/ihren}} Möglichkeiten entsprechend selbstständig und trifft Entscheidungen nach vorgängigen Abklärungen.'),
('selbstaendigkeit_sorgfalt_genauigkeit', 'arbeitsweise_leistung', 'mitarbeiter', 'd', 'ungenuegend', 3, '{{Er|Sie|Er/Sie}} kann Entscheidungen oft nur nach vorgängigen Rückfragen treffen.'),
('selbstaendigkeit_sorgfalt_genauigkeit', 'arbeitsweise_leistung', 'mitarbeiter', 'd', 'genuegend', 1, '{{Er|Sie|Er/Sie}} arbeitet grösstenteils selbständig und findet sich in {{seinem|ihrem|seinem/ihrem}} Arbeitsbereich zurecht. Dabei arbeitet {{er|sie|er/sie}} sorgfältig und genau.'),
('selbstaendigkeit_sorgfalt_genauigkeit', 'arbeitsweise_leistung', 'mitarbeiter', 'd', 'genuegend', 2, '{{Er|Sie|Er/Sie}} arbeitet sorgfältig und trifft Entscheidungen grösstenteils selbstständig.'),
('selbstaendigkeit_sorgfalt_genauigkeit', 'arbeitsweise_leistung', 'mitarbeiter', 'd', 'genuegend', 3, '{{Er|Sie|Er/Sie}} trifft Entscheidungen mit Sachverstand und wenigen Rückfragen.'),
('selbstaendigkeit_sorgfalt_genauigkeit', 'arbeitsweise_leistung', 'mitarbeiter', 'd', 'gut', 1, '{{Er|Sie|Er/Sie}} arbeitet sicher und selbständig. Dabei trifft {{er|sie|er/sie}} gute Entscheide und arbeitet mit ausserordentlicher Sorgfalt und Genauigkeit.'),
('selbstaendigkeit_sorgfalt_genauigkeit', 'arbeitsweise_leistung', 'mitarbeiter', 'd', 'gut', 2, '{{Er|Sie|Er/Sie}} arbeitet effizient und genau. Entscheidungen trifft {{er|sie|er/sie}} selbstständig und mit Sachkenntnis.'),
('selbstaendigkeit_sorgfalt_genauigkeit', 'arbeitsweise_leistung', 'mitarbeiter', 'd', 'gut', 3, '{{Er|Sie|Er/Sie}} trifft Entscheidungen selbstständig und mit viel Sachkenntnis.'),
('selbstaendigkeit_sorgfalt_genauigkeit', 'arbeitsweise_leistung', 'mitarbeiter', 'd', 'sehr_gut', 1, '{{Er|Sie|Er/Sie}} arbeitet sicher und selbständig. Dabei trifft {{er|sie|er/sie}} stets die richtigen Entscheide und arbeitet mit beispielhafter Sorgfalt und Genauigkeit.'),
('selbstaendigkeit_sorgfalt_genauigkeit', 'arbeitsweise_leistung', 'mitarbeiter', 'd', 'sehr_gut', 2, '{{Er|Sie|Er/Sie}} arbeitet sehr effizient und genau. Entscheidungen trifft {{er|sie|er/sie}} situationsgerecht, sehr selbstständig und mit grosser Sachkenntnis.'),
('selbstaendigkeit_sorgfalt_genauigkeit', 'arbeitsweise_leistung', 'mitarbeiter', 'd', 'sehr_gut', 3, '{{Er|Sie|Er/Sie}} trifft Entscheidungen sehr selbstständig, vorausschauend und mit grosser Sachkenntnis.'),
('termintreue', 'arbeitsweise_leistung', 'mitarbeiter', 'd', 'ungenuegend', 1, 'Termine hält {{er|sie|er/sie}} grundsätzlich ein.'),
('termintreue', 'arbeitsweise_leistung', 'mitarbeiter', 'd', 'ungenuegend', 2, '{{Er|Sie|Er/Sie}} beachtet allgemeine Richtlinien oder konkrete Vorgaben nicht immer mit der erforderlichen Sorgfalt.'),
('termintreue', 'arbeitsweise_leistung', 'mitarbeiter', 'd', 'genuegend', 1, 'Termine hält {{er|sie|er/sie}} meist zuverlässig ein.'),
('termintreue', 'arbeitsweise_leistung', 'mitarbeiter', 'd', 'genuegend', 2, '{{Er|Sie|Er/Sie}} hält Terminauflagen meist ein und befolgt weitgehend sowohl allgemeine Richtlinien als auch konkrete Vorgaben.'),
('termintreue', 'arbeitsweise_leistung', 'mitarbeiter', 'd', 'gut', 1, 'Termine hält {{er|sie|er/sie}} auch unter Belastung ein.'),
('termintreue', 'arbeitsweise_leistung', 'mitarbeiter', 'd', 'gut', 2, '{{Er|Sie|Er/Sie}} hält Terminauflagen ein und befolgt sowohl allgemeine Richtlinien als auch konkrete Vorgaben.'),
('termintreue', 'arbeitsweise_leistung', 'mitarbeiter', 'd', 'sehr_gut', 1, 'Termine hält {{er|sie|er/sie}} auch unter hoher Belastung zuverlässig ein.'),
('termintreue', 'arbeitsweise_leistung', 'mitarbeiter', 'd', 'sehr_gut', 2, 'Termine hält {{er|sie|er/sie}} auch unter hoher Belastung jederzeit zuverlässig ein.'),
('termintreue', 'arbeitsweise_leistung', 'mitarbeiter', 'd', 'sehr_gut', 3, '{{Er|Sie|Er/Sie}} unterschreitet häufig die Terminauflagen und hält sich ausnahmslos sowohl an allgemeine Richtlinien als auch konkrete Vorgaben.'),
('arbeitsorganisation', 'arbeitsweise_leistung', 'mitarbeiter', 'd', 'ungenuegend', 1, '{vorname} {nachname} kann geplante Aufgaben umsetzen.'),
('arbeitsorganisation', 'arbeitsweise_leistung', 'mitarbeiter', 'd', 'ungenuegend', 2, '{vorname} {nachname} benötigt Unterstützung bei der Arbeitsplanung.'),
('arbeitsorganisation', 'arbeitsweise_leistung', 'mitarbeiter', 'd', 'ungenuegend', 3, 'Das ungenügend ausgeprägte organisatorische Geschick von {vorname} {nachname} erfordert manchmal Vorgaben bei der Aufgabenerfüllung.'),
('arbeitsorganisation', 'arbeitsweise_leistung', 'mitarbeiter', 'd', 'ungenuegend', 4, '{vorname} {nachname} informiert spärlich über den eigenen Arbeitsbereich und unterschätzt teilweise den Informationsbedarf anderer Stellen. {Er|Sie|Er/Sie} meldet sich in schwierigen Situationen bei den Vorgesetzten manchmal zu spät.'),
('arbeitsorganisation', 'arbeitsweise_leistung', 'mitarbeiter', 'd', 'genuegend', 1, '{vorname} {nachname} kann geplante Aufgaben richtig umsetzen.'),
('arbeitsorganisation', 'arbeitsweise_leistung', 'mitarbeiter', 'd', 'genuegend', 2, '{vorname} {nachname} vermag die Aufgaben praxisgerecht zu organisieren.'),
('arbeitsorganisation', 'arbeitsweise_leistung', 'mitarbeiter', 'd', 'genuegend', 3, 'Dank {seiner|ihrer|seiner/ihrer} Umsicht organisiert {vorname} {nachname} Aufgaben und Projekte praxisgerecht.'),
('arbeitsorganisation', 'arbeitsweise_leistung', 'mitarbeiter', 'd', 'genuegend', 4, '{vorname} {nachname} informiert auf Verlangen angemessen über den eigenen Arbeitsbereich und leitet wichtige Informationen meistens weiter. {Er|Sie|Er/Sie} bezieht Vorgesetzte bei Bedarf mit ein.'),
('arbeitsorganisation', 'arbeitsweise_leistung', 'mitarbeiter', 'd', 'gut', 1, '{vorname} {nachname} plant und organisiert {seine|ihre|seine/ihre} Aufgaben gut und setzt Prioritäten bei der Erfüllung derselben.'),
('arbeitsorganisation', 'arbeitsweise_leistung', 'mitarbeiter', 'd', 'gut', 2, '{vorname} {nachname} plant und organisiert {seine|ihre|seine/ihre} Aufgaben effektiv und setzt klare Prioritäten.'),
('arbeitsorganisation', 'arbeitsweise_leistung', 'mitarbeiter', 'd', 'gut', 3, 'Dank {seiner|ihrer|seiner/ihrer} guten analytischen Fähigkeit plant und organisiert {vorname} {nachname} Aufgaben zweckmässig und setzt Prioritäten.'),
('arbeitsorganisation', 'arbeitsweise_leistung', 'mitarbeiter', 'd', 'gut', 4, '{vorname} {nachname} informiert zeitgerecht, umfassend über den eigenen Arbeitsbereich und leitet wichtige Informationen rechtzeitig weiter. {Er|Sie|Er/Sie} bezieht Vorgesetzte in schwierige Situationen mit ein.'),
('arbeitsorganisation', 'arbeitsweise_leistung', 'mitarbeiter', 'd', 'sehr_gut', 1, '{vorname} {nachname} plant und organisiert {seine|ihre|seine/ihre} Aufgaben gekonnt und setzt konsequent klare Prioritäten bei der Erfüllung derselben.'),
('arbeitsorganisation', 'arbeitsweise_leistung', 'mitarbeiter', 'd', 'sehr_gut', 2, '{vorname} {nachname} plant und organisiert {seine|ihre|seine/ihre} Aufgaben effektiv, systematisch und setzt klare Prioritäten.'),
('arbeitsorganisation', 'arbeitsweise_leistung', 'mitarbeiter', 'd', 'sehr_gut', 3, 'Dank {seiner|ihrer|seiner/ihrer} ausgeprägten analytischen Fähigkeit plant und organisiert {vorname} {nachname} Aufgaben systematisch und nach klaren Prioritäten.'),
('arbeitsorganisation', 'arbeitsweise_leistung', 'mitarbeiter', 'd', 'sehr_gut', 4, '{vorname} {nachname} informiert zeitgerecht, offen, umfassend über den eigenen Arbeitsbereich und leitet wichtige Informationen sofort an die richtigen Stellen weiter. {Er|Sie|Er/Sie} bezieht Vorgesetzte in schwierige Situationen rechtzeitig mit ein.'),
('arbeitsqualitaet', 'arbeitsweise_leistung', 'mitarbeiter', 'd', 'ungenuegend', 1, 'Mit {{seinen|ihren|seinen/ihren}} Arbeitsergebnissen strebt {{er|sie|er/sie}} Qualität an.'),
('arbeitsqualitaet', 'arbeitsweise_leistung', 'mitarbeiter', 'd', 'ungenuegend', 2, 'Die angestrebte Arbeitsqualität vermag {{er|sie|er/sie}} nur mit Unterstützung zu erreichen.'),
('arbeitsqualitaet', 'arbeitsweise_leistung', 'mitarbeiter', 'd', 'genuegend', 1, '{{Seine|Ihre|Seine/Ihre}} Arbeitsergebnisse sind von guter Qualität.'),
('arbeitsqualitaet', 'arbeitsweise_leistung', 'mitarbeiter', 'd', 'genuegend', 2, 'Mit der notwendigen Aufmerksamkeit erzielt {{er|sie|er/sie}} das geforderte Arbeitsergebnis.'),
('arbeitsqualitaet', 'arbeitsweise_leistung', 'mitarbeiter', 'd', 'gut', 1, '{{Seine|Ihre|Seine/Ihre}} Arbeitsergebnisse sind von überzeugender Qualität.'),
('arbeitsqualitaet', 'arbeitsweise_leistung', 'mitarbeiter', 'd', 'gut', 2, 'Durch {{seine|ihre|seine/ihre}} Sorgfalt und Gewissenhaftigkeit erzielt {{er|sie|er/sie}} ein einwandfreies Arbeitsergebnis.'),
('arbeitsqualitaet', 'arbeitsweise_leistung', 'mitarbeiter', 'd', 'sehr_gut', 1, '{{Seine|Ihre|Seine/Ihre}} Arbeitsergebnisse sind von beispielhafter Qualität.'),
('arbeitsqualitaet', 'arbeitsweise_leistung', 'mitarbeiter', 'd', 'sehr_gut', 2, 'Durch grösste Sorgfalt und Gewissenhaftigkeit erzielt {{er|sie|er/sie}} ein hochwertiges Arbeitsergebnis.'),
('zielerreichung', 'arbeitsweise_leistung', 'mitarbeiter', 'd', 'ungenuegend', 1, 'Dabei erreicht {{er|sie|er/sie}} meist viele vereinbarte Ziele.'),
('zielerreichung', 'arbeitsweise_leistung', 'mitarbeiter', 'd', 'ungenuegend', 2, 'Dabei erreicht {{er|sie|er/sie}} meist vereinbarte Ziele.'),
('zielerreichung', 'arbeitsweise_leistung', 'mitarbeiter', 'd', 'ungenuegend', 3, 'Die qualitativen und quantitativen Vorgaben erfüllt {{er|sie|er/sie}} nicht immer. Mit {{seinen|ihren|seinen/ihren}} Leistungen sind wir meist zufrieden.'),
('zielerreichung', 'arbeitsweise_leistung', 'mitarbeiter', 'd', 'genuegend', 1, 'Dabei erreicht {{er|sie|er/sie}} meist alle vereinbarten Ziele.'),
('zielerreichung', 'arbeitsweise_leistung', 'mitarbeiter', 'd', 'genuegend', 2, 'Dabei erreicht {{er|sie|er/sie}} vereinbarte Ziele.'),
('zielerreichung', 'arbeitsweise_leistung', 'mitarbeiter', 'd', 'genuegend', 3, 'Die qualitativen und quantitativen Vorgaben erfüllt {{er|sie|er/sie}}. Mit {{seinen|ihren|seinen/ihren}} Leistungen sind wir zufrieden.'),
('zielerreichung', 'arbeitsweise_leistung', 'mitarbeiter', 'd', 'gut', 1, 'Dabei erreicht {{er|sie|er/sie}} die vereinbarten Ziele und übertrifft diese häufig.'),
('zielerreichung', 'arbeitsweise_leistung', 'mitarbeiter', 'd', 'gut', 2, 'Dabei erreicht {{er|sie|er/sie}} stets die vereinbarten Ziele.'),
('zielerreichung', 'arbeitsweise_leistung', 'mitarbeiter', 'd', 'gut', 3, 'Die qualitativen und quantitativen Vorgaben erfüllt {{er|sie|er/sie}} einwandfrei. Mit {{seinen|ihren|seinen/ihren}} Leistungen sind wir sehr zufrieden.'),
('zielerreichung', 'arbeitsweise_leistung', 'mitarbeiter', 'd', 'sehr_gut', 1, 'Dabei erreicht {{er|sie|er/sie}} die vereinbarten sehr hoch gesetzten Ziele und übertrifft diese meist.'),
('zielerreichung', 'arbeitsweise_leistung', 'mitarbeiter', 'd', 'sehr_gut', 2, 'Dabei erreicht {{er|sie|er/sie}} auch anspruchsvolle Ziele und übertrifft diese oft.'),
('zielerreichung', 'arbeitsweise_leistung', 'mitarbeiter', 'd', 'sehr_gut', 3, 'Die qualitativen und quantitativen Vorgaben übertrifft {{er|sie|er/sie}} oft. Mit {{seinen|ihren|seinen/ihren}} Leistungen sind wir ausgesprochen zufrieden.'),
('zufriedenheit_leistung', 'arbeitsweise_leistung', 'mitarbeiter', 'd', 'ungenuegend', 1, 'Zusammengefasst erbringt {vorname} {nachname} unseren Erwartungen entsprechende Leistungen.'),
('zufriedenheit_leistung', 'arbeitsweise_leistung', 'mitarbeiter', 'd', 'ungenuegend', 2, 'Zusammengefasst entsprechen die Leistungen von {vorname} {nachname} nicht immer unseren Erwartungen.'),
('zufriedenheit_leistung', 'arbeitsweise_leistung', 'mitarbeiter', 'd', 'ungenuegend', 3, 'Die Leistungen von {vorname} {nachname} entsprechen nicht immer unseren Erwartungen.'),
('zufriedenheit_leistung', 'arbeitsweise_leistung', 'mitarbeiter', 'd', 'genuegend', 1, 'Zusammengefasst erbringt {vorname} {nachname} immer die von uns erwarteten Leistungen. {{Seine|Ihre|Seine/Ihre}} Aufgaben erledigt {{er|sie|er/sie}} ordnungsgemäss.'),
('zufriedenheit_leistung', 'arbeitsweise_leistung', 'mitarbeiter', 'd', 'genuegend', 2, 'Zusammengefasst erbringt {vorname} {nachname} konstante Leistungen, welche unseren Erwartungen entsprechen.'),
('zufriedenheit_leistung', 'arbeitsweise_leistung', 'mitarbeiter', 'd', 'genuegend', 3, 'Die Leistungen von {vorname} {nachname} entsprechen weitgehend unseren Erwartungen.'),
('zufriedenheit_leistung', 'arbeitsweise_leistung', 'mitarbeiter', 'd', 'gut', 1, 'Zusammengefasst erbringt {vorname} {nachname} jederzeit beste Leistungen, welche unseren hohen Erwartungen entsprechen. {{Seine|Ihre|Seine/Ihre}} Aufgaben erledigt {{er|sie|er/sie}} stets zu unserer vollen Zufriedenheit.'),
('zufriedenheit_leistung', 'arbeitsweise_leistung', 'mitarbeiter', 'd', 'gut', 2, 'Zusammengefasst erbringt {vorname} {nachname} konstant gute Leistungen, welche unseren Erwartungen in jeder Hinsicht entsprechen.'),
('zufriedenheit_leistung', 'arbeitsweise_leistung', 'mitarbeiter', 'd', 'gut', 3, 'Die Leistungen von {vorname} {nachname} entsprechen in jeder Hinsicht unseren Erwartungen.'),
('zufriedenheit_leistung', 'arbeitsweise_leistung', 'mitarbeiter', 'd', 'sehr_gut', 1, 'Zusammengefasst erbringt {vorname} {nachname} jederzeit in höchstem Masse beste Leistungen, welche unsere hohen Erwartungen überbieten. Alle {{seine|ihre|seine/ihre}} Aufgaben erledigt {{er|sie|er/sie}} stets zu unserer vollsten Zufriedenheit.'),
('zufriedenheit_leistung', 'arbeitsweise_leistung', 'mitarbeiter', 'd', 'sehr_gut', 2, 'Zusammengefasst erbringt {vorname} {nachname} jederzeit ausgezeichnete Leistungen, welche unsere Erwartungen in jeder Hinsicht übertreffen.'),
('zufriedenheit_leistung', 'arbeitsweise_leistung', 'mitarbeiter', 'd', 'sehr_gut', 3, 'Die Leistungen von {vorname} {nachname} übertreffen in jeder Hinsicht unsere Erwartungen.'),
('verhalten_gegenueber_dritten', 'persoenliches_verhalten', 'mitarbeiter', 'd', 'ungenuegend', 1, 'Das Verhalten von {vorname} {nachname} gegenüber Vorgesetzten, anderen Mitarbeitenden, Kunden und Geschäftspartnern ist angemessen.'),
('verhalten_gegenueber_dritten', 'persoenliches_verhalten', 'mitarbeiter', 'd', 'ungenuegend', 2, 'Das Verhalten von {vorname} {nachname} gegenüber Vorgesetzten, Mitarbeitenden, Kundinnen und Kunden ist korrekt.'),
('verhalten_gegenueber_dritten', 'persoenliches_verhalten', 'mitarbeiter', 'd', 'ungenuegend', 3, '{vorname} {nachname} ist bei Vorgesetzten, Mitarbeitenden und Anspruchsgruppen akzeptiert.'),
('verhalten_gegenueber_dritten', 'persoenliches_verhalten', 'mitarbeiter', 'd', 'ungenuegend', 4, 'Das Auftreten von {vorname} {nachname} gibt gelegentlich zu Beanstandung Anlass.'),
('verhalten_gegenueber_dritten', 'persoenliches_verhalten', 'mitarbeiter', 'd', 'genuegend', 1, 'Das Verhalten von {vorname} {nachname} gegenüber Vorgesetzten, anderen Mitarbeitenden, Kunden und Geschäftspartnern ist immer korrekt.'),
('verhalten_gegenueber_dritten', 'persoenliches_verhalten', 'mitarbeiter', 'd', 'genuegend', 2, 'Das Verhalten von {vorname} {nachname} gegenüber Vorgesetzten, Mitarbeitenden, Kundinnen und Kunden ist stets korrekt.'),
('verhalten_gegenueber_dritten', 'persoenliches_verhalten', 'mitarbeiter', 'd', 'genuegend', 3, '{vorname} {nachname} ist bei Vorgesetzten, Mitarbeitenden und Anspruchsgruppen anerkannt.'),
('verhalten_gegenueber_dritten', 'persoenliches_verhalten', 'mitarbeiter', 'd', 'genuegend', 4, '{vorname} {nachname} ist freundlich und hilfsbereit und kann sich auch in ungewohnten Situationen behaupten.'),
('verhalten_gegenueber_dritten', 'persoenliches_verhalten', 'mitarbeiter', 'd', 'gut', 1, 'Das Verhalten von {vorname} {nachname} gegenüber Vorgesetzten, anderen Mitarbeitenden, Kunden und Geschäftspartnern ist einwandfrei.'),
('verhalten_gegenueber_dritten', 'persoenliches_verhalten', 'mitarbeiter', 'd', 'gut', 2, 'Das Verhalten von {vorname} {nachname} gegenüber Vorgesetzten, Mitarbeitenden, Kundinnen und Kunden ist stets freundlich und korrekt.'),
('verhalten_gegenueber_dritten', 'persoenliches_verhalten', 'mitarbeiter', 'd', 'gut', 3, '{vorname} {nachname} ist bei Vorgesetzten, Mitarbeitenden und Anspruchsgruppen anerkannt und geschätzt.'),
('verhalten_gegenueber_dritten', 'persoenliches_verhalten', 'mitarbeiter', 'd', 'gut', 4, '{vorname} {nachname} ist aufgeschlossen, freundlich und hilfsbereit und meistert auch ungewohnte Situationen routiniert.'),
('verhalten_gegenueber_dritten', 'persoenliches_verhalten', 'mitarbeiter', 'd', 'sehr_gut', 1, 'Das Verhalten von {vorname} {nachname} gegenüber Vorgesetzten, anderen Mitarbeitenden, Kunden und Geschäftspartnern ist stets vorbildlich und einwandfrei.'),
('verhalten_gegenueber_dritten', 'persoenliches_verhalten', 'mitarbeiter', 'd', 'sehr_gut', 2, 'Das Verhalten von {vorname} {nachname} gegenüber Vorgesetzten, Mitarbeitenden, Kundinnen und Kunden ist stets vorbildlich, freundlich und korrekt. {{Er|Sie|Er/Sie}} wird allseits sehr geschätzt und anerkannt.'),
('verhalten_gegenueber_dritten', 'persoenliches_verhalten', 'mitarbeiter', 'd', 'sehr_gut', 3, '{vorname} {nachname} wird von Vorgesetzten, Mitarbeitenden und Anspruchsgruppen gleichermassen anerkannt und sehr geschätzt.'),
('verhalten_gegenueber_dritten', 'persoenliches_verhalten', 'mitarbeiter', 'd', 'sehr_gut', 4, '{vorname} {nachname} geht offen, zuvorkommend und hilfsbereit auf andere zu und meistert auch ungewöhnliche Situationen sehr gewandt.'),
('konfliktfaehigkeit', 'persoenliches_verhalten', 'mitarbeiter', 'd', 'ungenuegend', 1, '{{Er|Sie|Er/Sie}} meistert schwierige Situationen angebracht.'),
('konfliktfaehigkeit', 'persoenliches_verhalten', 'mitarbeiter', 'd', 'ungenuegend', 2, '{{Er|Sie|Er/Sie}} benötigt in schwierigen Situationen Unterstützung, um angemessene Lösungen zu finden.'),
('konfliktfaehigkeit', 'persoenliches_verhalten', 'mitarbeiter', 'd', 'ungenuegend', 3, 'Aus Diskussionen und Auseinandersetzungen hält {{er|sie|er/sie}} sich wo möglich raus oder meidet diese.'),
('konfliktfaehigkeit', 'persoenliches_verhalten', 'mitarbeiter', 'd', 'ungenuegend', 4, 'In Verhandlungssituationen benötigt {{er|sie|er/sie}} teilweise Unterstützung, um eine für die Beteiligten annehmbare Lösung zu finden.'),
('konfliktfaehigkeit', 'persoenliches_verhalten', 'mitarbeiter', 'd', 'genuegend', 1, '{{Er|Sie|Er/Sie}} bleibt auch in schwierigen Situationen sachlich. Darüber hinaus versucht {{er|sie|er/sie}} stets angemessene Lösungen zu finden.'),
('konfliktfaehigkeit', 'persoenliches_verhalten', 'mitarbeiter', 'd', 'genuegend', 2, '{{Er|Sie|Er/Sie}} bleibt auch in schwierigen Situationen sachlich und kann angemessene Lösungen finden.'),
('konfliktfaehigkeit', 'persoenliches_verhalten', 'mitarbeiter', 'd', 'genuegend', 3, 'Bei Diskussionen und Auseinandersetzungen verhält {{er|sie|er/sie}} sich eher zurückhaltend und nimmt meist eine neutrale Haltung ein.'),
('konfliktfaehigkeit', 'persoenliches_verhalten', 'mitarbeiter', 'd', 'genuegend', 4, 'Mit {{seinem|ihrem|seinem/ihrem}} Verhandlungsgeschick gelingt es {{ihm|ihr|ihm/ihr}} auch in angespannten Situationen eine für die Beteiligten annehmbare Lösung zu finden.'),
('konfliktfaehigkeit', 'persoenliches_verhalten', 'mitarbeiter', 'd', 'gut', 1, '{{Er|Sie|Er/Sie}} bleibt auch in schwierigen Situationen sachlich und kooperativ. Darüber hinaus versucht {{er|sie|er/sie}} Lösungen zu finden, welche möglichst die Interessen aller Beteiligten berücksichtigen.'),
('konfliktfaehigkeit', 'persoenliches_verhalten', 'mitarbeiter', 'd', 'gut', 2, '{{Er|Sie|Er/Sie}} bleibt auch in schwierigen Situationen sachlich, kooperativ und lösungsorientiert.'),
('konfliktfaehigkeit', 'persoenliches_verhalten', 'mitarbeiter', 'd', 'gut', 3, 'Bei Diskussionen und Auseinandersetzungen wirkt {{er|sie|er/sie}} bei unterschiedlichen Ansichten ausgleichend.'),
('konfliktfaehigkeit', 'persoenliches_verhalten', 'mitarbeiter', 'd', 'gut', 4, 'Mit {{seinem|ihrem|seinem/ihrem}} guten Verhandlungsgeschick gelingt es {{ihm|ihr|ihm/ihr}} auch in angespannten Situationen eine für alle Beteiligten geeignete Lösung zu finden.'),
('konfliktfaehigkeit', 'persoenliches_verhalten', 'mitarbeiter', 'd', 'sehr_gut', 1, '{{Er|Sie|Er/Sie}} bleibt auch in schwierigen Situationen ruhig, sachlich und kooperativ. Darüber hinaus findet {{er|sie|er/sie}} optimale Lösungen, welche die Interessen aller Beteiligten berücksichtigen.'),
('konfliktfaehigkeit', 'persoenliches_verhalten', 'mitarbeiter', 'd', 'sehr_gut', 2, 'Bei Diskussionen und Auseinandersetzungen kann {{er|sie|er/sie}} ausgezeichnet zwischen unterschiedlichen Ansichten vermitteln.'),
('konfliktfaehigkeit', 'persoenliches_verhalten', 'mitarbeiter', 'd', 'sehr_gut', 3, 'Mit {{seinem|ihrem|seinem/ihrem}} beeindruckenden Verhandlungsgeschick gelingt es {{ihm|ihr|ihm/ihr}} auch in angespannten Situationen eine konsensfähige Lösung zu finden.'),
('kommunikationsfaehigkeit', 'persoenliches_verhalten', 'mitarbeiter', 'd', 'ungenuegend', 1, 'In Gesprächen kommuniziert {{er|sie|er/sie}} verständlich.'),
('kommunikationsfaehigkeit', 'persoenliches_verhalten', 'mitarbeiter', 'd', 'ungenuegend', 2, 'In Fachgesprächen kommuniziert {{er|sie|er/sie}} verständlich.'),
('kommunikationsfaehigkeit', 'persoenliches_verhalten', 'mitarbeiter', 'd', 'ungenuegend', 3, '{{Seine|Ihre|Seine/Ihre}} mündliche und schriftliche Ausdrucksfähigkeit ist teils zu wenig adressatengerecht.'),
('kommunikationsfaehigkeit', 'persoenliches_verhalten', 'mitarbeiter', 'd', 'ungenuegend', 4, 'Darüber hinaus gelingt es {{ihm|ihr|ihm/ihr}} selten, eigene Ideen in Gespräche oder Diskussionen einzubringen.'),
('kommunikationsfaehigkeit', 'persoenliches_verhalten', 'mitarbeiter', 'd', 'genuegend', 1, 'In Gesprächen kommuniziert {{er|sie|er/sie}} korrekt und hört auch anderen Standpunkten zu.'),
('kommunikationsfaehigkeit', 'persoenliches_verhalten', 'mitarbeiter', 'd', 'genuegend', 2, 'In Fachgesprächen kommuniziert {{er|sie|er/sie}} korrekt und lässt andere Standpunkte gelten.'),
('kommunikationsfaehigkeit', 'persoenliches_verhalten', 'mitarbeiter', 'd', 'genuegend', 3, '{{Er|Sie|Er/Sie}} verfügt weitgehend über eine adressatengerechte mündliche und schriftliche Ausdrucksfähigkeit.'),
('kommunikationsfaehigkeit', 'persoenliches_verhalten', 'mitarbeiter', 'd', 'genuegend', 4, 'Darüber hinaus kann {{er|sie|er/sie}} eigene Ideen verständlich darlegen und an Fachdiskussionen teilnehmen.'),
('kommunikationsfaehigkeit', 'persoenliches_verhalten', 'mitarbeiter', 'd', 'gut', 1, 'In Gesprächen kommuniziert {{er|sie|er/sie}} klar, offen und versteht es gut, auch andere Meinungen und Standpunkte einzubeziehen.'),
('kommunikationsfaehigkeit', 'persoenliches_verhalten', 'mitarbeiter', 'd', 'gut', 2, 'In Fachgesprächen versteht {{er|sie|er/sie}} es gut, auch andere Meinungen und Standpunkte einzubeziehen, nachvollziehbar zu argumentieren und dabei klar und offen zu kommunizieren. {{Er|Sie|Er/Sie}} pflegt einen angemessenen und zielorientierten Informationsaustausch mit den jeweiligen Anspruchsgruppen.'),
('kommunikationsfaehigkeit', 'persoenliches_verhalten', 'mitarbeiter', 'd', 'gut', 3, '{{Er|Sie|Er/Sie}} verfügt über eine adressatengerechte mündliche und schriftliche Ausdrucksfähigkeit.'),
('kommunikationsfaehigkeit', 'persoenliches_verhalten', 'mitarbeiter', 'd', 'gut', 4, 'Darüber hinaus versteht {{er|sie|er/sie}} es, eigene Ideen nachvollziehbar zu vertreten und sich an Fachdiskussionen aktiv zu beteiligen.'),
('kommunikationsfaehigkeit', 'persoenliches_verhalten', 'mitarbeiter', 'd', 'sehr_gut', 1, 'In Gesprächen versteht {{er|sie|er/sie}} es besonders gut, auch andere Meinungen und Standpunkte einzubeziehen und dabei immer klar, ehrlich und offen zu kommunizieren.'),
('kommunikationsfaehigkeit', 'persoenliches_verhalten', 'mitarbeiter', 'd', 'sehr_gut', 2, 'In Fachgesprächen versteht {{er|sie|er/sie}} es besonders gut, auch andere Meinungen und Standpunkte einzubeziehen, nachvollziehbar zu argumentieren und dabei immer klar und offen zu kommunizieren. {{Er|Sie|Er/Sie}} pflegt einen angemessenen und zielorientierten Informationsaustausch mit den jeweiligen Anspruchsgruppen.'),
('kommunikationsfaehigkeit', 'persoenliches_verhalten', 'mitarbeiter', 'd', 'sehr_gut', 3, '{{Er|Sie|Er/Sie}} verfügt über eine gewandte, adressatengerechte mündliche und schriftliche Ausdrucksfähigkeit.'),
('kommunikationsfaehigkeit', 'persoenliches_verhalten', 'mitarbeiter', 'd', 'sehr_gut', 4, 'Darüber hinaus versteht {{er|sie|er/sie}} es, eigene Ideen stichhaltig zu vertreten und sich in Fachdiskussionen konstruktiv einzubringen.'),
('teamfaehigkeit', 'persoenliches_verhalten', 'mitarbeiter', 'd', 'ungenuegend', 1, 'Zu {{seinen|ihren|seinen/ihren}} Eigenschaften gehört, dass {{er|sie|er/sie}} sich um ein gutes Verhältnis zu {{seinem|ihrem|seinem/ihrem}} Team bemüht.'),
('teamfaehigkeit', 'persoenliches_verhalten', 'mitarbeiter', 'd', 'ungenuegend', 2, '{{Er|Sie|Er/Sie}} ordnet sich im Team ein.'),
('teamfaehigkeit', 'persoenliches_verhalten', 'mitarbeiter', 'd', 'ungenuegend', 3, '{{Er|Sie|Er/Sie}} hat Schwierigkeiten, sich in ein Team einzuordnen.'),
('teamfaehigkeit', 'persoenliches_verhalten', 'mitarbeiter', 'd', 'genuegend', 1, 'Zu {{seinen|ihren|seinen/ihren}} Stärken gehört, dass {{er|sie|er/sie}} sich immer um ein gutes Verhältnis zu {{seinem|ihrem|seinem/ihrem}} Team bemüht.'),
('teamfaehigkeit', 'persoenliches_verhalten', 'mitarbeiter', 'd', 'genuegend', 2, '{{Er|Sie|Er/Sie}} bringt sich ins Team ein und trägt zu einer angenehmen Zusammenarbeit bei.'),
('teamfaehigkeit', 'persoenliches_verhalten', 'mitarbeiter', 'd', 'genuegend', 3, '{{Er|Sie|Er/Sie}} fügt sich ins Team ein und arbeitet mit den Anderen zusammen.'),
('teamfaehigkeit', 'persoenliches_verhalten', 'mitarbeiter', 'd', 'gut', 1, 'Zu {{seinen|ihren|seinen/ihren}} Stärken gehören Teamfähigkeit und das aktive Unterstützen von Zusammenarbeit.'),
('teamfaehigkeit', 'persoenliches_verhalten', 'mitarbeiter', 'd', 'gut', 2, '{{Er|Sie|Er/Sie}} bringt sich ins Team ein, ist integer und unterstützend. {{Er|Sie|Er/Sie}} trägt zu einer konstruktiven sowie positiven Zusammenarbeit bei und kann gut mit unterschiedlichen Personen und Situationen umgehen.'),
('teamfaehigkeit', 'persoenliches_verhalten', 'mitarbeiter', 'd', 'gut', 3, '{{Er|Sie|Er/Sie}} bringt sich gut ins Team ein und unterstützt die Zusammenarbeit.'),
('teamfaehigkeit', 'persoenliches_verhalten', 'mitarbeiter', 'd', 'sehr_gut', 1, 'Zu {{seinen|ihren|seinen/ihren}} Stärken gehören vorbildliche Teamfähigkeit und die Fähigkeit gute, positive Zusammenarbeit aktiv zu unterstützen.'),
('teamfaehigkeit', 'persoenliches_verhalten', 'mitarbeiter', 'd', 'sehr_gut', 2, '{{Er|Sie|Er/Sie}} bringt sich vorbildlich ins Team ein, ist integer und jederzeit unterstützend. {{Er|Sie|Er/Sie}} trägt aktiv zu einer konstruktiven sowie positiven Zusammenarbeit bei und kann sehr gut mit unterschiedlichen Personen und Situationen umgehen.'),
('teamfaehigkeit', 'persoenliches_verhalten', 'mitarbeiter', 'd', 'sehr_gut', 3, '{{Er|Sie|Er/Sie}} bringt sich vorbildlich ins Team ein und unterstützt und fördert die Zusammenarbeit.'),
('offenheit_fuer_feedback', 'persoenliches_verhalten', 'mitarbeiter', 'd', 'ungenuegend', 1, 'Ausserdem ist {{er|sie|er/sie}} Anregungen gegenüber empfänglich und hört sich Vorschläge immer an.'),
('offenheit_fuer_feedback', 'persoenliches_verhalten', 'mitarbeiter', 'd', 'ungenuegend', 2, 'Ausserdem hört {{er|sie|er/sie}} sich Feedback und Vorschläge an.'),
('offenheit_fuer_feedback', 'persoenliches_verhalten', 'mitarbeiter', 'd', 'ungenuegend', 3, 'Es ist für {{ihn|sie|ihn/sie}} nicht einfach, andere Meinungen und begründete Kritik anzunehmen und sich auf die Bedürfnisse der Gesprächspartner einzustellen.'),
('offenheit_fuer_feedback', 'persoenliches_verhalten', 'mitarbeiter', 'd', 'ungenuegend', 4, '{{Er|Sie|Er/Sie}} reflektiert eigene Handlungen kaum und setzt Anregungen nur zögerlich um.'),
('offenheit_fuer_feedback', 'persoenliches_verhalten', 'mitarbeiter', 'd', 'genuegend', 1, 'Ausserdem ist {{er|sie|er/sie}} Anregungen und Feedback gegenüber offen und kann Vorschläge annehmen.'),
('offenheit_fuer_feedback', 'persoenliches_verhalten', 'mitarbeiter', 'd', 'genuegend', 2, 'Ausserdem ist {{er|sie|er/sie}} Feedback gegenüber offen und kann Vorschläge annehmen.'),
('offenheit_fuer_feedback', 'persoenliches_verhalten', 'mitarbeiter', 'd', 'genuegend', 3, '{{Er|Sie|Er/Sie}} akzeptiert andere Meinungen und begründete Kritik und lässt sich auf die Bedürfnisse der Gesprächspartner ein.'),
('offenheit_fuer_feedback', 'persoenliches_verhalten', 'mitarbeiter', 'd', 'gut', 1, 'Ausserdem gibt {{er|sie|er/sie}} konstruktives Feedback, ist offen für Anregungen und setzt Vorschläge nutzbringend um.'),
('offenheit_fuer_feedback', 'persoenliches_verhalten', 'mitarbeiter', 'd', 'gut', 2, '{{Er|Sie|Er/Sie}} lässt sich durch andere Meinungen und begründete Kritik anregen, kann zuhören und sich auf die Bedürfnisse der Gesprächspartner einlassen.'),
('offenheit_fuer_feedback', 'persoenliches_verhalten', 'mitarbeiter', 'd', 'gut', 3, '{{Er|Sie|Er/Sie}} ist fähig, die eigenen Handlungen zu reflektieren, ist offen für Anregungen und nutzt entsprechende Empfehlungen.'),
('offenheit_fuer_feedback', 'persoenliches_verhalten', 'mitarbeiter', 'd', 'sehr_gut', 1, 'Ausserdem gibt und fördert {{er|sie|er/sie}} konstruktives Feedback, ist jederzeit offen für Anregungen und setzt Vorschläge zielsicher, sowie nutzbringend um.'),
('offenheit_fuer_feedback', 'persoenliches_verhalten', 'mitarbeiter', 'd', 'sehr_gut', 2, 'Ausserdem gibt und fördert {{er|sie|er/sie}} konstruktives Feedback, reflektiert und ist jederzeit offen für Anregungen. Vorschläge setzt {{er|sie|er/sie}} nutzbringend um.'),
('offenheit_fuer_feedback', 'persoenliches_verhalten', 'mitarbeiter', 'd', 'sehr_gut', 3, '{{Er|Sie|Er/Sie}} begrüsst andere Meinungen und begründete Kritik als Anregung, kann gut zuhören und sich problemlos auf die Bedürfnisse der Gesprächspartner einlassen.'),
('offenheit_fuer_feedback', 'persoenliches_verhalten', 'mitarbeiter', 'd', 'sehr_gut', 4, '{{Er|Sie|Er/Sie}} reflektiert die eigenen Handlungen konsequent und nutzt Anregungen sowie Empfehlungen von aussen sehr professionell.'),
('wissen_teilen', 'persoenliches_verhalten', 'mitarbeiter', 'd', 'ungenuegend', 1, '{{Sein|Ihr|Sein/Ihr}} Wissen und Informationen teilt {{er|sie|er/sie}} bei Bedarf mit {{seinem|ihrem|seinem/ihrem}} Team und {{seinen|ihren|seinen/ihren}} Vorgesetzten.'),
('wissen_teilen', 'persoenliches_verhalten', 'mitarbeiter', 'd', 'ungenuegend', 2, '{{Er|Sie|Er/Sie}} gibt {{sein|ihr|sein/ihr}} Wissen und Informationen auf Nachfrage an Vorgesetzte und Mitarbeitende weiter.'),
('wissen_teilen', 'persoenliches_verhalten', 'mitarbeiter', 'd', 'ungenuegend', 3, '{{Sein|Ihr|Sein/Ihr}} Wissen und Können vermittelt {{er|sie|er/sie}} zu wenig nachhaltig.'),
('wissen_teilen', 'persoenliches_verhalten', 'mitarbeiter', 'd', 'ungenuegend', 4, 'Wir vermissen manchmal {{sein|ihr|sein/ihr}} Engagement und die Freude bei der Ausbildung der Lernenden.'),
('wissen_teilen', 'persoenliches_verhalten', 'mitarbeiter', 'd', 'genuegend', 1, '{{Sein|Ihr|Sein/Ihr}} Wissen und Informationen teilt {{er|sie|er/sie}} bei Bedarf stets mit {{seinem|ihrem|seinem/ihrem}} Team und {{seinen|ihren|seinen/ihren}} Vorgesetzten.'),
('wissen_teilen', 'persoenliches_verhalten', 'mitarbeiter', 'd', 'genuegend', 2, '{{Er|Sie|Er/Sie}} gibt {{sein|ihr|sein/ihr}} Wissen und Informationen bei Bedarf an Vorgesetzte und Mitarbeitende weiter.'),
('wissen_teilen', 'persoenliches_verhalten', 'mitarbeiter', 'd', 'genuegend', 3, '{{Sein|Ihr|Sein/Ihr}} Wissen und Können vermittelt {{er|sie|er/sie}} im Allgemeinen geschickt.'),
('wissen_teilen', 'persoenliches_verhalten', 'mitarbeiter', 'd', 'genuegend', 4, 'Die Lernenden bildet {{er|sie|er/sie}} mit Engagement und Freude aus.'),
('wissen_teilen', 'persoenliches_verhalten', 'mitarbeiter', 'd', 'gut', 1, 'Mit grossem Engagement gibt {{er|sie|er/sie}} {{sein|ihr|sein/ihr}} Wissen und Informationen gut verständlich an {{sein|ihr|sein/ihr}} Team und {{seine|ihre|seine/ihre}} Vorgesetzten weiter.'),
('wissen_teilen', 'persoenliches_verhalten', 'mitarbeiter', 'd', 'gut', 2, '{{Er|Sie|Er/Sie}} gibt {{sein|ihr|sein/ihr}} Wissen und arbeitsrelevante Informationen an Vorgesetzte und Mitarbeitende weiter.'),
('wissen_teilen', 'persoenliches_verhalten', 'mitarbeiter', 'd', 'gut', 3, '{{Sein|Ihr|Sein/Ihr}} Wissen und Können vermittelt {{er|sie|er/sie}} mit didaktischem und pädagogischem Geschick.'),
('wissen_teilen', 'persoenliches_verhalten', 'mitarbeiter', 'd', 'gut', 4, 'Die Lernenden bildet {{er|sie|er/sie}} mit viel Engagement und Freude aus, verbunden mit didaktischem und pädagogischem Geschick.'),
('wissen_teilen', 'persoenliches_verhalten', 'mitarbeiter', 'd', 'sehr_gut', 1, 'Mit grossem und unaufdringlichem Engagement gibt {{er|sie|er/sie}} {{sein|ihr|sein/ihr}} umfassendes Wissen und arbeitsrelevante Informationen gut verständlich an {{sein|ihr|sein/ihr}} Team und {{seine|ihre|seine/ihre}} Vorgesetzten weiter.'),
('wissen_teilen', 'persoenliches_verhalten', 'mitarbeiter', 'd', 'sehr_gut', 2, '{{Er|Sie|Er/Sie}} gibt {{sein|ihr|sein/ihr}} umfassendes Wissen und arbeitsrelevante Informationen adäquat an Vorgesetzte und Mitarbeitende weiter.'),
('wissen_teilen', 'persoenliches_verhalten', 'mitarbeiter', 'd', 'sehr_gut', 3, '{{Sein|Ihr|Sein/Ihr}} Wissen und Können vermittelt {{er|sie|er/sie}} mit ausgeprägtem didaktischem und pädagogischem Geschick.'),
('wissen_teilen', 'persoenliches_verhalten', 'mitarbeiter', 'd', 'sehr_gut', 4, 'Die Lernenden bildet {{er|sie|er/sie}} mit grossem Engagement und Freude aus, verbunden mit einem ausgeprägten didaktischen und pädagogischen Geschick.'),
('synergien_nutzen', 'unternehmertum', 'mitarbeiter', 'd', 'ungenuegend', 1, '{vorname} {nachname} erkennt funktions- und bereichsübergreifende Synergien und bespricht daraus gewonnene Ideen mit anderen Fachpersonen.'),
('synergien_nutzen', 'unternehmertum', 'mitarbeiter', 'd', 'ungenuegend', 2, '{vorname} {nachname} erkennt mit Unterstützung Synergien.'),
('synergien_nutzen', 'unternehmertum', 'mitarbeiter', 'd', 'ungenuegend', 3, 'Das Sensorium von {vorname} {nachname} für wirtschaftliche und bereichsübergreifende Zusammenhänge ist nicht sehr ausgeprägt.'),
('synergien_nutzen', 'unternehmertum', 'mitarbeiter', 'd', 'genuegend', 1, '{vorname} {nachname} erkennt funktions- und bereichsübergreifende Synergien und setzt daraus gewonnenes Wissen ein.'),
('synergien_nutzen', 'unternehmertum', 'mitarbeiter', 'd', 'genuegend', 2, '{vorname} {nachname} erkennt Synergien und kann daraus gewonnenes Wissen einsetzen.'),
('synergien_nutzen', 'unternehmertum', 'mitarbeiter', 'd', 'genuegend', 3, '{vorname} {nachname} besitzt ein Sensorium für wirtschaftliche und bereichsübergreifende Zusammenhänge.'),
('synergien_nutzen', 'unternehmertum', 'mitarbeiter', 'd', 'gut', 1, '{vorname} {nachname} erkennt funktions- und bereichsübergreifende Synergien und kann daraus gewonnenes Wissen nutzbringend einsetzen.'),
('synergien_nutzen', 'unternehmertum', 'mitarbeiter', 'd', 'gut', 2, '{vorname} {nachname} erkennt funktions- und bereichsübergreifende Synergien und setzt daraus gewonnenes Wissen ein.'),
('synergien_nutzen', 'unternehmertum', 'mitarbeiter', 'd', 'gut', 3, '{vorname} {nachname} besitzt ein gutes Sensorium für wirtschaftliche und bereichsübergreifende Zusammenhänge.'),
('synergien_nutzen', 'unternehmertum', 'mitarbeiter', 'd', 'sehr_gut', 1, '{vorname} {nachname} erkennt funktions- und bereichsübergreifende Synergien und kann dank dieser Kompetenz, daraus gewonnenes Wissen optimal zum Nutzen des Unternehmens einsetzen.'),
('synergien_nutzen', 'unternehmertum', 'mitarbeiter', 'd', 'sehr_gut', 2, '{vorname} {nachname} erkennt und nutzt funktions- sowie bereichsübergreifende Synergien und setzt daraus gewonnenes Wissen optimal ein.'),
('synergien_nutzen', 'unternehmertum', 'mitarbeiter', 'd', 'sehr_gut', 3, '{vorname} {nachname} besitzt ein ausgeprägtes Sensorium für wirtschaftliche und bereichsübergreifende Zusammenhänge.'),
('flexibilitaet', 'unternehmertum', 'mitarbeiter', 'd', 'ungenuegend', 1, 'Auch Veränderungen kann {{er|sie|er/sie}} annehmen und vertraut Bewährtem.'),
('flexibilitaet', 'unternehmertum', 'mitarbeiter', 'd', 'ungenuegend', 2, 'Veränderungen kann {{er|sie|er/sie}} annehmen und vertraut Bewährtem.'),
('flexibilitaet', 'unternehmertum', 'mitarbeiter', 'd', 'ungenuegend', 3, '{{Er|Sie|Er/Sie}} kann sich nur schwer auf veränderte Situationen einstellen.'),
('flexibilitaet', 'unternehmertum', 'mitarbeiter', 'd', 'genuegend', 1, 'Auch bei Veränderungen kann {{er|sie|er/sie}} sich der neuen Situation anpassen.'),
('flexibilitaet', 'unternehmertum', 'mitarbeiter', 'd', 'genuegend', 2, 'Veränderungen nimmt {{er|sie|er/sie}} an und kann sich neuen Gegebenheiten anpassen.'),
('flexibilitaet', 'unternehmertum', 'mitarbeiter', 'd', 'genuegend', 3, '{{Er|Sie|Er/Sie}} ist bereit, sich veränderten Situationen anzupassen.'),
('flexibilitaet', 'unternehmertum', 'mitarbeiter', 'd', 'gut', 1, 'Mit Veränderungen geht {{er|sie|er/sie}} erfolgreich und anpassungsfähig um.'),
('flexibilitaet', 'unternehmertum', 'mitarbeiter', 'd', 'gut', 2, 'Veränderungen gegenüber ist {{er|sie|er/sie}} offen und kann sich neuen Gegebenheiten gut anpassen.'),
('flexibilitaet', 'unternehmertum', 'mitarbeiter', 'd', 'gut', 3, '{{Er|Sie|Er/Sie}} kann sich veränderten Situationen leicht anpassen und betrachtet diese als Lernfeld.'),
('flexibilitaet', 'unternehmertum', 'mitarbeiter', 'd', 'sehr_gut', 1, 'Mit Veränderungen geht {{er|sie|er/sie}} professionell um und kann sich neuen Gegebenheiten gut anpassen.'),
('flexibilitaet', 'unternehmertum', 'mitarbeiter', 'd', 'sehr_gut', 2, 'Mit Veränderungen geht {{er|sie|er/sie}} sehr offen und gewandt um. {{Er|Sie|Er/Sie}} passt sich neuen Gegebenheiten schnell an.'),
('flexibilitaet', 'unternehmertum', 'mitarbeiter', 'd', 'sehr_gut', 3, 'Auf veränderte Situationen kann {{er|sie|er/sie}} sich sofort einstellen und betrachtet diese als Herausforderung.'),
('kundenorientierung', 'unternehmertum', 'mitarbeiter', 'd', 'ungenuegend', 1, 'Zudem erweist {{er|sie|er/sie}} sich Kunden gegenüber als {{Ansprechpartner|Ansprechpartnerin|Ansprechpartner/in}}, {{welcher|welche|welcher/welche}} Kundenbedürfnisse aufnimmt und Kundenbeziehungen als wichtig erachtet.'),
('kundenorientierung', 'unternehmertum', 'mitarbeiter', 'd', 'ungenuegend', 2, 'Zudem steht {{er|sie|er/sie}} der Kundschaft als {{Ansprechpartner|Ansprechpartnerin|Ansprechpartner/in}} zur Verfügung.'),
('kundenorientierung', 'unternehmertum', 'mitarbeiter', 'd', 'ungenuegend', 3, 'Als {{Ansprechpartner|Ansprechpartnerin|Ansprechpartner/in}} verfolgt {{er|sie|er/sie}} die Anliegen und Bedürfnisse der Kunden bzw. verschiedenen Anspruchsgruppen meist mit der angezeigten Verbindlichkeit.'),
('kundenorientierung', 'unternehmertum', 'mitarbeiter', 'd', 'ungenuegend', 4, 'Bei {{ihm|ihr|ihm/ihr}} vermissen wir manchmal die angemessene Beratung der Anspruchsgruppen.'),
('kundenorientierung', 'unternehmertum', 'mitarbeiter', 'd', 'genuegend', 1, 'Zudem erweist {{er|sie|er/sie}} sich Kunden gegenüber als {{anerkannter|anerkannte|anerkannter/anerkannte}} {{Ansprechpartner|Ansprechpartnerin|Ansprechpartner/in}}, {{welcher|welche|welcher/welche}} Kundenbedürfnisse erfasst und Kundenbeziehungen pflegt.'),
('kundenorientierung', 'unternehmertum', 'mitarbeiter', 'd', 'genuegend', 2, 'Zudem erweist {{er|sie|er/sie}} sich gegenüber der Kundschaft als {{freundlicher|freundliche|freundlicher/freundliche}} {{Ansprechpartner|Ansprechpartnerin|Ansprechpartner/in}}.'),
('kundenorientierung', 'unternehmertum', 'mitarbeiter', 'd', 'genuegend', 3, 'Zudem erweist {{er|sie|er/sie}} sich als {{anerkannter|anerkannte|anerkannter/anerkannte}} {{Ansprechpartner|Ansprechpartnerin|Ansprechpartner/in}}, {{welcher|welche|welcher/welche}} die Anliegen der Kunden bzw. verschiedenen Anspruchsgruppen ernst nimmt und sich an diesen orientiert.'),
('kundenorientierung', 'unternehmertum', 'mitarbeiter', 'd', 'genuegend', 4, '{{Er|Sie|Er/Sie}} achtet auf eine angemessene Beratung der Anspruchsgruppen.'),
('kundenorientierung', 'unternehmertum', 'mitarbeiter', 'd', 'gut', 1, 'Zudem erweist {{er|sie|er/sie}} sich Kunden gegenüber als {{kompetenter|kompetente|kompetenter/kompetente}} und {{dienstleistungsorientierter|dienstleistungsorientierte|dienstleistungsorientierter/dienstleistungsorientierte}} {{Ansprechpartner|Ansprechpartnerin|Ansprechpartner/in}}, {{welcher|welche|welcher/welche}} spezifische Kundenbedürfnisse erfasst und langfristige Kundenbeziehungen entwickelt und pflegt.'),
('kundenorientierung', 'unternehmertum', 'mitarbeiter', 'd', 'gut', 2, 'Zudem erweist {{er|sie|er/sie}} sich gegenüber der Kundschaft als {{kompetenter|kompetente|kompetenter/kompetente}}, {{dienstleistungsorientierter|dienstleistungsorientierte|dienstleistungsorientierter/dienstleistungsorientierte}} {{Ansprechpartner|Ansprechpartnerin|Ansprechpartner/in}}. Kundenbeziehungen pflegt {{er|sie|er/sie}} nachhaltig.'),
('kundenorientierung', 'unternehmertum', 'mitarbeiter', 'd', 'gut', 3, 'Zudem erweist {{er|sie|er/sie}} sich als {{kompetenter|kompetente|kompetenter/kompetente}}, {{dienstleistungsorientierter|dienstleistungsorientierte|dienstleistungsorientierter/dienstleistungsorientierte}} {{Ansprechpartner|Ansprechpartnerin|Ansprechpartner/in}}, {{welcher|welche|welcher/welche}} die Anliegen der Kunden bzw. verschiedenen Anspruchsgruppen ernst nimmt und spezifische Kundenbedürfnisse gut erfasst.'),
('kundenorientierung', 'unternehmertum', 'mitarbeiter', 'd', 'gut', 4, '{{Er|Sie|Er/Sie}} achtet auf eine gründliche und seriöse Beratung der Anspruchsgruppen.'),
('kundenorientierung', 'unternehmertum', 'mitarbeiter', 'd', 'sehr_gut', 1, 'Zudem erweist {{er|sie|er/sie}} sich Kunden gegenüber als überaus {{kompetenter|kompetente|kompetenter/kompetente}}, sehr {{dienstleistungsorientierter|dienstleistungsorientierte|dienstleistungsorientierter/dienstleistungsorientierte}} {{Ansprechpartner|Ansprechpartnerin|Ansprechpartner/in}}, {{welcher|welche|welcher/welche}} spezifische Kundenbedürfnisse präzise erfasst und langfristige Kundenbeziehungen mit viel Eigeninitiative entwickelt und pflegt.'),
('kundenorientierung', 'unternehmertum', 'mitarbeiter', 'd', 'sehr_gut', 2, 'Zudem erweist {{er|sie|er/sie}} sich gegenüber der Kundschaft als überaus {{kompetenter|kompetente|kompetenter/kompetente}}, {{dienstleistungsorientierter|dienstleistungsorientierte|dienstleistungsorientierter/dienstleistungsorientierte}} {{Ansprechpartner|Ansprechpartnerin|Ansprechpartner/in}}. Spezifische Kundenbedürfnisse erfasst {{er|sie|er/sie}} präzise und pflegt Kundenbeziehungen nachhaltig.'),
('kundenorientierung', 'unternehmertum', 'mitarbeiter', 'd', 'sehr_gut', 3, 'Zudem erweist {{er|sie|er/sie}} sich als {{ein|eine|ein/eine}} überaus {{kompetenter|kompetente|kompetenter/kompetente}}, sehr {{dienstleistungsorientierter|dienstleistungsorientierte|dienstleistungsorientierter/dienstleistungsorientierte}} {{Ansprechpartner|Ansprechpartnerin|Ansprechpartner/in}}, {{welcher|welche|welcher/welche}} die Anliegen der Kunden bzw. verschiedenen Anspruchsgruppen sehr ernst nimmt und deren spezifischen Bedürfnisse präzise erfasst.'),
('kundenorientierung', 'unternehmertum', 'mitarbeiter', 'd', 'sehr_gut', 4, '{{Er|Sie|Er/Sie}} sorgt für eine fundierte Beratung der Anspruchsgruppen.');

commit;


-- ###################### supabase/010_schluss_und_wechsel.sql ######################
-- ============================================================================
-- zeugnix.ch – Schluss-/Dankformeln + Wechsel-Detailfelder (Migration 010)
-- ----------------------------------------------------------------------------
-- Zweck:
--   (A) certificates: drei optionale Felder für wechsel-spezifische Details
--       (neue Funktion, neue Firma, Wechseldatum). Werden im Neu-Formular
--       erfasst und über {neue_funktion}/{neue_firma}/{wechsel_datum} in die
--       Schlussformel eingesetzt.
--   (B) phrase_blocks: die Schluss-Bausteine werden VOLLSTÄNDIG durch Silvans
--       Katalog ersetzt (alle category='schluss'-Zeilen aus Seed 002 raus).
--       Quelle: scripts/data/bausteine-parsed.json -> schlussLines (Roh-Zeilen),
--       hier handkuratiert: 'Max Mustermann' -> {vorname} {nachname},
--       Geschlechtswörter als {{m|f|d}}-Tokens, Quell-Fehler korrigiert,
--       beispielspezifische Angaben (Firma/Funktion/Datum) in die
--       '<typ>_detail'-Varianten als Platzhalter ausgelagert.
--
-- Engine-Vertrag (lib/phrases/engine.ts): category='schluss', rating='gut',
--   employee_type='mitarbeiter' (Führungskraft fällt darauf zurück),
--   gender='d' mit Tokens. Subkategorien je Zeugnistyp:
--     schluss_dank, zwischen, funktionswechsel(+_detail), vorgesetztenwechsel,
--     interner_wechsel(+_detail), reorganisation,
--     wunsch_mitarbeiter, wunsch_mitarbeiterin.
--   Die '_detail'-Variante greift nur, wenn ALLE ihrer Felder gesetzt sind.
--
-- Idempotent: ADD COLUMN IF NOT EXISTS + DELETE+INSERT der Schluss-Bausteine.
-- Ausführung: Supabase Dashboard -> SQL Editor -> einfügen -> Run
-- ============================================================================

-- (A) Wechsel-spezifische Zusatzfelder (optional) -----------------------------
alter table public.certificates add column if not exists new_function_title text;
alter table public.certificates add column if not exists new_company_name text;
alter table public.certificates add column if not exists transition_date date;

-- (B) Schluss-Bausteine vollständig ersetzen ----------------------------------
delete from public.phrase_blocks where category = 'schluss';

insert into public.phrase_blocks
  (category, subcategory, employee_type, gender, rating, variant, text, signal_strength, tonality)
values
-- ----- schluss_dank: allgemeine Dank-/Schlussformel (Typ 'schluss' + Dank) ---
('schluss', 'schluss_dank', 'mitarbeiter', 'd', 'gut', 1,
 'Wir danken {vorname} {nachname} für die bisherige Mitarbeit und wünschen {{ihm|ihr|ihm/ihr}} alles Gute und viel Erfolg.',
 'eindeutig', 'positiv'),
('schluss', 'schluss_dank', 'mitarbeiter', 'd', 'gut', 2,
 'Wir danken {vorname} {nachname} bestens für die bisherige wertvolle Mitarbeit und wünschen {{ihm|ihr|ihm/ihr}} alles Gute und weiterhin viel Erfolg.',
 'eindeutig', 'positiv'),
('schluss', 'schluss_dank', 'mitarbeiter', 'd', 'gut', 3,
 'Wir danken {vorname} {nachname} für die bisherige sehr wertvolle Unterstützung bestens und hoffen, noch lange auf {{seine|ihre|seine/ihre}} geschätzte Mitarbeit zählen zu dürfen.',
 'eindeutig', 'positiv'),
('schluss', 'schluss_dank', 'mitarbeiter', 'd', 'gut', 4,
 'Wir danken {vorname} {nachname} bestens für die bisherige Mitarbeit.',
 'mittel', 'positiv'),

-- ----- zwischen: Zwischenzeugnis (aus Seed 002 übernommen) -------------------
('schluss', 'zwischen', 'mitarbeiter', 'd', 'gut', 1,
 'Dieses Zwischenzeugnis wird auf Wunsch von {{Herrn|Frau|Herrn/Frau}} {nachname} ausgestellt.',
 'eindeutig', 'neutral'),

-- ----- funktionswechsel: generisch + Detail (neue_funktion + neue_firma) -----
('schluss', 'funktionswechsel', 'mitarbeiter', 'd', 'gut', 1,
 '{vorname} {nachname} verlässt uns heute auf eigenen Wunsch, um eine neue berufliche Herausforderung anzunehmen. Wir danken {{Herrn|Frau|Herrn/Frau}} {nachname} bestens für die wertvolle Mitarbeit und wünschen {{ihm|ihr|ihm/ihr}} alles Gute und weiterhin viel Erfolg.',
 'eindeutig', 'positiv'),
('schluss', 'funktionswechsel_detail', 'mitarbeiter', 'd', 'gut', 1,
 '{vorname} {nachname} verlässt uns heute auf eigenen Wunsch, um eine Aufgabe als {neue_funktion} bei der {neue_firma} zu übernehmen. Wir danken {{Herrn|Frau|Herrn/Frau}} {nachname} bestens für die wertvolle Mitarbeit und wünschen {{ihm|ihr|ihm/ihr}} alles Gute und weiterhin viel Erfolg.',
 'eindeutig', 'positiv'),

-- ----- vorgesetztenwechsel --------------------------------------------------
('schluss', 'vorgesetztenwechsel', 'mitarbeiter', 'd', 'gut', 1,
 'Dieses Zeugnis wird aufgrund eines Vorgesetztenwechsels ausgestellt. Wir danken {{ihm|ihr|ihm/ihr}} für die bisherige sehr wertvolle Unterstützung bestens und hoffen, noch lange auf {{seine|ihre|seine/ihre}} geschätzte Mitarbeit zählen zu dürfen.',
 'eindeutig', 'neutral'),

-- ----- interner_wechsel: generisch + Detail (wechsel_datum + neue_funktion) --
('schluss', 'interner_wechsel', 'mitarbeiter', 'd', 'gut', 1,
 'Wir danken {vorname} {nachname} bestens für die bisherige wertvolle Mitarbeit und wünschen {{ihm|ihr|ihm/ihr}} viel Freude und Erfolg im neuen Aufgabengebiet.',
 'eindeutig', 'positiv'),
('schluss', 'interner_wechsel_detail', 'mitarbeiter', 'd', 'gut', 1,
 'Dieses Zeugnis wird aufgrund eines internen Übertritts von {{Herrn|Frau|Herrn/Frau}} {nachname} ausgestellt. {{Er|Sie|Er/Sie}} wird per {wechsel_datum} als {neue_funktion} weiterhin bei uns tätig sein.',
 'eindeutig', 'neutral'),

-- ----- reorganisation -------------------------------------------------------
('schluss', 'reorganisation', 'mitarbeiter', 'd', 'gut', 1,
 '{vorname} {nachname} verlässt uns heute. Wir danken {{Herrn|Frau|Herrn/Frau}} {nachname} bestens für die wertvolle Mitarbeit und wünschen {{ihm|ihr|ihm/ihr}} für die berufliche und private Zukunft alles Gute.',
 'eindeutig', 'positiv'),

-- ----- wunsch_mitarbeiter / wunsch_mitarbeiterin (gleicher Text, Tokens) ----
('schluss', 'wunsch_mitarbeiter', 'mitarbeiter', 'd', 'gut', 1,
 'Dieses Zeugnis wird auf Wunsch von {{Herrn|Frau|Herrn/Frau}} {nachname} ausgestellt. Wir danken {{ihm|ihr|ihm/ihr}} für die bisherige sehr wertvolle Unterstützung bestens und hoffen, noch lange auf {{seine|ihre|seine/ihre}} geschätzte Mitarbeit zählen zu dürfen.',
 'eindeutig', 'neutral'),
('schluss', 'wunsch_mitarbeiterin', 'mitarbeiter', 'd', 'gut', 1,
 'Dieses Zeugnis wird auf Wunsch von {{Herrn|Frau|Herrn/Frau}} {nachname} ausgestellt. Wir danken {{ihm|ihr|ihm/ihr}} für die bisherige sehr wertvolle Unterstützung bestens und hoffen, noch lange auf {{seine|ihre|seine/ihre}} geschätzte Mitarbeit zählen zu dürfen.',
 'eindeutig', 'neutral');

-- Done.


-- ###################### supabase/011_certificate_formatting.sql ######################
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

