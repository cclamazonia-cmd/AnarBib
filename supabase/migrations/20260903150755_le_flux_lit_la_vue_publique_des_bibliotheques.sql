-- ============================================================================
-- E11 — le flux des nouveautés doit pouvoir lire la vue publique des bibliothèques
-- ============================================================================
-- `api.libraries_public_v1` est une vue `security_invoker` accordée à `anon` et
-- `authenticated` seulement. L'Edge Function `rss-novidades` (e7a8acab) parle
-- en service_role (fonction sans JWT, flux anonyme par nature) et sa première
-- garde interroge cette vue : en production, « permission denied for view
-- libraries_public_v1 » — vu le 03/09 à la première requête, banc d'essai
-- vert (il ne voit pas les grants). Un grant SELECT au rôle de service suffit :
-- la vue reste `security_invoker`, service_role lit `libraries` avec ses
-- propres droits, et le prédicat de publicité reste dans la vue, écrit une
-- seule fois. Rien n'est ouvert à anon qui ne l'était déjà.
begin;

grant select on api.libraries_public_v1 to service_role;

do $$
begin
  if not has_table_privilege('service_role', 'api.libraries_public_v1', 'SELECT') then
    raise exception 'E11 — service_role ne lit toujours pas api.libraries_public_v1 : abandon.';
  end if;
  if has_table_privilege('anon', 'api.libraries_public_v1', 'INSERT') then
    raise exception 'E11 — anon écrit dans api.libraries_public_v1 : abandon.';
  end if;
end $$;

commit;
