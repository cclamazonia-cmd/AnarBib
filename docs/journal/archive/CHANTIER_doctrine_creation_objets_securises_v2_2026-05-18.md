# Doctrine de création d'objets backend sécurisés — v2

**Statut** : extension du document du 12/05/2026  
**Date d'adoption** : 18 mai 2026  
**Origine** : leçons opérationnelles du chantier #150 (audit sécurité fonctions privées)  
**Document parent** : `CHANTIER_doctrine_creation_objets_securises_2026-05-12.md` (toujours en vigueur)

---

## 0. Pourquoi un v2

Le document du 12/05 pose les fondations : SECURITY DEFINER + `search_path` fixé + REVOKE EXECUTE FROM PUBLIC + GRANT explicites. Ces fondations restent valides.

**Le v2 ajoute quatre extensions** issues des découvertes de l'audit chantier #150 (18/05) :

1. Le piège `ALTER DEFAULT PRIVILEGES` Supabase et la forme étendue du REVOKE.
2. Le cas particulier des triggers non-DEFINER qui appellent une SECURITY DEFINER REVOKE-ed.
3. La méthode de vérification anti-régression obligatoire pour tout REVOKE.
4. Le triage à trois catégories pour distinguer fonctions privées, fonctions exposées et fonctions de calcul pur.

Le hook `.githooks/pre-commit` reste actif. Il a besoin d'un raffinement (item backlog #3 du chantier #150) pour éviter les faux positifs sur les commentaires d'en-tête mentionnant `SECURITY DEFINER`.

---

## 1. Extension : pattern REVOKE étendu obligatoire

### 1.1 Le piège Supabase

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

### 1.2 La forme étendue obligatoire

Pour toute fonction privée (cron, helper interne, fonction destinée à n'être appelée que par d'autres SECURITY DEFINER ou par des triggers SECURITY DEFINER), la migration de création **DOIT** inclure :

```sql
REVOKE EXECUTE ON FUNCTION public.fn_xxx(<signature>)
  FROM PUBLIC, anon, authenticated, service_role;
```

`postgres` conserve EXECUTE par défaut (jamais REVOKE) et les triggers / fonctions internes continuent de tourner via `SECURITY DEFINER`.

### 1.3 Pour les fonctions exposées au frontend

Le pattern doctrinal du v1 reste : `REVOKE FROM PUBLIC` + `GRANT TO authenticated` explicite. Le piège `ALTER DEFAULT PRIVILEGES` n'a alors pas d'effet visible parce que le `GRANT` est exactement ce que la default privilege ferait — mais le `GRANT` rend l'intention explicite et survit à un futur changement de default privilege côté Supabase.

### 1.4 Vérification de l'isolation effective

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

## 2. Extension : triggers non-DEFINER qui appellent des SECURITY DEFINER

### 2.1 Le problème

Quand un trigger non-SECURITY-DEFINER appelle une fonction SECURITY DEFINER, l'invocation se fait avec les droits de **l'utilisateur·rice qui a déclenché le trigger** (= typiquement `authenticated`). PostgreSQL vérifie alors `has_function_privilege(authenticated, ..., 'EXECUTE')` avant même que la fonction appelée ne change de contexte d'exécution.

Si la fonction appelée a été REVOKE-ed pour `authenticated`, le trigger plante avec `permission denied for function ...`.

### 2.2 La règle

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

Le `SET search_path` est nécessaire parce que `ALTER FUNCTION ... SECURITY DEFINER` ne pose pas le search_path automatiquement — la doctrine v1 exige le search_path fixé sur toute SECURITY DEFINER.

### 2.3 Cas réel rencontré

Chantier #150 SP2 : `tg_enqueue_task_level_notifications_from_task` était l'unique caller non-DEFINER de `enqueue_task_level_notifications_from_task`. La migration `20260518160000_chantier150_sp2_revoke_notifications_helpers.sql` le promeut SECURITY DEFINER avant de REVOKE la fonction cible.

---

## 3. Extension : vérification anti-régression obligatoire dans tout REVOKE

### 3.1 Le DO-block est obligatoire

Toute migration de REVOKE EXECUTE doit terminer par un `DO $verif$` qui :

1. **Confirme l'isolation effective** sur les rôles applicatifs (`public`, `anon`, `authenticated`, `service_role` = `false`).
2. **Confirme la non-régression** : les RPC frontend / Edge Function critiques connues comme étant des callers des fonctions REVOKE-ed restent accessibles à `authenticated`.
3. **Confirme les patchs préalables** : si un trigger non-DEFINER a été promu, vérifier que la promotion est effective (`prosecdef = true`).

Toute violation déclenche un `RAISE EXCEPTION` qui rollback la transaction et fait Woodpecker rouge.

### 3.2 Template du DO-block

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

---

## 4. Extension : méthode de triage des fonctions privées

### 4.1 Les trois catégories

Toute fonction SECURITY DEFINER du schéma `public` callable par `authenticated` se classe en une seule des trois catégories suivantes :

