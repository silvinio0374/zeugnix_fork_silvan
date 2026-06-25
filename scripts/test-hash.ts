/**
 * Tests für die Hash-Engine.
 *
 * Ausführen:
 *   npm run test:hash   (bzw. npx tsx scripts/test-hash.ts)
 *
 * Absichtlich ohne Test-Framework, damit keine zusätzlichen Dependencies
 * nötig sind. Kerngedanke: Der Hash beim Finalisieren (über die Textquelle)
 * MUSS dem Hash beim Prüfen (über den aus dem PDF extrahierten, zwischen den
 * Sentinels isolierten Text) entsprechen.
 */

import {
  BODY_SENTINEL_START,
  BODY_SENTINEL_END,
  canonicalizeForHash,
  extractBodyBetweenSentinels,
  sha256,
} from "../lib/hash/canonicalize";

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

async function run() {
  console.log("\n=== Hash-Engine Tests ===\n");

  // ----- canonicalizeForHash -----
  console.log("canonicalizeForHash:");
  assert(
    "Mehrfach-Whitespace → ein Space",
    canonicalizeForHash("a    b\t\tc") === "a b c",
  );
  assert(
    "Newlines werden zu Spaces geplättet",
    canonicalizeForHash("a\n\n\n\nb") === "a b",
  );
  assert(
    "Whitespace-Variationen ergeben gleichen Output",
    canonicalizeForHash("Hallo  Welt\n\n\n\nDies\tist\tein  Test.") ===
      canonicalizeForHash("Hallo Welt Dies ist ein Test."),
  );
  assert("Trim am Rand", canonicalizeForHash("  text  ") === "text");
  assert(
    "Typografische Quotes → ASCII",
    canonicalizeForHash("“Hallo”") === '"Hallo"',
  );
  assert("En-Dash → Hyphen", canonicalizeForHash("a–b") === "a-b");
  assert("NBSP → Space", canonicalizeForHash("a b") === "a b");
  assert(
    "Bullet bleibt erhalten",
    canonicalizeForHash("• Aufgabe 1\n• Aufgabe 2") === "• Aufgabe 1 • Aufgabe 2",
  );

  // ----- sha256 (bekannte Vektoren) -----
  console.log("\nsha256:");
  assert(
    "SHA-256 von leerem String",
    (await sha256("")) ===
      "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
  );
  assert(
    "SHA-256 von 'a'",
    (await sha256("a")) ===
      "ca978112ca1bbdcafac231b39a23dc4da786eff8147c4e72b9807785afee48bb",
  );

  // ----- extractBodyBetweenSentinels -----
  console.log("\nextractBodyBetweenSentinels:");
  assert(
    "Body wird zwischen Sentinels herausgeschnitten",
    extractBodyBetweenSentinels(
      `Briefkopf XY ${BODY_SENTINEL_START} Der Zeugnistext. ${BODY_SENTINEL_END} Unterschriften`,
    )?.trim() === "Der Zeugnistext.",
  );
  assert(
    "Fehlende Marker → null",
    extractBodyBetweenSentinels("Kein Marker hier drin") === null,
  );
  assert(
    "Nur Start-Marker → null",
    extractBodyBetweenSentinels(`x ${BODY_SENTINEL_START} y`) === null,
  );
  assert(
    "Tolerant gegen Spaces in den Klammern (pdfjs-Verklebung)",
    extractBodyBetweenSentinels(
      "a [[ zeugnix : body-start ]] B [[ zeugnix : body-end ]] c",
    )?.trim() === "B",
  );

  // ----- End-to-End-Symmetrie (Kern-Regression) -----
  console.log("\nEnd-to-End-Symmetrie (Finalize ↔ Verify):");
  const body =
    "Frau Beispiel war vom 01.01.2020 bis 31.12.2024 tätig.\n\n" +
    "Zu ihren Hauptaufgaben gehörten:\n• A\n• B\n\n" +
    "Sie erfüllte die Aufgaben stets zu unserer vollsten Zufriedenheit.\n\n" +
    "Zürich, 15.01.2025";

  // Finalize-Seite: Hash über die reine Textquelle.
  const finalizeHash = await sha256(canonicalizeForHash(body));

  // Verify-Seite: simuliert pdfjs (alle Whitespaces → " ") + Sentinels + Rauschen
  // (Briefkopf davor, Unterschriften/Hash-Block danach).
  const pdfExtract =
    "Muster AG  Musterstrasse 1  8000 Zürich  Arbeitszeugnis  " +
    BODY_SENTINEL_START +
    " " +
    body.replace(/\s+/g, " ").trim() +
    " " +
    BODY_SENTINEL_END +
    "  Digital ausgestellt durch  Max Muster  Echtheitsnachweis (SHA-256)  abcdef";
  const verifyBody = extractBodyBetweenSentinels(pdfExtract);
  const verifyHash = verifyBody
    ? await sha256(canonicalizeForHash(verifyBody))
    : "NULL";

  assert(
    "Finalize-Hash == Verify-Hash (trotz Layout-/Whitespace-Unterschied)",
    finalizeHash === verifyHash,
    `${finalizeHash} != ${verifyHash}`,
  );
  assert(
    "Inhaltliche Änderung bricht den Hash",
    finalizeHash !== (await sha256(canonicalizeForHash(body + " zusätzlich"))),
  );

  // ----- Zusammenfassung -----
  console.log(`\n=== ${passed} passed, ${failed} failed ===\n`);
  if (failed > 0) process.exit(1);
}

run().catch((err) => {
  console.error(err);
  process.exit(1);
});
