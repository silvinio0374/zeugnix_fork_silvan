# zeugnix — Designsystem und Schriften

**Adressat:** Christoph Senn, Head HR, First Corporate Services AG
**Autor:** Silvan Schück
**Stand:** 10. Juli 2026
**Anlass:** Antwort auf das Mail vom 7. Juli 2026 und die Brand Summary

---

## Vorbemerkung

Der Einwand trifft zu. Als das Mail geschrieben wurde, hatte zeugnix **kein Designsystem**: keine Token-Ebene, keine Theme-Ebene, keine Grenzen. Die Anfrage „Schrift und Farbe konfigurierbar machen" war exakt die isolierte Einzelanpassung, vor der es warnt.

Dieses Dokument trennt sauber zwischen **der Ausgangslage** und **dem, was seither umgesetzt ist**. Der lizenzfreie Teil des Umbaus ist bereits erledigt; er stand nicht unter Vorbehalt einer Schriftentscheidung. Was noch aussteht, ist die Marke.

Zum Verständnis der Brand Summary: Sie zeigt fünf Marken mit je eigenem Schriftpaar und eigener Farbe. Damit ist die eigentliche Anforderung nicht „ein Style-Picker", sondern **Mandanten-Branding** — zeugnix muss Zeugnisse unter mehreren Marken ausstellen können. Das ist ein anderer und grösserer Auftrag, und dieses Dokument geht davon aus.

### Die fünf Marken

Angaben aus der von euch gelieferten Brand Summary. Die Schriftnamen sind übernommen; die **Farbwerte haben wir bewusst nicht aus dem PDF abgeleitet** — aus einem Bild lassen sie sich nur schätzen, und ein geschätzter Markenwert ist wertlos.

| Marke | Headlines | Paragraphs | Farbe |
|---|---|---|---|
| First Advisory | Minion | Rotis Sans | Hex ausstehend |
| CSL | Chambers Sans | Inter | Hex ausstehend |
| IAB | Minion | Akkurat | Hex ausstehend |
| Comply2gether | Coco Sharp | Coco Sharp | Hex ausstehend |
| Prokuration | Campton | Campton | Hex ausstehend |

---

## Ausgangslage: wie die Styles verwaltet *waren*

Die direkte Antwort auf die vier gestellten Fragen, bezogen auf den Stand vor dem Umbau:

| Frage | Antwort |
|---|---|
| Gab es Design Tokens? | **Nein.** Kein Style Dictionary, kein Token-Export, keine Zwischenschicht. |
| Gab es CSS-Variablen? | **Praktisch nein.** Genau zwei (`--background`, `--foreground`), beide statisch. |
| Konnten User Templates verwalten oder wechseln? | **Nein.** Genau ein hart codiertes Layout. |
| War es hart codiert? | **Ja.** Farben und Schriftgrössen als Literale im Code. |

Technisch: Next.js 15 mit Tailwind CSS. Die Farben der Anwendung sind drei hart codierte Hex-Skalen (`ink`, `petrol`, `navy`) in `tailwind.config.ts`. Kein shadcn/ui, kein `class-variance-authority`, kein Dark Mode.

Der eigentliche Befund lag tiefer: Die Typografie des Zeugnisses war an **drei Stellen dupliziert** — im PDF-Generator, in der Live-Vorschau und im Absatz-Renderer. Diese drei Stellen waren bereits leicht auseinandergelaufen: unterschiedliche Seitenränder (56/60 pt gegen 20/22 mm), unterschiedliche Zeilenhöhen (1,6 gegen 1,55), unterschiedliche Signaturfarben, und der Vorschau fehlte der Unterschriftskopf ganz.

Konfigurierbar war pro Firma: Logo, Unterzeichner, Stammdaten — dazu ein **freier Farbwähler ohne jede Kontrastprüfung** und eine von drei Schriften. Zusätzlich konnte im Editor **jede einzelne Textstelle** eine beliebige Schrift und beliebige Farbe erhalten. Genau die „vollständige Freiheit in der Gestaltung", die laut Mail selten sinnvoll ist.

---

## Es gibt zwei getrennte Style-Welten

Das ist für die Schriftfrage entscheidend, weil nur eine der beiden gebrandet werden soll.

