-- Dette de B20 soldée : `fn_assembleia_facilitator_name` cesse d'être un annuaire.
--
-- ============================================================================
-- LE DÉFAUT, ET LA SOLUTION RETENUE (Xavier, 02/09/2026 — « ok pour la 2 »)
-- ============================================================================
-- La vue `api.assembleia_facilitators_v1` (security_invoker, lue par
-- AssembleiasTab) affiche le nom des facilitateur·rices en appelant une
-- fonction SECURITY DEFINER qui lit `profiles` à la place de la personne
-- connectée. Sa seule condition était « la personne cherchée est facilitatrice
-- QUELQUE PART » : n'importe quel compte connecté, même sans appartenance,
-- obtenait le nom de toute personne facilitant une assemblée quelconque —
-- un annuaire par ricochet (FED-7). Fermée pour cela le 01/09 (B14 paquet 7),
-- ROUVERTE le 02/09 parce que la vue en dépendait (20260902175631) : l'écran
-- était rendu, pas la garde.
--
-- Deux chemins possibles. (1) La jointure sous RLS dans la vue — propre, mais
-- les noms disparaissent si la RLS de `profiles` ne montre que le sien.
-- (2) **Garder la fonction et la scoper juste** : elle reçoit AUSSI
-- l'assemblée, et ne rend le nom que si la personne connectée VOIT cette
-- assemblée — exactement la condition de la policy `assembleias_select`
-- (`fn_caller_attached_member() OR fn_caller_is_network_admin()`) — et que
-- la personne cherchée y est bien facilitatrice. Retenu : l'écran garde ses
-- noms, la fonction perd son pouvoir d'énumération, et la garde vit dans le
-- corps (DOC-RPC-3), pas dans le grant.
--
-- L'ancienne signature (uuid) DISPARAÎT : la garder ouverte serait garder
-- l'oracle. La vue est recréée avec `WITH (security_invoker = true)` — un
-- CREATE OR REPLACE VIEW nu réinitialise cette option (piège du 31/08).

-- 1) La fonction scopée, sous son nom (les suites qui la gardent par nom
--    restent vraies : une_vue_appelle_aussi_tests T3, pg_depend).
CREATE OR REPLACE FUNCTION public.fn_assembleia_facilitator_name(p_assembleia_id uuid, p_user_id uuid)
RETURNS text
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path TO 'public', 'auth', 'pg_temp'
AS $$
  SELECT nullif(trim(coalesce(p.first_name, '') || ' ' || coalesce(p.last_name, '')), '')
    FROM public.profiles p
   WHERE p.id = p_user_id
     -- la même porte que la vue : qui voit l'assemblée voit ses facilitateur·rices
     AND (public.fn_caller_attached_member() OR public.fn_caller_is_network_admin())
     -- et seulement pour CETTE assemblée
     AND EXISTS (SELECT 1 FROM public.assembleia_facilitators f
                  WHERE f.assembleia_id = p_assembleia_id AND f.user_id = p_user_id);
$$;

REVOKE EXECUTE ON FUNCTION public.fn_assembleia_facilitator_name(uuid, uuid) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.fn_assembleia_facilitator_name(uuid, uuid) TO authenticated, service_role;

COMMENT ON FUNCTION public.fn_assembleia_facilitator_name(uuid, uuid) IS
  'Nom d''une personne facilitatrice d''UNE assemblée donnée, rendu seulement à qui voit l''assemblée (même porte que assembleias_select : membre rattaché·e ou admin réseau). Remplace la forme (uuid) du 02/09/2026, qui rendait le nom de tout·e facilitateur·rice de n''importe quelle assemblée à n''importe quel compte connecté — un annuaire par ricochet (FED-7). Solution 2 de la dette B20, arbitrage Xavier. Appelée par api.assembleia_facilitators_v1 (security_invoker).';

-- 2) La vue, recréée avec son option — et avec les deux arguments.
CREATE OR REPLACE VIEW api.assembleia_facilitators_v1 WITH (security_invoker = true) AS
  SELECT f.id,
         f.assembleia_id,
         f.user_id,
         f.status,
         f.designated_at,
         public.fn_assembleia_facilitator_name(f.assembleia_id, f.user_id) AS display_name
    FROM public.assembleia_facilitators f;

COMMENT ON VIEW api.assembleia_facilitators_v1 IS
  'Volontaires (status=volunteer) et facilitateur·rices désigné·es (status=designated) d''une assemblée visible. display_name résolu par un helper definer scopé à l''assemblée ET au droit de la voir (20260902183505). security_invoker. Paquet ASSEMBLEIAS P2c.';

-- 3) L'oracle disparaît.
DROP FUNCTION public.fn_assembleia_facilitator_name(uuid);

-- ============================================================================
-- GARDES DE FIN
-- ============================================================================
DO $$
DECLARE v_n int;
BEGIN
  -- a) l'ancienne forme n'existe plus, la nouvelle existe
  IF EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
              WHERE n.nspname = 'public' AND p.proname = 'fn_assembleia_facilitator_name' AND p.pronargs = 1) THEN
    RAISE EXCEPTION 'la forme (uuid) survit — l''oracle serait toujours là — rollback';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
                  WHERE n.nspname = 'public' AND p.proname = 'fn_assembleia_facilitator_name' AND p.pronargs = 2) THEN
    RAISE EXCEPTION 'la forme (uuid, uuid) manque — rollback';
  END IF;

  -- b) droits : ouverte à authenticated (la vue l'appelle sous le rôle du lecteur), fermée à anon
  IF NOT has_function_privilege('authenticated', 'public.fn_assembleia_facilitator_name(uuid, uuid)', 'EXECUTE') THEN
    RAISE EXCEPTION 'authenticated sans EXECUTE — AssembleiasTab rendrait 403 — rollback';
  END IF;
  IF has_function_privilege('anon', 'public.fn_assembleia_facilitator_name(uuid, uuid)', 'EXECUTE') THEN
    RAISE EXCEPTION 'anon a EXECUTE — rollback';
  END IF;

  -- c) la vue est en security_invoker et dépend bien de la nouvelle forme
  SELECT count(*) INTO v_n
    FROM pg_class c
    JOIN pg_rewrite rw ON rw.ev_class = c.oid
    JOIN pg_depend d ON d.classid = 'pg_rewrite'::regclass AND d.objid = rw.oid AND d.refclassid = 'pg_proc'::regclass
    JOIN pg_proc p ON p.oid = d.refobjid
   WHERE c.relnamespace = 'api'::regnamespace AND c.relname = 'assembleia_facilitators_v1'
     AND 'security_invoker=true' = ANY (c.reloptions)
     AND p.proname = 'fn_assembleia_facilitator_name' AND p.pronargs = 2;
  IF v_n = 0 THEN
    RAISE EXCEPTION 'la vue n''est pas en security_invoker ou n''appelle pas la forme scopée — rollback';
  END IF;
END $$;
