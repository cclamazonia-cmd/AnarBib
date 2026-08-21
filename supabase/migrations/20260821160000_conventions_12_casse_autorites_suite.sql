-- =====================================================================
-- CONVENTIONS CATALOGRAPHIQUES — 12 · Casse des autorités, seconde passe
-- Foyer : REGISTRE §37 `CONV` · CONV-1, CONV-2, CONV-6
--
-- 21 verdicts posés depuis la migration 11 : 11 « valider », 10 « corriger
-- à la main ». Le lot n'est toujours pas soldé (5 lignes restent à revoir),
-- et `applique_le` permet de repasser sans rien rejouer.
--
-- ---------------------------------------------------------------------
-- SECTION 1 — QUATRE VERDICTS AMENDÉS, SUR DEMANDE ET POUR CAUSE
--
-- Quatre des dix corrections manuelles plaçaient la particule EN TÊTE du
-- point d'accès, pour des noms français et portugais. La migration 04,
-- appliquée le 21/08 dans ce même chantier, a tranché l'inverse pour ces
-- langues — `Beauvoir, Simone de`, `Sousa, Manuel Joaquim de`,
-- `Carvalho, Florentino de`. Appliquer les deux régimes, c'est reconstituer
-- exactement le désordre que CONV-1/CONV-6 démontent.
--
-- Signalé à la coordination, qui a demandé l'alignement sur la convention
-- (21/08). Les valeurs sont donc amendées ICI, et l'amendement est tracé
-- dans `note` : un verdict humain qu'on modifie doit rester lisible comme
-- tel, sinon la file ment sur sa propre provenance.
--
-- CE QUI N'EST PAS AMENDÉ, et c'est une erreur de ma part corrigée avant
-- écriture : `Van Paassen, Pierre` a d'abord été signalé comme contraire à
-- `Jong, Rudolf de`. À tort. La règle suit la langue du NOM (CONV-6), mais
-- la tradition qui catalogue la personne compte aussi : Rudolf de Jong,
-- néerlandais aux Pays-Bas, s'entre « Jong, … de » ; Pierre van Paassen et
-- A. E. van Vogt, émigrés en Amérique du Nord, sont entrés « Van Paassen »
-- et « Van Vogt » à la Library of Congress. Les deux verdicts de la
-- coordination étaient bons ; c'est mon objection qui était trop large.
-- =====================================================================

begin;

-- Ferdinand de Saussure — francophone. Précédent : `Beauvoir, Simone de`.
update public.catalog_review_queue
   set valeur_retenue = 'Saussure, Ferdinand de',
       note = coalesce(note || ' · ', '')
              || 'valeur amendée le 21/08 (CONV-6, nom français : particule rejetée) — '
              || 'verdict d''origine : « De Saussure, Ferdinand »'
 where lot = 'autorite_casse' and entity_id = 11149 and applique_le is null
   and valeur_retenue = 'De Saussure, Ferdinand';

-- João de Scantimburgo — brésilien. Précédent : `Sousa, Manuel Joaquim de`.
update public.catalog_review_queue
   set valeur_retenue = 'Scantimburgo, João de',
       note = coalesce(note || ' · ', '')
              || 'valeur amendée le 21/08 (CONV-6, nom portugais : particule rejetée) — '
              || 'verdict d''origine : « De Scantimburgo, João »'
 where lot = 'autorite_casse' and entity_id = 11150 and applique_le is null
   and valeur_retenue = 'De Scantimburgo, João';

-- Ângela Maria de Castro Gomes — brésilienne. L'entrée se fait sur le
-- DERNIER élément du nom en portugais. Le circonflexe manquant est rétabli
-- au passage : « Angela » n'est pas une graphie, c'est une perte d'import.
update public.catalog_review_queue
   set valeur_retenue = 'Gomes, Ângela Maria de Castro',
       note = coalesce(note || ' · ', '')
              || 'valeur amendée le 21/08 (CONV-6, nom portugais : entrée sur le dernier '
              || 'élément, particule rejetée ; circonflexe rétabli) — '
              || 'verdict d''origine : « De Castro Gomes, Angela Maria »'
 where lot = 'autorite_casse' and entity_id = 10658 and applique_le is null
   and valeur_retenue = 'De Castro Gomes, Angela Maria';

-- Paulo Sérgio de Moraes Sarmento Pinheiro — brésilien. Même règle.
update public.catalog_review_queue
   set valeur_retenue = 'Pinheiro, Paulo Sérgio de Moraes Sarmento',
       note = coalesce(note || ' · ', '')
              || 'valeur amendée le 21/08 (CONV-6, nom portugais : entrée sur le dernier '
              || 'élément, particule rejetée) — '
              || 'verdict d''origine : « De Moraes Sarmento Pinheiro, Paulo Sérgio »'
 where lot = 'autorite_casse' and entity_id = 11043 and applique_le is null
   and valeur_retenue = 'De Moraes Sarmento Pinheiro, Paulo Sérgio';

