/**
 * Betreiber-Angaben für Impressum, AGB und Datenschutzerklärung.
 *
 * ACHTUNG: Enthält Platzhalter (siehe einzelne Felder). Vor Live-Schaltung
 * mit den echten Angaben des Betreibers ersetzen und die drei Legal-Seiten
 * juristisch prüfen lassen (Impressumspflicht: UWG Art. 3 Abs. 1 lit. s).
 */
export const companyInfo = {
  legalName: "[FIRMENNAME AG/GmbH]",
  legalForm: "[Rechtsform, z.B. GmbH]",
  address: {
    street: "[Strasse und Hausnummer]",
    zipCity: "[PLZ Ort]",
    country: "Schweiz",
  },
  uid: "[UID-Nummer, z.B. CHE-123.456.789]",
  commercialRegister: "[Handelsregisteramt, z.B. Handelsregisteramt des Kantons Zürich]",
  representedBy: "[Name der vertretungsberechtigten Person]",
  contactEmail: "kontakt@zeugnix.ch",
  contactPhone: "[Telefonnummer, optional]",
  jurisdiction: "[Gerichtsstand, z.B. Zürich]",
} as const;
