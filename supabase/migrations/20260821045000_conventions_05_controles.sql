-- =====================================================================
-- CONVENTIONS CATALOGRAPHIQUES — 05 · Contrôles permanents
-- Foyer : REGISTRE §37 `CONV` · spec §8, critère d'acceptation n°2
--         (« chaque règle est testable »)
--
-- Cette migration ne corrige rien. Elle transforme les requêtes de
-- l'audit en contrôle permanent, pour que le drift soit VISIBLE au lieu
-- de se re-sédimenter en silence.
--
-- Doctrine : SIGNALER, JAMAIS BLOQUER (spec §7.1). Une notice mal formée
-- reste enregistrable ; c'est un indicateur de santé documentaire, pas
-- un reproche.
--
-- ---------------------------------------------------------------------
-- EXPOSITION — pourquoi la vue vit dans `private` et non dans `public`
--
-- Le cadrage posait la vue dans `public` avec `grant select … to
-- authenticated`, en la commentant « réservée au staff ». Elle ne l'était
-- pas : `authenticated`, c'est tout lecteur inscrit de la fédération, et
-- une vue sans `security_invoker` s'exécute avec les droits de son
-- propriétaire — la RLS des tables sous-jacentes ne s'applique pas. Cela
-- aurait ouvert un dump complet de `authors` (sort_name, preferred_name,
-- country) et des titres de `books` à n'importe quel compte : la même
-- famille de trou que les fonctions DEFINER ouvertes à `anon`.
--
-- Le gabarit maison (_TEMPLATE.sql) impose `WITH (security_invoker =
-- true)` pour toute vue, l'exception SECURITY DEFINER devant être
-- justifiée en COMMENT. Ici le choix est de NE PAS exposer la vue du
-- tout : elle vit dans `private` (hors Data API, aucun grant), et l'accès
-- passe par deux fonctions `api.*` SECURITY DEFINER gatées sur
-- `public.fn_caller_is_staff()`, conformément à DOC-OBJ-2. Ce détour
-- règle au passage un blocage : la vue appelle
-- `public.fn_conv_lower_stopwords`, dont la migration 03 révoque
-- l'EXECUTE — or le droit sur une fonction se vérifie contre l'appelant.
-- En passant par un wrapper DEFINER, c'est le propriétaire qui exécute.
--
-- COÛT : la vue est un UNION ALL de 9 balayages, dont un appelle une
-- fonction plpgsql PAR LIGNE de `books`. Elle n'est pas faite pour être
-- appelée en boucle — le goulot de l'instance est le pool PostgREST.
-- =====================================================================

begin;

