/**
 * Rendert den formatierten Zeugnis-Body (Tiptap-JSON) als HTML für die
 * A4-Vorschau. Nutzt denselben Block-/Run-Walker wie das PDF
 * (lib/certificate/tiptap-runs.ts) und dieselben Design-Tokens
 * (lib/design/document-css.ts) -> Vorschau und PDF zeigen denselben Text mit
 * denselben Formatierungen. Runs überschreiben Farbe/Schrift per Mark.
 */

import React from "react";
import { tiptapToBlocks, type Run } from "@/lib/certificate/tiptap-runs";
import type { TiptapDoc } from "@/lib/certificate/tiptap-plaintext";
import { resolveTheme } from "@/lib/design/document-tokens";
import { buildDocumentCss } from "@/lib/design/document-css";

function runStyle(run: Run): React.CSSProperties {
  // Kein fontStyle: Kursiv ist im Zeugnis unzulässig (siehe tiptap-runs.ts).
  return {
    fontWeight: run.bold ? 700 : undefined,
    textDecoration: run.underline ? "underline" : undefined,
    color: run.color || undefined,
    fontFamily: run.fontFamily || undefined,
  };
}

export function CertificateFormattedBody({
  doc,
  themeId,
}: {
  doc: TiptapDoc | null;
  themeId?: string | null;
}) {
  const css = buildDocumentCss(resolveTheme(themeId));
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
            <div key={bi} style={css.formattedBullet}>
              {"• "}
              {runs}
            </div>
          );
        }
        return (
          <p key={bi} style={css.formattedParagraph}>
            {runs}
          </p>
        );
      })}
    </>
  );
}
