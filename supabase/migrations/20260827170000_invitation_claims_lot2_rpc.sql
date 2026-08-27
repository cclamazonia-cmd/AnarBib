-- =============================================================================
-- Invitation d'une bibliotheque — LOT 2 : emettre, revoquer, lister
-- =============================================================================
-- Date     : 2026-08-27
-- Ref      : docs/journal/cadrages/CADRAGE_invitation_bibliotheque_2026-08-27.md
-- Suite de : 20260827120000 (lot 1, schema)
--
-- DECISIONS ACTEES LE 27/08/2026, qui donnent leur forme a ces trois RPC :
--
--   D2 — QUI PEUT INVITER : les administrateur·rices reseau actif·ves,
--        et personne d'autre. Les coordenador·as de bibliotheque : NON.
--
--        L'ouverture aux coordenador·as etait conditionnee a la reutilisation
--        d'un vote a majorite qualifiee (67 %) « deja plus ou moins en place ».
--        Verification faite, il n'existe pas — et son absence n'est pas un oubli.
--        TOUTE la gouvernance reseau d'AnarBib fonctionne a l'UNANIMITE AVEC
--        VETO, jamais a la majorite :
--          * cooptation d'un·e admin      : un seul vote `opposed` = rejet immediat
--                                           (trg_check_cooptation_completion) ;
--          * retrait collectif d'un·e admin : unanimite des autres actif·ves,
--                                           quorum >= 2 (fn_network_admin_vote_
--                                           collective_removal) ;
--          * evaluation d'une demande d'adhesion : unanimite, et le commentaire
--                                           de library_request_votes le dit
--                                           explicitement « symetrique aux votes
--                                           de cooptation ».
--        Le seul `majority` du depot est LOCAL a une bibliotheque
--        (fn_propose_library_profile_change, (staff_actif / 2) + 1) et c'est une
--        majorite SIMPLE, pas qualifiee.
--
--        Introduire du 67 % ici ne serait donc pas une reutilisation mais une
--        NOUVEAUTE DOCTRINALE : on remplacerait un droit de veto — anti-
--        majoritaire par construction, ce qui est le choix politique du reseau —
--        par une regle ou une minorite peut etre mise en minorite. Ca ne se
--        decide pas dans une migration. La borne reste ouverte au paragraphe 8
--        du cadrage ; en attendant, le geste est reserve aux admins.
--
--   D3 — DUREE DE VIE : 45 jours. Les 14 jours du claim d'inscription
--        conviennent a quelqu'un qui vient de creer son compte et a le mail sous
--        les yeux ; une bibliotheque sollicitee sans preavis doit avoir le temps
--        d'en parler en assemblee. Une invitation qui expire avant d'avoir ete
--        lue est une porte qu'on referme au nez.
--
-- LE JETON NE SE PERSISTE JAMAIS EN CLAIR. fn_create_... le rend UNE FOIS, a
-- l'appel, et seul son hash SHA-256 va en base. Consequence assumee : l'envoi
-- est un geste SEPARE (mailer, ou copier-coller vers Signal, ou remise de la
-- main a la main a Bologne). C'est volontairement plus artisanal qu'un « envoyer
-- l'invitation » en un clic — et conforme au paragraphe 7 du cadrage : une
-- invitation est un geste adresse, pas une campagne. Le corollaire technique
-- compte autant : faire transiter le jeton par un evenement de notification
-- l'ecrirait en clair dans team_notification_outbox, ou il resterait.
--
-- UNE SEULE INVITATION VIVANTE PAR ADRESSE. Garde posee par defaut dans
-- fn_create_... : reinviter une adresse deja sollicitee et sans reponse, c'est
-- exactement le glissement vers la relance que le cadrage ecarte. Revoquer
-- d'abord, reinviter ensuite — ce qui oblige a dire pourquoi. Revisable.
--
-- DROITS : `authenticated` uniquement. Surtout PAS `anon`, contrairement aux
-- trois RPC de lecture du claim (qui, elles, doivent servir une personne invitee
-- sans compte). Ici on emet, on revoque, on liste : ce sont des actes de
-- coordination.
-- =============================================================================

-- ── 1. Emettre une invitation ───────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_create_library_request_invitation(
  p_email text,
  p_library_name text,
  p_note text DEFAULT NULL
) RETURNS TABLE(claim_id uuid, claim_token text, expires_at timestamptz)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'extensions'
    AS $fn$
declare
  -- D3. Constante nommee plutot qu'un nombre au milieu du code : la prochaine
  -- personne qui la change doit voir qu'elle change une decision.
  c_ttl_jours constant int := 45;
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

  -- Une seule invitation vivante par adresse (cf. en-tete).
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

  -- Jeton opaque, meme format que celui de l'EF register (base64url, 32 octets,
  -- sans remplissage) : les deux origines produisent des liens interchangeables.
  v_token := rtrim(translate(encode(extensions.gen_random_bytes(32), 'base64'), '+/', '-_'), '=');

  insert into public.library_request_claims (
    user_id, email_snapshot, claim_token_hash, claim_purpose, claim_origin,
    expires_at, created_by_user_id, metadata
  ) values (
    null,                                   -- personne ne l'a encore reclamee
    v_email,
    public.fn_hash_claim_token(v_token),
    'library_request',
    'invitation',
    now() + make_interval(days => c_ttl_jours),
    auth.uid(),                             -- une invitation est signee (lot 1)
    jsonb_strip_nulls(jsonb_build_object(
      'source', 'network_admin_invitation',
      'library_name', v_nom,
      'note', nullif(btrim(coalesce(p_note, '')), '')
    ))
  )
  returning * into v_row;

  return query select v_row.id, v_token, v_row.expires_at;
