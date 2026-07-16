/**
 * Tests für die Tempus-Auswahl der Baustein-Engine (Präsens ⟷ Präteritum).
 *
 * Prüft:
 *  1. Der Präteritum-Pool deckt jeden Präsens-Key ab (keine Lücken/Waisen).
 *  2. Gender-Tokens und Platzhalter sind zwischen beiden Fassungen identisch.
 *  3. generateCertificate() wählt tatsächlich den passenden Pool je nach Typ
 *     (Zwischenzeugnis = Präsens, sonst Präteritum) und löst Tokens weiterhin auf.
 *
 * Ausführen:
 *   npx tsx scripts/test-tempus.ts
 */

import { readFileSync } from "fs";
import { join } from "path";
import { SKILLS } from "../lib/phrases/skills";
import {
  generateCertificate,
  type PhraseBlock,
  type EmployeeData,
  type CertificateData,
  type Evaluation,
} from "../lib/phrases/engine";

let passed = 0;
let failed = 0;

function assert(name: string, condition: boolean, details?: string) {
  if (condition) {
    console.log(`  ✓ ${name}`);
    passed++;
  } else {
    console.log(`  ✗ ${name}${details ? ` — ${details}` : ""}`);
    failed++;
  }
}

interface TokenizedEntry {
  tokenized: string;
  ok: boolean;
}

const TOKENIZED_PATH = join(process.cwd(), "scripts/data/bausteine-tokenized.json");
const TOKENIZED_PRAETERITUM_PATH = join(
  process.cwd(),
  "scripts/data/bausteine-tokenized-praeteritum.json",
);

const praesens: Record<string, TokenizedEntry> = JSON.parse(
  readFileSync(TOKENIZED_PATH, "utf-8"),
);
const praeteritum: Record<string, TokenizedEntry> = JSON.parse(
  readFileSync(TOKENIZED_PRAETERITUM_PATH, "utf-8"),
);

// ---------------------------------------------------------------------------
// 1. Abdeckung
// ---------------------------------------------------------------------------
console.log("\nAbdeckung: Präteritum-Pool vs. Präsens-Pool");
{
  const praesensKeys = Object.keys(praesens);
  const praeteritumKeys = Object.keys(praeteritum);
  const missing = praesensKeys.filter((k) => !praeteritum[k]);
  const extra = praeteritumKeys.filter((k) => !praesens[k]);
  assert(
    `Alle ${praesensKeys.length} Präsens-Keys haben eine Präteritum-Fassung`,
    missing.length === 0,
    missing.slice(0, 10).join(", "),
  );
  assert(
    "Keine zusätzlichen/verwaisten Präteritum-Keys",
    extra.length === 0,
    extra.slice(0, 10).join(", "),
  );
}

// ---------------------------------------------------------------------------
// 2. Struktur: Gender-Tokens und Platzhalter identisch
// ---------------------------------------------------------------------------
console.log("\nStruktur: Gender-Tokens/Platzhalter unverändert");
{
  let tokenMismatches = 0;
  const extractTokens = (s: string): string[] => (s.match(/\{\{[^{}]*\}\}/g) ?? []).sort();
  const extractPlaceholders = (s: string): string[] =>
    (s.match(/\{(vorname|nachname)\}/g) ?? []).sort();
  for (const [key, entry] of Object.entries(praesens)) {
    const other = praeteritum[key];
    if (!other) continue;
    const a = extractTokens(entry.tokenized);
    const b = extractTokens(other.tokenized);
    const ap = extractPlaceholders(entry.tokenized);
    const bp = extractPlaceholders(other.tokenized);
    if (JSON.stringify(a) !== JSON.stringify(b) || JSON.stringify(ap) !== JSON.stringify(bp)) {
      tokenMismatches++;
      if (tokenMismatches <= 10) {
        console.log(
          `    ✗ ${key}: praesens=${JSON.stringify(a.concat(ap))} praeteritum=${JSON.stringify(b.concat(bp))}`,
        );
      }
    }
  }
  assert("Gender-Tokens/Platzhalter bei allen Einträgen identisch", tokenMismatches === 0, `${tokenMismatches} Abweichungen`);
}

