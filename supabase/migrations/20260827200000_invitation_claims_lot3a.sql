-- =============================================================================
-- Invitation d'une bibliotheque — LOT 3a : note scindee, nom rendu, purge
-- =============================================================================
-- Date     : 2026-08-27
-- Ref      : docs/journal/cadrages/CADRAGE_invitation_bibliotheque_2026-08-27.md
-- Suite de : 20260827120000 (lot 1, schema) · 20260827170000 (lot 2, RPC)
--
-- Trois bornes du paragraphe 8 tranchees le 27/08/2026 :
--
--   A1 — La personne invitee voit le nom de la bibliotheque avant meme de
--        creer son compte. fn_get_library_request_claim_context le rend donc
--        desormais. Sans ca, le lien dit « quelqu'un vous a envoye ceci » la
--        ou il doit dire « AnarBib invite la Bibliotheque X ».
--
--   A3 — L'invitation est signee INSTITUTIONNELLEMENT (« la coordination du
--        reseau »), jamais nominativement. Consequence directe : la fonction de
--        contexte, qui est ouverte a `anon`, ne rend AUCUNE information sur
--        l'admin emetteur. created_by_user_id reste en base pour l'audit, il
--        n'en sort pas. C'est coherent avec la doctrine du depot, ou tout vote
--        porte un `disclose_identity` explicite : l'identite n'est jamais
--        divulguee par defaut.
--
--   A4 — LE CHAMP `note` EST SCINDE EN DEUX, et c'est le point important.
--        Un champ libre unique, rendu aux admins par la liste, allait servir
--        aussi bien a « rencontree a Bologne » qu'a « mefiants, y aller
--        doucement ». Le jour ou un lot suivant l'aurait affiche a la personne
--        invitee — parce qu'il etait la, et qu'il ressemblait a un message —
--        la fuite aurait ete silencieuse et irrattrapable. Deux champs, deux
--        destinations, plus aucune ambiguite possible :
--          * note_interne         : jamais rendue a la personne invitee.
--                                   Seule la liste (admins) la voit.
--          * mot_accompagnement   : ecrit POUR elle, destine au mail.
--        La regle ne tient pas a la vigilance de qui codera l'ecran : elle
--        tient au nom des colonnes.
--
--   B  — PURGE A 45 JOURS. `library_request_claims` est dans
--        deploy/bg2-known-tables.txt mais PAS dans la denylist PII : elle part
--        donc dans le flux de sauvegarde LONG (retention 7/4/6). C'etait
--        defendable tant que la table ne contenait que des auto-candidatures,
--        dont l'email duplique celui d'un compte tout juste cree — et
--        `profiles`, elle, est bien dans la denylist. Ca cesse d'etre vrai avec
--        les invitations : on y stocke l'adresse d'un TIERS qui n'a rien
--        demande et ne repondra peut-etre jamais.
--
--        45 jours apres son expiration ou sa revocation, une invitation perd
--        son email et ses deux notes. La LIGNE RESTE : qui a invite, quand,
--        pour quelle bibliotheque, avec quelle issue. L'audit survit, la donnee
--        personnelle non. `purged_at` horodate le geste.
--
--        Portee volontairement etroite : seules les invitations `expiree` ou
--        `revoquee`. Une invitation ABOUTIE n'est pas purgee ici — elle a
--        produit une library_request qui porte legitimement le contact — et les
--        auto-candidatures ne sont pas concernees du tout.
--
-- FORME. Les trois fonctions changent de signature de sortie ou d'entree :
-- CREATE OR REPLACE ne sait ni renommer un parametre ni changer les colonnes
-- rendues, d'ou DROP + CREATE. Les droits sont donc reposes explicitement
-- derriere chacune — un DROP les emporte, et les oublier ouvrirait ou fermerait
-- la porte en silence. Aucune invitation n'existe encore en base (verifie), le
-- DROP ne casse aucun lien vivant.
-- =============================================================================

