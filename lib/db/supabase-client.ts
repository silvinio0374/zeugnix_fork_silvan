"use client";

import { createBrowserClient } from "@supabase/ssr";
import { createClient as createSupabaseClient } from "@supabase/supabase-js";

/**
 * Browser-seitiger Supabase-Client für Client Components.
 *
 * Hält die App-Session über Cookies (von @supabase/ssr verwaltet). @supabase/ssr
 * erzwingt intern flowType "pkce" + detectSessionInUrl – eigene auth-Optionen
 * würden überschrieben. Wird überall verwendet (Session lesen/setzen, Logout etc.).
 */
export function createClient() {
  return createBrowserClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
  );
}

/**
 * Schlanker Plain-Client NUR zum Anstoßen des Magic-Links (signInWithOtp).
 *
 * Mit flowType "implicit" wird KEIN PKCE-code_challenge gesendet -> der Versand-
 * Link enthält kein `pkce_`-Token, sondern bringt die Tokens direkt im URL-
 * Fragment zurück. Dadurch ist kein im Browser gespeicherter Verifier nötig und
 * der Link funktioniert browser-/geräteübergreifend.
 *
 * persistSession/detectSessionInUrl/autoRefreshToken sind aus, damit dieser
 * Client keinerlei Zustand schreibt und nicht mit dem SSR-Cookie-Client
 * kollidiert. Die eigentliche Session setzt der Callback über createClient().
 */
export function createOtpClient() {
  return createSupabaseClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      auth: {
        flowType: "implicit",
        persistSession: false,
        detectSessionInUrl: false,
        autoRefreshToken: false,
      },
    },
  );
}
