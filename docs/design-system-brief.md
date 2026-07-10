# zeugnix — Designsystem und Schriften

**Adressat:** Christoph Senn, Head HR, First Corporate Services AG
**Autor:** Silvan Schück
**Stand:** 10. Juli 2026
**Anlass:** Antwort auf das Mail vom 7. Juli 2026 und die `Brand Summary`

---

## Vorbemerkung

Der Einwand trifft zu, und zwar in jedem Punkt. zeugnix hat heute **kein Designsystem**. Es gibt keine Design Tokens, keine Theme-Ebene, kein Template-System. Die Anfrage „Schrift und Farbe konfigurierbar machen" war genau die isolierte Einzelanpassung, vor der das Mail warnt. Dieses Dokument beschreibt den Ist-Zustand ungeschönt, schlägt den Token-Satz vor und beantwortet die Frage nach den Schriftschnitten — inklusive zweier Punkte zu Lizenzkosten, die im Mail noch nicht enthalten sind.

Ein Hinweis vorweg zum Verständnis der `Brand Summary`: Sie zeigt fünf Marken mit je eigenem Schriftpaar und eigener Farbe. Damit ist die eigentliche Anforderung nicht „ein Style-Picker", sondern **Mandanten-Branding** — zeugnix muss Zeugnisse unter mehreren Marken ausstellen können. Das ist ein anderer und grösserer Auftrag, und das Dokument geht davon aus.

| Marke | Headlines | Paragraphs | Farbe |
|---|---|---|---|
| First Advisory | Minion | Rotis Sans | Olivgrün |
| CSL | Chambers Sans | Inter | Rot |
| IAB | Minion | Akkurat | Stahlblau |
| Comply2gether | CocoSharp | CocoSharp | Rot |
| Prokuration | Campton | Campton | Blau |

---

## 1. Wie die Styles heute technisch verwaltet werden

Die direkte Antwort auf die gestellten Fragen:

| Frage | Antwort |
|---|---|
| Gibt es Design Tokens? | **Nein.** Kein Style Dictionary, kein Token-Export, keine Zwischenschicht. |
| Gibt es CSS-Variablen? | **Praktisch nein.** Genau zwei (`--background`, `--foreground`), beide statisch. Keine Theme-Variablen. |
| Können User Templates verwalten oder wechseln? | **Nein.** Es existiert genau ein hart codiertes Layout. |
| Ist es hart codiert? | **Ja.** Farben und Schriftgrössen stehen als Literale im Code. |

Technisch: Next.js 15 mit Tailwind CSS. Die Farben sind drei hart codierte Hex-Skalen (`ink`, `petrol`, `navy`) in `tailwind.config.ts`. Es gibt kein shadcn/ui, kein `class-variance-authority`, keinen Dark Mode.

**Der eigentliche Befund** liegt tiefer: Die Typografie des Zeugnisses selbst ist an **drei Stellen dupliziert** —

- `lib/pdf/certificate.tsx` (das PDF)
- `components/app/certificate-preview.tsx` (die Live-Vorschau)
- `lib/pdf/tiptap-to-pdf.tsx` (die Absätze im PDF)

Eine Änderung an der Schriftgrösse müsste heute an drei Orten konsistent nachgezogen werden. Die drei Stellen sind bereits leicht auseinandergelaufen (siehe Abschnitt 4).

---

## 2. Es gibt zwei getrennte Style-Welten

Das ist für die Schriftfrage entscheidend, weil nur eine der beiden Welten überhaupt gebrandet werden soll.

**Welt A — die zeugnix-Anwendung** (Login, Formulare, Editor-Oberfläche). Schriften Inter Tight und Fraunces, geladen über einen Google-Fonts-Link. Akzentfarbe Petrol `#0F7A6B`. Das ist die Marke zeugnix, sie bleibt unverändert und ist **nicht Gegenstand des Brandings**.

**Welt B — das erzeugte Zeugnis** (A4-PDF und dessen Live-Vorschau). Erzeugt serverseitig mit `@react-pdf/renderer`. Verfügbar sind hier bislang **nur die drei in PDF eingebauten Basisschriften**: Helvetica, Times, Courier. Diese brauchen keine Einbettung und keine Lizenz.

