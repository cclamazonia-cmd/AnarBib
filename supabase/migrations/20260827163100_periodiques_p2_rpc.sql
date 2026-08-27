-- =========================================================================
-- Paquet PÉRIODIQUES P2 — RPC de catalogage et surfaces de lecture
-- =========================================================================
-- Date     : 2026-08-27
-- Chantier : périodiques (spec-periodiques v0.1, §6)
-- Auteur   : Xavier (arbitrages) + Claude (rédaction)
--
-- POURQUOI. P1 a posé l'objet ; sans ces fonctions il n'est atteignable que
-- par SQL. Doctrine maison : écritures par RPC SECURITY DEFINER avec
-- search_path épinglé et contrôle de rôle, lectures par fonctions/vues api.*
-- en SECURITY INVOKER sous RLS.
--
-- POURQUOI UN PAYLOAD jsonb PLUTÔT QUE VINGT PARAMÈTRES. serials porte seize
-- colonnes descriptives. Une signature à seize paramètres nommés à défaut NULL
-- ne sait pas distinguer « ne touche pas » de « vide ce champ », et toute
-- évolution du modèle casse la signature (donc les appelants). Le payload dit
-- exactement l'inverse : une clé PRÉSENTE est écrite (y compris à null, ce qui
-- vide), une clé ABSENTE n'est pas touchée. Précédent maison :
-- api.fn_cartography_update_admin(p_entry_id, p_payload).
--
-- ET POURQUOI IL REFUSE LES CLÉS INCONNUES. Un payload permissif avale les
-- fautes de frappe en silence : le champ ne s'enregistre jamais et personne ne
-- le voit — c'est exactement le défaut vécu sur l'allowlist de la file de
-- notifications (un event_type accepté côté trigger, refusé côté CHECK, avalé
-- en WARNING). fn_serial_apply_payload lève donc sur toute clé hors liste.
--
-- CE QUI N'EST PAS ÉCRIVABLE PAR CE CHEMIN, et pourquoi :
--   * status            -> api.fn_serial_set_status, réservé à la coordination.
--                          Promouvoir est un geste, pas un effet de bord.
--   * predecessor_id /
--     successor_id      -> api.fn_serial_set_filiation, qui pose les deux côtés.
--   * slug              -> identité de l'objet et de son URL publique. Le
--                          changer casserait les liens déjà partagés.
--   * issue_key         -> colonne générée (garde G4).
--
-- CHECKLIST DOCTRINE (fonctions SECURITY DEFINER)
--   [x] SET search_path = public, pg_catalog
--   [x] REVOKE EXECUTE ... FROM PUBLIC, anon
--   [x] GRANT EXECUTE ... TO authenticated
--   [x] Garde de rôle interne (fn_caller_is_staff / fn_is_catalog_coordinator)
--   [x] Helper privé révoqué de PUBLIC, anon, authenticated, service_role
--   [x] Lectures en SECURITY INVOKER : la RLS de P1 fait le filtrage
--   [x] DO block de vérification en fin de transaction
-- =========================================================================

BEGIN;

-- -------------------------------------------------------------------------
-- 1. Helper privé — appliquer un payload descriptif
-- -------------------------------------------------------------------------
-- Partagé par fn_serial_create et fn_serial_update pour que les deux chemins
-- valident EXACTEMENT la même chose. Deux copies divergeraient en six mois.
CREATE OR REPLACE FUNCTION public.fn_serial_apply_payload(
  p_serial_id bigint,
  p_payload   jsonb
)
RETURNS public.serials
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $function$
DECLARE
  v_allowed constant text[] := ARRAY[
    'uniform_title','sort_title','title_nonfiling','alt_i18n','hidden_i18n',
    'issn','issn_l','publisher_id','emitter_org','place_publication',
    'country_code','language','periodicidade','start_year','end_year',
    'is_continuing','scope_note'
  ];
  v_unknown text[];
  r public.serials;
