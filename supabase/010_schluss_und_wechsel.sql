-- ============================================================================
-- zeugnix.ch – Schluss-/Dankformeln + Wechsel-Detailfelder (Migration 010)
-- ----------------------------------------------------------------------------
-- Zweck:
--   (A) certificates: drei optionale Felder für wechsel-spezifische Details
--       (neue Funktion, neue Firma, Wechseldatum). Werden im Neu-Formular
--       erfasst und über {neue_funktion}/{neue_firma}/{wechsel_datum} in die
--       Schlussformel eingesetzt.
--   (B) phrase_blocks: die Schluss-Bausteine werden VOLLSTÄNDIG durch Silvans
--       Katalog ersetzt (alle category='schluss'-Zeilen aus Seed 002 raus).
--       Quelle: scripts/data/bausteine-parsed.json -> schlussLines (Roh-Zeilen),
--       hier handkuratiert: 'Max Mustermann' -> {vorname} {nachname},
--       Geschlechtswörter als {{m|f|d}}-Tokens, Quell-Fehler korrigiert,
--       beispielspezifische Angaben (Firma/Funktion/Datum) in die
--       '<typ>_detail'-Varianten als Platzhalter ausgelagert.
--
-- Engine-Vertrag (lib/phrases/engine.ts): category='schluss', rating='gut',
--   employee_type='mitarbeiter' (Führungskraft fällt darauf zurück),
--   gender='d' mit Tokens. Subkategorien je Zeugnistyp:
--     schluss_dank, zwischen, funktionswechsel(+_detail), vorgesetztenwechsel,
--     interner_wechsel(+_detail), reorganisation,
--     wunsch_mitarbeiter, wunsch_mitarbeiterin.
--   Die '_detail'-Variante greift nur, wenn ALLE ihrer Felder gesetzt sind.
--
-- Idempotent: ADD COLUMN IF NOT EXISTS + DELETE+INSERT der Schluss-Bausteine.
-- Ausführung: Supabase Dashboard -> SQL Editor -> einfügen -> Run
-- ============================================================================

-- (A) Wechsel-spezifische Zusatzfelder (optional) -----------------------------
alter table public.certificates add column if not exists new_function_title text;
alter table public.certificates add column if not exists new_company_name text;
alter table public.certificates add column if not exists transition_date date;

-- (B) Schluss-Bausteine vollständig ersetzen ----------------------------------
delete from public.phrase_blocks where category = 'schluss';

insert into public.phrase_blocks
  (category, subcategory, employee_type, gender, rating, variant, text, signal_strength, tonality)
values
-- ----- schluss_dank: allgemeine Dank-/Schlussformel (Typ 'schluss' + Dank) ---
('schluss', 'schluss_dank', 'mitarbeiter', 'd', 'gut', 1,
 'Wir danken {vorname} {nachname} für die bisherige Mitarbeit und wünschen {{ihm|ihr|ihm/ihr}} alles Gute und viel Erfolg.',
 'eindeutig', 'positiv'),
('schluss', 'schluss_dank', 'mitarbeiter', 'd', 'gut', 2,
 'Wir danken {vorname} {nachname} bestens für die bisherige wertvolle Mitarbeit und wünschen {{ihm|ihr|ihm/ihr}} alles Gute und weiterhin viel Erfolg.',
 'eindeutig', 'positiv'),
('schluss', 'schluss_dank', 'mitarbeiter', 'd', 'gut', 3,
 'Wir danken {vorname} {nachname} für die bisherige sehr wertvolle Unterstützung bestens und hoffen, noch lange auf {{seine|ihre|seine/ihre}} geschätzte Mitarbeit zählen zu dürfen.',
 'eindeutig', 'positiv'),
('schluss', 'schluss_dank', 'mitarbeiter', 'd', 'gut', 4,
 'Wir danken {vorname} {nachname} bestens für die bisherige Mitarbeit.',
 'mittel', 'positiv'),

-- ----- zwischen: Zwischenzeugnis (aus Seed 002 übernommen) -------------------
('schluss', 'zwischen', 'mitarbeiter', 'd', 'gut', 1,
 'Dieses Zwischenzeugnis wird auf Wunsch von {{Herrn|Frau|Herrn/Frau}} {nachname} ausgestellt.',
 'eindeutig', 'neutral'),

