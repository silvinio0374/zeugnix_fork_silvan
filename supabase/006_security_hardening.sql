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
