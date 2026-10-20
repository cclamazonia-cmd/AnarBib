-- =========================================================================
-- Un Wikidata, une seule fiche d'autorité
-- =========================================================================
-- Date     : 2026-10-20
-- Chantier : catalogage / autorités (suite du doublon Q51862284)
-- Auteur   : Xavier (+ Claude)
--
-- LE CAS. Q51862284 (José Luis Gutiérrez Molina) a été posé deux fois :
-- sur 10907 par l'enrichissement du 26/09, puis sur 11572 par une proposition
-- C4 de l'Atelier (bebb7a02, kind 'edition', appliquée le 18/10). Personne ne
-- regardait si l'identifiant était déjà pris : ni wd-rapprocher.mjs, ni
-- api.fn_authority_propose, ni api.fn_authority_apply, ni publish_author_draft,
-- et aucun index ne l'interdisait. Les deux fiches sont fusionnées par
-- 20261020174232 (décision de Xavier) ; celle-ci empêche la récidive.
--
-- CE QUI CHANGE
--   1. private.fn_autorite_wikidata_libre(qid, author_id) : refuse, message
--      clair, si le Wikidata est porté par une AUTRE fiche. Hint i18n
--      'error.catalog.wikidata_already_used' ; DETAIL en JSON {qid, author_id,
--      name} que localizeError passe à la traduction (le nom et le numéro de
--      l'autre fiche sont toute l'utilité du refus : on oriente vers la fusion).
--   2. Déclencheur BEFORE INSERT OR UPDATE OF wikidata_id sur public.authors :
--      normalise (btrim, majuscules, '' → NULL) et appelle la garde quand la
--      valeur change. Il couvre d'un coup les deux chemins visés —
--      publish_author_draft (INSERT et UPDATE) et fn_authority_apply (edition)
--      — et tout autre écrivain (private.fn_enrichir_autorites, migrations).
--      Pourquoi un déclencheur plutôt que deux gardes recopiées dans deux
--      fonctions : un troisième chemin d'écriture existe déjà
--      (fn_enrichir_autorites), un quatrième viendra ; une garde par fonction
--      en oublierait un, comme on a oublié celui-ci.
--   3. api.fn_authority_propose : la même garde DÈS la proposition (edition
--      d'une autorité qui porte wikidata_id), pour ne pas laisser courir sept
--      jours de consentement sur une proposition qui sera refusée à
--      l'application. Patch par remplacement de la définition réelle (ancre
--      comptée), pas de recopie : la fonction fait 5,6 ko.
--   4. public.merge_author_with_fields : reprendre wikidata_id du doublon
--      heurterait l'index tant que le doublon existe (il est supprimé APRÈS,
--      par merge_author) ; on libère d'abord la valeur sur le doublon.
--   5. Index unique partiel authors(wikidata_id) WHERE wikidata_id IS NOT NULL,
--      le plancher que rien ne contourne. Précédé d'un contrôle qui nomme les
--      doublons restants : s'il en reste, la migration s'arrête ici.
--
-- Rejouable : CREATE OR REPLACE, DROP TRIGGER IF EXISTS, CREATE INDEX IF NOT
-- EXISTS, patch de fn_authority_propose sauté s'il est déjà posé.
-- Suite : tests/sql/wikidata_une_seule_fiche_tests.sql.
-- =========================================================================

BEGIN;

-- ── 1. La garde ─────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION private.fn_autorite_wikidata_libre(p_qid text, p_author_id bigint)
RETURNS void
LANGUAGE plpgsql
STABLE
SET search_path TO 'public', 'pg_catalog'
AS $function$
DECLARE
  v_q     text := nullif(upper(btrim(p_qid)), '');
  v_id    bigint;
  v_nom   text;
BEGIN
  IF v_q IS NULL THEN
    RETURN;
  END IF;
  -- Les valeurs en base sont normalisées (déclencheur ci-dessous ; 713 sur 713
  -- au format ^Q[0-9]+$ le 20/10) : l'égalité simple emprunte l'index unique.
  SELECT a.id, a.preferred_name INTO v_id, v_nom
    FROM public.authors a
   WHERE a.wikidata_id = v_q
     AND a.id IS DISTINCT FROM p_author_id
   ORDER BY a.id
   LIMIT 1;
  IF v_id IS NOT NULL THEN
    -- Pas de « : » dans le message : l'Atelier recolle ce qui suit le premier
    -- deux-points à la traduction (messageDErreur), on le doublerait.
    RAISE EXCEPTION 'Wikidata % déjà porté par la fiche n° % (%) — fusionner les deux fiches plutôt que recopier l''identifiant', v_q, v_id, v_nom
      USING ERRCODE = 'P0001',
            HINT    = 'error.catalog.wikidata_already_used',
            DETAIL  = jsonb_build_object('qid', v_q, 'author_id', v_id, 'name', v_nom)::text;
  END IF;
