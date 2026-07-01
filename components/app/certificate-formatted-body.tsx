/**
 * Rendert den formatierten Zeugnis-Body (Tiptap-JSON) als HTML für die
 * A4-Vorschau. Nutzt denselben Block-/Run-Walker wie das PDF
 * (lib/certificate/tiptap-runs.ts) -> Vorschau und PDF zeigen denselben Text
 * mit denselben Formatierungen. Basis-Schrift/-Farbe erbt der Body vom Blatt
 * (CertificatePreview sheetFontFamily/sheetColor); Runs überschreiben per Mark.
 */

import React from "react";
import { tiptapToBlocks, type Run } from "@/lib/certificate/tiptap-runs";
import type { TiptapDoc } from "@/lib/certificate/tiptap-plaintext";

function runStyle(run: Run): React.CSSProperties {
  return {
    fontWeight: run.bold ? 700 : undefined,
    fontStyle: run.italic ? "italic" : undefined,
    textDecoration: run.underline ? "underline" : undefined,
    color: run.color || undefined,
    fontFamily: run.fontFamily || undefined,
  };
}

export function CertificateFormattedBody({ doc }: { doc: TiptapDoc | null }) {
  const blocks = tiptapToBlocks(doc);
  return (
    <>
      {blocks.map((block, bi) => {
        const runs = block.runs.map((run, ri) => (
          <span key={ri} style={runStyle(run)}>
            {run.text}
          </span>
        ));
        if (block.type === "bullet") {
          return (
            <div key={bi} style={{ marginLeft: "16px", marginBottom: "4px" }}>
              {"• "}
              {runs}
            </div>
          );
        }
        return (
          <p key={bi} style={{ margin: "0 0 14px 0" }}>
            {runs}
          </p>
        );
      })}
    </>
  );
}
