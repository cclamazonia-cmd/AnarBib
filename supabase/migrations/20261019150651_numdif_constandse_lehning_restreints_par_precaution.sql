-- =========================================================================
-- NUMDIF — 34 PDF d'Anarchief.org (Constandse, Lehning) restreints par
-- précaution, en attendant l'archiviste
-- =========================================================================
-- Date     : 2026-10-19
-- Chantier : documents numériques — PDF déjà diffusés en ligne (REGISTRE §47)
-- Auteur   : Claude (assistant·e), pour la coordination
-- Session  : Anarchief — ouvrir le lot Overige (même outil, dans l'autre sens)
-- Ref      : migration 20261019145347_numdif_overige_a_b_et_realignement (la
--            garde, l'enregistrement, et la fonction Edge
--            realign-digital-resource qui déplace le fichier)
--
-- POURQUOI
--   Dans la feuille des lots de TEXTES rendue le 19/10/2026, l'archiviste
--   (J/M) donne à trois auteurs une lettre plus restrictive que celle de leurs
--   FICHIERS (feuille du 15/10) :
--     Constandse, A.L.    : fichiers A + B → textes « B + C » (scans d'un
--                           collaborateur inconnu) ;
--     Constandse, Anton   : fichiers A + B → textes « C » (« wél copyright ») ;
--     Lehning, Arthur     : fichiers A     → textes « B + C » (« copyright ;
--                           erfgenamen niet gevonden »).
--   La question « ces lettres valent-elles aussi pour les fichiers ? » lui
--   est posée. En attendant, la règle v0.1 (un doute = accès restreint)
--   s'applique : décision de Xavier du 19/10/2026 (~17 h 10), « restreins
--   par précaution les 34 PDF publics de Constandse et Lehning ». La
--   ressource 859 (« Anarchisme, zes beschouwingen », De Jong, Lehning e.a.)
--   l'est aussi : Lehning en est co-auteur.
--
-- CE QUE FAIT LE PAQUET (donnée seule)
--   Le cas des 34 candidats passe en statut_inconnu ; la justification garde
--   tout ce qu'elle disait et ajoute la précaution (date, lettre des textes,
--   question en attente) ; tool_notes garde le cas d'avant pour le retour.
--   Les ressources ne bougent PAS ici : la fonction Edge
--   realign-digital-resource les ramène dans pdf-restrito (empreintes avant
--   et après la copie, original effacé), comme le lot Overige dans l'autre
--   sens. Compte gardé : 0 (banc) ou 34 (production), sinon échec.
--
-- CHECKLIST DOCTRINE
--   [x] Aucun objet nouveau ; UPDATE de lignes, sans verrou exclusif
--   [x] Critère par identifiants de ressource ET source ET cas public
-- =========================================================================

BEGIN;

DO $precaution$
DECLARE
  c_ressources constant bigint[] := ARRAY[
    634, 635,                                                    -- Constandse, A.L.
    636, 637, 638, 639, 640, 641, 642, 643, 644, 645, 646, 647, 648, 649,
    650, 651, 652, 653, 654, 655, 656, 657, 1540, 1559,          -- Constandse, Anton
    1184, 1185, 1186, 1187, 1188, 1189, 1190,                    -- Lehning
    859];                                                        -- De Jong, Lehning e.a.
  v_n int;
BEGIN
  SELECT count(*) INTO v_n
    FROM ingest.digital_candidates c
   WHERE c.resource_id = ANY (c_ressources) AND c.source_name = 'Anarchief.org' AND c.status = 'verse'
     AND c.source_case IN ('diffusion_autorisee', 'domaine_public', 'anti_copyright');
  IF v_n NOT IN (0, 34) THEN
    RAISE EXCEPTION 'Précaution Constandse/Lehning : % candidat(s) au critère (0 ou 34 attendus)', v_n;
  END IF;

  UPDATE ingest.digital_candidates c
     SET source_case = 'statut_inconnu',
         justification = c.justification || ' — Restreint par précaution le 19/10/2026 (décision de la coordination) : '
           || CASE WHEN c.resource_id IN (634, 635)
                   THEN 'dans sa feuille des lots de textes du 19/10/2026, J/M donne aux textes de Constandse, A.L. la lettre « B + C » (scans d''un collaborateur inconnu)'
                   WHEN c.resource_id = 859
                   THEN 'Lehning, co-auteur, reçoit la lettre « B + C » dans la feuille des lots de textes de J/M du 19/10/2026 (« copyright ; erfgenamen niet gevonden »)'
                   WHEN c.resource_id BETWEEN 1184 AND 1190
                   THEN 'dans sa feuille des lots de textes du 19/10/2026, J/M donne aux textes de Lehning la lettre « B + C » (« copyright ; erfgenamen niet gevonden »)'
                   ELSE 'dans sa feuille des lots de textes du 19/10/2026, J/M donne aux textes de Constandse, Anton la lettre « C » (« wél copyright »)'
              END
           || ' ; question posée à J/M : cette lettre vaut-elle aussi pour les fichiers ? En attendant, règle v0.1 : un doute = accès restreint.',
         tool_notes = coalesce(c.tool_notes, '{}'::jsonb) || jsonb_build_object('precaution_2026_10_19', jsonb_build_object(
           'de', c.source_case, 'vers', 'statut_inconnu',
           'motif', 'Lettre des textes plus restrictive (feuille de J/M du 19/10/2026) ; décision de Xavier du 19/10/2026 : restreindre par précaution en attendant J/M.')),
         updated_at = now()
   WHERE c.resource_id = ANY (c_ressources) AND c.source_name = 'Anarchief.org' AND c.status = 'verse'
     AND c.source_case IN ('diffusion_autorisee', 'domaine_public', 'anti_copyright');
  GET DIAGNOSTICS v_n = ROW_COUNT;
  RAISE NOTICE 'Précaution Constandse/Lehning : % candidat(s) passé(s) en statut_inconnu', v_n;
END
$precaution$;

COMMIT;

-- =========================================================================
-- Retour : remettre source_case = tool_notes->'precaution_2026_10_19'->>'de'
-- et retirer le suffixe « — Restreint par précaution le 19/10/2026 … » de la
-- justification, puis réaligner les 34 ressources par la fonction Edge.
-- =========================================================================
