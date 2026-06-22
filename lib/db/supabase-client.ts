"use client";

import { createBrowserClient } from "@supabase/ssr";

/**
 * Browser-seitiger Supabase-Client für Client Components.
 */
export function createClient() {
  // Hinweis: @supabase/ssr erzwingt intern flowType "pkce" und cookie-
  // basiertes Storage – eigene auth-Optionen (flowType/detectSessionInUrl)
  // würden ohnehin überschrieben. Der Magic-Link läuft daher über den
  // token_hash-Weg (verifyOtp im Callback), der keinen PKCE-Verifier
  // braucht. Voraussetzung: E-Mail-Template nutzt {{ .TokenHash }}.
  return createBrowserClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
  );
}
