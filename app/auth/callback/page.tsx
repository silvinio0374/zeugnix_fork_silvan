"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import type { EmailOtpType } from "@supabase/supabase-js";
import { createClient } from "@/lib/db/supabase-client";

/**
 * /auth/callback (Client Component)
 *
 * Verarbeitet den Magic-Link-Rücksprung von Supabase im BROWSER. Bewusst
 * clientseitig: Der PKCE-„code verifier" liegt als Cookie im Browser. Bei der
 * Magic-Link-Weiterleitung (Mail -> supabase.co -> zurück auf unsere Domain)
 * wird dieser Cookie bei einer Server-Route nicht zuverlässig mitgeschickt
 * (Cross-Site-Redirect) -> „PKCE code verifier not found in storage".
 *
 * Der Browser-Client liest den Verifier dagegen direkt aus seinem eigenen
 * Storage und kann den Code zuverlässig einlösen. Unterstützt beide Varianten:
 *   - PKCE:        ?code=...                  -> exchangeCodeForSession
 *   - OTP-Verify:  ?token_hash=...&type=...   -> verifyOtp
 */
export default function AuthCallbackPage() {
  const router = useRouter();
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const supabase = createClient();
    const params = new URL(window.location.href).searchParams;
    const next = params.get("next") ?? "/app/dashboard";
    const code = params.get("code");
    const tokenHash = params.get("token_hash");
    const type = params.get("type") as EmailOtpType | null;

    (async () => {
      try {
        if (code) {
          const { error } = await supabase.auth.exchangeCodeForSession(code);
          if (error) throw error;
        } else if (tokenHash && type) {
          const { error } = await supabase.auth.verifyOtp({
            token_hash: tokenHash,
            type,
          });
          if (error) throw error;
        } else {
          throw new Error("Der Link enthält keine Anmeldedaten.");
        }
        // Harter Reload statt router.replace: stellt sicher, dass die
        // Middleware die frisch gesetzten Session-Cookies sieht.
        window.location.assign(next);
      } catch (e: unknown) {
        const msg =
          e instanceof Error ? e.message : "Anmeldung fehlgeschlagen.";
        setError(msg);
      }
    })();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  return (
    <div className="flex min-h-screen items-center justify-center px-4">
      <div className="w-full max-w-sm text-center">
        {error ? (
          <>
            <h1 className="text-[16px] font-medium text-ink-900">
              Anmeldung fehlgeschlagen
            </h1>
            <div className="mt-3 rounded-md border border-red-200 bg-red-50 px-3 py-2 text-[13px] text-red-700">
              {error}
            </div>
            <a
              href="/login"
              className="mt-4 inline-block text-[13px] text-petrol-700 underline hover:text-petrol-800"
            >
              Zurück zum Login
            </a>
          </>
        ) : (
          <p className="text-[14px] text-ink-600">
            Anmeldung wird abgeschlossen…
          </p>
        )}
      </div>
    </div>
  );
}
