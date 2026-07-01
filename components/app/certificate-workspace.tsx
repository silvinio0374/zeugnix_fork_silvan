"use client";

import { createContext, useContext, useRef } from "react";

type FlushFn = () => Promise<void>;

interface WorkspaceContext {
  /** Editor registriert hier seine "jetzt speichern"-Funktion (oder null beim Unmount). */
  registerFlush: (fn: FlushFn | null) => void;
  /** Sichert ausstehende Editor-Änderungen. Wirft, wenn das Speichern fehlschlägt. */
  flush: () => Promise<void>;
}

const Ctx = createContext<WorkspaceContext | null>(null);

/**
 * Klammert Editor und Aktionen einer Zeugnis-Detailseite zusammen, damit die
 * Aktionen (z.B. Finalisieren) den noch ausstehenden Auto-Save des Editors
 * flushen können, bevor sie loslaufen. Verhindert Datenverlust durch den
 * 800ms-Debounce im Editor.
 */
export function CertificateWorkspace({
  children,
}: {
  children: React.ReactNode;
}) {
  const flushRef = useRef<FlushFn | null>(null);
  const value = useRef<WorkspaceContext>({
    registerFlush: (fn) => {
      flushRef.current = fn;
    },
    flush: async () => {
      if (flushRef.current) await flushRef.current();
    },
  }).current;

  return <Ctx.Provider value={value}>{children}</Ctx.Provider>;
}

export function useCertificateWorkspace() {
  return useContext(Ctx);
}