Nur **Welt B** trägt die Marke des Mandanten. Wenn ein Zeugnis unter „First Advisory" erscheinen soll, betrifft das ausschliesslich das Dokument.

---

## 3. Was heute pro Firma konfigurierbar ist

Sehr wenig, und ohne Grenzen:

- **Logo** (Upload, erscheint im Briefkopf)
- **Textfarbe** — ein freier Farbwähler. Volle Freiheit, keine Kontrastprüfung.
- **Schriftart** — eine von drei (Helvetica, Times, Courier)

Zusätzlich kann im Editor **jede einzelne Textstelle** eine beliebige Schrift und beliebige Farbe erhalten. Genau die „vollständige Freiheit in der Gestaltung", die laut Mail selten sinnvoll ist. Dem stimmen wir zu und schlagen vor, sie zurückzunehmen.

Alles andere ist fest: Titelgrösse 18 pt, Fliesstext 11 pt, Zeilenhöhe, Seitenränder, Akzentfarbe, Grautöne.

---

## 4. Vorschlag: eine Token-Ebene für das Dokument

Wir führen `lib/design/document-tokens.ts` als **einzige Quelle der Wahrheit** für das Zeugnis ein. Die drei duplizierten Stellen lesen künftig daraus.

Die Tokens zerfallen bewusst in zwei Klassen — das ist die im Mail geforderte **Grenzziehung**:

**Unveränderlich (nie durch Marke oder Nutzer überschreibbar):**

| Token-Gruppe | Werte |
|---|---|
| `fontSize` | title 18 · companyName 14 · body 11 · caption 10 · small 9 · letterhead 8.5 · micro 8 · fine 7.5 |
| `lineHeight` | page 1.55 · body 1.6 · letterhead 1.45 |
| `letterSpacing` | title 0.5 · label 0.6 |
| `space` | Seitenränder, Abstände Briefkopf/Titel/Absatz/Signatur/Hash |
| `page` | A4, 210 × 297 mm |

**Überschreibbar pro Marke (`DocumentTheme`):**

| Token | Bedeutung |
|---|---|
| `fonts.heading` | Schrift für Titel und Briefkopf |
| `fonts.body` | Schrift für den Fliesstext |
| `fonts.mono` | Schrift für den Prüfhash |
| `colors.brandAccent` | Markenfarbe (Labels, Linien, QR-Code) |
| `colors.textPrimary` | Fliesstextfarbe |
| `colors.textSecondary`, `.textMuted`, `.rule` | abgeleitete Grautöne |

Der Punkt aus dem Mail — „es macht einen Unterschied, ob das ein Titel, eine Zwischenüberschrift oder eine Fusszeile ist" — ist damit im Typsystem abgebildet: Rollen statt Werte. Und weil die Grössen **nicht** Teil des Theme-Typs sind, kann eine Marke die Schriftgrösse gar nicht verstellen. Die Grenze ist vom Compiler erzwungen, nicht von einer Konvention.

Eine Marke ist danach **reine Daten**:

```ts
"first-advisory": {
  id: "first-advisory",
  label: "First Advisory",
  fonts: { heading: "minion", body: "rotis-sans", mono: "courier" },
  colors: { ...BASE_COLORS, brandAccent: "#XXXXXX" },
}
```

Kein Code-Umbau mehr, nur ein Eintrag. Genau deshalb bauen wir diese Ebene **jetzt**, bevor eine Schrift gekauft wird.

