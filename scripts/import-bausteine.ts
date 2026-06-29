/**
 * Import-Pipeline für den Zwischenzeugnis-Satzbaustein-Katalog.
 *
 * Quelle: scripts/data/bausteine-zwischenzeugnis.txt (Word-Export als Text).
 *
 * TEIL A (dieses File): Parsen + deterministisches Normalisieren → strukturierte
 * Skill-/Varianten-Liste + JSON-Dump + Summary. BRAUCHT KEINEN API-KEY.
 *
 *   npx tsx scripts/import-bausteine.ts
 *
 * TEIL B (folgt): LLM-Tokenisierung der Geschlechter ({{m|f|d}}) + Ausgabe von
 * supabase/009_seed_bausteine.sql und lib/phrases/skills.ts. Braucht ANTHROPIC_API_KEY.
 *
 * Struktur der Quelle (verifiziert):
 *   "Für Führungskräfte"                          → employee_type=fuehrungskraft, Thema "fuehrung"
 *   "Für Mitarbeitende ohne Führungsfunktion"     → employee_type=mitarbeiter
 *     <Themen-Header>                              → subcategory
 *       <Skill-Header>      ('*'=Kern)             → category
 *         Ungenügend|Genügend|Gut|Sehr gut        → rating
 *           <Variante 1..N> (aufeinanderfolgende Zeilen)
 *   "Schlussformulierung" / "Dank an Mitarbeiter" → separat (für schluss_dank)
 */

import { readFileSync, writeFileSync } from "fs";
import { join } from "path";

// ---------------------------------------------------------------- Konstanten

const SOURCE = join(process.cwd(), "scripts/data/bausteine-zwischenzeugnis.txt");
const DUMP = join(process.cwd(), "scripts/data/bausteine-parsed.json");
const TOKENIZED = join(process.cwd(), "scripts/data/bausteine-tokenized.json");
const SQL_OUT = join(process.cwd(), "supabase/009_seed_bausteine.sql");
const SKILLS_OUT = join(process.cwd(), "lib/phrases/skills.ts");

// Alte Beurteilungs-Kategorien (Seed 002) → werden deaktiviert. Achtung:
// 'arbeitsqualitaet'/'zielerreichung' existieren auch als NEUE Skill-Keys –
// die Deaktivierung greift deshalb nur auf die alten Zeilen (subcategory='gesamt').
const OLD_CATEGORIES = [
  "fachliche_leistung",
  "arbeitsweise",
  "arbeitsqualitaet",
  "zielerreichung",
  "fuehrungsverhalten",
  "verhalten",
];
// Themen-Slugs der neuen Katalog-Bausteine (für idempotenten Re-Run-Delete).
const THEME_SLUGS = [
  "fuehrung",
  "arbeitsbereitschaft_fachwissen",
  "arbeitsweise_leistung",
  "persoenliches_verhalten",
  "unternehmertum",
];

type Rating = "ungenuegend" | "genuegend" | "gut" | "sehr_gut";
type EmployeeType = "mitarbeiter" | "fuehrungskraft";

const SECTION_FUEHRUNG = "Für Führungskräfte";
const SECTION_MITARBEITER = "Für Mitarbeitende ohne Führungsfunktion";
const SECTION_SCHLUSS = "Schlussformulierung";

// Themen-Header (nur im Mitarbeitenden-Abschnitt). Reihenfolge = Ausgabereihenfolge.
const THEME_HEADERS = [
  "Arbeitsbereitschaft und Fachwissen",
  "Arbeitsweise und Leistung",
  "Persönliches Verhalten",
  "Unternehmertum",
];

const RATING_HEADERS: Record<string, Rating> = {
  Ungenügend: "ungenuegend",
  Genügend: "genuegend",
  Gut: "gut",
  "Sehr gut": "sehr_gut",
};

// ---------------------------------------------------------------- Typen

