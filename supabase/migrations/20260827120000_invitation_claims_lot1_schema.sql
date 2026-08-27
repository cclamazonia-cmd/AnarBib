-- =============================================================================
-- Invitation d'une bibliotheque — LOT 1 : schema des claims
-- =============================================================================
-- Date     : 2026-08-27
-- Ref      : docs/journal/cadrages/CADRAGE_invitation_bibliotheque_2026-08-27.md
-- Decision : option A du paragraphe 5 — on ETEND library_request_claims plutot
--            que de creer une table d'invitations separee. Actee le 27/08.
--
-- CE QUE CE LOT FAIT, ET S'ARRETE LA. Il ouvre le schema. Il ne cree AUCUNE
-- invitation : la RPC d'emission, le mailer et le raccord a l'ecran sont des
-- lots suivants, et plusieurs bornes du paragraphe 8 du cadrage ne sont pas
-- tranchees (qui peut inviter, duree de vie, retention). Le schema est
-- volontairement livre seul parce qu'il ne depend d'aucune de ces reponses.
--
-- 1. user_id DEVIENT NULLABLE. C'etait le verrou : une invitation n'a pas
--    d'utilisateur au moment ou on l'emet. Mais une colonne rendue nullable
--    « pour un cas » devient un trou des qu'on l'oublie, donc la garantie
--    perdue est remplacee par une contrainte NOMMEE :
--      user_id is not null OR claim_origin = 'invitation'
--    Autrement dit : un claim d'auto-candidature porte toujours son compte,
--    exactement comme avant ; seul un claim d'invitation a le droit d'attendre.
--
-- 2. claim_origin, COLONNE REELLE ET NON UNE CLE JSONB. Le cadrage disait
--    « une source dans metadata ». On s'en ecarte : une CHECK ne peut pas
--    contraindre proprement une cle jsonb, et c'est precisement le role qu'on
--    lui demande ici (point 1). Une colonne se contraint, s'indexe et se grep.
--    Le defaut 'self_signup' preserve la retro-compatibilite : l'EF register
--    insere sans connaitre cette colonne et continue de fonctionner telle
--    quelle — aucun redeploiement de fonction Edge n'est necessaire.
--
-- 3. REVOCATION. Une invitation part parfois a la mauvaise adresse. revoked_at
--    + revoked_by_user_id + revoked_reason, avec motif OBLIGATOIRE (doctrine
--    « note obligatoire » du depot : on dit pourquoi).
--
--    ⚠️ ET SURTOUT : les deux fonctions de lecture du claim apprennent a
--    ignorer un claim revoque. Un revoked_at que personne ne lit serait pire
--    que pas de revocation du tout — il donnerait l'illusion d'avoir ferme une
--    porte restee grande ouverte. C'est la seule raison pour laquelle ce lot
--    touche a du code deja en service.
--
-- 4. UNE INVITATION EST SIGNEE. created_by_user_id, jusqu'ici nullable et
--    rempli par la personne elle-meme, devient obligatoire pour une invitation :
--    on doit toujours pouvoir dire qui a sollicite qui. C'est aussi ce qui
--    empeche une invitation de se creer « toute seule ».
--
-- Les corps des deux fonctions sont ceux du baseline, avec UNE ligne ajoutee
-- chacun (`and c.revoked_at is null`), extraits et patches par script — voir
-- la migration 20260827100000 pour ce que coute une reecriture de memoire.
-- =============================================================================

-- ── 1. Origine du claim ─────────────────────────────────────────────────────
ALTER TABLE public.library_request_claims
  ADD COLUMN IF NOT EXISTS claim_origin text NOT NULL DEFAULT 'self_signup';

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'public.library_request_claims'::regclass
      AND conname = 'library_request_claims_origin_chk'
  ) THEN
    ALTER TABLE public.library_request_claims
      ADD CONSTRAINT library_request_claims_origin_chk
      CHECK (claim_origin IN ('self_signup', 'invitation'));
  END IF;
END $$;

-- ── 2. Revocation ───────────────────────────────────────────────────────────
ALTER TABLE public.library_request_claims
  ADD COLUMN IF NOT EXISTS revoked_at timestamptz,
  ADD COLUMN IF NOT EXISTS revoked_by_user_id uuid REFERENCES public.profiles(id),
  ADD COLUMN IF NOT EXISTS revoked_reason text;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'public.library_request_claims'::regclass
      AND conname = 'library_request_claims_revocation_motivee_chk'
  ) THEN
    ALTER TABLE public.library_request_claims
      ADD CONSTRAINT library_request_claims_revocation_motivee_chk
      CHECK (revoked_at IS NULL
             OR nullif(btrim(coalesce(revoked_reason, '')), '') IS NOT NULL);
  END IF;