end;
$fn$;

REVOKE ALL ON FUNCTION public.fn_create_library_request_invitation(text, text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.fn_create_library_request_invitation(text, text, text) FROM anon;
GRANT EXECUTE ON FUNCTION public.fn_create_library_request_invitation(text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_create_library_request_invitation(text, text, text) TO service_role;

COMMENT ON FUNCTION public.fn_create_library_request_invitation(text, text, text) IS
  'Emet une invitation a rejoindre le reseau. Reserve aux admins reseau actif·ves (D2 du 27/08/2026 : les coordenador·as ne peuvent pas inviter). TTL 45 jours (D3). Rend le jeton en clair UNE SEULE FOIS : seul son hash est stocke, l''envoi est un geste separe. Refuse une seconde invitation vivante pour la meme adresse.';

-- ── 2. Revoquer une invitation ──────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_revoke_library_request_invitation(
  p_claim_id uuid,
  p_motif text
) RETURNS TABLE(claim_id uuid, revoked_at timestamptz)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'extensions'
    AS $fn$
declare
  v_motif text;
  v_row public.library_request_claims;
begin
  if not public.fn_caller_is_network_admin() then
    raise exception 'Seule l''administration du reseau peut revoquer une invitation.'
      using errcode = '42501', hint = 'error.library_invitation.not_network_admin';
  end if;

  -- Doctrine « note obligatoire » : on dit pourquoi. La CHECK du lot 1 est le
  -- filet ; ce test-ci existe pour rendre un message lisible plutot qu'une
  -- violation de contrainte.
  v_motif := nullif(btrim(coalesce(p_motif, '')), '');
  if v_motif is null then
    raise exception 'Indique le motif de la revocation.'
      using errcode = '23514', hint = 'error.library_invitation.reason_required';
  end if;

  update public.library_request_claims c
     set revoked_at = now(),
         revoked_by_user_id = auth.uid(),
         revoked_reason = v_motif
   where c.id = p_claim_id
     and c.claim_origin = 'invitation'   -- on ne revoque pas une auto-candidature
     and c.used_at is null               -- ni une invitation deja aboutie
     and c.revoked_at is null            -- idempotence : pas de double revocation
  returning c.* into v_row;

  if not found then
    raise exception 'Cette invitation n''existe pas, a deja abouti, ou a deja ete revoquee.'
      using errcode = '42501', hint = 'error.library_invitation.not_revocable';
  end if;

  return query select v_row.id, v_row.revoked_at;
end;
$fn$;

REVOKE ALL ON FUNCTION public.fn_revoke_library_request_invitation(uuid, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.fn_revoke_library_request_invitation(uuid, text) FROM anon;
GRANT EXECUTE ON FUNCTION public.fn_revoke_library_request_invitation(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_revoke_library_request_invitation(uuid, text) TO service_role;

COMMENT ON FUNCTION public.fn_revoke_library_request_invitation(uuid, text) IS
  'Annule une invitation non aboutie. Reserve aux admins reseau actif·ves, motif obligatoire. Ne touche ni aux auto-candidatures ni aux invitations deja consommees. Un claim revoque devient invisible de fn_get_library_request_claim_context et refuse par fn_consume_library_request_claim (lot 1).';

-- ── 3. Lister les invitations emises ────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_list_library_request_invitations(
  p_inclure_closes boolean DEFAULT false
) RETURNS TABLE(
  claim_id uuid,
  email_snapshot text,
  library_name text,
  note text,
  etat text,
  created_at timestamptz,
  expires_at timestamptz,
  invitee_par uuid,
  reclamee_par uuid,
  used_by_request_id uuid,
  revoked_reason text
)
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'extensions'
    AS $fn$
  -- Ne rend JAMAIS claim_token_hash, et encore moins un jeton : la liste sert a
  -- suivre des gestes deja poses, pas a les rejouer. Cf. paragraphe 7 du cadrage
  -- (« pas de liste de prospects ») : on ne montre que des invitations EMISES,
  -- avec leur auteur·e et leur motif — pas des bibliotheques a demarcher.
  select
    c.id,
    c.email_snapshot,
    c.metadata->>'library_name',
    c.metadata->>'note',
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
    c.revoked_reason
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
  'Liste les invitations emises (jamais les auto-candidatures). Reserve aux admins reseau actif·ves — la garde est DANS le where, donc un appel non autorise rend zero ligne au lieu d''une erreur. Ne rend jamais de jeton ni de hash.';
