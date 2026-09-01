-- B14, lot `api`, paquet 2 — correctif du correctif, 15 minutes après.
--
-- CE QUI S'EST PASSÉ. La migration `20260901074627` a borné le bloc GLOBAL de
-- `get_member_restriction` à la relation vérifiée par la garde — c'était le bon
-- correctif de sécurité, et il tient. Mais elle l'a écrit avec un `IF … THEN
-- SELECT … INTO v_global; END IF;` : sur le chemin où la personne visée n'est
-- PAS membre, la branche est sautée, le `record` n'est jamais assigné, et la
-- lecture suivante de `v_global.is_restricted` lève
-- `record "v_global" is not assigned yet` au lieu de rendre un bloc vide.
--
-- En PL/pgSQL, un `SELECT INTO` sans résultat **assigne** le record (champs à
-- NULL) ; c'est de ne pas l'exécuter du tout qui laisse la structure
-- indéterminée. La version d'origine ne pouvait pas rencontrer le cas : ses
-- deux SELECT s'exécutaient toujours.
--
-- CE QUI L'A ATTRAPÉ. La suite écrite dans le même commit,
-- `b14_api_gel_global_borne_tests.sql` : T1 — le seul test qui emprunte le
-- chemin « personne étrangère » — a échoué en CI sur base fraîche, T2 et T3
-- passant. Le défaut n'était pas une fuite (rien ne sortait) mais un refus
-- bruyant là où on attendait un silence ; c'est exactement ce que T1 affirmait
-- (« on attend un silence, pas une erreur »).
--
-- PORTÉE RÉELLE EN PRODUCTION, mesurée avant d'écrire : la version fautive y a
-- été déployée (le job `backend` a réussi pendant que `sql-tests` rougissait).
-- Les trois appels du front passent tous un lecteur DÉJÀ résolu comme membre :
-- le chemin fautif n'était atteignable par aucun écran. Aucune fuite non plus —
-- le bornage fonctionnait. Le risque était un plantage sur un usage futur.
--
-- LE CORRECTIF. La condition de relation passe dans le `WHERE` du SELECT, qui
-- s'exécute donc toujours : record assigné, champs NULL hors périmètre, bloc
-- global vide. Une seule requête, aucune branche — la forme qui ne peut pas
-- retomber dans ce piège.

CREATE OR REPLACE FUNCTION api.get_member_restriction(p_user_id uuid, p_library_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_local  record;
  v_global record;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'not_authenticated');
  END IF;

  IF NOT public.user_can_act_as_staff_on_library(p_library_id) THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'not_authorized');
  END IF;

  -- Restriction LOCALE (membership actif du membre dans cette biblio)
  SELECT m.is_restricted, m.restricted_reason, m.restricted_by, m.restricted_at,
         COALESCE(NULLIF(btrim(pb.first_name || ' ' || COALESCE(pb.last_name, '')), ''), pb.email) AS by_name
    INTO v_local
  FROM public.user_library_memberships m
  LEFT JOIN public.profiles pb ON pb.id = m.restricted_by
  WHERE m.user_id = p_user_id AND m.library_id = p_library_id AND m.status = 'active'
  LIMIT 1;

  -- Gel GLOBAL (profile) — borné à la relation que la garde vérifie : la
  -- personne visée est membre de la bibliothèque dont l'appelant·e est staff.
  -- La condition vit dans le WHERE, pas dans un IF : le SELECT INTO s'exécute
  -- toujours, donc le record est TOUJOURS assigné (champs NULL hors périmètre).
  -- Une branche sautée laisserait la structure indéterminée et ferait lever la
  -- fonction — c'est le défaut introduit puis corrigé le 01/09.
  SELECT pr.is_restricted, pr.restricted_reason, pr.restricted_by, pr.restricted_since,
         COALESCE(NULLIF(btrim(pg.first_name || ' ' || COALESCE(pg.last_name, '')), ''), pg.email) AS by_name
    INTO v_global
  FROM public.profiles pr
  LEFT JOIN public.profiles pg ON pg.id = pr.restricted_by
  WHERE pr.id = p_user_id
    AND EXISTS (
      SELECT 1 FROM public.user_library_memberships m
      WHERE m.user_id = p_user_id
        AND m.library_id = p_library_id
        AND COALESCE(m.status, '') NOT IN ('removed', 'terminated')
    )
  LIMIT 1;

  RETURN jsonb_build_object(
    'ok', true,
    'local', jsonb_build_object(
      'is_restricted', COALESCE(v_local.is_restricted, false),
      'reason',        v_local.restricted_reason,
      'by',            v_local.restricted_by,
      'by_name',       v_local.by_name,
      'at',            v_local.restricted_at
    ),
    'global', jsonb_build_object(
      'is_restricted', COALESCE(v_global.is_restricted, false),
      'reason',        v_global.restricted_reason,
      'by',            v_global.restricted_by,
      'by_name',       v_global.by_name,
      'since',         v_global.restricted_since
    )
  );
END;
$function$;

COMMENT ON FUNCTION api.get_member_restriction(uuid, uuid) IS
  'État de restriction d''un membre, pour le staff de SA bibliothèque. Le bloc global (gel réseau, sa raison, son auteur) n''est renseigné que si la personne visée est membre de p_library_id — bornage posé le 01/09/2026 (B14), condition dans le WHERE et non dans un IF pour que le record soit toujours assigné. Point ouvert consigné dans AUDIT_execute_authenticated_2026-09-01 : by_name retombe sur l''e-mail quand le profil de l''auteur n''a pas de nom.';

DO $$
BEGIN
  IF NOT has_function_privilege('authenticated', 'api.get_member_restriction(uuid, uuid)', 'EXECUTE') THEN
    RAISE EXCEPTION 'get_member_restriction a perdu EXECUTE pour authenticated — rollback';
  END IF;
END $$;