BEGIN
  IF p_payload IS NULL OR jsonb_typeof(p_payload) <> 'object' THEN
    RAISE EXCEPTION 'Payload de périodique invalide (objet JSON attendu).'
      USING ERRCODE = 'P0001', HINT = 'error.serial.payload.invalid';
  END IF;

  SELECT array_agg(k) INTO v_unknown
  FROM jsonb_object_keys(p_payload) AS k
  WHERE k <> ALL (v_allowed);

  IF v_unknown IS NOT NULL THEN
    RAISE EXCEPTION 'Champs de périodique inconnus : %.', array_to_string(v_unknown, ', ')
      USING ERRCODE = 'P0001', HINT = 'error.serial.payload.unknownField';
  END IF;

  -- uniform_title est NOT NULL : présent mais vide = refus explicite, pas un
  -- effacement silencieux qui laisserait une autorité sans nom.
  IF p_payload ? 'uniform_title'
     AND nullif(btrim(coalesce(p_payload->>'uniform_title','')), '') IS NULL THEN
    RAISE EXCEPTION 'Le titre retenu ne peut pas être vide.'
      USING ERRCODE = 'P0001', HINT = 'error.serial.title.required';
  END IF;

  IF p_payload ? 'alt_i18n' AND jsonb_typeof(p_payload->'alt_i18n') NOT IN ('object','null') THEN
    RAISE EXCEPTION 'alt_i18n doit être un objet par locale.'
      USING ERRCODE = 'P0001', HINT = 'error.serial.payload.invalid';
  END IF;
  IF p_payload ? 'hidden_i18n' AND jsonb_typeof(p_payload->'hidden_i18n') NOT IN ('object','null') THEN
    RAISE EXCEPTION 'hidden_i18n doit être un objet par locale.'
      USING ERRCODE = 'P0001', HINT = 'error.serial.payload.invalid';
  END IF;

  IF p_payload ? 'publisher_id'
     AND p_payload->>'publisher_id' IS NOT NULL
     AND NOT EXISTS (SELECT 1 FROM public.publishers pu
                      WHERE pu.id = (p_payload->>'publisher_id')::bigint) THEN
    RAISE EXCEPTION 'Éditeur inexistant : %.', p_payload->>'publisher_id'
      USING ERRCODE = 'P0002', HINT = 'error.serial.publisher.notFound';
  END IF;

  UPDATE public.serials s SET
    uniform_title     = CASE WHEN p_payload ? 'uniform_title'
                             THEN btrim(p_payload->>'uniform_title') ELSE s.uniform_title END,
    sort_title        = CASE WHEN p_payload ? 'sort_title'
                             THEN nullif(btrim(coalesce(p_payload->>'sort_title','')),'') ELSE s.sort_title END,
    title_nonfiling   = CASE WHEN p_payload ? 'title_nonfiling'
                             THEN coalesce((p_payload->>'title_nonfiling')::smallint, 0) ELSE s.title_nonfiling END,
    alt_i18n          = CASE WHEN p_payload ? 'alt_i18n'
                             THEN coalesce(nullif(p_payload->'alt_i18n','null'::jsonb), '{}'::jsonb) ELSE s.alt_i18n END,
    hidden_i18n       = CASE WHEN p_payload ? 'hidden_i18n'
                             THEN coalesce(nullif(p_payload->'hidden_i18n','null'::jsonb), '{}'::jsonb) ELSE s.hidden_i18n END,
    issn              = CASE WHEN p_payload ? 'issn'
                             THEN nullif(btrim(coalesce(p_payload->>'issn','')),'') ELSE s.issn END,
    issn_l            = CASE WHEN p_payload ? 'issn_l'
                             THEN nullif(btrim(coalesce(p_payload->>'issn_l','')),'') ELSE s.issn_l END,
    publisher_id      = CASE WHEN p_payload ? 'publisher_id'
                             THEN (p_payload->>'publisher_id')::bigint ELSE s.publisher_id END,
    emitter_org       = CASE WHEN p_payload ? 'emitter_org'
                             THEN nullif(btrim(coalesce(p_payload->>'emitter_org','')),'') ELSE s.emitter_org END,
    place_publication = CASE WHEN p_payload ? 'place_publication'
                             THEN nullif(btrim(coalesce(p_payload->>'place_publication','')),'') ELSE s.place_publication END,
    country_code      = CASE WHEN p_payload ? 'country_code'
                             THEN nullif(btrim(coalesce(p_payload->>'country_code','')),'') ELSE s.country_code END,
    language          = CASE WHEN p_payload ? 'language'
                             THEN nullif(btrim(coalesce(p_payload->>'language','')),'') ELSE s.language END,
    periodicidade     = CASE WHEN p_payload ? 'periodicidade'
                             THEN nullif(btrim(coalesce(p_payload->>'periodicidade','')),'') ELSE s.periodicidade END,
    start_year        = CASE WHEN p_payload ? 'start_year'
                             THEN nullif(btrim(coalesce(p_payload->>'start_year','')),'') ELSE s.start_year END,
    end_year          = CASE WHEN p_payload ? 'end_year'
                             THEN nullif(btrim(coalesce(p_payload->>'end_year','')),'') ELSE s.end_year END,
    is_continuing     = CASE WHEN p_payload ? 'is_continuing'
                             THEN coalesce((p_payload->>'is_continuing')::boolean, true) ELSE s.is_continuing END,
    scope_note        = CASE WHEN p_payload ? 'scope_note'
                             THEN nullif(btrim(coalesce(p_payload->>'scope_note','')),'') ELSE s.scope_note END,
    updated_by        = auth.uid(),
    updated_at        = now()
  WHERE s.id = p_serial_id
  RETURNING * INTO r;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Périodique introuvable : %.', p_serial_id
      USING ERRCODE = 'no_data_found', HINT = 'error.serial.notFound';
  END IF;

  RETURN r;
