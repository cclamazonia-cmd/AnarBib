-- =========================================================================
-- Le lot « autor_sans_autorite » rattache le contributeur qui existe déjà,
-- même quand sa graphie diffère un peu de la transcription : il n'ajoute
-- plus de ligne en double.
-- =========================================================================
-- Date     : 2026-10-04
-- Chantier : conventions de catalogage — file de vérification (C5/B)
-- Auteur   : Claude (Opus 5.5), pour Xavier
-- Session  : Doublons SNI & forme autorisée des contributeurs
--
-- Constat (04/10/2026, fiche /livro/2736, backlog E28) : appliqué le 03/09,
-- le lot a doublé le contributeur de cinq livres. api.conv_revue_appliquer ne
-- rattachait une ligne existante que si son nom égalait EXACTEMENT la
-- transcription, à la casse et aux accents près ; sinon il insérait une ligne
-- neuve. Les cinq cas :
--   « Serviço Nacional d Informações – SNI »  ≠ « … de Informações – SNI »
--   « RUSSELL, Bertrand »                     ≠ « Russel, Bertrand »    (×2)
--   « Golarons, Ricard de Vargas (org.) »     ≠ « Golarons, Ricard de Vargas »
--   « FERNANDES, Rubem César (Org) »          ≠ « FERNANDES, Rubem César »
-- Les données ont été corrigées à la main le 04/10 ; ce correctif empêche un
-- ré-ensemencement du lot de les recréer. La file est vide aujourd'hui
-- (446 appliquées, 18 écartées, aucune en attente) : rien n'est rejoué ici.
--
-- Règle de rapprochement, parmi les contributeurs NON LIÉS du livre :
--   clé = fn_normalize_name (minuscules, accents repliés, ponctuation retirée,
--         mots triés : « Bertrand Russell » = « RUSSELL, Bertrand ») après
--         retrait d'une parenthèse finale (« (org.) », « (Org) ») ;
--   retenu si la clé est égale, ou si la similarité trigramme des clés
--   atteint 0,6 ; à égalité de clé d'abord, puis par similarité, puis par
--   position. Une ligne neuve n'est insérée que si aucun ne ressemble.
-- Seuil mesuré en production le 04/10 : les cinq cas ont une clé égale ou une
-- similarité ≥ 0,83 ; entre contributeurs DISTINCTS d'un même livre, aucune
-- paire de personnes réellement différentes n'atteint 0,5 (les seules paires
-- au-dessus sont elles-mêmes des doublons).
--
-- Fonction reprise de sa définition en production (pg_get_functiondef,
-- 04/10) ; seul le bloc du lien change. Même signature : CREATE OR REPLACE
-- garde les droits existants (authenticated).
-- =========================================================================

-- Clé de comparaison d'un nom de contributeur.
CREATE OR REPLACE FUNCTION private.conv_cle_contributeur(p_nom text)
RETURNS text
LANGUAGE sql
IMMUTABLE
SET search_path TO 'public', 'pg_catalog'
AS $function$
  select public.fn_normalize_name(regexp_replace(coalesce(p_nom, ''), '\s*\([^)]*\)\s*$', ''))
$function$;

COMMENT ON FUNCTION private.conv_cle_contributeur(text) IS
  'Clé de rapprochement d''un nom de contributeur : fn_normalize_name après retrait d''une parenthèse finale ((org.), (Org)). Lot autor_sans_autorite, 04/10/2026.';

REVOKE EXECUTE ON FUNCTION private.conv_cle_contributeur(text) FROM PUBLIC, anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION api.conv_revue_appliquer(p_lot text)
 RETURNS TABLE(applique bigint, refuse bigint, nonfiling_reinit bigint)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
declare
  v_uid  uuid := auth.uid();
  v_app  bigint := 0;
  v_ref  bigint := 0;
  v_nf   bigint := 0;
  r      record;
  v_cible text;
  v_cle   text;
  v_author bigint;
  v_pref  text;