// ---------------------------------------------------------------------------
// 3. generateCertificate(): Tempus folgt certificate.type
// ---------------------------------------------------------------------------
console.log("\ngenerateCertificate(): Tempus folgt certificate.type");
{
  const skillByKey = new Map(SKILLS.map((s) => [s.key, s]));
  const blocks: PhraseBlock[] = [];
  let id = 0;
  const addPool = (pool: Record<string, TokenizedEntry>, tempus: "praesens" | "praeteritum") => {
    for (const [key, entry] of Object.entries(pool)) {
      const [skillKey, rating, variantStr] = key.split("|");
      const meta = skillByKey.get(skillKey);
      if (!meta) continue;
      blocks.push({
        id: String(id++),
        category: skillKey,
        subcategory: meta.theme,
        employee_type: meta.employeeType,
        gender: "d",
        rating: rating as PhraseBlock["rating"],
        variant: Number(variantStr),
        text: entry.tokenized,
        tempus,
      });
    }
  };
  addPool(praesens, "praesens");
  addPool(praeteritum, "praeteritum");

  const employee: EmployeeData = {
    firstName: "Anna",
    lastName: "Muster",
    gender: "f",
    functionTitle: "Sachbearbeiterin",
    entryDate: "2020-01-01",
    exitDate: "2024-01-01",
    isManager: false,
  };
  const evaluations: Evaluation[] = SKILLS.filter((s) => s.employeeType === "mitarbeiter").map(
    (s) => ({ category: s.key, rating: "gut" as const }),
  );

  const makeCert = (type: CertificateData["type"]): CertificateData => ({
    type,
    zeugnisTyp: type === "zwischen" ? "zwischen" : "schluss",
    tasks: [],
    thankEmployee: false,
    location: "Zürich",
    date: "2024-01-01",
    companyName: "Muster AG",
  });

  const zwischen = generateCertificate(employee, makeCert("zwischen"), evaluations, blocks);
  const schluss = generateCertificate(employee, makeCert("schluss"), evaluations, blocks);

  assert(
    "Zwischenzeugnis: keine 'Kein Baustein'-Warnungen",
    zwischen.warnings.filter((w) => w.includes("Kein Baustein")).length === 0,
    zwischen.warnings.join(" | "),
  );
  assert(
    "Schlusszeugnis: keine 'Kein Baustein'-Warnungen",
    schluss.warnings.filter((w) => w.includes("Kein Baustein")).length === 0,
    schluss.warnings.join(" | "),
  );
  assert("Zwischen- und Schlusstext unterscheiden sich (Tempus greift)", zwischen.text !== schluss.text);
  assert("Kein rohes Gender-Token im generierten Text (Zwischen)", !/\{\{/.test(zwischen.text));
  assert("Kein rohes Gender-Token im generierten Text (Schluss)", !/\{\{/.test(schluss.text));

  // Stichprobe Hauptaufgaben-Zeile (Tempus-Fix aus generateCertificate)
  const withTask = { ...makeCert("zwischen"), tasks: ["Buchhaltung"] };
  const withTaskZwischen = generateCertificate(employee, withTask, evaluations, blocks);
  const withTaskSchluss = generateCertificate(
    employee,
    { ...makeCert("schluss"), tasks: ["Buchhaltung"] },
    evaluations,
    blocks,
  );
  assert(
    "Hauptaufgaben-Zeile im Zwischenzeugnis im Präsens",
    withTaskZwischen.text.includes("Zu ihren Hauptaufgaben gehören:"),
  );
  assert(
    "Hauptaufgaben-Zeile im Schlusszeugnis im Präteritum",
    withTaskSchluss.text.includes("Zu ihren Hauptaufgaben gehörten:"),
  );
}

console.log(`\n${passed} bestanden, ${failed} fehlgeschlagen`);
process.exit(failed === 0 ? 0 : 1);
