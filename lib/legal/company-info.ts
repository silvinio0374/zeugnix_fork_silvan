/**
 * Betreiber-Angaben für Impressum, AGB und Datenschutzerklärung.
 * zeugnix.ch ist ein Produkt der advisori GmbH (Domain und Produktname
 * bleiben "zeugnix"/"zeugnix.ch").
 *
 * ACHTUNG: `uid` ist noch ein Platzhalter (UID-Nummer nicht bekannt/nicht
 * verifiziert) - vor Live-Schaltung ergänzen. Alle drei Legal-Seiten vor
 * Live-Schaltung zusätzlich juristisch prüfen lassen (Impressumspflicht:
 * UWG Art. 3 Abs. 1 lit. s).
 */
export const companyInfo = {
  legalName: "advisori GmbH",
  legalForm: "GmbH",
  address: {
    street: "Neugasse 6",
    zipCity: "6300 Zug",
    country: "Schweiz",
  },
  uid: "[UID-Nummer, z.B. CHE-123.456.789]",
  commercialRegister: "Handelsregisteramt des Kantons Zug",
  representedBy: "Patrick Hitz, Geschäftsführer",
  contactEmail: "info@advisori.ch",
  contactPhone: undefined as string | undefined,
  jurisdiction: "Zug",
} as const;
