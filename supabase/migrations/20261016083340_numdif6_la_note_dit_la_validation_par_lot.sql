-- =========================================================================
-- NUMDIF-6 — la note et la justification d'une ressource versée par lot
-- disent ce qui a été fait : une validation par lot, pas une lecture de la
-- page de titre
-- =========================================================================
-- Date     : 2026-10-16
-- Chantier : documents numériques — PDF déjà diffusés en ligne (REGISTRE §47)
-- Auteur   : Claude (assistant·e), pour la coordination
-- Session  : NUMDIF — note des ressources versées par lot
-- Ref      : REGISTRE §47 NUMDIF-6 (0.92, 15/10/2026) ; migration
--            20261015182432_numdif_versement_cote_serveur (la fonction
--            d'enregistrement) ; tests/sql/numdif_note_lot_tests.sql
--
-- POURQUOI
--   Les 1 470 PDF d'Anarchief.org (versés les 15-16/10 par la file NUMDIF) ont
--   été validés PAR LOT (NUMDIF-6) : l'administration du réseau, par
--   délégation écrite du 15/10/2026, sur la déclaration de droits de
--   l'archiviste (Rechtenregeling v0.1, lettres du 15/10/2026). Personne n'a
--   ouvert les fichiers un à un. Or ingest.fn_digital_candidate_deposit_record
--   écrivait pour chacun :
--     notes                : « Fac-símile da edição da ficha, verificado na
--                            folha de rosto. … validado pela coordenação da
--                            biblioteca detentora em 15/10/2026. »
--     rights_justification : « … Menção impressa na edição, p. déclaration
--                            par lot (…) : «<remarque de l'archiviste>». »
--                            (diffusion_autorisee, anti_copyright)
--   Les deux sont inexacts : rien n'a été vérifié sur la page de titre, la
--   validation n'est pas celle de la coordination détentrice, et la
--   « mention » est une remarque de l'archiviste, pas un texte imprimé dans
--   l'édition (la remarque figure déjà dans la justification : « remarque
--   J/M : « … » »). Texte validé par Xavier le 16/10/2026.
--
-- CE QUE FAIT LE PAQUET
--   1. La fonction d'enregistrement reçoit une branche NUMDIF-6. Un candidat
--      est « validé par lot » quand sa page de mention est une déclaration
--      par lot (rights_mention_page LIKE 'déclaration par lot%'), OU quand sa
--      justification le dit (« NUMDIF-6 … validation par lot ») — les 156
--      fichiers du lot « Overige bestanden », statut_inconnu, n'ont pas de
--      page de mention et ont pourtant été validés par lot. Pour eux :
--        notes = « Fac-símile da edição da ficha, fornecido pela mesma fonte
--                  que a ficha (NUMDIF-6 ; folha de rosto não verificada
--                  arquivo por arquivo). Candidato NUMDIF n.º <id>, validado
--                  em lote pela administração da rede, por delegação escrita
--                  de 15/10/2026. »
--        justification (diffusion_autorisee, anti_copyright) = celle du
--                  candidat + « Declaração de direitos por lote do arquivista
--                  (Rechtenregeling v0.1, carta de 15/10/2026). »
--      Hors lot, rien ne change (folha de rosto, Menção impressa…).
--      Les dates sont celles de la seule déclaration par lot reçue à ce jour
--      (Anarchief, 15/10/2026) : une deuxième source partenaire déclarée par
--      lot devra amender ce texte ici, pas le recopier.
--   2. Les ressources déjà versées sont corrigées, TEXTE SEUL : notes et
--      rights_justification (et updated_at, par le déclencheur). Ni fichier,
--      ni seau, ni chemin, ni portée, ni statut de droits ne bougent. La
--      justification n'est remplacée que si elle est EXACTEMENT celle
--      qu'écrivait la fonction (justification du candidat + suffixe
--      « Menção impressa… ») ; toute justification retouchée depuis reste
--      telle quelle (et la garde finale la signalerait).
--   En production au 16/10 : 1 470 notes, 1 156 justifications (les autres
--   cas — domaine_public, statut_inconnu — n'avaient pas de suffixe).
--
-- CHECKLIST DOCTRINE
--   - Repartir de la définition RÉELLE : pg_get_functiondef + remplacements à
--     ancres comptées (gabarit de 20261015182432) — une campagne passée qui
--     aurait retouché le corps est conservée ; une ancre absente fait échouer
--     la migration au lieu de la vider.
--   - CREATE OR REPLACE garde propriétaire, SECURITY DEFINER, search_path et
--     droits (fermée à authenticated/anon, ouverte à service_role : T3 de
--     numdif_versement_tests).
--   - Aucun verrou exclusif de table (UPDATE de lignes, remplacement de
--     fonction) : pas de collision avec la fenêtre de sauvegarde.
-- =========================================================================

CREATE OR REPLACE FUNCTION pg_temp.numdif6_remplacer(p_def text, p_old text, p_new text)
RETURNS text LANGUAGE plpgsql AS $r$
DECLARE v_n int;
BEGIN
  v_n := (length(p_def) - length(replace(p_def, p_old, ''))) / length(p_old);
  IF v_n <> 1 THEN
    RAISE EXCEPTION 'NUMDIF-6 : ancre trouvée % fois au lieu d''une : %', v_n, left(p_old, 90);
  END IF;
  RETURN replace(p_def, p_old, p_new);
END
$r$;

-- ── 1. La branche NUMDIF-6 dans la fonction d'enregistrement ────────────
DO $numdif6_fonction$
DECLARE v text;
BEGIN
  v := pg_get_functiondef('ingest.fn_digital_candidate_deposit_record(bigint, uuid, text, text, text, text, bigint)'::regprocedure);

  v := pg_temp.numdif6_remplacer(v, $a$v_res bigint;$a$, $a$v_res bigint;
  v_lot boolean;$a$);

  v := pg_temp.numdif6_remplacer(v, $a$v_justif := CASE WHEN v_c.source_case IN ('diffusion_autorisee', 'anti_copyright')$a$,
$a$-- NUMDIF-6 (16/10/2026) : validé par lot = déclaration de droits de
  -- l'archiviste (page de mention « déclaration par lot … ») ou validation par
  -- lot écrite dans la justification. Ni page de titre lue, ni mention imprimée.
  v_lot := coalesce(v_c.rights_mention_page LIKE 'déclaration par lot%', false)
           OR coalesce(v_c.justification LIKE '%NUMDIF-6%validation par lot%', false);
  v_justif := CASE WHEN v_lot AND v_c.source_case IN ('diffusion_autorisee', 'anti_copyright')
                   THEN v_c.justification
                        || ' Declaração de direitos por lote do arquivista (Rechtenregeling v0.1, carta de 15/10/2026).'
                   WHEN v_c.source_case IN ('diffusion_autorisee', 'anti_copyright')$a$);

  v := pg_temp.numdif6_remplacer(v, $a$'Fac-símile da edição da ficha, verificado na folha de rosto'$a$,
$a$CASE WHEN v_lot THEN
      'Fac-símile da edição da ficha, fornecido pela mesma fonte que a ficha (NUMDIF-6 ; '
      || 'folha de rosto não verificada arquivo por arquivo). Candidato NUMDIF n.º ' || v_c.id
      || ', validado em lote pela administração da rede, por delegação escrita de 15/10/2026.'
    ELSE
    'Fac-símile da edição da ficha, verificado na folha de rosto'$a$);

  v := pg_temp.numdif6_remplacer(v, $a$'DD/MM/YYYY') || '.',$a$, $a$'DD/MM/YYYY') || '.' END,$a$);

  EXECUTE v;
