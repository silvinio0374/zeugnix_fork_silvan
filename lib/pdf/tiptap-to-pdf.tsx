/**
 * zeugnix.ch – Tiptap-JSON -> @react-pdf
 * ----------------------------------------------------------------------------
 * Rendert den formatierten Body (Schrift/Farbe/Fett pro Run) ins PDF. Nutzt
 * denselben Block-/Run-Walker wie die HTML-Vorschau (lib/certificate/
 * tiptap-runs.ts) -> Vorschau und PDF zeigen garantiert denselben Text mit
 * denselben Formatierungen.
 *
 * HASH-SICHERHEIT: Die Konkatenation aller Run-Texte (in genau dieser
 * Reihenfolge, OHNE eingefügte Trennzeichen) ist – nach canonicalizeForHash –
 * identisch zur gehashten Klartext-Projektion. Runs nie mit Whitespace trennen.
 *
 * Alle Masse stammen aus lib/design/document-tokens.ts (BASE_TOKENS), damit
 * PDF und Vorschau nicht auseinanderlaufen können.
 */

import { Text } from "@react-pdf/renderer";
import React from "react";
import type { TiptapNode } from "@/lib/certificate/tiptap-plaintext";
import { tiptapToBlocks, type Run } from "@/lib/certificate/tiptap-runs";
import { BASE_TOKENS as T, type DocumentTheme } from "@/lib/design/document-tokens";
import { pdfFontName } from "./fonts";

function runStyle(run: Run, theme: DocumentTheme) {
  return {
    // Kursiv ist im Zeugnis unzulässig (siehe tiptap-runs.ts) -> immer aufrecht.
    fontFamily: pdfFontName(run.fontFamily ?? theme.fonts.body, run.bold, false),
    color: run.color ?? theme.colors.textPrimary,
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
  theme: DocumentTheme,
): React.ReactElement[] | null {
  const blocks = tiptapToBlocks(doc);
  if (blocks.length === 0) return null;

  const blockFont = pdfFontName(theme.fonts.body, false, false);

  return blocks.map((block, bi) => {
    const runEls = block.runs.map((run, ri) => (
      <Text key={"r-" + ri} style={runStyle(run, theme)}>
        {run.text}
      </Text>
    ));

    if (block.type === "bullet") {
      return (
        <Text
          key={"b-" + bi}
          style={{
            fontSize: T.fontSize.body,
            lineHeight: T.lineHeight.body,
            marginLeft: T.space.bulletMarginLeft,
            marginBottom: T.space.bulletMarginBottom,
            fontFamily: blockFont,
            color: theme.colors.textPrimary,
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
          fontSize: T.fontSize.body,
          lineHeight: T.lineHeight.body,
          textAlign: "justify",
          marginBottom: T.space.paragraphMarginBottom,
          fontFamily: blockFont,
          color: theme.colors.textPrimary,
        }}
      >
        {runEls}
      </Text>
    );
  });
}
