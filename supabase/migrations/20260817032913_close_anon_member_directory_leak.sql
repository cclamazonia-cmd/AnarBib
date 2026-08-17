-- Ferme la fuite d'annuaire des membres exploitable sans aucun compte.
--
-- Constat (audit du 2026-08-17). Trois fonctions SECURITY DEFINER etaient
-- executables par le role anon et contournent la RLS par construction :
--
--   resolve_login_email(identifiant)              -> e-mail + user_id
--   fn_user_display_name(uuid)                    -> prenom et nom
--   fn_membership_can_engage_circulation(uuid,..) -> rattachement a une biblio
--
-- Enchainees, elles reconstituent l'annuaire complet des membres depuis
-- internet. L'exploitation est triviale car les public_id reels ne sont pas
-- ceux prevus par generate_public_id() (20 caracteres hex aleatoires) : ils
-- sont de la forme U + nombre, concentres sur une plage etroite, donc
-- enumerables en quelques secondes.
--
-- Verifie avant revocation : aucune politique RLS n'utilise ces fonctions, et
-- leurs seuls appelants internes sont soit SECURITY DEFINER (les droits de
-- l'appelant n'entrent pas en jeu), soit inaccessibles a anon. La revocation
-- ne peut donc pas reproduire la panne du 2026-07-02 sur les helpers RLS.
--
-- La connexion par numero de lecteur reste possible : la resolution
-- identifiant -> e-mail passe desormais par l'Edge Function `login`, qui
-- l'effectue avec le service_role APRES verification Turnstile et controle du
-- rate limit. Elle n'est donc plus un service en libre-service.

revoke execute on function public.resolve_login_email(text) from anon;
revoke execute on function public.fn_user_display_name(uuid) from anon;
revoke execute on function public.fn_membership_can_engage_circulation(uuid, uuid) from anon;

-- L'Edge Function login appelle la resolution avec le service_role.
grant execute on function public.resolve_login_email(text) to service_role;

-- authenticated conserve l'acces : RedePage (ajout d'une personne par un
-- administrateur reseau) resout un public_id, et les fonctions d'affichage
-- de nom servent aux ecrans internes.
