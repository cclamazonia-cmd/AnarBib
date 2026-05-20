# Doctrine de création d'objets PostgreSQL sécurisés

**Date initiale** : 2026-05-12
**Dernière mise à jour** : 2026-05-20 (fusion de la doctrine v2 du 18/05 issue du chantier #150)
**Statut** : Actif, à appliquer à toute nouvelle migration AnarBib
**Auteur** : Xavier, coordenador AnarBib
**Référence** : Issu du chantier linter L.* (sessions des 11-12 mai 2026), enrichi par les leçons L.12 du 19/05 et par l'audit sécurité du chantier #150 (18/05)

> **Note de fusion (20/05/2026)** : ce document consolide deux notes auparavant séparées :
> - la doctrine de base du 12/05 (templates 1-4, chantier linter L.*), mise à jour le 19/05 avec les leçons L.12
> - la doctrine « v2 » du 18/05 (extensions issues du chantier #150 audit sécurité des fonctions privées)
>
> La **Partie I** (templates 1-4) couvre la création d'objets sécurisés au quotidien. La **Partie II** (sections 5-8) couvre l'audit et l'isolation des fonctions privées déjà existantes. Les deux parties forment une doctrine unique. L'ancienne note `CHANTIER_doctrine_creation_objets_securises_v2_2026-05-18.md` est archivée — ce document la remplace intégralement.

---

# PARTIE I — Création d'objets sécurisés (templates 1-4)

## Pourquoi cette note

Le chantier linter L.* des 11-12 mai 2026 a éradiqué ~90 alertes de sécurité accumulées depuis le début du projet. Ces alertes étaient générées par les **defaults laxistes** de PostgreSQL et Supabase :

- Toute fonction `SECURITY DEFINER` créée sans précaution est exécutable par PUBLIC, anon et authenticated par défaut
- Toute fonction sans `search_path` explicite est vulnérable aux attaques par injection de schéma
- Toute table créée dans `public` sera, à partir du 30 octobre 2026, inaccessible via la Data API sans `GRANT` explicite
- Toute vue créée sans `security_invoker` exécute son SQL avec les droits du créateur (postgres), bypass des RLS
- Toute table dans `public.*` avec RLS désactivée est signalée **ERROR** par le linter Supabase (`rls_disabled_in_public`)

Pour éviter de regénérer cette dette technique à chaque nouveau paquet, cette note fournit les **templates obligatoires** à appliquer pour toute création d'objet PostgreSQL dans AnarBib.

L'application de ces templates ajoute ~30 secondes par fonction et ~1 minute par table. Le bénéfice : zéro alerte linter générée, zéro dette accumulée, et la prod reste alignée avec la doctrine de sécurité.

---

## Template 1 — Création de fonction SECURITY DEFINER

### Anatomie complète

```sql
-- Création de la fonction avec doctrine appliquée
CREATE OR REPLACE FUNCTION public.fn_nom_de_fonction(
  p_arg1 type1,
  p_arg2 type2
)
RETURNS type_retour
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $function$
DECLARE
  -- variables locales
BEGIN
  -- corps de la fonction
END;
$function$;

-- Verrouillage par défaut : retirer EXECUTE à PUBLIC (qui inclut anon et authenticated)
REVOKE EXECUTE ON FUNCTION public.fn_nom_de_fonction(type1, type2) FROM PUBLIC;

-- Accord explicite aux rôles légitimes (choisir UNE des options ci-dessous)
GRANT EXECUTE ON FUNCTION public.fn_nom_de_fonction(type1, type2) TO authenticated;
-- OU pour les parcours publics légitimes :
-- GRANT EXECUTE ON FUNCTION public.fn_nom_de_fonction(type1, type2) TO anon, authenticated;
-- OU pour les fonctions internes (triggers, cron, helpers privés) :
-- (ne rien grant — REVOKE FROM PUBLIC suffit, service_role conserve l'accès)
```

### Points doctrinaux à respecter

1. **`SET search_path = public, pg_catalog`** est obligatoire pour toute fonction SECURITY DEFINER. Sans cela, un·e attaquant·e peut injecter un schéma malveillant en tête du search_path et détourner les appels de fonctions internes. C'est l'alerte `function_search_path_mutable` du linter Supabase.

2. **`REVOKE EXECUTE FROM PUBLIC`** systématique. Sans ça, anon et authenticated peuvent exécuter la fonction par défaut, sans qu'on l'ait voulu.

3. **`GRANT EXECUTE TO <rôle>` explicite** pour le rôle légitime. La liste blanche anon doit rester courte (~7 fonctions actuellement : catalog, claim, submit, asset public, resolve_login_email). Si tu hésites à ajouter une fonction à la liste blanche anon, refuse par défaut.

4. **Exception critique : helpers utilisés dans RLS**. Si la fonction est appelée dans une policy RLS d'une table lisible par anon, **elle DOIT garder `GRANT EXECUTE TO anon`**, même si son corps retourne toujours false en contexte anon. Sans ce GRANT, l'évaluation de la policy plante avec un permission denied silencieux et PostgREST filtre toutes les lignes.

   Helpers concernés (à ne jamais REVOKE de anon) : `fn_caller_is_administrador`, `fn_caller_is_network_admin`, `fn_current_user_is_in_network`, `fn_current_user_is_member_of`, `fn_is_cross_library_action`, `fn_library_visible_to_caller`, `user_can_act_as_staff_on_library`, `user_can_engage_library`.

5. **Justifier le SECURITY DEFINER**. Si la fonction n'a pas besoin de bypass RLS, préférer `SECURITY INVOKER` (par défaut, plus simple, pas d'alerte linter). SECURITY DEFINER s'utilise pour :
   - les agrégats statistiques qui doivent réconcilier transparence et confidentialité (cf. `library_circulation_stats`)
   - les opérations d'écriture cross-RLS (cf. les RPC de gouvernance réseau)
   - les helpers RLS qui doivent voir l'ensemble du contexte utilisateur·rice

6. **Cas particulier : fonctions SECURITY INVOKER aussi concernées** (leçon L.12, 19/05/2026). Le linter `function_search_path_mutable` signale toute fonction (DEFINER ou INVOKER) sans `search_path` fixé. Même pour les triggers SECURITY INVOKER, c'est une bonne pratique de toujours fixer `search_path = public, pg_catalog`.

---

## Template 2 — Création de table avec RLS et grants futur-proof

### Anatomie complète

```sql
-- Création de la table
CREATE TABLE public.ma_nouvelle_table (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  library_id uuid REFERENCES public.libraries(id) ON DELETE CASCADE,
  -- colonnes métier
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- Indexes utiles
CREATE INDEX ma_nouvelle_table_user_id_idx ON public.ma_nouvelle_table(user_id);
CREATE INDEX ma_nouvelle_table_library_id_idx ON public.ma_nouvelle_table(library_id);

-- GRANT explicites futur-proof (cf. Supabase 30/10/2026)
-- Choisir UN des trois scénarios ci-dessous

-- Scénario A : Catalogue public (lisible par anon)
GRANT SELECT ON public.ma_nouvelle_table TO anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.ma_nouvelle_table TO authenticated;

-- Scénario B : Table métier privée (authenticated uniquement)
GRANT SELECT, INSERT, UPDATE, DELETE ON public.ma_nouvelle_table TO authenticated;

-- Scénario C : Table hors Data API (manipulée uniquement par RPC SECURITY DEFINER)
REVOKE ALL ON public.ma_nouvelle_table FROM anon, authenticated;
-- ET garder ENABLE RLS + policy lock-down explicite pour satisfaire le linter :
-- (voir Scénario C détaillé plus bas dans la section ENABLE RLS)

-- service_role conserve TOUJOURS l'accès complet (Edge Functions)
GRANT ALL ON public.ma_nouvelle_table TO service_role;

-- RLS obligatoire
ALTER TABLE public.ma_nouvelle_table ENABLE ROW LEVEL SECURITY;

-- Policies (au moins une, sinon RLS bloque tout côté API)
CREATE POLICY "ma_nouvelle_table_select_owner"
  ON public.ma_nouvelle_table
  FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY "ma_nouvelle_table_select_staff"
  ON public.ma_nouvelle_table
  FOR SELECT
  TO authenticated
  USING (user_can_act_as_staff_on_library(library_id));

CREATE POLICY "ma_nouvelle_table_insert_owner"
  ON public.ma_nouvelle_table
  FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

-- Si Scénario C (table fermée, lock-down explicite) :
-- CREATE POLICY "ma_nouvelle_table_lockdown"
--   ON public.ma_nouvelle_table
--   FOR ALL
--   TO anon, authenticated
--   USING (false) WITH CHECK (false);

-- Trigger d'audit updated_at (si applicable)
CREATE TRIGGER ma_nouvelle_table_set_updated_at
  BEFORE UPDATE ON public.ma_nouvelle_table
  FOR EACH ROW EXECUTE FUNCTION public.fn_set_updated_at();
```

### Points doctrinaux à respecter

1. **GRANT explicites OBLIGATOIRES** depuis le 30 octobre 2026 (pour les projets existants comme AnarBib). Sans GRANT, la table sera inaccessible via supabase-js avec une erreur 42501.

2. **ALWAYS ENABLE ROW LEVEL SECURITY**. Une table sans RLS qui a des GRANT pour authenticated devient un trou de sécurité béant : n'importe qui·te connecté·e peut lire toutes les lignes via PostgREST. **Et le linter Supabase signale `rls_disabled_in_public` comme ERROR critique** (cf. leçon L.12 du 19/05/2026).

3. **Au moins une policy par opération autorisée**. Si tu accordes INSERT mais pas de policy INSERT, l'opération sera bloquée par RLS. Audit possible :
   ```sql
   SELECT polname, polcmd, polroles::regrole[]::text 
   FROM pg_policy 
   WHERE polrelid = 'public.ma_nouvelle_table'::regclass;
   ```

4. **service_role conserve TOUJOURS l'accès**. Les Edge Functions utilisent cette clé pour bypass les RLS quand nécessaire (notifications, jobs cron, etc.).

5. **Documenter dans COMMENT ON TABLE** la sémantique de la table, surtout si elle a des particularités politiques (transparence, confidentialité, etc.).

---

## Template 3 — Création de vue

### Anatomie complète

```sql
CREATE OR REPLACE VIEW public.v_ma_vue
WITH (security_invoker = true)
AS
  SELECT t.col1, t.col2, ...
  FROM public.ma_table t
  WHERE ...;

-- GRANT explicites
GRANT SELECT ON public.v_ma_vue TO authenticated;
-- Optionnel pour vues publiques :
-- GRANT SELECT ON public.v_ma_vue TO anon;

-- COMMENT documentaire (recommandé)
COMMENT ON VIEW public.v_ma_vue IS
  'Description courte de la vue. Mode security_invoker depuis sa création '
  '(paquet X.Y du JJ/MM/AAAA). Sources : public.ma_table.';
```

### Points doctrinaux à respecter

1. **`security_invoker = true` par défaut**. Le linter signale toute vue en SECURITY DEFINER comme ERROR. C'est rarement justifié, à l'exception du pattern « agrégats statistiques transparents » documenté dans `CHANTIER_linter_security_definer_assume_2026-05-12.md`.

2. **Si vous devez créer une vue SECURITY DEFINER** (par exemple pour réconcilier transparence agrégée et confidentialité individuelle ligne à ligne) :
   - Documenter le choix politique dans le COMMENT ON VIEW
   - Créer une note décisionnelle dans `docs/decisions/` qui explique pourquoi
   - Accepter sciemment l'ERROR linter persistante
   - Mentionner les conditions de remise en question (cf. note `CHANTIER_linter_security_definer_assume`)

3. **Pour les vues `security_invoker=true`** : le caller doit avoir SELECT sur les tables sources via RLS. Si la vue retourne 0 ligne en pratique alors qu'elle devrait en retourner, c'est probablement que les RLS sources bloquent.

---

## Template 4 — Bloc de vérification automatique en fin de migration

À ajouter en fin de toute migration touchant à des permissions, des policies ou la résolution de noms (search_path, déplacement d'extension) :

```sql
BEGIN;

-- ... contenu de la migration ...

-- Vérification automatique
DO $$
DECLARE
  v_count int;
BEGIN
  -- Test en contexte anon PostgREST-like
  SET LOCAL ROLE anon;
  SET LOCAL "request.jwt.claims" = '{}';

  SELECT count(*) INTO v_count FROM public.ma_table_critique;

  IF v_count < 1 THEN
    RAISE EXCEPTION 'Vérification échouée : ma_table_critique invisible en anon (% lignes). Rollback automatique.', v_count;
  END IF;

  RESET ROLE;

  -- Optionnel : test en contexte authenticated simulé
  SET LOCAL ROLE authenticated;
  SET LOCAL "request.jwt.claims" = '{"sub":"00000000-0000-0000-0000-000000000000","role":"authenticated"}';

  -- ... tests authentifiés ...

  RESET ROLE;

  RAISE NOTICE 'Vérifications OK : % lignes visibles', v_count;
END $$;

COMMIT;
```

### Points doctrinaux à respecter

1. **`SET LOCAL ROLE` + `SET LOCAL "request.jwt.claims"`** ensemble. SET LOCAL ROLE seul est insuffisant car il ne reproduit pas le contexte JWT que PostgREST passe à la base. Les tests qui semblent valider une RLS en SQL Editor avec seulement SET ROLE peuvent planter en prod via PostgREST.

2. **RAISE EXCEPTION = rollback automatique de la transaction**. Si le test échoue, la migration n'est pas appliquée et Woodpecker remonte l'erreur.

3. **RESET ROLE après les tests** pour ne pas affecter les opérations suivantes dans la migration.

4. **Tester les parcours critiques en contexte simulé**, pas juste les permissions au niveau métadata. Exemple : confirmer que le catalogue anon retourne au moins 1 livre, pas juste que la fonction a SELECT.

5. **DO-block tolérant pour tables fermées (leçon L.12bis du 19/05/2026)**. Quand le test vérifie qu'une table n'est PAS lisible par anon/authenticated, il doit accepter DEUX mécanismes de blocage légitimes :
   - **GRANT bloque** → exception `SQLSTATE 42501` (`insufficient_privilege`)
   - **RLS bloque** → SELECT retourne 0 ligne

   Pattern obligatoire :

   ```sql
   BEGIN
     EXECUTE format('SELECT count(*) FROM public.%I', v_table) INTO v_count;
     IF v_count = 0 THEN
       v_blocked := true;  -- RLS bloque
     END IF;
   EXCEPTION
     WHEN insufficient_privilege THEN
       v_blocked := true;  -- GRANT bloque (42501)
   END;
   ```

   Sans le bloc EXCEPTION, le DO-block plante sur les tables sans GRANT (cas L.12bis du 19/05/2026, où le test a planté avant même d'évaluer la RLS sur 3 tables archivées sans GRANT anon/authenticated).

---

## Checklist pratique à coller en tête de chaque migration

```sql
-- =========================================================================
-- Paquet [NOM_PAQUET] — [DESCRIPTION COURTE]
-- =========================================================================
-- Date : YYYY-MM-DD
-- Chantier : [nom du chantier global, par exemple "admin réseau", "consultations"]
-- Auteur : [nom du contributeur·rice]
--
-- CHECKLIST DOCTRINE :
--   [ ] Si création de fonction SECURITY DEFINER :
--       [ ] SET search_path = public, pg_catalog
--       [ ] REVOKE EXECUTE ... FROM PUBLIC
--       [ ] GRANT EXECUTE ... TO <rôle ciblé>
--       [ ] Exception helpers RLS anon-lisibles : GRANT TO anon conservé
--   [ ] Si création de fonction SECURITY INVOKER (trigger, fonction métier) :
--       [ ] SET search_path = public, pg_catalog (hygiène linter)
--   [ ] Si création de table dans public :
--       [ ] GRANT SELECT/INSERT/UPDATE/DELETE explicites
--       [ ] ALTER TABLE ... ENABLE ROW LEVEL SECURITY (TOUJOURS, même fermées)
--       [ ] Au moins une CREATE POLICY par opération autorisée
--       [ ] Si table fermée : policy lock-down USING (false) WITH CHECK (false)
--       [ ] GRANT ALL TO service_role
--   [ ] Si création de vue :
--       [ ] WITH (security_invoker = true)
--       [ ] Exception SECURITY DEFINER : justification dans COMMENT + note dans docs/decisions
--   [ ] Si touche permissions/policies/search_path/extensions :
--       [ ] DO block de vérification automatique en fin de transaction
--       [ ] Tests parcours critiques en contexte anon ET authenticated simulés
--       [ ] Pour tables fermées : EXCEPTION WHEN insufficient_privilege
-- =========================================================================
```

---

## Cas particuliers documentés

### `api.library_circulation_stats` : SECURITY DEFINER assumé

Cette vue reste en SECURITY DEFINER par choix politique pour réconcilier transparence agrégée du réseau et confidentialité individuelle ligne à ligne. Voir note dédiée : `CHANTIER_linter_security_definer_assume_2026-05-12.md`.

### Helpers RLS anon-lisibles : GRANT EXECUTE TO anon conservé

Les helpers utilisés dans des RLS de tables anon-lisibles doivent conserver leur GRANT à anon. Sans ce GRANT, l'évaluation de la policy plante avec permission denied et PostgREST filtre silencieusement toutes les lignes. Liste actuelle :

- `fn_caller_is_administrador`
- `fn_caller_is_network_admin`
- `fn_current_user_is_in_network`
- `fn_current_user_is_member_of`
- `fn_is_cross_library_action`
- `fn_library_visible_to_caller`
- `user_can_act_as_staff_on_library`
- `user_can_engage_library`

### Liste blanche anon des RPC SECURITY DEFINER

Sept fonctions sont sciemment exécutables par anon parce qu'elles servent à des parcours publics légitimes :

- `api.search_catalog_v1(text)` — recherche catalogue
- `public.fn_consume_library_request_claim(text, uuid)` — réclamation par token
- `public.fn_get_library_request_claim_context(text)` — contexte avant réclamation
- `public.fn_submit_library_request(...)` — soumission d'inscription sans auth préalable
- `public.fn_submit_library_request_via_claim(...)` — soumission via réclamation
- `public.get_book_primary_public_digital_asset_v2(bigint)` — accès public aux PDFs domaine public
- `public.resolve_login_email(text)` — résolution email avant login

Toute nouvelle entrée dans cette liste doit être documentée et justifiée explicitement dans la migration qui la crée.

### Extensions PostgreSQL

Installer dans le schéma `extensions`, pas dans `public` :

```sql
CREATE EXTENSION IF NOT EXISTS my_extension WITH SCHEMA extensions;
```

Les fonctions métier qui utilisent ces extensions doivent inclure `extensions` dans leur search_path :

```sql
ALTER FUNCTION my.func(...) SET search_path = public, extensions, pg_temp;
```

### Tables archivées ou inertes dans `public.*` (leçon L.12 / L.12bis / L.12ter, 19/05/2026)

Pour une table conservée dans `public.*` mais qui n'est **plus accédée via PostgREST** (snapshot historique, archive gelée, table de migration ponctuelle), **ne JAMAIS désactiver la RLS** via `ALTER TABLE ... DISABLE ROW LEVEL SECURITY`. Le linter Supabase signale toute table publique sans RLS comme **ERROR** `rls_disabled_in_public`, considérant qu'elle pourrait être lue si un GRANT était accordé un jour par mégarde.

Le bon pattern est :

```sql
-- 1. Conserver la RLS activée
ALTER TABLE public._archived_ma_table ENABLE ROW LEVEL SECURITY;

-- 2. Ajouter une policy lock-down qui bloque tout
CREATE POLICY "ma_table_lockdown"
  ON public._archived_ma_table
  FOR ALL
  TO anon, authenticated
  USING (false)
  WITH CHECK (false);

-- 3. Documenter
COMMENT ON TABLE public._archived_ma_table IS
  'Archive gelée du JJ/MM/AAAA — table inerte. '
  'RLS activée + policy lock-down. Accessible uniquement via service_role.';
```

**Pourquoi pas simplement `DISABLE RLS` ?** Parce que Supabase classe `rls_disabled_in_public` comme ERROR (criticité supérieure à `rls_enabled_no_policy` qui n'est qu'INFO). Pour une table publique-mais-inerte, la RLS activée + policy `USING (false)` est strictement équivalente sécurité-wise mais sans alerte critique au linter.

**`service_role` reste autorisé** parce qu'il a `BYPASSRLS` au niveau Postgres, indépendamment des policies. Donc une Edge Function ou un accès SQL Editor avec service_role peut toujours lire l'archive pour audit ponctuel.

**Alternatives à considérer avant d'arriver à ce pattern** :

1. **Déplacer la table hors de `public`** vers un schéma `archive` non exposé à l'API REST. Mieux mais demande un refactor et de retirer le schéma de `db_extra_search_path` Supabase.
2. **DROP TABLE** si l'archive n'a vraiment plus aucune valeur historique. À privilégier quand le coût de conservation excède la valeur des données.
3. **`REVOKE ALL` sur la table** sans policy : marche techniquement mais le linter Supabase ne le voit pas et continuera à signaler `rls_enabled_no_policy`.

Le pattern `ENABLE RLS + USING (false)` est le compromis pragmatique entre exigence du linter, simplicité d'écriture et zéro risque d'accès accidentel.

---

---

# PARTIE II — Audit et isolation des fonctions privées existantes (chantier #150)

> Cette partie consolide la doctrine « v2 » du 18/05/2026, issue des leçons opérationnelles du chantier #150 (audit sécurité des fonctions privées). Là où la Partie I traite de la **création** d'objets sécurisés, la Partie II traite de l'**audit et l'isolation** de fonctions privées déjà en base.

## 5. Le piège `ALTER DEFAULT PRIVILEGES` et le pattern REVOKE étendu

### 5.1 Le piège Supabase

Sur la DB Supabase d'AnarBib (`uflwmikiyjfnikiphtcp`), un `ALTER DEFAULT PRIVILEGES` posé par `supabase_admin` puis répliqué par `postgres` octroie automatiquement `EXECUTE` aux rôles `anon`, `authenticated` et `service_role` sur **toute nouvelle fonction du schéma `public`** — indépendamment de tout REVOKE explicite que la migration de création poserait.

Conséquence : `REVOKE EXECUTE ... FROM PUBLIC` **ne suffit pas** à isoler une fonction privée. Le pseudo-rôle `PUBLIC` est distinct des rôles `anon` / `authenticated` / `service_role`. Seul un REVOKE nominatif sur les quatre les couvre tous.

Diagnostic en SQL :

```sql
SELECT 
  defaclrole::regrole AS granted_by,
  defaclnamespace::regnamespace AS schema,
  CASE defaclobjtype 
    WHEN 'r' THEN 'table/view'
    WHEN 'S' THEN 'sequence'
    WHEN 'f' THEN 'function'
    WHEN 'T' THEN 'type'
    WHEN 'n' THEN 'schema'
  END AS object_type,
  defaclacl AS default_acls
FROM pg_default_acl
WHERE defaclnamespace = 'public'::regnamespace;
```

### 5.2 La forme étendue obligatoire

Pour toute fonction privée (cron, helper interne, fonction destinée à n'être appelée que par d'autres SECURITY DEFINER ou par des triggers SECURITY DEFINER), la migration de création **DOIT** inclure :

```sql
REVOKE EXECUTE ON FUNCTION public.fn_xxx(<signature>)
  FROM PUBLIC, anon, authenticated, service_role;
```

`postgres` conserve EXECUTE par défaut (jamais REVOKE) et les triggers / fonctions internes continuent de tourner via `SECURITY DEFINER`.

**Articulation avec la Partie I** : le Template 1 (§ Partie I) indiquait `REVOKE EXECUTE FROM PUBLIC`. Cette forme reste correcte pour les fonctions exposées au frontend (où elle est suivie d'un `GRANT TO authenticated` explicite). Mais pour les **fonctions privées**, la forme étendue `FROM PUBLIC, anon, authenticated, service_role` est désormais **obligatoire**. Le Template 1 doit être lu à la lumière de cette précision.

### 5.3 Pour les fonctions exposées au frontend

Le pattern doctrinal de la Partie I reste : `REVOKE FROM PUBLIC` + `GRANT TO authenticated` explicite. Le piège `ALTER DEFAULT PRIVILEGES` n'a alors pas d'effet visible parce que le `GRANT` est exactement ce que la default privilege ferait — mais le `GRANT` rend l'intention explicite et survit à un futur changement de default privilege côté Supabase.

### 5.4 Vérification de l'isolation effective

Après tout REVOKE, vérifier en SQL :

```sql
SELECT 
  has_function_privilege('public', 'public.fn_xxx(...)'::regprocedure, 'EXECUTE'),
  has_function_privilege('anon', 'public.fn_xxx(...)'::regprocedure, 'EXECUTE'),
  has_function_privilege('authenticated', 'public.fn_xxx(...)'::regprocedure, 'EXECUTE'),
  has_function_privilege('service_role', 'public.fn_xxx(...)'::regprocedure, 'EXECUTE'),
  has_function_privilege('postgres', 'public.fn_xxx(...)'::regprocedure, 'EXECUTE');
```

Les quatre premiers doivent être `false`, le dernier `true`.

---

## 6. Triggers non-DEFINER qui appellent des SECURITY DEFINER

### 6.1 Le problème

Quand un trigger non-SECURITY-DEFINER appelle une fonction SECURITY DEFINER, l'invocation se fait avec les droits de **l'utilisateur·rice qui a déclenché le trigger** (= typiquement `authenticated`). PostgreSQL vérifie alors `has_function_privilege(authenticated, ..., 'EXECUTE')` avant même que la fonction appelée ne change de contexte d'exécution.

Si la fonction appelée a été REVOKE-ed pour `authenticated`, le trigger plante avec `permission denied for function ...`.

### 6.2 La règle

**Avant tout REVOKE** d'une fonction SECURITY DEFINER, vérifier que **tous ses callers SQL sont SECURITY DEFINER**.

Requête de vérification :

```sql
SELECT 
  af.proname AS caller_name,
  af.prosecdef AS caller_is_security_definer
FROM pg_proc target
JOIN pg_namespace tn ON tn.oid = target.pronamespace
JOIN pg_proc af ON pg_get_functiondef(af.oid) ILIKE '%' || target.proname || '%'
                AND af.proname <> target.proname
WHERE tn.nspname = 'public' AND target.proname = 'fn_target_to_revoke';
```

Si un caller est non-DEFINER, la migration de REVOKE doit le patcher en amont :

```sql
ALTER FUNCTION public.tg_non_definer_caller() SECURITY DEFINER;
ALTER FUNCTION public.tg_non_definer_caller() SET search_path TO 'public', 'pg_temp';
```

Le `SET search_path` est nécessaire parce que `ALTER FUNCTION ... SECURITY DEFINER` ne pose pas le search_path automatiquement — la doctrine Partie I exige le search_path fixé sur toute SECURITY DEFINER.

### 6.3 Cas réel rencontré

Chantier #150 SP2 : `tg_enqueue_task_level_notifications_from_task` était l'unique caller non-DEFINER de `enqueue_task_level_notifications_from_task`. La migration `20260518160000_chantier150_sp2_revoke_notifications_helpers.sql` le promeut SECURITY DEFINER avant de REVOKE la fonction cible.

---

## 7. Vérification anti-régression obligatoire dans tout REVOKE

### 7.1 Le DO-block est obligatoire

Toute migration de REVOKE EXECUTE doit terminer par un `DO $verif$` qui :

1. **Confirme l'isolation effective** sur les rôles applicatifs (`public`, `anon`, `authenticated`, `service_role` = `false`).
2. **Confirme la non-régression** : les RPC frontend / Edge Function critiques connues comme étant des callers des fonctions REVOKE-ed restent accessibles à `authenticated`.
3. **Confirme les patchs préalables** : si un trigger non-DEFINER a été promu, vérifier que la promotion est effective (`prosecdef = true`).

Toute violation déclenche un `RAISE EXCEPTION` qui rollback la transaction et fait Woodpecker rouge.

### 7.2 Template du DO-block

```sql
DO $verif$
DECLARE
  v_remaining_exposure int;
  v_target_functions text[] := ARRAY['fn_xxx_1', 'fn_xxx_2', ...];
  v_critical_rpc_frontend text[] := ARRAY['fn_caller_1', 'fn_caller_2', ...];
  v_rpc_regression_count int;
BEGIN
  -- Isolation effective
  SELECT count(*) INTO v_remaining_exposure
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public'
    AND p.proname = ANY(v_target_functions)
    AND (has_function_privilege('public', p.oid, 'EXECUTE')
      OR has_function_privilege('anon', p.oid, 'EXECUTE')
      OR has_function_privilege('authenticated', p.oid, 'EXECUTE')
      OR has_function_privilege('service_role', p.oid, 'EXECUTE'));
  IF v_remaining_exposure > 0 THEN
    RAISE EXCEPTION 'VERIF_FAIL_1 : % fonctions Cat 3 encore exposees', v_remaining_exposure;
  END IF;

  -- Non-régression
  SELECT count(*) INTO v_rpc_regression_count
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public'
    AND p.proname = ANY(v_critical_rpc_frontend)
    AND NOT has_function_privilege('authenticated', p.oid, 'EXECUTE');
  IF v_rpc_regression_count > 0 THEN
    RAISE EXCEPTION 'VERIF_FAIL_2 : % RPC frontend regression', v_rpc_regression_count;
  END IF;

  RAISE NOTICE 'OK : isolation effective sur N fonctions';
END
$verif$;
```

**Articulation avec la Partie I** : le Template 4 (§ Partie I) décrit le DO-block de vérification pour les migrations de création touchant aux permissions. Le DO-block ci-dessus est sa **spécialisation pour les migrations de REVOKE** : il vérifie en plus la non-régression des RPC frontend. Les deux patterns coexistent.

---

## 8. Méthode de triage des fonctions privées

### 8.1 Les trois catégories

Toute fonction SECURITY DEFINER du schéma `public` callable par `authenticated` se classe en une seule des trois catégories suivantes :

**Cat 1 — Frontend** : RPC légitimement callable par authenticated, **avec garde RBAC interne explicite** (`auth.uid()` + check de rôle via `fn_caller_is_network_admin`, `fn_current_user_can_*`, `user_can_manage_library`, `user_can_engage_library`, `can_manage_profile_from_my_libraries`, ou filtrage `user_id = auth.uid()`). À laisser tel quel.

**Cat 2 — Calcul pur** : fonctions sans effet de bord (lecteurs `STABLE` qui retournent une valeur calculée, sans écriture, sans accès à secrets vault, sans dispatch webhook). L'exposition à authenticated ne donne aucun pouvoir à un attaquant. Doctrine pragmatique : laisser tel quel. Doctrine défense-en-profondeur : REVOKE par sprint hygiène dédié (cf. item backlog #81).

**Cat 3 — Privilégiée** : helpers internes, jobs cron, fonctions appelées par triggers ou par d'autres SECURITY DEFINER, **sans garde RBAC propre**. Une exposition à authenticated permet à un attaquant d'invoquer la fonction au nom de `postgres` (bypass RLS, dispatch webhook avec secret vault, écriture audit log sans vérif). À REVOKE en priorité.

### 8.2 Méthode de classification

Pour une fonction donnée, dans l'ordre :

1. **Lire le code complet** via `pg_get_functiondef(p.oid)` — **pas un substring tronqué** qui pourrait couper avant un `WHERE` filtrant ou un check d'autorisation final.
2. Chercher la garde RBAC en début de fonction (`IF auth.uid() IS NULL THEN ... ; IF NOT user_can_... THEN ...`).
3. Si pas de garde explicite en début, chercher un filtre RBAC dans le `WHERE` final ou les CTE (cas des fonctions SQL `STABLE`).
4. Si pas de garde du tout :
    - Effet de bord (écriture, dispatch, log) → **Cat 3**
    - Calcul pur (lecteur, classifieur, predicat booléen) → **Cat 2**
5. Garde présente → **Cat 1**.

### 8.3 Recensement systématique des callers avant REVOKE

Avant tout REVOKE Cat 3, **trois recensements croisés** :

1. **Callers SQL** dans `pg_proc` :

```sql
WITH targets(target_name) AS (VALUES ('fn_to_revoke'), ...)
SELECT t.target_name, af.schema_name || '.' || af.proname AS caller, af.prosecdef
FROM targets t
JOIN (SELECT p.oid, p.proname, n.nspname AS schema_name, p.prosecdef,
             pg_get_functiondef(p.oid) AS body
      FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
      WHERE n.nspname IN ('public', 'api', 'ingest')) af
  ON af.body ILIKE '%' || t.target_name || '%' AND af.proname <> t.target_name
ORDER BY t.target_name, af.proname;
```

2. **Grep frontend** :

```powershell
cd "C:\Users\accat\Claude's AnarBib\anarbib-app"
$patterns = @('fn_to_revoke', ...)
foreach ($p in $patterns) {
  $hits = Get-ChildItem -Path src -Recurse -Include *.jsx,*.js,*.ts,*.tsx -ErrorAction SilentlyContinue |
          Select-String -Pattern $p -SimpleMatch
  if ($hits) { Write-Host "=== $p ===" -ForegroundColor Yellow; $hits | Select-Object Path, LineNumber, Line }
}
```

3. **Grep Edge Functions** : idem sur `supabase\functions`.

**Interprétation** :

- Aucun hit (SQL et front) → Cat 3 confirmée, REVOKE pur.
- Hit SQL uniquement, tous SECURITY DEFINER → Cat 3 confirmée, REVOKE pur.
- Hit SQL avec au moins un caller non-DEFINER → Cat 3, REVOKE + patch SECURITY DEFINER du caller dans la même migration.
- Hit frontend ou Edge Function en commentaire (`// via fn_xxx`) → Cat 3 confirmée, REVOKE pur.
- Hit frontend ou Edge Function en appel actif → **Cat 1 dégradé** (laisser callable) ou re-design de la fonction pour ajouter une garde RBAC interne. Décision politique au cas par cas.

### 8.4 Pièges procéduraux observés

**Faux positif via substring tronqué** (chantier #150, SP4 annulé) : `pg_get_functiondef` retournant >1500 caractères peut tronquer avant un `WHERE` filtrant. **Toujours récupérer le code complet** pour les fonctions SQL avec CTE multiples ou logique conditionnelle en fin de corps.

**Hook pre-commit faux positif sur commentaires** (chantier #150, SP3) : le hook actuel détecte le pattern `SECURITY DEFINER` n'importe où dans le fichier, y compris dans les blocs de commentaires d'en-tête de migration. Une migration REVOKE pur qui mentionne "SECURITY DEFINER" dans la justification politique déclenche le hook. Bypass légitime : `git commit --no-verify`. Item backlog #80 : raffiner le hook (ignorer lignes `--` et blocs `/* ... */`).

**Mojibake d'affichage `Get-Content`** (doctrine UTF-8 17/05) : `Get-Content` sur Windows FR lit en CP1252 par défaut et affiche `â€"` au lieu de `—` même si le fichier est UTF-8 valide. Toujours vérifier avec `[System.IO.File]::ReadAllText($path, [System.Text.UTF8Encoding]::new($false))` avant de croire à une corruption.

### 8.5 Récapitulatif opérationnel — checklist d'audit d'une fonction privée

1. ☐ Lire le code complet de la fonction via `pg_get_functiondef`.
2. ☐ Identifier la catégorie (Cat 1 / Cat 2 / Cat 3) avec la méthode §8.2.
3. ☐ Si Cat 3 : recensement SQL des callers (§8.3.1).
4. ☐ Vérifier que tous les callers SQL sont SECURITY DEFINER. Sinon : patch préalable dans la migration (§6.2).
5. ☐ Grep frontend (§8.3.2).
6. ☐ Grep Edge Functions (§8.3.3).
7. ☐ Si hit frontend / Edge Function en appel actif : décision politique (Cat 1 dégradé ou redesign).
8. ☐ Rédiger la migration REVOKE avec :
   - Forme étendue `FROM PUBLIC, anon, authenticated, service_role`.
   - Patch préalable SECURITY DEFINER si nécessaire (avec `SET search_path`).
   - DO-block de vérification (isolation + non-régression + confirmation patchs) (§7.2).
9. ☐ Push, attendre Woodpecker vert.
10. ☐ Test de fumée SQL post-prod : `has_function_privilege` sur les 5 rôles (4 applicatifs + postgres).
11. ☐ Test de fumée live : déclencher au moins un workflow réel qui utilise la fonction cible.

### 8.6 Référence — état du chantier #150

Le chantier #150 a appliqué cette méthode à ~160 fonctions SECURITY DEFINER du schéma public. Résultat : 28 fonctions Cat 3 isolées + 1 trigger patché en SECURITY DEFINER, en 3 sous-paquets (SP1 / SP2 / SP3). Détails dans `docs/decisions/AUDIT_securite_fonctions_privees_2026-05-18.md`.

---

## Évolution de cette doctrine

Cette doctrine a deux origines : le chantier linter L.* des 11-12 mai 2026 (Partie I, complétée le 19/05 par les leçons L.12 / L.12bis / L.12ter) et le chantier #150 d'audit sécurité du 18/05 (Partie II). Les deux ont été fusionnées en un document unique le 20/05/2026. Elle a vocation à continuer d'évoluer :

- Si Supabase modifie ses defaults (notamment `ALTER DEFAULT PRIVILEGES`), ajuster les templates et le pattern REVOKE étendu en conséquence
- Si la doctrine politique d'AnarBib évolue, ajuster les exceptions documentées
- Si de nouveaux patterns d'usage émergent (cron, webhooks externes, etc.), enrichir les templates
- Si l'audit Cat 2 (item backlog #81) est mené, intégrer ses conclusions dans la Partie II §8

Pour proposer une évolution : créer une note `CHANTIER_doctrine_evolution_AAAA-MM-JJ.md` dans `docs/decisions/` qui explique la proposition, et mettre ce document de référence à jour si validé.

---

## Historique des leçons intégrées

| Date | Leçon | Référence |
|---|---|---|
| 2026-05-12 | Doctrine initiale issue du chantier linter L.1 à L.11 (Partie I, templates 1-4) | Paquets L.1-L.11 |
| 2026-05-18 | Piège `ALTER DEFAULT PRIVILEGES` : REVOKE étendu `FROM PUBLIC, anon, authenticated, service_role` obligatoire (Partie II §5) | Chantier #150 SP1-SP3 |
| 2026-05-18 | Triggers non-DEFINER appelant des SECURITY DEFINER REVOKE-ed : patch préalable obligatoire (Partie II §6) | Chantier #150 SP2 |
| 2026-05-18 | DO-block anti-régression obligatoire dans toute migration REVOKE (Partie II §7) | Chantier #150 SP1-SP3 |
| 2026-05-18 | Triage Cat 1 / Cat 2 / Cat 3 des fonctions privées (Partie II §8) | Chantier #150 audit |
| 2026-05-19 | Tables archivées : `ENABLE RLS + policy USING (false)`, jamais `DISABLE RLS` | Paquet L.12 (régression) → L.12ter (correction) |
| 2026-05-19 | DO-block tolérant : `EXCEPTION WHEN insufficient_privilege` quand on teste l'inaccessibilité | Hotfix L.12bis (échec Woodpecker) → L.12ter |
| 2026-05-19 | Fonctions SECURITY INVOKER aussi concernées par `function_search_path_mutable` | Paquet L.12 sur `fn_block_lph_modification` |
| 2026-05-20 | Fusion de la doctrine v2 (chantier #150) dans ce document unique — Partie I création / Partie II audit | Marathon réécriture corpus du 20/05 |

---

## Références

- Chantier linter L.* (sessions 11-12 mai 2026) : 9 paquets, ~270 → ~184 alertes
- Document de synthèse du chantier : `AnarBib_Recap_Chantier_Linter_2026-05-12.docx`
- Note de décision SECURITY DEFINER assumé : `CHANTIER_linter_security_definer_assume_2026-05-12.md`
- Audit sécurité chantier #150 : `docs/decisions/AUDIT_securite_fonctions_privees_2026-05-18.md`
- Paquet L.12 (cleanup zero risk) : `supabase/migrations/20260519300000_paquetL12_cleanup_zero_risk.sql`
- Paquet L.12ter (hotfix RLS archives) : `supabase/migrations/20260519320000_paquetL12ter_hotfix_rls_archives_tolerant.sql`
- Migration chantier #150 SP2 (exemple de patch trigger non-DEFINER) : `supabase/migrations/20260518160000_chantier150_sp2_revoke_notifications_helpers.sql`
- Documentation Supabase Data API defaults 30/10/2026 : mail du 12/05/2026
- Documentation Supabase database linter : <https://supabase.com/docs/guides/database/database-linter>
- Documentation Supabase rls_disabled_in_public : <https://supabase.com/docs/guides/database/database-linter?lint=0006_rls_disabled_in_public>
- Documentation PostgreSQL SECURITY DEFINER : <https://www.postgresql.org/docs/current/sql-createfunction.html#SQL-CREATEFUNCTION-SECURITY>

---

*Doctrine fusionnée le 20/05/2026. Partie I issue du chantier linter L.* (11-12/05), Partie II issue du chantier #150 audit sécurité (18/05). Ce document remplace les notes séparées `..._2026-05-12.md` (originale) et `..._v2_2026-05-18.md` (archivée). Pour proposer une évolution : créer une note `CHANTIER_doctrine_evolution_AAAA-MM-JJ.md` dans `docs/decisions/`.*
