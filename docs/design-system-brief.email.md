# E-Mail-Entwurf an Christoph Senn

> Nicht Teil des Briefs. Zum Kopieren, Kürzen, Anpassen.
> Der Brief (`design-system-brief.md`) geht als PDF oder Anhang mit.

---

**Betreff:** Schriften und Designsystem — du hast recht, und zwei Punkte kommen dazu

Hallo Christoph

Danke für den Anhang und vor allem für den Kommentar. Du hast in jedem Punkt recht: zeugnix hat heute kein Designsystem. Keine Design Tokens, keine Theme-Ebene, keine CSS-Variablen ausser zwei statischen, kein Template-System. Die Typografie des Zeugnisses steht als Literal an drei Stellen im Code, und die sind bereits leicht auseinandergelaufen. Unsere Anfrage „Schrift und Farbe konfigurierbar machen" war genau die isolierte Einzelanpassung, vor der du warnst.

Ich habe das im Detail aufgeschrieben — beiliegend der Brief mit dem Ist-Zustand, dem vorgeschlagenen Token-Satz und den Grenzen, die wir setzen wollen. Zwei Punkte daraus möchte ich hier vorwegnehmen, weil sie die Kostenfrage verschieben:

**1. Der MyFonts-Link greift zu kurz.** zeugnix erzeugt die PDFs auf dem Server und bettet die Schrift in jedes Dokument ein. Das ist bei MyFonts nicht der Desktop-Fall, sondern eine **Server-Lizenz** — deren FAQ nennt „server-generated documents like dynamic PDFs" ausdrücklich. Die Live-Vorschau im Browser braucht zusätzlich eine **Webfont-Lizenz**, und die wird dort meist **jährlich nach Seitenaufrufen** abgerechnet. Also zwei Lizenzarten parallel und eine laufende Verpflichtung, kein Einmalkauf. Ausserdem gibt es nicht alle fünf Schriften bei MyFonts: Inter ist Open Source und kostenlos, Akkurat kommt von Lineto, Minion von Adobe.

**2. Dein eigenes Merkblatt beantwortet die Schriftschnitt-Frage.** Das `Merkblatt Zeugniserstellung 2017` hält fest, dass Kursivsetzung — wie Ausrufezeichen und Anführungszeichen — als persönliche Andeutung nicht ins Zeugnis gehört. Unser Editor erlaubt Kursiv heute trotzdem. Nehmen wir es raus, sinkt der Bedarf von vier auf **zwei Schnitte pro Familie**: Regular und Bold. Bei Comply2gether und Prokuration, die eine Familie für Headlines und Paragraphs nutzen, sind das **zwei Schnitte statt eines Family Packs**. Die Grenze ist damit nicht aus Sparzwang gesetzt, sondern aus deiner Fachregel abgeleitet.

Als Reihenfolge schlage ich vor, **mit CSL zu beginnen**: deren Paragraph-Schrift ist Inter, die ist kostenlos und schon im Produkt. Damit können wir die ganze Marken-Pipeline zu null Lizenzkosten beweisen, bevor wir die erste Schrift kaufen.

**Zu deiner Frage nach Testzugang und Entwickler:** beides gern. Ich bin der Entwickler, wir brauchen keinen Umweg. Ich richte dir einen Testzugang auf unserer Preview-Umgebung ein — nicht auf der Produktivumgebung, dort liegen echte Mandantendaten. Hast du in den nächsten Tagen 45 Minuten? Agenda: Token-Satz durchgehen, Schriftschnitte bestätigen, Lizenzform pro Schrift klären, Reihenfolge der Marken festlegen.

Was ich von dir noch bräuchte: die **exakten Hex-Werte** der fünf Markenfarben. Aus dem PDF lassen sie sich nur schätzen, und ich möchte jede Farbe gegen WCAG AA prüfen, bevor sie ins System geht. Unser heutiges Petrol liegt bei rund 5,2:1 und besteht AA — bei den roten Marken könnte es knapper werden.

Bis zum Termin baue ich die Token-Ebene bereits ein und räume die drei duplizierten Stellen zusammen. Das ist lizenzfrei und setzt keine Schriftentscheidung voraus. Danach ist eine neue Marke eine Datenänderung und kein Projekt.

Beste Grüsse
Silvan
