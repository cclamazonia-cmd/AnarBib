-- Expose le fuseau horaire de reference de chaque bibliotheque
-- (library_service_state.consultation_timezone) au frontend, y compris aux
-- LECTEURS, pour afficher les creneaux de consultation et les heures de retrait
-- de reservation dans le fuseau de la biblioteca concernee — et non dans le
-- fuseau du navigateur (bug : un lecteur en France voyait l'heure d'une biblio
-- bresilienne decalee ; painel et compte lecteur divergeaient).
--
-- Pourquoi une fonction SECURITY DEFINER : library_service_state est protegee
-- par RLS (SELECT reserve au staff via user_can_act_as_staff_on_library), donc
-- un lecteur ne peut pas la lire directement. Cette fonction n'expose QUE le
-- couple (library_id, fuseau) — donnee non sensible (fuseau d'exploitation
-- public d'une bibliotheque) — sans ouvrir la table. Le frontend charge la
-- petite table une fois et croise par library_id (deja present sur chaque
-- reservation/consultation). Repli 'America/Belem' = defaut de la colonne.

create or replace function public.fn_library_timezones()
returns table(library_id uuid, consultation_timezone text)
language sql
stable
security definer
set search_path = public
as $$
  select lss.library_id,
         coalesce(nullif(btrim(lss.consultation_timezone), ''), 'America/Belem') as consultation_timezone
  from public.library_service_state lss;
$$;

alter function public.fn_library_timezones() owner to postgres;

revoke all on function public.fn_library_timezones() from public;
grant execute on function public.fn_library_timezones() to authenticated, service_role;

comment on function public.fn_library_timezones() is
  'Retourne (library_id, consultation_timezone) pour toutes les bibliotheques. SECURITY DEFINER : contourne la RLS staff-only de library_service_state pour exposer uniquement le fuseau (non sensible) au frontend lecteur/painel. Repli America/Belem. Sert a afficher les horaires de resa/consultation dans le fuseau de la biblio concernee.';