-- =====================================================================
-- SECTION 2 — APPLICATION
--
-- Même mécanique qu'en 10 et 11 : forme d'affichage d'abord (sa garde
-- porte sur l'état actuel, qui disparaît à l'étape suivante), puis point
-- d'accès, puis marquage de la file.
--
-- Garde STRICTE (`= avant`, pas `upper(...)`). En migration 10 elle avait
-- été assouplie à la casse près, parce que la seule transformation subie
-- entre-temps ÉTAIT la casse. Ici l'écart résiduel est structurel : ne pas
-- desserrer une garde sans avoir mesuré pourquoi elle refuse.
-- =====================================================================

-- 1. Forme d'affichage (CONV-2), là où elle est encore mécaniquement dérivée.
--    Une cible sans virgule (collectivité) reçoit le point d'accès verbatim :
--    une personne morale ne se range pas « Nom, Prénom ».
update public.authors a
   set preferred_name = case
         when coalesce(nullif(btrim(q.valeur_retenue), ''), q.apres_propose) ~ ', '
          and (length(coalesce(nullif(btrim(q.valeur_retenue), ''), q.apres_propose))
               - length(replace(coalesce(nullif(btrim(q.valeur_retenue), ''), q.apres_propose), ',', ''))) = 1
         then btrim(split_part(coalesce(nullif(btrim(q.valeur_retenue), ''), q.apres_propose), ', ', 2)
                    || ' ' ||
                    split_part(coalesce(nullif(btrim(q.valeur_retenue), ''), q.apres_propose), ', ', 1))
         else coalesce(nullif(btrim(q.valeur_retenue), ''), q.apres_propose)
       end
  from public.catalog_review_queue q
 where q.entity_id = a.id
   and q.lot = 'autorite_casse'
   and q.decision in ('valide', 'corrige')
   and q.applique_le is null
   and coalesce(nullif(btrim(q.valeur_retenue), ''), q.apres_propose) is not null
   and a.sort_name = q.avant
   and a.preferred_name = btrim(split_part(a.sort_name, ', ', 2) || ' ' || split_part(a.sort_name, ', ', 1));

-- 2. Point d'accès (CONV-1).
update public.authors a
   set sort_name = coalesce(nullif(btrim(q.valeur_retenue), ''), q.apres_propose)
  from public.catalog_review_queue q
 where q.entity_id = a.id
   and q.lot = 'autorite_casse'
   and q.decision in ('valide', 'corrige')
   and q.applique_le is null
   and coalesce(nullif(btrim(q.valeur_retenue), ''), q.apres_propose) is not null
   and a.sort_name = q.avant;

-- 3. Marquage.
update public.catalog_review_queue q
   set applique_le = now()
  from public.authors a
 where a.id = q.entity_id
   and q.lot = 'autorite_casse'
   and q.decision in ('valide', 'corrige')
   and q.applique_le is null
   and a.sort_name = coalesce(nullif(btrim(q.valeur_retenue), ''), q.apres_propose);

-- =====================================================================
-- Vérification — SIGNALE, ne bloque pas. Jouable sur base vide (CI).
-- =====================================================================
do $$
declare
  n_lot      bigint;
  n_applique bigint;
  n_revoir   bigint;
  n_bloque   bigint;
  l_bloque   text;
begin
  select count(*) into n_lot from public.catalog_review_queue where lot = 'autorite_casse';
  if n_lot = 0 then
    raise notice 'CONV/12 — file vide (reconstruction CI) : rien à appliquer.';
    return;
  end if;

  select count(*) into n_applique from public.catalog_review_queue
   where lot = 'autorite_casse' and applique_le is not null;
  select count(*) into n_revoir from public.catalog_review_queue
   where lot = 'autorite_casse' and decision = 'a_revoir';

  select count(*), coalesce(string_agg(entity_id::text, ', ' order by entity_id), '')
    into n_bloque, l_bloque
    from public.catalog_review_queue
   where lot = 'autorite_casse'
     and decision in ('valide', 'corrige')
     and applique_le is null;

  if n_bloque > 0 then
    raise warning 'CONV/12 — % verdict(s) tranché(s) NON appliqué(s) : autorités %. '
                  'Le point d''accès en base ne correspond plus à l''instantané de la file : '
                  'la fiche a changé depuis (typiquement, un autre lot du chantier l''a déjà '
                  'corrigée). Un verdict posé sur un état périmé DÉFERAIT ce travail — la garde '
                  'refuse, à raison. À relire dans l''Atelier, où « Écarter » suffit. Cf. CONV-O6.',
                  n_bloque, l_bloque;
  end if;

  raise notice 'CONV/12 — % ligne(s) appliquée(s) sur % · % encore à revoir · % bloquée(s).',
               n_applique, n_lot, n_revoir, n_bloque;
end $$;

commit;