END;
$function$;

REVOKE ALL ON FUNCTION private.fn_autorite_wikidata_libre(text, bigint) FROM PUBLIC, anon, authenticated;

COMMENT ON FUNCTION private.fn_autorite_wikidata_libre(text, bigint) IS
  'Refuse (hint error.catalog.wikidata_already_used, DETAIL {qid, author_id, name}) un Wikidata déjà porté par une autre fiche que p_author_id. 20/10/2026, cas Q51862284.';

-- ── 2. Le déclencheur ───────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION private.fn_authors_wikidata_une_fiche()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'public', 'pg_catalog'
AS $function$
BEGIN
  NEW.wikidata_id := nullif(upper(btrim(NEW.wikidata_id)), '');
  IF NEW.wikidata_id IS NOT NULL
     AND (TG_OP = 'INSERT' OR NEW.wikidata_id IS DISTINCT FROM OLD.wikidata_id) THEN
    PERFORM private.fn_autorite_wikidata_libre(NEW.wikidata_id, NEW.id);
  END IF;
  RETURN NEW;
END;
$function$;

-- Un déclencheur n'a besoin d'aucun grant pour se déclencher.
REVOKE ALL ON FUNCTION private.fn_authors_wikidata_une_fiche() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS trg_authors_wikidata_une_fiche ON public.authors;
CREATE TRIGGER trg_authors_wikidata_une_fiche
  BEFORE INSERT OR UPDATE OF wikidata_id ON public.authors
  FOR EACH ROW EXECUTE FUNCTION private.fn_authors_wikidata_une_fiche();

-- ── 3. Dès la proposition (Atelier) ─────────────────────────────────────
DO $$
DECLARE
  c_sig    constant regprocedure := 'api.fn_authority_propose(text, text, bigint, bigint, jsonb, text)'::regprocedure;
  c_ancre  constant text := '  -- ── Gardes propres à la scission';
  c_ajout  constant text :=
       '  -- 20/10/2026 (Q51862284) : un Wikidata déjà porté par une autre fiche est' || chr(10)
    || '  -- refusé dès la proposition, pas sept jours plus tard à l''application.' || chr(10)
    || '  if p_kind = ''edition'' and p_target_kind = ''author'' then' || chr(10)
    || '    perform private.fn_autorite_wikidata_libre(p_payload -> ''fields'' ->> ''wikidata_id'', p_target_id);' || chr(10)
    || '  end if;' || chr(10) || chr(10);
  v_def    text := pg_get_functiondef(c_sig);
  v_n      int;
BEGIN
  IF position('fn_autorite_wikidata_libre' in v_def) > 0 THEN
    RAISE NOTICE 'fn_authority_propose porte déjà la garde Wikidata.';
    RETURN;
  END IF;
  v_n := (length(v_def) - length(replace(v_def, c_ancre, ''))) / length(c_ancre);
  IF v_n <> 1 THEN
    RAISE EXCEPTION 'fn_authority_propose : ancre « Gardes propres à la scission » trouvée % fois (1 attendue).', v_n;
  END IF;
  EXECUTE replace(v_def, c_ancre, c_ajout || c_ancre);
END $$;

-- ── 4. Fusion avec reprise de champs ────────────────────────────────────
-- Définition réelle de la production (20/10/2026), plus le bloc wikidata_id.
CREATE OR REPLACE FUNCTION public.merge_author_with_fields(p_canonical_id bigint, p_duplicate_id bigint, p_fields text[] DEFAULT '{}'::text[])
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
DECLARE
  k_interdits text[] := public.fn_dedup_non_transferable_author_fields();
  v_champs    text[];
  v_inconnus  text[];
  v_refuses   text[];
  v_set       text;
  v_qid       text;
