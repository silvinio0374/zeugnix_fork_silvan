import { createClient } from "@/lib/db/supabase-server";
import { NextResponse } from "next/server";
import type { EmailOtpType } from "@supabase/supabase-js";

/**
 * GET /auth/callback
 *
 * Verarbeitet den Magic-Link-Rücksprung von Supabase. Unterstützt beide
 * Varianten, in denen der Link ankommen kann:
 *   - PKCE:        ?code=...                  -> exchangeCodeForSession
 *   - OTP-Verify:  ?token_hash=...&type=...   -> verifyOtp
 *
 * Bei Erfolg: Weiterleitung in die App. Bei Fehler: zurück zur Login-Seite,
 * inkl. konkreter Fehlermeldung im ?error=-Parameter (zur Diagnose).
 */
export async function GET(request: Request) {
  const { searchParams, origin } = new URL(request.url);
  const code = searchParams.get("code");
  const tokenHash = searchParams.get("token_hash");
  const type = searchParams.get("type") as EmailOtpType | null;
  const next = searchParams.get("next") ?? "/app/dashboard";

  const supabase = await createClient();

  if (code) {
    const { error } = await supabase.auth.exchangeCodeForSession(code);
    if (!error) return NextResponse.redirect(`${origin}${next}`);
    return NextResponse.redirect(
      `${origin}/login?error=${encodeURIComponent(error.message)}`,
    );
  }

  if (tokenHash && type) {
    const { error } = await supabase.auth.verifyOtp({
      token_hash: tokenHash,
      type,
    });
    if (!error) return NextResponse.redirect(`${origin}${next}`);
    return NextResponse.redirect(
      `${origin}/login?error=${encodeURIComponent(error.message)}`,
    );
  }

  // Weder code noch token_hash vorhanden -> Link enthielt keine Auth-Daten
  return NextResponse.redirect(`${origin}/login?error=missing_auth_params`);
}
