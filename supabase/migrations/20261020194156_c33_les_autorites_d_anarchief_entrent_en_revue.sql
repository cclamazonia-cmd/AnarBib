-- C33 (20/10/2026) — les 308 autorités créées pour Anarchief entrent dans la
-- file de revue de l'Atelier.
--
-- `1704c05c` (19/10) a créé 308 autorités (197 personnes, 111 collectivités),
-- source « Anarchief.org · import 2026-10 ». La décision de Xavier prévoyait
-- de les marquer pour relecture dans l'Atelier : aucune ligne de file n'avait
-- été créée. Elles y entrent ici, sur les lots EXISTANTS — aucun écran, aucune
-- fonction ne change :
--   * les personnes dans `autorite_forme` (la forme du point d'accès se relit
--     à la main ; la proposition est celle de l'outil, `fn_conv_forme_proposition`,
--     sinon la forme actuelle) ;
--   * les collectivités dans `autorite_collectivite` (proposition : la forme
--     actuelle).
-- « Valider » confirme la forme proposée, « corriger » en donne une autre ;
-- `api.conv_revue_appliquer` l'écrit ensuite, comme pour les autres lots.
-- Une ligne déjà en file pour la même autorité et le même lot ne bouge pas.
--
-- Vérifié en lisant la production le 20/10 : « Wayne Prize », la graphie des
-- trois notices d'Anarchief (ANARCHIEF-988, -3052, -3053), est bien liée à
-- Wayne Price (11615, « Price, Wayne »), et la graphie de la source est gardée
-- en forme variante. Rien à corriger.
--
-- Sans ces autorités (banc, rejeu), ne fait rien.

DO $c33$
DECLARE
  v_p int; v_c int;
  c_source constant text := 'Anarchief.org · import 2026-10';
BEGIN
  WITH faits AS (
    INSERT INTO public.catalog_review_queue (lot, entity_kind, entity_id, contexte, avant, apres_propose, decision, note)
    SELECT 'autorite_forme', 'author', a.id, 'Anarchief', a.sort_name,
           coalesce(nullif(btrim(public.fn_conv_forme_proposition(a.sort_name)), ''), a.sort_name),
           'a_revoir',
           'Import Anarchief 19/10 (1704c05c) · autorité créée à l''import, jamais relue : la forme, puis l''identité'
           || CASE WHEN a.wikidata_id IS NOT NULL THEN ' (Wikidata ' || a.wikidata_id || ' à confirmer)' ELSE ' (sans identifiant externe)' END
           || '. Valider = confirmer la forme proposée ; corriger = donner la forme retenue.'
      FROM public.authors a
     WHERE a.source_label = c_source
       AND coalesce(a.authority_type, 'person') NOT IN ('collective', 'congress')
    ON CONFLICT (lot, entity_id) DO NOTHING
    RETURNING 1)
  SELECT count(*) INTO v_p FROM faits;

  WITH faits AS (
    INSERT INTO public.catalog_review_queue (lot, entity_kind, entity_id, contexte, avant, apres_propose, decision, note)
    SELECT 'autorite_collectivite', 'author', a.id, 'Anarchief', a.sort_name, a.sort_name,
           'a_revoir',
           'Import Anarchief 19/10 (1704c05c) · collectivité créée à l''import, jamais relue : la forme, puis l''identité'
           || CASE WHEN a.wikidata_id IS NOT NULL THEN ' (Wikidata ' || a.wikidata_id || ' à confirmer)' ELSE ' (sans identifiant externe)' END
           || '. Valider = confirmer telle quelle ; corriger = donner la forme retenue.'
      FROM public.authors a
     WHERE a.source_label = c_source
       AND a.authority_type IN ('collective', 'congress')
    ON CONFLICT (lot, entity_id) DO NOTHING
    RETURNING 1)
  SELECT count(*) INTO v_c FROM faits;

  -- Vérification : chaque autorité de la source a sa ligne de revue.
  IF EXISTS (SELECT 1 FROM public.authors a
              WHERE a.source_label = c_source
                AND NOT EXISTS (SELECT 1 FROM public.catalog_review_queue q
                                 WHERE q.entity_kind = 'author' AND q.entity_id = a.id
                                   AND q.lot IN ('autorite_forme', 'autorite_collectivite'))) THEN
    RAISE EXCEPTION 'C33 : une autorité d''Anarchief reste hors de la file de revue.';
  END IF;
  RAISE NOTICE 'C33 : % personne(s) et % collectivité(s) d''Anarchief versées en revue.', v_p, v_c;
END
$c33$;
