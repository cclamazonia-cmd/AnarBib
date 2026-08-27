-- =========================================================================
-- Paquet PÉRIODIQUES P5 — Le titre de revue entre dans l'Atelier autorités
-- =========================================================================
-- Date     : 2026-08-27
-- Chantier : périodiques (spec-periodiques v0.1, §5 et garde G5)
-- Auteur   : Xavier (arbitrages) + Claude (rédaction)
--
-- POURQUOI. Le titre de périodique entre dans la machinerie existante plutôt
-- que d'en avoir une nouvelle : même file de propositions, même délibération,
-- même journal de fusion.
--
-- ⚠️ LE PIÈGE QUE CE PAQUET DÉSAMORCE. Élargir le seul CHECK
-- authority_proposals_target_kind_check à 'serial' aurait créé un chemin MORT,
-- et pire : un chemin mort SILENCIEUX. api.fn_authority_apply enchaîne
--     if target_kind = 'author' … elsif target_kind = 'subject' …
-- SANS branche else. Une proposition de fusion de revue serait donc passée en
-- status='applied', aurait émis la notification « fusion exécutée » aux
-- bibliothèques utilisatrices… sans avoir fusionné quoi que ce soit. Personne
-- n'aurait vu d'erreur. C'est le même défaut que l'allowlist de la file de
-- notifications (un type accepté d'un côté, refusé de l'autre, avalé en
-- WARNING) : ce qui coûte cher n'est pas la panne, c'est son invisibilité.
--
-- Un target_kind ne s'ajoute donc pas à un endroit mais à QUATRE, ensemble :
--   1. le CHECK de public.authority_proposals ;
--   2. api.fn_authority_propose  — sinon on ne peut rien déposer ;
--   3. api.fn_authority_apply    — sinon on applique du vide (ci-dessus) ;
--   4. api.fn_authority_list     — sinon la proposition s'affiche sans nom.
--
-- LE RESTE DU PAQUET :
--   5. public.merge_serial — sur le modèle de merge_subject, plus la garde G5 ;
--   6. public.serial_not_duplicate + mark / unmark / list, symétriques de
--      author_not_duplicate ;
--   7. public.suggest_serial_duplicates — la détection d'autorités.
--
-- ÉCART ASSUMÉ AVEC LA SPEC §5. Elle demande que « suggest_authority_duplicates
-- couvre les titres de revues ». Vérification faite, cette fonction a une
-- signature de retour ENTIÈREMENT auteur (author_id_a, nom_a, tri_a, oeuvres_a,
-- …) : y verser des revues obligerait soit à mentir sur les noms de colonnes,
-- soit à casser la signature et donc l'écran de l'Atelier. On implémente
-- l'INTENTION — « deux serials de titre proche SONT de vrais doublons
-- candidats, contrairement à leurs fascicules » — dans une fonction sœur,
-- suggest_serial_duplicates, de même forme et de mêmes niveaux de preuve.
--
-- ALIGNEMENT FICEDL : hors périmètre, comme le dit la spec. Le thésaurus FICEDL
-- indexe des matières, pas des titres. Ne pas forcer l'analogie.
--
-- CHECKLIST DOCTRINE
--   [x] Table public : GRANT explicites, ENABLE RLS, policy nommée
--   [x] SECURITY DEFINER : search_path épinglé, REVOKE PUBLIC/anon, GRANT ciblé
--   [x] DROP sans CASCADE (le CHECK est remplacé, pas supprimé en cascade)
--   [x] DO block de vérification en fin de transaction
-- =========================================================================

BEGIN;

-- -------------------------------------------------------------------------
-- 1. Le CHECK
-- -------------------------------------------------------------------------
ALTER TABLE public.authority_proposals
  DROP CONSTRAINT IF EXISTS authority_proposals_target_kind_check;
ALTER TABLE public.authority_proposals
  ADD CONSTRAINT authority_proposals_target_kind_check
  CHECK (target_kind = ANY (ARRAY['author'::text, 'subject'::text, 'serial'::text]));

