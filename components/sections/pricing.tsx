import Link from "next/link";
import { cn } from "@/lib/utils";

// Während der Beta ist die Echtheitsprüfung faktisch kostenlos (Stripe ist noch
// ein Stub); der reguläre Preis bleibt durchgestrichen als Anker sichtbar.
// Die Klartext-Analyse ist noch nicht verdrahtet → `comingSoon:true` ("kommt
// bald"), damit kein nicht-vorhandenes Feature als verfügbar beworben wird.
// `beta:false` ohne comingSoon = dauerhaft gratis.
const tiers = [
  {
    name: "Erstellen",
    price: "CHF 0",
    regularPrice: null as string | null,
    sub: "Unbegrenzt kostenlos",
    beta: false,
    comingSoon: false,
    cta: "Kostenlos starten",
    href: "/app/certificates/new",
    features: [
      "Schweizer Arbeitszeugnis erstellen",
      "Führungskraft per Magic Link einladen",
      "Firmenlogo hochladen",
      "PDF-Generierung mit Hash und QR-Code",
      "Verifikation jederzeit möglich",
    ],
    featured: false,
    badge: null as string | null,
  },
  {
    name: "Echtheit prüfen",
    price: "CHF 19.90",
    regularPrice: "CHF 19.90" as string | null,
    sub: "Pro Prüfung",
    beta: true,
    comingSoon: false,
    cta: "Echtheit prüfen",
    href: "/verify",
    features: [
      "SHA-256-Hash neu berechnen",
      "Abgleich mit registriertem Original",
      "Manipulation erkennen",
      "Verifikationsbericht als PDF",
    ],
    featured: true,
    badge: "Jetzt verfügbar" as string | null,
  },
  {
    name: "Premium-Prüfung",
    price: "CHF 39.90",
    regularPrice: "CHF 39.90" as string | null,
    sub: "Echtheit + Analyse",
    beta: false,
    comingSoon: true,
    cta: "Mehr erfahren",
    href: "/verify",
    features: [
      "Vollständige Echtheitsprüfung",
      "Klartext-Zeugnisanalyse",
      "Stärken, schwächere Signale, Auffälligkeiten",
      "Schlussformel-Analyse",
      "Kombinierter PDF-Bericht",
    ],
    featured: false,
    badge: null as string | null,
  },
  {
    name: "Zeugnisanalyse",
    price: "CHF 29.90",
    regularPrice: "CHF 29.90" as string | null,
    sub: "Pro Zeugnis",
    beta: false,
    comingSoon: true,
    cta: "Mehr erfahren",
    href: "/verify",
    features: [
      "Formulierungen auswerten",
      "Gesamturteil und Vertrauensniveau",
      "Stärken und Schwächen",
      "Schlussformel-Analyse",
      "Analysebericht als PDF",
    ],
    featured: false,
    badge: null as string | null,
  },
];

