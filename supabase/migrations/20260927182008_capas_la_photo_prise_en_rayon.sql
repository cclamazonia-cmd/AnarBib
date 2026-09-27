-- ============================================================================
-- CAPAS · la photo prise en rayon, livre en main
-- Foyer : spec-module-capas · chantier capas du 27/09/2026 (campagne photo)
--
-- POURQUOI. Le fonds brésilien n'existe pas dans les catalogues ouverts : sur
-- 32 notices pt-BR sans ISBN tirées au hasard le 27/09, AUCUNE couverture
-- trouvée en ligne ; la recherche en lot (20260927180120) plafonne vers
-- 25-30 %. Le reste, 2 094 notices à la BTL, c'est une photo prise en rayon.
-- Jusqu'ici, pour la poser : ouvrir la notice au catalogage, téléverser,
-- enregistrer, publier.
--
-- CE QUE FAIT CETTE MIGRATION — trois RPC pour l'onglet « Couvertures » du
-- Painel (staff de terrain : librarian, coordenador, comme le récolement) :
--   1. api.capas_photo_resume(biblio)  : combien de notices détenues sans
--      couverture, combien photographiées ;
--   2. api.capas_photo_liste(biblio, recherche, …) : sans recherche, les
--      notices détenues sans couverture, dans l'ordre des tombos (celui des
--      rayons, faute de cote : 2 exemplaires cotés sur 2 363 à la BTL) ; avec
--      une recherche, ce qu'elle désigne — l'étiquette QR d'un exemplaire
--      (…?ex=<id>), un ISBN, un tombo entier ou ses seuls chiffres (« 447 »),
--      un titre, un nom ;
--   3. api.capas_photo_poser(notice, chemin, remplacer) : attache la photo
--      (déjà rangée dans le bucket par le navigateur, nom neuf `photo-…` dans
--      le dossier de la notice), provenance « photo ». Une couverture présente
--      n'est remplacée que sur demande EXPLICITE ; sinon « deja_une_capa » et
--      rien n'est écrit. Une proposition du lot en attente devient sans objet.
--
-- La photo arrive préparée par le navigateur (src/lib/photoCapa.js) :
-- redressée, réduite, réencodée — sans les métadonnées du téléphone.
--
-- Suite : tests/sql/capas_photo_tests.sql.
-- ============================================================================
begin;