-- ── 1. Purge : la colonne qui autorise l'effacement ─────────────────────────
ALTER TABLE public.library_request_claims
  ADD COLUMN IF NOT EXISTS purged_at timestamptz;

-- email_snapshot devient effacable — mais, comme user_id au lot 1, seulement
-- pour un cas NOMME. Une ligne sans email est une ligne purgee, jamais une
-- ligne mal ecrite.
ALTER TABLE public.library_request_claims ALTER COLUMN email_snapshot DROP NOT NULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'public.library_request_claims'::regclass
      AND conname = 'library_request_claims_email_ou_purge_chk'
  ) THEN
    ALTER TABLE public.library_request_claims
      ADD CONSTRAINT library_request_claims_email_ou_purge_chk
      CHECK (email_snapshot IS NOT NULL OR purged_at IS NOT NULL);
  END IF;
END $$;

COMMENT ON COLUMN public.library_request_claims.purged_at IS
  'Horodatage de la purge des donnees personnelles (email_snapshot, note_interne, mot_accompagnement) 45 jours apres expiration ou revocation d''une invitation. La ligne survit pour l''audit : qui a invite, quand, pour quelle bibliotheque, avec quelle issue.';

-- ── 2. Emettre : deux notes au lieu d'une ───────────────────────────────────
DROP FUNCTION IF EXISTS public.fn_create_library_request_invitation(text, text, text);

CREATE FUNCTION public.fn_create_library_request_invitation(
  p_email text,
  p_library_name text,
  p_note_interne text DEFAULT NULL,
  p_mot_accompagnement text DEFAULT NULL
) RETURNS TABLE(claim_id uuid, claim_token text, expires_at timestamptz)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'extensions'
    AS $fn$
declare
  c_ttl_jours constant int := 45;   -- D3
  v_email text;
  v_nom text;
  v_token text;
  v_row public.library_request_claims;
begin
  if not public.fn_caller_is_network_admin() then
    raise exception 'Seule l''administration du reseau peut inviter une bibliotheque.'
      using errcode = '42501', hint = 'error.library_invitation.not_network_admin';
  end if;

  v_email := lower(nullif(btrim(coalesce(p_email, '')), ''));
  if v_email is null then
    raise exception 'Indique l''adresse a inviter.'
      using errcode = '23514', hint = 'error.library_invitation.email_required';
  end if;

  v_nom := nullif(btrim(coalesce(p_library_name, '')), '');
  if v_nom is null then
    raise exception 'Indique le nom de la bibliotheque invitee.'
      using errcode = '23514', hint = 'error.library_invitation.library_name_required';
  end if;

  if exists (
    select 1 from public.library_request_claims c
     where c.claim_origin = 'invitation'
       and c.email_snapshot = v_email
       and c.used_at is null
       and c.revoked_at is null
       and c.expires_at > now()
  ) then
    raise exception 'Une invitation est deja en cours pour cette adresse. Revoque-la avant d''en emettre une autre.'
      using errcode = '23505', hint = 'error.library_invitation.already_pending';
  end if;

  v_token := rtrim(translate(encode(extensions.gen_random_bytes(32), 'base64'), '+/', '-_'), '=');

  insert into public.library_request_claims (
    user_id, email_snapshot, claim_token_hash, claim_purpose, claim_origin,
    expires_at, created_by_user_id, metadata
  ) values (
    null, v_email, public.fn_hash_claim_token(v_token), 'library_request', 'invitation',
    now() + make_interval(days => c_ttl_jours), auth.uid(),
    jsonb_strip_nulls(jsonb_build_object(
      'source', 'network_admin_invitation',
      'library_name', v_nom,
      -- A4 : deux champs, deux destinations. note_interne ne sort JAMAIS vers
      -- la personne invitee ; mot_accompagnement est ecrit pour elle.
      'note_interne', nullif(btrim(coalesce(p_note_interne, '')), ''),
      'mot_accompagnement', nullif(btrim(coalesce(p_mot_accompagnement, '')), '')
    ))
  )
  returning * into v_row;

  return query select v_row.id, v_token, v_row.expires_at;
