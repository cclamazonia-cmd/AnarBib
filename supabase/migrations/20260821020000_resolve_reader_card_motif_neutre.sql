-- =============================================================================
-- api.resolve_reader_card : rendre le motif de refus REELLEMENT neutre
-- =============================================================================
-- TROUVE le 20/08/2026, en triant les 125 fonctions SECURITY DEFINER de `api`
-- ouvertes aux comptes connectes (§8 du plan de marche).
--
-- LA FONCTION EST BIEN GARDEE. Elle exige un compte, hache le jeton, et ne
-- resout l'identite que si l'appelant est staff actif (librarian|coordenador)
-- de la bibliotheque DU JETON. Rien de tout cela ne change ici.
--
-- CE QUI NE VA PAS est une phrase. Le code portait ce commentaire :
--
--     -- Message neutre identique à token_not_found (anti-fuite).
--     RETURN jsonb_build_object('ok', false, 'reason', 'not_staff_of_library');
--
-- Le commentaire annonce un message neutre ; la valeur renvoyee, elle, est
-- DISTINCTE de 'token_not_found'. Un compte quelconque qui obtient une carte —
-- la photo d'un QR suffit — peut donc distinguer « ce jeton existe, mais tu
-- n'es pas staff de sa bibliotheque » de « ce jeton n'existe pas ». Il confirme
-- ainsi qu'une carte est enregistree, et qu'elle appartient a une bibliotheque
-- dont il n'est pas membre.
--
-- POURQUOI CA A TENU SI LONGTEMPS SANS SE VOIR : la neutralite EST implementee,
-- mais dans l'interface. src/pages/painel/tabs/ResolveCardBox.jsx ecrase les
-- deux motifs sur une seule cle i18n :
--
--     // token_not_found + not_staff_of_library -> message neutre commun
--     const key = (reason === 'token_not_found' || reason === 'not_staff_of_library')
--       ? 'card.resolve.error.unrecognized' : ...
--
-- Ce qu'une personne VOIT est donc bien neutre. Mais PostgREST expose la
-- fonction : n'importe quel compte peut l'appeler directement et lire le
-- `reason` brut. Une defense placee dans la presentation ne protege personne
-- qui attaque — elle ne protege que ceux qui n'essaient pas.
--
-- SEVERITE FAIBLE, et il faut le dire aussi : les jetons sont haches par
-- fn_hash_claim_token et ne se devinent pas. Il faut deja detenir la carte.
-- Ce qui est corrige ici tient donc moins du trou que de l'ecart entre une
-- intention ecrite et le code — l'espece de defaut qui se propage, parce que
-- le prochain lecteur fait confiance au commentaire.
--
-- LE CORRECTIF NE COUTE AUCUN MESSAGE. Le front collapsant deja les deux
-- motifs, renvoyer 'token_not_found' dans les deux cas ne change rien a ce que
-- voit le personnel : « Jeton non reconnu pour cette bibliotheque ». Le
-- traitement des deux valeurs est conserve cote front, sans dommage, et il
-- protegera encore si quelqu'un revenait un jour sur cette migration.
-- =============================================================================

begin;

