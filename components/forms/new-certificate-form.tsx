"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/db/supabase-client";
import { schlusssatzPreview } from "@/lib/phrases/schlusssaetze";

interface Props {
  companies: { id: string; name: string }[];
}

export function NewCertificateForm({ companies }: Props) {
  const router = useRouter();
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState("");

  // Sauber getrenntes Datenmodell (Christoph-Matrix):
  //   Zeugnistyp × Austrittsgrund + stapelbare Opt-ins.
  const [zeugnisTyp, setZeugnisTyp] = useState<
    "schluss" | "zwischen" | "arbeitsbestaetigung"
  >("schluss");
  const [austrittsgrund, setAustrittsgrund] = useState<
    "wunsch_an" | "wunsch_ag" | "einvernehmen"
  >("wunsch_an");
  const [optinBedauern, setOptinBedauern] = useState(false);
  const [optinReorg, setOptinReorg] = useState(false);
  const [optinVorgesetztenwechsel, setOptinVorgesetztenwechsel] = useState(false);
  const [optinInternerWechsel, setOptinInternerWechsel] = useState(false);
  const [wertschaetzung, setWertschaetzung] = useState<
    "standard" | "wertschaetzender" | "top"
  >("standard");

  const showWechselFields = optinVorgesetztenwechsel || optinInternerWechsel;

  // Live-Vorschau des Schlusssatzes (neutrale Form) für die aktuelle Auswahl.
  const schlusssatzVorschau =
    zeugnisTyp === "arbeitsbestaetigung"
      ? null
      : schlusssatzPreview({
          zeugnisTyp,
          austrittsgrund,
          wertschaetzung,
          optinBedauern,
          optinReorg,
        });

  // Abgeleiteter Legacy-`type`: hält Engine/Vorschau/PDF unverändert lauffähig,
  // bis diese in späteren Phasen auf die neuen Felder umgestellt sind.
  const legacyType =
    zeugnisTyp === "arbeitsbestaetigung"
      ? "arbeitsbestaetigung"
      : zeugnisTyp === "zwischen"
        ? optinVorgesetztenwechsel
          ? "vorgesetztenwechsel"
          : optinInternerWechsel
            ? "interner_wechsel"
            : "zwischen"
        : optinReorg
          ? "reorganisation"
          : "schluss";

  async function onSubmit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    setSubmitting(true);
    setError("");

    const fd = new FormData(e.currentTarget);
    const supabase = createClient();

    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (!user) {
      setError("Nicht angemeldet");
      setSubmitting(false);
      return;
    }

    // 1. Employee anlegen
    const { data: employee, error: empErr } = await supabase
      .from("employees")
      .insert({
        company_id: fd.get("company_id"),
        first_name: fd.get("first_name") as string,
        last_name: fd.get("last_name") as string,
        gender: fd.get("gender") as string,
        date_of_birth: (fd.get("date_of_birth") as string) || null,
        function_title: fd.get("function_title") as string,
        entry_date: fd.get("entry_date"),
        exit_date: (fd.get("exit_date") as string) || null,
        employment_percentage: parseInt(fd.get("employment_percentage") as string) || 100,
        is_manager: fd.get("is_manager") === "on",
      })
      .select()
      .single();

    if (empErr || !employee) {
      setError(empErr?.message ?? "Fehler beim Anlegen der Mitarbeiterin");
      setSubmitting(false);
      return;
    }

    // 2. Certificate anlegen
    const tasks = (fd.get("tasks") as string)
      .split("\n")
      .map((t) => t.trim())
      .filter(Boolean);

    const { data: cert, error: certErr } = await supabase
      .from("certificates")
      .insert({
        company_id: fd.get("company_id"),
        employee_id: employee.id,
        type: legacyType,
        zeugnis_typ: zeugnisTyp,
        austrittsgrund: zeugnisTyp === "schluss" ? austrittsgrund : null,
        optin_bedauern: zeugnisTyp === "schluss" ? optinBedauern : false,
        optin_reorg: optinReorg,
        optin_vorgesetztenwechsel:
          zeugnisTyp === "zwischen" ? optinVorgesetztenwechsel : false,
        optin_interner_wechsel:
          zeugnisTyp === "zwischen" ? optinInternerWechsel : false,
        wertschaetzungsgrad:
          zeugnisTyp === "arbeitsbestaetigung" ? "standard" : wertschaetzung,
        tasks,
        status: "draft",
        // Dank ist im Schlusssatz-Katalog bereits enthalten.
        thank_employee: zeugnisTyp === "schluss",
        new_function_title: (fd.get("new_function_title") as string) || null,
        new_company_name: (fd.get("new_company_name") as string) || null,
        transition_date: (fd.get("transition_date") as string) || null,
        created_by_user_id: user.id,
      })
      .select()
      .single();

    if (certErr || !cert) {
      setError(certErr?.message ?? "Fehler beim Anlegen des Zeugnisses");
      setSubmitting(false);
      return;
    }

    router.push(`/app/certificates/${cert.id}`);
  }

  return (
    <form onSubmit={onSubmit} className="space-y-8">
      {/* Firma */}
      <Section title="Firma">
        <Field label="Firma">
          <select name="company_id" required className="input">
            {companies.map((c) => (
              <option key={c.id} value={c.id}>
                {c.name}
              </option>
            ))}
          </select>
        </Field>
      </Section>

      {/* Mitarbeitende */}
      <Section title="Mitarbeitende">
        <div className="grid gap-4 sm:grid-cols-2">
          <Field label="Vorname">
            <input name="first_name" required className="input" />
          </Field>
          <Field label="Nachname">
            <input name="last_name" required className="input" />
          </Field>
        </div>
        <div className="grid gap-4 sm:grid-cols-2">
          <Field label="Anrede / Geschlecht">
            <select name="gender" required className="input">
              <option value="f">Frau</option>
              <option value="m">Herr</option>
              <option value="d">Neutral</option>
            </select>
          </Field>
          <Field label="Geburtsdatum">
            <input name="date_of_birth" type="date" className="input" />
          </Field>
        </div>
        <Field label="Funktion">
          <input name="function_title" required className="input" />
        </Field>
        <div className="grid gap-4 sm:grid-cols-3">
          <Field label="Eintrittsdatum">
            <input name="entry_date" type="date" required className="input" />
          </Field>
          <Field label="Austrittsdatum (optional bei Zwischenzeugnis)">
            <input name="exit_date" type="date" className="input" />
          </Field>
          <Field label="Beschäftigungsgrad %">
            <input
              name="employment_percentage"
              type="number"
              min="1"
              max="100"
              defaultValue="100"
              className="input"
            />
          </Field>
        </div>
        <label className="flex items-center gap-2 text-[13px]">
          <input type="checkbox" name="is_manager" />
          <span>Person hat Führungsfunktion</span>
        </label>
      </Section>

      {/* Zeugnis */}
      <Section title="Zeugnis">
        <Field label="Zeugnistyp">
          <select
            required
            className="input"
            value={zeugnisTyp}
            onChange={(e) =>
              setZeugnisTyp(
                e.target.value as
                  | "schluss"
                  | "zwischen"
                  | "arbeitsbestaetigung",
              )
            }
          >
            <option value="schluss">Schlusszeugnis</option>
            <option value="zwischen">Zwischenzeugnis</option>
            <option value="arbeitsbestaetigung">Arbeitsbestätigung</option>
          </select>
        </Field>

        {zeugnisTyp === "arbeitsbestaetigung" && (
          <p className="text-[12px] leading-relaxed text-ink-500">
            Bestätigt nur Funktion und Dauer der Anstellung – ohne qualitative
            Beurteilung. Aufgaben sind optional; den Text können Sie nach der
            Generierung frei ergänzen.
          </p>
        )}

        {zeugnisTyp === "schluss" && (
          <>
            <Field label="Austrittsgrund">
              <select
                className="input"
                value={austrittsgrund}
                onChange={(e) =>
                  setAustrittsgrund(
                    e.target.value as "wunsch_an" | "wunsch_ag" | "einvernehmen",
                  )
                }
              >
                <option value="wunsch_an">Wunsch der/des Mitarbeitenden</option>
                <option value="wunsch_ag">Wunsch des Arbeitgebers</option>
                <option value="einvernehmen">Gegenseitiges Einvernehmen</option>
              </select>
            </Field>
            <div className="space-y-2">
              <span className="block text-[12px] font-medium text-ink-700">
                Optionale Zusätze im Schlusssatz
              </span>
              <label className="flex items-center gap-2 text-[13px]">
                <input
                  type="checkbox"
                  checked={optinBedauern}
                  onChange={(e) => setOptinBedauern(e.target.checked)}
                />
                <span>Bedauern über das Ausscheiden</span>
              </label>
              <label className="flex items-center gap-2 text-[13px]">
                <input
                  type="checkbox"
                  checked={optinReorg}
                  onChange={(e) => setOptinReorg(e.target.checked)}
                />
                <span>Reorganisation</span>
              </label>
            </div>
          </>
        )}

        {zeugnisTyp === "zwischen" && (
          <div className="space-y-2">
            <span className="block text-[12px] font-medium text-ink-700">
              Optionale Zusätze / Anlass
            </span>
            <label className="flex items-center gap-2 text-[13px]">
              <input
                type="checkbox"
                checked={optinReorg}
                onChange={(e) => setOptinReorg(e.target.checked)}
              />
              <span>Reorganisation</span>
            </label>
            <label className="flex items-center gap-2 text-[13px]">
              <input
                type="checkbox"
                checked={optinVorgesetztenwechsel}
                onChange={(e) => setOptinVorgesetztenwechsel(e.target.checked)}
              />
              <span>Vorgesetztenwechsel</span>
            </label>
            <label className="flex items-center gap-2 text-[13px]">
              <input
                type="checkbox"
                checked={optinInternerWechsel}
                onChange={(e) => setOptinInternerWechsel(e.target.checked)}
              />
              <span>Interner Wechsel</span>
            </label>
          </div>
        )}

        {zeugnisTyp !== "arbeitsbestaetigung" && (
          <>
            <Field label="Wertschätzungsgrad (Schlusssatz)">
              <select
                className="input"
                value={wertschaetzung}
                onChange={(e) =>
                  setWertschaetzung(
                    e.target.value as "standard" | "wertschaetzender" | "top",
                  )
                }
              >
                <option value="standard">Standard</option>
                <option value="wertschaetzender">Etwas wertschätzender</option>
                <option value="top">Top-Mitarbeitende</option>
              </select>
            </Field>
            {schlusssatzVorschau && (
              <div className="rounded-md border border-ink-200 bg-ink-50/50 p-3">
                <div className="text-[11px] font-medium uppercase tracking-wider text-ink-500">
                  Schlusssatz-Vorschau
                </div>
                <p className="mt-1.5 text-[13px] leading-relaxed text-ink-700">
                  {schlusssatzVorschau}
                </p>
                <p className="mt-2 text-[11px] leading-relaxed text-ink-400">
                  Neutrale Form – Name und Anrede werden beim Generieren
                  eingesetzt. Standardisierte Formulierung, für alle Zeugnisse
                  einheitlich wiederverwendbar.
                </p>
              </div>
            )}
          </>
        )}

        {showWechselFields && (
          <div className="grid gap-4 sm:grid-cols-3">
            <Field label="Neue Funktion (optional)">
              <input name="new_function_title" className="input" />
            </Field>
            <Field label="Neue Firma (optional)">
              <input name="new_company_name" className="input" />
            </Field>
            <Field label="Wechseldatum (optional)">
              <input name="transition_date" type="date" className="input" />
            </Field>
          </div>
        )}

        <Field label="Hauptaufgaben (eine pro Zeile)">
          <textarea
            name="tasks"
            rows={5}
            placeholder="Beratung von Geschäftskunden&#10;Vorbereitung der Quartalsabschlüsse&#10;Schulung neuer Mitarbeitender"
            className="input"
          />
        </Field>

      </Section>

      {error && (
        <div className="rounded-md border border-red-200 bg-red-50 px-4 py-3 text-[13px] text-red-700">
          {error}
        </div>
      )}

      <div className="flex justify-end gap-3 border-t border-ink-200 pt-6">
        <button
          type="submit"
          disabled={submitting}
          className="btn-primary disabled:opacity-50"
        >
          {submitting ? "Wird gespeichert…" : "Weiter zu Beurteilung"}
        </button>
      </div>

      <style>{`
        .input {
          width: 100%;
          padding: 10px 12px;
          font-size: 14px;
          border: 1px solid rgb(228, 230, 234);
          border-radius: 6px;
          background: white;
          outline: none;
          transition: border-color 0.15s;
        }
        .input:focus {
          border-color: rgb(15, 122, 107);
          box-shadow: 0 0 0 3px rgba(15, 122, 107, 0.1);
        }
      `}</style>
    </form>
  );
}

function Section({
  title,
  children,
}: {
  title: string;
  children: React.ReactNode;
}) {
  return (
    <div className="card p-6">
      <h2 className="mb-4 text-[14px] font-medium tracking-tight">{title}</h2>
      <div className="space-y-4">{children}</div>
    </div>
  );
}

function Field({
  label,
  children,
}: {
  label: string;
  children: React.ReactNode;
}) {
  return (
    <label className="block">
      <span className="mb-1 block text-[12px] font-medium text-ink-700">
        {label}
      </span>
      {children}
    </label>
  );
}