create or replace function api.capas_photo_resume(p_library_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path to 'public', 'pg_catalog'
as $function$
declare
  v jsonb;
begin
  if not (public.fn_caller_is_network_admin()
          or public.user_has_library_staff_role((select auth.uid()), p_library_id)) then
    raise exception 'Acesso restrito ao staff de catalogacao.' using errcode = '42501', hint = 'error.catalog.staff_only';
  end if;

  select jsonb_build_object(
           'sans_capa',      count(*) filter (where nullif(btrim(coalesce(b.cover_object_path, '')), '') is null),
           'photographiees', count(*) filter (where b.cover_source = 'photo'
                                               and nullif(btrim(coalesce(b.cover_object_path, '')), '') is not null),
           'total',          count(*))
    into v
    from public.books b
    join public.book_holdings h on h.book_id = b.id and h.library_id = p_library_id
   where coalesce(b.tipo_material, '') <> 'recurso_digital';

  return v;
end;
$function$;

create or replace function api.capas_photo_liste(p_library_id uuid, p_recherche text default null,
                                                 p_limite integer default 20, p_decalage integer default 0)
returns table (book_id bigint, bib_ref text, titulo text, subtitulo text, autor text, editora text,
               ano text, volume text, isbn text, tombos text[], a_une_capa boolean)
language plpgsql
stable
security definer
set search_path to 'public', 'pg_catalog'
as $function$
#variable_conflict use_column
declare
  v_q        text := nullif(btrim(coalesce(p_recherche, '')), '');
  v_ex       bigint;
  v_isbn     text;
  v_chiffres text;
begin
  if not (public.fn_caller_is_network_admin()
          or public.user_has_library_staff_role((select auth.uid()), p_library_id)) then
    raise exception 'Acesso restrito ao staff de catalogacao.' using errcode = '42501', hint = 'error.catalog.staff_only';
  end if;

  -- L'étiquette QR d'un exemplaire porte …/livro/<notice>?ex=<exemplaire>.
  v_ex := substring(v_q from '[?&]ex=(\d{1,18})')::bigint;
  -- Un ISBN : dix ou treize signes une fois ôtés tirets et espaces, sans lettres
  -- autres que la clé X (un tombo « BTL-TL-EX-… » n'en est pas un).
  if v_ex is null and v_q !~ '[A-WYZa-wyz]'
     and regexp_replace(upper(v_q), '[^0-9X]', '', 'g') ~ '^(\d{9}[\dX]|\d{13})$' then
    v_isbn := regexp_replace(upper(v_q), '[^0-9X]', '', 'g');
  end if;
  -- Les seuls chiffres d'un tombo : « 447 » désigne …-000447.
  if v_ex is null and v_isbn is null and v_q ~ '^\d{1,9}$' then
    v_chiffres := v_q;
  end if;

  return query
    select b.id, b.bib_ref, b.titulo, b.subtitulo, b.autor, b.editora, b.ano, b.volume, b.isbn,
           t.tombos, nullif(btrim(coalesce(b.cover_object_path, '')), '') is not null
      from public.books b
      join public.book_holdings h on h.book_id = b.id and h.library_id = p_library_id
      left join lateral (select array_agg(e.tombo order by e.tombo) filter (where e.tombo is not null) as tombos,
                                min(e.tombo) as premier
                           from public.exemplares e where e.holding_id = h.id) t on true
     where coalesce(b.tipo_material, '') <> 'recurso_digital'
       and case
             when v_q is null then
               nullif(btrim(coalesce(b.cover_object_path, '')), '') is null
             when v_ex is not null then
               exists (select 1 from public.exemplares e where e.id = v_ex and e.holding_id = h.id)
             when v_isbn is not null then
               regexp_replace(upper(coalesce(b.isbn, '')), '[^0-9X]', '', 'g') = v_isbn
             when v_chiffres is not null then
               exists (select 1 from public.exemplares e
                        where e.holding_id = h.id and e.tombo ~ ('(^|[^0-9])0*' || v_chiffres || '$'))
               or coalesce(b.bib_ref, '') ~ ('(^|[^0-9])0*' || v_chiffres || '$')
             else
               b.titulo ilike '%' || v_q || '%'
               or b.autor ilike '%' || v_q || '%'
               or lower(coalesce(b.bib_ref, '')) = lower(v_q)
               or exists (select 1 from public.exemplares e
                           where e.holding_id = h.id and lower(coalesce(e.tombo, '')) = lower(v_q))
           end
     order by t.premier nulls last, b.bib_ref, b.id
     limit least(greatest(coalesce(p_limite, 20), 1), 50)
    offset greatest(coalesce(p_decalage, 0), 0);
end;
$function$;

create or replace function api.capas_photo_poser(p_book_id bigint, p_object_path text, p_remplacer boolean default false)
returns text
language plpgsql
security definer
set search_path to 'public', 'pg_catalog'
as $function$
declare
  v_admin boolean := public.fn_caller_is_network_admin();
  v_ids   uuid[]  := public.fn_caller_staff_library_ids();
  v_book  public.books%rowtype;
begin
  if not v_admin and cardinality(v_ids) = 0 then
    raise exception 'Acesso restrito ao staff de catalogacao.' using errcode = '42501', hint = 'error.catalog.staff_only';
  end if;

  select * into v_book from public.books where id = p_book_id for update;
  if not found or not public.fn_capas_dans_le_perimetre(v_book.id, v_book.owner_library_id, v_ids, v_admin) then
    raise exception 'capa_hors_perimetre' using errcode = '42501', hint = 'error.capas.hors_perimetre';
  end if;

  -- La photo est rangée dans le dossier de CETTE notice (clé = bib_ref nettoyée
  -- comme par cover_lookup et src/lib/photoCapa.js), sous un nom neuf.
  if coalesce(p_object_path, '') !~ '^books/[A-Za-z0-9_-]{1,120}/photo-[a-z0-9]{1,20}\.jpg$'
     or split_part(p_object_path, '/', 2) <> left(regexp_replace(coalesce(v_book.bib_ref, ''), '[^A-Za-z0-9_-]', '_', 'g'), 120) then
    raise exception 'capa_chemin_invalide' using hint = 'error.capas.chemin_invalide';
  end if;

  if nullif(btrim(coalesce(v_book.cover_object_path, '')), '') is not null and not coalesce(p_remplacer, false) then
    return 'deja_une_capa';
  end if;

  update public.books
     set cover_object_path = p_object_path,
         cover_source      = 'photo',
         cover_license     = null,
         updated_at        = now(),
         updated_by        = auth.uid()
   where id = p_book_id;

  -- Une proposition du lot qui attendait n'a plus d'objet.
  update public.cover_proposals
     set statut = 'perimee'
   where book_id = p_book_id and statut = 'a_revoir';

  return 'posee';
end;
$function$;

comment on function api.capas_photo_resume(uuid) is
  'Capas · campagne photo : notices détenues par la bibliothèque sans couverture, et photographiées. Staff de la bibliothèque.';
comment on function api.capas_photo_liste(uuid, text, integer, integer) is
  'Capas · campagne photo : sans recherche, les notices détenues sans couverture (ordre des tombos) ; avec, ce que '
  'désigne la recherche (étiquette QR ?ex=, ISBN, tombo ou ses chiffres, titre, nom, bib_ref). Staff de la bibliothèque.';
comment on function api.capas_photo_poser(bigint, text, boolean) is
  'Capas · campagne photo : attache une photo rangée dans le dossier de la notice (provenance photo). Ne remplace une '
  'couverture présente que si p_remplacer ; sinon rend deja_une_capa sans rien écrire.';

revoke all on function api.capas_photo_resume(uuid) from public, anon;
revoke all on function api.capas_photo_liste(uuid, text, integer, integer) from public, anon;
revoke all on function api.capas_photo_poser(bigint, text, boolean) from public, anon;
grant execute on function api.capas_photo_resume(uuid) to authenticated;
grant execute on function api.capas_photo_liste(uuid, text, integer, integer) to authenticated;
grant execute on function api.capas_photo_poser(bigint, text, boolean) to authenticated;

do $$
declare
  v_f text;
begin
  foreach v_f in array array[
    'api.capas_photo_resume(uuid)',
    'api.capas_photo_liste(uuid, text, integer, integer)',
    'api.capas_photo_poser(bigint, text, boolean)'] loop
    if has_function_privilege('anon', v_f, 'EXECUTE') or not has_function_privilege('authenticated', v_f, 'EXECUTE') then
      raise exception 'capas photo : droits inattendus sur %', v_f;
    end if;
  end loop;
end $$;

commit;