create or replace function api.resolve_reader_card(p_token text)
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'public', 'extensions'
as $function$
DECLARE
  v_uid      uuid := auth.uid();
  v_hash     text;
  v_tok      public.reader_card_tokens%ROWTYPE;
  v_prof     public.profiles%ROWTYPE;
  v_is_staff boolean;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'not_authenticated');
  END IF;

  IF COALESCE(btrim(p_token), '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'invalid_token');
  END IF;

  v_hash := public.fn_hash_claim_token(lower(btrim(p_token)));

  -- Jeton recherché QUEL QUE SOIT le statut (actif privilégié en cas de
  -- collision de hash, impossible en pratique) → permet de distinguer ensuite
  -- carte révoquée vs jeton inconnu, sans fuite (cf. en-tête).
  SELECT * INTO v_tok
  FROM public.reader_card_tokens
  WHERE token_hash = v_hash
  ORDER BY (status = 'active') DESC, created_at DESC
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'token_not_found');
  END IF;

  -- Garde : staff actif (librarian|coordenador) de la biblio du jeton.
  SELECT EXISTS (
    SELECT 1
    FROM public.user_library_memberships m
    WHERE m.user_id = v_uid
      AND m.library_id = v_tok.library_id
      AND m.status = 'active'
      AND m.role IN ('librarian', 'coordenador')
  ) INTO v_is_staff;

  IF NOT v_is_staff THEN
    -- Motif VOLONTAIREMENT identique a celui du jeton inconnu : un appelant qui
    -- n'est pas staff de cette bibliotheque ne doit pas pouvoir distinguer
    -- « carte existante ailleurs » de « carte inexistante ». C'est la seule
    -- ligne que change cette migration ; le commentaire l'annoncait deja, le
    -- code ne le faisait pas. Ne pas « clarifier » ce motif en le rendant
    -- specifique : sa banalite est le controle.
    RETURN jsonb_build_object('ok', false, 'reason', 'token_not_found');
  END IF;

  -- L'appelant est staff de la bonne biblio : on peut l'informer précisément.
  IF v_tok.status <> 'active' THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'card_revoked');
  END IF;

  -- Résolution de l'identité (le staff de la bonne biblio y a droit).
  SELECT * INTO v_prof FROM public.profiles WHERE id = v_tok.user_id;

  RETURN jsonb_build_object(
    'ok',             true,
    'reader_user_id', v_tok.user_id,
    'membership_id',  v_tok.membership_id,
    'library_id',     v_tok.library_id,
    'public_id',      v_prof.public_id,
    'display_name',   NULLIF(btrim(COALESCE(v_prof.first_name, '') || ' ' || COALESCE(v_prof.last_name, '')), ''),
    'is_restricted',  COALESCE(v_prof.is_restricted, false)
  );
END;
$function$;

comment on function api.resolve_reader_card(text) is
  'Resout une carte de lecteur·rice a partir de son jeton. Reservee au staff '
  'actif de la bibliotheque du jeton. Un appelant non habilite recoit '
  '''token_not_found'', volontairement indistinct du jeton inexistant.';

-- CREATE OR REPLACE conserve les droits ; on les reaffirme quand meme, pour que
-- le fichier dise seul qui peut appeler la fonction.
revoke execute on function api.resolve_reader_card(text) from public, anon;
grant  execute on function api.resolve_reader_card(text) to authenticated;

-- -----------------------------------------------------------------------------
-- Verification
-- -----------------------------------------------------------------------------
do $$
begin
  if exists (
    select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'api' and p.proname = 'resolve_reader_card'
       and p.prosrc like '%not_staff_of_library%'
  ) then
    raise exception 'le motif not_staff_of_library subsiste : la fuite nest pas fermee';
  end if;

  if has_function_privilege('anon', 'api.resolve_reader_card(text)', 'EXECUTE') then
    raise exception 'anon ne doit pas pouvoir appeler resolve_reader_card';
  end if;

  if not has_function_privilege('authenticated', 'api.resolve_reader_card(text)', 'EXECUTE') then
    raise exception 'authenticated doit pouvoir appeler resolve_reader_card';
  end if;
end $$;

commit;

-- =============================================================================
-- CONTROLE APRES DEPLOIEMENT
-- =============================================================================
-- Avec un compte NON staff de la bibliotheque du jeton, les deux appels
-- suivants doivent rendre EXACTEMENT la meme chose :
--
--   select api.resolve_reader_card('<jeton d une vraie carte>');
--   select api.resolve_reader_card('jeton-qui-nexiste-pas');
--   -> {"ok": false, "reason": "token_not_found"}  dans les deux cas.
--
-- Avec un compte staff de la bonne bibliotheque, le comportement est inchange :
-- identite resolue, ou 'card_revoked' si la carte a ete remplacee.
-- =============================================================================
