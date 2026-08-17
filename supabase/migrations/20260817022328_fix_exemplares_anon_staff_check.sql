-- Restaure la lecture anonyme des exemplaires (donc de la fiche livre publique)
-- sans réintroduire d'oracle d'appartenance.
--
-- Contexte. Le durcissement des grants du 2026-07-02 a retiré EXECUTE sur
-- public.user_has_library_staff_role(uuid, uuid) au rôle `anon`. Or la politique
-- RLS `exemplares_public_read` s'applique à `anon` et appelle cette fonction :
-- toute lecture anonyme de `public.exemplares` échoue donc en 42501
-- (« permission denied for function user_has_library_staff_role »), ce qui fait
-- répondre 401 à v_book_detail_public_v2 pour les visiteurs non connectés.
-- Côté application, BookPage.jsx retombe silencieusement sur `books` : la fiche
-- s'affiche mais amputée des champs enrichis, avec un aller-retour perdu à chaque
-- consultation. Constaté le 2026-08-16 pendant le test de charge FICEDL Bologna.
--
-- Pourquoi ne PAS simplement rendre le grant à anon : user_has_library_staff_role
-- accepte un p_user_id arbitraire. L'exposer à anon en ferait un oracle permettant
-- de confirmer, pour un UUID d'usager connu, son appartenance à l'équipe d'une
-- bibliothèque. La révocation de juillet était donc justifiée.
--
-- Correctif retenu : la politique n'appelle jamais la fonction qu'avec auth.uid().
-- On introduit une variante qui ne renseigne que sur l'appelant, sans paramètre
-- d'identité, et on l'utilise dans la seule politique exposée à anon.
-- user_has_library_staff_role reste inchangée et non accessible à anon.

create or replace function public.fn_caller_is_library_staff(p_library_id uuid)
returns boolean
language sql
stable
security definer
set search_path to 'public', 'auth', 'pg_temp'
as $$
  select exists (
    select 1
    from public.user_library_memberships ulm
    where ulm.user_id = (select auth.uid())
      and ulm.library_id = p_library_id
      and ulm.status = 'active'
      and lower(coalesce(ulm.role, '')) in ('librarian', 'coordenador')
  );
$$;

comment on function public.fn_caller_is_library_staff(uuid) is
  'Vrai si l''appelant (auth.uid()) est librarian/coordenador actif de la bibliothèque donnée. '
  'Variante sans oracle de user_has_library_staff_role : ne renseigne que sur soi-même, donc '
  'exposable à anon, pour qui auth.uid() est NULL et le résultat toujours false.';

revoke all on function public.fn_caller_is_library_staff(uuid) from public;
grant execute on function public.fn_caller_is_library_staff(uuid) to anon, authenticated, service_role;

-- Même expression qu'auparavant, au helper près.
drop policy if exists exemplares_public_read on public.exemplares;
create policy exemplares_public_read on public.exemplares
for select to authenticated, anon
using (
  exists (
    select 1
    from public.book_holdings h
    where h.id = exemplares.holding_id
      and fn_library_visible_to_caller(h.library_id)
      and (exemplares.visibility = 'public' or fn_caller_is_library_staff(h.library_id))
  )
);
