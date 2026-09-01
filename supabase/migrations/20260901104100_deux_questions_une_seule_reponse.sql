-- B14, schéma `public`, paquet 5 : « es-tu staff ? » et « où ? » sont deux
-- questions, et trente-sept fonctions les lisaient comme une seule.
--
-- ============================================================================
-- LE DÉFAUT
-- ============================================================================
-- Le paquet 5 examinait les 53 fonctions `SECURITY DEFINER` de `public` qui
-- **écrivent** et portent une garde apparente, en cherchant le décalage classique
-- entre l'objet gardé et l'objet écrit — celui de la faille exemplaires/holdings
-- de juillet. Les fonctions, une à une, sont saines : elles calculent leur garde
-- à partir de l'objet lu, jamais d'un paramètre.
--
-- Le décalage n'était pas dans les fonctions. Il était dans la vue qu'elles
-- interrogent toutes.
--
-- `api.my_access` rend deux colonnes que **trente-sept fonctions** — dont
-- **vingt-quatre qui écrivent** : toute la circulation, tout l'argent, tout
-- l'import — lisent ensemble comme si elles répondaient à la même question :
--
--   * `can_access_painel` valait `has_any_staff_membership OR is_network_admin`
--     — soit « as-tu un rôle staff **quelque part** ? » ;
--   * `library_id` valait celui de l'adhésion **effective**, choisie par
--     `ORDER BY is_primary DESC, created_at, library_slug LIMIT 1` — soit
--     « quelle est ta bibliothèque **principale** ? ».
--
-- Rien ne garantissait que ces deux-là parlent de la même bibliothèque. Une
-- personne bibliothécaire à la bibliothèque A et **simple lectrice** à la
-- bibliothèque B, avec B pour bibliothèque principale, obtenait
-- `can_access_painel = true` et `library_id = B` : le panneau de B, où elle n'a
-- aucun rôle. Or c'est exactement sur ce couple que reposent
-- `fn_record_membership_payment`, `fn_record_deposit`,
-- `fn_v2_create_emprestimo_by_holdings` et vingt et une autres écritures — elles
-- vérifient `v_actor.library_id` et n'ont aucun moyen de savoir que la réponse
-- vient d'ailleurs.
--
-- ============================================================================
-- CE QUI EST MESURÉ, ET CE QUI EST DORMANT
-- ============================================================================
-- Mesuré en production le 01/09/2026 : **une** personne cumule un rôle staff
-- dans une bibliothèque et une adhésion non-staff dans une autre. Aujourd'hui
-- elle est sauve par le tri — son adhésion staff (BLMF, mai) porte
-- `is_primary`, donc elle l'emporte. Ce qui l'armerait n'est pas une attaque :
-- c'est **désigner l'autre bibliothèque comme principale**, un geste ordinaire
-- offert par l'interface. Zéro personne exploitable, un clic pour le devenir.
--
-- La question utile n'est pas « est-ce exploitable aujourd'hui ? » mais « qu'est-ce
-- qui l'armerait ? » — c'est la leçon du lot `api`, et elle s'applique ici.
--
-- ============================================================================
-- LE CORRECTIF, ET POURQUOI IL NE PEUT RIEN CASSER
-- ============================================================================
-- On ne touche à aucune des trente-sept fonctions : on rend les deux colonnes
-- cohérentes à la source.
--
--   1. l'adhésion effective **préfère une adhésion staff** (`is_staff DESC` en
--      tête du tri, avant `is_primary`) ;
--   2. `can_access_painel` se calcule alors sur **cette** adhésion — plus sur
--      « n'importe laquelle ».
--
-- Les deux ensemble sont **équivalents à l'ancien calcul, pas plus restrictifs** :
-- si une personne a un rôle staff quelque part, (1) garantit que l'adhésion
-- effective est justement celle-là, donc (2) rend `true` exactement dans les
-- mêmes cas qu'avant. Personne ne perd un accès — non par chance mesurée, mais
-- par construction. Le seul changement est *quelle* bibliothèque est rendue
-- quand les deux divergeaient, et c'était le bug.
--
-- Mesure de confirmation avant écriture : sur les 14 personnes actives,
-- **zéro** voit sa bibliothèque effective changer. Le correctif est invisible
-- sur l'état actuel et ferme le chemin pour la suite.
--
-- Le cas de l'administration du réseau est laissé tel quel, délibérément : un·e
-- admin réseau garde `can_access_painel` même sans rôle local, parce que son
-- pouvoir est global par ailleurs (`fn_caller_is_network_admin` ouvre bien plus
-- que ça). Mesuré : 1 admin réseau actif, staff par ailleurs — le cas « admin
-- réseau seulement lecteur·rice » n'existe pas en base aujourd'hui.
--
-- ============================================================================
-- PIÈGE DE FORME
-- ============================================================================
-- `CREATE OR REPLACE VIEW` **réinitialise les options** de la vue : omettre
-- `WITH (security_invoker = true)` ferait retomber `api.my_access` en
-- `SECURITY DEFINER`, c'est-à-dire une vue qui contourne la RLS pour tout le
-- monde. Ce piège a déjà exposé l'annuaire pendant une heure le 31/08/2026.
-- L'option est reportée ci-dessous, et une garde de fin la vérifie.
--
-- `public.my_access` n'est pas touchée : elle liste ses colonnes explicitement
-- et la liste ne change pas.

