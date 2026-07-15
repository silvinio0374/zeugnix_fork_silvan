-- 014_fix_bausteine_texte.sql
-- Korrektur der Katalog-Bausteine aus 009 (dort bereits in Prod ausgeführt):
--   * 11 defekte Gender-Tokens mit einfachen statt doppelten Klammern
--     (arbeitsorganisation) – wurden von der Engine nicht aufgelöst und
--     standen wörtlich im Zeugnistext
--   * fehlendes {{ein|eine|ein/eine}}-Token (ausdauer_belastbarkeit)
--   * Platzhalter-Baustein 'Auffassungsgabe' (sehr_gut/4) entfernt
--   * Wording: "der Verwaltung"→"dem Unternehmen", "raus"→"heraus",
--     Kommafehler, "deren spezifischen"→"spezifische",
--     selbständig vereinheitlicht
-- Manuell im Supabase-SQL-Editor (Projekt "zeugnix") ausführen.
-- Idempotent: jedes Statement matcht zusätzlich auf den ALTEN Text und
-- trifft beim zweiten Lauf nichts mehr. Erwartung beim ersten Lauf:
-- 39 UPDATE-Treffer, 1 DELETE-Treffer.
-- Entstanden aus dem Diff alt/neu von 009 (generiert, nicht von Hand).

begin;

-- initiativ_fleiss / ungenuegend / Variante 3
update public.phrase_blocks set text = '{vorname} {nachname} fällt es teilweise schwer, Initiative zu entwickeln und sich für {{seinen|ihren|seinen/ihren}} Aufgabenbereich zu engagieren.'
 where category = 'initiativ_fleiss' and subcategory = 'arbeitsbereitschaft_fachwissen'
   and employee_type = 'mitarbeiter' and rating = 'ungenuegend' and variant = 3
   and text = '{vorname} {nachname} fällt es teilweise schwer Initiative zu entwickeln und sich für {{seinen|ihren|seinen/ihren}} Aufgabenbereich zu engagieren.';

-- selbstaendigkeit_nach_eintritt / gut / Variante 2
update public.phrase_blocks set text = 'Bereits nach kurzer Einarbeitungszeit erledigt {{er|sie|er/sie}} {{seine|ihre|seine/ihre}} Aufgaben selbständig. Dank {{seiner|ihrer|seiner/ihrer}} schnellen Auffassungsgabe erkennt {{er|sie|er/sie}} Zusammenhänge und kann sich auf neue Situationen einstellen.'
 where category = 'selbstaendigkeit_nach_eintritt' and subcategory = 'arbeitsbereitschaft_fachwissen'
   and employee_type = 'mitarbeiter' and rating = 'gut' and variant = 2
   and text = 'Bereits nach kurzer Einarbeitungszeit erledigt {{er|sie|er/sie}} {{seine|ihre|seine/ihre}} Aufgaben selbstständig. Dank {{seiner|ihrer|seiner/ihrer}} schnellen Auffassungsgabe erkennt {{er|sie|er/sie}} Zusammenhänge und kann sich auf neue Situationen einstellen.';

-- selbstaendigkeit_nach_eintritt / sehr_gut / Variante 2
update public.phrase_blocks set text = 'Bereits nach kurzer Einarbeitungszeit erledigt {{er|sie|er/sie}} sämtliche Aufgaben sehr selbständig. {{Er|Sie|Er/Sie}} zeichnet sich durch schnelle Auffassungsgabe aus, erkennt relevante Zusammenhänge und kann sich rasch auf neue Situationen einstellen.'
 where category = 'selbstaendigkeit_nach_eintritt' and subcategory = 'arbeitsbereitschaft_fachwissen'
   and employee_type = 'mitarbeiter' and rating = 'sehr_gut' and variant = 2
   and text = 'Bereits nach kurzer Einarbeitungszeit erledigt {{er|sie|er/sie}} sämtliche Aufgaben sehr selbstständig. {{Er|Sie|Er/Sie}} zeichnet sich durch schnelle Auffassungsgabe aus, erkennt relevante Zusammenhänge und kann sich rasch auf neue Situationen einstellen.';