export function PricingSection() {
  return (
    <section
      id="pricing"
      className="border-b border-ink-200 bg-white py-24 scroll-mt-20"
    >
      <div className="container-zx">
        <div className="grid items-end gap-6 sm:grid-cols-2 sm:gap-12">
          <div>
            <div className="eyebrow">Preise</div>
            <h2 className="headline-display mt-3 text-[32px] leading-[1.15] sm:text-[40px]">
              Faire, transparente Preise.
            </h2>
          </div>
          <p className="text-[15px] leading-relaxed text-ink-600 sm:text-right">
            Die Erstellung ist kostenlos und bleibt es. Die Echtheitsprüfung ist
            <strong className="font-medium text-ink-800">
              {" "}
              während der Beta ebenfalls kostenlos
            </strong>{" "}
            – die Klartext-Analyse folgt in Kürze.
          </p>
        </div>

        <div className="mt-14 grid gap-3 lg:grid-cols-4">
          {tiers.map((tier) => (
            <div
              key={tier.name}
              className={cn(
                "relative flex flex-col rounded-xl border bg-white p-6 transition-shadow",
                tier.featured
                  ? "border-petrol-600 shadow-xl shadow-petrol-900/10 lg:scale-[1.015]"
                  : "border-ink-200 hover:shadow-md hover:shadow-ink-900/5",
              )}
            >
              {tier.featured && (
                <span className="absolute -top-2.5 left-6 rounded-full bg-petrol-700 px-2.5 py-1 text-[10px] font-medium uppercase tracking-wider text-white">
                  {tier.badge}
                </span>
              )}

              <div>
                <div className="flex items-center gap-2">
                  <h3 className="text-[14px] font-medium tracking-tight text-ink-900">
                    {tier.name}
                  </h3>
                  {tier.beta && (
                    <span className="rounded-full bg-petrol-50 px-2 py-0.5 text-[10px] font-medium uppercase tracking-wider text-petrol-700 ring-1 ring-inset ring-petrol-600/20">
                      Beta
                    </span>
                  )}
                  {tier.comingSoon && (
                    <span className="rounded-full bg-ink-100 px-2 py-0.5 text-[10px] font-medium uppercase tracking-wider text-ink-500 ring-1 ring-inset ring-ink-300/40">
                      Bald
                    </span>
                  )}
                </div>
                {tier.comingSoon ? (
                  <>
                    <div className="mt-3 font-display text-[24px] font-light leading-none tracking-tight text-ink-400">
                      Kommt bald
                    </div>
                    <p className="mt-1 text-[12px] text-ink-500">
                      In Vorbereitung · regulär {tier.regularPrice}
                    </p>
                  </>
                ) : tier.beta ? (
                  <>
                    <div className="mt-3 font-display text-[28px] font-light leading-none tracking-tight text-ink-900">
                      Kostenlos
                    </div>
                    <p className="mt-1 text-[12px] text-ink-500">
                      <span className="line-through">
                        statt {tier.regularPrice}
                      </span>{" "}
                      · während der Beta
                    </p>
                  </>
                ) : (
                  <>
                    <div className="mt-3 font-display text-[28px] font-light leading-none tracking-tight text-ink-900">
                      {tier.price}
                    </div>
                    <p className="mt-1 text-[12px] text-ink-500">{tier.sub}</p>
                  </>
                )}
              </div>

              <ul className="mt-6 flex-1 space-y-2.5">
                {tier.features.map((f) => (
                  <li
                    key={f}
                    className="flex items-start gap-2 text-[13px] leading-relaxed text-ink-700"
                  >
                    <svg
                      width="13"
                      height="13"
                      viewBox="0 0 24 24"
                      fill="none"
                      stroke="currentColor"
                      strokeWidth="2.5"
                      strokeLinecap="round"
                      strokeLinejoin="round"
                      className="mt-1 flex-shrink-0 text-petrol-600"
                    >
                      <polyline points="20 6 9 17 4 12" />
                    </svg>
                    <span>{f}</span>
                  </li>
                ))}
              </ul>

              <Link
                href={tier.href}
                className={cn(
                  "mt-6 inline-flex items-center justify-center rounded-md px-4 py-2.5 text-[13px] font-medium transition-all active:scale-[0.985]",
                  tier.featured
                    ? "bg-petrol-700 text-white hover:bg-petrol-800"
                    : tier.comingSoon
                      ? "border border-ink-200 bg-white text-ink-500 hover:border-ink-300 hover:bg-ink-50"
                      : "border border-ink-200 bg-white text-ink-800 hover:border-ink-300 hover:bg-ink-50",
                )}
              >
                {tier.cta}
              </Link>
            </div>
          ))}
        </div>

        {/* Firmenpaket */}
        <div className="mt-6 flex flex-col items-start gap-4 rounded-xl border border-ink-200 bg-ink-50/50 px-6 py-5 sm:flex-row sm:items-center sm:justify-between">
          <div className="flex items-center gap-4">
            <div className="flex h-10 w-10 flex-shrink-0 items-center justify-center rounded-md bg-navy-700 text-white">
              <svg
                width="18"
                height="18"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                strokeWidth="1.7"
                strokeLinecap="round"
                strokeLinejoin="round"
              >
                <rect x="3" y="3" width="18" height="18" rx="2" />
                <path d="M9 9h6v6H9z" />
              </svg>
            </div>
            <div>
              <div className="flex flex-wrap items-baseline gap-x-2 text-[14px] font-medium tracking-tight text-ink-900">
                Firmenpaket
                <span className="text-[12px] font-normal text-ink-500">
                  <span className="line-through">ab CHF 49/Monat</span> ·
                  während der Beta kostenlos
                </span>
              </div>
              <div className="mt-0.5 text-[12.5px] text-ink-600">
                Mehrere Prüfungen · Recruiter-Zugang · Verifikationshistorie ·
                Zentrale Rechnungsstellung · Exportfunktion
              </div>
            </div>
          </div>
          <Link
            href="/contact"
            className="btn-secondary whitespace-nowrap py-2.5"
          >
            Firmenzugang anfragen
          </Link>
        </div>
      </div>
    </section>
  );
}