interface ParsedVariant {
  rating: Rating;
  variant: number; // 1..N je (Skill, Rating)
  text: string; // normalisiert (Name → {vorname} {nachname}); Geschlecht noch männlich
}

interface ParsedSkill {
  key: string; // = phrase_blocks.category
  label: string;
  core: boolean; // '*' im Dokument
  theme: string; // = subcategory
  themeLabel: string;
  employeeType: EmployeeType;
  order: number; // globale Reihenfolge (Thema-dann-Skill)
  variants: ParsedVariant[];
}

// ---------------------------------------------------------------- Helpers

const STOPWORDS = new Set(["und", "für", "mit", "der", "die", "das"]);

/** "Selbständigkeit, Sorgfalt und Genauigkeit" → "selbstaendigkeit_sorgfalt_genauigkeit" */
function slug(input: string): string {
  return input
    .toLowerCase()
    .replace(/ä/g, "ae")
    .replace(/ö/g, "oe")
    .replace(/ü/g, "ue")
    .replace(/ß/g, "ss")
    .replace(/[^a-z0-9\s]/g, " ") // Kommas etc. raus
    .split(/\s+/)
    .filter((w) => w.length > 0 && !STOPWORDS.has(w))
    .join("_");
}

/** Deterministische Normalisierung einer Varianten-Zeile (ohne Geschlecht). */
function normalizeVariant(raw: string): string {
  let t = raw.trim();
  // Word-Export-Klebefehler: "stehtMax Mustermann" → "steht Max Mustermann"
  t = t.replace(/([a-zäöüß])(Max Mustermann)/g, "$1 $2");
  // Name → Platzhalter (passt zur Engine: {vorname} {nachname})
  t = t.replace(/Max Mustermann/g, "{vorname} {nachname}");
  // Mehrfach-Whitespace zusammenziehen
  t = t.replace(/\s+/g, " ").trim();
  return t;
}

function stripTrailingColon(s: string): string {
  return s.replace(/:\s*$/, "").trim();
}

// ---------------------------------------------------------------- Parser

interface ParseResult {
  skills: ParsedSkill[];
  schlussLines: string[]; // Rohzeilen des Schluss-/Dank-Abschnitts (Teil B)
  warnings: string[];
}

