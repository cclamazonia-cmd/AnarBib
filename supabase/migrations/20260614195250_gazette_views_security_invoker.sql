-- Aligner les vues gazette sur la convention maison (security_invoker)
alter view api.gazette_issues_public_v1  set (security_invoker = on);
alter view api.gazette_locales_public_v1 set (security_invoker = on);

-- Avec security_invoker, l'appelant (anon/authenticated) doit avoir le GRANT SELECT
-- sur les tables de base ; la RLS limite déjà la visibilité aux numéros publiés.
grant select on public.gazette_issues        to anon, authenticated;
grant select on public.gazette_issue_locales to anon, authenticated;