END
$numdif6_fonction$;

-- ── 2. Les ressources déjà versées : texte seul ─────────────────────────
DO $numdif6_donnees$
DECLARE v_notes int; v_justif int; v_reste int;
BEGIN
  WITH lot AS (
    SELECT c.*
      FROM ingest.digital_candidates c
     WHERE c.status = 'verse' AND c.resource_id IS NOT NULL
       AND (coalesce(c.rights_mention_page LIKE 'déclaration par lot%', false)
            OR coalesce(c.justification LIKE '%NUMDIF-6%validation par lot%', false))
  ), maj AS (
    UPDATE public.book_digital_resources r
       SET notes = 'Fac-símile da edição da ficha, fornecido pela mesma fonte que a ficha (NUMDIF-6 ; '
                   || 'folha de rosto não verificada arquivo por arquivo). Candidato NUMDIF n.º ' || lot.id
                   || ', validado em lote pela administração da rede, por delegação escrita de 15/10/2026.',
           rights_justification =
             CASE WHEN lot.source_case IN ('diffusion_autorisee', 'anti_copyright')
                   AND r.rights_justification = lot.justification || ' Menção impressa na edição, p. '
                         || lot.rights_mention_page || ' : «' || lot.rights_mention || '».'
                  THEN lot.justification
                       || ' Declaração de direitos por lote do arquivista (Rechtenregeling v0.1, carta de 15/10/2026).'
                  ELSE r.rights_justification END
      FROM lot
     WHERE r.id = lot.resource_id
       AND r.notes LIKE 'Fac-símile da edição da ficha, verificado na folha de rosto%'
    RETURNING r.rights_justification LIKE '%Declaração de direitos por lote do arquivista%' AS j
  )
  SELECT count(*), count(*) FILTER (WHERE j) INTO v_notes, v_justif FROM maj;

  -- Garde : plus aucune ressource versée par lot ne dit « folha de rosto »
  -- ni ne cite une « déclaration par lot » comme page imprimée.
  SELECT count(*) INTO v_reste
    FROM ingest.digital_candidates c
    JOIN public.book_digital_resources r ON r.id = c.resource_id
   WHERE (coalesce(c.rights_mention_page LIKE 'déclaration par lot%', false)
          OR coalesce(c.justification LIKE '%NUMDIF-6%validation par lot%', false))
     AND (r.notes LIKE '%verificado na folha de rosto%'
          OR r.rights_justification LIKE '%Menção impressa na edição, p. déclaration par lot%');
  IF v_reste > 0 THEN
    RAISE EXCEPTION 'NUMDIF-6 : % ressource(s) versée(s) par lot gardent l''ancien texte', v_reste;
  END IF;

  RAISE NOTICE 'NUMDIF-6 : % note(s) corrigée(s), % justification(s)', v_notes, v_justif;
END
$numdif6_donnees$;