END $function$;

REVOKE ALL ON FUNCTION public.fn_serial_apply_payload(bigint, jsonb)
  FROM PUBLIC, anon, authenticated, service_role;

COMMENT ON FUNCTION public.fn_serial_apply_payload(bigint, jsonb) IS
  'Helper PRIVÉ (aucun GRANT) : applique un payload descriptif à un périodique '
  'et refuse toute clé hors liste blanche. Partagé par api.fn_serial_create et '
  'api.fn_serial_update pour que les deux chemins valident la même chose. '
  'N''effectue AUCUN contrôle de rôle — c''est à l''appelant de le faire.';

-- -------------------------------------------------------------------------
-- 2. Création d'un titre
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION api.fn_serial_create(
  p_uniform_title text,
  p_payload       jsonb DEFAULT '{}'::jsonb
)
RETURNS public.serials
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $function$
DECLARE
  v_id bigint;
  r    public.serials;
BEGIN
  IF NOT public.fn_caller_is_staff() THEN
    RAISE EXCEPTION 'Acesso restrito ao staff de catalogacao.'
      USING ERRCODE = 'insufficient_privilege', HINT = 'error.serial.forbidden';
  END IF;

  IF nullif(btrim(coalesce(p_uniform_title,'')), '') IS NULL THEN
    RAISE EXCEPTION 'Le titre retenu ne peut pas être vide.'
      USING ERRCODE = 'P0001', HINT = 'error.serial.title.required';
  END IF;

  -- status reste au défaut 'proposto' : aucune autorité ne naît validée, pas
  -- même celle créée à la volée pendant le catalogage.
  INSERT INTO public.serials (uniform_title, created_by, updated_by)
  VALUES (btrim(p_uniform_title), auth.uid(), auth.uid())
  RETURNING id INTO v_id;

  IF p_payload IS NOT NULL AND p_payload <> '{}'::jsonb THEN
    r := public.fn_serial_apply_payload(v_id, p_payload - 'uniform_title');
  ELSE
    SELECT * INTO r FROM public.serials WHERE id = v_id;
  END IF;

  RETURN r;
END $function$;