function parse(content: string): ParseResult {
  const lines = content.split(/\r?\n/);

  // Index der nächsten nicht-leeren Zeile (für Skill-Header-Lookahead).
  function nextNonEmpty(from: number): string | null {
    for (let j = from + 1; j < lines.length; j++) {
      const t = lines[j].trim();
      if (t !== "") return t;
    }
    return null;
  }

  const skills: ParsedSkill[] = [];
  const schlussLines: string[] = [];
  const warnings: string[] = [];

  let employeeType: EmployeeType | null = null;
  let themeLabel: string | null = null; // null = noch kein Thema (Führungskräfte: implizit)
  let inSchluss = false;
  let current: ParsedSkill | null = null;
  let currentRating: Rating | null = null;
  let order = 0;

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i].trim();
    if (line === "") continue;

    // Schluss-Abschnitt: ab hier nur noch Rohzeilen sammeln.
    if (inSchluss) {
      schlussLines.push(line);
      continue;
    }

    // --- Abschnitts-Header ---
    if (line === SECTION_FUEHRUNG) {
      employeeType = "fuehrungskraft";
      themeLabel = "Führung"; // implizites Thema
      current = null;
      currentRating = null;
      continue;
    }
    if (line === SECTION_MITARBEITER) {
      employeeType = "mitarbeiter";
      themeLabel = null;
      current = null;
      currentRating = null;
      continue;
    }
    if (line === SECTION_SCHLUSS) {
      inSchluss = true;
      schlussLines.push(line);
      current = null;
      currentRating = null;
      continue;
    }

    // Vor dem ersten Abschnitt (Titelzeile o. ä.) ignorieren.
    if (employeeType === null) continue;

    // --- Themen-Header (nur Mitarbeitende) ---
    if (THEME_HEADERS.includes(line)) {
      themeLabel = line;
      current = null;
      currentRating = null;
      continue;
    }

    // --- Bewertungsstufen-Header ---
    const ratingKey = stripTrailingColon(line);
    if (RATING_HEADERS[ratingKey] !== undefined) {
      currentRating = RATING_HEADERS[ratingKey];
      continue;
    }

    // --- Skill-Header vs. Variante ---
    // Ein Skill-Header ist eine Zeile, deren NÄCHSTE nicht-leere Zeile "Ungenügend"
    // ist (jeder Skill beginnt mit der Stufe Ungenügend).
    const nxt = nextNonEmpty(i);
    const nxtIsUngenuegend =
      nxt !== null && RATING_HEADERS[stripTrailingColon(nxt)] === "ungenuegend";

    if (nxtIsUngenuegend) {
      const core = line.startsWith("*");
      const label = line.replace(/^\*/, "").trim();
      const theme = employeeType === "fuehrungskraft" ? "fuehrung" : slug(themeLabel ?? "");
      const tLabel = themeLabel ?? "Führung";
      if (!theme) warnings.push(`Skill "${label}" ohne Thema (employeeType=${employeeType}).`);
      current = {
        key: slug(label),
        label,
        core,
        theme,
        themeLabel: tLabel,
        employeeType,
        order: order++,
        variants: [],
      };
      skills.push(current);
      currentRating = null;
      continue;
    }

    // --- Variante ---
    if (current && currentRating) {
      const variantNo =
        current.variants.filter((v) => v.rating === currentRating).length + 1;
      current.variants.push({
        rating: currentRating,
        variant: variantNo,
        text: normalizeVariant(line),
      });
    } else {
      warnings.push(`Unzugeordnete Zeile (kein Skill/Rating aktiv): "${line.slice(0, 60)}"`);
    }
  }

  return { skills, schlussLines, warnings };
}

// ---------------------------------------------------------------- Validierung / Summary

function summarize(result: ParseResult): void {
  const { skills, schlussLines, warnings } = result;

  console.log("\n=== Parser-Ergebnis: Zwischenzeugnis-Katalog ===\n");

  // Gruppierung Abschnitt → Thema
  const byType: Record<string, ParsedSkill[]> = {};
  for (const s of skills) {
    (byType[s.employeeType] ??= []).push(s);
  }

  let totalVariants = 0;
  const issues: string[] = [];
  const dupKeys = new Set<string>();
  const seenKeys = new Set<string>();

  for (const type of Object.keys(byType)) {
    console.log(`■ ${type}  (${byType[type].length} Skills)`);
    const byTheme: Record<string, ParsedSkill[]> = {};
    for (const s of byType[type]) (byTheme[s.themeLabel] ??= []).push(s);

    for (const theme of Object.keys(byTheme)) {
      console.log(`  ▸ ${theme} (${slug(theme === "Führung" ? "fuehrung" : theme)})`);
      for (const s of byTheme[theme]) {
        // Varianten je Rating zählen
        const perRating: Record<Rating, number> = {
          ungenuegend: 0,
          genuegend: 0,
          gut: 0,
          sehr_gut: 0,
        };
        for (const v of s.variants) perRating[v.rating]++;
        totalVariants += s.variants.length;

        // Checks
        const missing = (Object.keys(perRating) as Rating[]).filter((r) => perRating[r] === 0);
        if (missing.length) issues.push(`${s.key}: fehlende Stufe(n) ${missing.join(", ")}`);
        if (seenKeys.has(s.key)) dupKeys.add(s.key);
        seenKeys.add(s.key);
        const leftover = s.variants.filter((v) => /Max|Mustermann/.test(v.text));
        if (leftover.length) issues.push(`${s.key}: ${leftover.length} Variante(n) mit Rest "Max/Mustermann"`);

        console.log(
          `      ${s.core ? "★" : "·"} ${s.label}  [${s.key}]  ` +
            `U${perRating.ungenuegend}/G${perRating.genuegend}/Gut${perRating.gut}/SG${perRating.sehr_gut}`,
        );
      }
    }
    console.log("");
  }

  console.log(
    `Σ Skills: ${skills.length} | Kern (★): ${skills.filter((s) => s.core).length} | ` +
      `Varianten: ${totalVariants} | Schluss-Zeilen: ${schlussLines.length}`,
  );

  if (dupKeys.size) issues.push(`Doppelte Skill-Keys: ${[...dupKeys].join(", ")}`);

  if (issues.length) {
    console.log(`\n⚠ ${issues.length} Auffälligkeit(en):`);
    for (const x of issues) console.log(`   - ${x}`);
  } else {
    console.log("\n✓ Keine strukturellen Auffälligkeiten.");
  }

  if (warnings.length) {
    console.log(`\n⚠ ${warnings.length} Parser-Warnung(en):`);
    for (const w of warnings.slice(0, 15)) console.log(`   - ${w}`);
    if (warnings.length > 15) console.log(`   … (+${warnings.length - 15} weitere)`);
  }
}