**Welt A — die Anwendung.** Login, Formulare, Editor-Oberfläche. Inter Tight und Fraunces, geladen über einen Google-Fonts-Link. Akzent Petrol `#0F7A6B`. Das ist die Marke zeugnix. **Nicht Gegenstand des Brandings.**

**Welt B — das erzeugte Zeugnis.** Zwei Darstellungen desselben Dokuments:

- Das **A4-PDF** wird serverseitig erzeugt (`@react-pdf/renderer`).
- Die **Live-Vorschau** ist eine clientseitige HTML-Wiedergabe aus denselben Tokens.

Diese Unterscheidung ist gleich in der Lizenzfrage wichtig, denn PDF und Browser sind lizenzrechtlich zwei verschiedene Fälle.

Verfügbar sind heute in Welt B nur die drei in PDF eingebauten Basisschriften: Helvetica, Times, Courier. Sie werden **ohne Einbettung der Glyphen** nur namentlich referenziert; es fallen keine Font-Lizenzkosten an. (Die Namen bleiben Monotype-Marken, und eine PDF/A-Archivierung würde Einbettung verlangen — für uns heute nicht relevant.)

---

## Was seither umgesetzt ist

Eine **Token-Ebene für das Dokument** ist die einzige Quelle der Wahrheit. Die drei duplizierten Stellen lesen daraus. Das PDF ist dabei die verbindliche Wahrheit — es ist das rechtlich relevante Artefakt —, und die Vorschau folgt seinen Werten.

Die Tokens zerfallen bewusst in zwei Klassen. Das ist die geforderte Grenzziehung:

**Unveränderlich, nie durch Marke oder Nutzer überschreibbar**

| Token-Gruppe | Rollen |
|---|---|
| `fontSize` | `title` 18 · `companyName` 14 · `body` 11 · `signature` 10 · `signatureRole` 9 · `letterhead` 8,5 · `signaturesHeader` 8 · `hash` 7,5 · `hashLabel` 7 |
| `lineHeight` | `page` 1,55 · `body` 1,6 · `letterhead` 1,45 |
| `letterSpacing` | `title` · `label` |
| `space` | Seitenränder, Abstände Briefkopf/Titel/Absatz/Signatur/Hash |
| `page` | A4, 210 × 297 mm |

**Überschreibbar pro Marke (das gesamte Theme, mehr nicht)**

| Token | Bedeutung |
|---|---|
| `fonts.heading` | Titel, Briefkopf, Unterschriftsnamen, Labels |
| `fonts.body` | Fliesstext |
| `fonts.mono` | Prüfhash |
| `colors.brandAccent` | Labels, Linien, QR-Code |
| `colors.textPrimary` | Fliesstextfarbe |
| `colors.textSecondary`, `.textMuted`, `.rule` | abgeleitete Grautöne |

Der Punkt aus dem Mail — „es macht einen Unterschied, ob das ein Titel, eine Zwischenüberschrift oder eine Fusszeile ist" — ist damit im Typsystem abgebildet: **Rollen statt Werte**. Und weil die Grössen nicht Teil des Theme-Typs sind, *kann* eine Marke die Schriftgrösse gar nicht verstellen. Die Grenze ist vom Compiler erzwungen, nicht von einer Konvention.

Weiter umgesetzt:

- **Drei kuratierte Stile** stehen zur Wahl (Helvetica, Times, Courier als Fliesstextschrift) — kein freier Font-Upload.
- **Der freie Farbwähler ist entfernt.** Farben kommen aus dem Theme und laufen durch einen automatischen **WCAG-AA-Kontrasttest**, der beim Bauen der Anwendung fehlschlägt, wenn ein Theme unter 4,5:1 gegen Papierweiss fällt.
- **Im Editor bleiben Fett und Unterstrichen.** Schrift und Farbe pro Textstelle sind weg.
- **Kursiv ist entfernt** — dazu gleich mehr.

Was Nutzer weiterhin **nicht** können: eigene Vorlagen anlegen. Das Layout ist eines und fest. Umschaltbar ist der Stil, nicht die Struktur.

Eine Marke wie First Advisory ist danach **reine Daten** — ein Eintrag, kein Code-Umbau:

```ts
"first-advisory": {
  label: "First Advisory",
  fonts: { heading: "minion", body: "rotis-sans", mono: "courier" },
  colors: { ...BASE, brandAccent: "#______" },
}
```