-- innovation / genuegend / Variante 3
update public.phrase_blocks set text = 'Ferner ist {{er|sie|er/sie}} interessiert, an Neuerungen mitzuwirken.'
 where category = 'innovation' and subcategory = 'arbeitsbereitschaft_fachwissen'
   and employee_type = 'mitarbeiter' and rating = 'genuegend' and variant = 3
   and text = 'Ferner ist {{er|sie|er/sie}} interessiert an Neuerungen mitzuwirken.';

-- ausdauer_belastbarkeit / ungenuegend / Variante 1
update public.phrase_blocks set text = 'Ausserdem ist {{er|sie|er/sie}} {{ein|eine|ein/eine}} {{Mitarbeitender|Mitarbeitende|Mitarbeitende/r}}, {{der|die|der/die}} {{seine|ihre|seine/ihre}} Aufgaben grösstenteils gut bewältigt.'
 where category = 'ausdauer_belastbarkeit' and subcategory = 'arbeitsbereitschaft_fachwissen'
   and employee_type = 'mitarbeiter' and rating = 'ungenuegend' and variant = 1
   and text = 'Ausserdem ist {{er|sie|er/sie}} ein {{Mitarbeitender|Mitarbeitende|Mitarbeitende/r}}, {{der|die|der/die}} {{seine|ihre|seine/ihre}} Aufgaben grösstenteils gut bewältigt.';

-- ausdauer_belastbarkeit / genuegend / Variante 1
update public.phrase_blocks set text = 'Ausserdem ist {{er|sie|er/sie}} {{ein|eine|ein/eine}} {{belastbarer|belastbare|belastbare/r}} {{Mitarbeitender|Mitarbeitende|Mitarbeitende/r}}, {{der|die|der/die}} {{seine|ihre|seine/ihre}} Aufgaben in der Regel gut bewältigt.'
 where category = 'ausdauer_belastbarkeit' and subcategory = 'arbeitsbereitschaft_fachwissen'
   and employee_type = 'mitarbeiter' and rating = 'genuegend' and variant = 1
   and text = 'Ausserdem ist {{er|sie|er/sie}} ein {{belastbarer|belastbare|belastbare/r}} {{Mitarbeitender|Mitarbeitende|Mitarbeitende/r}}, {{der|die|der/die}} {{seine|ihre|seine/ihre}} Aufgaben in der Regel gut bewältigt.';

-- ausdauer_belastbarkeit / gut / Variante 1
update public.phrase_blocks set text = 'Auch unter schwierigen Arbeitsbedingungen ist {{er|sie|er/sie}} {{ein|eine|ein/eine}} {{ausdauernder|ausdauernde|ausdauernde/r}} und {{belastbarer|belastbare|belastbare/r}} {{Mitarbeitender|Mitarbeitende|Mitarbeitende/r}}, {{der|die|der/die}} alle Anforderungen stets gut bewältigt.'
 where category = 'ausdauer_belastbarkeit' and subcategory = 'arbeitsbereitschaft_fachwissen'
   and employee_type = 'mitarbeiter' and rating = 'gut' and variant = 1
   and text = 'Auch unter schwierigen Arbeitsbedingungen ist {{er|sie|er/sie}} ein {{ausdauernder|ausdauernde|ausdauernde/r}} und {{belastbarer|belastbare|belastbare/r}} {{Mitarbeitender|Mitarbeitende|Mitarbeitende/r}}, {{der|die|der/die}} alle Anforderungen stets gut bewältigt.';

-- ausdauer_belastbarkeit / gut / Variante 2
update public.phrase_blocks set text = 'Auch unter anspruchsvollen Arbeitsbedingungen ist {{er|sie|er/sie}} {{ein|eine|ein/eine}} {{ausdauernder|ausdauernde|ausdauernde/r}} und {{belastbarer|belastbare|belastbare/r}} {{Mitarbeitender|Mitarbeitende|Mitarbeitende/r}}, {{der|die|der/die}} alle Anforderungen stets gut bewältigt.'
 where category = 'ausdauer_belastbarkeit' and subcategory = 'arbeitsbereitschaft_fachwissen'
   and employee_type = 'mitarbeiter' and rating = 'gut' and variant = 2
   and text = 'Auch unter anspruchsvollen Arbeitsbedingungen ist {{er|sie|er/sie}} ein {{ausdauernder|ausdauernde|ausdauernde/r}} und {{belastbarer|belastbare|belastbare/r}} {{Mitarbeitender|Mitarbeitende|Mitarbeitende/r}}, {{der|die|der/die}} alle Anforderungen stets gut bewältigt.';

