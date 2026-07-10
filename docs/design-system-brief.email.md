# E-Mail-Entwurf an Christoph Senn

> Nicht Teil des Briefs. Zum Kopieren, Kürzen, Anpassen.
> Anhang: `design-system-brief.html` — öffnet sich per Doppelklick im Browser,
> lädt nichts nach, und lässt sich über „Drucken → Als PDF sichern" zu PDF machen.

---

**Betreff:** Schriften und Designsystem — du hast recht, und zwei Punkte kommen dazu

Hallo Christoph

Danke für den Anhang und vor allem für den Kommentar. Du hast recht: zeugnix hatte kein Designsystem. Keine Design Tokens, keine Theme-Ebene, keine CSS-Variablen ausser zwei statischen, keine definierten Grenzen. Die Typografie des Zeugnisses stand als Literal an drei Stellen im Code, und die waren bereits leicht auseinandergelaufen. Unsere Anfrage „Schrift und Farbe konfigurierbar machen" war genau die isolierte Einzelanpassung, vor der du warnst.

Deinen Einwand haben wir umgesetzt, statt ihn nur zu diskutieren. Beiliegend der Brief mit dem Token-Satz, den Grenzen und der Schriftschnitt-Matrix. Der lizenzfreie Teil ist bereits gebaut — er brauchte keine Schriftentscheidung.

Drei Punkte möchte ich vorwegnehmen:

**1. Der MyFonts-Link greift zu kurz, aber anders, als ich zuerst dachte.** Die meisten eurer Schriften sind dort tatsächlich erhältlich; nur Akkurat läuft über den Direktvertrieb von Lineto, und Inter ist ohnehin Open Source. Das eigentliche Problem ist die **Lizenzart**. zeugnix erzeugt die PDFs auf dem Server und bettet die Schrift in jedes Dokument ein. Die MyFonts-FAQ ordnet genau das der **Server-Lizenz** zu und nennt als Beispiel ausdrücklich „PDF receipts". Eine Desktop-Lizenz deckt das nicht. Kommt später die Markenschrift auch in die Browser-Vorschau, braucht es zusätzlich eine **Webfont-Lizenz**, die nach monatlichen Seitenaufrufen bemessen wird. Das sind wiederkehrende Kosten, kein Einmalkauf.

**Und ein Vorbehalt, den ich nicht wegargumentieren will:** Dieselbe FAQ schreibt, eine so lizenzierte Schrift dürfe nicht in SaaS eingesetzt werden, „where the service is the product rather that the item that is created". Ob zeugnix darunter fällt, ist Auslegungssache — bei uns ist der Dienst das Produkt *und* das Zeugnis der geschaffene Gegenstand. **Das müssen wir vor einem Kauf mit der Foundry schriftlich klären.** Es ist der einzige Punkt im ganzen Vorhaben, der ein echtes Risiko trägt.

**2. Euer Merkblatt beantwortet die Schriftschnitt-Frage.** Das „Merkblatt zur Zeugniserstellung" von 2017 nennt unter „Was gehört nicht ins Zeugnis?" die persönlichen Andeutungen „durch Ausrufe oder Fragezeichen, kursive Schrift, Anführungszeichen". So wie wir das verstehen, geht es dort um die Andeutung, nicht um den Schriftschnitt an sich — die rechtliche Einordnung liegt bei euch. Wir haben Kursiv trotzdem aus dem Editor genommen, damit es gar nicht erst als Andeutung dienen kann. Nebeneffekt: pro Marke fallen zwei Schnitte weg. Statt sechs braucht es vier; bei Comply2gether und Prokuration, die eine Familie für Headlines und Paragraphs nutzen, nur zwei.

Aufgefallen ist uns, dass **Fettdruck nicht auf dieser Liste steht.** Er ist deshalb geblieben. Wenn ihr ihn aus derselben Erwägung ebenfalls streichen wollt, spart das nochmals einen Schnitt pro Marke — sagt uns kurz Bescheid.

**3. Als Reihenfolge schlage ich CSL zuerst vor.** Deren Fliesstextschrift ist Inter, Open Source und kostenlos. Damit können wir die ganze Marken-Pipeline zu null Lizenzkosten beweisen, bevor wir die erste Schrift kaufen. (Zur Klarstellung: Inter steckt noch nicht im Zeugnis-Renderer — die Oberfläche nutzt die verwandte Inter Tight. Für CSL wäre es ein Einbauschritt, aber kein Kostenpunkt.)

**Zu deiner Frage nach Testzugang und Entwickler:** beides gern, wir brauchen keinen Umweg. zeugnix wurde von Patrick Hitz begonnen; ich entwickle mit und stimme mich direkt mit dir ab. Einen Testzugang richte ich dir auf unserer Preview-Umgebung ein — nicht auf der Produktivumgebung, dort liegen echte Mandantendaten. Hast du in den nächsten Tagen 45 Minuten? Agenda: Token-Satz durchgehen, Schriftschnitte bestätigen, Lizenzform und den SaaS-Vorbehalt pro Schrift klären, Reihenfolge der Marken festlegen.

Was ich von dir noch bräuchte: die **exakten Hex-Werte** der fünf Markenfarben. Aus dem PDF lassen sie sich nur schätzen, und ich möchte keine geschätzte Markenfarbe ins System legen. Jede Farbe läuft bei uns durch einen Kontrasttest, der dem Build vorgeschaltet ist — verfehlt sie WCAG AA, lässt sich die Anwendung nicht mehr bauen. Unser heutiges Petrol liegt bei 5,23:1 und besteht; bei kräftigen Rot- und Blautönen kann es knapper werden.

Beste Grüsse
Silvan
