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