-- ausdauer_belastbarkeit / sehr_gut / Variante 1
update public.phrase_blocks set text = 'Auch unter schwierigen Arbeitsbedingungen ist {{er|sie|er/sie}} {{ein|eine|ein/eine}} {{ausdauernder|ausdauernde|ausdauernde/r}} und ausserordentlich {{belastbarer|belastbare|belastbare/r}} {{Mitarbeitender|Mitarbeitende|Mitarbeitende/r}}, {{der|die|der/die}} allen Anforderungen stets sehr gut gewachsen ist.'
 where category = 'ausdauer_belastbarkeit' and subcategory = 'arbeitsbereitschaft_fachwissen'
   and employee_type = 'mitarbeiter' and rating = 'sehr_gut' and variant = 1
   and text = 'Auch unter schwierigen Arbeitsbedingungen ist {{er|sie|er/sie}} ein {{ausdauernder|ausdauernde|ausdauernde/r}} und ausserordentlich {{belastbarer|belastbare|belastbare/r}} {{Mitarbeitender|Mitarbeitende|Mitarbeitende/r}}, {{der|die|der/die}} allen Anforderungen stets sehr gut gewachsen ist.';

-- ausdauer_belastbarkeit / sehr_gut / Variante 2
update public.phrase_blocks set text = 'Auch unter anspruchsvollen Arbeitsbedingungen ist {{er|sie|er/sie}} {{ein|eine|ein/eine}} {{ausdauernder|ausdauernde|ausdauernde/r}} und äusserst {{belastbarer|belastbare|belastbare/r}} {{Mitarbeitender|Mitarbeitende|Mitarbeitende/r}}, {{der|die|der/die}} alle Anforderungen stets sehr gut bewältigt. Dabei behält {{er|sie|er/sie}} die Übersicht und handelt überlegt.'
 where category = 'ausdauer_belastbarkeit' and subcategory = 'arbeitsbereitschaft_fachwissen'
   and employee_type = 'mitarbeiter' and rating = 'sehr_gut' and variant = 2
   and text = 'Auch unter anspruchsvollen Arbeitsbedingungen ist {{er|sie|er/sie}} ein {{ausdauernder|ausdauernde|ausdauernde/r}} und äusserst {{belastbarer|belastbare|belastbare/r}} {{Mitarbeitender|Mitarbeitende|Mitarbeitende/r}}, {{der|die|der/die}} alle Anforderungen stets sehr gut bewältigt. Dabei behält {{er|sie|er/sie}} die Übersicht und handelt überlegt.';

-- verlaesslichkeit_pflichtbewusstsein / ungenuegend / Variante 3
update public.phrase_blocks set text = '{vorname} {nachname} fühlt sich {{seiner|ihrer|seiner/ihrer}} Aufgabe und dem Unternehmen nur bedingt verpflichtet.'
 where category = 'verlaesslichkeit_pflichtbewusstsein' and subcategory = 'arbeitsweise_leistung'
   and employee_type = 'mitarbeiter' and rating = 'ungenuegend' and variant = 3
   and text = '{vorname} {nachname} fühlt sich {{seiner|ihrer|seiner/ihrer}} Aufgabe und der Verwaltung nur bedingt verpflichtet.';

-- verlaesslichkeit_pflichtbewusstsein / genuegend / Variante 2
update public.phrase_blocks set text = 'Wir lernten {vorname} {nachname} als {{einen|eine|einen/eine}} {{zuverlässigen|zuverlässige|zuverlässigen/zuverlässige}} {{Mitarbeiter|Mitarbeiterin|Mitarbeiter/in}} kennen, {{der|die|der/die}} sich {{seiner|ihrer|seiner/ihrer}} Aufgabe und dem Unternehmen verpflichtet fühlt.'
 where category = 'verlaesslichkeit_pflichtbewusstsein' and subcategory = 'arbeitsweise_leistung'
   and employee_type = 'mitarbeiter' and rating = 'genuegend' and variant = 2
   and text = 'Wir lernten {vorname} {nachname} als {{einen|eine|einen/eine}} {{zuverlässigen|zuverlässige|zuverlässigen/zuverlässige}} {{Mitarbeiter|Mitarbeiterin|Mitarbeiter/in}} kennen, {{der|die|der/die}} sich {{seiner|ihrer|seiner/ihrer}} Aufgabe und der Verwaltung verpflichtet fühlt.';

