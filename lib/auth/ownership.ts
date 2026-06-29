import type { SupabaseClient } from "@supabase/supabase-js";

/**
 * Defense-in-Depth Ownership-Check, der die RLS-Logik explizit im Code
 * spiegelt: Ein User darf eine Firma (und damit ihre Zeugnisse) verwalten,
 * wenn er entweder ihr Ersteller ist (`companies.created_by_user_id`) ODER als
 * Mitglied in `company_members` eingetragen ist.
 *
 * Erwartet den AUTHENTIFIZIERTEN Client (createClient, nicht Service-Role).
 * Da RLS dieselben Zeilen ohnehin filtert, ist dies die zweite
 * Verteidigungslinie — und liefert ein klares 403 statt eines indirekten 404.
 */
export async function userIsCompanyMember(
  supabase: SupabaseClient,
  companyId: string | null | undefined,
  userId: string | null | undefined,
): Promise<boolean> {
  if (!companyId || !userId) return false;

  // Echte Query-Fehler (Timeout, Netzwerk) NICHT verschlucken: sonst würde
  // `data` zu null und der legitime Owner bekäme fälschlich ein 403. Bei einem
  // echten Fehler werfen → Route liefert 500 (wiederholbar). `maybeSingle()`
  // liefert bei "keine Zeile" error=null, wirft also nur bei echten Fehlern.
  const { data: company, error: companyErr } = await supabase
    .from("companies")
    .select("created_by_user_id")
    .eq("id", companyId)
    .maybeSingle();
  if (companyErr) {
    throw new Error(`Ownership-Check fehlgeschlagen (companies): ${companyErr.message}`);
  }

  if (company?.created_by_user_id === userId) return true;

  const { data: membership, error: memberErr } = await supabase
    .from("company_members")
    .select("user_id")
    .eq("company_id", companyId)
    .eq("user_id", userId)
    .maybeSingle();
  if (memberErr) {
    throw new Error(`Ownership-Check fehlgeschlagen (company_members): ${memberErr.message}`);
  }

  return !!membership;
}