// ---------------------------------------------------------------- Teil A: Parse + Dump

function parseAndDump(): ParseResult {
  const content = readFileSync(SOURCE, "utf-8");
  const result = parse(content);
  summarize(result);

  writeFileSync(DUMP, JSON.stringify(result, null, 2), "utf-8");
  console.log(`\n→ JSON-Dump geschrieben: ${DUMP}`);

  // Beispiel-Stichproben (ein Kern-Skill je Abschnitt, alle Stufen).
  console.log("\n=== Stichproben (normalisiert, Geschlecht noch männlich) ===");
  const samples = [
    result.skills.find((s) => s.employeeType === "fuehrungskraft" && s.core),
    result.skills.find((s) => s.employeeType === "mitarbeiter" && s.core),
  ].filter(Boolean) as ParsedSkill[];
  for (const s of samples) {
    console.log(`\n● ${s.label} [${s.key}] (${s.employeeType}/${s.theme})`);
    for (const v of s.variants) {
      console.log(`   ${v.rating}#${v.variant}: ${v.text}`);
    }
  }
  return result;
}

// ---------------------------------------------------------------- Teil B: Tokenisierung (Key)

const variantId = (skillKey: string, rating: Rating, variant: number) =>
  `${skillKey}|${rating}|${variant}`;

/** Begrenzte Parallelität für die API-Aufrufe. */
async function mapPool<T, R>(
  items: T[],
  poolSize: number,
  fn: (item: T, index: number) => Promise<R>,
): Promise<R[]> {
  const results: R[] = new Array(items.length);
  let next = 0;
  async function worker() {
    while (next < items.length) {
      const idx = next++;
      results[idx] = await fn(items[idx], idx);
    }
  }
  await Promise.all(
    Array.from({ length: Math.min(poolSize, items.length) }, worker),
  );
  return results;
}

interface TokenizedEntry {
  tokenized: string;
  ok: boolean;
  note?: string;
  leftover?: string[];
}

