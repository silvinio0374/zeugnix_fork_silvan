/**
 * AUTO-GENERIERT von scripts/import-bausteine.ts – nicht von Hand editieren.
 * Skill-Metadaten des Zwischenzeugnis-Katalogs (Anzeige + Gruppierung im Formular,
 * Themen-Reihenfolge in der Engine). 'core' = im Quelldokument mit '*' markiert
 * (vorausgewählt). 'theme' = phrase_blocks.subcategory, 'key' = phrase_blocks.category.
 */

export interface SkillMeta {
  key: string;
  label: string;
  help?: string;
  theme: string;
  themeLabel: string;
  employeeType: "mitarbeiter" | "fuehrungskraft";
  core: boolean;
  order: number;
}

export const SKILLS: SkillMeta[] = [
  { key: "vorbild", label: "Vorbild", theme: "fuehrung", themeLabel: "Führung", employeeType: "fuehrungskraft", core: true, order: 0 },
  { key: "offenheit_vertrauen", label: "Offenheit und Vertrauen", theme: "fuehrung", themeLabel: "Führung", employeeType: "fuehrungskraft", core: false, order: 1 },
  { key: "verantwortung_uebertragen", label: "Verantwortung übertragen", theme: "fuehrung", themeLabel: "Führung", employeeType: "fuehrungskraft", core: false, order: 2 },
  { key: "lenkung_arbeitsleistung", label: "Lenkung und Arbeitsleistung", theme: "fuehrung", themeLabel: "Führung", employeeType: "fuehrungskraft", core: true, order: 3 },
  { key: "aktives_change_management", label: "Aktives Change Management", theme: "fuehrung", themeLabel: "Führung", employeeType: "fuehrungskraft", core: false, order: 4 },
  { key: "mitarbeiterfoerderung", label: "Mitarbeiterförderung", theme: "fuehrung", themeLabel: "Führung", employeeType: "fuehrungskraft", core: false, order: 5 },
  { key: "wissensaustausch", label: "Wissensaustausch", theme: "fuehrung", themeLabel: "Führung", employeeType: "fuehrungskraft", core: false, order: 6 },
  { key: "strategieorientierung", label: "Strategieorientierung", theme: "fuehrung", themeLabel: "Führung", employeeType: "fuehrungskraft", core: false, order: 7 },
  { key: "initiativ_fleiss", label: "Initiative und Fleiss", theme: "arbeitsbereitschaft_fachwissen", themeLabel: "Arbeitsbereitschaft und Fachwissen", employeeType: "mitarbeiter", core: true, order: 8 },
  { key: "selbstaendigkeit_nach_eintritt", label: "Selbständigkeit nach Eintritt", theme: "arbeitsbereitschaft_fachwissen", themeLabel: "Arbeitsbereitschaft und Fachwissen", employeeType: "mitarbeiter", core: false, order: 9 },
  { key: "motivation_engagement", label: "Motivation und Engagement", theme: "arbeitsbereitschaft_fachwissen", themeLabel: "Arbeitsbereitschaft und Fachwissen", employeeType: "mitarbeiter", core: true, order: 10 },
  { key: "unternehmensbeitrag", label: "Unternehmensbeitrag", theme: "arbeitsbereitschaft_fachwissen", themeLabel: "Arbeitsbereitschaft und Fachwissen", employeeType: "mitarbeiter", core: false, order: 11 },
  { key: "berufserfahrung", label: "Berufserfahrung", theme: "arbeitsbereitschaft_fachwissen", themeLabel: "Arbeitsbereitschaft und Fachwissen", employeeType: "mitarbeiter", core: true, order: 12 },
  { key: "fachliche_anforderungen", label: "Fachliche Anforderungen", theme: "arbeitsbereitschaft_fachwissen", themeLabel: "Arbeitsbereitschaft und Fachwissen", employeeType: "mitarbeiter", core: false, order: 13 },
  { key: "verantwortung_aufgabenbewaeltigung", label: "Verantwortung und Aufgabenbewältigung", theme: "arbeitsbereitschaft_fachwissen", themeLabel: "Arbeitsbereitschaft und Fachwissen", employeeType: "mitarbeiter", core: true, order: 14 },
  { key: "auffassungsgabe", label: "Auffassungsgabe", theme: "arbeitsbereitschaft_fachwissen", themeLabel: "Arbeitsbereitschaft und Fachwissen", employeeType: "mitarbeiter", core: false, order: 15 },
  { key: "innovation", label: "Innovation", theme: "arbeitsbereitschaft_fachwissen", themeLabel: "Arbeitsbereitschaft und Fachwissen", employeeType: "mitarbeiter", core: false, order: 16 },
  { key: "ausdauer_belastbarkeit", label: "Ausdauer und Belastbarkeit", theme: "arbeitsbereitschaft_fachwissen", themeLabel: "Arbeitsbereitschaft und Fachwissen", employeeType: "mitarbeiter", core: false, order: 17 },
  { key: "fachkenntnisse_lernbereitschaft", label: "Fachkenntnisse und Lernbereitschaft", theme: "arbeitsbereitschaft_fachwissen", themeLabel: "Arbeitsbereitschaft und Fachwissen", employeeType: "mitarbeiter", core: true, order: 18 },
  { key: "methodeneinsatz", label: "Methodeneinsatz", theme: "arbeitsbereitschaft_fachwissen", themeLabel: "Arbeitsbereitschaft und Fachwissen", employeeType: "mitarbeiter", core: false, order: 19 },
  { key: "verlaesslichkeit_pflichtbewusstsein", label: "Verlässlichkeit und Pflichtbewusstsein", theme: "arbeitsweise_leistung", themeLabel: "Arbeitsweise und Leistung", employeeType: "mitarbeiter", core: true, order: 20 },
  { key: "selbstaendigkeit_sorgfalt_genauigkeit", label: "Selbständigkeit, Sorgfalt und Genauigkeit", theme: "arbeitsweise_leistung", themeLabel: "Arbeitsweise und Leistung", employeeType: "mitarbeiter", core: true, order: 21 },
  { key: "termintreue", label: "Termintreue", theme: "arbeitsweise_leistung", themeLabel: "Arbeitsweise und Leistung", employeeType: "mitarbeiter", core: false, order: 22 },
  { key: "arbeitsorganisation", label: "Arbeitsorganisation", theme: "arbeitsweise_leistung", themeLabel: "Arbeitsweise und Leistung", employeeType: "mitarbeiter", core: false, order: 23 },
  { key: "arbeitsqualitaet", label: "Arbeitsqualität", theme: "arbeitsweise_leistung", themeLabel: "Arbeitsweise und Leistung", employeeType: "mitarbeiter", core: true, order: 24 },
  { key: "zielerreichung", label: "Zielerreichung", theme: "arbeitsweise_leistung", themeLabel: "Arbeitsweise und Leistung", employeeType: "mitarbeiter", core: false, order: 25 },
  { key: "zufriedenheit_leistung", label: "Zufriedenheit mit Leistung", theme: "arbeitsweise_leistung", themeLabel: "Arbeitsweise und Leistung", employeeType: "mitarbeiter", core: true, order: 26 },
  { key: "verhalten_gegenueber_dritten", label: "Verhalten gegenüber Dritten", theme: "persoenliches_verhalten", themeLabel: "Persönliches Verhalten", employeeType: "mitarbeiter", core: true, order: 27 },
  { key: "konfliktfaehigkeit", label: "Konfliktfähigkeit", theme: "persoenliches_verhalten", themeLabel: "Persönliches Verhalten", employeeType: "mitarbeiter", core: false, order: 28 },
  { key: "kommunikationsfaehigkeit", label: "Kommunikationsfähigkeit", theme: "persoenliches_verhalten", themeLabel: "Persönliches Verhalten", employeeType: "mitarbeiter", core: false, order: 29 },
  { key: "teamfaehigkeit", label: "Teamfähigkeit", theme: "persoenliches_verhalten", themeLabel: "Persönliches Verhalten", employeeType: "mitarbeiter", core: true, order: 30 },
  { key: "offenheit_fuer_feedback", label: "Offenheit für Feedback", theme: "persoenliches_verhalten", themeLabel: "Persönliches Verhalten", employeeType: "mitarbeiter", core: false, order: 31 },
  { key: "wissen_teilen", label: "Wissen teilen", theme: "persoenliches_verhalten", themeLabel: "Persönliches Verhalten", employeeType: "mitarbeiter", core: false, order: 32 },
  { key: "synergien_nutzen", label: "Synergien nutzen", theme: "unternehmertum", themeLabel: "Unternehmertum", employeeType: "mitarbeiter", core: false, order: 33 },
  { key: "flexibilitaet", label: "Flexibilität", theme: "unternehmertum", themeLabel: "Unternehmertum", employeeType: "mitarbeiter", core: false, order: 34 },
  { key: "kundenorientierung", label: "Kundenorientierung", theme: "unternehmertum", themeLabel: "Unternehmertum", employeeType: "mitarbeiter", core: false, order: 35 },
];
