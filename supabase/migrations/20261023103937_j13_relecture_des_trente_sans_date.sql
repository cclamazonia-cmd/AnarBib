-- =========================================================================
-- J13, suite — les ressources « domaine public » sans date relues une à une
-- (23/10/2026) : 24 PDF passent au restreint, trois fiches corrigées
-- =========================================================================
-- Date     : 2026-10-23
-- Chantier : documents numériques — REGISTRE §47, NUMDIF-2 amendé le 22/10
-- Auteur   : Claude (assistant·e), pour la coordination
-- Ref      : 20261022211722 (Rocker, De Boe), 20261022213527 (sans candidat),
--            docs/journal/audits/RELECTURE_j13_domaine_public_2026-10-22.md
--
-- POURQUOI
--   NUMDIF-2 (d) : domaine public = auteur·rice ET traducteur·rice morts
--   depuis plus de 70 ans ; œuvre collective ou anonyme : 70 ans depuis la
--   publication ; une date inconnue ne fait pas le cas, le doute va à (c).
--   Les PDF ont été lus le 23/10 :
--     · « Dag van de anarchie : Leuven » (1332) : programme de la journée du
--       3-4 avril 1982, textes de personnes vivantes, aucune mention de libre
--       reproduction sur ses 7 pages → (c) ;
--     · « Commune van Parijs » (1331) : texte « basé sur les articles des
--       historiennes Denise De Weerdt et Catherine Oukhow », bibliographie
--       jusqu'en 2007, aucune mention → (c) ;
--     · « Bart de Ligt 1883-1938 » (868) : l'avant-propos la date de 1958
--       (« il y a vingt ans que De Ligt est mort ») et réunit « divers
--       collaborateurs » ; œuvre collective de 1958 → (c) jusqu'au 1er janvier
--       2029 ; l'année de la notice (« 1883 », la naissance) devient 1958 ;
--     · « De Syndicalist » (NSV, 19 numéros, janvier-mai 1940) : rédaction
--       d'Albert de Jong (†1970), articles signés d'initiales et d'une dizaine
--       de noms sans date connue → (c), question posée à J/M sur les
--       contributeurs ;
--     · Schleuning, « A abolição do trabalho e outros mitos » (71) : traduction
--       de 2011 (Ateneu Diego Giménez, COB-AIT), autrice vivante, aucune
--       mention → (c) ;
--     · « El mundo libertario » (39) : « © 2009, Editorial Aún Creemos en los
--       Sueños », registre de propriété intellectuelle → (c).
--   Décisions de Xavier des 22 et 23/10/2026 (questionnaires).
--
-- CE QUE FAIT LE PAQUET (donnée seule)
--   1. 22 candidats d'Anarchief (1331, 1332, 868, 19 × De Syndicalist) :
--      domaine_public → statut_inconnu, motif ajouté à la justification,
--      cas d'avant dans tool_notes ; compte gardé 0 ou 22.
--   2. 39 et 71 (sans candidat) : la décision s'écrit dans la ressource
--      (`metadata.restriction_demandee`, chemin de 20261022213527) ; compte
--      gardé 0 ou 2.
--   Les fichiers ne bougent pas ici : la fonction Edge realign-digital-resource
--   les ramène dans pdf-restrito.
--   3. Fiches : année 1958 pour la brochure de Ligt ; « Yves Delage Goldsmith »
--      (11405, une seule notice) devient Yves Delage (1854-1920), et le second
--      auteur de « La Parthénogénèse » (« Marie », sans autorité) est rattaché
--      à Marie Goldsmith (11393). Gardes : chaque ligne n'est touchée que si
--      elle a encore la valeur lue le 23/10.
-- =========================================================================

BEGIN;

DO $j13b$
DECLARE
  c_syndicalist constant bigint[] := ARRAY[1291, 1293, 1294, 1295, 1296, 1297, 1298, 1299, 1300,
                                            1301, 1302, 1303, 1304, 1305, 1306, 1307, 1308, 1309, 1310];
  c_tous constant bigint[] := ARRAY[868, 1331, 1332] || c_syndicalist;
  v_n int;
