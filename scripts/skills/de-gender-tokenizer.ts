/**
 * ┌─────────────────────────────────────────────────────────────────────────┐
 * │ Skill: DE-Gender-Tokenizer                                                │
 * │ Funktion:   DE-Gendering (männlicher Text → {{m|f|d}}-Template-Tokens)    │
 * │ Erstellt:   2026-06-29                                                     │
 * │ Projekt:    zeugnix.ch (Phase 2 – Satzbaustein-Katalog)                    │
 * │ Wiederverwendbar: ja – generisch für jedes deutsche Templating-Projekt,    │
 * │   das eine Geschlechterauswahl m/f/d über Platzhalter-Tokens auflösen will.│
 * └─────────────────────────────────────────────────────────────────────────┘
 *
 * Wandelt deutschen, MÄNNLICH formulierten Text (der sich auf EINE Person
 * bezieht) in eine Vorlage mit Tokens der Form `{{maskulin|feminin|neutral}}`
 * um. Die Konsum-Engine ersetzt das Token zur Laufzeit nach Geschlecht
 * (m → 1. Wert, f → 2. Wert, d → 3. Wert).
 *
 *   "Er übernimmt seine Aufgaben."
 *   → "{{Er|Sie|Er/Sie}} übernimmt {{seine|ihre|seine/ihre}} Aufgaben."
 *
 * Nutzung (braucht ANTHROPIC_API_KEY beim Aufrufer):
 *   import Anthropic from "@anthropic-ai/sdk";
 *   const client = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY });
 *   const out = await genderTokenizeBatch(client, [{ id: "1", text: "Er ..." }]);
 *   const checked = await verifyGenderTokensBatch(client, [{ id: "1", original, tokenized }]);
 *
 * Bewusst über `messages.create` + JSON (stabilste SDK-Oberfläche) statt über
 * strukturierte Outputs, plus Validierung + ein Retry – robust für Einmal-Jobs.
 */

import type Anthropic from "@anthropic-ai/sdk";

// Default bewusst Sonnet: Geschlechter-Tokenisierung ist eine eng umrissene,
// regelbasierte Sprachaufgabe und läuft zusätzlich durch einen adversarialen
// Prüf-Pass – Opus wäre hier teuer ohne nennenswerten Qualitätsgewinn. Per
// GENDER_TOKENIZER_MODEL überschreibbar (z. B. für einen einmaligen Opus-Lauf).
const MODEL = process.env.GENDER_TOKENIZER_MODEL ?? "claude-sonnet-4-6";

// --------------------------------------------------------------- Prompts

const RULES = `Du bist ein präziser Linguist für deutsche Personalsprache. Du
erhältst Sätze, die sich auf EINE Person beziehen und durchgehend MÄNNLICH
formuliert sind. Wandle sie in eine geschlechtsneutrale Vorlage um, indem du
JEDES Wort, dessen Form vom GESCHLECHT DER PERSON abhängt, durch ein Token
ersetzt:

    {{maskulin|feminin|neutral}}

- maskulin = die ursprüngliche männliche Form
- feminin  = die weibliche Form
- neutral  = die Beidnennung mit Schrägstrich (z. B. "er/sie", "sein/ihr")

Beispiele (Gross-/Kleinschreibung am Satzanfang beibehalten!):
  er        → {{er|sie|er/sie}}            Er → {{Er|Sie|Er/Sie}}
  ihn       → {{ihn|sie|ihn/sie}}
  ihm       → {{ihm|ihr|ihm/ihr}}
  sein/e/r/s/m/n (Possessiv, je Deklination):
            sein   → {{sein|ihr|sein/ihr}}
            seine  → {{seine|ihre|seine/ihre}}
            seinem → {{seinem|ihrem|seinem/ihrem}}
            seiner → {{seiner|ihrer|seiner/ihrer}}
            seines → {{seines|ihres|seines/ihres}}
            seinen → {{seinen|ihren|seinen/ihren}}
  dessen    → {{dessen|deren|dessen/deren}}
  Herr      → {{Herr|Frau|Herr/Frau}}
  Vorgesetzten → {{Vorgesetzten|Vorgesetzte|Vorgesetzten/Vorgesetzte}}
  Mitarbeiter (= die Person) → {{Mitarbeiter|Mitarbeiterin|Mitarbeiter/in}}
  Personenbezogene Adjektive/Partizipien, die das Geschlecht zeigen, ebenso.

SEHR WICHTIG – NICHT tokenisieren:
- Platzhalter wie {vorname}, {nachname} und alle Zeichen in geschweiften Klammern
  bleiben UNVERÄNDERT.
- Wörter, die nur mit dem GRAMMATISCHEN Geschlecht eines Rollen-Substantivs
  übereinstimmen, NICHT anfassen. "Führungskraft", "Führungspersönlichkeit",
  "Fachkraft" sind grammatisch feminin – ein darauf bezogenes "die"/"motivierte"
  bleibt GLEICH, egal welches Geschlecht die Person hat.
  Beispiel: "… als motivierte Führungskraft, die handelt. Entscheidungen trifft er."
  → "die" und "motivierte" bleiben; nur "er" wird zu {{er|sie|er/sie}}.
- Inhalt, Wortstellung, Interpunktion und alle nicht-geschlechtsabhängigen Wörter
  bleiben exakt erhalten. Erfinde nichts dazu, lasse nichts weg.`;

