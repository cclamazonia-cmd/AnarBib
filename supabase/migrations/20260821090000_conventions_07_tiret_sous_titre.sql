-- =====================================================================
-- CONVENTIONS CATALOGRAPHIQUES — 07 · Le tiret de sous-titre est une
--                                      frontiere de phrase (CONV-3)
-- Foyer : REGISTRE §37 `CONV`
--
-- DEFAUT CONSTATE a la relecture de la table de revue. La fonction
-- traitait `:` `;` `?` `!` et le point final comme des frontieres, mais
-- pas le TIRET, qui en est une : apres lui, un sous-titre redemarre, et
-- son premier mot garde donc sa capitale.
--
--   Durruti - Da Revolta a Revolucao        -> « - da Revolta »     FAUX
--   Libertando a vida - A revolucao das ... -> « - a revolucao »    FAUX
--   O Homem e a Terra - A Cultura e a ...   -> « - a Cultura »      FAUX
--
-- 11 propositions sur 222 etaient concernees. Un defaut systematique se
-- corrige a la source : le rejeter a la main a la revue le ferait
-- revenir a la prochaine notice cataloguee.
--
-- Rien n'est ecrit dans public.books : la table de revue est REGENEREE,
-- et seulement si aucun verdict humain n'y a encore ete pose.
-- =====================================================================

begin;

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
    -- Allemand : la casse des substantifs EST l'orthographe (CONV-3).
    when p_lang like 'de%' then array[
      'der','die','das','den','dem','des','ein','eine','einen','einem','eines',
      'und','oder','von','zu','zur','zum','in','im','an','am','auf','für','mit','als']
    else null
  end;

  if stopwords is null then
    return p_title;   -- langue non couverte : on ne touche a rien.
  end if;

  parts := regexp_split_to_array(p_title, '\s+');

  for i in 1 .. coalesce(array_length(parts, 1), 0) loop
    w := parts[i];

    if i = 1 or prev_end_colon then
      out_parts := out_parts || w;                       -- position initiale
    elsif w ~ '[A-ZÀ-Þ]{2,}' then
      out_parts := out_parts || w;                       -- sigle / chiffre romain
    elsif lower(btrim(w, '.,;:!?«»"''()')) = any(stopwords) then
      out_parts := out_parts || lower(w);                -- mot-outil -> minuscule
    else
      out_parts := out_parts || w;                       -- tout le reste intact
    end if;

    -- Frontiere de phrase. Le point final ne compte QUE s'il ne s'agit pas
    -- d'un sigle pointe : « La C.N.T. Y la revolucion » ne redemarre pas une
    -- phrase apres « C.N.T. ». Vérifié sur corpus réel (id 425-427).
    --
    -- AJOUT 21/08 : le TIRET ISOLE (« Durruti - Da Revolta a Revolucao »)
    -- introduit un sous-titre, donc une nouvelle phrase. Trois graphies
    -- circulent dans le fonds : trait d'union, demi-cadratin, cadratin. On
    -- ne traite que le tiret ISOLE entre deux espaces : « Sacher-Masoch »
    -- ou « anarcho-syndicalisme » n'ouvrent evidemment rien.
    prev_end_colon := (w ~ '[:;?!]$')
                   or (w ~ '\.$' and w !~ '\..*\.' and length(w) > 2)
                   or (w in ('-', '–', '—'));
  end loop;

  return array_to_string(out_parts, ' ');
end $$;

comment on function public.fn_conv_lower_stopwords(text, text) is
  'CONV-3 · abaisse la casse des seuls mots-outils, en position non-initiale, '
  'selon la langue du titre. Frontieres de phrase : ponctuation forte, point '
  'final non-sigle, et TIRET ISOLE (sous-titre, corrige le 21/08). Ne recasse '
  'pas le titre. Sigles et chiffres romains preserves. Outil interne : non expose.';

revoke all on function public.fn_conv_lower_stopwords(text, text)
  from public, anon, authenticated, service_role;

-- ---------------------------------------------------------------------
-- Regeneration de la table de revue — SEULEMENT si elle est vierge.
--
-- Un verdict humain deja pose ne doit jamais etre efface par une
-- correction d'outil : c'est du travail de relecture, pas du cache.
-- ---------------------------------------------------------------------
do $$
declare
  n_verdicts bigint := 0;
  n_avant    bigint := 0;
  n_apres    bigint := 0;
begin
  if to_regclass('conv_backup.titres_a_revoir_20260820') is null then
    raise notice 'CONV/07 — pas de table de revue (base neuve) : rien a regenerer.';
    return;
  end if;

  select count(*) into n_verdicts from conv_backup.titres_a_revoir_20260820 where valide;
  select count(*) into n_avant    from conv_backup.titres_a_revoir_20260820;

  if n_verdicts > 0 then
    raise warning 'CONV/07 — % verdict(s) deja pose(s) : table NON regeneree. '
                  'Relire a la main les propositions comportant un tiret de '
                  'sous-titre, ou vider les verdicts avant de rejouer.', n_verdicts;
    return;
  end if;

  drop table conv_backup.titres_a_revoir_20260820;

  create table conv_backup.titres_a_revoir_20260820 as
  select b.id, b.idioma, b.titulo as avant,
         public.fn_conv_lower_stopwords(b.titulo, b.idioma) as apres,
         false as valide
    from public.books b
   where b.idioma is not null
     and public.fn_conv_lower_stopwords(b.titulo, b.idioma) is distinct from b.titulo;

  comment on table conv_backup.titres_a_revoir_20260820 is
    'CONV-3 · propositions de normalisation de casse, regenerees le 21/08 apres '
    'correction du tiret de sous-titre. La fonction retire un artefact d''import, '
    'elle NE DECIDE PAS si un mot est un nom propre. Passer valide=true apres '
    'relecture humaine. RIEN n''est ecrit dans public.books par cette migration.';

  select count(*) into n_apres from conv_backup.titres_a_revoir_20260820;
  raise notice 'CONV/07 — table de revue regeneree : % propositions (avant : %).',
               n_apres, n_avant;
end $$;

commit;
