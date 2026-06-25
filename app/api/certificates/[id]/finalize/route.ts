import { NextRequest, NextResponse } from "next/server";
import { createClient } from "@/lib/db/supabase-server";
import { canonicalizeForHash, sha256 } from "@/lib/hash/canonicalize";

export async function POST(
  _req: NextRequest,
  { params }: { params: Promise<{ id: string }> },
) {
  const { id } = await params;
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });

  const { data: cert } = await supabase
    .from("certificates")
    .select("*, employees(*), companies(*)")
    .eq("id", id)
    .single();

  if (!cert)
    return NextResponse.json({ error: "Zeugnis nicht gefunden" }, { status: 404 });

  if (!cert.generated_text) {
    return NextResponse.json(
      { error: "Zeugnistext muss zuerst generiert werden." },
      { status: 400 },
    );
  }

  if (cert.status === "final") {
    return NextResponse.json(
      { error: "Zeugnis ist bereits finalisiert." },
      { status: 400 },
    );
  }

  // Hash über den TATSÄCHLICH gedruckten Body bilden – exakt dieselbe Quelle
  // wie das PDF (app/api/certificates/[id]/pdf/route.ts) und dieselbe
  // Pipeline wie die Verifikation (canonicalizeForHash). Datum/Ort sind als
  // letzter Absatz Teil des Body, daher kein separates (flüchtiges) Datum.
  const bodyText = cert.edited_text || cert.generated_text || "";
  const canonicalString = canonicalizeForHash(bodyText);
  const hash = await sha256(canonicalString);

  await supabase
    .from("certificates")
    .update({
      hash,
      canonical_content: canonicalString,
      status: "final",
      finalized_at: new Date().toISOString(),
    })
    .eq("id", id);

  // Optional: Employer-Badge aktivieren, wenn das die erste Finalisierung ist
  await supabase
    .from("companies")
    .update({ has_employer_badge: true })
    .eq("id", cert.company_id);

  // Idempotent insert in employer_badges
  await supabase
    .from("employer_badges")
    .upsert(
      { company_id: cert.company_id, badge_type: "verified_certificate_employer", active: true },
      { onConflict: "company_id,badge_type", ignoreDuplicates: true },
    );

  return NextResponse.json({ ok: true, hash });
}
