import { LegalContent, Placeholder } from "@/components/marketing/legal-content";
import { companyInfo } from "@/lib/legal/company-info";
import { siteConfig } from "@/lib/site-config";

export const metadata = { title: "Impressum" };

// TODO(Patrick): Platzhalter in lib/legal/company-info.ts durch echte
// Betreiber-Angaben ersetzen, danach diese Seite vor Live-Schaltung
// juristisch prüfen lassen (Impressumspflicht: UWG Art. 3 Abs. 1 lit. s).
export default function Page() {
  return (
    <LegalContent
      title="Impressum"
      updated="16. Juli 2026"
      sections={[
        {
          heading: "Anbieter",
          body: (
            <p>
              <Placeholder>{companyInfo.legalName}</Placeholder>
              <br />
              <Placeholder>{companyInfo.address.street}</Placeholder>
              <br />
              <Placeholder>{companyInfo.address.zipCity}</Placeholder>,{" "}
              {companyInfo.address.country}
              <br />
              UID: <Placeholder>{companyInfo.uid}</Placeholder>
              <br />
              Handelsregister: <Placeholder>{companyInfo.commercialRegister}</Placeholder>
            </p>
          ),
        },
        {
          heading: "Vertreten durch",
          body: <p><Placeholder>{companyInfo.representedBy}</Placeholder></p>,
        },
        {
          heading: "Kontakt",
          body: (
            <p>
              E-Mail:{" "}
              <a href={`mailto:${companyInfo.contactEmail}`} className="underline">
                {companyInfo.contactEmail}
              </a>
              <br />
              Telefon: <Placeholder>{companyInfo.contactPhone}</Placeholder>
            </p>
          ),
        },
        {
          heading: "Haftungsausschluss",
          body: (
            <>
              <p>
                {siteConfig.name} unterstützt die strukturierte Erstellung,
                Absicherung und Prüfung von Schweizer Arbeitszeugnissen.
                Verantwortung für Wahrheit, Vollständigkeit und
                arbeitsrechtliche Zulässigkeit der Zeugnisinhalte verbleibt
                beim ausstellenden Arbeitgeber.
              </p>
              <p>
                Trotz sorgfältiger inhaltlicher Kontrolle übernehmen wir
                keine Haftung für die Inhalte externer Links. Für den
                Inhalt verlinkter Seiten sind ausschliesslich deren
                Betreiber verantwortlich.
              </p>
            </>
          ),
        },
        {
          heading: "Urheberrecht",
          body: (
            <p>
              Alle Inhalte dieser Website (Texte, Bilder, Design) sind
              urheberrechtlich geschützt. Eine Vervielfältigung oder
              Verwendung ausserhalb der Nutzung der Plattform bedarf der
              vorherigen schriftlichen Zustimmung.
            </p>
          ),
        },
      ]}
    />
  );
}