-- LE MÊME PIÈGE, UNE COUCHE PLUS BAS. merge_log.entity_type porte lui aussi un
-- CHECK fermé ('author','book','book_draft','subject'). Sans cette ligne,
-- merge_serial lèverait au moment de journaliser — après avoir déjà repointé
-- les fascicules et fusionné les états de collection. La transaction serait
-- annulée, donc rien de cassé, mais la fusion serait IMPOSSIBLE et l'échec
-- incompréhensible (l'erreur parle de merge_log, pas de périodiques).
-- Trouvé par la suite d'acceptation, pas à la lecture : c'est ce qui la
-- justifie.
ALTER TABLE public.merge_log
  DROP CONSTRAINT IF EXISTS merge_log_entity_type_check;
ALTER TABLE public.merge_log
  ADD CONSTRAINT merge_log_entity_type_check
  CHECK (entity_type = ANY (ARRAY['author'::text, 'book'::text, 'book_draft'::text,
                                  'subject'::text, 'serial'::text]));

COMMENT ON COLUMN public.merge_log.entity_type IS
  'author / book / book_draft / subject / serial. Élargi aux titres de '
  'périodiques par le paquet PÉRIODIQUES P5 du 27/08/2026. Toute nouvelle '
  'famille d''autorité fusionnable doit être ajoutée ICI EN MÊME TEMPS que sa '
  'fonction merge_* : sinon la fusion échoue au dernier geste, sur un message '
  'qui ne parle pas d''elle.';

COMMENT ON COLUMN public.authority_proposals.target_kind IS
  'author / subject / serial. Élargi aux titres de périodiques par le paquet '
  'PÉRIODIQUES P5 du 27/08/2026 — en même temps que fn_authority_propose, '
  'fn_authority_apply et fn_authority_list, qui doivent TOUJOURS être élargies '
  'ensemble : fn_authority_apply n''a pas de branche else et marquerait une '
  'proposition « appliquée » sans rien faire.';

-- -------------------------------------------------------------------------
-- 2. Table « pas un doublon » pour les titres
-- -------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.serial_not_duplicate (
  serial_id_a bigint NOT NULL REFERENCES public.serials(id) ON DELETE CASCADE,
  serial_id_b bigint NOT NULL REFERENCES public.serials(id) ON DELETE CASCADE,
  reason      text,
  created_by  uuid,
  created_at  timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (serial_id_a, serial_id_b),
  CONSTRAINT serial_not_duplicate_ordered CHECK (serial_id_a < serial_id_b)
);

COMMENT ON TABLE public.serial_not_duplicate IS
  'Paires de titres de périodiques arbitrées « ce ne sont pas des doublons ». '
  'La contrainte serial_id_a < serial_id_b évite la paire enregistrée deux fois '
  'dans les deux sens — les fonctions normalisent avec least/greatest. '
  'Réversible dès l''origine (unmark_serials_not_duplicate) : l''irréversibilité '
  'de book_not_duplicate a été un défaut, on ne le reproduit pas. '
  'Créée par le paquet PÉRIODIQUES P5 du 27/08/2026.';
COMMENT ON COLUMN public.serial_not_duplicate.reason IS
  'Motif facultatif, pour que la décision reste lisible six mois plus tard '
  '(« deux revues homonymes », « supports distincts d''un même ISSN-L »…).';

-- REVOKE d'abord (ALTER DEFAULT PRIVILEGES de Supabase, cf. P1) : sans lui,
-- anon lirait les arbitrages et n'importe quel compte pourrait en poser.
REVOKE ALL ON public.serial_not_duplicate FROM anon, authenticated;
GRANT SELECT ON public.serial_not_duplicate TO authenticated;
GRANT ALL    ON public.serial_not_duplicate TO service_role;

ALTER TABLE public.serial_not_duplicate ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS serial_not_duplicate_staff_select ON public.serial_not_duplicate;
CREATE POLICY serial_not_duplicate_staff_select
  ON public.serial_not_duplicate FOR SELECT
  TO authenticated
  USING (public.fn_caller_is_staff());

-- -------------------------------------------------------------------------
-- 3. Écarter / rétablir une paire de titres
-- -------------------------------------------------------------------------
-- Les deux gardes sont IDENTIQUES à dessein : qui peut écarter peut rétablir.
-- Toute divergence entre elles créerait un cul-de-sac.
CREATE OR REPLACE FUNCTION public.mark_serials_not_duplicate(
  p_a      bigint,
  p_b      bigint,
  p_reason text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $function$
DECLARE v_lo bigint; v_hi bigint;
BEGIN
  IF NOT public.fn_caller_is_staff() THEN
    RAISE EXCEPTION 'Apenas bibliotecárias e coordenadoras podem editar o catálogo.'
      USING ERRCODE = '42501', HINT = 'error.catalog.discard.forbidden';
  END IF;
  IF p_a IS NULL OR p_b IS NULL OR p_a = p_b THEN
    RAISE EXCEPTION 'Par de periódicos inválido.'
      USING ERRCODE = 'P0001', HINT = 'error.serial.notDuplicate.invalidPair';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.serials WHERE id = p_a)
     OR NOT EXISTS (SELECT 1 FROM public.serials WHERE id = p_b) THEN
    RAISE EXCEPTION 'Periódico inexistente.'
      USING ERRCODE = 'P0002', HINT = 'error.serial.notDuplicate.invalidPair';
  END IF;

  v_lo := least(p_a, p_b);
  v_hi := greatest(p_a, p_b);

  INSERT INTO public.serial_not_duplicate (serial_id_a, serial_id_b, created_by, reason)
  VALUES (v_lo, v_hi, auth.uid(), nullif(btrim(coalesce(p_reason,'')), ''))
  ON CONFLICT (serial_id_a, serial_id_b) DO NOTHING;
END $function$;

REVOKE ALL ON FUNCTION public.mark_serials_not_duplicate(bigint, bigint, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_serials_not_duplicate(bigint, bigint, text) TO authenticated;

COMMENT ON FUNCTION public.mark_serials_not_duplicate(bigint, bigint, text) IS
  'Écarte une paire de titres de périodiques des détections, avec motif '
  'facultatif. Réversible par unmark_serials_not_duplicate. Staff de catalogage. '
  'Paquet PÉRIODIQUES P5.';

CREATE OR REPLACE FUNCTION public.unmark_serials_not_duplicate(
  p_a bigint,
  p_b bigint
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $function$
DECLARE v_lo bigint; v_hi bigint;
BEGIN
  -- Garde identique à mark_serials_not_duplicate.
  IF NOT public.fn_caller_is_staff() THEN
    RAISE EXCEPTION 'Apenas bibliotecárias e coordenadoras podem editar o catálogo.'
      USING ERRCODE = '42501', HINT = 'error.catalog.discard.forbidden';
  END IF;
  IF p_a IS NULL OR p_b IS NULL OR p_a = p_b THEN
    RAISE EXCEPTION 'Par de periódicos inválido.'
      USING ERRCODE = 'P0001', HINT = 'error.serial.notDuplicate.invalidPair';
  END IF;

  v_lo := least(p_a, p_b);
  v_hi := greatest(p_a, p_b);

  DELETE FROM public.serial_not_duplicate
   WHERE serial_id_a = v_lo AND serial_id_b = v_hi;
END $function$;

REVOKE ALL ON FUNCTION public.unmark_serials_not_duplicate(bigint, bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.unmark_serials_not_duplicate(bigint, bigint) TO authenticated;

COMMENT ON FUNCTION public.unmark_serials_not_duplicate(bigint, bigint) IS
  'Rétablit une paire de titres écartée : elle réapparaît dans les détections. '
  'Aucune autorité n''est modifiée. Staff de catalogage. Paquet PÉRIODIQUES P5.';

CREATE OR REPLACE FUNCTION public.list_serials_not_duplicate(p_max integer DEFAULT 200)
RETURNS TABLE (
  serial_id_a     bigint,
  slug_a          text,
  titre_a         text,
  serial_id_b     bigint,
  slug_b          text,
  titre_b         text,
  reason          text,
  created_at      timestamptz,
  created_by_name text
)
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path = public, pg_catalog
AS $function$
BEGIN
  IF NOT public.fn_caller_is_staff() THEN
    RAISE EXCEPTION 'Acesso restrito ao staff de catalogacao.'
      USING ERRCODE = '42501', HINT = 'error.catalog.discard.forbidden';
  END IF;
  RETURN QUERY
  SELECT nd.serial_id_a, sa.slug, sa.uniform_title,
         nd.serial_id_b, sb.slug, sb.uniform_title,
         nd.reason, nd.created_at,
         (SELECT nullif(btrim(coalesce(pr.first_name,'')||' '||coalesce(pr.last_name,'')),'')
            FROM public.profiles pr WHERE pr.id = nd.created_by)
  FROM public.serial_not_duplicate nd
  JOIN public.serials sa ON sa.id = nd.serial_id_a
  JOIN public.serials sb ON sb.id = nd.serial_id_b
  ORDER BY nd.created_at DESC
  LIMIT greatest(coalesce(p_max, 200), 1);
END $function$;

REVOKE ALL ON FUNCTION public.list_serials_not_duplicate(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_serials_not_duplicate(integer) TO authenticated;

COMMENT ON FUNCTION public.list_serials_not_duplicate(integer) IS
  'Paires de titres écartées, avec titres, motif, date et personne ayant '
  'arbitré — la table ne stocke que des identifiants, sans cette fonction '
  'l''interface n''afficherait qu''une liste de nombres, donc une décision '
  'illisible, donc incontestable. Staff de catalogage. Paquet PÉRIODIQUES P5.';

-- -------------------------------------------------------------------------
-- 4. Détection de doublons d'AUTORITÉS de périodiques
-- -------------------------------------------------------------------------
-- Symétrique inverse de P3 : deux FASCICULES de désignations différentes ne
-- sont pas des doublons, mais deux TITRES proches en sont de vrais candidats.
CREATE OR REPLACE FUNCTION public.suggest_serial_duplicates(p_max integer DEFAULT 500)
RETURNS TABLE (
  serial_id_a   bigint,
  slug_a        text,
  titre_a       text,
  issn_a        text,
  fascicules_a  integer,
  serial_id_b   bigint,
  slug_b        text,
  titre_b       text,
  issn_b        text,
  fascicules_b  integer,
  match_kind    text,
  score         real,
  niveau_preuve text,
  rang_preuve   integer
)
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_catalog'
AS $function$
BEGIN
  IF NOT public.fn_caller_is_staff() THEN
    RAISE EXCEPTION 'Acesso restrito ao staff de catalogacao.'
      USING ERRCODE = '42501', HINT = 'error.catalog.discard.forbidden';
  END IF;

  PERFORM set_config('pg_trgm.similarity_threshold', '0.3', true);

  RETURN QUERY
  WITH paires AS (
    SELECT a.id AS ida, b.id AS idb,
           a.slug AS sa, b.slug AS sb,
           a.uniform_title AS ta, b.uniform_title AS tb,
           public.fn_normalize_name(a.uniform_title) AS na,
           public.fn_normalize_name(b.uniform_title) AS nb,
           nullif(regexp_replace(coalesce(a.issn,''), '\D', '', 'g'), '') AS ia,
           nullif(regexp_replace(coalesce(b.issn,''), '\D', '', 'g'), '') AS ib,
           nullif(regexp_replace(coalesce(a.issn_l,''), '\D', '', 'g'), '') AS la,
           nullif(regexp_replace(coalesce(b.issn_l,''), '\D', '', 'g'), '') AS lb
    FROM public.serials a
    JOIN public.serials b
      ON b.id > a.id
     AND (b.uniform_title % a.uniform_title
          OR (nullif(regexp_replace(coalesce(a.issn,''), '\D', '', 'g'), '')
              = nullif(regexp_replace(coalesce(b.issn,''), '\D', '', 'g'), '')))
    WHERE a.status <> 'depreciado' AND b.status <> 'depreciado'
  ), evaluees AS (
    SELECT p.*,
           similarity(p.na, p.nb)::real AS sc,
           (p.ia IS NOT NULL AND p.ia = p.ib) AS meme_issn,
           -- L'ISSN de liaison relie les SUPPORTS d'un même titre (papier /
           -- en ligne). Deux fiches qui le partagent décrivent la même revue :
           -- c'est une preuve forte, mais moins forte que l'ISSN lui-même —
           -- deux supports peuvent légitimement mériter deux fiches.
           (p.la IS NOT NULL AND p.la = p.lb) AS meme_issn_l,
           (p.na = p.nb) AS titre_exact
    FROM paires p
    WHERE NOT EXISTS (
      SELECT 1 FROM public.serial_not_duplicate nd
       WHERE nd.serial_id_a = p.ida AND nd.serial_id_b = p.idb)
  )
  SELECT e.ida, e.sa, e.ta, (SELECT s.issn FROM public.serials s WHERE s.id = e.ida),
         (SELECT count(*)::integer FROM public.books bk WHERE bk.serial_id = e.ida),
         e.idb, e.sb, e.tb, (SELECT s.issn FROM public.serials s WHERE s.id = e.idb),
         (SELECT count(*)::integer FROM public.books bk WHERE bk.serial_id = e.idb),
         CASE WHEN e.meme_issn THEN 'issn'
              WHEN e.titre_exact THEN 'exact'
              ELSE 'approx' END,
         CASE WHEN e.meme_issn THEN 1.0::real ELSE e.sc END,
         CASE WHEN e.meme_issn   THEN 'issn'
              WHEN e.titre_exact THEN 'titre_exact'
              WHEN e.meme_issn_l THEN 'issn_de_liaison'
              ELSE 'titre_proche' END,
         (CASE WHEN e.meme_issn   THEN 1
               WHEN e.titre_exact THEN 2
               WHEN e.meme_issn_l THEN 3
               ELSE 4 END)::integer
  FROM evaluees e
  WHERE e.meme_issn OR e.titre_exact OR e.meme_issn_l OR e.sc >= 0.45
  ORDER BY (CASE WHEN e.meme_issn   THEN 1
                 WHEN e.titre_exact THEN 2
                 WHEN e.meme_issn_l THEN 3
                 ELSE 4 END),
           CASE WHEN e.meme_issn THEN 1.0::real ELSE e.sc END DESC,
           e.ta
  LIMIT greatest(coalesce(p_max, 500), 1);
END $function$;

REVOKE ALL ON FUNCTION public.suggest_serial_duplicates(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.suggest_serial_duplicates(integer) TO authenticated;

COMMENT ON FUNCTION public.suggest_serial_duplicates(integer) IS
  'Doublons candidats parmi les TITRES de périodiques, triés par niveau de '
  'preuve (issn > titre_exact > issn_de_liaison > titre_proche). Fonction sœur '
  'de suggest_authority_duplicates, séparée parce que la signature de retour de '
  'celle-ci est entièrement auteur (nom, tri, oeuvres) : y verser des revues '
  'obligerait à mentir sur les colonnes ou à casser l''écran de l''Atelier. '
  'Staff de catalogage. Paquet PÉRIODIQUES P5.';

-- -------------------------------------------------------------------------
-- 5. La fusion
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.merge_serial(
  p_canonical_id bigint,
  p_duplicate_id bigint
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $function$
DECLARE
  v_dup      public.serials;
  v_can      public.serials;
  v_marque   text;
  v_locale   text;
  v_lib      uuid;
  v_fusion   integer := 0;
BEGIN
  IF NOT public.fn_caller_is_staff() THEN
    RAISE EXCEPTION 'Acesso restrito ao staff de catalogacao.'
      USING ERRCODE = '42501', HINT = 'error.serial.forbidden';
  END IF;
  IF p_canonical_id = p_duplicate_id THEN
    RAISE EXCEPTION 'Canonico e duplicado identicos.'
      USING ERRCODE = 'P0001', HINT = 'error.serial.merge.samePair';
  END IF;

  SELECT * INTO v_dup FROM public.serials WHERE id = p_duplicate_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Duplicado % inexistente.', p_duplicate_id
      USING ERRCODE = 'no_data_found', HINT = 'error.serial.notFound';
  END IF;
  SELECT * INTO v_can FROM public.serials WHERE id = p_canonical_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Canonico % inexistente.', p_canonical_id
      USING ERRCODE = 'no_data_found', HINT = 'error.serial.notFound';
  END IF;

  v_marque := ' [fusão: ' || v_dup.slug || ', ' || to_char(now(), 'DD/MM/YYYY') || ']';

  -- 5.1 Les fascicules changent de titre.
  UPDATE public.books SET serial_id = p_canonical_id WHERE serial_id = p_duplicate_id;

  -- 5.2 GARDE G5 — fusionner les états de collection, PAS les écraser.
  -- Deux titres fusionnés peuvent chacun porter un statement rédigé à la main,
  -- par deux bibliothèques ou par la même à deux époques. Écraser en perdrait
  -- un sans trace. On concatène avec une marque, et la coordination tranche.
  UPDATE public.serial_holdings can
     SET statement = CASE
           WHEN dup.statement IS NULL THEN can.statement
           WHEN can.statement IS NULL THEN dup.statement || v_marque
           WHEN btrim(can.statement) = btrim(dup.statement) THEN can.statement
           ELSE can.statement || E'\n' || dup.statement || v_marque
         END,
         gaps_note = CASE
           WHEN dup.gaps_note IS NULL THEN can.gaps_note
           WHEN can.gaps_note IS NULL THEN dup.gaps_note || v_marque
           WHEN btrim(can.gaps_note) = btrim(dup.gaps_note) THEN can.gaps_note
           ELSE can.gaps_note || E'\n' || dup.gaps_note || v_marque
         END,
         -- Le niveau le plus prudent l'emporte quand le canonique n'a rien dit.
         completeness = CASE WHEN can.completeness = 'desconhecida'
                             THEN dup.completeness ELSE can.completeness END,
         -- ET, pas OU : publier ce qu'une bibliothèque avait choisi de ne pas
         -- publier est la direction qui fait du tort. Elle republiera si elle
         -- le veut.
         is_public = (can.is_public AND dup.is_public),
         updated_by = auth.uid()
    FROM public.serial_holdings dup
   WHERE dup.serial_id = p_duplicate_id
     AND can.serial_id = p_canonical_id
     AND can.library_id = dup.library_id;

  GET DIAGNOSTICS v_fusion = ROW_COUNT;

  -- Les états de collection du doublon sans équivalent chez le canonique
  -- changent simplement de titre.
  UPDATE public.serial_holdings
     SET serial_id = p_canonical_id
   WHERE serial_id = p_duplicate_id
     AND library_id NOT IN (SELECT library_id FROM public.serial_holdings
                             WHERE serial_id = p_canonical_id);

  -- 5.3 Filiation : ce qui pointait vers le doublon pointe vers le canonique.
  -- Sans cela, le ON DELETE SET NULL de la clé étrangère effacerait
  -- silencieusement des maillons de filiation à l'étape 5.7.
  UPDATE public.serials SET predecessor_id = p_canonical_id
   WHERE predecessor_id = p_duplicate_id AND id <> p_canonical_id;
  UPDATE public.serials SET successor_id = p_canonical_id
   WHERE successor_id = p_duplicate_id AND id <> p_canonical_id;
  -- Si le canonique avait le doublon pour voisin de filiation, il hérite du
  -- maillon suivant plutôt que de se pointer lui-même.
  UPDATE public.serials c
     SET predecessor_id = v_dup.predecessor_id
   WHERE c.id = p_canonical_id AND c.predecessor_id = p_duplicate_id;
  UPDATE public.serials c
     SET successor_id = v_dup.successor_id
   WHERE c.id = p_canonical_id AND c.successor_id = p_duplicate_id;

  -- 5.4 Arbitrages « pas un doublon » : les repointer, sans créer d'auto-paire.
  INSERT INTO public.serial_not_duplicate (serial_id_a, serial_id_b, reason, created_by, created_at)
  SELECT least(p_canonical_id, CASE WHEN nd.serial_id_a = p_duplicate_id THEN nd.serial_id_b ELSE nd.serial_id_a END),
         greatest(p_canonical_id, CASE WHEN nd.serial_id_a = p_duplicate_id THEN nd.serial_id_b ELSE nd.serial_id_a END),
         nd.reason, nd.created_by, nd.created_at
  FROM public.serial_not_duplicate nd
  WHERE p_duplicate_id IN (nd.serial_id_a, nd.serial_id_b)
    AND p_canonical_id <> (CASE WHEN nd.serial_id_a = p_duplicate_id THEN nd.serial_id_b ELSE nd.serial_id_a END)
  ON CONFLICT (serial_id_a, serial_id_b) DO NOTHING;

  -- 5.5 Métadonnées : compléter ce qui manque au canonique, sans jamais
  -- l'écraser (le `||` fait gagner l'opérande de droite, ici le canonique).
  -- ET SURTOUT : verser le titre du doublon dans les formes REJETÉES, pour que
  -- chercher l'ancienne forme continue de trouver le survivant. Sans ce geste,
  -- la prochaine personne qui catalogue ne trouve rien et recrée le doublon.
  v_locale := coalesce(nullif(btrim(coalesce(v_dup.language, '')), ''), 'und');

  UPDATE public.serials c
     SET alt_i18n     = v_dup.alt_i18n || c.alt_i18n,
         hidden_i18n  = jsonb_set(
                          v_dup.hidden_i18n || c.hidden_i18n,
                          ARRAY[v_locale],
                          coalesce(
                            (CASE WHEN jsonb_typeof((v_dup.hidden_i18n || c.hidden_i18n) -> v_locale) = 'array'
                                  THEN (v_dup.hidden_i18n || c.hidden_i18n) -> v_locale
                                  ELSE '[]'::jsonb END)
                            || to_jsonb(v_dup.uniform_title),
                            '[]'::jsonb),
                          true),
         issn         = coalesce(c.issn, v_dup.issn),
         issn_l       = coalesce(c.issn_l, v_dup.issn_l),
         publisher_id = coalesce(c.publisher_id, v_dup.publisher_id),
         emitter_org  = coalesce(c.emitter_org, v_dup.emitter_org),
         place_publication = coalesce(c.place_publication, v_dup.place_publication),
         country_code = coalesce(c.country_code, v_dup.country_code),
         language     = coalesce(c.language, v_dup.language),
         periodicidade= coalesce(c.periodicidade, v_dup.periodicidade),
         start_year   = coalesce(c.start_year, v_dup.start_year),
         end_year     = coalesce(c.end_year, v_dup.end_year),
         scope_note   = coalesce(c.scope_note, v_dup.scope_note),
         updated_at   = now(),
         updated_by   = auth.uid()
   WHERE c.id = p_canonical_id;

  -- 5.6 Journaliser AVANT de supprimer : après, v_dup n'existe plus qu'ici.
  INSERT INTO public.merge_log (entity_type, canonical_id, duplicate_id, details, merged_by)
  VALUES ('serial', p_canonical_id, p_duplicate_id,
          jsonb_build_object(
            'duplicate_slug',  v_dup.slug,
            'duplicate_title', v_dup.uniform_title,
            'duplicate_issn',  v_dup.issn,
            'holdings_fusionnes', v_fusion),
          auth.uid());

  -- 5.7 Supprimer le doublon (tout est repointé).
  DELETE FROM public.serials WHERE id = p_duplicate_id;

  -- 5.8 Recalculer l'état de collection du survivant, maintenant qu'il porte
  -- les fascicules des deux.
  FOR v_lib IN SELECT DISTINCT library_id FROM public.serial_holdings
                WHERE serial_id = p_canonical_id LOOP
    PERFORM public.fn_recompute_serial_holdings(p_canonical_id, v_lib);
  END LOOP;
END $function$;

REVOKE ALL ON FUNCTION public.merge_serial(bigint, bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.merge_serial(bigint, bigint) TO authenticated;

COMMENT ON FUNCTION public.merge_serial(bigint, bigint) IS
  'Fusionne deux titres de périodiques : repointe les fascicules, FUSIONNE les '
  'états de collection par bibliothèque (garde G5 — concaténation marquée, '
  'jamais écrasement), repointe la filiation et les arbitrages, verse le titre '
  'du doublon dans les formes rejetées du survivant (sinon la prochaine '
  'personne qui catalogue ne le trouve plus et le recrée), journalise dans '
  'merge_log puis supprime. Staff de catalogage. Paquet PÉRIODIQUES P5.';

-- -------------------------------------------------------------------------
-- 6. Atelier : proposer
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION api.fn_authority_propose(
  p_kind text, p_target_kind text, p_target_id bigint,
  p_merge_into_id bigint, p_payload jsonb, p_rationale text)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_catalog'
AS $function$
declare
  v_id       uuid;
  v_deadline timestamptz;
  v_part     jsonb;
  v_pref     text;
  v_sort     text;
  v_n        int;
  v_collision text;
begin
  if not (public.fn_caller_is_network_contributor() or public.fn_caller_is_staff()) then
    raise exception 'forbidden' using hint = 'atelier.error.notContributor';
  end if;
  if p_kind not in ('creation', 'edition', 'fusion', 'traduction', 'scission') then
    raise exception 'bad_kind';
  end if;
  -- AJOUT PÉRIODIQUES P5 : 'serial'.
  if p_target_kind not in ('author', 'subject', 'serial') then raise exception 'bad_target_kind'; end if;

  if p_kind = 'creation' then
    if p_target_id is not null then raise exception 'creation_has_target'; end if;
  else
    if p_target_id is null then raise exception 'missing_target'; end if;
    if p_target_kind = 'author'  and not exists (select 1 from public.authors  where id = p_target_id) then raise exception 'target_not_found'; end if;
    if p_target_kind = 'subject' and not exists (select 1 from public.subjects where id = p_target_id) then raise exception 'target_not_found'; end if;
    if p_target_kind = 'serial'  and not exists (select 1 from public.serials  where id = p_target_id) then raise exception 'target_not_found'; end if;
  end if;

  if p_kind = 'fusion' then
    if p_merge_into_id is null or p_merge_into_id = p_target_id then raise exception 'bad_merge_target'; end if;
    if p_target_kind = 'author'  and not exists (select 1 from public.authors  where id = p_merge_into_id) then raise exception 'canonical_not_found'; end if;
    if p_target_kind = 'subject' and not exists (select 1 from public.subjects where id = p_merge_into_id) then raise exception 'canonical_not_found'; end if;
    if p_target_kind = 'serial'  and not exists (select 1 from public.serials  where id = p_merge_into_id) then raise exception 'canonical_not_found'; end if;
  elsif p_merge_into_id is not null then
    raise exception 'merge_target_only_for_fusion';
  end if;

  -- ── Gardes propres à la scission ──────────────────────────────────
  if p_kind = 'scission' then
    -- Ni une matière NI UN TITRE DE REVUE ne se scindent par ce chemin : le
    -- repointage de fn_authority_split ne connaît que les liaisons de livres à
    -- auteurs. Un titre qui se scinde en deux (revue qui se divise) se traite
    -- par la filiation, pas par la scission d'autorité.
    if p_target_kind <> 'author' then
      raise exception 'scission_author_only' using hint = 'atelier.error.scissionAuthorOnly';
    end if;

    if jsonb_typeof(p_payload -> 'parts') <> 'array'
       or jsonb_array_length(p_payload -> 'parts') < 2 then
      raise exception 'scission_needs_two_parts' using hint = 'atelier.error.scissionParts';
    end if;

    for v_part in select * from jsonb_array_elements(p_payload -> 'parts') loop
      v_pref := btrim(coalesce(v_part ->> 'preferred_name', ''));
      v_sort := btrim(coalesce(v_part ->> 'sort_name', ''));
      if v_pref = '' or v_sort = '' then
        raise exception 'scission_part_incomplete' using hint = 'atelier.error.scissionPartIncomplete';
      end if;
      if coalesce(v_part ->> 'authority_type', 'person') not in ('person', 'collective', 'congress') then
        raise exception 'scission_bad_type' using hint = 'atelier.error.scissionBadType';
      end if;

      select a.sort_name into v_collision
        from public.authors a
       where a.sort_name = v_sort and a.id <> p_target_id
       limit 1;
      if v_collision is not null then
        raise exception 'scission_part_exists: %', v_collision
          using hint = 'atelier.error.scissionPartExists';
      end if;
    end loop;

    select count(distinct btrim(x ->> 'sort_name')) into v_n
      from jsonb_array_elements(p_payload -> 'parts') x;
    if v_n <> jsonb_array_length(p_payload -> 'parts') then
      raise exception 'scission_duplicate_parts' using hint = 'atelier.error.scissionDuplicateParts';
    end if;
  end if;

  v_deadline := now() + case when p_kind in ('fusion', 'scission')
                             then interval '14 days' else interval '7 days' end;

  insert into public.authority_proposals (kind, target_kind, target_id, merge_into_id, payload, rationale, deadline, proposed_by)
  values (p_kind, p_target_kind, p_target_id, p_merge_into_id,
          case
            when p_kind = 'scission'
              then coalesce(p_payload, '{}'::jsonb)
                   || jsonb_build_object('avant',
                        (select a.sort_name from public.authors a where a.id = p_target_id))
            else coalesce(p_payload, '{}'::jsonb)
          end,
          p_rationale, v_deadline, auth.uid())
  returning id into v_id;

  perform public.fn_authority_emit('authority.proposal_opened', jsonb_build_object(
    'proposal_id', v_id, 'kind', p_kind, 'target_kind', p_target_kind,
    'target_id', p_target_id, 'merge_into_id', p_merge_into_id, 'proposed_by', auth.uid()));
  return v_id;
end;
$function$;

COMMENT ON FUNCTION api.fn_authority_propose(text, text, bigint, bigint, jsonb, text) IS
  'Dépose une proposition à l''Atelier autorités. target_kind élargi à '
  '''serial'' par le paquet PÉRIODIQUES P5 du 27/08/2026. La SCISSION reste '
  'réservée aux auteurs : une revue qui se divise se décrit par la filiation '
  '(predecessor_id / successor_id), pas par une scission d''autorité.';

-- -------------------------------------------------------------------------
-- 7. Atelier : appliquer
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION api.fn_authority_apply(p_proposal_id uuid)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_catalog'
AS $function$
declare v_p public.authority_proposals; v_f jsonb;
begin
  if not public.fn_caller_is_staff() then
    raise exception 'forbidden' using hint = 'atelier.error.notStaff';
  end if;
  select * into v_p from public.authority_proposals where id = p_proposal_id for update;
  if not found then raise exception 'proposal_not_found'; end if;
  if v_p.status <> 'resolved_consent' then
    raise exception 'not_ready' using hint = 'atelier.error.notResolvedConsent';
  end if;

  if v_p.kind = 'fusion' then
    if v_p.target_kind = 'author'  then perform public.merge_author(v_p.merge_into_id, v_p.target_id);
    elsif v_p.target_kind = 'subject' then perform public.merge_subject(v_p.merge_into_id, v_p.target_id);
    -- AJOUT PÉRIODIQUES P5.
    elsif v_p.target_kind = 'serial' then perform public.merge_serial(v_p.merge_into_id, v_p.target_id);
    else
      -- AJOUT PÉRIODIQUES P5 : la branche qui manquait. Sans elle, un
      -- target_kind non prévu passait la proposition en « appliquée » et
      -- notifiait les bibliothèques d'une fusion qui n'avait pas eu lieu.
      raise exception 'apply_target_kind_not_implemented: %', v_p.target_kind
        using hint = 'atelier.error.applyKindDeferred';
    end if;

  elsif v_p.kind = 'scission' then
    perform public.fn_authority_split(v_p.target_id,
                                      v_p.payload -> 'parts',
                                      v_p.payload ->> 'avant');

  elsif v_p.kind = 'edition' then
    v_f := coalesce(v_p.payload -> 'fields', '{}'::jsonb);
    if v_p.target_kind = 'author' then
      update public.authors set
        preferred_name  = coalesce(v_f ->> 'preferred_name', preferred_name),
        sort_name       = coalesce(v_f ->> 'sort_name', sort_name),
        biography       = coalesce(v_f ->> 'biography', biography),
        birth_year      = coalesce((v_f ->> 'birth_year')::int, birth_year),
        death_year      = coalesce((v_f ->> 'death_year')::int, death_year),
        country         = coalesce(v_f ->> 'country', country),
        viaf_id         = coalesce(v_f ->> 'viaf_id', viaf_id),
        isni            = coalesce(v_f ->> 'isni', isni),
        wikidata_id     = coalesce(v_f ->> 'wikidata_id', wikidata_id),
        notes           = coalesce(v_f ->> 'notes', notes),
        structured_meta = coalesce(v_f -> 'structured_meta', structured_meta),
        variant_forms   = coalesce(v_f -> 'variant_forms', variant_forms),
        updated_at = now(), updated_by = auth.uid()
      where id = v_p.target_id;
    elsif v_p.target_kind = 'subject' then
      update public.subjects set
        label_i18n = coalesce(v_f -> 'label_i18n', label_i18n),
        scope_note = coalesce(v_f ->> 'scope_note', scope_note),
        parent_id  = coalesce((v_f ->> 'parent_id')::bigint, parent_id),
        updated_at = now(), updated_by = auth.uid()
      where id = v_p.target_id;
    -- AJOUT PÉRIODIQUES P5. On réutilise le helper du paquet P2 plutôt que de
    -- réécrire un UPDATE : l'édition passée par l'Atelier valide alors
    -- EXACTEMENT comme l'édition directe, y compris le refus des champs
    -- inconnus. Deux listes de champs à tenir à jour divergeraient.
    elsif v_p.target_kind = 'serial' then
      perform public.fn_serial_apply_payload(v_p.target_id, v_f);
    else
      raise exception 'apply_target_kind_not_implemented: %', v_p.target_kind
        using hint = 'atelier.error.applyKindDeferred';
    end if;

  else
    raise exception 'apply_kind_not_implemented' using hint = 'atelier.error.applyKindDeferred';
  end if;

  update public.authority_proposals set status = 'applied', applied_at = now(), updated_at = now()
   where id = p_proposal_id;

  -- Notification aux bibliothèques utilisatrices.
  --
  -- LA SCISSION RÉUTILISE `authority.edit_applied` PLUTÔT QUE D'INVENTER
  -- UN ÉVÉNEMENT. Ce n'est pas de la paresse : un `authority.split_executed`
  -- neuf devrait être ajouté au routage de la fonction Edge `notify-event`
  -- ET à ses libellés de courriel dans les dix langues. Un seul de ces
  -- endroits oublié, et la notification part dans le vide sans erreur —
  -- une notification morte est invisible, c'est ce qui la rend coûteuse.
  -- `edit_applied` résout déjà `target_id` sur la fiche d'origine, qui est
  -- exactement celle que les bibliothèques utilisaient. Le libellé
  -- sous-décrit l'événement ; c'est un défaut visible, préférable à un
  -- silence invisible. Le même raisonnement vaut pour les périodiques :
  -- ils réutilisent merge_executed / edit_applied.
  if v_p.kind = 'fusion' then
    perform public.fn_authority_emit('authority.merge_executed', jsonb_build_object(
      'proposal_id', v_p.id, 'kind', v_p.kind, 'target_kind', v_p.target_kind,
      'target_id', v_p.target_id, 'merge_into_id', v_p.merge_into_id, 'proposed_by', v_p.proposed_by));
  else
    perform public.fn_authority_emit('authority.edit_applied', jsonb_build_object(
      'proposal_id', v_p.id, 'kind', v_p.kind, 'target_kind', v_p.target_kind,
      'target_id', v_p.target_id, 'proposed_by', v_p.proposed_by));
  end if;
  return 'applied';
end;
$function$;

COMMENT ON FUNCTION api.fn_authority_apply(uuid) IS
  'Applique une proposition résolue par consentement. Couvre author, subject et '
  '— depuis le paquet PÉRIODIQUES P5 du 27/08/2026 — serial. Les branches else '
  'ajoutées LÈVENT désormais au lieu de marquer « appliquée » une proposition '
  'qu''elles ne savent pas exécuter : un échec bruyant vaut mieux qu''une '
  'notification de fusion pour une fusion qui n''a pas eu lieu.';

-- -------------------------------------------------------------------------
-- 8. Atelier : lister
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION api.fn_authority_list()
RETURNS TABLE(id uuid, kind text, target_kind text, target_id bigint, target_label text,
              merge_into_id bigint, merge_into_label text, status text,
              deadline timestamptz, rationale text, proposed_by uuid, proposer_name text,
              objection_count integer, created_at timestamptz)
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_catalog'
AS $function$
BEGIN
  IF NOT (public.fn_caller_is_network_contributor() OR public.fn_caller_is_staff() OR public.fn_caller_is_network_admin()) THEN
    RETURN;  -- non-participant : liste vide
  END IF;
  RETURN QUERY
  SELECT p.id, p.kind, p.target_kind, p.target_id,
    CASE p.target_kind
      WHEN 'author'  THEN (SELECT a.preferred_name FROM public.authors a WHERE a.id = p.target_id)
      WHEN 'subject' THEN (SELECT coalesce(s.label_i18n->>'pt-BR', s.slug) FROM public.subjects s WHERE s.id = p.target_id)
      -- AJOUT PÉRIODIQUES P5 : sans cette ligne, une proposition de revue
      -- s'affiche sans nom dans l'Atelier — donc indélibérable.
      WHEN 'serial'  THEN (SELECT coalesce(se.uniform_title, se.slug) FROM public.serials se WHERE se.id = p.target_id)
    END,
    p.merge_into_id,
    CASE WHEN p.merge_into_id IS NULL THEN NULL
      WHEN p.target_kind='author'  THEN (SELECT a.preferred_name FROM public.authors a WHERE a.id = p.merge_into_id)
      WHEN p.target_kind='subject' THEN (SELECT coalesce(s.label_i18n->>'pt-BR', s.slug) FROM public.subjects s WHERE s.id = p.merge_into_id)
      WHEN p.target_kind='serial'  THEN (SELECT coalesce(se.uniform_title, se.slug) FROM public.serials se WHERE se.id = p.merge_into_id)
    END,
    p.status, p.deadline, p.rationale, p.proposed_by,
    (SELECT nullif(btrim(coalesce(pr.first_name,'')||' '||coalesce(pr.last_name,'')),'') FROM public.profiles pr WHERE pr.id = p.proposed_by),
    (SELECT count(*)::integer FROM public.authority_proposal_objections o WHERE o.proposal_id = p.id),
    p.created_at
  FROM public.authority_proposals p
  ORDER BY p.created_at DESC;
END;
$function$;

COMMENT ON FUNCTION api.fn_authority_list() IS
  'File de l''Atelier autorités, avec les libellés résolus par target_kind — '
  'author, subject et serial depuis le paquet PÉRIODIQUES P5 du 27/08/2026.';

-- -------------------------------------------------------------------------
-- 9. Vérification automatique
-- -------------------------------------------------------------------------
-- Vérification STRUCTURELLE — et c'est ici qu'elle compte le plus : le défaut
-- que ce paquet désamorce est un défaut de STRUCTURE (une branche manquante),
-- pas de calcul. La fusion elle-même (garde G5, formes rejetées, filiation) est
-- couverte par tests/sql/periodiques_tests.sql, qui tourne après le seed.
DO $verif$
DECLARE
  v_apply   text;
  v_propose text;
  v_list    text;
BEGIN
  -- 1. Le CHECK accepte 'serial'.
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
     WHERE conrelid = 'public.authority_proposals'::regclass
       AND conname = 'authority_proposals_target_kind_check'
       AND pg_get_constraintdef(oid) LIKE '%serial%') THEN
    RAISE EXCEPTION 'P5 : le CHECK target_kind n''accepte pas ''serial''.';
  END IF;

  -- 1 bis. Et le CHECK de merge_log, sans quoi la fusion échoue à son dernier
  -- geste sur une erreur qui ne parle pas de périodiques.
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
     WHERE conrelid = 'public.merge_log'::regclass
       AND conname = 'merge_log_entity_type_check'
       AND pg_get_constraintdef(oid) LIKE '%serial%') THEN
    RAISE EXCEPTION 'P5 : merge_log.entity_type n''accepte pas ''serial'' — merge_serial ne pourra pas journaliser.';
  END IF;

  v_apply   := pg_get_functiondef('api.fn_authority_apply(uuid)'::regprocedure);
  v_propose := pg_get_functiondef('api.fn_authority_propose(text,text,bigint,bigint,jsonb,text)'::regprocedure);
  v_list    := pg_get_functiondef('api.fn_authority_list()'::regprocedure);

  -- 2. LES QUATRE ENDROITS. Un target_kind admis par le CHECK mais ignoré par
  --    l'une des trois fonctions produit un chemin mort : la proposition passe
  --    en « appliquée », la notification part, et rien n'a eu lieu. C'est
  --    précisément ce que cette assertion empêche de revenir.
  IF v_propose NOT LIKE '%''author'', ''subject'', ''serial''%' THEN
    RAISE EXCEPTION 'P5 : fn_authority_propose n''accepte pas target_kind = serial.';
  END IF;
  IF v_apply NOT LIKE '%merge_serial%' THEN
    RAISE EXCEPTION 'P5 : fn_authority_apply ne sait pas fusionner deux revues.';
  END IF;
  IF v_apply NOT LIKE '%fn_serial_apply_payload%' THEN
    RAISE EXCEPTION 'P5 : fn_authority_apply ne sait pas éditer une revue.';
  END IF;
  IF v_list NOT LIKE '%public.serials se%' THEN
    RAISE EXCEPTION 'P5 : fn_authority_list ne résout pas le libellé des revues (proposition sans nom = indélibérable).';
  END IF;

  -- 3. LA BRANCHE ELSE. Sans elle, un target_kind futur non prévu retomberait
  --    dans le silence : proposition marquée appliquée, bibliothèques
  --    notifiées d'une fusion qui n'a pas eu lieu.
  IF v_apply NOT LIKE '%apply_target_kind_not_implemented%' THEN
    RAISE EXCEPTION 'P5 : fn_authority_apply n''a pas de branche else — le chemin mort silencieux subsiste.';
  END IF;

  -- 4. La scission reste réservée aux auteurs : fn_authority_split ne connaît
  --    que les liaisons de livres à auteurs.
  IF v_propose NOT LIKE '%scission_author_only%' THEN
    RAISE EXCEPTION 'P5 : la garde « scission réservée aux auteurs » a disparu.';
  END IF;

  -- 5. serial_not_duplicate : RLS active, aucune écriture directe, et le geste
  --    est réversible dès l'origine (l'irréversibilité de book_not_duplicate a
  --    été un défaut, on ne le reproduit pas).
  IF NOT (SELECT relrowsecurity FROM pg_class WHERE oid = 'public.serial_not_duplicate'::regclass) THEN
    RAISE EXCEPTION 'public.serial_not_duplicate : RLS non activée.';
  END IF;
  IF has_table_privilege('authenticated', 'public.serial_not_duplicate', 'INSERT')
     OR has_table_privilege('anon', 'public.serial_not_duplicate', 'SELECT') THEN
    RAISE EXCEPTION 'public.serial_not_duplicate : droits inattendus.';
  END IF;
  IF to_regprocedure('public.unmark_serials_not_duplicate(bigint,bigint)') IS NULL THEN
    RAISE EXCEPTION 'P5 : écarter une paire de titres serait irréversible.';
  END IF;

  -- 6. merge_serial applique bien la garde G5 (concaténation, pas écrasement).
  IF pg_get_functiondef('public.merge_serial(bigint,bigint)'::regprocedure)
     NOT LIKE '%fusão:%' THEN
    RAISE EXCEPTION 'G5 : merge_serial ne marque pas la concaténation des états de collection.';
  END IF;

  RAISE NOTICE 'Paquet PÉRIODIQUES P5 : vérifications structurelles OK (CHECK + 3 fonctions + branche else, scission bornée, arbitrage réversible, G5).';
END $verif$;

COMMIT;

NOTIFY pgrst, 'reload schema';

-- =========================================================================
-- Rollback ciblé :
-- =========================================================================
-- BEGIN;
--   -- Réappliquer les corps de fn_authority_propose / fn_authority_apply /
--   -- fn_authority_list du 21/08/2026 (20260821210000_conventions_17_scission_autorite.sql
--   -- et les migrations Atelier antérieures), PUIS :
--   ALTER TABLE public.authority_proposals DROP CONSTRAINT IF EXISTS authority_proposals_target_kind_check;
--   ALTER TABLE public.authority_proposals ADD CONSTRAINT authority_proposals_target_kind_check
--     CHECK (target_kind = ANY (ARRAY['author'::text, 'subject'::text]));
--   DROP FUNCTION IF EXISTS public.merge_serial(bigint, bigint);
--   DROP FUNCTION IF EXISTS public.suggest_serial_duplicates(integer);
--   DROP FUNCTION IF EXISTS public.list_serials_not_duplicate(integer);
--   DROP FUNCTION IF EXISTS public.unmark_serials_not_duplicate(bigint, bigint);
--   DROP FUNCTION IF EXISTS public.mark_serials_not_duplicate(bigint, bigint, text);
--   DROP TABLE IF EXISTS public.serial_not_duplicate;
-- COMMIT;
-- =========================================================================
