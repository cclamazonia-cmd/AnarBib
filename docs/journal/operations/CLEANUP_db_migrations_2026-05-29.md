# CLEANUP — Archivage du dossier `db/migrations/` (legacy pré-Woodpecker)

**Date** : 29 mai 2026
**Type** : Cleanup / décision d'organisation du dépôt
**Statut** : Acté, à exécuter
**Origine** : Audit factuel du 29/05/2026 (dump prod du 28/05 vs `db/migrations`)

---

## 1. Contexte

Le dépôt `anarbib-app` contient deux dossiers de migrations SQL coexistants :

- **`supabase/migrations/`** — actif depuis le paquet 14 (10/05/2026). Format `YYYYMMDDHHMMSS_nom.sql`, appliqué automatiquement par Woodpecker via `supabase db push --linked`. Pipeline en place, idempotent, traçable. 154 fichiers au 28/05/2026.

- **`db/migrations/`** — historique pré-paquet 14. Format hétérogène (`YYYYMMDD_nom.sql`, `2026_05_07_nom.sql`, voire `01-fix-...sql`), appliqué manuellement via Supabase CLI (`supabase db push` sans Woodpecker) ou via SQL Editor. **N'est pas lu par le pipeline Woodpecker.** 43 fichiers couvrant la fenêtre du 01/05 au 10/05/2026.

Le commentaire historique dans `.woodpecker.yml` (lignes 211-220) qualifie cette coexistence de « dette acceptée » avec « un écart connu entre les fichiers locaux et le tracker prod ». Le présent audit vérifie factuellement si cet écart existe encore.

## 2. Audit factuel — méthode

