-- Décision du 01/09/2026 : les cinq gardes en `WHERE` rejoignent `DOC-SILENCE-1`.
--
-- ============================================================================
-- LA QUESTION, ET COMMENT ELLE A ÉTÉ TRANCHÉE
-- ============================================================================
-- Cinq fonctions réseau mettaient leur garde **dans le `WHERE`** plutôt que dans
-- un `IF` : un appel non autorisé y rendait **zéro ligne au lieu d'une erreur**.
--
--   * `fn_list_library_request_invitations`  — `where fn_caller_is_network_admin()`
--   * `fn_list_orphan_library_mentions`      — idem
--   * `fn_network_library_metrics`           — `where fn_current_user_can_view_network_metrics()`
--   * `fn_network_list_library_requests`     — `where fn_current_user_can_review_library_requests()`
--   * `fn_network_get_library_request`       — idem (trouvée au paquet 4)
--
-- Le paquet 3 du lot `api` avait corrigé six fonctions de cette forme au nom de
-- `DOC-SILENCE-1`. Ici, la forme était **délibérée et commentée** — d'où une
-- question posée au collectif plutôt qu'un correctif appliqué seul. Réponse du
-- 01/09 : **on aligne**. Ce que rend le silence n'est pas rien, c'est une
-- phrase : « le réseau n'a aucune bibliothèque », « aucune candidature
-- n'attend ». Le jour où une candidature n'apparaît pas, personne ne peut
-- distinguer « il n'y en a pas » de « tu n'as pas le droit de la voir ».
--
-- ============================================================================
-- LA FORME, ET POURQUOI ELLE N'EST PAS CELLE QU'ON ATTENDAIT
-- ============================================================================
-- Ces cinq fonctions sont en `LANGUAGE sql` : on ne peut pas y ouvrir un bloc
-- `IF`. La solution évidente — les convertir en `plpgsql` — demanderait de
-- réécrire cinq corps pour n'y changer qu'une garde, exactement ce que
-- `DOC-MSG-1` interdit depuis qu'il a coûté trois CI rouges.
--
-- On garde donc le `WHERE`, et on y met un prédicat qui **lève** au lieu de
-- rendre `false`. Le corps n'est jamais retapé : trois helpers assertifs sont
-- créés, puis substitués par `pg_get_functiondef` avec contrôle que la
-- substitution a bien eu lieu.
--
-- **Ce qui a été vérifié avant d'y compter** : un prédicat levant placé dans un
-- `WHERE` se déclenche-t-il quand la relation est **vide** ? C'est le cas qui
-- compte — une garde qui ne mordrait que sur une table peuplée ne garderait
-- rien. Mesuré en production sur deux tables temporaires : `table_vide=LEVEE`,
-- `table_pleine=LEVEE`. PostgreSQL traite un qual constant en filtre évalué une
-- fois, avant le parcours.
--
-- **La limite, écrite parce qu'elle est réelle** : cela dépend du plan choisi.
-- Un plan qui n'exécuterait jamais le nœud portant le filtre n'évaluerait pas la
-- garde. C'est pourquoi la suite `tests/sql/refus_reseau_se_dit_tests.sql`
-- **appelle réellement les cinq fonctions** sous un JWT non autorisé au lieu de
-- relire leur définition : si un jour un plan change, le test rougit.
--
-- ============================================================================
-- ÉPREUVE (production, transaction annulée, dans les deux sens)
-- ============================================================================
--   compte ordinaire : orphan=REFUS  metrics=REFUS  requests=REFUS  invit=REFUS
--   admin réseau     : metrics=OK(4) requests=OK(1) orphan=OK(0)
--
-- La dernière ligne est le bénéfice même de la décision : `OK(0)` est un vrai
-- zéro, et il ne se confond plus avec un refus.
--
-- Aucun droit ne change : ces cinq fonctions refusaient déjà les mêmes
-- personnes. On corrige ce qu'elles **disent** en refusant.

-- ============================================================================
-- LES TROIS HELPERS ASSERTIFS
-- ============================================================================
-- `SECURITY INVOKER` volontairement : ils ne font que retourner ou lever, et les
-- prédicats qu'ils enveloppent portent déjà leur propre `SECURITY DEFINER`.
-- Ajouter un definer ici élargirait la surface sans rien apporter.

CREATE OR REPLACE FUNCTION public.fn_assert_network_admin()
RETURNS boolean
LANGUAGE plpgsql
STABLE
SET search_path = public, auth
AS $$
BEGIN
  IF public.fn_caller_is_network_admin() THEN
    RETURN true;
  END IF;
  RAISE EXCEPTION 'forbidden: network administration' USING ERRCODE = '42501';
END $$;

