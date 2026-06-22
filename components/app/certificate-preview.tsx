"use client";

import { useEffect, useState } from "react";
import QRCode from "qrcode";
import { buildVerifyUrl } from "@/lib/hash/canonicalize";

interface Company {
  name?: string;
  address?: string | null;
  postal_code?: string | null;
  city?: string | null;
  website?: string | null;
  phone?: string | null;
  email?: string | null;
  logo_url?: string | null;
  signatory_1_name?: string | null;
  signatory_1_role?: string | null;
  signatory_2_name?: string | null;
  signatory_2_role?: string | null;
}

interface Employee {
  first_name: string;
  last_name: string;
  gender: "m" | "f" | "d";
  function_title: string;
  date_of_birth?: string | null;
  entry_date: string;
  exit_date?: string | null;
}

interface Props {
  company: Company;
  employee: Employee;
  type: string;
  text: string;
  hash?: string | null;
}

const TYPE_LABELS: Record<string, string> = {
  schluss: "Arbeitszeugnis",
  zwischen: "Zwischenzeugnis",
  funktionswechsel: "Arbeitszeugnis",
  vorgesetztenwechsel: "Arbeitszeugnis",
  interner_wechsel: "Arbeitszeugnis",
  reorganisation: "Arbeitszeugnis",
  wunsch_mitarbeiterin: "Arbeitszeugnis",
  wunsch_mitarbeiter: "Arbeitszeugnis",
};

function formatDate(iso?: string | null): string {
  if (!iso) return "";
  const [y, m, d] = iso.split("-");
  return `${d}.${m}.${y}`;
}

