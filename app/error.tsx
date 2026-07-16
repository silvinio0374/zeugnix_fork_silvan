"use client";

import { useEffect } from "react";

/**
 * Globaler Fallback fuer unerwartete Fehler (App Router error boundary).
 * Muss Client Component sein und `error`/`reset` entgegennehmen.
 */
export default function GlobalError({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  useEffect(() => {
    console.error("[app error boundary]", error);
  }, [error]);

  return (
    <section className="bg-white">
      <div className="container-zx flex min-h-[calc(100vh-4rem)] max-w-md flex-col items-center justify-center py-16 text-center">
        <div className="eyebrow">Fehler</div>
        <h1 className="headline-display mt-3 text-[32px] leading-[1.15]">
          Etwas ist schiefgelaufen
        </h1>
        <p className="mt-4 text-[14px] leading-relaxed text-ink-600">
          Es ist ein unerwarteter Fehler aufgetreten. Versuchen Sie es erneut
          oder kehren Sie zur Startseite zurück.
        </p>
        <div className="mt-8 flex flex-wrap justify-center gap-3">
          <button onClick={() => reset()} className="btn-primary">
            Erneut versuchen
          </button>
          <a href="/" className="btn-secondary">
            Zur Startseite
          </a>
        </div>
      </div>
    </section>
  );
}