const TOKENIZE_SYSTEM = `${RULES}

Du erhältst ein JSON-Array [{"id","text"}]. Antworte AUSSCHLIESSLICH mit einem
JSON-Array [{"id","tokenized"}] mit denselben ids und der tokenisierten Fassung.
Kein Fliesstext, keine Markdown-Codeblöcke.`;

const VERIFY_SYSTEM = `${RULES}

Du bist nun der adversariale PRÜFER. Du erhältst Paare aus Originalsatz
(männlich) und bereits tokenisierter Fassung. Prüfe streng:
1. Wurde JEDES personenbezogene geschlechtsabhängige Wort korrekt tokenisiert?
2. Wurde fälschlich etwas tokenisiert, das nur grammatisch (Rollen-Substantiv)
   übereinstimmt? → rückgängig.
3. Sind feminine und neutrale Formen grammatisch korrekt?
4. Blieb der Inhalt (inkl. {vorname}/{nachname}, Interpunktion) unverändert?

Antworte AUSSCHLIESSLICH mit JSON-Array
[{"id","final","ok":bool,"note":"kurz, nur wenn ok=false"}].
"final" ist die korrigierte (oder unveränderte) tokenisierte Fassung. Kein
Fliesstext, keine Codeblöcke.`;

// --------------------------------------------------------------- Helpers

/** Robustes JSON-Parsing: Codeblöcke strippen, sonst grössten []-Block nehmen. */
function parseJsonArray(raw: string): any[] {
  let s = raw.trim();
  s = s.replace(/^```(?:json)?\s*/i, "").replace(/\s*```$/i, "").trim();
  try {
    const v = JSON.parse(s);
    if (Array.isArray(v)) return v;
  } catch {
    /* unten weiterversuchen */
  }
  const start = s.indexOf("[");
  const end = s.lastIndexOf("]");
  if (start !== -1 && end > start) {
    return JSON.parse(s.slice(start, end + 1));
  }
  throw new Error(`Antwort ist kein JSON-Array: ${raw.slice(0, 200)}`);
}

async function callJson(
  client: Anthropic,
  system: string,
  userPayload: unknown,
): Promise<any[]> {
  const send = async () => {
    const resp = await client.messages.create({
      model: MODEL,
      max_tokens: 16000,
      thinking: { type: "adaptive" },
      system,
      messages: [{ role: "user", content: JSON.stringify(userPayload) }],
    });
    const block = resp.content.find((b) => b.type === "text") as
      | { type: "text"; text: string }
      | undefined;
    return parseJsonArray(block?.text ?? "");
  };
  try {
    return await send();
  } catch {
    // Ein Retry – transiente Fehler oder Formatabweichung.
    return await send();
  }
}