END $$;

-- ── 3. Le verrou remplace : user_id nullable, mais seulement pour une invitation
ALTER TABLE public.library_request_claims ALTER COLUMN user_id DROP NOT NULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'public.library_request_claims'::regclass
      AND conname = 'library_request_claims_user_id_par_origine_chk'
  ) THEN
    ALTER TABLE public.library_request_claims
      ADD CONSTRAINT library_request_claims_user_id_par_origine_chk
      CHECK (user_id IS NOT NULL OR claim_origin = 'invitation');
  END IF;
END $$;

-- ── 4. Une invitation est signee ────────────────────────────────────────────
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'public.library_request_claims'::regclass
      AND conname = 'library_request_claims_invitation_signee_chk'
  ) THEN
    ALTER TABLE public.library_request_claims
      ADD CONSTRAINT library_request_claims_invitation_signee_chk
      CHECK (claim_origin <> 'invitation' OR created_by_user_id IS NOT NULL);
  END IF;
END $$;

COMMENT ON COLUMN public.library_request_claims.claim_origin IS
  'Origine du claim. self_signup (defaut) = la personne s''est inscrite d''elle-meme par /criar-conta, l''EF register a pose le claim. invitation = la coordination a sollicite une bibliotheque ; user_id peut alors etre NULL tant que personne ne l''a reclame, et created_by_user_id est obligatoire. Cf. CADRAGE_invitation_bibliotheque_2026-08-27 paragraphe 5, option A.';

COMMENT ON COLUMN public.library_request_claims.user_id IS
  'Compte porteur du claim. NOT NULL jusqu''au 27/08/2026 ; desormais nullable POUR LE SEUL CAS claim_origin = ''invitation'' (contrainte library_request_claims_user_id_par_origine_chk), ou il se remplit quand la personne invitee cree son compte.';

COMMENT ON COLUMN public.library_request_claims.revoked_at IS
  'Annulation d''une invitation partie a la mauvaise adresse. Un claim revoque est invisible de fn_get_library_request_claim_context et refuse par fn_consume_library_request_claim. Motif obligatoire (revoked_reason).';

-- ── 5. Les deux lectures du claim ignorent desormais un claim revoque ───────
-- Corps du baseline + une ligne. Sans cela, revoked_at serait decoratif.

CREATE OR REPLACE FUNCTION "public"."fn_get_library_request_claim_context"("p_claim_token" "text") RETURNS TABLE("claim_id" "uuid", "email_snapshot" "text", "expires_at" timestamp with time zone, "claim_purpose" "text", "is_valid" boolean)
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public', 'extensions'
    AS $$
  select
    c.id as claim_id,
    c.email_snapshot,
    c.expires_at,
    c.claim_purpose,
    true as is_valid
  from public.library_request_claims c
  where c.claim_token_hash = public.fn_hash_claim_token(btrim(p_claim_token))
    and c.claim_purpose = 'library_request'
    and c.used_at is null
    and c.expires_at > now()
    and c.revoked_at is null
  limit 1;
$$;

CREATE OR REPLACE FUNCTION "public"."fn_consume_library_request_claim"("p_claim_token" "text", "p_request_id" "uuid" DEFAULT NULL::"uuid") RETURNS "public"."library_request_claims"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'extensions'
    AS $$
declare
  v_row public.library_request_claims;
begin
  if nullif(btrim(coalesce(p_claim_token, '')), '') is null then
    raise exception 'Link inválido.' using errcode = '23514';
  end if;

  update public.library_request_claims c
  set
    used_at = now(),
    used_by_request_id = coalesce(p_request_id, c.used_by_request_id)
  where c.claim_token_hash = public.fn_hash_claim_token(btrim(p_claim_token))
    and c.claim_purpose = 'library_request'
    and c.used_at is null
    and c.expires_at > now()
    and c.revoked_at is null
  returning c.* into v_row;

  if not found then
    raise exception 'Este link não é mais válido. Solicite um novo acesso.'
      using errcode = '42501';
  end if;

  return v_row;
end;
$$;

COMMENT ON FUNCTION public.fn_get_library_request_claim_context(text) IS
  'SECURITY DEFINER intentional: valide un claim token et rend son contexte (accessible a anon : une personne invitee n''a pas encore de compte). Filtrage par hash SHA-256. Depuis le 27/08/2026, exclut aussi les claims revoques.';
