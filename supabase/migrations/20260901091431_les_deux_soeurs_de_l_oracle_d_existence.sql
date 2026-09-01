-- B14, schéma `public`, paquet 2 : les quatorze sœurs de l'oracle d'existence.
--
-- ============================================================================
-- LE DÉFAUT
-- ============================================================================
-- Le paquet 1 a fermé `fn_painel_find_profile_by_lookup`, qui distinguait
-- « compte trouvé, mais pas dans votre bibliothèque » de « rien trouvé » — un
-- test d'existence d'adresse e-mail. Le correctif était juste et **isolé** :
-- une fonction corrigée sans qu'on cherche ses sœurs.
--
-- Cherchées par le MOTIF plutôt que par le nom (le second chemin qu'exige
-- `DOC-RECENS-1`), il y en avait deux autres — puis **douze de plus** quand la
-- suite de test écrite dans la foulée a cherché le message SANS ses accents
-- (« nao pertence » et non « não pertence ») :
--
--   * `fn_painel_get_profile_by_id(uuid)` — la jumelle exacte, par identifiant.
--   * `fn_attach_received_asset_record(bigint, …)` — sur un **bigint
--     séquentiel** : en incrémentant, on compte les fonds reçus dans le réseau.
--   * les douze `fn_import_*` — « Run % introuvable » contre « Run % nao
--     pertence a esta biblioteca », sur des identifiants séquentiels eux aussi :
--     l'activité de catalogage des autres bibliothèques.
--
-- Chercher un texte dans une base multilingue doit couvrir les variantes
-- d'accentuation. Le « second chemin » était lui-même incomplet.
--
-- Aucun DROIT ne change : ces fonctions refusaient déjà les mêmes personnes.
-- On unifie ce qu'elles **disent** en refusant — doctrine de
-- `api.resolve_reader_card` : la banalité du motif est le contrôle.
--
-- ============================================================================
-- LA FORME DE CETTE MIGRATION, ET POURQUOI ELLE A CHANGÉ
-- ============================================================================
-- Les deux premières versions de ce fichier RECOPIAIENT le corps des deux
-- grosses fonctions pour n'y changer que trois mots. Les deux ont échoué au
-- déploiement, la seconde après un correctif qui n'était qu'une deuxième
-- supposition :
--
--   1. le `DEFAULT 'both'` du dernier paramètre de
--      `fn_attach_received_asset_record` avait été omis — PostgreSQL refuse un
--      `CREATE OR REPLACE` qui retire un défaut ;
--   2. son `search_path` avait perdu le schéma `auth` — ce qui aurait cassé
--      `auth.uid()` si le remplacement était passé.
--
-- La leçon n'est pas « mieux recopier » : c'est **ne pas recopier**. On part
-- désormais de `pg_get_functiondef` — la définition réelle, avec sa signature,
-- ses défauts, sa volatilité et son `search_path` — et on n'y remplace que les
-- chaînes visées. Le corps n'est jamais retapé, donc jamais altéré par
-- inadvertance. C'est le patron du wrap RLS `20260703203953`, avec le contrôle
-- que le paquet 3 du lot `api` y avait ajouté : **la substitution est vérifiée**,
-- et la migration échoue si le motif a disparu plutôt que de se croire appliquée.
--
-- Chaque substitution ci-dessous a été essayée à blanc en production avant
-- écriture.

DO $$
DECLARE
  r record;
  v_def text;
  v_new text;
  n int := 0;
