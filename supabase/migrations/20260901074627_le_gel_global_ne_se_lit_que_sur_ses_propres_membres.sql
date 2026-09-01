-- B14, lot `api`, paquet 2 : `get_member_restriction` lisait le gel global
-- de n'importe quel compte, y compris étranger à la bibliothèque.
--
-- CE QUE LA FONCTION FAISAIT. Sa garde est juste — `user_can_act_as_staff_on_library
-- (p_library_id)` : il faut être staff de LA bibliothèque passée en paramètre.
-- Le bloc LOCAL respecte ce cadre (il filtre sur `library_id = p_library_id`).
-- Le bloc GLOBAL, lui, lit `public.profiles WHERE id = p_user_id` **sans aucun
-- lien avec la bibliothèque**. Un·e staff de n'importe quelle bibliothèque
-- pouvait donc demander, pour n'importe quel UUID du réseau, si la personne est
-- gelée globalement, DEPUIS QUAND, POURQUOI (texte libre motivant un acte
-- disciplinaire réseau) et PAR QUI — le champ `by_name` retombant même sur
-- l'e-mail de l'admin réseau quand son profil n'a pas de nom.
--
-- La garde vérifiait donc une relation (staff de cette biblio) que la requête
-- suivante n'utilisait pas. C'est la forme du 18/05 : un identifiant en
-- paramètre, une donnée nominative en retour — ici la raison d'une sanction.
--
-- FUITE DORMANTE, comme celle du paquet 1 (`get_due_date_for_loan`) : relevé du
-- 01/09/2026, `profiles.is_restricted = true` sur **zéro** compte. Rien à lire
-- aujourd'hui ; tout à lire au premier gel posé, sans qu'un signal l'annonce.
-- Deux fuites dormantes en deux paquets, même mécanique — la garde d'une
-- fonction ne protège que les lignes qui s'y réfèrent.
--
-- LE CORRECTIF. Le bloc global est borné à la même relation que la garde : on
-- ne le renseigne que si la personne visée est effectivement membre de la
-- bibliothèque dont l'appelant·e est staff (statut hors 'removed'/'terminated',
-- pour couvrir une adhésion suspendue ou en attente — c'est justement là qu'on
-- veut savoir). Hors de ce cadre, `global` rend `is_restricted: false` sans
-- motif ni auteur : la fonction ne dit rien plutôt que de mentir, et l'appel
-- reste `ok: true` — aucun front ne casse.
--
-- USAGE RÉEL PRÉSERVÉ, vérifié dans le dépôt : les trois appels
-- (`PanelPage.jsx:1386`, `TabLeitor.jsx:352` et `:407`) passent tous le profil
-- d'un lecteur DÉJÀ résolu comme membre de `libraryId`. Le bornage ne retire
-- donc rien à personne.

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
  v_est_membre boolean;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'not_authenticated');
  END IF;

  IF NOT public.user_can_act_as_staff_on_library(p_library_id) THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'not_authorized');
  END IF;

  -- La relation que la garde vérifie : la personne visée appartient-elle à la
  -- bibliothèque dont l'appelant·e est staff ? Tout ce qui suit s'y borne.
  SELECT EXISTS (
    SELECT 1 FROM public.user_library_memberships m
    WHERE m.user_id = p_user_id
      AND m.library_id = p_library_id
      AND COALESCE(m.status, '') NOT IN ('removed', 'terminated')
  ) INTO v_est_membre;

  -- Restriction LOCALE (membership actif du membre dans cette biblio)
  SELECT m.is_restricted, m.restricted_reason, m.restricted_by, m.restricted_at,
         COALESCE(NULLIF(btrim(pb.first_name || ' ' || COALESCE(pb.last_name, '')), ''), pb.email) AS by_name
    INTO v_local
  FROM public.user_library_memberships m
  LEFT JOIN public.profiles pb ON pb.id = m.restricted_by
  WHERE m.user_id = p_user_id AND m.library_id = p_library_id AND m.status = 'active'
  LIMIT 1;

  -- Gel GLOBAL (profile) — SEULEMENT sur ses propres membres.
  IF v_est_membre THEN
    SELECT pr.is_restricted, pr.restricted_reason, pr.restricted_by, pr.restricted_since,
           COALESCE(NULLIF(btrim(pg.first_name || ' ' || COALESCE(pg.last_name, '')), ''), pg.email) AS by_name
      INTO v_global
    FROM public.profiles pr
    LEFT JOIN public.profiles pg ON pg.id = pr.restricted_by
    WHERE pr.id = p_user_id
    LIMIT 1;
  END IF;

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
  'État de restriction d''un membre, pour le staff de SA bibliothèque. Le bloc global (gel réseau, sa raison, son auteur) n''est renseigné que si la personne visée est membre de p_library_id — durci le 01/09/2026 (B14) : il se lisait auparavant sur n''importe quel UUID du réseau. Point ouvert consigné dans AUDIT_execute_authenticated_2026-09-01 : by_name retombe sur l''e-mail quand le profil de l''auteur n''a pas de nom.';

DO $$
BEGIN
  IF NOT has_function_privilege('authenticated', 'api.get_member_restriction(uuid, uuid)', 'EXECUTE') THEN
    RAISE EXCEPTION 'get_member_restriction a perdu EXECUTE pour authenticated — le Painel casserait, rollback';
  END IF;
END $$;