async function tokenizeAll(result: ParseResult): Promise<void> {
  const { loadEnvConfig } = await import("@next/env");
  loadEnvConfig(process.cwd());

  const apiKey = process.env.ANTHROPIC_API_KEY;
  if (!apiKey) {
    console.error("\n✗ ANTHROPIC_API_KEY fehlt (.env.local). Tokenisierung abgebrochen.");
    process.exit(1);
  }

  const { default: Anthropic } = await import("@anthropic-ai/sdk");
  const { genderTokenizeBatch, verifyGenderTokensBatch, findUntokenizedMaleMarkers } =
    await import("./skills/de-gender-tokenizer");
  const client = new Anthropic({ apiKey, maxRetries: 5 });

  console.log(`\n=== Tokenisierung (Claude, ${result.skills.length} Skills) ===\n`);

  // Cache laden: bereits ok-tokenisierte Varianten werden NICHT erneut an die
  // API geschickt. So kostet ein Re-Run (z. B. nach Katalog-Änderung oder
  // Absturz) nur noch die offenen/fehlerhaften Varianten – nicht alles neu.
  let out: Record<string, TokenizedEntry> = {};
  try {
    out = JSON.parse(readFileSync(TOKENIZED, "utf-8"));
    const cached = Object.values(out).filter((e) => e.ok).length;
    if (cached) console.log(`  (Cache: ${cached} Varianten bereits ok – werden übersprungen)\n`);
  } catch {
    /* kein Cache vorhanden – Vollerstellung */
  }

  await mapPool(result.skills, 3, async (skill) => {
    // Nur Varianten verarbeiten, die noch nicht erfolgreich tokenisiert sind.
    const items = skill.variants
      .map((v) => ({ id: variantId(skill.key, v.rating, v.variant), text: v.text }))
      .filter((it) => !out[it.id]?.ok);
    if (items.length === 0) {
      console.log(`  ⏭ ${skill.key} (komplett aus Cache)`);
      return;
    }

    // Pass 1: tokenisieren
    const toks = await genderTokenizeBatch(client, items);
    // Pass 2: adversarisch prüfen / korrigieren
    const verifyItems = toks.map((t) => ({
      id: t.id,
      original: items.find((i) => i.id === t.id)!.text,
      tokenized: t.tokenized,
    }));
    const checked = await verifyGenderTokensBatch(client, verifyItems);

    for (const c of checked) {
      const leftover = findUntokenizedMaleMarkers(c.final);
      const ok = c.ok && leftover.length === 0;
      out[c.id] = {
        tokenized: c.final,
        ok,
        note: c.note,
        leftover: leftover.length ? leftover : undefined,
      };
    }
    // Inkrementell speichern – ein Absturz/Abbruch verliert nicht den ganzen
    // Lauf, und der Cache greift beim nächsten Start sofort. (writeFileSync ist
    // synchron → keine Verschränkung trotz Pool.)
    writeFileSync(TOKENIZED, JSON.stringify(out, null, 2), "utf-8");
    console.log(`  ✓ ${skill.key} (${items.length} Varianten)`);
  });

  // Geflaggte Varianten (nicht ok) aus dem Gesamtbestand erheben.
  const flagged: string[] = [];
  for (const [id, e] of Object.entries(out)) {
    if (!e.ok) {
      flagged.push(
        `${id}${e.note ? ` – ${e.note}` : ""}` +
          `${e.leftover?.length ? ` – Rest: ${e.leftover.join(",")}` : ""}`,
      );
    }
  }

  writeFileSync(TOKENIZED, JSON.stringify(out, null, 2), "utf-8");
  console.log(
    `\n→ Tokenisiert: ${TOKENIZED} (${Object.keys(out).length} Varianten)`,
  );
  if (flagged.length) {
    console.log(`\n⚠ ${flagged.length} Variante(n) zur manuellen Review markiert:`);
    for (const f of flagged.slice(0, 50)) console.log(`   - ${f}`);
    if (flagged.length > 50) console.log(`   … (+${flagged.length - 50} weitere)`);
  } else {
    console.log("\n✓ Alle Varianten von der Prüfung als ok markiert.");
  }
}

// ---------------------------------------------------------------- Emit: skills.ts + SQL