end;
$fn$;

REVOKE ALL ON FUNCTION public.fn_create_library_request_invitation(text, text, text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.fn_create_library_request_invitation(text, text, text, text) FROM anon;
GRANT EXECUTE ON FUNCTION public.fn_create_library_request_invitation(text, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_create_library_request_invitation(text, text, text, text) TO service_role;

COMMENT ON FUNCTION public.fn_create_library_request_invitation(text, text, text, text) IS
  'Emet une invitation. Admins reseau seuls (D2), TTL 45 jours (D3), jeton rendu une seule fois. note_interne n''est JAMAIS montree a la personne invitee ; mot_accompagnement lui est destine (A4).';

-- ── 3. Contexte du claim : rendre le nom, et rien de l'emetteur ─────────────
DROP FUNCTION IF EXISTS public.fn_get_library_request_claim_context(text);

CREATE FUNCTION public.fn_get_library_request_claim_context(p_claim_token text)
RETURNS TABLE(
  claim_id uuid,
  email_snapshot text,
  expires_at timestamptz,
  claim_purpose text,
  is_valid boolean,
  claim_origin text,
  library_name text,
  mot_accompagnement text
)
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'extensions'
    AS $fn$
  -- Ouverte a `anon` : une personne invitee n'a pas encore de compte.
  -- Ne rend donc RIEN sur l'admin emetteur (A3 : signature institutionnelle),
  -- et surtout jamais metadata->>'note_interne' (A4).
  select
    c.id as claim_id,
    c.email_snapshot,
    c.expires_at,
    c.claim_purpose,
    true as is_valid,
    c.claim_origin,
    c.metadata->>'library_name' as library_name,
    c.metadata->>'mot_accompagnement' as mot_accompagnement
  from public.library_request_claims c
  where c.claim_token_hash = public.fn_hash_claim_token(btrim(p_claim_token))
    and c.claim_purpose = 'library_request'
    and c.used_at is null
    and c.expires_at > now()
    and c.revoked_at is null
  limit 1;
$fn$;

REVOKE ALL ON FUNCTION public.fn_get_library_request_claim_context(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_get_library_request_claim_context(text) TO anon;
GRANT EXECUTE ON FUNCTION public.fn_get_library_request_claim_context(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_get_library_request_claim_context(text) TO service_role;

COMMENT ON FUNCTION public.fn_get_library_request_claim_context(text) IS
  'SECURITY DEFINER intentional: valide un claim token et rend son contexte (accessible a anon : une personne invitee n''a pas encore de compte). Exclut les claims revoques. Rend le nom de la bibliotheque invitee (A1) et le mot d''accompagnement, JAMAIS la note interne (A4) ni l''identite de l''emetteur (A3).';

-- ── 4. Liste : les deux notes, pour les admins seuls ────────────────────────
DROP FUNCTION IF EXISTS public.fn_list_library_request_invitations(boolean);

CREATE FUNCTION public.fn_list_library_request_invitations(
  p_inclure_closes boolean DEFAULT false
) RETURNS TABLE(
  claim_id uuid,
  email_snapshot text,
  library_name text,
  note_interne text,
  mot_accompagnement text,
  etat text,
  created_at timestamptz,
  expires_at timestamptz,
  invitee_par uuid,
  reclamee_par uuid,
  used_by_request_id uuid,
  revoked_reason text,
  purged_at timestamptz
)
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'extensions'
    AS $fn$
  -- Jamais de jeton ni de hash. Ne montre que des invitations EMISES — des
  -- gestes deja poses, avec leur auteur·e et leur motif — pas des bibliotheques
  -- a demarcher (paragraphe 7 du cadrage).
  select
    c.id,
    c.email_snapshot,
    c.metadata->>'library_name',
    c.metadata->>'note_interne',
    c.metadata->>'mot_accompagnement',
    case
      when c.revoked_at is not null then 'revoquee'
      when c.used_at is not null    then 'aboutie'
      when c.expires_at <= now()    then 'expiree'
      when c.user_id is not null    then 'compte_cree'
      else                               'en_attente'
    end,
    c.created_at,
    c.expires_at,
    c.created_by_user_id,
    c.user_id,
    c.used_by_request_id,
    c.revoked_reason,
    c.purged_at
  from public.library_request_claims c
  where public.fn_caller_is_network_admin()
    and c.claim_origin = 'invitation'
    and (
      p_inclure_closes
      or (c.revoked_at is null and c.used_at is null and c.expires_at > now())
    )
  order by c.created_at desc;
$fn$;

REVOKE ALL ON FUNCTION public.fn_list_library_request_invitations(boolean) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.fn_list_library_request_invitations(boolean) FROM anon;
GRANT EXECUTE ON FUNCTION public.fn_list_library_request_invitations(boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_list_library_request_invitations(boolean) TO service_role;

COMMENT ON FUNCTION public.fn_list_library_request_invitations(boolean) IS
  'Liste les invitations emises. Admins reseau seuls — garde dans le where, donc un appel non autorise rend zero ligne. Jamais de jeton ni de hash. Rend les deux notes : c''est le seul endroit ou note_interne est lisible.';

-- ── 5. La purge elle-meme ───────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_purge_library_request_invitations()
RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'extensions'
    AS $fn$
declare
  c_delai_jours constant int := 45;   -- B
  v_purgees int;
begin
  with cibles as (
    select c.id
      from public.library_request_claims c
     where c.claim_origin = 'invitation'
       and c.purged_at is null
       and (
         (c.revoked_at is not null and c.revoked_at  < now() - make_interval(days => c_delai_jours))
         or
         (c.used_at is null and c.expires_at < now() - make_interval(days => c_delai_jours))
       )
  ), effacees as (
    update public.library_request_claims c
       set email_snapshot = null,
           metadata = (c.metadata - 'note_interne' - 'mot_accompagnement'),
           purged_at = now()
      from cibles t
     where c.id = t.id
     returning c.id
  )
  select count(*) into v_purgees from effacees;

  return jsonb_build_object('purgees', v_purgees, 'run_at', now());
end;
$fn$;

REVOKE ALL ON FUNCTION public.fn_purge_library_request_invitations() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.fn_purge_library_request_invitations() FROM anon;
REVOKE ALL ON FUNCTION public.fn_purge_library_request_invitations() FROM authenticated;
GRANT EXECUTE ON FUNCTION public.fn_purge_library_request_invitations() TO service_role;

COMMENT ON FUNCTION public.fn_purge_library_request_invitations() IS
  'Efface email et notes des invitations expirees ou revoquees depuis plus de 45 jours (B). La ligne survit pour l''audit. Ne touche ni aux invitations abouties (leur contact vit legitimement dans library_requests) ni aux auto-candidatures.';

-- ── 6. Le cron qui la fait tourner ──────────────────────────────────────────
-- Bloc do/exception : le harnais sql-tests reconstruit le schema SANS pg_cron,
-- un appel nu y rendrait la CI rouge.
DO $cron$
BEGIN
  PERFORM cron.schedule(
    'anarbib-purge-invitations-expirees',
    '40 3 * * *',
    'SELECT public.fn_purge_library_request_invitations();'
  );
  RAISE NOTICE 'Cron purge-invitations-expirees planifie (actif).';
EXCEPTION WHEN others THEN
  RAISE WARNING 'Cron purge-invitations-expirees NON planifie (cron indisponible ici ?) : %.', sqlerrm;
END
$cron$;