**Zum Ist-Zustand ehrlich:** PDF und Vorschau sind bereits auseinandergelaufen (Seitenränder 56/60 pt gegen 20/22 mm, Zeilenhöhe 1.6 gegen 1.55, unterschiedliche Signaturfarben, und der Vorschau fehlt der Block „Digital ausgestellt durch"). Der Refactor macht das PDF zur verbindlichen Wahrheit — es ist das rechtlich relevante Artefakt — und zieht die Vorschau darauf nach.

---

## 5. Wie viele Schriftschnitte wirklich nötig sind

Die Vermutung im Mail, dass kein volles Family Pack nötig ist, trifft zu. Wir können die Zahl sogar exakt herleiten.

**Technische Randbedingung:** `@react-pdf/renderer` muss **jeden Schnitt einzeln registrieren und in jedes erzeugte PDF einbetten**. Es gibt kein synthetisches Fetten oder Kursivieren. Jeder Schnitt, den der Editor erlaubt, ist also eine eigene Lizenzposition.

Heute erlaubt der Editor Fett **und Kursiv**. Das erzwänge pro Familie vier Schnitte: Regular, Italic, Bold, Bold Italic.

**Hier hilft das eigene Merkblatt weiter.** Das `Merkblatt Zeugniserstellung 2017` hält fest, dass persönliche Anmerkungen durch Ausrufezeichen, Fragezeichen, Anführungszeichen **und Kursivsetzung** nicht ins Arbeitszeugnis gehören. Kursiv ist im Zeugnis also fachlich unzulässig. Wenn wir es aus dem Editor entfernen — was wir ohnehin tun sollten —, halbiert sich der Bedarf:

| | mit Kursiv | ohne Kursiv |
|---|---|---|
| Paragraph-Familie | Regular, Italic, Bold, Bold Italic | **Regular, Bold** |
| Headline-Familie | Regular, Bold | **Regular** |
| **Schnitte pro Marke** | **6** | **3** |
| Comply2gether / Prokuration (eine Familie) | 4 | **2** |

Unterstrichen braucht keinen eigenen Schnitt. Der Prüfhash bleibt auf der lizenzfreien Courier.

Damit ist die Antwort: **zwei bis drei Schnitte pro Marke, kein Family Pack.** Und die Grenze ist nicht aus Sparzwang gesetzt, sondern aus der Fachregel abgeleitet — genau die Art von Begründung, die ein Designsystem tragen sollte.

Wenn der Zeugnistitel dieselbe Familie wie der Fliesstext nutzen darf, sinkt der Bedarf auf **zwei Schnitte pro Marke**. Das ist eine gestalterische Entscheidung, die wir gerne gemeinsam treffen.

---

## 6. Zur Lizenzfrage — was der MyFonts-Link nicht abdeckt

Zwei Punkte, die vor jeder Budgetfreigabe geklärt sein müssen.

**a) Serverseitig erzeugte PDFs sind kein Desktop-Kauf.**
zeugnix rendert das Zeugnis auf dem Server und bettet die Schrift in jedes PDF ein. Nach der [MyFonts-FAQ](https://www.myfonts.com/pages/faq/) ist das ausdrücklich der Fall der **Server-Lizenz** („required for sites, web apps, or services that allow a non-licensed user to utilize the font to create a product … would cover server-generated documents like dynamic PDFs"). Eine **Desktop-Lizenz schliesst Einbettung und Weitergabe explizit aus** und genügt hier nicht.

Die Live-Vorschau im Browser braucht **zusätzlich** eine **Webfont-Lizenz**. Diese wird bei MyFonts von den meisten Foundries **jährlich und nach Seitenaufrufen** abgerechnet.

Es sind also **zwei Lizenzarten parallel**, und bei der Webfont-Lizenz handelt es sich um eine **laufende, mengenabhängige Verpflichtung — keinen Einmalkauf.** Das ändert die Wirtschaftlichkeitsrechnung und sollte vor der Auswahl bekannt sein.

**b) Nicht alle fünf Schriften gibt es bei MyFonts.**
Nach erster Recherche — **jede Zeile ist vor einer Beschaffung zu verifizieren**:

| Schrift | Vermutliche Bezugsquelle | Bemerkung |
|---|---|---|
| Inter | SIL Open Font License | **kostenlos**, bereits im Produkt |
| Minion | Adobe | Lizenzierung über Adobe, nicht MyFonts; Server-Einbettung gesondert prüfen |
| Akkurat | Lineto (Direktvertrieb) | vermutlich nicht über MyFonts beziehbar |
| Rotis Sans | Monotype | |
| Chambers Sans | Fontsmith / Monotype | |
| CocoSharp | Latinotype | |
| Campton | René Bieder | |

