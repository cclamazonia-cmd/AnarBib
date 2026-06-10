# Prompt de reprise — Audit sécurité fonctions privées AnarBib

**Chantier** : #150 — Audit sécurité fonctions privées (faille `ALTER DEFAULT PRIVILEGES` Supabase)
**Découvert** : 17 mai 2026, session paquet profils B.4
**Estimation** : 2h30 à 3h en session dédiée à froid
**Statut** : à programmer (recommandation : sprint hygiène Phase 0 du plan d'action 15/05)

---

## 1. Contexte de la découverte

### Le pré-requis : doctrine de création d'objets sécurisés

AnarBib applique depuis le 12/05/2026 une doctrine de création d'objets backend sécurisés, codifiée dans `docs/decisions/CHANTIER_doctrine_creation_objets_securises_2026-05-12.md`. Pour les fonctions PL/pgSQL, le pattern recommandé est :

```sql
CREATE OR REPLACE FUNCTION public.fn_xxx()
RETURNS ...
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $body$ ... $body$;

REVOKE EXECUTE ON FUNCTION public.fn_xxx() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_xxx() TO authenticated;  -- si callable depuis frontend
```

Cette doctrine est enforcée par un hook git `.githooks/pre-commit` qui bloque les commits SQL ne la respectant pas.

### La faille découverte le 17/05/2026

En session paquet B.4 (jobs pg_cron pour les transitions de profils), Xavier a créé deux fonctions cron destinées à n'être appelables **que par `postgres`** (donc le cron lui-même) :

```sql
CREATE OR REPLACE FUNCTION public.fn_expire_overdue_profile_proposals()
RETURNS int LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public AS $body$ ... $body$;

REVOKE EXECUTE ON FUNCTION public.fn_expire_overdue_profile_proposals() FROM PUBLIC;
-- Pas de GRANT a authenticated : ce job doit etre callable uniquement par pg_cron (postgres).
```

Le DO-block de vérification de fin de migration a échoué avec :

```
ERROR: B4_VERIF_FAIL : authenticated a EXECUTE sur fonctions cron (2 expose - fuite) (SQLSTATE P0001)
```

**Cause racine identifiée** : la DB Supabase a `ALTER DEFAULT PRIVILEGES` qui octroie automatiquement `EXECUTE` aux rôles `anon`, `authenticated`, `service_role` sur toute nouvelle fonction du schéma `public`. **`REVOKE FROM PUBLIC` seul ne suffit pas** parce que `PUBLIC` (le pseudo-rôle) ≠ `authenticated` (rôle explicite).

### Diagnostic confirmé en SQL

Xavier a passé la requête de diagnostic suivante en prod et obtenu confirmation :

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
    ELSE defaclobjtype::text
  END AS object_type,
  defaclacl AS default_acls
FROM pg_default_acl
WHERE defaclnamespace = 'public'::regnamespace;
```

Résultat (résumé) :
- `supabase_admin` octroie par défaut `EXECUTE` (X) à `postgres`, `anon`, `authenticated`, `service_role` sur **toutes nouvelles fonctions** du schéma `public`
- `postgres` octroie le même set (idempotent — accumulation historique)
- Ces ACLs s'appliquent à TOUTE nouvelle fonction créée dans `public`, indépendamment des `REVOKE` explicites

### Le fix appliqué à B.4

Migration corrective :

```sql
REVOKE EXECUTE ON FUNCTION public.fn_expire_overdue_profile_proposals() FROM PUBLIC, anon, authenticated, service_role;
REVOKE EXECUTE ON FUNCTION public.fn_execute_due_profile_proposals() FROM PUBLIC, anon, authenticated, service_role;
```

Le DO-block est ensuite passé OK. Les jobs sont en prod depuis le 17/05.

### Doctrine inscrite en mémoire Claude (#19)

> AnarBib doctrine création objets backend : lire docs/decisions/CHANTIER_doctrine_creation_objets_securises_2026-05-12.md. SECURITY DEFINER + search_path. Hook .githooks/pre-commit bloque violations. **PIEGE Supabase (17/05 B.4)** : ALTER DEFAULT PRIVILEGES grant EXECUTE TO anon/authenticated/service_role sur public.functions automatiquement. **REVOKE FROM PUBLIC seul NE SUFFIT PAS**. Fonction privée (cron/postgres only) : REVOKE FROM PUBLIC, anon, authenticated, service_role.

---

## 2. Périmètre de l'audit

### Question politique centrale

Toutes les fonctions du schéma `public` créées **avant le 17/05/2026** et qui n'ont qu'un `REVOKE FROM PUBLIC` (ou pas de REVOKE du tout) sont **potentiellement callable par `authenticated`** — donc par n'importe quel·le utilisateur·trice connecté·e à AnarBib.

**3 catégories à distinguer** :

1. **Fonctions destinées à être callable par authenticated** (RPC frontend) — pas de problème, c'est même voulu. Exemples : `api.create_consulta_local`, `fn_propose_library_profile_change`. **Ne rien changer.**

2. **Fonctions de calcul pur sans effet de bord** — exposition à authenticated = pas de gain pour un attaquant. Exemples : `fn_classify_transition`, `fn_required_governance_for_transition`. **Mineur, peut être laissé tel quel.**

3. **Fonctions privilégiées** (cron, triggers, helpers internes qui bypassent RLS via `SECURITY DEFINER`) — **vraies failles potentielles**. Une fonction `SECURITY DEFINER` callable par authenticated peut effectuer des actions au nom de `postgres` (donc bypass RLS), ce qui peut permettre des escalations.

C'est la **catégorie 3** qu'il faut auditer et corriger en priorité.

### Hors périmètre

- Les fonctions du schéma `api` (wrappers exposés à PostgREST) — par design callable par authenticated
- Les fonctions du schéma `auth` (gérées par Supabase)
- Les fonctions des schémas `cron`, `extensions`, etc.
- Les tables (les RLS gèrent l'accès, l'audit serait un autre chantier)
- Les vues (security_invoker est la doctrine, audit séparé)

---

## 3. Requête de diagnostic principale

À passer en premier dans la session d'audit :

```sql
-- Liste toutes les fonctions SECURITY DEFINER du schema public 
-- accessibles par authenticated (potentiellement vulnerables)
SELECT 
  p.proname,
  p.prosecdef AS is_security_definer,
  has_function_privilege('public', p.oid, 'EXECUTE') AS public_can_exec,
  has_function_privilege('authenticated', p.oid, 'EXECUTE') AS auth_can_exec,
  has_function_privilege('anon', p.oid, 'EXECUTE') AS anon_can_exec,
  has_function_privilege('service_role', p.oid, 'EXECUTE') AS sr_can_exec,
  obj_description(p.oid, 'pg_proc') AS function_comment,
  pg_get_function_arguments(p.oid) AS args,
  pg_get_function_result(p.oid) AS return_type
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public'
  AND p.prosecdef = true
  AND has_function_privilege('authenticated', p.oid, 'EXECUTE') = true
ORDER BY p.proname;
```

**Sortie attendue** : une ligne par fonction `SECURITY DEFINER` du schéma `public` callable par `authenticated`. Le volume est inconnu — estimation entre 50 et 200 lignes.

### Requête de diagnostic secondaire (filtrage)

Pour identifier rapidement les fonctions à risque réel parmi le résultat précédent :

```sql
-- Fonctions SECURITY DEFINER public callable par authenticated 
-- qui semblent NON destinees au frontend (heuristique : nom commence par fn_, pas par api_)
SELECT 
  p.proname,
  has_function_privilege('authenticated', p.oid, 'EXECUTE') AS auth_can_exec
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public'
  AND p.prosecdef = true
  AND has_function_privilege('authenticated', p.oid, 'EXECUTE') = true
  AND p.proname NOT LIKE 'fn\_propose\_%'   -- RPC propose ouverts a authenticated
  AND p.proname NOT LIKE 'fn\_vote\_%'      -- RPC vote ouverts a authenticated
  AND p.proname NOT LIKE 'fn\_cancel\_%'    -- RPC cancel ouverts a authenticated
  AND p.proname NOT LIKE 'fn\_execute\_%'   -- RPC execute ouverts a authenticated
  AND p.proname NOT LIKE 'fn\_request\_%'   -- divers RPC request
  AND p.proname NOT LIKE 'fn\_submit\_%'    -- divers RPC submit
ORDER BY p.proname;
```

C'est un point de départ ; les patterns de filtrage seront affinés à mesure du triage.

---

## 4. Plan d'exécution suggéré

### Phase 1 — Diagnostic (15-20 min)

1. Passer la requête de diagnostic principale → obtenir la liste exhaustive
2. Sauvegarder la liste dans un fichier temporaire : `docs/decisions/AUDIT_securite_fonctions_privees_2026-XX-XX.md`
3. Compter le volume et estimer le temps de triage

### Phase 2 — Triage manuel (1h à 1h30)

Pour **chaque fonction listée**, décider de la catégorie :
- **Cat 1 (frontend)** : laisser tel quel
- **Cat 2 (calcul pur)** : laisser tel quel (sauf décision politique de tightening)
- **Cat 3 (privilégiée)** : à REVOKE

Pour décider, lire :
- Le **commentaire** SQL de la fonction (`obj_description`)
- Si pas de commentaire utile, lire le **code** (récupérable via `pg_get_functiondef(p.oid)`)
- Si toujours doute, chercher les **callers** dans le frontend (`grep -r "fn_xxx" src/`)

**Heuristiques rapides** :
- Fonction appelée par un `pg_cron` job ou un trigger interne → **Cat 3**
- Fonction nommée `fn_*_internal`, `fn_block_*`, `fn_*_handler`, `fn_*_trigger` → **Cat 3** très probable
- Fonction qui modifie `libraries.*`, `network_administrators.*` sans paramètre d'identification → **Cat 3** très probable
- Fonction prefixée `fn_propose_/vote_/cancel_/execute_/request_/submit_` → **Cat 1** très probable (RPC ouverts)
- Fonction prefixée `fn_*_count`, `fn_classify_*`, `fn_required_*` → **Cat 2** probable

### Phase 3 — Migration corrective (30-45 min)

Rédiger UNE migration `YYYYMMDDHHMMSS_audit_securite_fonctions_privees.sql` :

```sql
BEGIN;

-- ============================================================================
-- Audit securite : REVOKE EXECUTE etendus sur fonctions Cat 3
-- ============================================================================
-- Doctrine de reference : docs/decisions/CHANTIER_doctrine_creation_objets_securises_2026-05-12.md
-- Decouverte 17/05/2026 (B.4) : ALTER DEFAULT PRIVILEGES Supabase grant
-- EXECUTE TO anon/authenticated/service_role sur public.functions automatiquement.
-- REVOKE FROM PUBLIC seul ne suffit pas.

-- Fonctions Cat 3 identifiees a l'audit du JJ/MM/2026 :

REVOKE EXECUTE ON FUNCTION public.fn_xxx_1() FROM PUBLIC, anon, authenticated, service_role;
REVOKE EXECUTE ON FUNCTION public.fn_xxx_2() FROM PUBLIC, anon, authenticated, service_role;
-- ... etc

-- DO-block de verification
DO $verif$
DECLARE
  v_count int;
BEGIN
  -- Test : authenticated n'a plus EXECUTE sur les fonctions REVOKEd
  SELECT count(*) INTO v_count
  FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid
  WHERE n.nspname = 'public'
    AND p.proname IN ('fn_xxx_1', 'fn_xxx_2', ...)
    AND has_function_privilege('authenticated', p.oid, 'EXECUTE') = true;
  IF v_count > 0 THEN
    RAISE EXCEPTION 'AUDIT_FAIL : % fonctions Cat 3 sont encore exposees a authenticated', v_count;
  END IF;
  RAISE NOTICE 'OK : isolation authenticated effective sur N fonctions';
  
  -- Test : verifier qu'aucune fonction Cat 1 (RPC frontend) n'a ete revokee par erreur
  SELECT count(*) INTO v_count
  FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid
  WHERE n.nspname = 'public'
    AND p.proname IN (
      'fn_propose_library_profile_change',
      'fn_vote_library_profile_change',
      'fn_cancel_library_profile_change',
      'fn_execute_library_profile_change'
      -- ... ajouter les RPC frontend critiques connues
    )
    AND has_function_privilege('authenticated', p.oid, 'EXECUTE') = false;
  IF v_count > 0 THEN
    RAISE EXCEPTION 'AUDIT_FAIL : % RPC frontend ne sont PLUS accessibles a authenticated (regression)', v_count;
  END IF;
  RAISE NOTICE 'OK : RPC frontend critiques toujours accessibles';
END
$verif$;

COMMIT;
```

### Phase 4 — Validation prod (30 min)

- Push de la migration
- Attendre Woodpecker vert
- Test fumée en prod :
  - Se connecter en compte staff
  - Tenter d'appeler une fonction Cat 3 depuis le frontend via la console : doit échouer avec `permission denied`
  - Tester que les workflows existants fonctionnent toujours (créer une consulta, voter une cooptation, etc.)
- Documenter dans `docs/decisions/AUDIT_securite_fonctions_privees_<date>.md` :
  - La liste exhaustive des fonctions auditées
  - Le triage Cat 1/2/3
  - Les fonctions REVOKEd
  - Les anomalies trouvées (s'il y en a)

### Phase 5 — Mise à jour de la doctrine (15 min)

Étendre `docs/decisions/CHANTIER_doctrine_creation_objets_securises_2026-05-12.md` (ou rédiger un v2) pour :
- Documenter le piège Supabase `ALTER DEFAULT PRIVILEGES`
- Mettre à jour les templates `_TEMPLATE.sql` avec la forme étendue de REVOKE
- Étendre le hook `.githooks/pre-commit` pour détecter les `REVOKE FROM PUBLIC` orphelins (sans `, anon, authenticated, service_role`) sur des fonctions sans `GRANT TO authenticated` explicite

---

## 5. Pièges à anticiper

### Faux positifs possibles

Certaines fonctions peuvent **apparaître** comme Cat 3 (privilégiées) mais sont en fait **appelées explicitement** par d'autres SECURITY DEFINER, donc le REVOKE n'aura pas d'impact réel. Exemple : `fn_library_active_staff_count` peut sembler interne mais on a vu qu'elle a `GRANT TO authenticated` explicite parce que le frontend l'utilise pour afficher un compteur.

**Méthode** : avant de REVOKE, faire un grep dans le frontend (`grep -r "fn_xxx" src/`) et dans les migrations SQL (`grep -r "fn_xxx" supabase/migrations/`) pour vérifier les call sites.

### Régressions silencieuses

Une fonction Cat 3 mal identifiée peut être appelée par un **trigger** qui ne soulève pas d'erreur visible (parce que le trigger tourne en `postgres` qui garde toujours `EXECUTE`). La régression peut ne se manifester que tard, en prod, dans un cas d'usage particulier.

**Méthode** : le DO-block de vérification doit inclure des tests sur les fonctions Cat 1 critiques pour ne pas REVOKE par erreur.

### Volume de la liste

Si la liste de fonctions à auditer fait plus de 100 lignes, **ne pas tout faire en une session**. Découper en sous-paquets :
- Sous-paquet 1 : fonctions du paquet A admin réseau (le plus ancien, le plus risqué)
- Sous-paquet 2 : fonctions du chantier consultations
- Sous-paquet 3 : fonctions du chantier linter (paquets L.1-L.11)
- Sous-paquet 4 : fonctions du chantier profils (A, B.1-B.4)
- etc.

Chaque sous-paquet = une migration distincte, push entre chaque.

### Sortie attendue de l'audit

À la fin :
- Une migration `YYYYMMDDHHMMSS_audit_securite_fonctions_privees.sql` (ou plusieurs si découpé) en prod
- Un document `docs/decisions/AUDIT_securite_fonctions_privees_<date>.md` qui liste tout
- Une mise à jour de `docs/decisions/CHANTIER_doctrine_creation_objets_securises_2026-05-12.md` (ou un v2)
- Un commit qui clôt l'item #150 du backlog

---

## 6. Décision politique à acter en début de session

**Question** : faut-il aussi REVOKE les fonctions Cat 2 (calcul pur) ?

Argument **pour** :
- Cohérence : si une fonction n'est pas explicitement marquée callable par authenticated, elle ne devrait pas l'être
- Défense en profondeur : on ne sait pas quels futurs usages pourraient exploiter ces fonctions
- Simplicité conceptuelle : 2 catégories au lieu de 3 (callable par authenticated explicitement OU privée)

Argument **contre** :
- Bruit : ajouter des dizaines de REVOKE sur des fonctions sans risque réel surcharge les migrations
- Risque de régression : certaines fonctions Cat 2 sont peut-être appelées par du frontend qu'on n'a pas vu
- Pragmatisme : auditer Cat 3 résout l'essentiel du problème politique

**Recommandation à débattre** : faire Cat 3 maintenant (audit ciblé), laisser Cat 2 en backlog pour un futur sprint hygiène.

---

## 7. Commande pour démarrer la session reprise

Quand tu seras prêt·e à attaquer cet audit, ouvre une nouvelle conversation Claude dans le projet AnarBib avec un message du type :

> Reprise du chantier #150 — audit sécurité fonctions privées. Prompt de reprise dans `docs/decisions/Prompt-Reprise-Chantier-150-audit-securite.md`. Découverte le 17/05 sur paquet B.4 que `ALTER DEFAULT PRIVILEGES` Supabase grant EXECUTE TO authenticated automatiquement sur toute fonction public. `REVOKE FROM PUBLIC` seul ne suffit pas. Commencer par passer la requête de diagnostic principale (Phase 1).

Claude lira ce prompt, comprendra le contexte, et démarrera fraîchement avec la requête de diagnostic.

---

## 8. Estimation finale

| Phase | Durée |
|---|---|
| 1. Diagnostic | 15-20 min |
| 2. Triage manuel | 1h - 1h30 |
| 3. Migration corrective | 30-45 min |
| 4. Validation prod | 30 min |
| 5. Mise à jour doctrine | 15 min |
| **Total** | **2h30 à 3h** |

Si la liste fait plus de 100 fonctions, prévoir une session supplémentaire de 1h pour le découpage en sous-paquets.

---

*Prompt de reprise rédigé le 17 mai 2026, fin de session B.4 paquet profils d'adoption. Item #150 du backlog AnarBib.*
