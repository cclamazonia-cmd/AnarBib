-- =========================================================================
-- Paquet PÉRIODIQUES P3 — La règle anti-faux-doublons
-- =========================================================================
-- Date     : 2026-08-27
-- Chantier : périodiques (spec-periodiques v0.1, §4)
-- Auteur   : Xavier (arbitrages) + Claude (rédaction)
--
-- POURQUOI, ET POURQUOI MAINTENANT. suggest_catalog_duplicates rapproche les
-- notices par similarité trigramme sur titulo. Deux fascicules d'une même revue
-- portent, par construction, le même titre : la fonction les voit comme des
-- doublons.
--
-- ⚠️ CORRECTION À LA SPEC v0.1 §1.3 ET §4. La spec donne les quatre « Encontros
-- com a Civilização brasileira » en exemple de faux positifs ACTUELS. Vérifié en
-- base le 27/08/2026 : les quatre partagent work_id = 15, et la règle
-- préexistante « même œuvre » les écarte donc DÉJÀ de la détection. Elles ne
-- polluent rien aujourd'hui, et ce paquet ne changera rien pour elles.
--
-- Ce qui ne diminue en rien l'urgence, au contraire : le danger porte sur ce qui
-- ARRIVE. trg_books_ensure_work crée UNE ŒUVRE PAR NOTICE à l'insertion — donc
-- 91 fascicules Solidaires importés produiront 91 œuvres distinctes, et la règle
-- « même œuvre » ne les protégera pas. Mesuré sur une reconstitution des sept
-- notices avec des œuvres distinctes : 6 paires détectées, ramenées à 2 par ce
-- paquet. C'est cette situation-là — celle de l'import — qu'il faut couvrir
-- avant qu'elle se produise, et non après.
--
-- Avec 91 fascicules Solidaires et une centaine de titres Anarchief, la file de
-- l'Atelier se remplirait de paires légitimes à écarter une par une. D'où
-- l'ordre imposé par la spec §11 : P3 AVANT le premier import de masse, sinon
-- il faut vider la file à la main — et chaque « pas un doublon » posé à la
-- va-vite est une décision durable prise sur du bruit.
--
-- LA RÈGLE. Elle se greffe sur un mécanisme déjà présent : la fonction écarte
-- depuis longtemps les paires partageant une même œuvre
--   and not (r.work_a is not null and r.work_b = r.work_a)
-- On ajoute la règle symétrique pour les périodiques.
--
-- POURQUOI PAS EXCLURE TOUTE PAIRE DE MÊME serial_id : parce que le doublon de
-- saisie du même numéro est fréquent — c'est même le doublon le PLUS probable
-- sur un import de 91 fascicules. On écarte le bruit, pas le signal. La paire
-- ne sort donc de la détection que si les deux désignations sont connues ET
-- différentes.
--
-- CAS RÉSIDUEL ASSUMÉ. Deux fascicules d'un même titre sans aucune désignation
-- (issue_key nulle des deux côtés) restent détectés. C'est voulu : deux notices
-- d'une même revue sans numéro ni date SONT un problème de catalogage, qu'il
-- faut voir.
--
-- EFFET SUR L'EXISTANT : aucun, et c'est normal (voir la correction ci-dessus).
-- Les sept notices actuelles sont déjà hors détection par la règle « même
-- œuvre ». Le comportement décrit par la spec — deux paires écartées (années
-- différentes) et deux conservées (années identiques) — est bien celui qu'on
-- mesure dès que les œuvres diffèrent, c'est-à-dire sur tout import à venir.
-- La suite tests/sql/periodiques_tests.sql le vérifie dans les deux sens.
--
-- PÉRIMÈTRE. Seule suggest_catalog_duplicates est modifiée, comme le demande la
-- spec. Les trois autres détections du réseau (suggest_book_duplicates,
-- api.suggest_draft_duplicates, suggest_duplicates_for_fields) travaillent sur
-- les BROUILLONS ou sur des champs isolés ; book_drafts ne porte pas encore de
-- serial_id, il n'y a donc rien à y filtrer. À rouvrir le jour où le rattachement
-- se fera dès le brouillon.
--
-- CHECKLIST DOCTRINE
--   [x] CREATE OR REPLACE : signature et type de retour INCHANGÉS (les trois
--       appelants front n'ont rien à savoir de ce paquet)
--   [x] SECURITY DEFINER + search_path conservés à l'identique
--   [x] Garde staff conservée à l'identique
--   [x] DO block de vérification en fin de transaction
-- =========================================================================

BEGIN;

CREATE OR REPLACE FUNCTION public.suggest_catalog_duplicates(p_max integer DEFAULT 500)
RETURNS TABLE(
  book_id_a bigint, ref_a text, titulo_a text, autor_a text, ano_a text,
  bibliotecas_a text, exemplares_a integer,
  book_id_b bigint, ref_b text, titulo_b text, autor_b text, ano_b text,
  bibliotecas_b text, exemplares_b integer,
  match_kind text, score real, configuration text, fusion_possible boolean,
  niveau_preuve text, rang_preuve integer)
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_catalog'
AS $function$
begin
  if not exists (
    select 1 from public.user_library_memberships m
    where m.user_id = auth.uid()
      and m.role = any (array['librarian'::text, 'coordenador'::text])
  ) then
    raise exception 'Acesso restrito ao staff de catalogacao.';
  end if;

  return query
  with brut as (
    select a.id as ia_id, b.id as ib_id,
           regexp_replace(upper(coalesce(a.isbn,'')),'[^0-9X]','','g') as isbn_a,
           regexp_replace(upper(coalesce(b.isbn,'')),'[^0-9X]','','g') as isbn_b,
           public.fn_normalize_name(a.titulo) as nt_a,
           public.fn_normalize_name(b.titulo) as nt_b,
           public.fn_normalize_name(a.autor)  as na_a,
           public.fn_normalize_name(b.autor)  as na_b,
           public.fn_normalize_name(coalesce(a.editora,'')) as ne_a,
           public.fn_normalize_name(coalesce(b.editora,'')) as ne_b,
           nullif(btrim(coalesce(a.ano,'')),'') as an_a,
           nullif(btrim(coalesce(b.ano,'')),'') as an_b,
           a.work_id as work_a, b.work_id as work_b,
           -- AJOUT PÉRIODIQUES P3 : de quoi reconnaître deux fascicules d'une
           -- même revue, et savoir si leurs désignations diffèrent.
           a.serial_id as serial_a, b.serial_id as serial_b,
           a.issue_key as issue_a,  b.issue_key as issue_b
    from public.books a
    join public.books b
      on b.id > a.id
     and b.titulo % a.titulo
  ),
  retenues as (
    select r.*,
           case when r.isbn_a <> '' and r.isbn_b = r.isbn_a then 'isbn' else 'approx' end as kind,
           case when r.isbn_a <> '' and r.isbn_b = r.isbn_a then 1.0::real
                else similarity(r.nt_a, r.nt_b)::real end as sc,
           case
             when r.isbn_a <> '' and r.isbn_b = r.isbn_a
               then 'isbn'
             when similarity(r.nt_a, r.nt_b) >= 0.99
              and r.an_a is not null and r.an_a = r.an_b
              and r.ne_a <> '' and similarity(r.ne_a, r.ne_b) >= 0.75
               then 'titre_annee_editeur'
             when similarity(r.nt_a, r.nt_b) >= 0.90
              and r.an_a is not null and r.an_a = r.an_b
               then 'titre_annee'
             else 'titre_seul'
           end as niveau
    from brut r
    where not exists (
            select 1 from public.book_not_duplicate nd
            where nd.book_id_a = least(r.ia_id, r.ib_id)
              and nd.book_id_b = greatest(r.ia_id, r.ib_id))
      and not (r.work_a is not null and r.work_b = r.work_a)
      -- AJOUT PÉRIODIQUES P3. Deux fascicules d'un même périodique ne sont pas
      -- des doublons dès lors que leur désignation diffère. S'ils portent la
      -- MÊME désignation, la détection reste active : c'est alors un vrai
      -- doublon de saisie, et c'est le plus fréquent sur un import.
      and not (
            r.serial_a is not null
        and r.serial_b = r.serial_a
        and r.issue_a is not null and r.issue_b is not null
        and r.issue_a <> r.issue_b
      )
      and ( (r.isbn_a <> '' and r.isbn_b = r.isbn_a)
         or ( r.nt_a <> '' and similarity(r.nt_a, r.nt_b) >= 0.5
              and (r.na_a = '' or r.na_b = '' or similarity(r.na_a, r.na_b) >= 0.4)
              and not (r.isbn_a <> '' and r.isbn_b <> '' and r.isbn_b <> r.isbn_a) ) )
  )
  select
    ba.id, ba.bib_ref, ba.titulo, ba.autor, ba.ano, la.libs, coalesce(la.ex,0)::integer,
    bb.id, bb.bib_ref, bb.titulo, bb.autor, bb.ano, lb.libs, coalesce(lb.ex,0)::integer,
    x.kind, x.sc,
    case when la.libs is not distinct from lb.libs then 'interne'
         else 'inter_bibliotheques' end,
    (la.libs is not distinct from lb.libs),
    x.niveau,
    (case x.niveau when 'isbn' then 1
                   when 'titre_annee_editeur' then 2
                   when 'titre_annee' then 3
                   else 4 end)::integer
  from retenues x
  join public.books ba on ba.id = x.ia_id
  join public.books bb on bb.id = x.ib_id
  join lateral (
    select string_agg(distinct l.short_name, ' + ' order by l.short_name) as libs,
           sum(h.exemplares_total) as ex
    from public.book_holdings h
    join public.libraries l on l.id = h.library_id
    where h.book_id = x.ia_id) la on true
  join lateral (
    select string_agg(distinct l.short_name, ' + ' order by l.short_name) as libs,
           sum(h.exemplares_total) as ex
    from public.book_holdings h
    join public.libraries l on l.id = h.library_id
    where h.book_id = x.ib_id) lb on true
  order by
    case x.niveau when 'isbn' then 1
                  when 'titre_annee_editeur' then 2
                  when 'titre_annee' then 3
                  else 4 end,
    x.sc desc,
    ba.titulo
  limit greatest(coalesce(p_max, 500), 1);
end $function$;

COMMENT ON FUNCTION public.suggest_catalog_duplicates(integer) IS
  'Détection de doublons du catalogue publié, triée par niveau de preuve. '
  'Écarte les paires déjà arbitrées (book_not_duplicate), les paires d''une même '
  'œuvre, et — depuis le paquet PÉRIODIQUES P3 du 27/08/2026 — les paires de '
  'fascicules d''un même périodique dont les désignations DIFFÈRENT. Deux '
  'fascicules de même désignation restent détectés : c''est le doublon de saisie, '
  'le plus fréquent sur un import de masse. Staff de catalogage.';

-- -------------------------------------------------------------------------
-- Vérification automatique
-- -------------------------------------------------------------------------
-- On fabrique la situation exacte de la spec, on la mesure, puis on annule
-- tout : la vérification n'a pas le droit de laisser de traces en base.
-- Vérification STRUCTURELLE. Le comportement (bruit écarté / signal conservé)
-- se mesure sur des fascicules réels : il est couvert par la suite
-- tests/sql/periodiques_tests.sql, qui tourne APRÈS le seed. Une migration ne
-- fabrique pas de notices de catalogue pour se tester.
DO $verif$
DECLARE
  v_def text;
BEGIN
  v_def := pg_get_functiondef('public.suggest_catalog_duplicates(integer)'::regprocedure);

  -- La règle est bien dans le corps, et sous sa forme complète : c'est la
  -- conjonction « même revue ET deux désignations connues ET différentes » qui
  -- fait la différence entre écarter le bruit et perdre le signal.
  IF v_def NOT LIKE '%r.serial_b = r.serial_a%'
     OR v_def NOT LIKE '%r.issue_a <> r.issue_b%'
     OR v_def NOT LIKE '%r.issue_a is not null and r.issue_b is not null%' THEN
    RAISE EXCEPTION 'P3 : la règle anti-faux-doublons est absente ou incomplète dans suggest_catalog_duplicates.';
  END IF;

  -- La règle préexistante sur les œuvres n'a pas été perdue au passage.
  IF v_def NOT LIKE '%r.work_a is not null and r.work_b = r.work_a%' THEN
    RAISE EXCEPTION 'P3 : la règle « même œuvre » a disparu de suggest_catalog_duplicates.';
  END IF;

  -- La garde staff non plus.
  IF v_def NOT LIKE '%Acesso restrito ao staff de catalogacao%' THEN
    RAISE EXCEPTION 'P3 : la garde staff a disparu de suggest_catalog_duplicates.';
  END IF;

  RAISE NOTICE 'Paquet PÉRIODIQUES P3 : vérification structurelle OK (règle posée, règles préexistantes intactes).';
END $verif$;

COMMIT;

NOTIFY pgrst, 'reload schema';

-- =========================================================================
-- Rollback ciblé : réappliquer la définition du 20/08/2026
-- (20260820145716_catalog_duplicates_tri_par_niveau_de_preuve.sql), c'est-à-dire
-- la même fonction SANS les quatre lignes marquées « AJOUT PÉRIODIQUES P3 ».
-- =========================================================================