begin
  if not public.fn_caller_is_staff() then
    raise exception 'acesso reservado à equipe' using errcode = '42501';
  end if;

  if p_lot is null or p_lot not in ('titre_casse', 'autorite_casse',
                                    'autorite_patronyme', 'autorite_collectivite',
                                    'autor_sans_autorite', 'autorite_forme') then
    raise exception 'Lote inválido: %', p_lot using errcode = '22023';
  end if;

  -- ── AUTEURS SANS AUTORITÉ (C5/B) ─────────────────────────────────────
  if p_lot = 'autor_sans_autorite' then
    for r in
      select q.id, q.entity_id, public.fn_conv_cible(q.valeur_retenue, q.apres_propose) as cible, q.avant
        from public.catalog_review_queue q
       where q.lot = p_lot
         and q.decision in ('valide', 'corrige')
         and q.applique_le is null
         and public.fn_conv_cible(q.valeur_retenue, q.apres_propose) is not null
       order by q.id
    loop
      v_cible := btrim(r.cible);
      -- Anti-écrasement : la transcription doit être celle du semis, et aucun
      -- contributeur ne doit déjà porter d'autorité.
      if not exists (select 1 from public.books b where b.id = r.entity_id and b.autor = r.avant)
         or exists (select 1 from public.book_contributors c where c.book_id = r.entity_id and c.author_id is not null) then
        continue;
      end if;

      -- L'autorité : retrouvée sans casse ni accents, sur les deux formes et la
      -- forme dérivée (audit 03/09, §N2) ; sinon créée.
      v_author := public.fn_conv_autorite_homonyme(v_cible);
      if v_author is null then
        v_pref := case
          when v_cible ~ ', ' and (length(v_cible) - length(replace(v_cible, ',', ''))) = 1
            then btrim(split_part(v_cible, ', ', 2) || ' ' || split_part(v_cible, ', ', 1))
          else v_cible
        end;
        insert into public.authors (sort_name, preferred_name, source_kind, source_label)
        values (v_cible, v_pref, 'conv_revue', 'C5 · lot autor_sans_autorite')
        returning id into v_author;
      end if;

      -- Le lien : sur le contributeur non lié qui RESSEMBLE à la transcription
      -- (clé égale, ou similarité >= 0,6 — cf. en-tête, E28) ; une ligne neuve
      -- seulement si aucun ne ressemble.
      v_cle := private.conv_cle_contributeur(v_cible);
      update public.book_contributors c
         set author_id = v_author
       where c.id = (select c2.id from public.book_contributors c2
                      where c2.book_id = r.entity_id and c2.author_id is null
                        and (private.conv_cle_contributeur(c2.name) = v_cle
                             or extensions.similarity(private.conv_cle_contributeur(c2.name), v_cle) >= 0.6)
                      order by (private.conv_cle_contributeur(c2.name) = v_cle) desc,
                               extensions.similarity(private.conv_cle_contributeur(c2.name), v_cle) desc,
                               c2.position
                      limit 1);
      if not found then
        insert into public.book_contributors (book_id, author_id, position, name, role, is_primary)
        select r.entity_id, v_author,
               coalesce((select max(c3.position) from public.book_contributors c3 where c3.book_id = r.entity_id), 0) + 1,
               v_cible, 'autor',
               not exists (select 1 from public.book_contributors c4 where c4.book_id = r.entity_id and c4.is_primary);
      end if;

      update public.catalog_review_queue q
         set applique_le = now(), applique_par = v_uid
       where q.id = r.id
         and exists (select 1 from public.book_contributors c where c.book_id = r.entity_id and c.author_id is not null);
      if found then v_app := v_app + 1; end if;
    end loop;

  -- ── COLLECTIVITÉS ────────────────────────────────────────────────────
  elsif p_lot = 'autorite_collectivite' then

    update public.authors a
       set authority_type = 'collective',
           structured_meta = jsonb_set(coalesce(a.structured_meta, '{}'::jsonb),
                                       '{authorityType}', '"collective"'::jsonb, true),
           sort_name       = public.fn_conv_cible(q.valeur_retenue, q.apres_propose),
           preferred_name  = public.fn_conv_cible(q.valeur_retenue, q.apres_propose)
      from public.catalog_review_queue q
     where q.entity_id = a.id
       and q.lot = p_lot
       and q.decision in ('valide', 'corrige')
       and q.applique_le is null
       and public.fn_conv_cible(q.valeur_retenue, q.apres_propose) is not null
       and a.sort_name = q.avant;

    with faits as (
      update public.catalog_review_queue q
         set applique_le = now(), applique_par = v_uid
        from public.authors a
       where a.id = q.entity_id
         and q.lot = p_lot
         and q.decision in ('valide', 'corrige')
         and q.applique_le is null
         and a.sort_name = public.fn_conv_cible(q.valeur_retenue, q.apres_propose)
         and a.authority_type = 'collective'
      returning 1
    )
    select count(*) into v_app from faits;

  -- ── AUTORITÉS (casse, patronymes, forme) ─────────────────────────────
  elsif p_lot in ('autorite_casse', 'autorite_patronyme', 'autorite_forme') then

    update public.authors a
       set preferred_name = case
             when public.fn_conv_cible(q.valeur_retenue, q.apres_propose) ~ ', '
              and (length(public.fn_conv_cible(q.valeur_retenue, q.apres_propose))
                   - length(replace(public.fn_conv_cible(q.valeur_retenue, q.apres_propose), ',', ''))) = 1
             then btrim(split_part(public.fn_conv_cible(q.valeur_retenue, q.apres_propose), ', ', 2)
                        || ' ' ||
                        split_part(public.fn_conv_cible(q.valeur_retenue, q.apres_propose), ', ', 1))
             else public.fn_conv_cible(q.valeur_retenue, q.apres_propose)
           end
      from public.catalog_review_queue q
     where q.entity_id = a.id
       and q.lot = p_lot
       and q.decision in ('valide', 'corrige')
       and q.applique_le is null
       and public.fn_conv_cible(q.valeur_retenue, q.apres_propose) is not null
       and a.sort_name = q.avant
       and a.preferred_name = btrim(split_part(a.sort_name, ', ', 2) || ' ' || split_part(a.sort_name, ', ', 1));

    update public.authors a
       set sort_name = public.fn_conv_cible(q.valeur_retenue, q.apres_propose)
      from public.catalog_review_queue q
     where q.entity_id = a.id
       and q.lot = p_lot
       and q.decision in ('valide', 'corrige')
       and q.applique_le is null
       and public.fn_conv_cible(q.valeur_retenue, q.apres_propose) is not null
       and a.sort_name = q.avant;

    with faits as (
      update public.catalog_review_queue q
         set applique_le = now(), applique_par = v_uid
        from public.authors a
       where a.id = q.entity_id
         and q.lot = p_lot
         and q.decision in ('valide', 'corrige')
         and q.applique_le is null
         and a.sort_name = public.fn_conv_cible(q.valeur_retenue, q.apres_propose)
      returning 1
    )
    select count(*) into v_app from faits;

  -- ── NOTICES ──────────────────────────────────────────────────────────
  else
    update public.books b
       set titulo = public.fn_conv_cible(q.valeur_retenue, q.apres_propose)
      from public.catalog_review_queue q
     where q.entity_id = b.id
       and q.lot = p_lot
       and q.decision in ('valide', 'corrige')
       and q.applique_le is null
       and public.fn_conv_cible(q.valeur_retenue, q.apres_propose) is not null
       and b.titulo = q.avant;

    with faits as (
      update public.catalog_review_queue q
         set applique_le = now(), applique_par = v_uid
        from public.books b
       where b.id = q.entity_id
         and q.lot = p_lot
         and q.decision in ('valide', 'corrige')
         and q.applique_le is null
         and b.titulo = public.fn_conv_cible(q.valeur_retenue, q.apres_propose)
      returning 1
    )
    select count(*) into v_app from faits;

    with remis as (
      update public.books b
         set title_nonfiling = 0
       where b.title_nonfiling is not null
         and b.title_nonfiling > 0
         and b.id in (select q2.entity_id from public.catalog_review_queue q2
                       where q2.lot = p_lot and q2.applique_le is not null)
         and substr(b.titulo, b.title_nonfiling, 1) not in (' ', '''', '’')
      returning 1
    )
    select count(*) into v_nf from remis;
  end if;

  select count(*) into v_ref
    from public.catalog_review_queue q
   where q.lot = p_lot
     and q.decision in ('valide', 'corrige')
     and q.applique_le is null;

  return query select v_app, v_ref, v_nf;
end;
$function$;
