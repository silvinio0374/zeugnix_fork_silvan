"use client";

import { createBrowserClient } from "@supabase/ssr";

/**
 * Browser-seitiger Supabase-Client für Client Components.
 */
export function createClient() {
  return createBrowserClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      auth: {
        // Den Magic-Link-Callback lösen wir explizit in
        // app/auth/callback/page.tsx ein. Automatisches Parsen der URL
        // würde den Code doppelt einlösen (Race mit unserem Aufruf).
        detectSessionInUrl: false,
        flowType: "pkce",
      },
    },
  );
}
