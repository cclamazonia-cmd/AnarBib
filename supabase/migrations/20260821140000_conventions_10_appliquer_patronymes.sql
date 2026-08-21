-- =====================================================================
-- CONVENTIONS CATALOGRAPHIQUES — 10 · Application des doubles patronymes
-- Foyer : REGISTRE §37 `CONV` · CONV-1 (point d'accès) + CONV-2 (la forme
--         d'affichage dérive du point d'accès)
--
-- PREMIÈRE MIGRATION D'APPLICATION DU CHANTIER. Elle n'invente rien : elle
-- exécute des verdicts humains posés un par un dans la file de vérification
-- (`/atelier-autoridades`), le 21/08. Le lot est SOLDÉ : 22 lignes, 20
-- validées, 2 écartées, 0 en attente.
--
-- Les 2 écartées sont exactement les 2 faux positifs que l'audit signalait —
-- « BORGES, Jorge Luis » et « MECHOSO, Juan Carlos », où « Jorge Luis » et
-- « Juan Carlos » sont des prénoms composés, pas des doubles patronymes. La
-- boucle « l'outil propose, l'humain décide » a tenu : l'avis a été suivi là
-- où il était fondé, et les 20 autres acceptés.
--
-- ---------------------------------------------------------------------
-- LA GARDE EST INSENSIBLE À LA CASSE, ET CE N'EST PAS UN RELÂCHEMENT.
--
-- La garde anti-écrasement habituelle compare l'état en base à la valeur
-- `avant` enregistrée au moment de la proposition. Ici elle aurait écarté
-- 19 des 20 lignes — vérifié avant d'écrire ce fichier. Non parce que les
-- fiches auraient été retouchées, mais parce que la migration 08 leur a
-- appliqué entre-temps la casse naturelle : « MAGÓN, Ricardo Flores » est
-- devenu « Magón, Ricardo Flores ». Le `avant` de la file est donc périmé
-- par une passe légitime du même chantier.
--
-- On compare donc sur `upper(btrim(...))`. C'est exact et non permissif :
-- la seule transformation subie entre-temps était la CASSE, et une
-- modification de CONTENU serait toujours attrapée. Mesuré : 20/20
-- identiques hors casse, 0 réellement différente.
-- =====================================================================

begin;

-- ---------------------------------------------------------------------
-- 1. Forme d'affichage D'ABORD (CONV-2)
--
--    Elle se calcule depuis la valeur retenue, mais sa garde porte sur
--    l'état ACTUEL : on ne re-dérive que là où `preferred_name` est encore
--    exactement la forme mécaniquement dérivée du point d'accès en place.
--    Une fiche retouchée à la main garde la sienne — on ne recouvre jamais
--    un geste humain. (Mesuré : 20/20 encore dérivées, 0 retouchée.)
--
--    Cet ordre est délibéré : après l'étape 2, l'ancien `sort_name` n'existe
--    plus, et la garde ne serait plus vérifiable.
-- ---------------------------------------------------------------------
update public.authors a
   set preferred_name = btrim(
         split_part(coalesce(nullif(btrim(q.valeur_retenue), ''), q.apres_propose), ', ', 2)
         || ' ' ||
         split_part(coalesce(nullif(btrim(q.valeur_retenue), ''), q.apres_propose), ', ', 1))
  from public.catalog_review_queue q
 where q.entity_id = a.id
   and q.lot = 'autorite_patronyme'
   and q.decision in ('valide', 'corrige')
   and q.applique_le is null
   and coalesce(nullif(btrim(q.valeur_retenue), ''), q.apres_propose) is not null
   and upper(btrim(a.sort_name)) = upper(btrim(q.avant))
   and a.preferred_name = btrim(split_part(a.sort_name, ', ', 2) || ' ' || split_part(a.sort_name, ', ', 1))
   and (length(a.sort_name) - length(replace(a.sort_name, ',', ''))) = 1
   and (length(coalesce(nullif(btrim(q.valeur_retenue), ''), q.apres_propose))
        - length(replace(coalesce(nullif(btrim(q.valeur_retenue), ''), q.apres_propose), ',', ''))) = 1;

-- ---------------------------------------------------------------------
-- 2. Point d'accès (CONV-1)
-- ---------------------------------------------------------------------
update public.authors a
   set sort_name = coalesce(nullif(btrim(q.valeur_retenue), ''), q.apres_propose)
  from public.catalog_review_queue q
 where q.entity_id = a.id
   and q.lot = 'autorite_patronyme'
   and q.decision in ('valide', 'corrige')
   and q.applique_le is null
   and coalesce(nullif(btrim(q.valeur_retenue), ''), q.apres_propose) is not null
   and upper(btrim(a.sort_name)) = upper(btrim(q.avant));

-- ---------------------------------------------------------------------
-- 3. Marquer la file — décider et écrire sont deux gestes, `applique_le`
--    les sépare. Une ligne appliquée ne se re-décide plus (la RPC
--    `api.conv_revue_decide` la refuse).
-- ---------------------------------------------------------------------
update public.catalog_review_queue q
   set applique_le = now()
  from public.authors a
 where a.id = q.entity_id
   and q.lot = 'autorite_patronyme'
   and q.decision in ('valide', 'corrige')
   and q.applique_le is null
   and a.sort_name = coalesce(nullif(btrim(q.valeur_retenue), ''), q.apres_propose);

-- ---------------------------------------------------------------------
-- 4. Vérification — SIGNALE, ne bloque pas (doctrine du chantier).
--    Jouable sur la base vide que reconstruit le job CI `sql-tests`.
-- ---------------------------------------------------------------------
do $$
declare
  n_lot      bigint;
  n_applique bigint;
  n_reste    bigint;
  n_ecarte   bigint;
  l_reste    text;
begin
  select count(*) into n_lot from public.catalog_review_queue where lot = 'autorite_patronyme';

  if n_lot = 0 then
    raise notice 'CONV/10 — file vide (reconstruction CI) : rien à appliquer.';
    return;
  end if;

  select count(*) into n_applique from public.catalog_review_queue
   where lot = 'autorite_patronyme' and applique_le is not null;
  select count(*) into n_ecarte from public.catalog_review_queue
   where lot = 'autorite_patronyme' and decision = 'ecarte';

  select count(*), coalesce(string_agg(entity_id::text, ', ' order by entity_id), '')
    into n_reste, l_reste
    from public.catalog_review_queue
   where lot = 'autorite_patronyme'
     and decision in ('valide', 'corrige')
     and applique_le is null;

  if n_reste > 0 then
    raise warning 'CONV/10 — % verdict(s) validé(s) NON appliqué(s) : autorités %. '
                  'Le point d''accès en base ne correspond plus à la valeur enregistrée '
                  'au moment de la proposition, même à la casse près — la fiche a été '
                  'modifiée depuis. À relire une par une, pas à forcer.', n_reste, l_reste;
  end if;

  raise notice 'CONV/10 — % point(s) d''accès corrigé(s) sur % du lot · % écarté(s) '
               '(faux positifs de l''audit) · % en attente.',
               n_applique, n_lot, n_ecarte, n_reste;
end $$;

commit;