**Cat 1 — Frontend** : RPC légitimement callable par authenticated, **avec garde RBAC interne explicite** (`auth.uid()` + check de rôle via `fn_caller_is_network_admin`, `fn_current_user_can_*`, `user_can_manage_library`, `user_can_engage_library`, `can_manage_profile_from_my_libraries`, ou filtrage `user_id = auth.uid()`). À laisser tel quel.

**Cat 2 — Calcul pur** : fonctions sans effet de bord (lecteurs `STABLE` qui retournent une valeur calculée, sans écriture, sans accès à secrets vault, sans dispatch webhook). L'exposition à authenticated ne donne aucun pouvoir à un attaquant. Doctrine pragmatique : laisser tel quel. Doctrine défense-en-profondeur : REVOKE par sprint hygiène dédié.

**Cat 3 — Privilégiée** : helpers internes, jobs cron, fonctions appelées par triggers ou par d'autres SECURITY DEFINER, **sans garde RBAC propre**. Une exposition à authenticated permet à un attaquant d'invoquer la fonction au nom de `postgres` (bypass RLS, dispatch webhook avec secret vault, écriture audit log sans vérif). À REVOKE en priorité.

### 4.2 Méthode de classification

Pour une fonction donnée, dans l'ordre :

1. **Lire le code complet** via `pg_get_functiondef(p.oid)` — **pas un substring tronqué** qui pourrait couper avant un `WHERE` filtrant ou un check d'autorisation final.
2. Chercher la garde RBAC en début de fonction (`IF auth.uid() IS NULL THEN ... ; IF NOT user_can_... THEN ...`).
3. Si pas de garde explicite en début, chercher un filtre RBAC dans le `WHERE` final ou les CTE (cas des fonctions SQL `STABLE`).
4. Si pas de garde du tout :
    - Effet de bord (écriture, dispatch, log) → **Cat 3**
    - Calcul pur (lecteur, classifieur, predicat booléen) → **Cat 2**
5. Garde présente → **Cat 1**.

### 4.3 Recensement systématique des callers avant REVOKE

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

### 4.4 Pièges procéduraux observés

**Faux positif via substring tronqué** (chantier #150, SP4 annulé) : `pg_get_functiondef` retournant >1500 caractères peut tronquer avant un `WHERE` filtrant. **Toujours récupérer le code complet** pour les fonctions SQL avec CTE multiples ou logique conditionnelle en fin de corps.

**Hook pre-commit faux positif sur commentaires** (chantier #150, SP3) : le hook actuel détecte le pattern `SECURITY DEFINER` n'importe où dans le fichier, y compris dans les blocs de commentaires d'en-tête de migration. Une migration REVOKE pur qui mentionne "SECURITY DEFINER" dans la justification politique déclenche le hook. Bypass légitime : `git commit --no-verify`. Item backlog : raffiner le hook (ignorer lignes `--` et blocs `/* ... */`).

**Mojibake d'affichage `Get-Content`** (doctrine UTF-8 17/05) : `Get-Content` sur Windows FR lit en CP1252 par défaut et affiche `â€"` au lieu de `—` même si le fichier est UTF-8 valide. Toujours vérifier avec `[System.IO.File]::ReadAllText($path, [System.Text.UTF8Encoding]::new($false))` avant de croire à une corruption.

---

## 5. Récapitulatif opérationnel — checklist d'audit d'une fonction privée

1. ☐ Lire le code complet de la fonction via `pg_get_functiondef`.
2. ☐ Identifier la catégorie (Cat 1 / Cat 2 / Cat 3) avec la méthode §4.2.
3. ☐ Si Cat 3 : recensement SQL des callers (§4.3.1).
4. ☐ Vérifier que tous les callers SQL sont SECURITY DEFINER. Sinon : patch préalable dans la migration (§2.2).
5. ☐ Grep frontend (§4.3.2).
6. ☐ Grep Edge Functions (§4.3.3).
7. ☐ Si hit frontend / Edge Function en appel actif : décision politique (Cat 1 dégradé ou redesign).
8. ☐ Rédiger la migration REVOKE avec :
   - Forme étendue `FROM PUBLIC, anon, authenticated, service_role`.
   - Patch préalable SECURITY DEFINER si nécessaire (avec `SET search_path`).
   - DO-block de vérification (isolation + non-régression + confirmation patchs) (§3.2).
9. ☐ Push, attendre Woodpecker vert.
10. ☐ Test de fumée SQL post-prod : `has_function_privilege` sur les 5 rôles (4 applicatifs + postgres).
11. ☐ Test de fumée live : déclencher au moins un workflow réel qui utilise la fonction cible.

---

## 6. Référence — état du chantier #150

Le chantier #150 a appliqué cette méthode à ~160 fonctions SECURITY DEFINER du schéma public. Résultat : 28 fonctions Cat 3 isolées + 1 trigger patché en SECURITY DEFINER, en 3 sous-paquets (SP1 / SP2 / SP3). Détails dans `docs/decisions/AUDIT_securite_fonctions_privees_2026-05-18.md`.

---

*Doctrine v2 adoptée le 18 mai 2026 à la clôture du chantier #150. Étend mais ne remplace pas le document du 12/05/2026.*