BEGIN
  FOR r IN
    SELECT p.oid, p.proname
      FROM pg_proc p JOIN pg_namespace ns ON ns.oid = p.pronamespace
     WHERE ns.nspname = 'public'
       AND p.prosecdef
       AND (
         p.proname IN ('fn_painel_get_profile_by_id', 'fn_attach_received_asset_record')
         OR (p.proname LIKE 'fn\_import\_%' AND p.prosrc ~* '(nao|não) pertence a esta biblioteca')
       )
  LOOP
    v_def := pg_get_functiondef(r.oid);
    v_new := v_def;

    -- (a) La famille `fn_import_*` : le message d'appartenance devient le
    --     message d'absence, qui porte déjà le même paramètre (« Run % … »).
    v_new := regexp_replace(v_new, '(nao|não) pertence a esta biblioteca', 'introuvable', 'g');

    -- (b) La jumelle du panneau : deux refus, un seul message.
    v_new := regexp_replace(v_new,
      'Este cadastro não pertence à biblioteca ativa deste painel\.',
      'Cadastro não encontrado.', 'g');

    -- (c) La ressource reçue. Ici le message d'absence porte l'identifiant et
    --     l'autre non : on retire l'identifiant du premier plutôt que de
    --     l'ajouter au second — un identifiant renvoyé dans un refus est déjà
    --     une confirmation qu'on l'a lu.
    v_new := regexp_replace(v_new,
      '''Recurso recebido % introuvável\.'', p_received_asset_id',
      '''Recurso recebido introuvável.''', 'g');
    v_new := regexp_replace(v_new,
      'Recurso recebido não pertence a uma biblioteca que você coordena\.',
      'Recurso recebido introuvável.', 'g');

    IF v_new = v_def THEN
      RAISE EXCEPTION 'public.% : aucun motif substitué — la fonction a changé de forme, migration interrompue plutôt que sans effet', r.proname;
    END IF;

    EXECUTE v_new;
    n := n + 1;
  END LOOP;

  -- On ne fige PAS le compte : un nombre exact écrit dans une migration devient
  -- faux dès qu'une fonction est ajoutée ou renommée ailleurs, et fait échouer
  -- un déploiement pour une raison qui n'est pas un défaut. L'invariant qui
  -- compte est vérifié par la garde de fin.
  RAISE NOTICE 'messages de refus unifiés sur % fonction(s)', n;
END $$;

COMMENT ON FUNCTION public.fn_painel_get_profile_by_id(uuid) IS
  'Profil par identifiant, pour le panneau. Rend UN SEUL message d''échec, que le compte existe hors de vos bibliothèques ou qu''il n''existe pas — unifié le 01/09/2026 (B14), avec sa sœur fn_painel_find_profile_by_lookup et douze fn_import_*. Même doctrine que api.resolve_reader_card : la banalité du motif est le contrôle.';

COMMENT ON FUNCTION public.fn_attach_received_asset_record(bigint, bigint, text, text, text) IS
  'Attache un fichier reçu d''un partenaire à une notice. Rend le MÊME message que la ressource n''existe pas ou qu''elle appartienne à une bibliothèque que vous ne coordonnez pas, et sans rappeler l''identifiant — unifié le 01/09/2026 (B14) : cet identifiant est un bigint séquentiel, deux messages distincts donnaient la volumétrie des fonds reçus dans le réseau.';

-- ============================================================================
-- GARDES DE FIN
-- ============================================================================
DO $$
DECLARE v_reste text;
BEGIN
  -- L'invariant réel : plus aucune fonction exposée ne dit que la chose existe
  -- ailleurs. Les deux orthographes du message sont couvertes.
  SELECT string_agg(n.nspname||'.'||p.proname, ', ')
    INTO v_reste
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname IN ('public','api')
     AND p.prosecdef
     AND has_function_privilege('authenticated', p.oid, 'EXECUTE')
     AND p.prosrc ~* 'não pertence|nao pertence|pertence à biblioteca|pertence a biblioteca';

  IF v_reste IS NOT NULL THEN
    RAISE EXCEPTION 'motif « existe mais pas chez vous » subsistant sur : % — rollback', v_reste;
  END IF;

  -- Le refus vit dans le corps, jamais dans le droit : les fonctions restent
  -- appelables, sinon l'écran casserait au lieu de refuser proprement.
  IF NOT has_function_privilege('authenticated', 'public.fn_painel_get_profile_by_id(uuid)', 'EXECUTE')
     OR NOT has_function_privilege('authenticated', 'public.fn_attach_received_asset_record(bigint, bigint, text, text, text)', 'EXECUTE') THEN
    RAISE EXCEPTION 'EXECUTE perdu — rollback';
  END IF;
END $$;
