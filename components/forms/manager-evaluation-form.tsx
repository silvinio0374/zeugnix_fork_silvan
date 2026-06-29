"use client";

import { useMemo, useState } from "react";
import { SKILLS, type SkillMeta } from "@/lib/phrases/skills";

const RATINGS = [
  { value: "sehr_gut", label: "Sehr gut" },
  { value: "gut", label: "Gut" },
  { value: "genuegend", label: "Genügend" },
  { value: "ungenuegend", label: "Ungenügend" },
];

interface ThemeGroup {
  theme: string;
  themeLabel: string;
  skills: SkillMeta[];
}

/**
 * Skills nach Thema gruppieren. Eine Führungskraft erhält den Führungs-Block
 * UND die allgemeinen Themen (wie zuvor: Basis + Führung), eine Mitarbeitende
 * ohne Führungsfunktion nur die allgemeinen Themen. Reihenfolge folgt aus
 * 'order' im Katalog.
 */
function buildThemes(isManager: boolean): ThemeGroup[] {
  const relevant = SKILLS.filter(
    (s) => isManager || s.employeeType === "mitarbeiter",
  )
    .slice()
    .sort((a, b) => a.order - b.order);

  const groups: ThemeGroup[] = [];
  for (const s of relevant) {
    let g = groups.find((x) => x.theme === s.theme);
    if (!g) {
      g = { theme: s.theme, themeLabel: s.themeLabel, skills: [] };
      groups.push(g);
    }
    g.skills.push(s);
  }
  return groups;
}

interface Props {
  certificateId: string;
  isManager: boolean;
  // Genau eines von beiden muss gesetzt sein:
  token?: string; // Manager-Einladung über E-Mail-Link
  selfMode?: boolean; // Eingeloggter HR/Inhaber beurteilt selbst
}