BEGIN
  IF NOT public.fn_is_dedup_arbiter() THEN
    RAISE EXCEPTION 'Arbitragem reservada à coordenação.'
      USING ERRCODE = '42501', HINT = 'error.catalog.arbiter_only';
  END IF;

  IF p_canonical_id IS NULL OR p_duplicate_id IS NULL OR p_canonical_id = p_duplicate_id THEN
    RAISE EXCEPTION 'Par de autoridades inválido.'
      USING ERRCODE = 'P0001', HINT = 'error.catalog.notDuplicate.invalidPair';
  END IF;

  SELECT coalesce(array_agg(DISTINCT c), '{}'::text[]) INTO v_champs
  FROM unnest(coalesce(p_fields, '{}'::text[])) c
  WHERE nullif(btrim(c), '') IS NOT NULL;

  IF array_length(v_champs, 1) IS NOT NULL THEN
    SELECT coalesce(array_agg(c), '{}'::text[]) INTO v_inconnus
    FROM unnest(v_champs) c
    WHERE NOT EXISTS (
      SELECT 1 FROM information_schema.columns
       WHERE table_schema = 'public' AND table_name = 'authors' AND column_name = c
    );
    IF array_length(v_inconnus, 1) IS NOT NULL THEN
      RAISE EXCEPTION 'Champ(s) inconnu(s) dans authors : %.', array_to_string(v_inconnus, ', ')
        USING ERRCODE = 'P0001', HINT = 'error.catalog.merge.unknown_field';
    END IF;

    SELECT coalesce(array_agg(c), '{}'::text[]) INTO v_refuses
    FROM unnest(v_champs) c WHERE c = ANY (k_interdits);
    IF array_length(v_refuses, 1) IS NOT NULL THEN
      RAISE EXCEPTION 'Champ(s) non reprenable(s) : %.', array_to_string(v_refuses, ', ')
        USING ERRCODE = 'P0001', HINT = 'error.catalog.merge.field_not_transferable';
    END IF;

    -- 20/10/2026 : wikidata_id est unique. Le doublon le porte encore jusqu'à
    -- merge_author ; on le lui retire d'abord, puis on le pose sur la fiche
    -- gardée, sinon la reprise se heurterait à l'index (et à la garde).
    IF 'wikidata_id' = ANY (v_champs) THEN
      SELECT wikidata_id INTO v_qid FROM public.authors WHERE id = p_duplicate_id;
      UPDATE public.authors SET wikidata_id = NULL WHERE id = p_duplicate_id;
      UPDATE public.authors SET wikidata_id = v_qid WHERE id = p_canonical_id;
      v_champs := array_remove(v_champs, 'wikidata_id');
    END IF;

    IF array_length(v_champs, 1) IS NOT NULL THEN
      SELECT string_agg(format('%I = d.%I', c, c), ', ') INTO v_set FROM unnest(v_champs) c;
      EXECUTE format(
        'UPDATE public.authors AS c SET %s FROM public.authors AS d WHERE c.id = $1 AND d.id = $2',
        v_set
      ) USING p_canonical_id, p_duplicate_id;
    END IF;
  END IF;

  -- Puis la fusion, inchangée. Une seule transaction : si merge_author refuse,
  -- la reprise est annulée avec elle.
  PERFORM public.merge_author(p_canonical_id, p_duplicate_id);
END;
$function$;

-- ── 5. L'index ──────────────────────────────────────────────────────────
DO $$
DECLARE
  v_reste text;
BEGIN
  SELECT string_agg(format('%s [%s]', q, ids), ', ' ORDER BY q) INTO v_reste
    FROM (SELECT upper(btrim(wikidata_id)) AS q, string_agg(id::text, ', ' ORDER BY id) AS ids
            FROM public.authors
           WHERE nullif(btrim(wikidata_id), '') IS NOT NULL
           GROUP BY 1 HAVING count(*) > 1) d;
  IF v_reste IS NOT NULL THEN
    RAISE EXCEPTION 'Wikidata portés par plusieurs fiches, à fusionner avant l''index : %', v_reste;
  END IF;
END $$;

-- Valeurs à la forme que pose le déclencheur (aucune ne diffère le 20/10).
UPDATE public.authors
   SET wikidata_id = nullif(upper(btrim(wikidata_id)), '')
 WHERE wikidata_id IS DISTINCT FROM nullif(upper(btrim(wikidata_id)), '');

CREATE UNIQUE INDEX IF NOT EXISTS authors_wikidata_id_unique
  ON public.authors (wikidata_id)
  WHERE wikidata_id IS NOT NULL;

-- Vérification
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_indexes
                  WHERE schemaname = 'public' AND indexname = 'authors_wikidata_id_unique') THEN
    RAISE EXCEPTION 'authors_wikidata_id_unique absent.';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_trigger
                  WHERE tgrelid = 'public.authors'::regclass
                    AND tgname = 'trg_authors_wikidata_une_fiche' AND NOT tgisinternal) THEN
    RAISE EXCEPTION 'trg_authors_wikidata_une_fiche absent.';
  END IF;
  IF position('fn_autorite_wikidata_libre' in
       pg_get_functiondef('api.fn_authority_propose(text, text, bigint, bigint, jsonb, text)'::regprocedure)) = 0 THEN
    RAISE EXCEPTION 'fn_authority_propose sans garde Wikidata.';
  END IF;
  IF has_function_privilege('authenticated', 'private.fn_autorite_wikidata_libre(text, bigint)', 'EXECUTE')
     OR has_function_privilege('anon', 'private.fn_autorite_wikidata_libre(text, bigint)', 'EXECUTE') THEN
    RAISE EXCEPTION 'fn_autorite_wikidata_libre ouverte à anon/authenticated.';
  END IF;
END $$;

COMMIT;
