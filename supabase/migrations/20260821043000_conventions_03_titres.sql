-- =====================================================================
-- CONVENTIONS CATALOGRAPHIQUES — 03 · Titres
-- Foyer : REGISTRE §37 `CONV` · CONV-3 (casse pilotée par la langue),
--         CONV-4 (article non-classant)
--
-- Réversible depuis conv_backup.books_20260820 (migration 00).
-- Prérequis : 01 (idioma en BCP-47) puis 02 (colonne title_nonfiling).
--
--   A. Dates dont le tiret a disparu à l'import  (~12 notices, mécanique)
--   B. Article rejeté en fin de titre            (10 notices, liste close)
--   C. Mots-outils capitalisés                   (~216 notices, ASSISTÉ)
--
-- ⚠️  Doctrine de vérification : les blocs de contrôle de ce fichier
--     SIGNALENT (raise warning + liste d'identifiants) au lieu de bloquer.
--     Une migration qui `raise exception` sur une condition de DONNÉES
--     avorte le déploiement entier dès qu'une fiche a bougé depuis
--     l'audit, ou dès qu'une notice est saisie dans l'ancien style — et
--     elle échoue systématiquement sur la base VIDE que reconstruit le
--     job CI `sql-tests`. Seuls les invariants structurels bloquent.
-- =====================================================================

begin;

-- =====================================================================
-- A. Tiret de date perdu :  « (1868 1910) » → « (1868-1910) »
--    Correction purement mécanique, aucun jugement documentaire.
-- =====================================================================
update public.books
   set titulo = regexp_replace(titulo, '(1[6-9][0-9]{2}) (1[6-9][0-9]{2})', '\1-\2', 'g')
 where titulo ~ '1[6-9][0-9]{2} 1[6-9][0-9]{2}';

update public.books
   set subtitulo = regexp_replace(subtitulo, '(1[6-9][0-9]{2}) (1[6-9][0-9]{2})', '\1-\2', 'g')
 where subtitulo ~ '1[6-9][0-9]{2} 1[6-9][0-9]{2}';

-- Espaces autour du tiret : « 1900 - 1930 » → « 1900-1930 ».
-- Le WHERE accepte l'espace d'UN SEUL côté (« 1900 -1930 », « 1900- 1930 »),
-- que le remplacement traite déjà.
update public.books
   set titulo = regexp_replace(titulo, '(1[6-9][0-9]{2})\s*-\s*(1[6-9][0-9]{2})', '\1-\2', 'g')
 where titulo ~ '1[6-9][0-9]{2}(\s+-|\s*-\s+)1[6-9][0-9]{2}';

update public.books
   set subtitulo = regexp_replace(subtitulo, '(1[6-9][0-9]{2})\s*-\s*(1[6-9][0-9]{2})', '\1-\2', 'g')
 where subtitulo ~ '1[6-9][0-9]{2}(\s+-|\s*-\s+)1[6-9][0-9]{2}';

-- =====================================================================
-- B. Article rejeté en fin de titre (vestige de la fiche cartonnée).
--    Liste CLOSE, établie fiche par fiche à l'audit §T3.
--    On ne généralise pas par regex : « Anarquismo, A Questão Social »
--    serait détruit par une règle automatique.
--
--    Chaque update est gardé par la valeur exacte attendue : si la fiche
--    a été éditée depuis l'audit, l'update ne s'applique pas — et le bloc
--    de contrôle le SIGNALE, il n'avorte pas la migration.
-- =====================================================================
update public.books set titulo = 'Os trabalhadores'                        where id = 68   and titulo = 'Trabalhadores, Os';
update public.books set titulo = 'A bomba'                                 where id = 667  and titulo = 'Bomba, A';
update public.books set titulo = 'Os anarquistas julgam Marx'              where id = 690  and titulo = 'Anarquistas Julgam Marx, Os';
update public.books set titulo = 'O Estado e seu papel histórico'          where id = 1134 and titulo = 'Estado E Seu Papel Historico, O';
update public.books set titulo = 'Los entresijos del anarquismo'           where id = 1173 and titulo = 'Entresijos Del Anarquismo, Los';
update public.books set titulo = 'A moral anarquista'                      where id = 1833 and titulo = 'Moral Anarquista, A';
update public.books set titulo = 'O processo de Luís XVI'                  where id = 1850 and titulo = 'Processo De Luis Xvi, O';
update public.books set titulo = 'O princípio anarquista e outros ensaios' where id = 1858 and titulo = 'Princípio Anarquista e Outros Ensaios, O';
update public.books set titulo = 'O reino de Deus está em vós'             where id = 1976 and titulo = 'Reino De Deus Esta Em Vos, O';
update public.books set titulo = 'A sociedade contra o Estado'             where id = 2061 and titulo = 'Sociedade Contra O Estado, A';

-- =====================================================================
-- C. Mots-outils capitalisés — fonction ASSISTÉE, pas passe aveugle.
--
--    La fonction abaisse la casse des SEULS mots-outils de la langue,
--    en position non-initiale, et ne touche à rien d'autre. Elle ne
--    « recasse » pas le titre : elle retire un artefact d'import (CONV-3).
--
--    Sont préservés : le premier mot, les mots après ponctuation forte,
--    les sigles et chiffres romains (2+ capitales consécutives : CNT,
--    IWW, FAU, XVI…).
-- =====================================================================

create or replace function public.fn_conv_lower_stopwords(p_title text, p_lang text)
returns text
language plpgsql
immutable
security invoker
set search_path = pg_catalog, public
as $$
declare
  stopwords text[];
  parts     text[];
  w         text;
  out_parts text[] := '{}';
  i         int;
  prev_end_colon boolean := false;
begin
  if p_title is null or p_lang is null then
    return p_title;
  end if;

  stopwords := case
    when p_lang like 'pt%' then array[
      'a','o','as','os','um','uma','uns','umas','de','da','do','das','dos',
      'em','na','no','nas','nos','por','pela','pelo','pelas','pelos','para',
      'com','sem','sob','sobre','entre','ao','aos','à','às','e','ou','que','se']
    when p_lang like 'es%' then array[
      'el','la','los','las','un','una','unos','unas','a','de','del','al','en',
      'por','para','con','sin','sobre','entre','y','e','o','u','que','se','su','sus']
    when p_lang like 'fr%' then array[
      'le','la','les','un','une','des','du','de','au','aux','à','en','dans',
      'par','pour','avec','sans','sur','sous','entre','et','ou','que','qui','ne']
    when p_lang like 'it%' then array[
      'il','lo','la','i','gli','le','un','uno','una','di','del','della','dei',
      'delle','da','dal','in','nel','con','su','sul','per','tra','fra','e','o','che']
    when p_lang like 'en%' then array[
      'a','an','the','of','in','on','at','to','for','with','from','by','and',
      'or','nor','but','as','is','it','its']
    when p_lang like 'ca%' then array[
      'el','la','els','les','un','una','de','del','dels','a','al','als','en',
      'amb','per','sobre','entre','i','o','que']
    when p_lang like 'eo%' then array['la','de','en','al','kun','por','kaj','aŭ','ke']
    -- Allemand : la casse des substantifs EST l'orthographe (CONV-3). On ne
    -- touche qu'aux mots-outils explicitement listés.
    when p_lang like 'de%' then array[
      'der','die','das','den','dem','des','ein','eine','einen','einem','eines',
      'und','oder','von','zu','zur','zum','in','im','an','am','auf','für','mit','als']
    else null
  end;

  if stopwords is null then
    return p_title;   -- langue non couverte : on ne touche à rien.
  end if;

  parts := regexp_split_to_array(p_title, '\s+');

  for i in 1 .. coalesce(array_length(parts, 1), 0) loop
    w := parts[i];

    if i = 1 or prev_end_colon then
      out_parts := out_parts || w;                       -- position initiale
    elsif w ~ '[A-ZÀ-Þ]{2,}' then
      out_parts := out_parts || w;                       -- sigle / chiffre romain
    elsif lower(btrim(w, '.,;:!?«»"''()')) = any(stopwords) then
      out_parts := out_parts || lower(w);                -- mot-outil → minuscule
    else
      out_parts := out_parts || w;                       -- tout le reste intact
    end if;

    -- Frontière de phrase. Le point final ne compte QUE s'il ne s'agit pas
    -- d'un sigle pointé : « La C.N.T. Y la revolución » ne redémarre pas une
    -- phrase après « C.N.T. ». Vérifié sur corpus réel (id 425-427).
    prev_end_colon := (w ~ '[:;?!]$')
                   or (w ~ '\.$' and w !~ '\..*\.' and length(w) > 2);
  end loop;

  return array_to_string(out_parts, ' ');
end $$;

comment on function public.fn_conv_lower_stopwords(text, text) is
  'CONV-3 · abaisse la casse des seuls mots-outils, en position non-initiale, '
  'selon la langue du titre. Ne recasse pas le titre. Sigles et chiffres romains '
  'préservés. Langue non couverte → identité. Outil interne du chantier '
  'conventions : non exposé (DOC-OBJ-2).';

revoke all on function public.fn_conv_lower_stopwords(text, text)
  from public, anon, authenticated, service_role;

-- --- Table de revue : proposition AVANT / APRÈS, rien n'est écrit ----
drop table if exists conv_backup.titres_a_revoir_20260820;
create table conv_backup.titres_a_revoir_20260820 as
select
  b.id,
  b.idioma,
  b.titulo                                              as avant,
  public.fn_conv_lower_stopwords(b.titulo, b.idioma)    as apres,
  false                                                 as valide
from public.books b
where b.idioma is not null
  and public.fn_conv_lower_stopwords(b.titulo, b.idioma) is distinct from b.titulo;

comment on table conv_backup.titres_a_revoir_20260820 is
  'CONV-3 · propositions de normalisation de casse. La fonction retire un artefact '
  'd''import, elle NE DÉCIDE PAS si un mot est un nom propre. Passer valide=true '
  'après relecture humaine, puis appliquer via le bloc commenté en fin de fichier. '
  'RIEN n''est écrit dans public.books par cette migration.';

-- =====================================================================
-- Recalcul de title_nonfiling pour les titres modifiés en B (CONV-4)
-- =====================================================================
update public.books set title_nonfiling = 2 where id in (667, 1833, 2061) and titulo ~ '^A ';
update public.books set title_nonfiling = 2 where id in (1134, 1850, 1976, 1858) and titulo ~ '^O ';
update public.books set title_nonfiling = 3 where id in (68, 690)          and titulo ~ '^Os ';
update public.books set title_nonfiling = 4 where id = 1173                and titulo ~ '^Los ';

-- =====================================================================
-- Vérification — SIGNALE, ne bloque pas (cf. doctrine en tête de fichier)
-- =====================================================================
do $$
declare
  n_dates    bigint;
  n_articles bigint;
  n_revue    bigint;
  n_nolang   bigint;
  n_books    bigint;
  l_dates    text;
  l_articles text;
begin
  select count(*) into n_books from public.books;

  select count(*), coalesce(string_agg(id::text, ', ' order by id), '')
    into n_dates, l_dates
    from public.books
   where titulo ~ '1[6-9][0-9]{2} 1[6-9][0-9]{2}'
      or subtitulo ~ '1[6-9][0-9]{2} 1[6-9][0-9]{2}';

  select count(*), coalesce(string_agg(id::text, ', ' order by id), '')
    into n_articles, l_articles
    from public.books
   where titulo ~ ', (O|A|Os|As|Um|Uma|Le|La|Les|El|Los|Las|The)$';

  select count(*) into n_revue  from conv_backup.titres_a_revoir_20260820;
  select count(*) into n_nolang from public.books where idioma is null;

  if n_dates > 0 then
    raise warning 'CONV/03·A — % titre(s)/sous-titre(s) portent encore un intervalle '
                  'de dates sans tiret : ids %. Cas non mécanisable (p. ex. trois '
                  'millésimes consécutifs) — à trancher à la main.', n_dates, l_dates;
  end if;

  if n_articles > 0 then
    raise warning 'CONV/03·B — % titre(s) à article rejeté subsistent : ids %. '
                  'La liste close de l''audit du 20/08 n''a pas couvert ces fiches '
                  '(éditées depuis, ou saisies après). À ajouter dans une migration '
                  'de suite, fiche par fiche.', n_articles, l_articles;
  end if;

  if n_books = 0 then
    raise notice 'CONV/03 — base sans notices (reconstruction CI) : rien à proposer.';
  elsif n_revue = 0 then
    raise warning 'CONV/03·C — 0 proposition de casse sur % notices. Vérifier que la '
                  'migration 01 a bien normalisé idioma : la partie C ne balaie que '
                  'les notices dont la langue est renseignée.', n_books;
  else
    raise notice 'CONV/03 — OK : dates et articles traités. % titres proposés à la revue '
                 'humaine ; % notices hors périmètre C faute de langue renseignée.',
                 n_revue, n_nolang;
  end if;
end $$;

commit;

-- =====================================================================
-- APPLICATION DE C — à jouer dans une migration SÉPARÉE, après revue
-- humaine de conv_backup.titres_a_revoir_20260820.
--
-- NE PAS décommenter ici. NE PAS écrire de script qui passe valide=true
-- en masse : la fonction propose, elle ne décide pas (REGISTRE §37).
--
--   update public.books b
--      set titulo = r.apres
--     from conv_backup.titres_a_revoir_20260820 r
--    where r.id = b.id
--      and r.valide
--      and b.titulo = r.avant;   -- garde anti-écrasement d'une édition
--                                -- survenue entre-temps
-- =====================================================================
