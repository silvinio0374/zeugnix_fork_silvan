"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { useRouter } from "next/navigation";
import { useEditor, EditorContent, type Editor } from "@tiptap/react";
import StarterKit from "@tiptap/starter-kit";
import { TextStyle, Color, FontFamily } from "@tiptap/extension-text-style";
import { useCertificateWorkspace } from "./certificate-workspace";
import { CertificatePreview } from "./certificate-preview";
import { CertificateFormattedBody } from "./certificate-formatted-body";
import {
  plainTextToTiptap,
  tiptapToPlainText,
  type TiptapDoc,
} from "@/lib/certificate/tiptap-plaintext";
import {
  CERTIFICATE_FONTS,
  fontConfig,
  DEFAULT_FONT_KEY,
  DEFAULT_TEXT_COLOR,
} from "@/lib/pdf/fonts";

interface Props {
  certificateId: string;
  generatedText: string;
  initialFormattedContent?: TiptapDoc | null;
  finalized: boolean;
  baseFontKey?: string | null;
  baseTextColor?: string | null;
  // Daten für die A4-Vorschau
  company: any;
  employee: any;
  type: string;
  hash?: string | null;
}

type SaveStatus = "idle" | "typing" | "saving" | "saved" | "error";

export function CertificateRichWorkspace({
  certificateId,
  generatedText,
  initialFormattedContent,
  finalized,
  baseFontKey,
  baseTextColor,
  company,
  employee,
  type,
  hash,
}: Props) {
  const router = useRouter();
  const workspace = useCertificateWorkspace();

  const baseCfg = fontConfig(baseFontKey || DEFAULT_FONT_KEY);
  const baseColor = baseTextColor || DEFAULT_TEXT_COLOR;

  const initialDoc: TiptapDoc =
    initialFormattedContent ?? plainTextToTiptap(generatedText);

  const [doc, setDoc] = useState<TiptapDoc>(initialDoc);
  const [status, setStatus] = useState<SaveStatus>("idle");
  const [errorMsg, setErrorMsg] = useState("");
  const [, setTick] = useState(0); // erzwingt Toolbar-Re-Render bei Selektion

  const jsonRef = useRef<TiptapDoc>(initialDoc);
  const lastSavedRef = useRef<string>(JSON.stringify(initialDoc));
  const saveTimer = useRef<NodeJS.Timeout | null>(null);
  const previewTimer = useRef<NodeJS.Timeout | null>(null);

  const saveNow = useCallback(async () => {
    if (finalized) return;
    const json = jsonRef.current;
    const serialized = JSON.stringify(json);
    if (serialized === lastSavedRef.current) return;
    if (saveTimer.current) {
      clearTimeout(saveTimer.current);
      saveTimer.current = null;
    }
    setStatus("saving");
    try {
      const res = await fetch(`/api/certificates/${certificateId}/content`, {
        method: "PUT",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ formatted_content: json }),
      });
      if (!res.ok) {
        const data = await res.json();
        throw new Error(data.error ?? "Speichern fehlgeschlagen");
      }
      lastSavedRef.current = serialized;
      setStatus("saved");
      setTimeout(() => setStatus("idle"), 2000);
    } catch (err: any) {
      setStatus("error");
      setErrorMsg(err.message);
      throw err;
    }
  }, [certificateId, finalized]);

  const editor = useEditor({
    immediatelyRender: false,
    editable: !finalized,
    extensions: [StarterKit, TextStyle, Color, FontFamily],
    content: initialDoc,
    editorProps: {
      attributes: {
        class: "zeugnix-prose",
        spellcheck: "true",
        lang: "de-CH",
      },
    },
    onUpdate: ({ editor }) => {
      const json = editor.getJSON() as TiptapDoc;
      jsonRef.current = json;
      // Vorschau leicht gedrosselt aktualisieren
      if (previewTimer.current) clearTimeout(previewTimer.current);
      previewTimer.current = setTimeout(() => setDoc(json), 120);
      // Speichern debounced
      setStatus("typing");
      if (saveTimer.current) clearTimeout(saveTimer.current);
      saveTimer.current = setTimeout(() => {
        saveNow().catch(() => {});
      }, 800);
    },
    onSelectionUpdate: () => setTick((t) => t + 1),
  });

  // saveNow beim Workspace registrieren (Finalisieren flusht ausstehende Saves).
  useEffect(() => {
    if (!workspace) return;
    workspace.registerFlush(saveNow);
    return () => workspace.registerFlush(null);
  }, [workspace, saveNow]);

  useEffect(() => {
    return () => {
      if (saveTimer.current) clearTimeout(saveTimer.current);
      if (previewTimer.current) clearTimeout(previewTimer.current);
    };
  }, []);

  async function resetToGenerated() {
    if (
      !confirm(
        "Formatierung und Bearbeitung verwerfen und auf den generierten Text zurücksetzen?",
      )
    )
      return;
    setStatus("saving");
    try {
      const res = await fetch(`/api/certificates/${certificateId}/content`, {
        method: "PUT",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ formatted_content: null }),
      });
      if (!res.ok) {
        const data = await res.json();
        throw new Error(data.error ?? "Zurücksetzen fehlgeschlagen");
      }
      const fresh = plainTextToTiptap(generatedText);
      editor?.commands.setContent(fresh);
      jsonRef.current = fresh;
      lastSavedRef.current = JSON.stringify(fresh);
      setDoc(fresh);
      setStatus("saved");
      setTimeout(() => setStatus("idle"), 2000);
      router.refresh();
    } catch (err: any) {
      setStatus("error");
      setErrorMsg(err.message);
    }
  }

  const previewText = tiptapToPlainText(doc);
  const trimmedText = previewText.trim();
  const wordCount = trimmedText ? trimmedText.split(/\s+/).length : 0;
  const charCount = trimmedText.length;
  // Schweizer Praxis: ein sehr knappes Zeugnis wirkt zurückhaltend/negativ.
  // Dezenter Nudge, sobald der Text auffällig kurz ist (grobe Heuristik).
  const tooShort = wordCount > 0 && wordCount < 150;

  return (
    <div className="grid gap-6 lg:grid-cols-5">
      {/* Editor – linke Spalte */}
      <div className="space-y-3 lg:col-span-2">
        <div className="flex items-center justify-between">
          <div className="text-[11px] font-medium uppercase tracking-wider text-ink-500">
            Editor
          </div>
          <div className="text-[12px]">
            {status === "typing" && <span className="text-ink-400">Tippt…</span>}
            {status === "saving" && (
              <span className="text-ink-500">Wird gespeichert…</span>
            )}
            {status === "saved" && (
              <span className="text-petrol-700">✓ Gespeichert</span>
            )}
            {status === "error" && (
              <span className="text-red-700">Fehler: {errorMsg}</span>
            )}
          </div>
        </div>

        {!finalized && <Toolbar editor={editor} baseCfg={baseCfg} baseColor={baseColor} />}

        <div
          className="rounded-md border border-ink-200 bg-white"
          style={{
            fontFamily: baseCfg.css,
            color: baseColor,
          }}
        >
          <EditorContent editor={editor} />
        </div>

        <div className="flex flex-wrap items-center justify-between gap-x-3 gap-y-1 text-[11.5px] text-ink-500">
          <span>
            {wordCount} {wordCount === 1 ? "Wort" : "Wörter"} · {charCount} Zeichen
          </span>
          {tooShort && (
            <span className="text-amber-700">
              Eher kurz – je knapper ein Zeugnis, desto zurückhaltender wirkt es.
            </span>
          )}
        </div>

        {!finalized && (
          <button
            onClick={resetToGenerated}
            className="text-[11.5px] font-medium text-ink-600 underline hover:text-ink-900"
          >
            Auf generierten Text zurücksetzen
          </button>
        )}
        {finalized && (
          <p className="text-[11.5px] text-ink-500">
            Das Zeugnis ist finalisiert. Bearbeitung nicht mehr möglich.
          </p>
        )}
      </div>

      {/* Vorschau – rechte Spalte (A4, formatiert) */}
      <div className="space-y-3 lg:col-span-3">
        <div className="text-[11px] font-medium uppercase tracking-wider text-ink-500">
          Vorschau (so wird das PDF aussehen)
        </div>
        <CertificatePreview
          company={company}
          employee={employee}
          type={type}
          text={previewText}
          hash={hash}
          bodyOverride={<CertificateFormattedBody doc={doc} />}
          sheetFontFamily={baseCfg.css}
          sheetColor={baseColor}
        />
      </div>

      <style>{`
        .zeugnix-prose {
          min-height: 360px;
          padding: 16px 18px;
          font-size: 14px;
          line-height: 1.6;
          outline: none;
        }
        .zeugnix-prose:focus { outline: none; }
        .zeugnix-prose p { margin: 0 0 10px 0; }
        .zeugnix-prose ul { margin: 0 0 10px 0; padding-left: 20px; }
        .zeugnix-prose li { margin: 0 0 3px 0; }
      `}</style>
    </div>
  );
}

