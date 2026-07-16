import { LegalContent, Placeholder } from "@/components/marketing/legal-content";
import { companyInfo } from "@/lib/legal/company-info";
import { siteConfig } from "@/lib/site-config";

export const metadata = { title: "Datenschutz" };

// TODO(Patrick): Platzhalter in lib/legal/company-info.ts ersetzen, Region der
// Supabase-Instanz im Dashboard prüfen und eintragen, danach vor
// Live-Schaltung juristisch prüfen lassen (revDSG).
export default function Page() {
  return (
    <LegalContent
      title="Datenschutzerklärung"
      updated="16. Juli 2026"
      intro={
        <>
          Diese Erklärung informiert gemäss revidiertem Datenschutzgesetz
          (revDSG) darüber, welche Personendaten {siteConfig.name} bei der
          Nutzung von {siteConfig.domain} bearbeitet.
        </>
      }
      sections={[
        {
          heading: "1. Verantwortlicher",
          body: (
            <p>
              <Placeholder>{companyInfo.legalName}</Placeholder>,{" "}
              <Placeholder>{companyInfo.address.street}</Placeholder>,{" "}
              <Placeholder>{companyInfo.address.zipCity}</Placeholder>. Kontakt
              für Datenschutzanfragen:{" "}
              <a href={`mailto:${companyInfo.contactEmail}`} className="underline">
                {companyInfo.contactEmail}
              </a>
              .
            </p>
          ),
        },
        {
          heading: "2. Welche Daten wir bearbeiten",
          body: (
            <ul className="list-disc space-y-1.5 pl-5">
              <li>
                <strong className="font-medium text-ink-800">Konto:</strong>{" "}
                E-Mail-Adresse (Anmeldung erfolgt passwortlos per Magic
                Link).
              </li>
              <li>
                <strong className="font-medium text-ink-800">
                  Zeugnisinhalte:
                </strong>{" "}
                Name, Position und Beurteilungstexte der Person, für die ein
                Zeugnis erstellt wird, sowie Firmenangaben und -logo des
                ausstellenden Arbeitgebers.
              </li>
              <li>
                <strong className="font-medium text-ink-800">
                  Dokument-Metadaten:
                </strong>{" "}
                Kryptografischer Hash, Erstellungs- und Prüfzeitpunkte,
                QR-Code-Referenz zur Verifikation.
              </li>
            </ul>
          ),
        },
        {
          heading: "3. Zweck der Bearbeitung",
          body: (
            <p>
              Wir bearbeiten diese Daten, um die Erstellung, Absicherung und
              Prüfung von Arbeitszeugnissen technisch zu ermöglichen, den
              Zugang zu Ihrem Konto sicherzustellen und mit Ihnen zu
              kommunizieren (z.B. Einladungslinks, Systembenachrichtigungen).
            </p>
          ),
        },
        {
          heading: "4. Rechtsgrundlage",
          body: (
            <p>
              Die Bearbeitung erfolgt zur Erfüllung des Nutzungsvertrags mit
              Ihnen bzw. mit dem ausstellenden Arbeitgeber sowie gestützt auf
              Ihre Einwilligung, soweit diese eingeholt wird.
            </p>
          ),
        },
        {
          heading: "5. Empfänger und Auftragsbearbeiter",
          body: (
            <>
              <p>
                Wir setzen folgende Dienstleister als Auftragsbearbeiter ein:
              </p>
              <ul className="list-disc space-y-1.5 pl-5">
                <li>
                  <strong className="font-medium text-ink-800">Supabase</strong>{" "}
                  – Datenbank und Authentifizierung. Serverstandort:{" "}
                  <Placeholder>[Region im Supabase-Dashboard prüfen]</Placeholder>.
                </li>
                <li>
                  <strong className="font-medium text-ink-800">Vercel</strong>{" "}
                  – Hosting der Webanwendung.
                </li>
                <li>
                  <strong className="font-medium text-ink-800">Resend</strong>{" "}
                  – Versand transaktionaler E-Mails (Magic Link,
                  Einladungen). Anbieter mit Sitz in den USA; die
                  Datenübermittlung erfolgt gestützt auf{" "}
                  <Placeholder>
                    [anwendbaren Schutzmechanismus bestätigen, z.B.
                    Swiss-U.S. Data Privacy Framework oder
                    Standardvertragsklauseln]
                  </Placeholder>
                  .
                </li>
              </ul>
              <p>
                Mit allen Auftragsbearbeitern bestehen bzw. bestehen
                vorgesehen Auftragsbearbeitungsvereinbarungen (ADV).
              </p>
            </>
          ),
        },
        {
          heading: "6. Aufbewahrungsdauer",
          body: (
            <p>
              Wir bewahren Personendaten so lange auf, wie dies für die
              genannten Zwecke oder zur Erfüllung gesetzlicher
              Aufbewahrungspflichten erforderlich ist. Zeugnisdokumente und
              deren Hash bleiben zu Verifikationszwecken gespeichert, solange
              das Konto besteht.
            </p>
          ),
        },
        {
          heading: "7. Cookies",
          body: (
            <p>
              Wir setzen ausschliesslich technisch notwendige Cookies zur
              Aufrechterhaltung Ihrer Anmeldesitzung ein (Supabase-Auth). Es
              findet kein Tracking und keine Analyse Ihres Nutzungsverhaltens
              durch Dritte statt. Für diese Cookies ist keine gesonderte
              Einwilligung erforderlich.
            </p>
          ),
        },
        {
          heading: "8. Ihre Rechte",
          body: (
            <p>
              Sie haben das Recht auf Auskunft, Berichtigung, Löschung und
              Herausgabe Ihrer Personendaten sowie das Recht, einer
              Bearbeitung zu widersprechen, soweit gesetzlich vorgesehen.
              Kontaktieren Sie uns dazu unter{" "}
              <a href={`mailto:${companyInfo.contactEmail}`} className="underline">
                {companyInfo.contactEmail}
              </a>
              .
            </p>
          ),
        },
        {
          heading: "9. Datensicherheit",
          body: (
            <p>
              Zeugnisdokumente werden mit einem SHA-256-Hash abgesichert, um
              nachträgliche Veränderungen erkennbar zu machen. Die
              Übertragung erfolgt verschlüsselt (TLS).
            </p>
          ),
        },
        {
          heading: "10. Änderungen dieser Erklärung",
          body: (
            <p>
              Wir passen diese Datenschutzerklärung an, wenn sich die
              Datenbearbeitung oder die Rechtslage ändert. Massgeblich ist
              jeweils die aktuell auf {siteConfig.domain} publizierte
              Fassung.
            </p>
          ),
        },
      ]}
    />
  );
}
