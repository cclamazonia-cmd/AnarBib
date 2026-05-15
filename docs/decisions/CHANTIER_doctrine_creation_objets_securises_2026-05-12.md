# Doctrine de création d'objets PostgreSQL sécurisés

**Date** : 2026-05-12
**Statut** : Actif, à appliquer à toute nouvelle migration AnarBib
**Auteur** : Xavier, coordenador AnarBib
**Référence** : Issu du chantier linter L.* (sessions des 11-12 mai 2026)

---

## Pourquoi cette note

Le chantier linter L.* des 11-12 mai 2026 a éradiqué ~90 alertes de sécurité accumulées depuis le début du projet. Ces alertes étaient générées par les **defaults laxistes** de PostgreSQL et Supabase :

- Toute fonction `SECURITY DEFINER` créée sans précaution est exécutable par PUBLIC, anon et authenticated par défaut
- Toute fonction sans `search_path` explicite est vulnérable aux attaques par injection de schéma
- Toute table créée dans `public` sera, à partir du 30 octobre 2026, inaccessible via la Data API sans `GRANT` explicite
- Toute vue créée sans `security_invoker` exécute son SQL avec les droits du créateur (postgres), bypass des RLS

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

-- service_role conserve TOUJOURS l'accès complet (Edge Functions)
GRANT ALL ON public.ma_nouvelle_table TO service_role;

-- RLS obligatoire
ALTER TABLE public.ma_nouvelle_table ENABLE ROW LEVEL SECURITY;

-- Policies (au moins une, sinon RLS bloque tout)
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

-- etc. selon les besoins métier

-- Trigger d'audit updated_at (si applicable)
CREATE TRIGGER ma_nouvelle_table_set_updated_at
  BEFORE UPDATE ON public.ma_nouvelle_table
  FOR EACH ROW EXECUTE FUNCTION public.fn_set_updated_at();
```

### Points doctrinaux à respecter

1. **GRANT explicites OBLIGATOIRES** depuis le 30 octobre 2026 (pour les projets existants comme AnarBib). Sans GRANT, la table sera inaccessible via supabase-js avec une erreur 42501.

2. **ALWAYS ENABLE ROW LEVEL SECURITY**. Une table sans RLS qui a des GRANT pour authenticated devient un trou de sécurité béant : n'importe qui·te connecté·e peut lire toutes les lignes via PostgREST.

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
--   [ ] Si création de table dans public :
--       [ ] GRANT SELECT/INSERT/UPDATE/DELETE explicites
--       [ ] ALTER TABLE ... ENABLE ROW LEVEL SECURITY
--       [ ] Au moins une CREATE POLICY par opération autorisée
--       [ ] GRANT ALL TO service_role
--   [ ] Si création de vue :
--       [ ] WITH (security_invoker = true)
--       [ ] Exception SECURITY DEFINER : justification dans COMMENT + note dans docs/decisions
--   [ ] Si touche permissions/policies/search_path/extensions :
--       [ ] DO block de vérification automatique en fin de transaction
--       [ ] Tests parcours critiques en contexte anon ET authenticated simulés
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

---

## Évolution de cette doctrine

Cette doctrine est issue du chantier linter L.* des 11-12 mai 2026. Elle a vocation à évoluer :

- Si Supabase modifie ses defaults, ajuster les templates en conséquence
- Si la doctrine politique d'AnarBib évolue, ajuster les exceptions documentées
- Si de nouveaux patterns d'usage émergent (cron, webhooks externes, etc.), enrichir les templates

Pour proposer une évolution : créer une note `CHANTIER_doctrine_evolution_AAAA-MM-JJ.md` dans `docs/decisions/` qui explique la proposition, et mettre cette note de référence à jour si validée.

---

## Références

- Chantier linter L.* (sessions 11-12 mai 2026) : 9 paquets, ~270 → ~184 alertes
- Document de synthèse du chantier : `AnarBib_Recap_Chantier_Linter_2026-05-12.docx`
- Note de décision SECURITY DEFINER assumé : `CHANTIER_linter_security_definer_assume_2026-05-12.md`
- Documentation Supabase Data API defaults 30/10/2026 : mail du 12/05/2026
- Documentation Supabase database linter : <https://supabase.com/docs/guides/database/database-linter>
- Documentation PostgreSQL SECURITY DEFINER : <https://www.postgresql.org/docs/current/sql-createfunction.html#SQL-CREATEFUNCTION-SECURITY>