COMMENT ON FUNCTION public.fn_assert_network_admin() IS
  'Variante LEVANTE de fn_caller_is_network_admin, pour les gardes placées dans un WHERE de fonction SQL — où un prédicat qui rend false donnerait une liste vide au lieu d''un refus (DOC-SILENCE-1, décision du 01/09/2026). Ne pas utiliser là où le prédicat ÉLARGIT un accès public : il y transformerait une navigation anonyme en erreur.';

CREATE OR REPLACE FUNCTION public.fn_assert_can_view_network_metrics()
RETURNS boolean
LANGUAGE plpgsql
STABLE
SET search_path = public, auth
AS $$
BEGIN
  IF public.fn_current_user_can_view_network_metrics() THEN
    RETURN true;
  END IF;
  RAISE EXCEPTION 'forbidden: network metrics' USING ERRCODE = '42501';
END $$;

COMMENT ON FUNCTION public.fn_assert_can_view_network_metrics() IS
  'Variante levante de fn_current_user_can_view_network_metrics (voir fn_assert_network_admin).';

CREATE OR REPLACE FUNCTION public.fn_assert_can_review_library_requests()
RETURNS boolean
LANGUAGE plpgsql
STABLE
SET search_path = public, auth
AS $$
BEGIN
  IF public.fn_current_user_can_review_library_requests() THEN
    RETURN true;
  END IF;
  RAISE EXCEPTION 'forbidden: library requests review' USING ERRCODE = '42501';
END $$;

COMMENT ON FUNCTION public.fn_assert_can_review_library_requests() IS
  'Variante levante de fn_current_user_can_review_library_requests (voir fn_assert_network_admin).';

-- ============================================================================
-- SUBSTITUTION DANS LES CINQ — PAR LISTE NOMMÉE, ET C'EST VOULU
-- ============================================================================
-- On ne substitue PAS par motif sur tout le schéma : dans plusieurs fonctions,
-- `fn_caller_is_network_admin()` **élargit** un accès au lieu de le restreindre
-- (`list_catalog_libraries`, `fn_team_list_invitations` : « ... OR admin réseau »).
-- Y mettre un prédicat levant transformerait une navigation ordinaire en erreur.
-- La liste est donc nommée, et le paquet 5 a vérifié chacun de ces cinq cas.

DO $$
DECLARE
  r record;
  v_def text;
  v_new text;
  n int := 0;
BEGIN
  FOR r IN
    SELECT p.oid, p.proname
      FROM pg_proc p JOIN pg_namespace ns ON ns.oid = p.pronamespace
     WHERE ns.nspname = 'public'
       AND p.proname IN ('fn_list_library_request_invitations',
                         'fn_list_orphan_library_mentions',
                         'fn_network_library_metrics',
                         'fn_network_list_library_requests',
                         'fn_network_get_library_request')
  LOOP
    v_def := pg_get_functiondef(r.oid);
    v_new := replace(v_def, 'public.fn_caller_is_network_admin()',
                            'public.fn_assert_network_admin()');
    v_new := replace(v_new, 'public.fn_current_user_can_view_network_metrics()',
                            'public.fn_assert_can_view_network_metrics()');
    v_new := replace(v_new, 'public.fn_current_user_can_review_library_requests()',
                            'public.fn_assert_can_review_library_requests()');

    IF v_new = v_def THEN
      RAISE EXCEPTION 'public.% : aucun prédicat substitué — la garde a changé de forme, migration interrompue plutôt que sans effet', r.proname;
    END IF;

    EXECUTE v_new;
    n := n + 1;
  END LOOP;

  RAISE NOTICE 'gardes rendues levantes sur % fonction(s)', n;
END $$;

-- ============================================================================
-- GARDE DE FIN
-- ============================================================================
DO $$
DECLARE v_reste text;
BEGIN
  -- Les cinq portent bien le prédicat levant.
  SELECT string_agg(p.proname, ', ')
    INTO v_reste
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public'
     AND p.proname IN ('fn_list_library_request_invitations','fn_list_orphan_library_mentions',
                       'fn_network_library_metrics','fn_network_list_library_requests',
                       'fn_network_get_library_request')
     AND p.prosrc !~ 'fn_assert_';

  IF v_reste IS NOT NULL THEN
    RAISE EXCEPTION 'garde muette subsistante sur : % — rollback', v_reste;
  END IF;

  -- Et les fonctions où le prédicat ÉLARGIT n'ont PAS été touchées : une garde
  -- levante y casserait la navigation au lieu de la protéger.
  IF EXISTS (
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = 'public'
       AND p.proname IN ('list_catalog_libraries','fn_team_list_invitations')
       AND p.prosrc ~ 'fn_assert_'
  ) THEN
    RAISE EXCEPTION 'un prédicat levant a été posé sur une garde ÉLARGISSANTE — rollback';
  END IF;
END $$;
