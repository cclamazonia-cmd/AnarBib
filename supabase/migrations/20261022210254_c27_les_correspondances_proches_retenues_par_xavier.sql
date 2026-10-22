-- ============================================================================
-- C27, suite — les correspondances PROCHES retenues par Xavier (22/10/2026,
-- relecture ligne à ligne par questionnaire, après 20261022203129).
--
-- Retenues (cinq lignes sur dix) :
--   · Spaanse Burgeroorlog          → Révolution espagnole
--   · Pacifisme, Sociale Defensie   → Antimilitarisme
--   · Bolshevisme, Lenin            → Révolution russe
--   · I.A.A., I.W.M.A. (l'AIT)      → Anarchosyndicalisme
--   · Platformisme                  → Organisation
-- Écartées : Criminologie (→ abolitionnisme pénal), Pedagogie / Opvoeding /
-- Educatie (→ éducation libertaire), Kraken (→ mouvement de quartier),
-- Situationisme / Autonomen (→ contre-culture), Sexualiteit (→ révolution
-- sexuelle) — trop larges ou à juger notice par notice.
--
-- Même fonction que les exactes (private.fn_indexer_sujets_importes) : matières
-- actives seulement, sujets existants gardés, aucune matière créée, rejouable.
-- Mesuré en lecture le 22/10 : 18 affectations neuves sur 18 notices, dont 15
-- n'avaient encore aucun sujet. Hors production, rien à faire.
-- ============================================================================
DO $$
DECLARE
  v_res jsonb; v_manque int;
  c_proches constant jsonb := '{
    "Spaanse Burgeroorlog": "revolucao-espanhola",
    "Pacifisme": "antimilitarismo", "Sociale Defensie": "antimilitarismo",
    "Bolshevisme": "revolucao-russa", "Lenin": "revolucao-russa",
    "I.A.A.": "anarcossindicalismo", "I.W.M.A.": "anarcossindicalismo",
    "Platformisme": "organisation"
  }';
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.books WHERE bib_ref LIKE 'ANARCHIEF-%') THEN
    RAISE NOTICE 'C27 proches : aucune notice d''Anarchief ici, rien à indexer';
    RETURN;
  END IF;

  v_res := private.fn_indexer_sujets_importes('ANARCHIEF-', c_proches);
  RAISE NOTICE 'C27 proches : %', v_res;

  SELECT count(*) INTO v_manque
    FROM public.books b,
         regexp_split_to_table(coalesce(b.marc_json -> 'ingest' -> 'raw_payload' ->> 'sujets', ''), '\s*\|\s*') x
    JOIN jsonb_each_text(c_proches) c ON c.key = btrim(x)
    JOIN public.subjects s ON s.slug = c.value
   WHERE b.bib_ref LIKE 'ANARCHIEF-%'
     AND NOT EXISTS (SELECT 1 FROM public.book_subjects bs WHERE bs.book_id = b.id AND bs.subject_id = s.id);
  IF v_manque > 0 THEN
    RAISE EXCEPTION 'C27 proches : % correspondance(s) retenue(s) non posée(s)', v_manque;
  END IF;
END $$;
