import { NextResponse } from "next/server";

/**
 * Schlanker In-Memory Sliding-Window Rate-Limiter.
 * ----------------------------------------------------------------------------
 * BEWUSST best-effort: Der Zustand lebt im Prozessspeicher EINER einzelnen
 * Lambda-/Server-Instanz. Auf Vercel skalieren mehrere Instanzen unabhängig,
 * jede hält ihren eigenen Zähler — es gibt also KEINEN global verteilten
 * Schutz. Das reicht, um plumpes Hämmern einer Quelle abzubremsen (DoS-Dämpfer
 * und Kostenbremse für die öffentlichen Service-Role-Endpunkte), ersetzt aber
 * kein echtes verteiltes Rate-Limiting (z. B. via Upstash/Redis). Bei Bedarf
 * später gegen einen geteilten Store austauschen.
 */

/** Zeitstempel (ms) der jüngsten Treffer eines Schlüssels. */
type Bucket = number[];

const store = new Map<string, Bucket>();

// Backstop gegen unbegrenztes Wachstum der Map (viele verschiedene IPs):
// gelegentlich tote Buckets aufräumen.
let lastSweep = Date.now();
const SWEEP_INTERVAL_MS = 5 * 60 * 1000;
const MAX_BUCKET_AGE_MS = 60 * 60 * 1000;

function maybeSweep(now: number) {
  if (now - lastSweep < SWEEP_INTERVAL_MS) return;
  lastSweep = now;
  for (const [key, hits] of store) {
    const last = hits[hits.length - 1];
    if (last === undefined || now - last > MAX_BUCKET_AGE_MS) {
      store.delete(key);
    }
  }
}

export interface RateLimitResult {
  ok: boolean;
  /** Sekunden bis zum nächsten erlaubten Versuch (nur gesetzt, wenn !ok). */
  retryAfter?: number;
}

/**
 * Prüft und registriert einen Zugriff auf `key`. Erlaubt höchstens `limit`
 * Treffer innerhalb von `windowMs`. Alte Treffer altern beim Zugriff selbst aus.
 */
export function rateLimit(
  key: string,
  limit: number,
  windowMs: number,
): RateLimitResult {
  const now = Date.now();
  maybeSweep(now);

  const cutoff = now - windowMs;
  const hits = (store.get(key) ?? []).filter((t) => t > cutoff);

  if (hits.length >= limit) {
    // gefilterte (gealterte) Liste zurückschreiben, ohne neuen Treffer
    store.set(key, hits);
    const retryAfter = Math.ceil((hits[0] + windowMs - now) / 1000);
    return { ok: false, retryAfter: Math.max(retryAfter, 1) };
  }

  hits.push(now);
  store.set(key, hits);
  return { ok: true };
}

/**
 * Client-IP aus den Proxy-Headern bestimmen. Auf Vercel ist
 * `x-forwarded-for` gesetzt; der erste Eintrag ist der ursprüngliche Client.
 */
export function getClientIp(req: Request): string {
  const xff = req.headers.get("x-forwarded-for");
  if (xff) {
    const first = xff.split(",")[0]?.trim();
    if (first) return first;
  }
  const real = req.headers.get("x-real-ip")?.trim();
  if (real) return real;
  return "unknown";
}

/** Einheitliche 429-Antwort inkl. `Retry-After`-Header. */
export function tooManyRequests(retryAfter?: number): NextResponse {
  const headers: Record<string, string> = {};
  if (retryAfter) headers["Retry-After"] = String(retryAfter);
  return NextResponse.json(
    {
      error:
        "Zu viele Anfragen in kurzer Zeit. Bitte einen Moment warten und erneut versuchen.",
    },
    { status: 429, headers },
  );
}