CREATE OR REPLACE VIEW api.my_access
WITH (security_invoker = true) AS
WITH base AS (
  SELECT sc.user_id, sc.email, sc.first_name, sc.last_name, sc.full_name,
         sc.is_authenticated, sc.is_librarian, sc.default_library_id,
         sc.default_library_slug, sc.default_library_name, sc.can_access_conta
    FROM api.my_session_context sc
), active_memberships AS (
  SELECT m.user_id, l.id AS library_id, l.slug AS library_slug, l.name AS library_name,
         m.role, m.status, m.is_primary, m.created_at,
         -- Ce drapeau est le cœur du correctif : il fait entrer le RÔLE dans le
         -- choix de l'adhésion effective, alors que le tri ne connaissait que
         -- l'ancienneté et la préférence d'affichage.
         (m.role = ANY (ARRAY['librarian'::text, 'coordenador'::text])) AS is_staff
    FROM user_library_memberships m
    JOIN libraries l ON l.id = m.library_id
   WHERE m.status = 'active'::text AND l.is_active = true AND m.user_id = auth.uid()
), effective_membership AS (
  SELECT am.user_id, am.library_id, am.library_slug, am.library_name,
         am.role, am.status, am.is_primary, am.created_at, am.is_staff
    FROM active_memberships am
   -- `is_staff` passe DEVANT `is_primary` : la bibliothèque où l'on travaille
   -- l'emporte sur celle qu'on a désignée comme principale. Sans quoi
   -- `can_access_painel` et `library_id` peuvent désigner deux bibliothèques
   -- différentes, et les trente-sept fonctions qui lisent les deux ensemble
   -- ouvrent le panneau de la mauvaise.
   ORDER BY am.is_staff DESC, am.is_primary DESC, am.created_at, am.library_slug
   LIMIT 1
), network_admin_status AS (
  SELECT (EXISTS ( SELECT 1 FROM network_administrators
                    WHERE network_administrators.user_id = auth.uid()
                      AND network_administrators.status = 'active'::text)) AS is_network_admin
)
SELECT b.user_id AS id,
       b.email,
       b.is_librarian,
       COALESCE(p.is_restricted, false) AS is_restricted,
       b.default_library_id,
       b.default_library_slug,
       b.default_library_name,
       b.can_access_conta,
       -- Avant : `has_any_staff_membership OR is_network_admin` — vrai si un rôle
       -- staff existait N'IMPORTE OÙ, sans rapport avec le `library_id` rendu
       -- juste en dessous. Maintenant la même question porte sur l'adhésion
       -- effective, qui est celle dont `library_id` sort.
       (COALESCE(em.is_staff, false) OR na.is_network_admin)
         AND COALESCE(p.is_restricted, false) = false AS can_access_painel,
       (COALESCE(em.is_staff, false) OR na.is_network_admin)
         AND COALESCE(p.is_restricted, false) = false AS can_access_catalogacao,
       b.user_id,
       p.public_id,
       p.first_name,
       p.last_name,
       em.library_id,
       em.library_slug,
       em.library_name,
       em.role,
       em.status,
       em.is_primary
  FROM base b
  LEFT JOIN profiles p ON p.id = b.user_id
  LEFT JOIN effective_membership em ON em.user_id = b.user_id
  CROSS JOIN network_admin_status na;

COMMENT ON VIEW api.my_access IS
  'Contexte de session : qui je suis, et dans quelle bibliothèque j''agis. Depuis le 01/09/2026 (B14, paquet 5), can_access_painel et library_id désignent OBLIGATOIREMENT la même bibliothèque — l''adhésion effective préfère un rôle staff avant la préférence d''affichage. Avant, « staff quelque part » et « bibliothèque principale » pouvaient diverger, et les 37 fonctions qui lisent les deux ensemble (24 écrivent : circulation, cotisations, dépôts, import) ouvraient alors le panneau d''une bibliothèque où la personne n''a aucun rôle. Ne pas dissocier ces deux colonnes sans relire ces 37 fonctions.';

-- ============================================================================
-- GARDES DE FIN
-- ============================================================================
DO $$
DECLARE
  v_opts text[];
  v_cols int;
BEGIN
  -- 1) Le piège du 31/08 : une vue qui retombe en definer contourne la RLS.
  SELECT c.reloptions INTO v_opts
    FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
   WHERE n.nspname = 'api' AND c.relname = 'my_access';

  IF v_opts IS NULL OR NOT ('security_invoker=true' = ANY (v_opts)) THEN
    RAISE EXCEPTION 'api.my_access a perdu security_invoker — la vue contournerait la RLS — rollback';
  END IF;

  -- 2) La liste de colonnes ne bouge pas : `public.my_access` les nomme une à une
  --    et casserait en silence si l'ordre ou le nombre changeait.
  SELECT count(*) INTO v_cols
    FROM information_schema.columns
   WHERE table_schema = 'api' AND table_name = 'my_access';

  IF v_cols <> 20 THEN
    RAISE EXCEPTION 'api.my_access rend % colonnes au lieu de 20 — public.my_access ne suivrait plus — rollback', v_cols;
  END IF;

  -- 3) La vue en aval est toujours lisible (elle n'a pas été recréée, mais si la
  --    forme amont avait changé, la dépendance aurait sauté).
  PERFORM 1 FROM public.my_access WHERE false;
END $$;
