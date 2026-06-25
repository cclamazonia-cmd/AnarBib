---
Genre : référence
Statut : 🟡 v0.1 — cadrage (rien d'implémenté ; à trancher en collectif/AG avant tout code)
Décisions : introduit DEPOT-0…DEPOT-10 (à verser au REGISTRE après validation) ; s'appuie sur COTIS-1…COTIS-10 (spec-cotisation)
Supersédé par : —
---

# Spec — Dépôt de garantie (caution remboursable par livre / par emprunt)

**Statut** : v0.1 — **cadrage**. Rien n'est implémenté. Ce document propose un modèle, **calqué sur l'architecture des cotisations**, à discuter et trancher en collectif avant la moindre ligne de code.
**Date** : 24/06/2026
**Origine** : pratique observée à l'**Anarchistisch Centrum Gent** (acompte remboursable de 3 € par livre — <https://acgent.wordpress.com/infotheek/>). Discussion AnarBib : bâtir sur une base proche des **cotisations** (argent, par biblio, rails locaux) et réévaluer les rails de paiement éthiques déjà cadrés en **COTIS-9** (PIX, QR EPC, Wero, virement SEPA instantané).
**Périmètre** : configuration par biblio, modèle de données (règles + registre des dépôts), cycle de vie collecte → détention → remboursement / rétention, soft-gate à l'emprunt, exemption de droit, rails de paiement (collecte **et** remboursement), notifications, affichage lectrice, rapports.

> **Vocabulaire.** On dit **dépôt de garantie** / **caution remboursable** (jamais « frais » ni « caution » au sens punitif : ce n'est ni une recette ni l'achat d'un service). pt-BR : **caução**. Le dépôt est une **somme détenue en fiducie**, restituée au retour de l'ouvrage. À distinguer **strictement** de la **cotisation** (recette, soutien au collectif, non remboursable).

---

## 0. Distinction fondamentale dépôt ≠ cotisation (DEPOT-0)

| | Cotisation (spec-cotisation) | Dépôt de garantie (ce document) |
|---|---|---|
| Nature | **Recette** (soutien au collectif) | **Passif / fiducie** (dû en retour) |
| Direction | Entre, **ne ressort jamais** | Entre **puis ressort** (remboursé) |
| Cycle | payé → valide → expire | collecté → **détenu** → **remboursé** \| **retenu** |
| Échéance | expire (gate dur, rappels cron) | n'expire pas (lié à la durée de l'emprunt) |
| Exclusion | « n'exclut personne » (exemption de droit) | **barrière à l'entrée du prêt** → même exemption de droit |

**DEPOT-0 — AnarBib est un *registre*, jamais un séquestre.** La bibliothèque **détient** l'argent (cash en présentiel, ou sur son rail local) ; AnarBib **trace** qui a versé quoi et l'état (détenu / remboursé / retenu). AnarBib ne **manipule** jamais les fonds, ne fait pas d'escrow, n'entre pas dans le périmètre PCI. **Conséquence directe : zéro donnée bancaire stockée** (comme les cotisations). On réutilise l'**architecture** des cotisations, **pas** la table `membership_payments` (sémantique opposée).

---

## 1. Principes directeurs (DEPOT-1…DEPOT-5)

- **DEPOT-1 — Strictement par bibliothèque, opt-in.** `libraries.deposit_enabled` (défaut `false`). La quasi-totalité des biblios n'utilisent pas le dépôt ; c'est la pratique de certaines (Gand-style). **Jamais imposé, jamais agrégé au niveau réseau** (cf. COTIS-1).
- **DEPOT-2 — Remboursable par défaut, c'est l'essence.** Un dépôt est une garantie **restituée au retour** de l'ouvrage. Le non-remboursement (**rétention**) est l'exception (perte / dégât), toujours **tracée et motivée**.
- **DEPOT-3 — Acte staff, anti-plateforme (= COTIS-3).** Collecte **et** remboursement sont **enregistrés par le staff** (espèces, virement, PIX, en nature, exemption…), jamais prélevés/restitués par un prestataire de paiement continu. **Pas d'encaissement automatique en v1.**
- **DEPOT-4 — Exemption de droit (= COTIS, non négociable).** Le staff peut **exempter par lecteur·rice** (`payment_method='exemption'`, montant 0) sans friction. Un dépôt ne doit **jamais** exclure pour raisons d'argent. **Leçon des cotisations** : sélection « exemption » ⟹ montant **forcé à 0 + champ désactivé**, dès le départ (le formulaire cotisation actuel ne le fait pas — à corriger là aussi).
- **DEPOT-5 — Soft-gate, jamais de blocage dur.** À la création d'un emprunt dans une biblio `deposit_enabled`, un dépôt est **attendu** : collecté **ou** explicitement **exempté**. C'est une **étape du flux comptoir**, pas un pré-blocage hostile (contrairement au gate dur des cotisations, COTIS-5). Le staff finalise le prêt en marquant le dépôt collecté ou exempté.

---

## 2. Configuration par bibliothèque (DEPOT-6)

- **`libraries.deposit_enabled boolean` (défaut `false`)** — interrupteur maître, comme `membership_enabled`.
- **`public.library_deposit_rules`** — règles propres à la biblio :
  - **`scope` ∈ `{per_item, per_loan}`** — un dépôt **par exemplaire emprunté** (modèle Gand) **ou par transaction d'emprunt**. *(Décidé : les deux supportés via ce champ.)*
  - `amount numeric(10,2)` (≥ 0), `currency text` (ISO 3 maj., défaut `EUR`).
  - `refundable boolean` (défaut `true`).
  - `is_active boolean`, `name`, `description`, `display_order`.
- **DEPOT-6 — gestion des règles = `coordenador`** (= COTIS-6, spec-gouvernance-roles).

---

## 3. Modèle de données

### 3.1 `public.loan_deposits` — le registre (cœur ; immuable + transitions tracées)
`id uuid`, `user_id uuid`, `library_id uuid`, `emprestimo_id` (FK), `emprestimo_item_id` (FK, **nullable** — renseigné si `scope=per_item`), `rule_id` (nullable), `amount numeric(10,2)` (≥ 0), `currency`, `collected_at timestamptz`, `collected_method membership_payment_method` (**réutilise l'enum cotisation**), `recorded_by` (staff), **`status deposit_status`** ∈ `{detenu, rembourse, retenu, partiel}`, `refunded_at`, `refunded_amount numeric(10,2)`, `refunded_method`, `refunded_by`, `retention_reason text` (**requis** si `retenu`/`partiel`), `notes`, `created_at`/`updated_at`, **`archived_at`/`archive_reason`** (archivage à la transition de profil, **jamais de suppression dure** — calque `membership_payments`).

### 3.2 Énumérations
- **`deposit_status`** : `detenu, rembourse, retenu, partiel`.
- **`membership_payment_method`** (réutilisé) pour `collected_method`/`refunded_method` : `cash, transfer, card, check, in_kind, exemption, other`. **`exemption`/`in_kind` de plein droit** à la collecte (DEPOT-4).

### 3.3 Vue `public.v_library_deposits` (état dérivé)
Par biblio : dépôts **détenus** (somme en fiducie courante = trésorerie « à rendre »), **remboursés**, **retenus** ; par lecteur·rice. Source des rapports (§9) et de l'affichage `/conta` (§8).

---

## 4. Cycle de vie & fonctions

```
collecté (detenu) ──[retour de l'ouvrage]──▶ remboursé (rembourse)
                  └─[perte / dégât]────────▶ retenu (retenu)  |  partiel (refunded_amount < amount)
```

- **`fn_record_deposit(p_user_id, p_emprestimo_id, p_emprestimo_item_id := NULL, p_rule_id, p_amount, p_method := 'cash', p_notes := NULL)`** → collecte (`status='detenu'`). **Garde** : staff (`can_access_painel`) ; `exemption`/`in_kind` contournent un éventuel plancher (calque `fn_record_membership_payment`). Émet le reçu `deposit_collected` (§7).
- **`fn_refund_deposit(p_deposit_id, p_refunded_method := 'cash', p_refunded_amount := <amount>, p_notes := NULL)`** → `status='rembourse'` (ou `'partiel'` si montant < `amount`). Garde staff. Émet `deposit_refunded`.
- **`fn_retain_deposit(p_deposit_id, p_retention_reason, p_partial_refund_amount := NULL)`** → `status='retenu'` (ou `'partiel'`). **Motif requis.**
- Transitions interdites refusées (un dépôt déjà `rembourse`/`retenu` ne se re-traite pas).

---

## 5. Lien au workflow d'emprunt (DEPOT-5, soft-gate)

- **À la création d'un emprunt** (RPC d'emprunt) dans une biblio `deposit_enabled` : selon `scope`, le front **propose la collecte** (par item ou par emprunt) à la finalisation. Le staff marque **collecté** ou **exempté**. **Soft-gate** : le prêt peut être finalisé en l'état (exemption tracée), pas un refus.
- **Au retour** (`emprestimo_itens_v2.item_status='devolvido'` ou emprunt `encerrado`) : si un dépôt `detenu` subsiste, l'UI **propose le remboursement** (`fn_refund_deposit`). Rappel visuel staff tant qu'un dépôt `detenu` reste sur un emprunt clos.
- **`fn_deposit_status_for_loan(p_emprestimo_id)`** : helper d'état (attendu / collecté / exempté / remboursé / retenu) pour l'UI.

---

## 6. Rails de paiement — collecte **et** remboursement

- **Collecte** : **réutilise l'infra COTIS-9** (coordonnées de paiement par biblio → **QR EPC** via `qrcode`, **clé/QR PIX**, **Wero**, **virement SEPA instantané**, ou **cash**). Rien à réinventer.
- **Remboursement = la pièce neuve** (la cotisation n'encaisse jamais en sens inverse). L'A2A instantané (PIX, SEPA instant) le permet techniquement, mais suppose la **coordonnée du·de la bénéficiaire**.
  - **DEPOT-7 — ne JAMAIS stocker la coordonnée bancaire du·de la lecteur·rice.** Remboursement **par défaut en cash, en présentiel** (zéro donnée). A2A en **option** : la coordonnée est fournie **éphémèrement** / gérée sur le **rail de la biblio**, **jamais persistée** côté AnarBib. AnarBib note seulement « remboursé, méthode X, le … ». *(Le cash contourne au passage le retard des banques françaises sur les QR de paiement.)*
- **DEPOT-8 — pas d'encaissement automatique en v1** (= COTIS-7). Webhook prestataire = **ouvert** (cf. COTIS-9b), **opt-in par biblio**, jamais imposé, **décision d'AG** si la portée est réseau. Acteurs à n'envisager qu'éthiques/militants (HelloAsso = FR seule ; Open Collective Europe ; Liberapay 0 % ; Wero A2A à surveiller).

---

## 7. Notifications (optionnelles, par biblio)

- **Reçu de collecte** — e-mail au membre si la biblio l'active (`library_notification_policies.deposit_receipt_mail_enabled`, défaut ON) : montant + emprunt concerné + mention « **remboursable au retour** ».
- **Reçu de remboursement** — e-mail : montant restitué + méthode.
- **Au membre seulement** (DOC-NOTIF-1), best-effort (ne casse jamais l'acte staff). **Pas de gate dur ⟹ pas de rappel cron** type cotisation (un dépôt n'expire pas ; il est lié à la vie de l'emprunt).

---

## 8. Affichage lectrice — `/conta`

- Section **dépôts** (si la biblio est `deposit_enabled` et que le membre a des dépôts) : dépôts **détenus** (montant, emprunt, depuis quand) + historique (remboursés / retenus). **État permanent**, comme le bandeau cotisation. Source : **`api.fn_my_deposits_status()`** (par appartenance).

---

## 9. Rapports bibliothèque (DEPOT-9 — couvre aussi un besoin cotisation)

> Besoin exprimé : un **tableau de suivi exportable**, **généré uniquement par et pour les biblios** ayant le système actif.

- **Cotisations d'abord** (besoin immédiat, modèle déjà en prod) : vue tableau par biblio, **réservée `coordenador`**, **uniquement si `membership_enabled`** — membres × statut (`dues_status`, `last_valid_until`, jours restants, dernier paiement montant/méthode/date) + totaux.
- **Dépôts ensuite** (même écran) : **détenus / remboursés / retenus** + **somme en fiducie courante** (trésorerie « à rendre » du collectif).
- **Export** : **PDF** (`jspdf` déjà présent ✅) + **CSV** (zéro dépendance, ouvrable Excel/LibreOffice — couvre 90 % du besoin). **XLSX** = nécessiterait `xlsx`/SheetJS → **différé** (ne pas alourdir le bundle tant qu'une biblio ne le réclame pas).
- Gabarit : `api.fn_library_cotisation_report(p_library_id)` / `api.fn_library_deposit_report(p_library_id)` (`SECURITY DEFINER`, garde `coordenador` + flag d'activation).

---

## 10. Garde-fous / valeurs (récap)

- **DEPOT-0** : registre, pas séquestre → **zéro donnée bancaire**.
- **DEPOT-4** : exemption de droit (ne pas exclure pour raisons d'argent).
- **DEPOT-7** : pas de coordonnée bancaire lecteur·rice stockée (remboursement cash par défaut).
- Souveraineté biblio (opt-in), **acte staff**, **canal humain premier**, anti-méga-machine.

---

## 11. Points ouverts (à trancher en collectif)

- **Encaissement/remboursement A2A automatique** (webhook) — COTIS-9b, opt-in, AG si réseau.
- **XLSX** (dépendance SheetJS) vs **CSV** — trancher si une biblio le réclame vraiment.
- **Plafond** de dépôt par biblio / par lecteur·rice ? (limiter la barrière).
- **Dépôt unique « tournant »** par lecteur·rice (un seul dépôt couvrant tous ses emprunts) vs par emprunt/item — le `scope=per_loan` s'en rapproche ; à confirmer.
- **Sort du dépôt à la suppression de compte RGPD** (`fn_delete_my_account`) : un dépôt `detenu` doit être **réglé/remboursé** avant, ou tracé/anonymisé comme le reste.
- **Articulation PEB / partage numérique** (dépôt inter-biblio ?) — **hors périmètre v1**.

---

## 12. Annexe — artefacts à créer (rien n'existe encore)

- **Tables** : `library_deposit_rules`, `loan_deposits` ; colonne `libraries.deposit_enabled` ; (option) `library_notification_policies.deposit_receipt_mail_enabled`.
- **Enums** : `deposit_status` ; réutilise `membership_payment_method`.
- **Fonctions** : `fn_record_deposit`, `fn_refund_deposit`, `fn_retain_deposit`, `fn_deposit_status_for_loan`, `api.fn_my_deposits_status` ; vue `v_library_deposits` ; rapports `api.fn_library_cotisation_report` / `api.fn_library_deposit_report`.
- **Edge Functions** : `handleDepositCollected` / `handleDepositRefunded` (moule de `_shared/domain/membership.ts`), clés mail `deposit.*` (10 locales).
- **Frontend** : étape dépôt dans le flux d'emprunt (Painel), section `/conta`, écran **Rapports** (BibliotecaPage) avec export PDF/CSV.
- **i18n** : `deposit.method.*` (réutilise l'enum), `deposit.status.*`, `deposit.report.*` (10 locales, charte inclusive).
- **Tests** : `tests/sql/paquet_depot_garantie_tests.sql` (collecte, remboursement, rétention, exemption, soft-gate, garde staff) + ajout à `ci-suites.txt`.
- **Décisions REGISTRE** : DEPOT-0…DEPOT-10 ; s'appuie sur COTIS-1…COTIS-10.
- **Correctif connexe (leçon exemption)** : auto-zéro + désactivation du champ montant à la sélection `exemption` — **côté cotisation (existant) ET dépôt (à naître)**.

---
*Spec produite le 24/06/2026 (cadrage v0.1, session « réflexion dépôt de garantie »). Rien d'implémenté : à discuter/valider en collectif/AG. DEPOT-0…DEPOT-10 à verser au REGISTRE après validation.*