BEGIN
  SELECT count(*) INTO v_n FROM ingest.digital_candidates c
   WHERE c.resource_id = ANY (c_tous) AND c.source_name = 'Anarchief.org' AND c.status = 'verse'
     AND c.source_case = 'domaine_public';
  IF v_n NOT IN (0, 22) THEN
    RAISE EXCEPTION 'J13 relecture : % candidat(s) au critère (0 ou 22 attendus)', v_n;
  END IF;

  UPDATE ingest.digital_candidates c
     SET source_case = 'statut_inconnu',
         justification = c.justification || ' — Restreint le 23/10/2026 (NUMDIF-2 amendé, relecture du PDF) : '
           || CASE WHEN c.resource_id = 868
                   THEN 'brochure de 1958 (avant-propos : « il y a vingt ans que De Ligt est mort »), textes de divers collaborateurs ; œuvre collective, domaine public le 1er janvier 2029.'
                   WHEN c.resource_id = 1331
                   THEN 'texte récent, « basé sur les articles des historiennes Denise De Weerdt et Catherine Oukhow », bibliographie jusqu''en 2007, sans mention de libre reproduction.'
                   WHEN c.resource_id = 1332
                   THEN 'programme de la journée du 3-4 avril 1982, textes de personnes vivantes, sans mention de libre reproduction.'
                   ELSE 'numéro de 1940, rédaction d''Albert de Jong (mort en 1970), articles signés d''initiales et de noms sans date connue ; question posée à J/M sur les contributeurs.'
              END
           || ' Décision de Xavier du 23/10/2026 (J13).',
         tool_notes = coalesce(c.tool_notes, '{}'::jsonb) || jsonb_build_object('j13_2026_10_23', jsonb_build_object(
           'de', c.source_case, 'vers', 'statut_inconnu',
           'motif', 'NUMDIF-2 amendé : relecture du PDF le 23/10/2026 ; décision de Xavier (J13).')),
         updated_at = now()
   WHERE c.resource_id = ANY (c_tous) AND c.source_name = 'Anarchief.org' AND c.status = 'verse'
     AND c.source_case = 'domaine_public';
  GET DIAGNOSTICS v_n = ROW_COUNT;
  RAISE NOTICE 'J13 relecture : % candidat(s) passé(s) en statut_inconnu', v_n;

  -- 2. sans candidat : la décision dans la ressource
  SELECT count(*) INTO v_n FROM public.book_digital_resources r
   WHERE r.id IN (39, 71) AND r.rights_status = 'dominio_publico' AND r.access_scope = 'publico'
     AND NOT EXISTS (SELECT 1 FROM ingest.digital_candidates c WHERE c.resource_id = r.id AND c.status = 'verse');
  IF v_n NOT IN (0, 2) THEN
    RAISE EXCEPTION 'J13 relecture sans candidat : % ressource(s) au critère (0 ou 2 attendues)', v_n;
  END IF;
  UPDATE public.book_digital_resources r
     SET metadata = coalesce(r.metadata, '{}'::jsonb) || jsonb_build_object('restriction_demandee', jsonb_build_object(
           'le', '2026-10-23', 'par', 'Xavier (administration du réseau)', 'item', 'J13',
           'motif', CASE WHEN r.id = 39
             THEN 'NUMDIF-2 amendé : « © 2009, Editorial Aún Creemos en los Sueños », registre de propriété intellectuelle ; cas (c), décision de Xavier (J13)'
             ELSE 'NUMDIF-2 amendé : traduction de 2011 (Ateneu Diego Giménez), autrice vivante, sans mention de libre reproduction ; cas (c), décision de Xavier (J13)' END)),
         updated_at = now()
   WHERE r.id IN (39, 71) AND r.rights_status = 'dominio_publico' AND r.access_scope = 'publico'
     AND NOT EXISTS (SELECT 1 FROM ingest.digital_candidates c WHERE c.resource_id = r.id AND c.status = 'verse');
  GET DIAGNOSTICS v_n = ROW_COUNT;
  RAISE NOTICE 'J13 relecture sans candidat : % ressource(s) marquée(s)', v_n;

  -- 3. les fiches
  UPDATE public.books SET ano = '1958' WHERE id = 2757 AND bib_ref = 'ANARCHIEF-1881' AND ano = '1883';
  GET DIAGNOSTICS v_n = ROW_COUNT;
  RAISE NOTICE 'J13 fiche de Ligt : % ligne(s)', v_n;

  UPDATE public.authors
     SET preferred_name = 'Yves Delage', sort_name = 'Delage, Yves',
         birth_year = 1854, death_year = 1920, country = 'FR', authority_type = 'person',
         notes = coalesce(notes || E'\n', '') || 'J13 (23/10/2026) : fiche corrigée — l''import avait fondu « Delage, Yves ; Goldsmith, Marie » en une seule autorité.',
         updated_at = now()
   WHERE id = 11405 AND preferred_name = 'Yves Delage Goldsmith'
     AND (SELECT count(*) FROM public.book_contributors bc WHERE bc.author_id = 11405) = 1;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  RAISE NOTICE 'J13 autorité Delage : % ligne(s)', v_n;
  IF v_n = 1 THEN
    UPDATE public.book_contributors SET name = 'Delage, Yves'
     WHERE book_id = 135 AND author_id = 11405 AND name = 'Goldsmith, Yves Delage';
    UPDATE public.book_contributors SET name = 'Goldsmith, Marie', author_id = 11393
     WHERE book_id = 135 AND author_id IS NULL AND name = 'Marie'
       AND EXISTS (SELECT 1 FROM public.authors a WHERE a.id = 11393 AND a.preferred_name = 'Marie Goldsmith');
  END IF;
END
$j13b$;

COMMIT;