export function CertificatePreview({
  company,
  employee,
  type,
  text,
  hash,
}: Props) {
  const title = TYPE_LABELS[type] ?? "Arbeitszeugnis";
  const today = new Date().toLocaleDateString("de-CH", {
    day: "2-digit",
    month: "2-digit",
    year: "numeric",
  });

  // QR-Code zum Hash erzeugen – identische Verify-URL und Optionen wie im PDF
  // (lib/pdf/certificate.tsx), damit Vorschau und PDF konsistent sind.
  const [qrDataUrl, setQrDataUrl] = useState<string>("");
  useEffect(() => {
    if (!hash) {
      setQrDataUrl("");
      return;
    }
    const baseUrl =
      process.env.NEXT_PUBLIC_SITE_URL ?? "https://zeugnix.ch";
    const verifyUrl = buildVerifyUrl(baseUrl, hash);
    let cancelled = false;
    QRCode.toDataURL(verifyUrl, {
      margin: 0,
      width: 200,
      color: { dark: "#0f7a6b", light: "#ffffff" },
    })
      .then((url) => {
        if (!cancelled) setQrDataUrl(url);
      })
      .catch(() => {
        if (!cancelled) setQrDataUrl("");
      });
    return () => {
      cancelled = true;
    };
  }, [hash]);

  // Text in Absätze splitten
  const paragraphs = text.split(/\n\n+/).map((p) => p.trim()).filter(Boolean);

  return (
    <div className="flex justify-center overflow-auto rounded-md bg-ink-100 p-4 sm:p-8">
      {/* A4-Blatt auf dezentem Hintergrund – wirkt wie ein aufliegendes Papier */}
      <div
        className="bg-white"
        style={{
          width: "100%",
          maxWidth: "210mm",
          minHeight: "297mm",
          padding: "20mm 22mm",
          boxSizing: "border-box",
          fontFamily: "Arial, Helvetica, sans-serif",
          fontSize: "11pt",
          lineHeight: "1.55",
          color: "#1a1d22",
          boxShadow:
            "0 1px 2px rgba(14, 16, 20, 0.08), 0 8px 24px rgba(14, 16, 20, 0.12)",
        }}
      >
        {/* Letterhead */}
        <table style={{ width: "100%", borderBottom: "1px solid #d4d8dd", paddingBottom: "16px", marginBottom: "32px" }}>
          <tbody>
            <tr>
              <td style={{ verticalAlign: "top", width: "60%" }}>
                {company.logo_url ? (
                  // eslint-disable-next-line @next/next/no-img-element
                  <img
                    src={company.logo_url}
                    alt={company.name}
                    style={{
                      maxHeight: "48px",
                      maxWidth: "180px",
                      objectFit: "contain",
                      display: "block",
                    }}
                  />
                ) : (
                  <div
                    style={{
                      fontSize: "13pt",
                      fontWeight: 600,
                      letterSpacing: "-0.01em",
                    }}
                  >
                    {company.name}
                  </div>
                )}
              </td>
              <td
                style={{
                  verticalAlign: "top",
                  textAlign: "right",
                  fontSize: "8.5pt",
                  color: "#6b7178",
                  lineHeight: "1.45",
                }}
              >
                {company.logo_url && (
                  <div style={{ fontWeight: 600, color: "#1a1d22", marginBottom: "2px" }}>
                    {company.name}
                  </div>
                )}
                {company.address && <div>{company.address}</div>}
                {(company.postal_code || company.city) && (
                  <div>
                    {company.postal_code} {company.city}
                  </div>
                )}
                {company.phone && <div>{company.phone}</div>}
                {company.email && <div>{company.email}</div>}
                {company.website && <div>{company.website}</div>}
              </td>
            </tr>
          </tbody>
        </table>

        {/* Title */}
        <h1
          style={{
            fontSize: "18pt",
            fontWeight: 700,
            textAlign: "center",
            margin: "0 0 32px 0",
            letterSpacing: "0.02em",
          }}
        >
          {title}
        </h1>

        {/* Body */}
        <div style={{ textAlign: "justify" }}>
          {paragraphs.map((p, i) => {
            // Bullet-Liste
            if (p.includes("•")) {
              const lines = p.split("\n");
              return (
                <div key={i} style={{ marginBottom: "14px" }}>
                  {lines.map((line, j) => (
                    <div
                      key={j}
                      style={{
                        marginLeft: line.startsWith("•") ? "16px" : 0,
                        marginBottom: line.startsWith("•") ? "4px" : "8px",
                      }}
                    >
                      {line}
                    </div>
                  ))}
                </div>
              );
            }
            // Datum / Ort am Ende
            if (i === paragraphs.length - 1 && /^[A-ZÄÖÜ][a-zäöü]+,\s*\d{2}\.\d{2}\.\d{4}/.test(p)) {
              return (
                <p
                  key={i}
                  style={{
                    marginTop: "32px",
                    marginBottom: "8px",
                    textAlign: "left",
                  }}
                >
                  {p}
                </p>
              );
            }
            return (
              <p key={i} style={{ margin: "0 0 14px 0" }}>
                {p}
              </p>
            );
          })}
        </div>

        {/* Unterschriftsblock */}
        {(company.signatory_1_name || company.signatory_2_name) && (
          <div style={{ marginTop: "48px" }}>
            <table style={{ width: "100%" }}>
              <tbody>
                <tr>
                  {company.signatory_1_name && (
                    <td style={{ verticalAlign: "top", width: "50%", paddingRight: "20px" }}>
                      <div
                        style={{
                          borderTop: "1px solid #1a1d22",
                          paddingTop: "6px",
                          fontSize: "10pt",
                        }}
                      >
                        <div style={{ fontWeight: 500 }}>{company.signatory_1_name}</div>
                        {company.signatory_1_role && (
                          <div style={{ color: "#6b7178" }}>{company.signatory_1_role}</div>
                        )}
                      </div>
                    </td>
                  )}
                  {company.signatory_2_name && (
                    <td style={{ verticalAlign: "top", width: "50%", paddingLeft: "20px" }}>
                      <div
                        style={{
                          borderTop: "1px solid #1a1d22",
                          paddingTop: "6px",
                          fontSize: "10pt",
                        }}
                      >
                        <div style={{ fontWeight: 500 }}>{company.signatory_2_name}</div>
                        {company.signatory_2_role && (
                          <div style={{ color: "#6b7178" }}>{company.signatory_2_role}</div>
                        )}
                      </div>
                    </td>
                  )}
                </tr>
              </tbody>
            </table>
          </div>
        )}

        {/* Hash-Block (nur bei finalisierten Zeugnissen) – zweispaltig:
            Hash-Text links, QR-Code rechts (konsistent zum PDF) */}
        {hash && (
          <div
            style={{
              marginTop: "48px",
              paddingTop: "14px",
              borderTop: "0.5px solid #d4d8dd",
              display: "flex",
              flexDirection: "row",
              alignItems: "flex-start",
              gap: "16px",
              fontSize: "8pt",
              color: "#6b7178",
              lineHeight: "1.5",
            }}
          >
            <div style={{ flex: 1 }}>
              <div
                style={{
                  fontSize: "7.5pt",
                  fontWeight: 600,
                  color: "#0f7a6b",
                  textTransform: "uppercase",
                  letterSpacing: "0.06em",
                  marginBottom: "4px",
                }}
              >
                Echtheitsnachweis (SHA-256)
              </div>
              <div
                style={{
                  fontFamily: "Menlo, Consolas, monospace",
                  fontSize: "7.5pt",
                  color: "#1a1d22",
                  wordBreak: "break-all",
                  marginBottom: "6px",
                }}
              >
                {hash}
              </div>
              <div>
                Dieses Arbeitszeugnis wurde mit zeugnix.ch erstellt und mit
                einem kryptografischen Echtheitsnachweis versehen. Jede
                nachträgliche Veränderung führt zu einem abweichenden Hash.
                Echtheit prüfen: zeugnix.ch/verify
              </div>
            </div>
            {qrDataUrl && (
              // eslint-disable-next-line @next/next/no-img-element
              <img
                src={qrDataUrl}
                alt="QR-Code zur Echtheitsprüfung"
                style={{
                  width: "72px",
                  height: "72px",
                  flexShrink: 0,
                  display: "block",
                }}
              />
            )}
          </div>
        )}
      </div>
    </div>
  );
}
