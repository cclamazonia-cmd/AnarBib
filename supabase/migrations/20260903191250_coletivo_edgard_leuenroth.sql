-- ============================================================================
-- CONV-8, suite — « Leueroth, Pelo Coletivo Edgar » devient la collectivité
-- « Coletivo Edgard Leuenroth », organisatrice du volume
-- Foyer : REGISTRE §37 `CONV` · CONV-8, CONV-O2, CONV-O7 · décision Xavier 03/09 soir
-- ============================================================================
-- CE QUI S'EST PASSÉ. La mention de responsabilité de « Movimento Operário
-- Brasileiro 1900-1979 » (Vega, 1980 ; notice 1828) disait « pelo Coletivo
-- Edgard Leuenroth ». L'import a traité la phrase comme un nom de personne : le
-- dernier mot pour patronyme, le reste pour prénoms, une coquille en prime —
-- « Leueroth, Pelo Coletivo Edgar ». Trois erreurs : la préposition « pelo »
-- (« par le ») est entrée dans le nom ; « Leueroth » n'est pas « Leuenroth » ;
-- « Edgar » n'est pas « Edgard » — c'est ainsi que le catalogue écrit déjà le
-- militant (autorité 41, « Leuenroth, Edgard », huit livres).
--
-- CE QUE LA MIGRATION FAIT, en un geste gardé :
--   · une autorité de COLLECTIVITÉ « Coletivo Edgard Leuenroth » (CONV-O2 : nom
--     officiel, sans inversion ; CONV-O7 : `authority_type` + jsonb), retrouvée
--     par `fn_conv_autorite_homonyme` si elle existait, créée sinon. Ce n'est
--     PAS l'autorité 41 : le collectif porte le nom du militant, il n'est pas le
--     militant ;
--   · le contributeur 4543 renommé « Coletivo Edgard Leuenroth », relié, au rôle
--     `organizacao` — « pelo coletivo » dit qui a réuni le volume ; les auteurs
--     des textes (Löwy, Sader, Castro, Hirata) suivent sur la même notice ;
--   · la transcription `books.autor` réparée sur son PREMIER segment seulement :
--     la coquille et le « pelo » sont de l'import, pas de la page. C'est le seul
--     point où l'on touche la transcription : on répare une saisie, on ne
--     normalise pas. Les autres segments restent tels qu'écrits.
-- Anti-écrasement : nom du contributeur, absence d'autorité, transcription
-- exacte. Journal `catalog_audit_log`. SECURITY INVOKER, aucun grant.
-- Suite : conv_8_collectif_nomme_tests.sql.
-- ============================================================================
begin;

create or replace function public.fn_conv_requalifier_contributeur_collectif(
  p_contrib_id bigint, p_nom_avant text, p_nom_collectif text, p_role text,
  p_autor_avant text, p_autor_apres text)
returns boolean
language plpgsql
security invoker
set search_path to 'public', 'pg_catalog'
as $$
declare
  c        public.book_contributors%rowtype;
  v_author bigint;
begin
  select * into c from public.book_contributors where id = p_contrib_id;
  if c.id is null or c.name is distinct from p_nom_avant or c.author_id is not null then return false; end if;
  if not exists (select 1 from public.books b where b.id = c.book_id and b.autor = p_autor_avant) then return false; end if;
  if p_role not in ('autor', 'organizador', 'organizacao', 'coordenador', 'editor', 'outro') then return false; end if;

  v_author := public.fn_conv_autorite_homonyme(p_nom_collectif);
  if v_author is null then
    insert into public.authors (sort_name, preferred_name, authority_type, structured_meta, source_kind, source_label)
    values (p_nom_collectif, p_nom_collectif, 'collective',
            jsonb_build_object('authorityType', 'collective'),
            'conv_revue', 'CONV-8 · collectivité requalifiée par migration (03/09)')
    returning id into v_author;
  else
    -- une fiche retrouvée qui ne serait pas typée collectivité le devient (les trois faces)
    update public.authors
       set authority_type = 'collective',
           structured_meta = jsonb_set(coalesce(structured_meta, '{}'::jsonb), '{authorityType}', '"collective"'::jsonb, true)
     where id = v_author and coalesce(authority_type, '') not in ('collective', 'congress');
  end if;

  update public.book_contributors
     set name = p_nom_collectif, role = p_role, author_id = v_author
   where id = p_contrib_id;

  update public.books set autor = p_autor_apres where id = c.book_id and autor = p_autor_avant;

  insert into public.catalog_audit_log (actor_id, action, entity_type, entity_id, label, details)
  values (null, 'update', 'book', c.book_id, p_nom_collectif,
          jsonb_build_object('via', 'migration CONV-8 (fn_conv_requalifier_contributeur_collectif)',
                             'contributeur_avant', to_jsonb(c), 'autorite', v_author,
                             'autor_avant', p_autor_avant, 'autor_apres', p_autor_apres));
  return true;
end;
$$;

comment on function public.fn_conv_requalifier_contributeur_collectif(bigint, text, text, text, text, text) is
  'CONV-8 · requalifie une ligne de contributeur qui est en fait une COLLECTIVITÉ mal '
  'importée : autorité collective retrouvée ou créée (trois faces), ligne renommée et '
  'reliée avec son rôle, premier segment de la transcription réparé. Gardes : nom exact, '
  'aucune autorité déjà liée, transcription exacte. Migration seulement (aucun grant).';

revoke all on function public.fn_conv_requalifier_contributeur_collectif(bigint, text, text, text, text, text) from public, anon, authenticated;

do $$
begin
  if has_function_privilege('anon', 'public.fn_conv_requalifier_contributeur_collectif(bigint,text,text,text,text,text)', 'EXECUTE')
     or has_function_privilege('authenticated', 'public.fn_conv_requalifier_contributeur_collectif(bigint,text,text,text,text,text)', 'EXECUTE') then
    raise exception 'CONV-8 — la requalification est exécutable depuis l''application : abandon.';
  end if;
end $$;

-- La ligne 4543 de la notice 1828. 0 sur une base fraîche.
do $$
declare v_ok boolean;
begin
  v_ok := public.fn_conv_requalifier_contributeur_collectif(
    4543, 'Leueroth, Pelo Coletivo Edgar', 'Coletivo Edgard Leuenroth', 'organizacao',
    'Leueroth, Pelo Coletivo Edgar ; Löwy, Michael ; Sader, Eder ; Sandra Castro; Helena Hirata',
    'Coletivo Edgard Leuenroth ; Löwy, Michael ; Sader, Eder ; Sandra Castro; Helena Hirata');
  raise notice 'CONV-8 — Coletivo Edgard Leuenroth : % (true attendu en production, false sur une base fraîche).', v_ok;
end $$;

commit;