// --------------------------------------------------------------- API

export interface TokenizeItem {
  id: string;
  text: string;
}
export interface TokenizeResult {
  id: string;
  tokenized: string;
}

/** Tokenisiert einen Batch männlich formulierter Sätze. */
export async function genderTokenizeBatch(
  client: Anthropic,
  items: TokenizeItem[],
): Promise<TokenizeResult[]> {
  if (items.length === 0) return [];
  const byId = new Map<string, string>();

  const runFor = async (batch: TokenizeItem[]) => {
    const arr = await callJson(client, TOKENIZE_SYSTEM, batch);
    for (const r of arr) {
      if (r && typeof r.id === "string" && typeof r.tokenized === "string") {
        byId.set(r.id, r.tokenized);
      }
    }
  };

  await runFor(items);

  // Fehlende ids gezielt nachfordern – das Modell lässt in einem Batch
  // gelegentlich einzelne Einträge aus. NICHT hart abbrechen (sonst geht der
  // ganze Lauf verloren), sondern bis zu zweimal nur die Lücken nachholen.
  let missing = items.filter((it) => !byId.has(it.id));
  for (let attempt = 0; attempt < 2 && missing.length > 0; attempt++) {
    await runFor(missing);
    missing = items.filter((it) => !byId.has(it.id));
  }

  // Letzter Fallback: Originaltext (männlich) behalten. Die anschliessende
  // Prüfung/Restmarker-Erkennung flaggt das zuverlässig zur manuellen Review.
  return items.map((it) => ({
    id: it.id,
    tokenized: byId.get(it.id) ?? it.text,
  }));
}

export interface VerifyItem {
  id: string;
  original: string;
  tokenized: string;
}
export interface VerifyResult {
  id: string;
  final: string;
  ok: boolean;
  note?: string;
}

/** Adversariale Prüfung/Korrektur eines tokenisierten Batches. */
export async function verifyGenderTokensBatch(
  client: Anthropic,
  items: VerifyItem[],
): Promise<VerifyResult[]> {
  if (items.length === 0) return [];
  const byId = new Map<string, any>();

  const runFor = async (batch: VerifyItem[]) => {
    const arr = await callJson(client, VERIFY_SYSTEM, batch);
    for (const r of arr) if (r && typeof r.id === "string") byId.set(r.id, r);
  };

  await runFor(items);

  // Fehlende ids gezielt nachfordern (siehe genderTokenizeBatch).
  let missing = items.filter((it) => !byId.has(it.id));
  for (let attempt = 0; attempt < 2 && missing.length > 0; attempt++) {
    await runFor(missing);
    missing = items.filter((it) => !byId.has(it.id));
  }

  return items.map((it) => {
    const r = byId.get(it.id);
    if (!r || typeof r.final !== "string") {
      // Keine verwertbare Prüfantwort → tokenisierte Fassung behalten, markieren.
      return { id: it.id, final: it.tokenized, ok: false, note: "Prüfung ohne Antwort" };
    }
    return { id: it.id, final: r.final, ok: r.ok !== false, note: r.note };
  });
}

/**
 * Grobe Resterkennung: männliche Marker, die NICHT in einem {{…}}-Token oder
 * {…}-Platzhalter stehen. Heuristik für eine abschliessende Vollständigkeitsprüfung.
 */
export function findUntokenizedMaleMarkers(text: string): string[] {
  // Tokens und Platzhalter ausblenden, dann auf freistehende männliche Wörter prüfen.
  const masked = text
    .replace(/\{\{[^}]*\}\}/g, " ")
    .replace(/\{[^}]*\}/g, " ");
  const markers = [
    "er", "ihn", "ihm", "sein", "seine", "seiner", "seinem", "seines", "seinen",
    "dessen", "Herr",
  ];
  const found = new Set<string>();
  for (const m of markers) {
    const re = new RegExp(`(^|[^\\wäöüß])${m}([^\\wäöüß]|$)`, "i");
    if (re.test(masked)) found.add(m);
  }
  return [...found];
}