Genau deshalb haben wir diese Ebene **jetzt** gebaut, bevor eine Schrift gekauft wird. Dass das erzeugte PDF sich dabei nicht verändert hat, ist nachgewiesen: alter und neuer Stand wurden gerendert und die Position jedes einzelnen Textelements verglichen.

---

## Wie viele Schriftschnitte wirklich nötig sind

Die Vermutung, dass kein volles Family Pack nötig ist, trifft zu. Die Zahl lässt sich exakt herleiten.

**Technische Randbedingung:** Der PDF-Renderer muss jeden Schnitt einzeln registrieren und in jedes erzeugte PDF einbetten. Es gibt kein synthetisches Fetten oder Kursivieren. Jeder Schnitt, den der Editor erlaubt, ist eine eigene Lizenzposition. Unterstrichen braucht keinen eigenen Schnitt, und der Prüfhash bleibt auf der lizenzfreien Courier.

### Der Kursiv-Punkt — mit der gebotenen Genauigkeit

Euer eigenes **Merkblatt zur Zeugniserstellung (2017)** listet unter „Was gehört nicht ins Zeugnis?" wörtlich:

> „Persönliche Anmerkungen oder Andeutungen durch Ausrufe oder Fragezeichen, **kursive Schrift**, Anführungszeichen, etc."

Wichtig ist die genaue Lesart: Das Merkblatt verbietet nicht den Schriftschnitt, sondern **Andeutungen, die sich seiner bedienen**. Ein zwingendes Rechtsverbot der Kursivschrift folgt daraus nicht.

Unsere Konsequenz ist trotzdem eindeutig: Wir haben Kursiv **aus dem Editor entfernt**. Damit kann es gar nicht erst als Andeutung eingesetzt werden — das Werkzeug macht den Fehler unmöglich, statt ihn nur zu verbieten. Dass dabei zwei Schriftschnitte pro Marke entfallen, ist ein willkommener Nebeneffekt, nicht der Grund.

**Fettdruck steht nicht auf eurer Liste**, deshalb ist er geblieben. Falls ihr ihn aus derselben Erwägung ebenfalls ausschliessen wollt, wäre das eine bewusste Entscheidung mit weiterer Kostenwirkung — siehe offene Fragen.

### Die Matrix

Jede Familie braucht Regular; Bold zusätzlich dort, wo fett gesetzt wird.

| | vorher (mit Kursiv) | jetzt (ohne Kursiv) |
|---|---|---|
| Paragraph-Familie | Regular, Italic, Bold, Bold Italic | **Regular, Bold** |
| Headline-Familie | Regular, Bold | Regular, Bold |
| **Schnitte pro Marke** | **6** | **4** |
| Comply2gether / Prokuration (eine Familie für beide Rollen) | 4 | **2** |

Der Kursiv-Verzicht spart also **genau zwei Schnitte pro Marke** — die beiden Kursivschnitte der Fliesstextfamilie. Bei den Marken mit nur einer Familie ist das eine Halbierung, bei den übrigen ein Drittel.

Anmerkung zur Headline-Familie: Sie trägt nicht nur den Titel, sondern auch Briefkopf, Unterschriftsnamen und Labels. Bold wird dort gebraucht. Die Zahl fällt erst dann auf **zwei Schnitte pro Marke**, wenn eine Marke durchgehend **eine** Familie für alle Rollen des Dokuments benutzt — nicht schon, wenn nur der Titel die Fliesstextschrift übernimmt.

**Antwort auf die Ausgangsfrage: zwei bis vier Schnitte pro Marke. Kein Family Pack.**

---

## Zur Lizenzfrage — was der MyFonts-Link nicht abdeckt