-- verlaesslichkeit_pflichtbewusstsein / gut / Variante 3
update public.phrase_blocks set text = 'Wir erleben {vorname} {nachname} als {{einen|eine|einen/eine}} {{wertvollen|wertvolle|wertvollen/wertvolle}} {{Mitarbeiter|Mitarbeiterin|Mitarbeiter/in}}, {{der|die|der/die}} sich in anerkennenswerter Weise {{seiner|ihrer|seiner/ihrer}} Aufgabe und dem Unternehmen verpflichtet fühlt.'
 where category = 'verlaesslichkeit_pflichtbewusstsein' and subcategory = 'arbeitsweise_leistung'
   and employee_type = 'mitarbeiter' and rating = 'gut' and variant = 3
   and text = 'Wir erleben {vorname} {nachname} als {{einen|eine|einen/eine}} {{wertvollen|wertvolle|wertvollen/wertvolle}} {{Mitarbeiter|Mitarbeiterin|Mitarbeiter/in}}, {{der|die|der/die}} sich in anerkennenswerter Weise {{seiner|ihrer|seiner/ihrer}} Aufgabe und der Verwaltung verpflichtet fühlt.';

-- verlaesslichkeit_pflichtbewusstsein / sehr_gut / Variante 3
update public.phrase_blocks set text = 'Wir erleben {vorname} {nachname} als {{einen|eine|einen/eine}} äusserst {{wertvollen|wertvolle|wertvollen/wertvolle}} {{Mitarbeiter|Mitarbeiterin|Mitarbeiter/in}}, {{der|die|der/die}} sich in unverkennbarer Weise {{seiner|ihrer|seiner/ihrer}} Aufgabe und dem Unternehmen verpflichtet fühlt.'
 where category = 'verlaesslichkeit_pflichtbewusstsein' and subcategory = 'arbeitsweise_leistung'
   and employee_type = 'mitarbeiter' and rating = 'sehr_gut' and variant = 3
   and text = 'Wir erleben {vorname} {nachname} als {{einen|eine|einen/eine}} äusserst {{wertvollen|wertvolle|wertvollen/wertvolle}} {{Mitarbeiter|Mitarbeiterin|Mitarbeiter/in}}, {{der|die|der/die}} sich in unverkennbarer Weise {{seiner|ihrer|seiner/ihrer}} Aufgabe und der Verwaltung verpflichtet fühlt.';

-- selbstaendigkeit_sorgfalt_genauigkeit / ungenuegend / Variante 2
update public.phrase_blocks set text = '{{Er|Sie|Er/Sie}} arbeitet {{seinen|ihren|seinen/ihren}} Möglichkeiten entsprechend selbständig und trifft Entscheidungen nach vorgängigen Abklärungen.'
 where category = 'selbstaendigkeit_sorgfalt_genauigkeit' and subcategory = 'arbeitsweise_leistung'
   and employee_type = 'mitarbeiter' and rating = 'ungenuegend' and variant = 2
   and text = '{{Er|Sie|Er/Sie}} arbeitet {{seinen|ihren|seinen/ihren}} Möglichkeiten entsprechend selbstständig und trifft Entscheidungen nach vorgängigen Abklärungen.';

-- selbstaendigkeit_sorgfalt_genauigkeit / genuegend / Variante 2
update public.phrase_blocks set text = '{{Er|Sie|Er/Sie}} arbeitet sorgfältig und trifft Entscheidungen grösstenteils selbständig.'
 where category = 'selbstaendigkeit_sorgfalt_genauigkeit' and subcategory = 'arbeitsweise_leistung'
   and employee_type = 'mitarbeiter' and rating = 'genuegend' and variant = 2
   and text = '{{Er|Sie|Er/Sie}} arbeitet sorgfältig und trifft Entscheidungen grösstenteils selbstständig.';

