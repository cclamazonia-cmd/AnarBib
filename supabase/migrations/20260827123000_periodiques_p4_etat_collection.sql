-- =========================================================================
-- Paquet PÉRIODIQUES P4 — L'état de collection
-- =========================================================================
-- Date     : 2026-08-27
-- Chantier : périodiques (spec-periodiques v0.1, §3.4 et garde G5)
-- Auteur   : Xavier (arbitrages) + Claude (rédaction)
--
-- POURQUOI. « Nous avons 1896-1914, sauf le n°23 et 1902 » est l'information
-- qui décide d'une demande de prêt entre bibliothèques. Sans elle, on demande à
-- l'aveugle, ou on ne demande pas. Aucune structure existante ne sait l'écrire.
--
-- LE PRINCIPE QUI COMMANDE TOUT LE RESTE : l'état de collection est DÉCLARÉ
-- autant que calculé. Le calcul depuis les fascicules présents ne dit jamais
-- qu'une lacune est définitive — il dit seulement ce qui est catalogué à cet
-- instant. Une archive, elle, le sait. Donc :
--   * quand `statement` est rempli, c'est LUI qui s'affiche ;
--   * le calcul ne le remplace JAMAIS, il l'accompagne ;
--   * une divergence entre les deux est une information utile (du catalogage
--     en retard, ou un don non encore traité), pas une erreur à corriger
--     automatiquement.
-- C'est pour cela que les colonnes calculées et la colonne déclarée coexistent
-- dans la même ligne au lieu que la seconde écrase la première.
--
-- CE QUE CE PAQUET AJOUTE EN PLUS DE LA SPEC, et pourquoi :
--   1. fn_recompute_serial_holdings ne crée PAS de ligne vide. La version de la
--      spec insère inconditionnellement : appelée pour un couple (revue,
--      bibliothèque) sans aucun fascicule, elle fabrique une ligne
--      « 0 numéro » qui dit au lecteur « cette bibliothèque a cette revue, mais
--      rien dedans ». Faux et décourageant. Ici : on n'insère que s'il y a
--      quelque chose OU si une ligne existe déjà (une bibliothèque qui perd son
--      dernier fascicule doit bien retomber à 0, pas rester sur un chiffre
--      périmé).
--   2. La lecture publique exige AUSSI que la bibliothèque soit visible de
--      l'appelant. `is_public` seul publierait l'état de collection d'une
--      bibliothèque privée ou isolée.
--
-- LIMITE CONNUE ET ASSUMÉE : computed_first / computed_last sont des min/max
-- sur books.ano, qui est du TEXTE. Sur « 1896 » et « 1914 » l'ordre
-- lexicographique et l'ordre chronologique coïncident ; sur « ca. 1902 » ou
-- « [1936?] » non. C'est le prix de ne pas forcer un entier là où nos fonds ne
-- le permettent pas — et c'est précisément pour cela que `statement` fait foi.
--
-- CE PAQUET REMPLACE AUSSI fn_serial_attach_issue / fn_serial_detach_issue
-- (P2) pour y brancher le recalcul, comme l'annonce la spec §6. Les signatures
-- ne bougent pas : l'interface n'a rien à changer.
--
-- CHECKLIST DOCTRINE
--   [x] Table public : GRANT explicites, ENABLE RLS, policies nommées
--   [x] Écritures réservées aux RPC (aucune policy d'écriture)
--   [x] Sous-requête RLS vers une table restrictive -> helper SECURITY DEFINER
--       (règle tirée du Lot 4 des notes de lecture)
--   [x] SECURITY DEFINER : search_path épinglé, REVOKE PUBLIC/anon, GRANT ciblé
--   [x] DO block de vérification en fin de transaction
-- =========================================================================

BEGIN;

-- -------------------------------------------------------------------------
-- 1. Helper de rôle — staff de CETTE bibliothèque
-- -------------------------------------------------------------------------
-- SECURITY DEFINER parce qu'il est appelé depuis une policy RLS : une
-- sous-requête EXISTS dans une expression de policy s'évalue AVEC la RLS des
-- tables qu'elle référence, et l'oublier a déjà coûté un INSERT refusé pour
-- tout le monde (notes de lecture, Lot 4).
--
-- Pourquoi pas fn_caller_is_staff() ET fn_current_user_is_member_of() : la
-- conjonction serait fausse. Quelqu'un bibliothécaire à la BLMF et simple
-- lectrice au CIRA passerait les deux tests pour le CIRA, et verrait l'état de
-- collection non publié du CIRA. Il faut le rôle DANS la bibliothèque visée.
CREATE OR REPLACE FUNCTION public.fn_serial_caller_is_library_staff(p_library_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path = public, pg_catalog
AS $function$
  SELECT EXISTS (
    SELECT 1 FROM public.user_library_memberships m
    WHERE m.user_id = auth.uid()
      AND m.library_id = p_library_id
      AND m.role IN ('librarian','coordenador')
      AND m.status = 'active'
  ) OR public.fn_caller_is_network_admin();
$function$;

REVOKE ALL ON FUNCTION public.fn_serial_caller_is_library_staff(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_serial_caller_is_library_staff(uuid) TO anon, authenticated;

COMMENT ON FUNCTION public.fn_serial_caller_is_library_staff(uuid) IS
  'Vrai si l''appelant est bibliothécaire ou coordination DE CETTE bibliothèque '
  '(ou administration réseau). Helper RLS : GRANT à anon conservé, sans quoi la '
  'policy lèverait au lieu de rendre faux. Paquet PÉRIODIQUES P4.';

-- -------------------------------------------------------------------------
-- 2. La table
-- -------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.serial_holdings (
  id             bigint GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  serial_id      bigint NOT NULL REFERENCES public.serials(id)   ON DELETE CASCADE,
  library_id     uuid   NOT NULL REFERENCES public.libraries(id) ON DELETE CASCADE,

  -- déclaré par la bibliothèque, fait foi
  statement      text,               -- « 1896-1914, lacunes : n°23, 1902 »
  gaps_note      text,
  completeness   text NOT NULL DEFAULT 'desconhecida',
  is_public      boolean NOT NULL DEFAULT true,

  -- calculé depuis les fascicules effectivement catalogués
  computed_first text,
  computed_last  text,
  computed_count integer NOT NULL DEFAULT 0,
  computed_at    timestamptz,

  created_at     timestamptz NOT NULL DEFAULT now(),
  updated_at     timestamptz NOT NULL DEFAULT now(),
  updated_by     uuid,

  CONSTRAINT serial_holdings_unique UNIQUE (serial_id, library_id),
  CONSTRAINT serial_holdings_completeness_chk
    CHECK (completeness IN ('completa','quase_completa','parcial','esparsa','desconhecida'))
);

CREATE INDEX IF NOT EXISTS serial_holdings_serial_id_idx  ON public.serial_holdings (serial_id);
CREATE INDEX IF NOT EXISTS serial_holdings_library_id_idx ON public.serial_holdings (library_id);

COMMENT ON TABLE public.serial_holdings IS
  'État de collection d''un périodique dans une bibliothèque : ce qu''elle '
  'DÉCLARE posséder, à côté de ce qui est calculé depuis les fascicules '
  'catalogués. Une ligne par couple (revue, bibliothèque). Créée par le paquet '
  'PÉRIODIQUES P4 du 27/08/2026.';

COMMENT ON COLUMN public.serial_holdings.statement IS
  'État de collection déclaré, en clair et dans la langue de la bibliothèque : '
  '« 1896-1914, lacunes : n°23, 1902 ». QUAND IL EST REMPLI, C''EST LUI QUI '
  'S''AFFICHE. Le calcul ne le remplace jamais : lui seul peut dire qu''une '
  'lacune est DÉFINITIVE, ce qu''aucun comptage de fascicules ne saura jamais.';
COMMENT ON COLUMN public.serial_holdings.gaps_note IS
  'Précisions sur les lacunes, quand statement ne suffit pas à les porter.';
COMMENT ON COLUMN public.serial_holdings.completeness IS
  'completa / quase_completa / parcial / esparsa / desconhecida (défaut). '
  'Sert au filtrage et à la décision de PEB, pas à l''affichage détaillé.';
COMMENT ON COLUMN public.serial_holdings.is_public IS
  'Publie l''état de collection dans l''OPAC. La visibilité de la BIBLIOTHÈQUE '
  's''applique en plus : une bibliothèque privée ou isolée ne publie rien, même '
  'à is_public=true.';
COMMENT ON COLUMN public.serial_holdings.computed_first IS
  'Plus petite valeur de books.ano parmi les fascicules catalogués. ATTENTION : '
  'ano est du TEXTE, donc c''est un min LEXICOGRAPHIQUE. Juste sur « 1896 », '
  'faux sur « ca. 1902 ». Indicatif — statement fait foi.';
COMMENT ON COLUMN public.serial_holdings.computed_last IS
  'Voir computed_first : max lexicographique sur un champ texte.';
COMMENT ON COLUMN public.serial_holdings.computed_count IS
  'Nombre de fascicules catalogués par cette bibliothèque pour ce titre. '
  'Une DIVERGENCE avec statement est une information (catalogage en retard, don '
  'non traité), pas une erreur à corriger automatiquement.';

-- REVOKE d'abord : Supabase pose des ALTER DEFAULT PRIVILEGES sur public, donc
-- une table neuve naît avec INSERT/UPDATE/DELETE accordés à anon et
-- authenticated. Sans cette ligne, l'état de collection serait modifiable
-- directement, sans passer par la coordination.
REVOKE ALL ON public.serial_holdings FROM anon, authenticated;
GRANT SELECT ON public.serial_holdings TO anon, authenticated;
GRANT ALL    ON public.serial_holdings TO service_role;

ALTER TABLE public.serial_holdings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS serial_holdings_select_public ON public.serial_holdings;
CREATE POLICY serial_holdings_select_public
  ON public.serial_holdings FOR SELECT
  TO anon, authenticated
  USING (is_public AND public.fn_library_visible_to_caller(library_id));

DROP POLICY IF EXISTS serial_holdings_select_staff ON public.serial_holdings;
CREATE POLICY serial_holdings_select_staff
  ON public.serial_holdings FOR SELECT
  TO authenticated
  USING (public.fn_serial_caller_is_library_staff(library_id));

COMMENT ON POLICY serial_holdings_select_public ON public.serial_holdings IS
  'is_public NE SUFFIT PAS : la bibliothèque doit aussi être visible de '
  'l''appelant, sinon une bibliothèque privée publierait son état de collection.';

DROP TRIGGER IF EXISTS serial_holdings_set_updated_at ON public.serial_holdings;
CREATE TRIGGER serial_holdings_set_updated_at
  BEFORE UPDATE ON public.serial_holdings
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- -------------------------------------------------------------------------
-- 3. Recalcul depuis les fascicules catalogués
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_recompute_serial_holdings(
  p_serial_id  bigint,
  p_library_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $function$
DECLARE
  v_first text;
  v_last  text;
  v_count integer;
BEGIN
  IF p_serial_id IS NULL OR p_library_id IS NULL THEN
    RETURN;
  END IF;

  SELECT min(b.ano), max(b.ano), count(*)::integer
    INTO v_first, v_last, v_count
  FROM public.books b
  JOIN public.book_holdings h ON h.book_id = b.id
  WHERE b.serial_id = p_serial_id
    AND h.library_id = p_library_id;

  -- Ne rien créer pour un couple sans aucun fascicule : une ligne « 0 numéro »
  -- dirait au lecteur « cette bibliothèque a la revue, mais rien dedans ».
  -- En revanche, si la ligne existe déjà (donc un état DÉCLARÉ à préserver, ou
  -- un comptage antérieur), elle doit bien retomber à 0 plutôt que de rester
  -- sur un chiffre périmé.
  IF v_count = 0 AND NOT EXISTS (
       SELECT 1 FROM public.serial_holdings
        WHERE serial_id = p_serial_id AND library_id = p_library_id) THEN
    RETURN;
  END IF;

  INSERT INTO public.serial_holdings AS sh
    (serial_id, library_id, computed_first, computed_last, computed_count, computed_at)
  VALUES (p_serial_id, p_library_id, v_first, v_last, v_count, now())
  ON CONFLICT (serial_id, library_id) DO UPDATE
    SET computed_first = excluded.computed_first,
        computed_last  = excluded.computed_last,
        computed_count = excluded.computed_count,
        computed_at    = excluded.computed_at;
  -- Noter ce qui n'est PAS dans le SET : statement, gaps_note, completeness et
  -- is_public. Le calcul n'a pas le droit d'y toucher.
END $function$;

REVOKE ALL ON FUNCTION public.fn_recompute_serial_holdings(bigint, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_recompute_serial_holdings(bigint, uuid) TO authenticated;

COMMENT ON FUNCTION public.fn_recompute_serial_holdings(bigint, uuid) IS
  'Recalcule les colonnes computed_* d''un couple (revue, bibliothèque) depuis '
  'les fascicules catalogués. NE TOUCHE JAMAIS à statement / gaps_note / '
  'completeness / is_public : le déclaré fait foi. Paquet PÉRIODIQUES P4.';

-- -------------------------------------------------------------------------
-- 4. État déclaré — coordination de la bibliothèque concernée
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION api.fn_serial_upsert_holdings(
  p_serial_id    bigint,
  p_library_id   uuid,
  p_statement    text    DEFAULT NULL,
  p_gaps_note    text    DEFAULT NULL,
  p_completeness text    DEFAULT NULL,
  p_is_public    boolean DEFAULT NULL
)
RETURNS public.serial_holdings
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $function$
DECLARE r public.serial_holdings;
BEGIN
  IF NOT public.fn_team_caller_is_coordenador(p_library_id) THEN
    RAISE EXCEPTION 'Réservé à la coordination de cette bibliothèque.'
      USING ERRCODE = 'insufficient_privilege', HINT = 'error.serial.holdings.forbidden';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.serials WHERE id = p_serial_id) THEN
    RAISE EXCEPTION 'Périodique introuvable : %.', p_serial_id
      USING ERRCODE = 'no_data_found', HINT = 'error.serial.notFound';
  END IF;
  IF p_completeness IS NOT NULL
     AND p_completeness NOT IN ('completa','quase_completa','parcial','esparsa','desconhecida') THEN
    RAISE EXCEPTION 'Niveau de complétude invalide : %.', p_completeness
      USING ERRCODE = 'check_violation', HINT = 'error.serial.holdings.completeness';
  END IF;

  INSERT INTO public.serial_holdings AS sh
    (serial_id, library_id, statement, gaps_note, completeness, is_public, updated_by)
  VALUES (
    p_serial_id, p_library_id,
    nullif(btrim(coalesce(p_statement,'')), ''),
    nullif(btrim(coalesce(p_gaps_note,'')), ''),
    coalesce(p_completeness, 'desconhecida'),
    coalesce(p_is_public, true),
    auth.uid())
  ON CONFLICT (serial_id, library_id) DO UPDATE
    SET statement    = nullif(btrim(coalesce(p_statement,'')), ''),
        gaps_note    = nullif(btrim(coalesce(p_gaps_note,'')), ''),
        completeness = coalesce(p_completeness, sh.completeness),
        is_public    = coalesce(p_is_public, sh.is_public),
        updated_by   = auth.uid()
  RETURNING * INTO r;

  -- Le déclaré vient d'être posé : on rafraîchit le calculé dans la foulée pour
  -- que la divergence, s'il y en a une, soit visible tout de suite.
  PERFORM public.fn_recompute_serial_holdings(p_serial_id, p_library_id);
  SELECT * INTO r FROM public.serial_holdings
   WHERE serial_id = p_serial_id AND library_id = p_library_id;
  RETURN r;
END $function$;

REVOKE ALL ON FUNCTION api.fn_serial_upsert_holdings(bigint, uuid, text, text, text, boolean)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION api.fn_serial_upsert_holdings(bigint, uuid, text, text, text, boolean)
  TO authenticated;

COMMENT ON FUNCTION api.fn_serial_upsert_holdings(bigint, uuid, text, text, text, boolean) IS
  'Pose l''état de collection DÉCLARÉ d''une revue dans une bibliothèque. '
  'statement et gaps_note sont écrits tels quels (NULL = vidé, c''est un geste '
  'explicite) ; completeness et is_public gardent leur valeur si on ne les '
  'passe pas. Coordination de la bibliothèque concernée. Paquet PÉRIODIQUES P4.';

-- -------------------------------------------------------------------------
-- 5. Surface publique de l'état de collection
-- -------------------------------------------------------------------------
CREATE OR REPLACE VIEW api.serial_holdings_public_v1
WITH (security_invoker = true)
AS
  SELECT sh.serial_id,
         s.slug AS serial_slug,
         sh.library_id,
         l.slug AS library_slug,
         l.short_name AS library_name,
         sh.statement,
         sh.gaps_note,
         sh.completeness,
         sh.computed_first,
         sh.computed_last,
         sh.computed_count,
         sh.computed_at,
         -- Ce que l'interface doit afficher, décidé ici une fois pour toutes
         -- plutôt que dans chaque page : le déclaré s'il existe, sinon rien
         -- (et surtout pas un intervalle calculé maquillé en déclaration).
         (sh.statement IS NOT NULL) AS has_statement
  FROM public.serial_holdings sh
  JOIN public.serials   s ON s.id = sh.serial_id
  JOIN public.libraries l ON l.id = sh.library_id;

GRANT SELECT ON api.serial_holdings_public_v1 TO anon, authenticated;

COMMENT ON VIEW api.serial_holdings_public_v1 IS
  'États de collection lisibles par l''appelant. security_invoker=true : le '
  'filtrage (is_public + visibilité de la bibliothèque + statut de la revue via '
  'la jointure sur serials) est fait par la RLS, pas réécrit ici. '
  'Paquet PÉRIODIQUES P4 du 27/08/2026.';

-- -------------------------------------------------------------------------
-- 6. Rattachement / détachement : brancher le recalcul
-- -------------------------------------------------------------------------
-- Signatures INCHANGÉES par rapport à P2 : l'interface n'a rien à modifier.
CREATE OR REPLACE FUNCTION api.fn_serial_attach_issue(
  p_book_id   bigint,
  p_serial_id bigint
)
RETURNS public.books
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $function$
DECLARE
  r      public.books;
  v_old  bigint;
  v_lib  uuid;
BEGIN
  IF NOT public.fn_caller_is_staff() THEN
    RAISE EXCEPTION 'Acesso restrito ao staff de catalogacao.'
      USING ERRCODE = 'insufficient_privilege', HINT = 'error.serial.forbidden';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.serials WHERE id = p_serial_id) THEN
    RAISE EXCEPTION 'Périodique introuvable : %.', p_serial_id
      USING ERRCODE = 'no_data_found', HINT = 'error.serial.notFound';
  END IF;

  SELECT serial_id INTO v_old FROM public.books WHERE id = p_book_id;

  UPDATE public.books SET serial_id = p_serial_id WHERE id = p_book_id
  RETURNING * INTO r;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Document introuvable : %.', p_book_id
      USING ERRCODE = 'no_data_found', HINT = 'error.serial.issue.notFound';
  END IF;

  -- Recalcul pour CHAQUE bibliothèque détentrice, et pour l'ANCIEN titre s'il
  -- y en avait un : sans cela, un fascicule déplacé d'un titre à l'autre
  -- laisserait le premier avec un comptage trop haut, définitivement.
  FOR v_lib IN SELECT h.library_id FROM public.book_holdings h WHERE h.book_id = p_book_id LOOP
    IF v_old IS NOT NULL AND v_old <> p_serial_id THEN
      PERFORM public.fn_recompute_serial_holdings(v_old, v_lib);
    END IF;
    PERFORM public.fn_recompute_serial_holdings(p_serial_id, v_lib);
  END LOOP;

  RETURN r;
END $function$;

COMMENT ON FUNCTION api.fn_serial_attach_issue(bigint, bigint) IS
  'Rattache un fascicule à son titre d''autorité et recalcule l''état de '
  'collection de chaque bibliothèque détentrice — ainsi que celui de l''ANCIEN '
  'titre, sans quoi un fascicule déplacé y laisserait un comptage trop haut. '
  'Ne touche pas à titulo_periodico (forme transcrite). Staff de catalogage. '
  'Recalcul ajouté par le paquet PÉRIODIQUES P4.';

CREATE OR REPLACE FUNCTION api.fn_serial_detach_issue(p_book_id bigint)
RETURNS public.books
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $function$
DECLARE
  r     public.books;
  v_old bigint;
  v_lib uuid;
BEGIN
  IF NOT public.fn_caller_is_staff() THEN
    RAISE EXCEPTION 'Acesso restrito ao staff de catalogacao.'
      USING ERRCODE = 'insufficient_privilege', HINT = 'error.serial.forbidden';
  END IF;

  SELECT serial_id INTO v_old FROM public.books WHERE id = p_book_id;

  UPDATE public.books SET serial_id = NULL WHERE id = p_book_id
  RETURNING * INTO r;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Document introuvable : %.', p_book_id
      USING ERRCODE = 'no_data_found', HINT = 'error.serial.issue.notFound';
  END IF;

  IF v_old IS NOT NULL THEN
    FOR v_lib IN SELECT h.library_id FROM public.book_holdings h WHERE h.book_id = p_book_id LOOP
      PERFORM public.fn_recompute_serial_holdings(v_old, v_lib);
    END LOOP;
  END IF;

  RETURN r;
END $function$;

COMMENT ON FUNCTION api.fn_serial_detach_issue(bigint) IS
  'Retire le lien d''un fascicule vers son titre et recalcule l''état de '
  'collection des bibliothèques détentrices. titulo_periodico est conservé. '
  'Staff de catalogage. Recalcul ajouté par le paquet PÉRIODIQUES P4.';

-- -------------------------------------------------------------------------
-- 7. Vérification automatique
-- -------------------------------------------------------------------------
-- Vérification STRUCTURELLE. Le comportement (pas de ligne vide, déclaré
-- préservé par le recalcul, retour à 0) est couvert par la suite
-- tests/sql/periodiques_tests.sql, qui tourne après le seed.
DO $verif$
BEGIN
  -- 1. RLS active et les deux policies de lecture en place.
  IF NOT (SELECT relrowsecurity FROM pg_class WHERE oid = 'public.serial_holdings'::regclass) THEN
    RAISE EXCEPTION 'public.serial_holdings : RLS non activée.';
  END IF;
  IF (SELECT count(*) FROM pg_policies
       WHERE schemaname = 'public' AND tablename = 'serial_holdings') <> 2 THEN
    RAISE EXCEPTION 'public.serial_holdings : nombre de policies inattendu.';
  END IF;

  -- 2. La lecture publique exige la visibilité de la bibliothèque, pas
  --    seulement is_public — c'est le point qui empêche une bibliothèque
  --    privée de publier son état de collection.
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
     WHERE schemaname = 'public' AND tablename = 'serial_holdings'
       AND policyname = 'serial_holdings_select_public'
       AND qual LIKE '%fn_library_visible_to_caller%') THEN
    RAISE EXCEPTION 'serial_holdings_select_public ne vérifie pas la visibilité de la bibliothèque.';
  END IF;

  -- 3. Aucune écriture directe : tout passe par la RPC.
  IF has_table_privilege('anon', 'public.serial_holdings', 'INSERT')
     OR has_table_privilege('authenticated', 'public.serial_holdings', 'UPDATE') THEN
    RAISE EXCEPTION 'public.serial_holdings : des droits d''écriture directs subsistent.';
  END IF;

  -- 4. Le recalcul ne touche PAS aux colonnes déclarées. On le lit dans le
  --    corps plutôt que de l'espérer : c'est la doctrine du paquet.
  IF pg_get_functiondef('public.fn_recompute_serial_holdings(bigint,uuid)'::regprocedure)
     ~* '(set|,)\s*(statement|gaps_note|completeness|is_public)\s*=' THEN
    RAISE EXCEPTION 'fn_recompute_serial_holdings écrit sur une colonne DÉCLARÉE — le calcul ne doit jamais remplacer le déclaré.';
  END IF;

  -- 5. attach / detach ont bien reçu le recalcul.
  IF pg_get_functiondef('api.fn_serial_attach_issue(bigint,bigint)'::regprocedure)
     NOT LIKE '%fn_recompute_serial_holdings%'
     OR pg_get_functiondef('api.fn_serial_detach_issue(bigint)'::regprocedure)
     NOT LIKE '%fn_recompute_serial_holdings%' THEN
    RAISE EXCEPTION 'P4 : le rattachement/détachement ne recalcule pas l''état de collection.';
  END IF;

  -- 6. La vue publique est en security_invoker (sinon elle contournerait la RLS).
  IF NOT EXISTS (
    SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
     WHERE n.nspname = 'api' AND c.relname = 'serial_holdings_public_v1'
       AND c.reloptions @> ARRAY['security_invoker=true']) THEN
    RAISE EXCEPTION 'api.serial_holdings_public_v1 n''est pas en security_invoker.';
  END IF;

  RAISE NOTICE 'Paquet PÉRIODIQUES P4 : vérifications structurelles OK (RLS, visibilité, droits, calcul non intrusif, recalcul branché).';
END $verif$;

COMMIT;

NOTIFY pgrst, 'reload schema';

-- =========================================================================
-- Rollback ciblé :
-- =========================================================================
-- BEGIN;
--   DROP VIEW IF EXISTS api.serial_holdings_public_v1;
--   DROP FUNCTION IF EXISTS api.fn_serial_upsert_holdings(bigint, uuid, text, text, text, boolean);
--   DROP FUNCTION IF EXISTS public.fn_recompute_serial_holdings(bigint, uuid);
--   DROP TABLE IF EXISTS public.serial_holdings;
--   DROP FUNCTION IF EXISTS public.fn_serial_caller_is_library_staff(uuid);
--   -- puis réappliquer les corps P2 de fn_serial_attach_issue / fn_serial_detach_issue
-- COMMIT;
-- =========================================================================
