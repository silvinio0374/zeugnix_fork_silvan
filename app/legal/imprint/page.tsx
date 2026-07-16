import { LegalContent, Placeholder } from "@/components/marketing/legal-content";
import { companyInfo } from "@/lib/legal/company-info";
import { siteConfig } from "@/lib/site-config";

export const metadata = { title: "Impressum" };

// TODO(Patrick): UID-Nummer in lib/legal/company-info.ts ergänzen, danach
// diese Seite vor Live-Schaltung juristisch prüfen lassen
// (Impressumspflicht: UWG Art. 3 Abs. 1 lit. s).
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
              {companyInfo.legalName}
              <br />
              {companyInfo.address.street}
              <br />
              {companyInfo.address.zipCity}, {companyInfo.address.country}
              <br />
              UID: <Placeholder>{companyInfo.uid}</Placeholder>
              <br />
              Handelsregister: {companyInfo.commercialRegister}
            </p>
          ),
        },
        {
          heading: "Vertreten durch",
          body: <p>{companyInfo.representedBy}</p>,
        },
        {
          heading: "Kontakt",
          body: (
            <p>
              E-Mail:{" "}
              <a href={`mailto:${companyInfo.contactEmail}`} className="underline">
                {companyInfo.contactEmail}
              </a>
              {companyInfo.contactPhone && (
                <>
                  <br />
                  Telefon: {companyInfo.contactPhone}
                </>
              )}
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
