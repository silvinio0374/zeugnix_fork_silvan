/**
 * zeugnix.ch – Tiptap-JSON -> @react-pdf
 * ----------------------------------------------------------------------------
 * Rendert den formatierten Body (Schrift/Farbe/Fett/Kursiv pro Run) ins PDF.
 * Nutzt denselben Block-/Run-Walker wie die HTML-Vorschau (lib/certificate/
 * tiptap-runs.ts) -> Vorschau und PDF zeigen garantiert denselben Text mit
 * denselben Formatierungen.
 *
 * HASH-SICHERHEIT: Die Konkatenation aller Run-Texte (in genau dieser
 * Reihenfolge, OHNE eingefügte Trennzeichen) ist – nach canonicalizeForHash –
 * identisch zur gehashten Klartext-Projektion. Runs nie mit Whitespace trennen.
 *
 * Style-Werte sind bewusst inline gehalten (nicht aus dem StyleSheet von
 * certificate.tsx importiert), bleiben aber deckungsgleich mit styles.body-
 * Paragraph / styles.bullet.
 */

import { Text } from "@react-pdf/renderer";
import React from "react";
import type { TiptapNode } from "@/lib/certificate/tiptap-plaintext";
import { tiptapToBlocks, type Run } from "@/lib/certificate/tiptap-runs";
import { pdfFontName, DEFAULT_FONT_KEY, DEFAULT_TEXT_COLOR } from "./fonts";

export interface PdfBaseStyle {
  fontKey: string;
  textColor: string;
}

function runStyle(run: Run, base: PdfBaseStyle) {
  return {
    fontFamily: pdfFontName(run.fontFamily ?? base.fontKey, run.bold, run.italic),
    color: run.color ?? base.textColor,
    ...(run.underline ? { textDecoration: "underline" as const } : {}),
  };
}

/**
 * Wandelt das Tiptap-Body-JSON in eine Liste von @react-pdf-<Text>-Absätzen.
 * Gibt null zurück, wenn kein verwertbarer Inhalt vorliegt (Caller fällt dann
 * auf den Plain-Text-Pfad zurück).
 */
export function tiptapToPdf(
  doc: TiptapNode | null | undefined,
  base: PdfBaseStyle,
): React.ReactElement[] | null {
  const blocks = tiptapToBlocks(doc);
  if (blocks.length === 0) return null;

  return blocks.map((block, bi) => {
    const runEls = block.runs.map((run, ri) => (
      <Text key={"r-" + ri} style={runStyle(run, base)}>
        {run.text}
      </Text>
    ));

    if (block.type === "bullet") {
      return (
        <Text
          key={"b-" + bi}
          style={{
            fontSize: 11,
            lineHeight: 1.6,
            marginLeft: 14,
            marginBottom: 3,
            fontFamily: pdfFontName(base.fontKey, false, false),
            color: base.textColor,
          }}
        >
          {"• "}
          {runEls}
        </Text>
      );
    }

    return (
      <Text
        key={"p-" + bi}
        style={{
          fontSize: 11,
          lineHeight: 1.6,
          textAlign: "justify",
          marginBottom: 11,
          fontFamily: pdfFontName(base.fontKey, false, false),
          color: base.textColor,
        }}
      >
        {runEls}
      </Text>
    );
  });
}

export const PDF_BASE_DEFAULT: PdfBaseStyle = {
  fontKey: DEFAULT_FONT_KEY,
  textColor: DEFAULT_TEXT_COLOR,
};