Hier liegt der Punkt, der die Wirtschaftlichkeitsrechnung verschiebt. Alle Zitate sind wörtlich aus der [MyFonts-FAQ](https://www.myfonts.com/pages/faq/) und der zugehörigen [Desktop-EULA](https://www.myfonts.com/pages/license-agreement?id=eula_2275).

### Serverseitig erzeugte PDFs sind kein Desktop-Kauf

zeugnix rendert das Zeugnis auf dem Server und bettet die Schrift in jedes PDF ein. Die FAQ beschreibt genau diesen Fall unter der **Server-Lizenz**:

> „A server license is required for sites, web apps, or services that allow a non-licensed user to utilize the font to create a product (for example, personalized t-shirts, **PDF receipts**, business cards, and pictures with captions, et cetera)."

Ein serverseitig erzeugtes Zeugnis-PDF folgt demselben Muster wie eine „PDF receipt".

Die **Desktop-Lizenz** genügt dafür nicht. Die FAQ ist unmissverständlich: „distribution and embedding of the font is not allowed." Die ausführliche EULA ist etwas differenzierter — sie erlaubt „create and distribute non-commercial non-editable .pdf documents containing embedded Font Software" — aber die Einschränkung auf **nicht-kommerzielle** Dokumente und das Verbot der Serverinstallation schliessen unseren Fall in beiden Fassungen aus.

### Ein SaaS-Vorbehalt, den wir klären müssen

Dieselbe FAQ enthält einen Satz, der für zeugnix unmittelbar relevant ist:

> „A font downloaded with this license cannot be used in SaaS, where the service is the product rather that the item that is created."

Die Auslegung ist nicht trivial. Bei zeugnix ist der Dienst das Produkt — *und* das erzeugte Zeugnis ist der geschaffene Gegenstand. Was hier gilt, **müssen wir vor einem Kauf mit der jeweiligen Foundry schriftlich klären.** Ich kennzeichne das ausdrücklich als offenen Punkt und argumentiere es nicht weg.

### Die Vorschau ist ein zweiter, bedingter Lizenzfall

Die Live-Vorschau nutzt heute reine System-Schriftstacks. Solange das so bleibt, entsteht **kein Webfont-Fall**. Sobald die lizenzierte Markenschrift auch im Browser erscheinen soll — damit die Vorschau dem PDF wirklich entspricht —, wird die Schriftdatei an den Browser ausgeliefert, und es braucht zusätzlich eine **Webfont-Lizenz**.

Das ist eine echte Produktentscheidung, keine technische Zwangsläufigkeit:

- **Mit Webfont-Lizenz:** Vorschau und PDF sehen identisch aus. Zusätzliche, mengenabhängige Kosten.
- **Ohne:** Die Vorschau zeigt eine Systemschrift, das PDF die Markenschrift. Die Geometrie stimmt, das Schriftbild nicht.

Zur Abrechnung, wörtlich: „Most foundries on MyFonts offer their webfonts with an Annual license model based on pageviews … You get a total number of pageviews that can be used per month." Also ein Jahresmodell mit **monatlichem Kontingent**, das nachgekauft werden muss. Einzelne Foundries bieten stattdessen einen Einmalkauf. **Pro Schrift zu prüfen.**

### Konsequenz für das Budget

Es sind potenziell **zwei Lizenzarten parallel** — Server für das PDF, Webfont für die Vorschau. Die Server-Lizenz ist bei den meisten Foundries jährlich zu erneuern, die Webfont-Lizenz mengenabhängig. Das sind **wiederkehrende Kosten**, kein reiner Einmalkauf. Diese Struktur sollte vor der Schriftauswahl bekannt sein, nicht danach.

### Bezugsquellen

Korrigiert gegenüber meiner ersten Recherche. Die meisten Schriften sind bei MyFonts erhältlich — die Lücke ist kleiner als gedacht, die Lizenzfrage dafür grösser:

| Schrift | Foundry / Gestalter | Bezug |
|---|---|---|
| Inter | Rasmus Andersson, SIL Open Font License | **kostenlos**, kein MyFonts-Produkt |
| Minion | Adobe Originals, Robert Slimbach | Adobe Fonts **und** MyFonts |
| Rotis Sans | Monotype | MyFonts |
| FF Chambers Sans | Verena Gerlach, FontFont (Monotype) | MyFonts |
| Coco Sharp | Zetafonts, Cosimo Lorenzo Pancini | MyFonts |
| Campton | René Bieder | MyFonts |
| Akkurat | Lineto | **nur Direktvertrieb**, nicht über MyFonts |

**Empfehlung zur Reihenfolge: mit CSL beginnen.** Deren Fliesstextschrift ist Inter — unter der SIL Open Font License, also kostenlos und ohne Server- oder Webfont-Problematik. Damit lässt sich die gesamte Marken-Pipeline (Theme, Einbettung, PDF, Vorschau) **zu null Lizenzkosten** end-to-end beweisen, bevor irgendetwas gekauft wird.

Eine Klarstellung dazu, weil sie leicht misszuverstehen ist: Inter ist heute **nicht** im Zeugnis-Renderer eingebunden. Die Anwendungsoberfläche nutzt die verwandte Familie *Inter Tight*. Für CSL müsste Inter einmalig als Schriftdatei eingebettet werden — ohne Lizenzkosten, aber mit einem Einbauschritt.

---

## Barrierefreiheit

Im Mail zu Recht genannt. Die heutige Akzentfarbe Petrol `#0F7A6B` erreicht auf Papierweiss **5,23:1**. Sie besteht damit **WCAG AA** für Fliesstext (Schwelle 4,5:1); die strengere Stufe AAA (7:1) erreicht sie nicht.

Für die Markenfarben können wir das noch nicht prüfen — dafür brauchen wir die exakten Hex-Werte. Sobald sie vorliegen, läuft jede Markenfarbe durch den Kontrasttest, der beim Bauen fehlschlägt, wenn ein Theme unter 4,5:1 fällt. Der Test schützt damit den Theme-Autor, nicht den Endnutzer — was der Punkt an einem Designsystem mit Grenzen ist.

Anzumerken ist: Kräftige Rot- und Blautöne können hier je nach Sättigung knapp werden. Das ist lösbar, indem die Markenfarbe für **Flächen und Linien** genutzt wird und der Fliesstext auf dem dunklen Neutralton bleibt.

---

## Testzugang und direkte Abstimmung

Beides gern.

**Testzugang:** Wir richten einen Account auf der Preview-Umgebung ein. Nicht auf der Produktivumgebung — dort liegen echte Mandantendaten.

**Direkter Draht:** Eine Vermittlung ist nicht nötig. Ich entwickle an zeugnix mit und stimme mich direkt ab. (Die Codebasis stammt ursprünglich von Patrick Hitz; die hier beschriebenen Änderungen sind von mir.)

Vorschlag für 45 Minuten: den Token-Satz gemeinsam durchgehen und die Rollen festlegen; die Schriftschnitt-Matrix bestätigen; Bezugsquelle, Lizenzform und den SaaS-Vorbehalt pro Schrift klären; die Reihenfolge der fünf Marken festlegen.

---

## Offene Fragen

1. **Exakte Hex-Werte** der fünf Markenfarben. Ohne sie kein Kontrasttest und kein Theme.
2. **SaaS-Vorbehalt.** Wer klärt mit den Foundries, ob eine Server-Lizenz den zeugnix-Anwendungsfall deckt? Das ist die einzige Frage, die ein echtes Projektrisiko trägt.
3. **Fettdruck.** Euer Merkblatt nennt ihn nicht. Soll er im Zeugnis bleiben? Ein Verzicht spart pro Marke einen weiteren Schnitt.
4. **Bezugseinheit des Brandings** — pro Marke oder pro ausstellender Gesellschaft? Beide sind abbildbar; es entscheidet über das Datenmodell.
5. **Vorschau-Treue.** Soll die Live-Vorschau die Markenschrift zeigen (Webfont-Lizenz nötig) oder genügt eine Systemschrift?
6. **Titelschrift.** Braucht der Zeugnistitel die Headline-Familie, oder genügt die Paragraph-Familie? Eine durchgehende Familie senkt den Bedarf auf zwei Schnitte.
7. **Lizenzhalter.** Beschafft First Advisory die Lizenzen, oder zeugnix? Bei mengenabhängigen Lizenzen ist das eine laufende Verpflichtung mit einer Schwelle, die jemand überwachen muss.
8. **Reihenfolge der Marken** — Vorschlag CSL zuerst, weil Inter lizenzkostenfrei ist.

---

## Zu den Quellen

Die Aussagen dieses Briefs sind gegen die jeweilige Primärquelle geprüft: die MyFonts-FAQ und die Desktop-EULA für die Lizenztypen, die Foundry-Seiten für die Zuordnung der Schriften, euer Merkblatt zur Zeugniserstellung (2017) für die Kursiv-Frage, und der Quellcode für alle Aussagen über zeugnix. Der Kontrastwert ist nach WCAG 2.1 berechnet.

Wo eine Aussage vom Auslegungsspielraum abhängt — der SaaS-Vorbehalt, das Webfont-Abrechnungsmodell —, ist sie als solche gekennzeichnet und nicht als Tatsache formuliert.