-- selbstaendigkeit_sorgfalt_genauigkeit / gut / Variante 2
update public.phrase_blocks set text = '{{Er|Sie|Er/Sie}} arbeitet effizient und genau. Entscheidungen trifft {{er|sie|er/sie}} selbständig und mit Sachkenntnis.'
 where category = 'selbstaendigkeit_sorgfalt_genauigkeit' and subcategory = 'arbeitsweise_leistung'
   and employee_type = 'mitarbeiter' and rating = 'gut' and variant = 2
   and text = '{{Er|Sie|Er/Sie}} arbeitet effizient und genau. Entscheidungen trifft {{er|sie|er/sie}} selbstständig und mit Sachkenntnis.';

-- selbstaendigkeit_sorgfalt_genauigkeit / gut / Variante 3
update public.phrase_blocks set text = '{{Er|Sie|Er/Sie}} trifft Entscheidungen selbständig und mit viel Sachkenntnis.'
 where category = 'selbstaendigkeit_sorgfalt_genauigkeit' and subcategory = 'arbeitsweise_leistung'
   and employee_type = 'mitarbeiter' and rating = 'gut' and variant = 3
   and text = '{{Er|Sie|Er/Sie}} trifft Entscheidungen selbstständig und mit viel Sachkenntnis.';

-- selbstaendigkeit_sorgfalt_genauigkeit / sehr_gut / Variante 2
update public.phrase_blocks set text = '{{Er|Sie|Er/Sie}} arbeitet sehr effizient und genau. Entscheidungen trifft {{er|sie|er/sie}} situationsgerecht, sehr selbständig und mit grosser Sachkenntnis.'
 where category = 'selbstaendigkeit_sorgfalt_genauigkeit' and subcategory = 'arbeitsweise_leistung'
   and employee_type = 'mitarbeiter' and rating = 'sehr_gut' and variant = 2
   and text = '{{Er|Sie|Er/Sie}} arbeitet sehr effizient und genau. Entscheidungen trifft {{er|sie|er/sie}} situationsgerecht, sehr selbstständig und mit grosser Sachkenntnis.';

-- selbstaendigkeit_sorgfalt_genauigkeit / sehr_gut / Variante 3
update public.phrase_blocks set text = '{{Er|Sie|Er/Sie}} trifft Entscheidungen sehr selbständig, vorausschauend und mit grosser Sachkenntnis.'
 where category = 'selbstaendigkeit_sorgfalt_genauigkeit' and subcategory = 'arbeitsweise_leistung'
   and employee_type = 'mitarbeiter' and rating = 'sehr_gut' and variant = 3
   and text = '{{Er|Sie|Er/Sie}} trifft Entscheidungen sehr selbstständig, vorausschauend und mit grosser Sachkenntnis.';

-- arbeitsorganisation / ungenuegend / Variante 4
update public.phrase_blocks set text = '{vorname} {nachname} informiert spärlich über den eigenen Arbeitsbereich und unterschätzt teilweise den Informationsbedarf anderer Stellen. {{Er|Sie|Er/Sie}} meldet sich in schwierigen Situationen bei den Vorgesetzten manchmal zu spät.'
 where category = 'arbeitsorganisation' and subcategory = 'arbeitsweise_leistung'
   and employee_type = 'mitarbeiter' and rating = 'ungenuegend' and variant = 4
   and text = '{vorname} {nachname} informiert spärlich über den eigenen Arbeitsbereich und unterschätzt teilweise den Informationsbedarf anderer Stellen. {Er|Sie|Er/Sie} meldet sich in schwierigen Situationen bei den Vorgesetzten manchmal zu spät.';

-- arbeitsorganisation / genuegend / Variante 3
update public.phrase_blocks set text = 'Dank {{seiner|ihrer|seiner/ihrer}} Umsicht organisiert {vorname} {nachname} Aufgaben und Projekte praxisgerecht.'
 where category = 'arbeitsorganisation' and subcategory = 'arbeitsweise_leistung'
   and employee_type = 'mitarbeiter' and rating = 'genuegend' and variant = 3
   and text = 'Dank {seiner|ihrer|seiner/ihrer} Umsicht organisiert {vorname} {nachname} Aufgaben und Projekte praxisgerecht.';

-- arbeitsorganisation / genuegend / Variante 4
update public.phrase_blocks set text = '{vorname} {nachname} informiert auf Verlangen angemessen über den eigenen Arbeitsbereich und leitet wichtige Informationen meistens weiter. {{Er|Sie|Er/Sie}} bezieht Vorgesetzte bei Bedarf mit ein.'
 where category = 'arbeitsorganisation' and subcategory = 'arbeitsweise_leistung'
   and employee_type = 'mitarbeiter' and rating = 'genuegend' and variant = 4
   and text = '{vorname} {nachname} informiert auf Verlangen angemessen über den eigenen Arbeitsbereich und leitet wichtige Informationen meistens weiter. {Er|Sie|Er/Sie} bezieht Vorgesetzte bei Bedarf mit ein.';

