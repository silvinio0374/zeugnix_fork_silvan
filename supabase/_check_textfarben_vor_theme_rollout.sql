-- ============================================================================
-- PRÜFABFRAGE (nur SELECT, ändert nichts) — vor dem Deploy des Token-Refactors
-- ----------------------------------------------------------------------------
-- Kontext: Mit der Theme-Einführung besitzt das Theme die Textfarbe. Die Spalte
-- companies.default_certificate_text_color wird nicht mehr gelesen und nicht
-- mehr geschrieben. Firmen, die dort eine EIGENE Farbe gesetzt hatten, sehen
-- ihren Fliesstext künftig in #1a1d22 — auch in bereits finalisierten
-- Zeugnissen, weil das PDF bei jedem Abruf neu gebaut wird.
--
-- Die Echtheitsprüfung bleibt intakt: der SHA-256 läuft über die Klartext-
-- projektion, nicht über die Formatierung.
--
-- Auf Patricks Supabase-Projekt "zeugnix" im SQL-Editor ausführen.
-- ============================================================================

-- 1) Welche Firmen sind überhaupt betroffen?
--    Leer = niemand betroffen, Refactor kann bedenkenlos deployen.
select
  c.id,
  c.name,
  c.default_certificate_text_color as gesetzte_farbe,
  c.default_certificate_font_family as stil_spalte,
  count(z.id) filter (where z.status = 'final')   as finalisierte_zeugnisse,
  count(z.id) filter (where z.status <> 'final')  as offene_zeugnisse
from companies c
left join certificates z on z.company_id = c.id
where c.default_certificate_text_color is not null
  and lower(c.default_certificate_text_color) <> '#1a1d22'
group by c.id, c.name, c.default_certificate_text_color, c.default_certificate_font_family
order by finalisierte_zeugnisse desc, c.name;


-- 2) Gegenprobe: Verteilung ALLER gesetzten Farben (auch der Standardfarbe).
--    Zeigt, ob das Feld überhaupt je bewusst benutzt wurde.
select
  coalesce(lower(default_certificate_text_color), '(nicht gesetzt)') as farbe,
  count(*) as firmen
from companies
group by 1
order by firmen desc;


-- 3) Gegenprobe: Verteilung der Stil-Spalte. Nach dem Refactor hält sie eine
--    Theme-ID; Alt-Werte helvetica|times|courier werden von resolveTheme()
--    weiterhin verstanden (zeugnix-standard | -serif | -mono).
--    Taucht hier etwas anderes auf, fällt es still auf zeugnix-standard zurück.
select
  coalesce(default_certificate_font_family, '(nicht gesetzt)') as stil,
  count(*) as firmen
from companies
group by 1
order by firmen desc;


-- 4) Nur falls (1) Treffer liefert und einzelne Textstellen zusätzlich eigene
--    Farben tragen: zählt Zeugnisse, deren Rich-Text-Body irgendwo eine
--    color-Mark gesetzt hat. Diese Farben BLEIBEN erhalten (Run-Marks
--    überschreiben die Theme-Farbe) — nur die Grundfarbe des Fliesstexts
--    wechselt. Dient dem Abschätzen des optischen Ausmasses.
select
  z.id,
  z.company_id,
  z.status
from certificates z
where z.formatted_content::text ilike '%"color"%'
order by z.status, z.id;
