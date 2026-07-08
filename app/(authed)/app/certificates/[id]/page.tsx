import { createClient } from "@/lib/db/supabase-server";
import { notFound } from "next/navigation";
import { CertificateActions } from "@/components/app/certificate-actions";
import { CertificateRichWorkspace } from "@/components/app/certificate-rich-workspace";
import { CertificateWorkspace } from "@/components/app/certificate-workspace";
import { CertificateManage } from "@/components/app/certificate-manage";
import Link from "next/link";

interface PageProps {
  params: Promise<{ id: string }>;
}

export default async function CertificateDetailPage({ params }: PageProps) {
  const { id } = await params;
  const supabase = await createClient();

  const { data: cert } = await supabase
    .from("certificates")
    .select(
      `
      *,
      employees (*),
      companies (*),
      manager_invitations (*),
      evaluations (*)
    `,
    )
    .eq("id", id)
    .single();

  if (!cert) notFound();

  const employee = cert.employees;
  const company = cert.companies;

  // Pflicht-Joins: ohne Mitarbeitende oder Firma ist das Zeugnis nicht
  // darstellbar (Datensatz inkonsistent) – freundliche Fehlerseite statt Crash.
  if (!employee || !company) {
    return (
      <div className="card border-amber-200 bg-amber-50/40 p-6">
        <h1 className="text-[16px] font-medium text-amber-900">
          Zeugnis unvollständig
        </h1>
        <p className="mt-2 text-[13.5px] text-amber-800">
          Zu diesem Zeugnis fehlen verknüpfte Stammdaten
          {!employee ? " (Mitarbeitende)" : ""}
          {!employee && !company ? " und" : ""}
          {!company ? " (Firma)" : ""}. Bitte prüfen Sie die Mitarbeitenden- und
          Firmendaten oder legen Sie das Zeugnis neu an.
        </p>
        <Link
          href="/app/certificates"
          className="mt-4 inline-block text-[13px] font-medium text-petrol-700 underline"
        >
          Zurück zur Übersicht
        </Link>
      </div>
    );
  }

  const evaluations = cert.evaluations ?? [];
  const invitations = cert.manager_invitations ?? [];

  const isFinal = cert.status === "final";
  const hasText = !!cert.generated_text;
  const isArchived = !!cert.archived_at;

  return (
    <div className="space-y-6">
      {isArchived && (
        <div className="rounded-md border border-amber-200 bg-amber-50/60 px-4 py-2.5 text-[12.5px] text-amber-800">
          Dieses Zeugnis ist archiviert und erscheint nicht in der
          Standardübersicht.
        </div>
      )}
      <div className="flex items-start justify-between gap-4">
        <div>
          <div className="text-[11px] font-medium uppercase tracking-wider text-petrol-600">
            {typeLabel(cert.type)}
          </div>
          <h1 className="headline-display mt-1 text-[28px] leading-tight">
            {employee.first_name} {employee.last_name}
          </h1>
          <p className="mt-1 text-[13.5px] text-ink-600">
            {employee.function_title} · {company.name}
          </p>
        </div>
        {isFinal && cert.hash && (
          <a
            href={`/api/certificates/${cert.id}/pdf`}
            target="_blank"
            rel="noopener"
            className="btn-primary flex shrink-0 items-center gap-2"
          >
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
              <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4" />
              <polyline points="7 10 12 15 17 10" />
              <line x1="12" y1="15" x2="12" y2="3" />
            </svg>
            PDF herunterladen
          </a>
        )}
      </div>

      {/* Status-Fortschritt */}
      <div className="card p-5">
        <div className="text-[11px] font-medium uppercase tracking-wider text-ink-500">
          Status
        </div>
        <div className="mt-3 flex items-center gap-2">
          <StepBadge label="Erstellt" active />
          <Connector />
          <StepBadge
            label="Beurteilung"
            active={evaluations.length > 0 || cert.status !== "draft"}
            current={cert.status === "pending_manager"}
          />
          <Connector />
          <StepBadge
            label="Generiert"
            active={!!cert.generated_text}
            current={cert.status === "manager_submitted" && !cert.hash}
          />
          <Connector />
          <StepBadge label="Final" active={isFinal} />
        </div>
      </div>

      {/* Aktionen + Editor teilen sich einen Workspace, damit Finalisieren den
          ausstehenden Auto-Save des Editors flushen kann. */}
      <CertificateWorkspace>
      {/* Aktionen */}
      <CertificateActions
        certificate={cert}
        evaluationCount={evaluations.length}
        invitationCount={invitations.length}
      />

      {/* Editor + Preview Split-View */}
      {hasText && (
        <div className="mt-6">
          <h2 className="mb-3 text-[15px] font-medium tracking-tight">
            Zeugnistext bearbeiten und Vorschau
          </h2>
          <CertificateRichWorkspace
            certificateId={cert.id}
            generatedText={cert.generated_text ?? ""}
            initialFormattedContent={cert.formatted_content ?? null}
            finalized={isFinal}
            baseFontKey={company.default_certificate_font_family}
            baseTextColor={company.default_certificate_text_color}
            company={company}
            employee={employee}
            type={cert.type}
            hash={cert.hash}
          />

          {/* Hinweise */}
          {(!company.logo_url ||
            !company.signatory_1_name ||
            !employee.date_of_birth) && (
            <div className="mt-6 rounded-md border border-amber-200 bg-amber-50/50 p-4">
              <div className="text-[12px] font-medium text-amber-900">
                Empfehlungen für ein professionelleres Zeugnis:
              </div>
              <ul className="mt-2 space-y-1 text-[12px] text-amber-800">
                {!company.logo_url && (
                  <li>
                    •{" "}
                    <Link
                      href="/app/company"
                      className="underline hover:text-amber-900"
                    >
                      Firmenlogo hochladen
                    </Link>
                  </li>
                )}
                {!company.signatory_1_name && (
                  <li>
                    •{" "}
                    <Link
                      href="/app/company"
                      className="underline hover:text-amber-900"
                    >
                      Unterzeichnende Personen erfassen
                    </Link>
                  </li>
                )}
                {!employee.date_of_birth && (
                  <li>
                    • Geburtsdatum der Mitarbeiterin / des Mitarbeiters fehlt
                  </li>
                )}
              </ul>
            </div>
          )}
        </div>
      )}
      </CertificateWorkspace>

      {/* Verwaltung: Archivieren / Löschen */}
      <CertificateManage
        certificateId={cert.id}
        status={cert.status}
        archived={isArchived}
      />
    </div>
  );
}

function typeLabel(t: string) {
  const map: Record<string, string> = {
    schluss: "Schlusszeugnis",
    zwischen: "Zwischenzeugnis",
    funktionswechsel: "Funktionswechsel",
    vorgesetztenwechsel: "Vorgesetztenwechsel",
    interner_wechsel: "Interner Wechsel",
    reorganisation: "Reorganisation",
    wunsch_mitarbeiterin: "Wunsch der Mitarbeiterin",
    wunsch_mitarbeiter: "Wunsch des Mitarbeiters",
    arbeitsbestaetigung: "Arbeitsbestätigung",
  };
  return map[t] ?? t;
}

function StepBadge({
  label,
  active,
  current,
}: {
  label: string;
  active?: boolean;
  current?: boolean;
}) {
  return (
    <div
      className={`rounded-full px-3 py-1 text-[11px] font-medium ${
        current
          ? "bg-petrol-700 text-white"
          : active
            ? "bg-petrol-50 text-petrol-700"
            : "bg-ink-100 text-ink-500"
      }`}
    >
      {label}
    </div>
  );
}

function Connector() {
  return <div className="h-px flex-1 bg-ink-200" />;
}