-- arbeitsorganisation / gut / Variante 1
update public.phrase_blocks set text = '{vorname} {nachname} plant und organisiert {{seine|ihre|seine/ihre}} Aufgaben gut und setzt Prioritäten bei der Erfüllung derselben.'
 where category = 'arbeitsorganisation' and subcategory = 'arbeitsweise_leistung'
   and employee_type = 'mitarbeiter' and rating = 'gut' and variant = 1
   and text = '{vorname} {nachname} plant und organisiert {seine|ihre|seine/ihre} Aufgaben gut und setzt Prioritäten bei der Erfüllung derselben.';

-- arbeitsorganisation / gut / Variante 2
update public.phrase_blocks set text = '{vorname} {nachname} plant und organisiert {{seine|ihre|seine/ihre}} Aufgaben effektiv und setzt klare Prioritäten.'
 where category = 'arbeitsorganisation' and subcategory = 'arbeitsweise_leistung'
   and employee_type = 'mitarbeiter' and rating = 'gut' and variant = 2
   and text = '{vorname} {nachname} plant und organisiert {seine|ihre|seine/ihre} Aufgaben effektiv und setzt klare Prioritäten.';

-- arbeitsorganisation / gut / Variante 3
update public.phrase_blocks set text = 'Dank {{seiner|ihrer|seiner/ihrer}} guten analytischen Fähigkeit plant und organisiert {vorname} {nachname} Aufgaben zweckmässig und setzt Prioritäten.'
 where category = 'arbeitsorganisation' and subcategory = 'arbeitsweise_leistung'
   and employee_type = 'mitarbeiter' and rating = 'gut' and variant = 3
   and text = 'Dank {seiner|ihrer|seiner/ihrer} guten analytischen Fähigkeit plant und organisiert {vorname} {nachname} Aufgaben zweckmässig und setzt Prioritäten.';

-- arbeitsorganisation / gut / Variante 4
update public.phrase_blocks set text = '{vorname} {nachname} informiert zeitgerecht, umfassend über den eigenen Arbeitsbereich und leitet wichtige Informationen rechtzeitig weiter. {{Er|Sie|Er/Sie}} bezieht Vorgesetzte in schwierige Situationen mit ein.'
 where category = 'arbeitsorganisation' and subcategory = 'arbeitsweise_leistung'
   and employee_type = 'mitarbeiter' and rating = 'gut' and variant = 4
   and text = '{vorname} {nachname} informiert zeitgerecht, umfassend über den eigenen Arbeitsbereich und leitet wichtige Informationen rechtzeitig weiter. {Er|Sie|Er/Sie} bezieht Vorgesetzte in schwierige Situationen mit ein.';

-- arbeitsorganisation / sehr_gut / Variante 1
update public.phrase_blocks set text = '{vorname} {nachname} plant und organisiert {{seine|ihre|seine/ihre}} Aufgaben gekonnt und setzt konsequent klare Prioritäten bei der Erfüllung derselben.'
 where category = 'arbeitsorganisation' and subcategory = 'arbeitsweise_leistung'
   and employee_type = 'mitarbeiter' and rating = 'sehr_gut' and variant = 1
   and text = '{vorname} {nachname} plant und organisiert {seine|ihre|seine/ihre} Aufgaben gekonnt und setzt konsequent klare Prioritäten bei der Erfüllung derselben.';

-- arbeitsorganisation / sehr_gut / Variante 2
update public.phrase_blocks set text = '{vorname} {nachname} plant und organisiert {{seine|ihre|seine/ihre}} Aufgaben effektiv, systematisch und setzt klare Prioritäten.'
 where category = 'arbeitsorganisation' and subcategory = 'arbeitsweise_leistung'
   and employee_type = 'mitarbeiter' and rating = 'sehr_gut' and variant = 2
   and text = '{vorname} {nachname} plant und organisiert {seine|ihre|seine/ihre} Aufgaben effektiv, systematisch und setzt klare Prioritäten.';