function emit(result: ParseResult): void {
  // --- lib/phrases/skills.ts (deterministisch, unabhängig von der Tokenisierung) ---
  const skillLines = result.skills.map(
    (s) =>
      `  { key: ${JSON.stringify(s.key)}, label: ${JSON.stringify(s.label)}, ` +
      `theme: ${JSON.stringify(s.theme)}, themeLabel: ${JSON.stringify(s.themeLabel)}, ` +
      `employeeType: ${JSON.stringify(s.employeeType)}, core: ${s.core}, order: ${s.order} },`,
  );
  const skillsTs = `/**
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
${skillLines.join("\n")}
];
`;
  writeFileSync(SKILLS_OUT, skillsTs, "utf-8");
  console.log(`→ ${SKILLS_OUT} (${result.skills.length} Skills)`);

  // --- supabase/009_seed_bausteine.sql (braucht die LLM-Tokenisierung) ---
  let tokenized: Record<string, TokenizedEntry>;
  try {
    tokenized = JSON.parse(readFileSync(TOKENIZED, "utf-8"));
  } catch {
    console.log(`→ SQL übersprungen: ${TOKENIZED} fehlt – erst "--tokenize" laufen lassen.`);
    return;
  }
  const rows: string[] = [];
  let missing = 0;
  const sqlEsc = (s: string) => s.replace(/'/g, "''");
  for (const s of result.skills) {
    for (const v of s.variants) {
      const id = variantId(s.key, v.rating, v.variant);
      const entry = tokenized[id];
      if (!entry) missing++;
      const text = entry?.tokenized ?? v.text; // Fallback: normalisiert (männlich)
      rows.push(
        `('${s.key}', '${s.theme}', '${s.employeeType}', 'd', '${v.rating}', ${v.variant}, '${sqlEsc(text)}')`,
      );
    }
  }

  const sql = `-- 009_seed_bausteine.sql
-- AUTO-GENERIERT von scripts/import-bausteine.ts (Quelle: scripts/data/bausteine-zwischenzeugnis.txt
-- + LLM-Geschlechter-Tokenisierung in scripts/data/bausteine-tokenized.json).
-- ${rows.length} Bausteine, ${result.skills.length} Fähigkeiten. Gender='d' (Tokens {{m|f|d}} im Text).

begin;

-- 1) Alte Beurteilungs-Kategorien (Seed 002) deaktivieren – NICHT löschen, damit
--    finalisierte Zeugnisse (immutabler Text/Hash) gültig bleiben. subcategory='gesamt'
--    grenzt sie von neuen Skills mit gleichem Key (arbeitsqualitaet/zielerreichung) ab.
update public.phrase_blocks set active = false
 where category in (${OLD_CATEGORIES.map((c) => `'${c}'`).join(", ")})
   and subcategory = 'gesamt';

-- 2) Vorhandene Katalog-Bausteine entfernen (idempotenter Re-Run; berührt
--    einleitung/schluss nicht, da andere subcategory).
delete from public.phrase_blocks
 where subcategory in (${THEME_SLUGS.map((t) => `'${t}'`).join(", ")});

-- 3) Neue Bausteine einfügen (signal_strength/tonality/warning_level/active = Defaults).
insert into public.phrase_blocks (category, subcategory, employee_type, gender, rating, variant, text) values
${rows.join(",\n")};

commit;
`;
  writeFileSync(SQL_OUT, sql, "utf-8");
  console.log(`→ ${SQL_OUT} (${rows.length} INSERT-Zeilen${missing ? `, ⚠ ${missing} ohne Tokenisierung (Fallback männlich)` : ""})`);
}

// ---------------------------------------------------------------- Main

async function main(): Promise<void> {
  const args = process.argv.slice(2);
  const result = parseAndDump();

  if (args.includes("--tokenize")) {
    await tokenizeAll(result);
  }
  if (args.includes("--emit")) {
    emit(result);
  }
  if (!args.includes("--tokenize") && !args.includes("--emit")) {
    console.log(
      "\nNächste Schritte:\n" +
        "  --tokenize   Geschlechter via Claude tokenisieren → bausteine-tokenized.json (braucht ANTHROPIC_API_KEY)\n" +
        "  --emit       skills.ts + 009_seed_bausteine.sql schreiben (nach --tokenize)",
    );
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
