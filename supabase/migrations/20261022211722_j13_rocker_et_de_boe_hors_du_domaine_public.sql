-- =========================================================================
-- J13 — 13 PDF d'Anarchief.org (Rocker, De Boe) sortent du domaine public :
-- NUMDIF-2 amendé leur donne le cas (c), restreint
-- =========================================================================
-- Date     : 2026-10-22
-- Chantier : documents numériques — REGISTRE §47, NUMDIF-2 amendé le 22/10
-- Auteur   : Claude (assistant·e), pour la coordination
-- Ref      : 20261019150651_numdif_constandse_lehning_restreints_par_precaution
--            (même geste) ; 20261019145347 (garde, enregistrement, fonction
--            Edge realign-digital-resource qui déplace le fichier)
--
-- POURQUOI
--   Le 22/10/2026, Xavier inscrit le quatrième cas de NUMDIF-2 avec son
--   critère : domaine public = l'auteur·rice ET le·la traducteur·rice morts
--   depuis plus de 70 ans ; une déclaration de source contraire au calcul ne
--   fait pas le cas. Relues contre lui, les 123 ressources actives sous ce
--   cas en donnent 15 dont un·e contributeur·rice est mort·e après 1955 :
--     Rocker, Rudolf (†1958)  : 9 PDF — lettre J/M « A + B », remarque
--                               « auteur gestorven geen copyright » ; protégé
--                               jusqu'au 1er janvier 2029 ;
--     De Boe, Jean (†1974)    : 4 PDF — lettre J/M « A », remarque
--                               « in principe copyright » ;
--     (et deux ressources hors file NUMDIF, SNI 1994 et Díaz †2021, traitées
--     à part : elles n'ont pas de candidat).
--   Décision de Xavier du 22/10/2026 (questionnaire) : restreindre les 13.
--
-- CE QUE FAIT LE PAQUET (donnée seule)
--   Le cas des 13 candidats passe de domaine_public à statut_inconnu ; la
--   justification garde tout ce qu'elle disait et ajoute le motif ;
--   tool_notes garde le cas d'avant. Les ressources ne bougent PAS ici : la
--   fonction Edge realign-digital-resource les ramène dans pdf-restrito
--   (empreintes avant et après la copie, original effacé). Compte gardé :
--   0 (banc) ou 13 (production), sinon échec. Rocker redevient public le
--   1er janvier 2029 par le geste inverse.
--
-- CHECKLIST DOCTRINE
--   [x] Aucun objet nouveau ; UPDATE de lignes, sans verrou exclusif
--   [x] Critère par identifiants de ressource ET source ET cas domaine_public
-- =========================================================================

BEGIN;

DO $j13$
DECLARE
  c_rocker constant bigint[] := ARRAY[1427, 1428, 1429, 1430, 1431, 1432, 1433, 1434, 1549];
  c_deboe  constant bigint[] := ARRAY[849, 850, 851, 852];
  v_n int;
BEGIN
  SELECT count(*) INTO v_n
    FROM ingest.digital_candidates c
   WHERE c.resource_id = ANY (c_rocker || c_deboe) AND c.source_name = 'Anarchief.org' AND c.status = 'verse'
     AND c.source_case = 'domaine_public';
  IF v_n NOT IN (0, 13) THEN
    RAISE EXCEPTION 'J13 Rocker/De Boe : % candidat(s) au critère (0 ou 13 attendus)', v_n;
  END IF;

  UPDATE ingest.digital_candidates c
     SET source_case = 'statut_inconnu',
         justification = c.justification || ' — Restreint le 22/10/2026 (NUMDIF-2 amendé, cas (d) : auteur·rice et traducteur·rice morts depuis plus de 70 ans) : '
           || CASE WHEN c.resource_id = ANY (c_rocker)
                   THEN 'Rudolf Rocker est mort en 1958, ses textes sont protégés jusqu''au 1er janvier 2029 ; la remarque « geen copyright » de la déclaration par lot ne fait pas le domaine public.'
                   ELSE 'Jean De Boe est mort en 1974 ; la remarque de J/M dit elle-même « in principe copyright ».'
              END
           || ' Décision de Xavier du 22/10/2026 (J13).',
         tool_notes = coalesce(c.tool_notes, '{}'::jsonb) || jsonb_build_object('j13_2026_10_22', jsonb_build_object(
           'de', c.source_case, 'vers', 'statut_inconnu',
           'motif', 'NUMDIF-2 amendé le 22/10/2026 : contributeur·rice mort·e depuis moins de 70 ans ; décision de Xavier (J13).')),
         updated_at = now()
   WHERE c.resource_id = ANY (c_rocker || c_deboe) AND c.source_name = 'Anarchief.org' AND c.status = 'verse'
     AND c.source_case = 'domaine_public';
  GET DIAGNOSTICS v_n = ROW_COUNT;
  RAISE NOTICE 'J13 Rocker/De Boe : % candidat(s) passé(s) en statut_inconnu', v_n;
END
$j13$;

-- Cinq publications militantes brésiliennes récentes, classées « domaine
-- public » par la migration de vocabulaire du 20/08 (« livre_de_direitos ») :
-- quatre du Centro de Cultura Libertária da Amazônia (1994-2014), une de la
-- Federação Anarquista do Rio de Janeiro (2008). Moins de 70 ans : pas le cas
-- (d). Décision de Xavier du 22/10/2026 : cas (a), diffusion autorisée par
-- l'éditeur — elles restent publiques, requalifiées `licenca_livre`. Hors file
-- NUMDIF (aucun candidat) : seule la ligne de ressource change, le fichier
-- reste dans son seau public. Compte gardé : 0 (banc) ou 5 (production).
DO $j13a$
DECLARE
  c_ressources constant bigint[] := ARRAY[41, 45, 48, 50, 52];
  v_n int;
BEGIN
  SELECT count(*) INTO v_n FROM public.book_digital_resources r
   WHERE r.id = ANY (c_ressources) AND r.rights_status = 'dominio_publico' AND r.access_scope = 'publico';
  IF v_n NOT IN (0, 5) THEN
    RAISE EXCEPTION 'J13 CCLA/FARJ : % ressource(s) au critère (0 ou 5 attendues)', v_n;
  END IF;
  UPDATE public.book_digital_resources r
     SET rights_status = 'licenca_livre',
         rights_justification = 'Diffusion autorisée par l''éditeur (NUMDIF-2, cas a) : publication militante de '
           || CASE WHEN r.id = 48 THEN 'la Federação Anarquista do Rio de Janeiro' ELSE 'du Centro de Cultura Libertária da Amazônia' END
           || ', diffusion libre attestée par la coordination (décision de Xavier du 22/10/2026, J13). Auparavant : '
           || coalesce(r.rights_justification, '—'),
         metadata = coalesce(r.metadata, '{}'::jsonb) || jsonb_build_object('j13_2026_10_22', jsonb_build_object(
           'de', 'dominio_publico', 'vers', 'licenca_livre', 'cas', 'a')),
         updated_at = now()
   WHERE r.id = ANY (c_ressources) AND r.rights_status = 'dominio_publico' AND r.access_scope = 'publico';
  GET DIAGNOSTICS v_n = ROW_COUNT;
  RAISE NOTICE 'J13 CCLA/FARJ : % ressource(s) requalifiée(s) en licenca_livre', v_n;
END
$j13a$;

COMMIT;

-- =========================================================================
-- Retour (Rocker, le 1er janvier 2029) : remettre source_case =
-- tool_notes->'j13_2026_10_22'->>'de', retirer le suffixe « — Restreint le
-- 22/10/2026 … » de la justification, puis réaligner par la fonction Edge.
-- =========================================================================