**Empfehlung für die Reihenfolge: mit CSL beginnen.** Deren Paragraph-Schrift ist **Inter** — Open Source, kostenlos, und bereits im Produkt vorhanden. Damit lässt sich die gesamte Marken-Pipeline (Theme, Einbettung, PDF, Vorschau) **zu null Lizenzkosten** end-to-end beweisen, bevor irgendetwas gekauft wird. Erst wenn das steht, kaufen wir die erste kommerzielle Schrift.

---

## 7. Barrierefreiheit

Im Mail zu Recht genannt. Die heutige Akzentfarbe Petrol `#0F7A6B` erreicht auf Papierweiss einen Kontrast von **≈ 5,2 : 1**. Sie besteht damit **WCAG AA** für Fliesstext (Schwelle 4,5 : 1); die strengere Stufe AAA (7 : 1) erreicht sie nicht.

Für die Markenfarben aus der `Brand Summary` können wir das noch nicht prüfen — dafür brauchen wir die **exakten Hex-Werte**, nicht die Farbeindrücke aus dem PDF. Sobald sie vorliegen, läuft jede Markenfarbe durch einen automatischen Kontrast-Test, der beim Bauen der Anwendung fehlschlägt, wenn ein Theme unter 4,5 : 1 fällt. Der Test schützt damit den Theme-Autor, nicht den Endnutzer — was der Punkt an einem Designsystem mit Grenzen ist.

Anzumerken ist: Die roten Marken (CSL, Comply2gether) und das Stahlblau (IAB) könnten hier knapp werden, je nach Sättigung. Das ist lösbar, indem die Markenfarbe für **Flächen und Linien** genutzt wird und der Fliesstext auf dem dunklen Neutralton bleibt.

---

## 8. Testzugang und direkte Abstimmung

Beides gern, und der Vorschlag geht sogar weiter.

- **Testzugang:** Wir richten einen Account auf der **Preview-Umgebung** ein. Nicht auf der Produktivumgebung — dort liegen echte Mandantendaten.
- **Direkter Draht:** Eine Vermittlung ist nicht nötig. Silvan Schück ist der Entwickler und stimmt sich direkt ab.

Vorschlag für einen Termin von 45 Minuten:

1. Token-Satz aus Abschnitt 4 gemeinsam durchgehen und die Rollen festlegen
2. Die Schriftschnitt-Matrix aus Abschnitt 5 bestätigen
3. Bezugsquelle und Lizenzform pro Schrift klären, Kostenrahmen abstecken
4. Reihenfolge der fünf Marken festlegen

---

## 9. Offene Fragen

1. **Kursiv im Zeugnis** — wird bestätigt, dass es ausgeschlossen werden soll? Das Merkblatt 2017 sagt ja. Es halbiert die benötigten Schriftschnitte.
2. **Bezugseinheit des Brandings** — pro Marke oder pro ausstellender Gesellschaft? Beide sind abbildbar, es entscheidet über das Datenmodell.
3. **Reihenfolge der Marken** — Vorschlag CSL zuerst, weil Inter lizenzkostenfrei ist.
4. **Lizenzhalter** — beschafft First Advisory die Lizenzen, oder zeugnix? Bei einer pageview-basierten Webfont-Lizenz ist das eine **laufende** Verpflichtung mit einer Mengenschwelle, die jemand überwachen muss.
5. **Titelschrift** — braucht der Zeugnistitel wirklich die Headline-Familie, oder genügt die Paragraph-Familie? Ersteres kostet pro Marke eine ganze zusätzliche Familie.
6. **Exakte Hex-Werte** der fünf Markenfarben, für den Kontrast-Test.

---

## Was wir bis zum Termin bereits umsetzen

Die Token-Ebene aus Abschnitt 4, die Zusammenführung der drei duplizierten Render-Stellen, die Entfernung der unbegrenzten Schrift- und Farbwahl aus dem Editor, sowie den Kontrast-Test. Das alles ist **lizenzfrei** und benötigt keine Entscheidung über Schriften. Es ist die Grundlage, auf der das Hinzufügen einer Marke danach eine Datenänderung ist und kein Projekt.