-- arbeitsorganisation / sehr_gut / Variante 3
update public.phrase_blocks set text = 'Dank {{seiner|ihrer|seiner/ihrer}} ausgeprägten analytischen Fähigkeit plant und organisiert {vorname} {nachname} Aufgaben systematisch und nach klaren Prioritäten.'
 where category = 'arbeitsorganisation' and subcategory = 'arbeitsweise_leistung'
   and employee_type = 'mitarbeiter' and rating = 'sehr_gut' and variant = 3
   and text = 'Dank {seiner|ihrer|seiner/ihrer} ausgeprägten analytischen Fähigkeit plant und organisiert {vorname} {nachname} Aufgaben systematisch und nach klaren Prioritäten.';

-- arbeitsorganisation / sehr_gut / Variante 4
update public.phrase_blocks set text = '{vorname} {nachname} informiert zeitgerecht, offen, umfassend über den eigenen Arbeitsbereich und leitet wichtige Informationen sofort an die richtigen Stellen weiter. {{Er|Sie|Er/Sie}} bezieht Vorgesetzte in schwierige Situationen rechtzeitig mit ein.'
 where category = 'arbeitsorganisation' and subcategory = 'arbeitsweise_leistung'
   and employee_type = 'mitarbeiter' and rating = 'sehr_gut' and variant = 4
   and text = '{vorname} {nachname} informiert zeitgerecht, offen, umfassend über den eigenen Arbeitsbereich und leitet wichtige Informationen sofort an die richtigen Stellen weiter. {Er|Sie|Er/Sie} bezieht Vorgesetzte in schwierige Situationen rechtzeitig mit ein.';

-- konfliktfaehigkeit / ungenuegend / Variante 3
update public.phrase_blocks set text = 'Aus Diskussionen und Auseinandersetzungen hält {{er|sie|er/sie}} sich wo möglich heraus oder meidet diese.'
 where category = 'konfliktfaehigkeit' and subcategory = 'persoenliches_verhalten'
   and employee_type = 'mitarbeiter' and rating = 'ungenuegend' and variant = 3
   and text = 'Aus Diskussionen und Auseinandersetzungen hält {{er|sie|er/sie}} sich wo möglich raus oder meidet diese.';

-- konfliktfaehigkeit / genuegend / Variante 4
update public.phrase_blocks set text = 'Mit {{seinem|ihrem|seinem/ihrem}} Verhandlungsgeschick gelingt es {{ihm|ihr|ihm/ihr}}, auch in angespannten Situationen eine für die Beteiligten annehmbare Lösung zu finden.'
 where category = 'konfliktfaehigkeit' and subcategory = 'persoenliches_verhalten'
   and employee_type = 'mitarbeiter' and rating = 'genuegend' and variant = 4
   and text = 'Mit {{seinem|ihrem|seinem/ihrem}} Verhandlungsgeschick gelingt es {{ihm|ihr|ihm/ihr}} auch in angespannten Situationen eine für die Beteiligten annehmbare Lösung zu finden.';

-- konfliktfaehigkeit / gut / Variante 4
update public.phrase_blocks set text = 'Mit {{seinem|ihrem|seinem/ihrem}} guten Verhandlungsgeschick gelingt es {{ihm|ihr|ihm/ihr}}, auch in angespannten Situationen eine für alle Beteiligten geeignete Lösung zu finden.'
 where category = 'konfliktfaehigkeit' and subcategory = 'persoenliches_verhalten'
   and employee_type = 'mitarbeiter' and rating = 'gut' and variant = 4
   and text = 'Mit {{seinem|ihrem|seinem/ihrem}} guten Verhandlungsgeschick gelingt es {{ihm|ihr|ihm/ihr}} auch in angespannten Situationen eine für alle Beteiligten geeignete Lösung zu finden.';

-- konfliktfaehigkeit / sehr_gut / Variante 3
update public.phrase_blocks set text = 'Mit {{seinem|ihrem|seinem/ihrem}} beeindruckenden Verhandlungsgeschick gelingt es {{ihm|ihr|ihm/ihr}}, auch in angespannten Situationen eine konsensfähige Lösung zu finden.'
 where category = 'konfliktfaehigkeit' and subcategory = 'persoenliches_verhalten'
   and employee_type = 'mitarbeiter' and rating = 'sehr_gut' and variant = 3
   and text = 'Mit {{seinem|ihrem|seinem/ihrem}} beeindruckenden Verhandlungsgeschick gelingt es {{ihm|ihr|ihm/ihr}} auch in angespannten Situationen eine konsensfähige Lösung zu finden.';