-- ----- funktionswechsel: generisch + Detail (neue_funktion + neue_firma) -----
('schluss', 'funktionswechsel', 'mitarbeiter', 'd', 'gut', 1,
 '{vorname} {nachname} verlässt uns heute auf eigenen Wunsch, um eine neue berufliche Herausforderung anzunehmen. Wir danken {{Herrn|Frau|Herrn/Frau}} {nachname} bestens für die wertvolle Mitarbeit und wünschen {{ihm|ihr|ihm/ihr}} alles Gute und weiterhin viel Erfolg.',
 'eindeutig', 'positiv'),
('schluss', 'funktionswechsel_detail', 'mitarbeiter', 'd', 'gut', 1,
 '{vorname} {nachname} verlässt uns heute auf eigenen Wunsch, um eine Aufgabe als {neue_funktion} bei der {neue_firma} zu übernehmen. Wir danken {{Herrn|Frau|Herrn/Frau}} {nachname} bestens für die wertvolle Mitarbeit und wünschen {{ihm|ihr|ihm/ihr}} alles Gute und weiterhin viel Erfolg.',
 'eindeutig', 'positiv'),

-- ----- vorgesetztenwechsel --------------------------------------------------
('schluss', 'vorgesetztenwechsel', 'mitarbeiter', 'd', 'gut', 1,
 'Dieses Zeugnis wird aufgrund eines Vorgesetztenwechsels ausgestellt. Wir danken {{ihm|ihr|ihm/ihr}} für die bisherige sehr wertvolle Unterstützung bestens und hoffen, noch lange auf {{seine|ihre|seine/ihre}} geschätzte Mitarbeit zählen zu dürfen.',
 'eindeutig', 'neutral'),

-- ----- interner_wechsel: generisch + Detail (wechsel_datum + neue_funktion) --
('schluss', 'interner_wechsel', 'mitarbeiter', 'd', 'gut', 1,
 'Wir danken {vorname} {nachname} bestens für die bisherige wertvolle Mitarbeit und wünschen {{ihm|ihr|ihm/ihr}} viel Freude und Erfolg im neuen Aufgabengebiet.',
 'eindeutig', 'positiv'),
('schluss', 'interner_wechsel_detail', 'mitarbeiter', 'd', 'gut', 1,
 'Dieses Zeugnis wird aufgrund eines internen Übertritts von {{Herrn|Frau|Herrn/Frau}} {nachname} ausgestellt. {{Er|Sie|Er/Sie}} wird per {wechsel_datum} als {neue_funktion} weiterhin bei uns tätig sein.',
 'eindeutig', 'neutral'),

-- ----- reorganisation -------------------------------------------------------
('schluss', 'reorganisation', 'mitarbeiter', 'd', 'gut', 1,
 '{vorname} {nachname} verlässt uns heute. Wir danken {{Herrn|Frau|Herrn/Frau}} {nachname} bestens für die wertvolle Mitarbeit und wünschen {{ihm|ihr|ihm/ihr}} für die berufliche und private Zukunft alles Gute.',
 'eindeutig', 'positiv'),

-- ----- wunsch_mitarbeiter / wunsch_mitarbeiterin (gleicher Text, Tokens) ----
('schluss', 'wunsch_mitarbeiter', 'mitarbeiter', 'd', 'gut', 1,
 'Dieses Zeugnis wird auf Wunsch von {{Herrn|Frau|Herrn/Frau}} {nachname} ausgestellt. Wir danken {{ihm|ihr|ihm/ihr}} für die bisherige sehr wertvolle Unterstützung bestens und hoffen, noch lange auf {{seine|ihre|seine/ihre}} geschätzte Mitarbeit zählen zu dürfen.',
 'eindeutig', 'neutral'),
('schluss', 'wunsch_mitarbeiterin', 'mitarbeiter', 'd', 'gut', 1,
 'Dieses Zeugnis wird auf Wunsch von {{Herrn|Frau|Herrn/Frau}} {nachname} ausgestellt. Wir danken {{ihm|ihr|ihm/ihr}} für die bisherige sehr wertvolle Unterstützung bestens und hoffen, noch lange auf {{seine|ihre|seine/ihre}} geschätzte Mitarbeit zählen zu dürfen.',
 'eindeutig', 'neutral');

-- Done.
