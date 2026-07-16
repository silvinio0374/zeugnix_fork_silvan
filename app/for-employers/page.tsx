import Link from "next/link";
import type { Metadata } from "next";
import { WorkflowSection } from "@/components/sections/workflow";
import { BadgeSection } from "@/components/sections/badge";

export const metadata: Metadata = {
  title: "Für Arbeitgeber",
  description:
    "Arbeitszeugnisse strukturiert erstellen, mit Hash absichern und als Arbeitgeber-Siegel sichtbar machen – für KMU, HR-Abteilungen und Treuhänder.",
};

const kmuFeatures = [
  "Weniger Aufwand pro Zeugnis",
  "Einheitliche Beurteilungsstandards",
  "Professionelle Formulierungen",
  "Arbeitgeber-Siegel möglich",
];

const treuhandFeatures = [
  "Mandantenfähige Verwaltung",
  "Reduktion arbeitsrechtlicher Risiken",
  "Standardisierte Qualität",
  "Verifikationshistorie pro Mandant",
];

export default function Page() {
  return (
    <>
      {/* Hero */}
      <section className="border-b border-ink-200 bg-white py-24">
        <div className="container-zx max-w-3xl">
          <div className="eyebrow">Für Arbeitgeber, KMU & Treuhänder</div>
          <h1 className="headline-display mt-3 text-[40px] leading-[1.1] sm:text-[48px]">
            Arbeitszeugnisse, die weniger Aufwand machen.
            <br />
            <span className="font-display italic text-petrol-700">
              Strukturiert erstellt, automatisch abgesichert.
            </span>
          </h1>
          <p className="mt-5 text-[15px] leading-relaxed text-ink-600">
            Strukturierte Erstellung mit Bausteinen, Führungskräfte-Einbindung
            über Magic Link und automatische Hash-Absicherung – für KMU,
            HR-Abteilungen und Treuhänder mit mandantenfähiger Verwaltung.
          </p>
          <div className="mt-8 flex flex-wrap gap-3">
            <Link href="/app/certificates/new" className="btn-primary">
              Kostenlos starten
              <svg
                width="14"
                height="14"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                strokeWidth="2"
                strokeLinecap="round"
                strokeLinejoin="round"
              >
                <path d="M5 12h14M13 6l6 6-6 6" />
              </svg>
            </Link>
            <Link href="/how-it-works" className="btn-secondary">
              So funktioniert's
            </Link>
          </div>
        </div>
      </section>

      {/* Für wen */}
      <section className="border-b border-ink-200 bg-ink-50/50 py-24">
        <div className="container-zx">
          <div className="eyebrow">Für wen</div>
          <h2 className="headline-display mt-3 text-[32px] leading-[1.15] sm:text-[40px]">
            Gebaut für Unternehmen mit HR-Verantwortung.
          </h2>

          <div className="mt-10 grid gap-6 sm:grid-cols-2">
            <div className="rounded-xl border border-ink-200 bg-white p-7">
              <h3 className="text-[16px] font-medium tracking-tight text-ink-900">
                KMU & HR-Abteilungen
              </h3>
              <ul className="mt-5 space-y-3">
                {kmuFeatures.map((item) => (
                  <li
                    key={item}
                    className="flex items-start gap-2.5 text-[14px] text-ink-700"
                  >
                    <svg
                      width="14"
                      height="14"
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
                    <span>{item}</span>
                  </li>
                ))}
              </ul>
            </div>

            <div className="rounded-xl border border-ink-200 bg-white p-7">
              <h3 className="text-[16px] font-medium tracking-tight text-ink-900">
                Treuhänder & HR-Berater
              </h3>
              <ul className="mt-5 space-y-3">
                {treuhandFeatures.map((item) => (
                  <li
                    key={item}
                    className="flex items-start gap-2.5 text-[14px] text-ink-700"
                  >
                    <svg
                      width="14"
                      height="14"
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
                    <span>{item}</span>
                  </li>
                ))}
              </ul>
            </div>
          </div>
        </div>
      </section>

      <WorkflowSection />

      <BadgeSection />

      {/* Firmenpaket */}
      <section className="bg-white py-24">
        <div className="container-zx max-w-3xl">
          <div className="flex flex-col items-start gap-4 rounded-xl border border-ink-200 bg-ink-50/50 px-6 py-5 sm:flex-row sm:items-center sm:justify-between">
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
                    während der Beta kostenlos · regulär ab CHF 49/Monat nach
                    der Beta
                  </span>
                </div>
                <div className="mt-0.5 text-[12.5px] text-ink-600">
                  Mehrere Prüfungen · Recruiter-Zugang · Verifikationshistorie
                  · Zentrale Rechnungsstellung · Exportfunktion
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
    </>
  );
}