create or replace view private.v_conv_controle_qualite
with (security_invoker = true) as

  -- --- Autorités : point d'accès sur un suffixe de filiation ---------
  select 'autoridade'::text  as dominio,
         'A3'::text          as regra,
         'ponto de acesso pelo sufixo de filiação'::text as problema,
         a.id::text          as id,
         a.sort_name         as valor
    from public.authors a
   where a.sort_name ~* '^(filho|júnior|junior|neto|sobrinho),'

  union all
  -- --- Autorités : particule en tête, langue qui la rejette ----------
  select 'autoridade', 'A2', 'partícula no início do ponto de acesso',
         a.id::text, a.sort_name
    from public.authors a
   where a.sort_name ~* '^(de|da|do|dos|das|del|von|zu)\s'
     and coalesce(a.name_lang, '') !~ '^(it|af|nl-BE)'

  union all
  -- --- Autorités : forme inversée dans le champ d'affichage ----------
  --     Resserré : on ne signale que la forme inversée AVÉRÉE (le champ
  --     d'affichage est le point d'accès), pas toute virgule — sans quoi
  --     les collectivités et les qualificatifs de fonction seraient
  --     signalés à perpétuité (CONV-2).
  select 'autoridade', 'A1', 'forma invertida em preferred_name',
         a.id::text, a.preferred_name
    from public.authors a
   where a.sort_name ~ ', '
     and upper(btrim(a.preferred_name)) = upper(btrim(a.sort_name))

  union all
  -- --- Autorités : capitales dans le point d'accès (CONV-1) ----------
  select 'autoridade', 'CONV-1', 'maiúsculas no ponto de acesso',
         a.id::text, a.sort_name
    from public.authors a
   where a.sort_name ~ '\m[A-ZÀ-Þ]{2,}\M'
     and a.sort_name !~ '[A-ZÀ-Þ]\.'       -- tolère les initiales : « Thompson, E. P. »

  union all
  -- --- Autorités : référentiel pays (CONV-7) -------------------------
  select 'autoridade', 'R1', 'country fora do referencial ISO 3166-1',
         a.id::text, a.country
    from public.authors a
   where a.country is not null and a.country !~ '^[A-Z]{2}$'

  union all
  -- --- Notices : article rejeté en fin (CONV-4) ----------------------
  select 'obra', 'T3', 'artigo rejeitado no fim do título',
         b.id::text, b.titulo
    from public.books b
   where b.titulo ~ ', (O|A|Os|As|Um|Uma|Le|La|Les|El|Los|Las|The)$'

  union all
  -- --- Notices : titre intégralement en capitales --------------------
  select 'obra', 'T2', 'título todo em maiúsculas',
         b.id::text, b.titulo
    from public.books b
   where b.titulo = upper(b.titulo)
     and b.titulo ~ '[A-ZÀ-Þ]{4,}'

  union all
  -- --- Notices : tiret de date perdu ---------------------------------
  select 'obra', 'T4', 'intervalo de datas sem hífen',
         b.id::text, b.titulo
    from public.books b
   where b.titulo ~ '1[6-9][0-9]{2} 1[6-9][0-9]{2}'

  union all
  -- --- Notices : mots-outils capitalisés (CONV-3) --------------------
  select 'obra', 'T1', 'palavra-ferramenta capitalizada',
         b.id::text, b.titulo
    from public.books b
   where b.idioma is not null
     and public.fn_conv_lower_stopwords(b.titulo, b.idioma) is distinct from b.titulo

  union all
  -- --- Notices : référentiel langue, hors référentiel (CONV-7) -------
  select 'obra', 'R2', 'idioma fora do referencial BCP-47',
         b.id::text, b.idioma
    from public.books b
   where b.idioma is not null and b.idioma !~ '^[a-z]{2}(-[A-Z]{2})?$'

  union all
  -- --- Notices : langue NON RENSEIGNÉE -------------------------------
  --     Règle distincte de R2 : CONV-7 pose que les NULL restent NULL
  --     (on n'invente pas une langue). Les compter comme « hors
  --     référentiel » noierait le signal sous ~471 violations
  --     structurellement irréparables par la convention seule.
  select 'obra', 'R3', 'idioma não informado',
         b.id::text, '(nulo)'::text
    from public.books b
   where b.idioma is null
;

comment on view private.v_conv_controle_qualite is
  'CONV · contrôle permanent des conventions catalographiques (REGISTRE §37). '
  'Signale, ne bloque jamais (spec §7.1). Alimente la file de vérification de '
  'l''Atelier autorités. Dans `private` et SANS grant : l''accès passe par '
  'api.conv_controle_qualite(), gatée staff — la lire largement reconstituerait '
  'l''annuaire des autorités. Libellés en pt-BR (DOC-I18N-1).';

-- --- Synthèse chiffrée ----------------------------------------------
create or replace view private.v_conv_controle_resumo
with (security_invoker = true) as
  select dominio, regra, problema, count(*) as total
    from private.v_conv_controle_qualite
   group by 1, 2, 3;

comment on view private.v_conv_controle_resumo is
  'CONV · synthèse chiffrée de v_conv_controle_qualite. À afficher au painel '
  'comme indicateur de santé documentaire, pas comme reproche.';

revoke all on private.v_conv_controle_qualite from public, anon, authenticated;
revoke all on private.v_conv_controle_resumo  from public, anon, authenticated;

-- =====================================================================
-- Accès staff — wrappers SECURITY DEFINER (DOC-OBJ-2)
-- =====================================================================

create or replace function api.conv_controle_qualite(
  p_regra  text default null,
  p_limite int  default 500
)
returns table (dominio text, regra text, problema text, id text, valor text)
language plpgsql
stable
security definer
set search_path to 'private', 'public', 'pg_catalog'
as $function$
begin
  if not public.fn_caller_is_staff() then
    raise exception 'acesso reservado à equipe' using errcode = '42501';
  end if;

  return query
    select v.dominio, v.regra, v.problema, v.id, v.valor
      from private.v_conv_controle_qualite v
     where p_regra is null or v.regra = p_regra
     order by v.dominio, v.regra, v.id
     limit greatest(1, least(coalesce(p_limite, 500), 5000));
end;
$function$;

comment on function api.conv_controle_qualite(text, int) is
  'CONV · file de vérification des conventions catalographiques, réservée à '
  'l''équipe (fn_caller_is_staff). SECURITY DEFINER assumé : la vue source vit '
  'dans `private` et appelle fn_conv_lower_stopwords, dont l''EXECUTE est '
  'révoqué (DOC-OBJ-2). Plafonnée à 5000 lignes — requête lourde.';

create or replace function api.conv_controle_resumo()
returns table (dominio text, regra text, problema text, total bigint)
language plpgsql
stable
security definer
set search_path to 'private', 'public', 'pg_catalog'
as $function$
begin
  if not public.fn_caller_is_staff() then
    raise exception 'acesso reservado à equipe' using errcode = '42501';
  end if;

  return query
    select r.dominio, r.regra, r.problema, r.total
      from private.v_conv_controle_resumo r
     order by r.total desc;
end;
$function$;

comment on function api.conv_controle_resumo() is
  'CONV · synthèse chiffrée du contrôle qualité, réservée à l''équipe. '
  'Indicateur de santé documentaire (spec §7.1), jamais un blocage.';

revoke all on function api.conv_controle_qualite(text, int) from public, anon;
revoke all on function api.conv_controle_resumo()          from public, anon;
grant execute on function api.conv_controle_qualite(text, int) to authenticated;
grant execute on function api.conv_controle_resumo()          to authenticated;

-- =====================================================================
-- Vérification (jouable sur base vide)
-- =====================================================================
do $$
declare
  n_familles bigint;
  n_grants   bigint;
begin
  select count(*) into n_familles from private.v_conv_controle_resumo;

  -- Invariant STRUCTUREL : ni anon ni public ne doivent pouvoir lire la vue.
  select count(*) into n_grants
    from information_schema.role_table_grants
   where table_schema = 'private'
     and table_name in ('v_conv_controle_qualite', 'v_conv_controle_resumo')
     and grantee in ('anon', 'PUBLIC', 'authenticated');

  if n_grants > 0 then
    raise exception 'CONV/05 — % grant(s) résiduel(s) sur les vues de contrôle : '
                    'l''annuaire des autorités serait lisible hors équipe. Abandon.',
                    n_grants;
  end if;

  raise notice 'CONV/05 — vue de contrôle créée dans `private`, accès staff via '
               'api.conv_controle_qualite/resumo. % famille(s) de signalement active(s).',
               n_familles;
end $$;

commit;
