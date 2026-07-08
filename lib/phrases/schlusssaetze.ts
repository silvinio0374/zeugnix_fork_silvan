/**
 * zeugnix.ch – Schlusssatz-Katalog (Christoph-Matrix)
 * ----------------------------------------------------------------------------
 * Eine Quelle der Wahrheit für den Schlusssatz, genutzt von:
 *   - der Engine (lib/phrases/engine.ts) bei der Generierung
 *   - dem Formular (components/forms/new-certificate-form.tsx) für die
 *     Live-Vorschau
 *
 * Der Schlusssatz ist EIN zusammengesetzter Block (Dank + Zukunftswünsche sind
 * eingebaut). Er wird gewählt entlang:
 *   Zeugnistyp  (schluss | zwischen)
 *   Austrittsgrund (wunsch_an | wunsch_ag | einvernehmen)   – nur bei Schluss
 *   Wertschätzungsgrad (standard | wertschaetzender | top)
 *   Opt-ins: Bedauern (nur Schluss, ersetzt den Satz), Reorganisation
 *
 * Gender-Tokens {{maskulin|feminin|neutral}} werden von der Engine bzw. der
 * Vorschau aufgelöst (m → 1., f → 2., d → 3. Wert).
 *
 * Leere Zellen (z.B. „Top-Mitarbeitende", wertschätzender-Zwischen, Einvernehmen)
 * sind bewusst noch nicht befüllt – die Auswahl fällt sauber auf die Standard-
 * Variante zurück. Diese Zellen werden später per Build-Time-KI ergänzt und von
 * Christoph geprüft.
 */

export type Wertschaetzung = "standard" | "wertschaetzender" | "top";
export type Grund = "wunsch_an" | "wunsch_ag" | "einvernehmen";

export interface SchlusssatzParams {
  zeugnisTyp: "schluss" | "zwischen" | "arbeitsbestaetigung";
  austrittsgrund?: Grund | null;
  wertschaetzung?: Wertschaetzung | null;
  optinBedauern?: boolean;
  optinReorg?: boolean;
}

// ---------------------------------------------------------------------------
// Katalog – von Christoph gelieferte Formulierungen (Rest = Lücke → Fallback)
// ---------------------------------------------------------------------------

const SCHLUSS: Record<Grund, Partial<Record<Wertschaetzung, string>>> = {
  wunsch_an: {
    standard:
      "Wir danken {{ihm|ihr|ihm/ihr}} für die geleistete Arbeit und wünschen {{ihm|ihr|ihm/ihr}} für die Zukunft alles Gute und weiterhin viel Erfolg.",
    wertschaetzender:
      "Wir danken {{ihm|ihr|ihm/ihr}} für die stets sehr gute Zusammenarbeit und die wertvollen Leistungen. Für die Zukunft wünschen wir {{ihm|ihr|ihm/ihr}} alles Gute und weiterhin viel Erfolg.",
    // top: Lücke (KI-Ergänzung)
  },
  wunsch_ag: {
    // Lücke – fällt auf wunsch_an zurück (Reorg-AG siehe SCHLUSS_REORG_AG)
  },
  einvernehmen: {
    // Lücke – fällt auf wunsch_an zurück
  },
};

// Opt-in „Bedauern" ersetzt den Satz (immer als Ergänzung, auch bei anderen
// Opt-ins → hat Vorrang). Wertschätzender Grundton.
const SCHLUSS_BEDAUERN =
  "Wir bedauern {{sein|ihr|sein/ihr}} Ausscheiden und danken {{ihm|ihr|ihm/ihr}} für die stets sehr gute Zusammenarbeit und die wertvollen Leistungen und wünschen {{ihm|ihr|ihm/ihr}} für die Zukunft alles Gute und weiterhin viel Erfolg.";

// Opt-in „Reorganisation" – arbeitnehmer- vs. arbeitgeberinitiiert.
const SCHLUSS_REORG_DEFAULT =
  "Im Zusammenhang mit einer Reorganisation danken wir {{ihm|ihr|ihm/ihr}} für die stets sehr gute Zusammenarbeit und die wertvollen Leistungen und wünschen {{ihm|ihr|ihm/ihr}} für die Zukunft alles Gute und weiterhin viel Erfolg.";
const SCHLUSS_REORG_AG =
  "Dieses Arbeitsverhältnis wurde im Rahmen einer Reorganisation beendet. Wir danken {{ihm|ihr|ihm/ihr}} für die geleistete Arbeit und wünschen {{ihm|ihr|ihm/ihr}} für die Zukunft alles Gute und weiterhin viel Erfolg.";

const ZWISCHEN: Partial<Record<Wertschaetzung, string>> = {
  standard:
    "Dieses Zwischenzeugnis wird auf Wunsch {{des Mitarbeiters|der Mitarbeiterin|des/der Mitarbeitenden}} ausgestellt. Wir danken {vorname} {nachname} für die bisherige wertvolle Mitarbeit und wünschen {{ihm|ihr|ihm/ihr}} alles Gute und weiterhin viel Erfolg.",
  // wertschaetzender / top: Lücke (KI-Ergänzung)
};

// ---------------------------------------------------------------------------
// Auswahl
// ---------------------------------------------------------------------------

/**
 * Liefert die Schlusssatz-Vorlage (mit {{m|f|d}}-Tokens und {vorname}/{nachname})
 * für die gegebene Kombination – oder null, wenn kein Satz zutrifft (Aufrufer
 * nutzt dann einen eigenen Fallback). Für schluss/zwischen wird über sinnvolle
 * Fallbacks stets ein Satz geliefert.
 */
export function pickSchlusssatz(p: SchlusssatzParams): string | null {
  const grad: Wertschaetzung = p.wertschaetzung ?? "standard";

  if (p.zeugnisTyp === "schluss") {
    if (p.optinBedauern) return SCHLUSS_BEDAUERN;
    if (p.optinReorg)
      return p.austrittsgrund === "wunsch_ag"
        ? SCHLUSS_REORG_AG
        : SCHLUSS_REORG_DEFAULT;

    const grund: Grund = p.austrittsgrund ?? "wunsch_an";
    const byGrund = SCHLUSS[grund] ?? {};
    return (
      byGrund[grad] ??
      byGrund.standard ??
      SCHLUSS.wunsch_an[grad] ??
      SCHLUSS.wunsch_an.standard ??
      null
    );
  }

  if (p.zeugnisTyp === "zwischen") {
    return ZWISCHEN[grad] ?? ZWISCHEN.standard ?? null;
  }

  // arbeitsbestaetigung: eigener Satz direkt in der Engine
  return null;
}

/**
 * Neutrale Auflösung der Gender-Tokens (3. Wert, z.B. „ihm/ihr") für die
 * Formular-Vorschau; Namensplatzhalter werden lesbar ersetzt.
 */
export function schlusssatzPreview(p: SchlusssatzParams): string | null {
  const tmpl = pickSchlusssatz(p);
  if (!tmpl) return null;
  return tmpl
    .replace(/\{\{([^{}]*)\}\}/g, (_m, inner: string) => {
      const parts = inner.split("|");
      return (parts[2] ?? parts[0] ?? "").trim();
    })
    .replace(/\{vorname\}\s*\{nachname\}/g, "[Name]")
    .replace(/\{vorname\}/g, "[Vorname]")
    .replace(/\{nachname\}/g, "[Nachname]");
}
