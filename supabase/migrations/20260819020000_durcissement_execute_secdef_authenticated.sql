-- =============================================================================
-- Durcissement EXECUTE des fonctions SECURITY DEFINER — lot 2 : authenticated
-- =============================================================================
-- Suite de 20260817200000_durcissement_execute_secdef_anon.sql, qui traitait
-- l'exposition a `anon`. Ce lot-ci traite deux fonctions exposees a
-- `authenticated` : n'importe quel compte, meme un compte lecteur ordinaire.
--
-- METHODE (19/08/2026) — le critere « la fonction controle-t-elle auth.uid() ? »
-- s'est revele mauvais sur cette base : on delegue systematiquement a des
-- predicats (fn_current_user_conta_ativa, fn_library_visible_to_caller,
-- fn_current_user_is_member_of). Trois fonctions suspectees sur ce critere se
-- sont averees saines. Le bon critere est : « que renvoie-t-elle, et a partir de
-- quel parametre ? ». Les deux fonctions ci-dessous prennent en parametre
-- l'identifiant de QUELQU'UN D'AUTRE et renvoient une donnee personnelle, sans
-- aucun controle de l'appelant.
--
-- CE QUI A ETE VERIFIE AVANT D'ECRIRE CETTE MIGRATION :
--   * aucune des deux fonctions n'est utilisee par une policy RLS (0)
--   * aucune n'est utilisee par une vue `security_invoker` (0)
--   * `service_role` possede une autorisation EXPLICITE (service_role=X/postgres)
--     et non heritee de PUBLIC : les Edge Functions ne sont pas affectees
--
-- NON TOUCHEE VOLONTAIREMENT : fn_assembleia_facilitator_name(uuid).
-- Elle est appelee par la vue api.assembleia_facilitators_v1, qui est en
-- `security_invoker = true` : la vue s'evalue avec les droits de l'appelant,
-- donc lui retirer EXECUTE pour `authenticated` casserait l'onglet Assembleias.
-- C'est le meme piege que les policies RLS, et il vaut d'etre note : une vue en
-- security_invoker rend un EXECUTE aussi indispensable qu'une policy.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. fn_user_display_name(uuid) — fuite de nom, et d'e-mail en repli
-- -----------------------------------------------------------------------------
-- SECURITY DEFINER, aucun controle d'appelant. Sur un UUID quelconque elle
-- renvoie « prenom nom » — et, si le nom est vide, **l'adresse e-mail**.
-- Les UUID d'usagers ne sont pas secrets : ils circulent dans les charges utiles
-- de l'API. Un compte lecteur ordinaire pouvait donc traduire un identifiant en
-- identite, voire en adresse.
--
-- Aucun appel depuis src/ ni depuis les Edge Functions (verifie le 19/08) : la
-- fonction n'est utilisee qu'a l'interieur d'autres fonctions, ou l'appel se
-- fait avec les droits du proprietaire et non ceux de l'appelant.
revoke execute on function public.fn_user_display_name(p_uid uuid)
  from anon, authenticated, public;

-- -----------------------------------------------------------------------------
-- 2. resolve_login_email(text) — l'oracle numero de lecteur -> e-mail
-- -----------------------------------------------------------------------------
-- Prend un numero de lecteur (public_id) et renvoie e-mail + user_id. Aucun
-- controle d'appelant. Le 17/08 on l'a retiree a `anon` ; elle restait ouverte a
-- `authenticated`, c'est-a-dire a n'importe quel compte, en masse.
--
-- ⚠️ Le commentaire de supabase/functions/login/index.ts affirmait :
--   « resolve_login_email [...] n'est plus executable par anon : seul le
--     service_role y accede, donc uniquement par ici. »
-- C'etait faux : `authenticated` avait toujours EXECUTE. A corriger dans la
-- foulee cote Edge Function.
--
-- Elle est appelee cote front par src/pages/rede/RedePage.jsx (transfert du
-- mandat de coordination), qui n'utilise QUE `user_id` et jamais l'e-mail.
-- On lui substitue donc une fonction gardee qui ne renvoie que l'UUID.

create or replace function public.fn_network_resolve_public_id(p_identifier text)
returns uuid
language sql
stable
security definer
set search_path to 'public', 'pg_temp'
as $$
  -- Le garde est dans le WHERE et non dans un RAISE : un appelant sans droit
  -- obtient NULL, indiscernable de « numero inconnu ». Pas d'oracle.
  select p.id
    from public.profiles p
   where upper(btrim(p.public_id)) = upper(btrim(p_identifier))
     and public.fn_caller_is_network_admin()
   limit 1;
$$;

comment on function public.fn_network_resolve_public_id(text) is
  'Resout un numero de lecteur en UUID, pour les admins reseau uniquement. '
  'Ne renvoie JAMAIS d''adresse e-mail, contrairement a resolve_login_email '
  'qu''elle remplace cote front (RedePage, transfert de mandat). 19/08/2026.';

revoke execute on function public.fn_network_resolve_public_id(text) from public;
revoke execute on function public.fn_network_resolve_public_id(text) from anon;
grant  execute on function public.fn_network_resolve_public_id(text) to authenticated;

-- Et seulement maintenant, la revocation. `service_role` conserve son
-- autorisation explicite : l'Edge Function `login` continue de fonctionner.
revoke execute on function public.resolve_login_email(p_identifier text)
  from anon, authenticated, public;

-- -----------------------------------------------------------------------------
-- Controle a passer apres deploiement
-- -----------------------------------------------------------------------------
-- select proname,
--        has_function_privilege('authenticated', oid, 'EXECUTE') as auth,
--        has_function_privilege('service_role',  oid, 'EXECUTE') as svc
--   from pg_proc where proname in
--     ('resolve_login_email','fn_user_display_name','fn_network_resolve_public_id');
--
-- Attendu :  resolve_login_email          auth=false  svc=true
--            fn_user_display_name         auth=false  svc=true
--            fn_network_resolve_public_id auth=true   svc=false
