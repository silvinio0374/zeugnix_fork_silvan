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
        // Implicit-Flow: Der Magic-Link bringt die Tokens direkt im
        // URL-Fragment zurück – kein PKCE-Verifier nötig, der im Browser
        // gespeichert sein müsste. Damit ist die Anmeldung immun gegen
        // Domain-Wechsel (Vercel-Preview/Site-URL), andere Geräte und
        // Link-Scanner. Den Callback verarbeiten wir explizit in
        // app/auth/callback/page.tsx, deshalb kein Auto-Parsing.
        detectSessionInUrl: false,
        flowType: "implicit",
      },
    },
  );
}
