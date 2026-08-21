-- =====================================================================
-- CONVENTIONS CATALOGRAPHIQUES — 11 · Casse du point d'accès, 1re passe
-- Foyer : REGISTRE §37 `CONV` · CONV-1 + CONV-2
--
-- Lot `autorite_casse`, **non soldé** : 36 verdicts posés sur 61 au moment
-- d'écrire. On applique ce qui est tranché ; les 25 restants attendent, et
-- `applique_le` permet de repasser sans rien rejouer.
--
-- 32 « valider » et **4 « corriger à la main »**. Ces quatre-là justifient
-- à elles seules l'écran de revue : ce ne sont pas des corrections de casse
-- mais des REDÉCOUPAGES, qu'aucune fonction n'aurait trouvés.
--   GERTZ, Renê E.        -> Gertz, René E.            (accent, pas casse)
--   OMENA, Maria A. M. De -> Munhoz De Omena, Maria A. (patronyme composé)
--   PIMENTEL, Antonio De Serpa -> De Serpa Pimentel, Antonio
--   JANEIRO, Faculdade De Letras Universidade Federal do Rio De
--     -> Faculdade De Letras Universidade Federal do Rio De Janeiro
--
-- ---------------------------------------------------------------------
-- DEUX CAS QUE LA MIGRATION 10 NE CONNAISSAIT PAS
--
-- 1. UNE CIBLE SANS VIRGULE. La collectivité ci-dessus n'a pas de point
--    d'inversion : une personne morale ne se range pas « Nom, Prénom ».
--    La forme d'affichage ne peut donc pas se dériver par échange autour
--    de la virgule — elle est IDENTIQUE au point d'accès. Traité à part.
--
-- 2. UN VERDICT DEVENU CADUC. L'autorité 10079 (Luis Di Filippo) figure
--    dans les DEUX lots. Le lot patronyme l'a déjà corrigée en
--    « Di Filippo, Luis » (migration 10, appliquée). Mais la file de casse
--    montrait encore l'instantané « FILIPPO, Luis Di » pris à sa création,
--    et le verdict a été posé là-dessus : appliquer « Filippo, Luis Di »
--    DÉFERAIT la migration 10 et remettrait la particule à la fin — faux
--    pour un nom italien (CONV-6 : la règle suit la langue du NOM).
--
--    La garde stricte l'écarte d'elle-même. Mais elle l'écarterait en
--    SILENCE, et une ligne « validée, jamais appliquée » resterait à
--    perpétuité dans la file sans que personne sache pourquoi. Le bloc de
--    vérification la nomme donc, avec sa raison.
--
--    Leçon générale, à retenir pour les 211 titres : `avant` est un
--    INSTANTANÉ. Quand une même entité figure dans deux lots, le second
--    verdict peut être posé sur une réalité que le premier a déjà changée.
--    La garde stricte est ce qui empêche l'un de défaire l'autre — ne
--    jamais l'assouplir sans avoir mesuré POURQUOI elle refuse.
--    (En 10 elle a été assouplie à la casse près, et c'était juste : la
--    seule transformation subie était la casse. Ici l'écart est structurel,
--    donc on ne l'assouplit pas.)
-- =====================================================================

begin;

-- ---------------------------------------------------------------------
-- 1. Forme d'affichage — cible AVEC virgule (CONV-2)
--    Garde sur l'état actuel : on ne re-dérive que là où preferred_name
--    est encore exactement la forme mécaniquement dérivée du point d'accès
--    en place. Une fiche retouchée à la main garde la sienne.
-- ---------------------------------------------------------------------
update public.authors a
   set preferred_name = btrim(
         split_part(coalesce(nullif(btrim(q.valeur_retenue), ''), q.apres_propose), ', ', 2)
         || ' ' ||
         split_part(coalesce(nullif(btrim(q.valeur_retenue), ''), q.apres_propose), ', ', 1))
  from public.catalog_review_queue q
 where q.entity_id = a.id
   and q.lot = 'autorite_casse'
   and q.decision in ('valide', 'corrige')
   and q.applique_le is null
   and coalesce(nullif(btrim(q.valeur_retenue), ''), q.apres_propose) is not null
   and a.sort_name = q.avant
   and a.preferred_name = btrim(split_part(a.sort_name, ', ', 2) || ' ' || split_part(a.sort_name, ', ', 1))
   and (length(a.sort_name) - length(replace(a.sort_name, ',', ''))) = 1
   and (length(coalesce(nullif(btrim(q.valeur_retenue), ''), q.apres_propose))
        - length(replace(coalesce(nullif(btrim(q.valeur_retenue), ''), q.apres_propose), ',', ''))) = 1;

-- ---------------------------------------------------------------------
-- 2. Forme d'affichage — cible SANS virgule (collectivité, mononyme)
--    Pas d'inversion possible : l'affichage EST le point d'accès.
-- ---------------------------------------------------------------------
update public.authors a
   set preferred_name = coalesce(nullif(btrim(q.valeur_retenue), ''), q.apres_propose)
  from public.catalog_review_queue q
 where q.entity_id = a.id
   and q.lot = 'autorite_casse'
   and q.decision in ('valide', 'corrige')
   and q.applique_le is null
   and coalesce(nullif(btrim(q.valeur_retenue), ''), q.apres_propose) is not null
   and a.sort_name = q.avant
   and coalesce(nullif(btrim(q.valeur_retenue), ''), q.apres_propose) !~ ', ';

-- ---------------------------------------------------------------------
-- 3. Point d'accès (CONV-1) — garde STRICTE, cf. en-tête
-- ---------------------------------------------------------------------
update public.authors a
   set sort_name = coalesce(nullif(btrim(q.valeur_retenue), ''), q.apres_propose)
  from public.catalog_review_queue q
 where q.entity_id = a.id
   and q.lot = 'autorite_casse'
   and q.decision in ('valide', 'corrige')
   and q.applique_le is null
   and coalesce(nullif(btrim(q.valeur_retenue), ''), q.apres_propose) is not null
   and a.sort_name = q.avant;

-- ---------------------------------------------------------------------
-- 4. Marquer la file
-- ---------------------------------------------------------------------
update public.catalog_review_queue q
   set applique_le = now()
  from public.authors a
 where a.id = q.entity_id
   and q.lot = 'autorite_casse'
   and q.decision in ('valide', 'corrige')
   and q.applique_le is null
   and a.sort_name = coalesce(nullif(btrim(q.valeur_retenue), ''), q.apres_propose);

-- ---------------------------------------------------------------------
-- 5. Vérification — SIGNALE, ne bloque pas
-- ---------------------------------------------------------------------
do $$
declare
  n_lot      bigint;
  n_applique bigint;
  n_attente  bigint;
  n_refus    bigint;
  l_refus    text;
begin
  select count(*) into n_lot from public.catalog_review_queue where lot = 'autorite_casse';

  if n_lot = 0 then
    raise notice 'CONV/11 — file vide (reconstruction CI) : rien à appliquer.';
    return;
  end if;

  select count(*) into n_applique from public.catalog_review_queue
   where lot = 'autorite_casse' and applique_le is not null;
  select count(*) into n_attente from public.catalog_review_queue
   where lot = 'autorite_casse' and decision = 'a_revoir';

  -- Verdicts posés que la garde a refusés : le point d'accès en base ne
  -- correspond plus à l'instantané sur lequel la décision a été prise.
  select count(*), coalesce(string_agg(q.entity_id::text, ', ' order by q.entity_id), '')
    into n_refus, l_refus
    from public.catalog_review_queue q
    join public.authors a on a.id = q.entity_id
   where q.lot = 'autorite_casse'
     and q.decision in ('valide', 'corrige')
     and q.applique_le is null
     and a.sort_name <> q.avant;

  if n_refus > 0 then
    raise warning 'CONV/11 — % verdict(s) NON appliqué(s), autorité(s) % : le point '
                  'd''accès a changé depuis que la proposition a été enregistrée. '
                  'Cas connu au 21/08 : l''autorité 10079 figure aussi au lot patronyme, '
                  'déjà appliqué — appliquer le verdict de casse le DÉFERAIT. Ces lignes '
                  'sont à reprendre à la main, jamais à forcer.', n_refus, l_refus;
  end if;

  raise notice 'CONV/11 — % ligne(s) appliquée(s) sur % · % encore à revoir · % verdict(s) refusé(s) par la garde.',
               n_applique, n_lot, n_attente, n_refus;
end $$;

commit;
