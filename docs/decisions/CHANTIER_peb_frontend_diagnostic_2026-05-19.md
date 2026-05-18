# CHANTIER PEB Frontend — Diagnostic et plan

**Date du diagnostic** : 19 mai 2026 (fin de session profils d'adoption)
**Auteur·rice** : Xavier (session avec Claude)
**Statut** : Reporté à session dédiée fraîche
**Précondition technique** : Aucune (backend prêt depuis le paquet C.4a.1 du 19/05)

---

## TL;DR

Le **backend PEB est 100% opérationnel** depuis le bouclage du paquet C.4a.1 :
triple défense (RLS SELECT permissive + RLS INSERT/UPDATE composite + RPC check),
11 RPC métier, 4 tables, 3 vues UI complètes.

Le **frontend JSX actuel** (onglet `ill` dans `BibliotecaPage.jsx`) **contourne**
toute cette machinerie : il utilise des accès Supabase directs via `.from('...')`
au lieu d'appeler les RPC SECURITY DEFINER. Conséquence : les protections
backend ne sont pas activées, et le module ne respecte pas les workflows métier.

Le message frontend obsolète `biblioteca.exchanges.implementationPending`
existe parce que **la personne qui a transposé le HTML monolithique en JSX a
laissé 90% du périmètre derrière**. Le câblage actuel JSX est une coquille
syntaxiquement valide mais doctrinalement incorrecte.

**Le câblage complet est un chantier de 3-5h dédié**, à faire en session fraîche.
Ne pas démarrer en fin de session intensive.

---

## État backend PEB (100% prêt)

### Tables (4)

| Table | Rôle |
|---|---|
| `interlibrary_loans_v2` | En-tête PEB (lender, borrower, dates, contacts, logistics) |
| `interlibrary_loan_items_v2` | Items individuels du PEB (exemplaires) |
| `interlibrary_loan_events` | Journal d'événements (audit trail) |
| `interlibrary_loan_notification_events` | Queue de notifications email |

### RPC métier (11)

| RPC | Rôle |
|---|---|
| `fn_v2_create_emprestimo_interbibliotecas` | Créer en-tête PEB. **C.4a.1 19/05** : check `fn_peb_authorized` |
| `fn_v2_add_emprestimo_interbibliotecas_itens` | Ajouter items à un PEB en préparation |
| `fn_v2_remove_emprestimo_interbibliotecas_item` | Retirer un item |
| `fn_v2_remove_emprestimo_interbibliotecas_itens` | Retirer plusieurs items |
| `fn_v2_dispatch_emprestimo_interbibliotecas` | Envoyer (préparation → emprestado) |
| `fn_v2_start_devolucao_emprestimo_interbibliotecas` | Démarrer retour |
| `fn_v2_return_emprestimo_interbibliotecas_linhas` | Confirmer retour items |
| `fn_v2_cancel_emprestimo_interbibliotecas` | Annuler |
| `fn_v2_recompute_from_emprestimo_interbibliotecas_linhas` | Recompute statut global depuis items |
| `fn_v2_refresh_emprestimo_interbibliotecas_status_global` | Refresh statut |
| `fn_v2_log_emprestimo_interbibliotecas_event` | Helper logging events |

### Notifications

- `fn_enqueue_emprestimo_interbibliotecas_notification` (trigger-side)
- `fn_notify_emprestimo_interbibliotecas_webhook` (envoi)
- `trg_interlibrary_loan_enqueue_notifications` (déclencheur AFTER INSERT/UPDATE)

### Vues UI (3)

| Vue | Colonnes clés |
|---|---|
| `api.interlibrary_loans_painel_ui` | header + agrégats items, calcule `local_role` (emprestadora/tomadora/ambas), `partner_library_*` selon point de vue |
| `api.interlibrary_loan_items_ui` | items détaillés avec is_overdue, days_until_due, days_overdue |
| `api.interlibrary_loans_reports_ui` | (à vérifier le contenu) |

### Protections RLS (paquets C.3b + C.3c, 19/05)

- **SELECT permissive** sur `interlibrary_loans_v2` : permet la lecture pour clôture
  des PEB en cours même si une biblio bascule en `circulation_mode='off'`
- **INSERT/UPDATE composite stricte** : `fn_peb_authorized(lender, borrower)`
  exige circulation+federated des deux côtés

### RPC check (paquet C.4a.1, 19/05)

`fn_v2_create_emprestimo_interbibliotecas` lève une exception P0001 avec
`hint = 'error.library.peb_not_authorized'` si une des deux biblios ne remplit
pas les conditions. **Traduit en C.4c.1 × 6 locales**.

---

## État frontend PEB (anti-patterns détectés)

### Fichier concerné

`src/pages/biblioteca/BibliotecaPage.jsx`, onglets `exchanges` et `ill`.

### Onglet `exchanges` (lignes 1109-1131)

- Formulaire maquette : sélecteur biblio partenaire, champs localDoc/wantedDoc/message/note
- 2 boutons `disabled` (register + openEmail)
- **Aucun handler câblé**
- Message en dur `biblioteca.exchanges.implementationPending` ligne 1129

**À supprimer** : onglet entier (le périmètre est couvert par `ill` qui est plus complet).
Garder éventuellement comme route alias vers `ill`, ou supprimer complètement.

### Onglet `ill` (lignes 1134-1221, 89 lignes JSX)

Possède la structure complète :
- Sélecteurs lender/borrower/status
- Recherche d'items (livres) avec ajout/retrait
- Champs contact, meeting point, dates, notes
- Bouton save + bouton clear
- Liste des PEB existants avec changement de statut + suppression

### Handlers JSX actuels — Anti-patterns

| Handler | Approche actuelle (incorrecte) | RPC correcte à utiliser |
|---|---|---|
| `saveIll` (ligne 315) | `.from('interlibrary_loans_v2').insert(...)` puis `.from('interlibrary_loan_items_v2').insert(...)` | `fn_v2_create_emprestimo_interbibliotecas` + `fn_v2_add_emprestimo_interbibliotecas_itens` |
| `updateIllStatus` (ligne 344) | `.from('interlibrary_loans_v2').update({status_global})` | `fn_v2_dispatch/start_devolucao/return/cancel_*` selon transition |
| `deleteIll` (ligne 349) | `.from('...').delete()` direct sur 2 tables | `fn_v2_cancel_emprestimo_interbibliotecas` |
| `searchIllDocs` (ligne 302) | `.from('books').select(...)` direct | OK en lecture, à conserver |
| Source `illLoans` (ligne 135) | `.from(...)` direct via `loadAll()` | `api.interlibrary_loans_painel_ui` |

**Conséquences pratiques** :
- Pas de check `fn_peb_authorized` au moment de l'INSERT direct → un staff de biblio
  isolated/off peut créer un PEB factice
- Pas de calcul `local_role` ni de `partner_library_name` → affichage pauvre,
  Lender↔Borrower difficile à lire
- Pas de logging events → pas d'audit trail
- Pas de queueing notifications → pas d'emails envoyés
- Pas de recompute statut global cohérent

---

## Référence : HTML monolithique original

Le fichier `biblioteca.html` (~5000 lignes) contient l'implémentation **historiquement
complète** du module PEB. La transposition JSX n'a repris que la coquille UI.

### Éléments du HTML à retransposer

#### Logique de politique (governance)

- `cfg.interlibrary_exchange.enabled` (bool) — activation locale
- `cfg.interlibrary_exchange.mutualization_only` (bool) — réciprocité requise
- `cfg.interlibrary_exchange.policy_note` (text) — politique affichée
- `cfg.interlibrary_exchange.guardrail_note` (text) — garde-fou affiché
- `cfg.interlibrary_exchange.min_total_copies` (int, défaut 2) — minimum exemplaires
- `cfg.interlibrary_exchange.min_available_copies` (int, défaut 2) — minimum dispo
- `cfg.interlibrary_exchange.require_available_now` (bool, défaut true)

→ Ces réglages vivent en JSONB sur `libraries.governance_settings` (ou équivalent).
À vérifier en début de session fraîche.

#### Sélection d'exemplaires (pas juste de livres)

Le HTML permet de sélectionner des **exemplaires** spécifiques (avec `tombo`),
pas juste des livres abstraits. Le JSX actuel sélectionne des `book_id` uniquement.
À aligner sur le pattern HTML qui passe par `holdings_with_lib` + `exemplares`.

#### Conditions de prêt entre biblios

- Vérifier que la biblio lender a `min_total_copies` exemplaires du livre
- Vérifier `min_available_copies` disponibles immédiatement
- Si `mutualization_only`, vérifier que la biblio borrower autorise réciproquement
  (`partnerAllowsExchange(partnerRow)`)
- Si `enabled === false`, refuser

→ Ces checks sont peut-être à intégrer dans une RPC dédiée
`fn_v2_check_peb_preconditions` ou dans `fn_v2_create_emprestimo_interbibliotecas`
elle-même. À discuter.

#### Status tones (couleurs)

- `interlibraryLoanStatusTone(value)` ligne 4051 du HTML — mapping
  statut → classe CSS (ok/info/warn/bad)
- `interlibraryLoanItemStatusTone(value)` ligne 4169 — idem pour items

→ Existe-t-il déjà des constantes équivalentes en JSX ? À vérifier dans `lib/`
ou créer un `src/lib/pebTones.js`.

#### Statuts amicaux (traductions)

- `friendlyInterlibraryLoanStatus(status)` — mapping enum → texte
  utilisateur traduit

→ Les clés i18n `ill.status.preparacao`, `ill.status.aguardando_saida`,
`ill.status.emprestado`, `ill.status.em_devolucao`, `ill.status.devolvido`,
`ill.status.cancelado` existent déjà côté JSX. Bon point de départ.

#### Système de cancel

- Confirmation explicite avant cancel (HTML ligne 4894)
- Appel `fn_v2_cancel_emprestimo_interbibliotecas` (pas DELETE)
- Refresh status après

#### Composant proposition de troca (interlibrary_exchange)

Le HTML inclut aussi un système de **propositions de troca** (échange permanent
d'exemplaires entre biblios), distinct du PEB classique. Lignes 3436-3477, 3904-3920.
**Hors scope chantier PEB** — c'est un autre module à part entière.

---

## Plan de chantier (session future)

### Préparation (30 min)

- Lire `biblioteca.html` lignes 600-5000 méthodiquement
- Cartographier chaque fonction HTML → RPC backend + colonne vue UI
- Vérifier que `libraries.governance_settings` contient bien `interlibrary_exchange`
- Auditer si d'autres composants JSX consomment des accès `.from('interlibrary_*')`
  directs qui devraient passer par RPC

### Refactor (2-3h)

#### Découpe en composants

`BibliotecaPage.jsx` est trop gros déjà (1900+ lignes). Créer un composant dédié :

```
src/components/biblioteca/PebPanel.jsx        (~400 lignes)
  ├── PebForm.jsx        (création/édition PEB)
  ├── PebItemsManager.jsx (sélection exemplaires)
  ├── PebList.jsx        (liste PEB existants)
  └── PebStatusBadge.jsx (rendu visuel statut)

src/lib/peb.js
  ├── createPeb()        → fn_v2_create_emprestimo_interbibliotecas
  ├── addPebItems()      → fn_v2_add_emprestimo_interbibliotecas_itens
  ├── removePebItem()    → fn_v2_remove_emprestimo_interbibliotecas_item
  ├── dispatchPeb()      → fn_v2_dispatch_emprestimo_interbibliotecas
  ├── startReturnPeb()   → fn_v2_start_devolucao_emprestimo_interbibliotecas
  ├── returnPebLines()   → fn_v2_return_emprestimo_interbibliotecas_linhas
  ├── cancelPeb()        → fn_v2_cancel_emprestimo_interbibliotecas
  ├── fetchPebPainelRows() → api.interlibrary_loans_painel_ui
  └── fetchPebItemRows()   → api.interlibrary_loan_items_ui

src/lib/pebTones.js
  └── interlibraryLoanStatusTone() + item tone
```

#### Suppression onglet `exchanges`

L'onglet `exchanges` devient redondant avec `ill` complet. Trois options :
1. Supprimer totalement l'onglet `exchanges` + ses clés i18n
2. Garder une route alias vers `ill`
3. Garder `exchanges` pour les **propositions de troca permanente** (hors scope PEB)
   et `ill` pour les emprunts ponctuels

**Décision à prendre en début de session.**

#### Suppression clé i18n obsolète

`biblioteca.exchanges.implementationPending` × 6 locales — à supprimer après
livraison du câblage.

### Tests fumée (1h)

- Créer un PEB BLMF→BTL avec 2 exemplaires
- Vérifier `api.interlibrary_loans_painel_ui` côté BLMF (local_role='emprestadora')
  et côté BTL (local_role='tomadora')
- Dispatch, retour, cancel
- Vérifier journal events
- Vérifier emails envoyés (si configuré)
- Tester refus quand une biblio passe en `circulation_mode='off'`
  (le check C.4a.1 doit faire son office)

---

## Précautions

1. **Sentinelles prod** : BLMF + BTL sont les seules biblios. **0 PEB en prod**
   actuellement. Tester en local d'abord, puis en prod sur un PEB de test
   BLMF→BTL qu'on annule proprement à la fin.

2. **Ne pas casser le JSX existant pendant la session** : faire une nouvelle
   branche git, ou copier `BibliotecaPage.jsx` en `.bak.pre-peb-cablage.<ts>`
   avant tout.

3. **i18n** : 6 locales à maintenir cohérentes. Les clés `biblioteca.ill.*`
   existent déjà — auditer si certaines doivent être renommées ou ajoutées.

4. **Doctrine v2 création objets backend** : si on ajoute une RPC
   `fn_v2_check_peb_preconditions`, suivre le template
   `docs/decisions/CHANTIER_doctrine_creation_objets_securises_2026-05-12.md`.

5. **UTF-8 PowerShell** : si on patche les JSON i18n, méthode
   `[System.IO.File]::ReadAllText/WriteAllText` avec `UTF8Encoding(false)`.

---

## Statut final 19/05/2026 fin de session profils d'adoption

- Backend PEB : **prêt et protégé** (triple défense + RPC i18n)
- Frontend PEB : **diagnostiqué**, périmètre cartographié, reporté à session fraîche
- Message `biblioteca.exchanges.implementationPending` : **maintenu** jusqu'à
  livraison du câblage (honnêteté doctrinale : le formulaire est prêt visuellement
  mais le câblage RPC manque)
- Spec profils d'adoption v0.5 : **entièrement livrée et déployée**
- Prochain chantier suggéré : **paquet D** de la spec profils d'adoption,
  ou **chantier PEB frontend** en session dédiée