export function ManagerEvaluationForm({
  token,
  certificateId,
  isManager,
  selfMode,
}: Props) {
  const themes = useMemo(() => buildThemes(isManager), [isManager]);

  // Kern-Skills (im Katalog mit '*') sind vorausgewählt; weitere zuschaltbar.
  const [selected, setSelected] = useState<Record<string, boolean>>(() => {
    const init: Record<string, boolean> = {};
    for (const g of themes) for (const s of g.skills) if (s.core) init[s.key] = true;
    return init;
  });
  const [ratings, setRatings] = useState<Record<string, string>>({});
  const [freeTexts, setFreeTexts] = useState<Record<string, string>>({});
  const [submitting, setSubmitting] = useState(false);
  const [done, setDone] = useState(false);
  const [error, setError] = useState("");

  function toggleSkill(key: string) {
    setSelected((prev) => ({ ...prev, [key]: !prev[key] }));
  }

  const selectedKeys = useMemo(
    () => Object.keys(selected).filter((k) => selected[k]),
    [selected],
  );
  const ratedSelectedCount = selectedKeys.filter((k) => ratings[k]).length;
  const progress =
    selectedKeys.length === 0
      ? 0
      : Math.round((ratedSelectedCount / selectedKeys.length) * 100);

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError("");

    if (selectedKeys.length === 0) {
      setError("Bitte mindestens eine Eigenschaft zur Beurteilung auswählen.");
      return;
    }
    const missing = selectedKeys.filter((k) => !ratings[k]);
    if (missing.length > 0) {
      setError(`Bitte alle ausgewählten Eigenschaften bewerten (${missing.length} offen).`);
      return;
    }

    setSubmitting(true);

    // Reihenfolge entlang der Themen beibehalten (für stabile Ausgabe).
    const evaluations = themes.flatMap((g) =>
      g.skills
        .filter((s) => selected[s.key])
        .map((s) => ({
          category: s.key,
          subcategory: s.theme,
          rating: ratings[s.key],
          free_text: freeTexts[s.key] ?? null,
        })),
    );

    let res: Response;
    if (selfMode) {
      // Eingeloggter User beurteilt direkt
      res = await fetch(`/api/certificates/${certificateId}/evaluate-self`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ evaluations }),
      });
    } else {
      // Manager über Token-Link
      res = await fetch("/api/evaluations/submit", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ token, evaluations }),
      });
    }

    if (!res.ok) {
      const data = await res.json().catch(() => ({}));
      setError(data.error ?? "Fehler beim Absenden");
      setSubmitting(false);
      return;
    }

    setDone(true);
  }

  if (done) {
    return (
      <div className="card p-10 text-center">
        <div className="mx-auto flex h-12 w-12 items-center justify-center rounded-full bg-petrol-100">
          <svg
            width="24"
            height="24"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            strokeWidth="2"
            strokeLinecap="round"
            strokeLinejoin="round"
            className="text-petrol-700"
          >
            <polyline points="20 6 9 17 4 12" />
          </svg>
        </div>
        <h2 className="mt-4 text-[16px] font-medium">Beurteilung gespeichert</h2>
        <p className="mt-2 text-[13.5px] text-ink-600">
          {selfMode
            ? "Sie können jetzt den Zeugnistext generieren."
            : "Vielen Dank. Der Arbeitgeber kann nun den Zeugnistext generieren. Sie können dieses Fenster schliessen."}
        </p>
        {selfMode && (
          <a
            href={`/app/certificates/${certificateId}`}
            className="btn-primary mt-6 inline-flex"
          >
            Zurück zum Zeugnis
          </a>
        )}
      </div>
    );
  }

  return (
    <form onSubmit={onSubmit} className="space-y-8">
      {/* Fortschritt */}
      <div className="card p-4">
        <div className="flex items-center justify-between text-[12px]">
          <span className="font-medium">
            Fortschritt · {selectedKeys.length} Eigenschaft
            {selectedKeys.length === 1 ? "" : "en"} ausgewählt
          </span>
          <span className="text-ink-500">{progress}%</span>
        </div>
        <div className="mt-2 h-1.5 overflow-hidden rounded-full bg-ink-100">
          <div
            className="h-full rounded-full bg-petrol-600 transition-all"
            style={{ width: `${progress}%` }}
          />
        </div>
        <p className="mt-2 text-[11.5px] leading-relaxed text-ink-500">
          Empfohlene Eigenschaften sind vorausgewählt. Schalten Sie pro Thema
          weitere zu oder ab – nur ausgewählte Eigenschaften erscheinen im Zeugnis.
        </p>
      </div>

      {themes.map((g) => {
        const selectedInTheme = g.skills.filter((s) => selected[s.key]);
        const ratedInTheme = selectedInTheme.filter((s) => ratings[s.key]);
        return (
          <section key={g.theme} className="space-y-3">
            <div className="flex items-baseline justify-between">
              <h2 className="text-[15px] font-semibold tracking-tight">
                {g.themeLabel}
              </h2>
              <span className="text-[12px] text-ink-500">
                {ratedInTheme.length}/{selectedInTheme.length} bewertet
              </span>
            </div>

            <div className="space-y-3">
              {g.skills.map((s) => {
                const on = !!selected[s.key];
                return (
                  <div
                    key={s.key}
                    className={`card p-4 transition-colors ${
                      on ? "" : "bg-ink-50/40"
                    }`}
                  >
                    <label className="flex cursor-pointer items-center gap-3">
                      <input
                        type="checkbox"
                        checked={on}
                        onChange={() => toggleSkill(s.key)}
                        className="h-4 w-4 accent-petrol-600"
                      />
                      <span
                        className={`text-[14px] font-medium ${
                          on ? "text-ink-900" : "text-ink-500"
                        }`}
                      >
                        {s.label}
                      </span>
                      {s.core && (
                        <span className="rounded-full bg-petrol-50 px-2 py-0.5 text-[10.5px] font-medium text-petrol-700">
                          empfohlen
                        </span>
                      )}
                    </label>
                    {s.help && on && (
                      <p className="mt-1 pl-7 text-[12px] text-ink-500">{s.help}</p>
                    )}

                    {on && (
                      <div className="mt-3 pl-7">
                        <div className="grid grid-cols-2 gap-2 sm:grid-cols-4">
                          {RATINGS.map((r) => (
                            <button
                              key={r.value}
                              type="button"
                              onClick={() =>
                                setRatings((prev) => ({ ...prev, [s.key]: r.value }))
                              }
                              className={`rounded-md border px-3 py-2 text-[12.5px] font-medium transition-colors ${
                                ratings[s.key] === r.value
                                  ? "border-petrol-600 bg-petrol-50 text-petrol-800"
                                  : "border-ink-200 bg-white text-ink-700 hover:border-ink-300"
                              }`}
                            >
                              {r.label}
                            </button>
                          ))}
                        </div>

                        <details className="mt-3">
                          <summary className="cursor-pointer text-[12px] text-petrol-700 hover:underline">
                            Optionale Anmerkung
                          </summary>
                          <textarea
                            value={freeTexts[s.key] ?? ""}
                            onChange={(e) =>
                              setFreeTexts((prev) => ({
                                ...prev,
                                [s.key]: e.target.value,
                              }))
                            }
                            rows={2}
                            placeholder="z.B. besonders erwähnenswerte Projekte oder Leistungen"
                            className="mt-2 w-full rounded-md border border-ink-200 px-3 py-2 text-[13px]"
                          />
                        </details>
                      </div>
                    )}
                  </div>
                );
              })}
            </div>
          </section>
        );
      })}

      {error && (
        <div className="rounded-md border border-red-200 bg-red-50 px-3 py-2 text-[13px] text-red-700">
          {error}
        </div>
      )}

      <div className="sticky bottom-0 -mx-6 border-t border-ink-200 bg-white px-6 py-4">
        <button
          type="submit"
          disabled={submitting || selectedKeys.length === 0 || progress < 100}
          className="btn-primary w-full disabled:opacity-50"
        >
          {submitting ? "Wird gesendet…" : "Beurteilung absenden"}
        </button>
      </div>
    </form>
  );
}