// ----------------------------------------------------------------------------
// Toolbar
// ----------------------------------------------------------------------------

function Toolbar({
  editor,
  baseCfg,
  baseColor,
}: {
  editor: Editor | null;
  baseCfg: ReturnType<typeof fontConfig>;
  baseColor: string;
}) {
  if (!editor) return null;

  const currentFont = fontConfig(
    (editor.getAttributes("textStyle").fontFamily as string) || baseCfg.key,
  );
  const currentColor =
    (editor.getAttributes("textStyle").color as string) || baseColor;

  const btn = (active: boolean) =>
    `rounded px-2.5 py-1 text-[13px] font-medium border ${
      active
        ? "border-petrol-500 bg-petrol-50 text-petrol-700"
        : "border-ink-200 bg-white text-ink-700 hover:bg-ink-50"
    }`;

  return (
    <div className="flex flex-wrap items-center gap-2 rounded-md border border-ink-200 bg-ink-50/50 p-2">
      <select
        value={currentFont.key}
        onChange={(e) =>
          editor
            .chain()
            .focus()
            .setFontFamily(fontConfig(e.target.value).css)
            .run()
        }
        className="rounded border border-ink-200 bg-white px-2 py-1 text-[12.5px]"
        title="Schriftart"
      >
        {CERTIFICATE_FONTS.map((f) => (
          <option key={f.key} value={f.key}>
            {f.label}
          </option>
        ))}
      </select>

      <button
        type="button"
        onClick={() => editor.chain().focus().toggleBold().run()}
        className={btn(editor.isActive("bold"))}
        title="Fett"
        style={{ fontWeight: 700 }}
      >
        F
      </button>
      <button
        type="button"
        onClick={() => editor.chain().focus().toggleItalic().run()}
        className={btn(editor.isActive("italic"))}
        title="Kursiv"
        style={{ fontStyle: "italic" }}
      >
        K
      </button>
      <button
        type="button"
        onClick={() => editor.chain().focus().toggleUnderline().run()}
        className={btn(editor.isActive("underline"))}
        title="Unterstrichen"
        style={{ textDecoration: "underline" }}
      >
        U
      </button>

      <label className="flex items-center gap-1.5 text-[12.5px] text-ink-600">
        Farbe
        <input
          type="color"
          value={currentColor}
          onChange={(e) => editor.chain().focus().setColor(e.target.value).run()}
          className="h-7 w-9 cursor-pointer rounded border border-ink-200 bg-white"
          title="Schriftfarbe"
        />
      </label>
      <button
        type="button"
        onClick={() => editor.chain().focus().unsetColor().run()}
        className="text-[11.5px] text-ink-500 underline hover:text-ink-800"
        title="Farbe zurücksetzen"
      >
        Farbe zurücksetzen
      </button>
    </div>
  );
}