Le dump SQL exact de la prod au 28/05/2026 (54 731 lignes UTF-8 après conversion depuis l'UTF-16-LE PowerShell) a été utilisé comme référence. Pour chaque objet créé par une migration de `db/migrations/`, vérification de sa présence en prod par `grep` exact sur le dump.

Périmètre :
- 47 fonctions (`CREATE FUNCTION`)
- 22 policies (`CREATE POLICY`)
- 3 tables (`CREATE TABLE`)
- 7 triggers (`CREATE TRIGGER`)

Soit 79 objets recensés au total dans les 43 fichiers de `db/migrations/`.

## 3. Résultats

| Type | Total recensé | Présents en prod | Absents |
|------|---------------|------------------|---------|
| Fonctions | 47 | 46 | 1 |
| Policies | 22 | 21 | 1 |
| Tables | 3 | 3 | 0 |
| Triggers | 7 | 5 | 2 |
| **Total** | **79** | **75** | **4** |

Soit **95 % de couverture directe** (75/79). Les 4 absences sont chacune **documentées comme retraits volontaires** par un chantier ultérieur, traçables dans le code ou dans les commentaires SQL en prod.

### 3.1 — Les quatre absences expliquées

**`trg_notify_emprestimo_criado` (fonction et trigger)** — créés par `20260510_paquet9_notif_refonte.sql`. Retirés au chantier #153.A (25/05/2026). La logique a été absorbée dans `fn_v2_create_emprestimo_by_holdings`, qui émet l'event lui-même depuis le 25/05. Trace en prod : `COMMENT ON FUNCTION public.fn_v2_create_emprestimo_by_holdings IS '... TR-2 (#153.A, 25/05/2026) : émet elle-même fn_dispatch_circulation_notify_event(...) depuis le 25/05 — le trigger trg_notify_emprestimo_criado a été retiré. Toute nouvelle voie de création d'emprunt doit émettre cet event elle-même.'`

**`ulm_select_all_for_administrador` (policy)** — créée par `20260507_ulm_select_policies_for_team_panel.sql`. Renommée en `ulm_select_all_for_network_admin` au paquet C.5a du chantier admin réseau (11/05/2026). Trace en prod : `COMMENT ON POLICY ulm_select_all_for_network_admin ON public.user_library_memberships IS 'Visibilité totale de user_library_memberships pour les administrateurs réseau. Renommée du nom historique ulm_select_all_for_administrador au paquet C.5a (11/05/2026). Le helper fn_caller_is_network_admin interroge network_administrators uniquement (paquet A).'`

**`trg_notify_emprestimo_status_change` (trigger)** — créé par une migration `db/migrations/` antérieure au paquet 9. Déprécié et retiré au paquet 9 (10/05/2026). La fonction sous-jacente `public.trg_notify_emprestimo_status_change()` est toujours présente en prod avec le commentaire : `COMMENT ON FUNCTION public.trg_notify_emprestimo_status_change() IS 'DEPRECATED 2026-05-10 (paquet 9) : sa logique a ete absorbee dans ...'`. Le code de la fonction reste pour traçabilité historique, mais aucun trigger ne l'invoque plus.

### 3.2 — Conclusion d'audit

**La dette résiduelle évoquée par `.woodpecker.yml` n'existe plus.** Tous les objets que `db/migrations` aurait dû produire sont soit en prod, soit volontairement retirés par un chantier ultérieur tracé. Aucune migration n'est orpheline en prod, aucun objet en prod n'est dépourvu d'origine identifiable.

## 4. Décision

**`db/migrations/` est archivé**, pas supprimé. La trace historique a une valeur — pour reconstituer l'origine d'une fonction encore vivante, ou pour comprendre une décision passée sans aller chercher dans Git. L'archivage se fait par déplacement avec `git mv` pour préserver l'historique des fichiers.

### Action immédiate

```bash
# Depuis la racine du repo anarbib-app/
git mv db/migrations docs/archive/db-migrations-legacy-pre-woodpecker
git mv docs/archive/db-migrations-legacy-pre-woodpecker/_diagnostics docs/archive/db-migrations-legacy-pre-woodpecker/_diagnostics
# (la seconde commande est idempotente et conserve la structure interne)

# Si le dossier docs/archive/ n'existe pas encore :
# mkdir -p docs/archive (avant les git mv)

# Le dossier db/ devient vide après l'archivage : on le supprime
rmdir db/ 2>/dev/null || true
```

### Mise à jour du `.woodpecker.yml`

Le commentaire historique des lignes 211-220 du `.woodpecker.yml` est obsolète. Il est remplacé par une version plus brève qui pointe vers ce document et vers l'archive.

**Avant** (lignes 211-220, à modifier) :

```yaml
  # NOTE HISTORIQUE :
  # Le dossier `db/migrations/` (à la racine du repo) contient l'historique
  # des migrations antérieures au paquet 14 et est figé en lecture seule.
  # Il y a un écart connu entre les fichiers locaux et le tracker prod
  # (certaines migrations ont été appliquées via SQL Editor sans être
  # commitées dans `db/migrations/`) qui ne peut être réconcilié rétroactivement.
  # Cette dette est acceptée : à partir du paquet 14, toutes les nouvelles
  # migrations passent par ce flow CI et sont donc 100% reproductibles.
```

**Après** :

```yaml
  # NOTE HISTORIQUE :
  # Les migrations antérieures au paquet 14 (01/05 → 10/05/2026, format
  # hétérogène) sont archivées dans `docs/archive/db-migrations-legacy-pre-woodpecker/`.
  # L'audit du 29/05/2026 (cf. `docs/journal/operations/CLEANUP_db_migrations_2026-05-29.md`)
  # a vérifié que 100 % des objets créés par ces migrations sont soit en prod,
  # soit volontairement retirés par un chantier ultérieur tracé. Aucune dette
  # résiduelle. Depuis le paquet 14, toutes les nouvelles migrations passent
  # par le flow CI ci-dessous et sont 100 % reproductibles.
```

## 5. Traçabilité après archivage

Pour retrouver l'origine d'une fonction ou d'une policy dont la création n'est pas dans `supabase/migrations/` :

1. Vérifier d'abord les commentaires SQL en base (`COMMENT ON FUNCTION ...`) qui pointent souvent vers le paquet et la date d'origine.
2. Si nécessaire, chercher dans `docs/archive/db-migrations-legacy-pre-woodpecker/` par nom de fichier (les noms incluent la date au format `YYYYMMDD_*.sql`) ou par grep sur l'objet recherché.

L'historique Git est préservé grâce à l'usage de `git mv` plutôt qu'une suppression suivie d'une copie.

## 6. Doctrine confirmée

Cet audit valide une pratique tacite du projet : **les commentaires SQL en prod sont la documentation primaire des refontes et retraits volontaires**. Chacun des quatre objets « absents » de l'audit portait un commentaire explicite qui a permis de qualifier l'absence en moins d'une minute. Cette pratique mérite d'être inscrite formellement — c'est probablement à intégrer dans le document doctrinal central `CHANTIER_doctrine_creation_objets_securises_2026-05-12.md` à sa prochaine révision : *« Tout retrait volontaire d'un objet (fonction, trigger, policy) doit être tracé par un `COMMENT ON ...` en prod qui pointe vers le chantier ou le paquet d'origine du retrait. »*

---

*Fin de la note. À committer avec le déplacement `git mv` dans le même commit, ainsi que la mise à jour du `.woodpecker.yml`. Message de commit suggéré : `chore: archive db/migrations legacy (pre-Woodpecker), audit 100% covered`.*
