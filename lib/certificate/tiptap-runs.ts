/**
 * zeugnix.ch – Gemeinsamer Tiptap-JSON-Walker (Blöcke/Runs)
 * ----------------------------------------------------------------------------
 * Zerlegt das Tiptap-Body-JSON in eine einfache Block-/Run-Struktur, die SOWOHL
 * die HTML-Vorschau ALS AUCH das PDF rendern. Eine gemeinsame Quelle garantiert,
 * dass Vorschau und PDF denselben Text mit denselben Formatierungen zeigen.
 *
 * Rein strukturell, KEIN `@tiptap/*`-Import (läuft auch serverseitig im PDF).
 * Die Klartext-Konkatenation der Runs ist – modulo Whitespace – identisch zur
 * Hash-Projektion `tiptapToPlainText` (siehe Test in scripts/test-tiptap.ts).
 */

import type { TiptapMark, TiptapNode } from "./tiptap-plaintext";

export interface Run {
  text: string;
  bold: boolean;
  italic: boolean;
  underline: boolean;
  color?: string;
  fontFamily?: string;
}

export interface Block {
  type: "paragraph" | "bullet";
  runs: Run[];
}

function resolveMarks(marks?: TiptapMark[]): Omit<Run, "text"> {
  let bold = false;
  let italic = false;
  let underline = false;
  let color: string | undefined;
  let fontFamily: string | undefined;
  for (const m of marks ?? []) {
    if (m.type === "bold") bold = true;
    else if (m.type === "italic") italic = true;
    else if (m.type === "underline") underline = true;
    else if (m.type === "textStyle") {
      if (m.attrs?.color) color = m.attrs.color as string;
      if (m.attrs?.fontFamily) fontFamily = m.attrs.fontFamily as string;
    }
  }
  return { bold, italic, underline, color, fontFamily };
}

/** Sammelt die Runs eines Block-Knotens (Absatz oder Listenpunkt). */
function collectRuns(node: TiptapNode, runs: Run[]): void {
  for (const child of node.content ?? []) {
    if (child.type === "text") {
      runs.push({ text: child.text ?? "", ...resolveMarks(child.marks) });
    } else if (child.type === "hardBreak") {
      runs.push({ text: "\n", bold: false, italic: false, underline: false });
    } else if (child.content) {
      collectRuns(child, runs);
    }
  }
}

export function tiptapToBlocks(doc: TiptapNode | null | undefined): Block[] {
  if (!doc || !doc.content) return [];
  const blocks: Block[] = [];
  for (const node of doc.content) {
    if (node.type === "bulletList") {
      for (const item of node.content ?? []) {
        const runs: Run[] = [];
        collectRuns(item, runs);
        blocks.push({ type: "bullet", runs });
      }
    } else {
      const runs: Run[] = [];
      collectRuns(node, runs);
      // leere Absätze droppen (konsistent mit tiptapToPlainText)
      if (runs.some((r) => r.text.trim().length > 0)) {
        blocks.push({ type: "paragraph", runs });
      }
    }
  }
  return blocks;
}

/**
 * Klartext aus Blöcken – Bullets mit "• "-Präfix, Blöcke per \n\n. Dient im
 * Test als Gegenprobe zur Hash-Projektion (nach canonicalizeForHash gleich).
 */
export function blocksToPlainText(blocks: Block[]): string {
  return blocks
    .map((b) => {
      const text = b.runs.map((r) => r.text).join("").trim();
      return b.type === "bullet" ? "• " + text : text;
    })
    .join("\n\n");
}