REVOKE ALL ON FUNCTION api.fn_serial_create(text, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION api.fn_serial_create(text, jsonb) TO authenticated;

COMMENT ON FUNCTION api.fn_serial_create(text, jsonb) IS
  'Crée un titre de périodique en status=proposto (slug automatique). '
  'p_payload accepte les champs descriptifs ; uniform_title y est ignoré au '
  'profit du premier paramètre. Staff de catalogage. Paquet PÉRIODIQUES P2.';

-- -------------------------------------------------------------------------
-- 3. Édition des champs descriptifs
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION api.fn_serial_update(
  p_serial_id bigint,
  p_payload   jsonb
)
RETURNS public.serials
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $function$
BEGIN
  IF NOT public.fn_caller_is_staff() THEN
    RAISE EXCEPTION 'Acesso restrito ao staff de catalogacao.'
      USING ERRCODE = 'insufficient_privilege', HINT = 'error.serial.forbidden';
  END IF;
  RETURN public.fn_serial_apply_payload(p_serial_id, p_payload);
END $function$;

REVOKE ALL ON FUNCTION api.fn_serial_update(bigint, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION api.fn_serial_update(bigint, jsonb) TO authenticated;

COMMENT ON FUNCTION api.fn_serial_update(bigint, jsonb) IS
  'Édite les champs descriptifs d''un titre de périodique. Une clé PRÉSENTE est '
  'écrite (à null = vidée), une clé ABSENTE n''est pas touchée ; toute clé '
  'inconnue lève. status, filiation et slug ont leurs propres chemins. '
  'Staff de catalogage. Paquet PÉRIODIQUES P2.';

-- -------------------------------------------------------------------------
-- 4. Promotion / dépréciation — coordination seulement
-- -------------------------------------------------------------------------
-- Pas de promotion automatique au seuil (« N fascicules dans M bibliothèques »)
-- : la promotion est un geste, pas un seuil (spec §13 TODO 4).
CREATE OR REPLACE FUNCTION api.fn_serial_set_status(
  p_serial_id bigint,
  p_status    text
)
RETURNS public.serials
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $function$
DECLARE r public.serials;
BEGIN
  IF NOT public.fn_is_catalog_coordinator() THEN
    RAISE EXCEPTION 'Réservé à la coordination catalogage.'
      USING ERRCODE = 'insufficient_privilege', HINT = 'error.serial.status.forbidden';
  END IF;
  IF p_status NOT IN ('proposto','ativo','depreciado') THEN
    RAISE EXCEPTION 'Statut invalide : %.', p_status
      USING ERRCODE = 'check_violation', HINT = 'error.serial.status.invalid';
  END IF;

  UPDATE public.serials
     SET status = p_status, updated_by = auth.uid(), updated_at = now()
   WHERE id = p_serial_id
  RETURNING * INTO r;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Périodique introuvable : %.', p_serial_id
      USING ERRCODE = 'no_data_found', HINT = 'error.serial.notFound';
  END IF;
  RETURN r;
END $function$;

REVOKE ALL ON FUNCTION api.fn_serial_set_status(bigint, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION api.fn_serial_set_status(bigint, text) TO authenticated;

COMMENT ON FUNCTION api.fn_serial_set_status(bigint, text) IS
  'proposto -> ativo (le titre devient visible du public) / depreciado. '
  'Coordination catalogage uniquement. Paquet PÉRIODIQUES P2.';

-- -------------------------------------------------------------------------
-- 5. Filiation (changements de titre)
-- -------------------------------------------------------------------------
-- Les deux gardes sont dans les triggers de P1 : cette RPC ne fait qu'ouvrir
-- le chemin d'écriture et traduire les refus. Elle écrit les deux colonnes en
-- UN seul UPDATE — deux UPDATE successifs feraient tourner le trigger de
-- symétrie sur un état intermédiaire incohérent.
CREATE OR REPLACE FUNCTION api.fn_serial_set_filiation(
  p_serial_id      bigint,
  p_predecessor_id bigint DEFAULT NULL,
  p_successor_id   bigint DEFAULT NULL
)
RETURNS public.serials
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $function$
DECLARE r public.serials;
BEGIN
  IF NOT public.fn_caller_is_staff() THEN
    RAISE EXCEPTION 'Acesso restrito ao staff de catalogacao.'
      USING ERRCODE = 'insufficient_privilege', HINT = 'error.serial.forbidden';
  END IF;

  IF p_predecessor_id IS NOT NULL
     AND NOT EXISTS (SELECT 1 FROM public.serials WHERE id = p_predecessor_id) THEN
    RAISE EXCEPTION 'Périodique prédécesseur introuvable : %.', p_predecessor_id
      USING ERRCODE = 'no_data_found', HINT = 'error.serial.notFound';
  END IF;
  IF p_successor_id IS NOT NULL
     AND NOT EXISTS (SELECT 1 FROM public.serials WHERE id = p_successor_id) THEN
    RAISE EXCEPTION 'Périodique successeur introuvable : %.', p_successor_id
      USING ERRCODE = 'no_data_found', HINT = 'error.serial.notFound';
  END IF;

  UPDATE public.serials
     SET predecessor_id = p_predecessor_id,
         successor_id   = p_successor_id,
         updated_by     = auth.uid(),
         updated_at     = now()
   WHERE id = p_serial_id
  RETURNING * INTO r;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Périodique introuvable : %.', p_serial_id
      USING ERRCODE = 'no_data_found', HINT = 'error.serial.notFound';
  END IF;

  -- Le trigger de symétrie a pu réécrire la ligne : on relit pour ne pas
  -- rendre un état périmé à l'interface.
  SELECT * INTO r FROM public.serials WHERE id = p_serial_id;
  RETURN r;
END $function$;

REVOKE ALL ON FUNCTION api.fn_serial_set_filiation(bigint, bigint, bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION api.fn_serial_set_filiation(bigint, bigint, bigint) TO authenticated;

COMMENT ON FUNCTION api.fn_serial_set_filiation(bigint, bigint, bigint) IS
  'Pose (ou retire, avec NULL) le prédécesseur et le successeur d''un titre. '
  'Le refus des cycles (G1) et la réciprocité (G2) sont tenus par les triggers '
  'de P1, donc valables aussi hors de ce chemin. Staff de catalogage.';

-- -------------------------------------------------------------------------
-- 6. Rattacher / détacher un fascicule
-- -------------------------------------------------------------------------
-- NOTE : le recalcul de l'état de collection annoncé par la spec §6 arrive
-- avec P4 (la table serial_holdings n'existe pas encore). P4 remplacera ces
-- deux fonctions pour l'ajouter — leur signature ne bouge pas.
CREATE OR REPLACE FUNCTION api.fn_serial_attach_issue(
  p_book_id   bigint,
  p_serial_id bigint
)
RETURNS public.books
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $function$
DECLARE r public.books;
BEGIN
  IF NOT public.fn_caller_is_staff() THEN
    RAISE EXCEPTION 'Acesso restrito ao staff de catalogacao.'
      USING ERRCODE = 'insufficient_privilege', HINT = 'error.serial.forbidden';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.serials WHERE id = p_serial_id) THEN
    RAISE EXCEPTION 'Périodique introuvable : %.', p_serial_id
      USING ERRCODE = 'no_data_found', HINT = 'error.serial.notFound';
  END IF;

  -- La garde G3 (tipo_material) est portée par le trigger de P1 : on ne la
  -- réécrit pas ici, on la laisse parler.
  UPDATE public.books SET serial_id = p_serial_id WHERE id = p_book_id
  RETURNING * INTO r;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Document introuvable : %.', p_book_id
      USING ERRCODE = 'no_data_found', HINT = 'error.serial.issue.notFound';
  END IF;
  RETURN r;
END $function$;

REVOKE ALL ON FUNCTION api.fn_serial_attach_issue(bigint, bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION api.fn_serial_attach_issue(bigint, bigint) TO authenticated;

COMMENT ON FUNCTION api.fn_serial_attach_issue(bigint, bigint) IS
  'Rattache un fascicule à son titre d''autorité. Ne touche PAS à '
  'titulo_periodico : la forme transcrite reste ce qui est imprimé sur le '
  'fascicule. Staff de catalogage. Paquet PÉRIODIQUES P2.';

CREATE OR REPLACE FUNCTION api.fn_serial_detach_issue(p_book_id bigint)
RETURNS public.books
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $function$
DECLARE r public.books;
BEGIN
  IF NOT public.fn_caller_is_staff() THEN
    RAISE EXCEPTION 'Acesso restrito ao staff de catalogacao.'
      USING ERRCODE = 'insufficient_privilege', HINT = 'error.serial.forbidden';
  END IF;

  UPDATE public.books SET serial_id = NULL WHERE id = p_book_id
  RETURNING * INTO r;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Document introuvable : %.', p_book_id
      USING ERRCODE = 'no_data_found', HINT = 'error.serial.issue.notFound';
  END IF;
  RETURN r;
END $function$;

REVOKE ALL ON FUNCTION api.fn_serial_detach_issue(bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION api.fn_serial_detach_issue(bigint) TO authenticated;

COMMENT ON FUNCTION api.fn_serial_detach_issue(bigint) IS
  'Retire le lien d''un fascicule vers son titre. titulo_periodico est conservé '
  '— c''est la forme transcrite, elle ne dépend pas du rattachement. '
  'Staff de catalogage. Paquet PÉRIODIQUES P2.';

-- -------------------------------------------------------------------------
-- 7. Recherche pour l'autocomplétion au catalogage
-- -------------------------------------------------------------------------
-- SECURITY INVOKER : la RLS de P1 décide de ce que l'appelant voit. C'est ce
-- qui donne le bon comportement sans le coder deux fois — le staff trouve les
-- titres PROPOSÉS (sinon il en recréerait des doublons à chaque saisie), le
-- reste du monde ne trouve que les titres promus.
CREATE OR REPLACE FUNCTION api.fn_serial_search(
  p_query text,
  p_limit integer DEFAULT 12
)
RETURNS TABLE (
  id            bigint,
  slug          text,
  uniform_title text,
  sort_title    text,
  issn          text,
  start_year    text,
  end_year      text,
  emitter_org   text,
  status        text,
  alt_i18n      jsonb,
  issues_count  integer
)
LANGUAGE sql
STABLE
SET search_path = public, pg_catalog
AS $function$
  SELECT s.id, s.slug, s.uniform_title, s.sort_title, s.issn,
         s.start_year, s.end_year, s.emitter_org, s.status, s.alt_i18n,
         (SELECT count(*)::integer FROM public.books b WHERE b.serial_id = s.id)
  FROM public.serials s
  WHERE s.status <> 'depreciado'
    AND nullif(btrim(p_query), '') IS NOT NULL
    AND (
      s.slug ILIKE '%' || btrim(p_query) || '%'
      OR public.f_normalize_search(s.uniform_title)
         LIKE '%' || public.f_normalize_search(btrim(p_query)) || '%'
      OR public.f_normalize_search(coalesce(s.sort_title,''))
         LIKE '%' || public.f_normalize_search(btrim(p_query)) || '%'
      OR regexp_replace(coalesce(s.issn,''), '\D', '', 'g') =
         nullif(regexp_replace(btrim(p_query), '\D', '', 'g'), '')
      OR EXISTS (SELECT 1 FROM jsonb_each(s.alt_i18n) kv
                  WHERE jsonb_typeof(kv.value) = 'array'
                    AND EXISTS (SELECT 1 FROM jsonb_array_elements_text(kv.value) syn
                                 WHERE public.f_normalize_search(syn)
                                       LIKE '%' || public.f_normalize_search(btrim(p_query)) || '%'))
      OR EXISTS (SELECT 1 FROM jsonb_each(s.hidden_i18n) kv
                  WHERE jsonb_typeof(kv.value) = 'array'
                    AND EXISTS (SELECT 1 FROM jsonb_array_elements_text(kv.value) syn
                                 WHERE public.f_normalize_search(syn)
                                       LIKE '%' || public.f_normalize_search(btrim(p_query)) || '%'))
    )
  ORDER BY coalesce(s.sort_title, s.uniform_title), s.slug
  LIMIT least(coalesce(p_limit, 12), 50);
$function$;

REVOKE ALL ON FUNCTION api.fn_serial_search(text, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION api.fn_serial_search(text, integer) TO authenticated;

COMMENT ON FUNCTION api.fn_serial_search(text, integer) IS
  'Autocomplétion de titre de périodique au catalogage : titre retenu, forme de '
  'tri, slug, ISSN (chiffres seuls, donc le tiret est indifférent), formes '
  'parallèles ET formes rejetées — ce sont ces dernières qui rattrapent les '
  'graphies fautives d''un import de masse. SECURITY INVOKER : la RLS filtre, '
  'donc le staff voit les titres proposés et le public non. Paquet PÉRIODIQUES P2.';

-- -------------------------------------------------------------------------
-- 8. Surfaces de lecture
-- -------------------------------------------------------------------------
-- Toutes en SECURITY INVOKER. Contrairement à api.subject_detail_v1 qui code
-- « status = ativo » en dur, on laisse la RLS trancher : c'est la même règle
-- écrite à un seul endroit, et le staff obtient ainsi la fiche d'un titre
-- proposé sans qu'il faille une seconde fonction pour lui.
CREATE OR REPLACE VIEW api.serials_list_v1
WITH (security_invoker = true)
AS
  SELECT s.id, s.slug, s.uniform_title, s.sort_title, s.title_nonfiling,
         s.alt_i18n, s.issn, s.issn_l, s.emitter_org, s.place_publication,
         s.country_code, s.language, s.periodicidade,
         s.start_year, s.end_year, s.is_continuing, s.scope_note, s.status,
         s.predecessor_id, s.successor_id,
         (SELECT count(*)::integer FROM public.books b WHERE b.serial_id = s.id) AS issues_count
  FROM public.serials s;

GRANT SELECT ON api.serials_list_v1 TO anon, authenticated;

COMMENT ON VIEW api.serials_list_v1 IS
  'Liste des titres de périodiques. security_invoker=true depuis sa création : '
  'la RLS de public.serials fait le filtrage (public = ativo seulement). '
  'Paquet PÉRIODIQUES P2 du 27/08/2026.';

CREATE OR REPLACE FUNCTION api.serial_detail_v1(p_slug text)
RETURNS TABLE (
  id                bigint,
  slug              text,
  uniform_title     text,
  sort_title        text,
  alt_i18n          jsonb,
  issn              text,
  issn_l            text,
  publisher_id      bigint,
  publisher_name    text,
  emitter_org       text,
  place_publication text,
  country_code      text,
  language          text,
  periodicidade     text,
  start_year        text,
  end_year          text,
  is_continuing     boolean,
  scope_note        text,
  status            text,
  predecessor_id    bigint,
  predecessor_slug  text,
  predecessor_title text,
  successor_id      bigint,
  successor_slug    text,
  successor_title   text,
  issues_count      integer
)
LANGUAGE sql
STABLE
SET search_path = public, pg_catalog
AS $function$
  SELECT s.id, s.slug, s.uniform_title, s.sort_title, s.alt_i18n,
         s.issn, s.issn_l, s.publisher_id, pu.name, s.emitter_org,
         s.place_publication, s.country_code, s.language, s.periodicidade,
         s.start_year, s.end_year, s.is_continuing, s.scope_note, s.status,
         s.predecessor_id, pr.slug, pr.uniform_title,
         s.successor_id,   su.slug, su.uniform_title,
         (SELECT count(*)::integer FROM public.books b WHERE b.serial_id = s.id)
  FROM public.serials s
  LEFT JOIN public.publishers pu ON pu.id = s.publisher_id
  LEFT JOIN public.serials pr    ON pr.id = s.predecessor_id
  LEFT JOIN public.serials su    ON su.id = s.successor_id
  WHERE s.slug = p_slug;
$function$;

REVOKE ALL ON FUNCTION api.serial_detail_v1(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api.serial_detail_v1(text) TO anon, authenticated;

COMMENT ON FUNCTION api.serial_detail_v1(text) IS
  'Fiche d''un titre de périodique par slug, avec éditeur et filiation résolus. '
  'Un maillon de filiation encore PROPOSÉ apparaît en NULL pour le public : '
  'c''est la RLS qui le masque, pas un oubli. Paquet PÉRIODIQUES P2.';

CREATE OR REPLACE FUNCTION api.serial_issues_v1(p_serial_id bigint)
RETURNS TABLE (
  book_id       bigint,
  bib_ref       text,
  titulo        text,
  titulo_periodico text,
  volume        text,
  numero        text,
  fasciculo     text,
  data_edicao   text,
  ano           text,
  issue_key     text,
  library_id    uuid,
  library_slug  text,
  library_name  text,
  exemplares    integer
)
LANGUAGE sql
STABLE
SET search_path = public, pg_catalog
AS $function$
  -- Garde G6 : trier sur issue_key seule donnerait « 1, 10, 2 » dès que la
  -- désignation n'est pas purement numérique. Toujours (ano, issue_key, titulo).
  SELECT b.id, b.bib_ref, b.titulo, b.titulo_periodico,
         b.volume, b.numero, b.fasciculo, b.data_edicao, b.ano, b.issue_key,
         l.id, l.slug, l.short_name,
         coalesce(h.exemplares_total, 0)
  FROM public.books b
  LEFT JOIN public.book_holdings h ON h.book_id = b.id
  LEFT JOIN public.libraries l     ON l.id = h.library_id
  WHERE b.serial_id = p_serial_id
  ORDER BY b.ano NULLS LAST, b.issue_key NULLS LAST, b.titulo;
$function$;

REVOKE ALL ON FUNCTION api.serial_issues_v1(bigint) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api.serial_issues_v1(bigint) TO anon, authenticated;

COMMENT ON FUNCTION api.serial_issues_v1(bigint) IS
  'Fascicules d''un titre, ordonnés (ano, issue_key, titulo) — garde G6 de la '
  'spec : issue_key seule donnerait « 1, 10, 2 ». SECURITY INVOKER : la RLS de '
  'books / book_holdings / libraries applique déjà la visibilité de chaque '
  'bibliothèque détentrice. Paquet PÉRIODIQUES P2.';

-- -------------------------------------------------------------------------
-- 9. Vérification automatique
-- -------------------------------------------------------------------------
DO $verif$
DECLARE
  v_missing text[];
BEGIN
  -- 9.1 Toutes les fonctions annoncées existent avec la bonne signature.
  SELECT array_agg(x) INTO v_missing FROM (
    SELECT x FROM unnest(ARRAY[
      'api.fn_serial_create(text,jsonb)',
      'api.fn_serial_update(bigint,jsonb)',
      'api.fn_serial_set_status(bigint,text)',
      'api.fn_serial_set_filiation(bigint,bigint,bigint)',
      'api.fn_serial_attach_issue(bigint,bigint)',
      'api.fn_serial_detach_issue(bigint)',
      'api.fn_serial_search(text,integer)',
      'api.serial_detail_v1(text)',
      'api.serial_issues_v1(bigint)'
    ]) AS x
    WHERE to_regprocedure(x) IS NULL
  ) q;
  IF v_missing IS NOT NULL THEN
    RAISE EXCEPTION 'Fonctions manquantes : %.', array_to_string(v_missing, ', ');
  END IF;

  -- 9.2 Le helper privé n'est exécutable par personne d'autre que le propriétaire.
  IF has_function_privilege('authenticated', 'public.fn_serial_apply_payload(bigint,jsonb)', 'EXECUTE')
     OR has_function_privilege('anon', 'public.fn_serial_apply_payload(bigint,jsonb)', 'EXECUTE') THEN
    RAISE EXCEPTION 'fn_serial_apply_payload reste exécutable par anon/authenticated.';
  END IF;

  -- 9.3 Les écritures ne sont PAS ouvertes à anon.
  IF has_function_privilege('anon', 'api.fn_serial_create(text,jsonb)', 'EXECUTE')
     OR has_function_privilege('anon', 'api.fn_serial_set_status(bigint,text)', 'EXECUTE') THEN
    RAISE EXCEPTION 'Des RPC d''écriture de périodique sont exécutables par anon.';
  END IF;

  -- 9.4 Les lectures publiques le sont bien.
  IF NOT has_function_privilege('anon', 'api.serial_detail_v1(text)', 'EXECUTE')
     OR NOT has_function_privilege('anon', 'api.serial_issues_v1(bigint)', 'EXECUTE') THEN
    RAISE EXCEPTION 'Les fiches publiques de périodique ne sont pas lisibles en anon.';
  END IF;

  -- 9.5 La vue de liste est bien en security_invoker (sans quoi elle
  --     publierait les titres proposés).
  IF NOT EXISTS (
    SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'api' AND c.relname = 'serials_list_v1'
      AND c.reloptions @> ARRAY['security_invoker=true']
  ) THEN
    RAISE EXCEPTION 'api.serials_list_v1 n''est pas en security_invoker.';
  END IF;

  RAISE NOTICE 'Paquet PÉRIODIQUES P2 : vérifications OK (9 fonctions, grants, security_invoker).';
END $verif$;

COMMIT;

NOTIFY pgrst, 'reload schema';

-- =========================================================================
-- Rollback ciblé :
-- =========================================================================
-- BEGIN;
--   DROP VIEW IF EXISTS api.serials_list_v1;
--   DROP FUNCTION IF EXISTS api.serial_issues_v1(bigint);
--   DROP FUNCTION IF EXISTS api.serial_detail_v1(text);
--   DROP FUNCTION IF EXISTS api.fn_serial_search(text, integer);
--   DROP FUNCTION IF EXISTS api.fn_serial_detach_issue(bigint);
--   DROP FUNCTION IF EXISTS api.fn_serial_attach_issue(bigint, bigint);
--   DROP FUNCTION IF EXISTS api.fn_serial_set_filiation(bigint, bigint, bigint);
--   DROP FUNCTION IF EXISTS api.fn_serial_set_status(bigint, text);
--   DROP FUNCTION IF EXISTS api.fn_serial_update(bigint, jsonb);
--   DROP FUNCTION IF EXISTS api.fn_serial_create(text, jsonb);
--   DROP FUNCTION IF EXISTS public.fn_serial_apply_payload(bigint, jsonb);
-- COMMIT;
-- =========================================================================