-- teamfaehigkeit / sehr_gut / Variante 1
update public.phrase_blocks set text = 'Zu {{seinen|ihren|seinen/ihren}} Stärken gehören vorbildliche Teamfähigkeit und die Fähigkeit, gute, positive Zusammenarbeit aktiv zu unterstützen.'
 where category = 'teamfaehigkeit' and subcategory = 'persoenliches_verhalten'
   and employee_type = 'mitarbeiter' and rating = 'sehr_gut' and variant = 1
   and text = 'Zu {{seinen|ihren|seinen/ihren}} Stärken gehören vorbildliche Teamfähigkeit und die Fähigkeit gute, positive Zusammenarbeit aktiv zu unterstützen.';

-- offenheit_fuer_feedback / sehr_gut / Variante 1
update public.phrase_blocks set text = 'Ausserdem gibt und fördert {{er|sie|er/sie}} konstruktives Feedback, ist jederzeit offen für Anregungen und setzt Vorschläge zielsicher sowie nutzbringend um.'
 where category = 'offenheit_fuer_feedback' and subcategory = 'persoenliches_verhalten'
   and employee_type = 'mitarbeiter' and rating = 'sehr_gut' and variant = 1
   and text = 'Ausserdem gibt und fördert {{er|sie|er/sie}} konstruktives Feedback, ist jederzeit offen für Anregungen und setzt Vorschläge zielsicher, sowie nutzbringend um.';

-- synergien_nutzen / sehr_gut / Variante 1
update public.phrase_blocks set text = '{vorname} {nachname} erkennt funktions- und bereichsübergreifende Synergien und kann dank dieser Kompetenz daraus gewonnenes Wissen optimal zum Nutzen des Unternehmens einsetzen.'
 where category = 'synergien_nutzen' and subcategory = 'unternehmertum'
   and employee_type = 'mitarbeiter' and rating = 'sehr_gut' and variant = 1
   and text = '{vorname} {nachname} erkennt funktions- und bereichsübergreifende Synergien und kann dank dieser Kompetenz, daraus gewonnenes Wissen optimal zum Nutzen des Unternehmens einsetzen.';

-- kundenorientierung / sehr_gut / Variante 3
update public.phrase_blocks set text = 'Zudem erweist {{er|sie|er/sie}} sich als {{ein|eine|ein/eine}} überaus {{kompetenter|kompetente|kompetenter/kompetente}}, sehr {{dienstleistungsorientierter|dienstleistungsorientierte|dienstleistungsorientierter/dienstleistungsorientierte}} {{Ansprechpartner|Ansprechpartnerin|Ansprechpartner/in}}, {{welcher|welche|welcher/welche}} die Anliegen der Kunden bzw. verschiedenen Anspruchsgruppen sehr ernst nimmt und deren spezifische Bedürfnisse präzise erfasst.'
 where category = 'kundenorientierung' and subcategory = 'unternehmertum'
   and employee_type = 'mitarbeiter' and rating = 'sehr_gut' and variant = 3
   and text = 'Zudem erweist {{er|sie|er/sie}} sich als {{ein|eine|ein/eine}} überaus {{kompetenter|kompetente|kompetenter/kompetente}}, sehr {{dienstleistungsorientierter|dienstleistungsorientierte|dienstleistungsorientierter/dienstleistungsorientierte}} {{Ansprechpartner|Ansprechpartnerin|Ansprechpartner/in}}, {{welcher|welche|welcher/welche}} die Anliegen der Kunden bzw. verschiedenen Anspruchsgruppen sehr ernst nimmt und deren spezifischen Bedürfnisse präzise erfasst.';

-- Platzhalter-Baustein entfernen (auffassungsgabe / sehr_gut / Variante 4)
delete from public.phrase_blocks
 where category = 'auffassungsgabe' and subcategory = 'arbeitsbereitschaft_fachwissen'
   and employee_type = 'mitarbeiter' and rating = 'sehr_gut' and variant = 4
   and text = 'Auffassungsgabe';

commit;
