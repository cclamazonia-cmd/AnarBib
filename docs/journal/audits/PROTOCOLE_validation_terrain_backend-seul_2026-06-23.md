# Protocole de validation terrain — clôtures « backend seul »

> **Date** : 2026-06-23
> **Origine** : audit externe code↔doc (§4.3, §6 #6). Les quatre modules
> #IMPORT / PARTNER / PEB / ILL-digital étaient marqués « backend seul, UX/terrain
> non audité ». **Vérification** : les écrans existent bien
> (`ImportWizard.jsx`, `LibraryPartnershipsSection.jsx` / `StabilizedPartnershipsSection.jsx`,
> `PebHistorySection.jsx`, `LibraryDigitalSharesSection.jsx`). Le manque n'est donc
> **pas l'écran** mais la **validation en usage réel par un·e non-spécialiste**.
> Ce document requalifie ces clôtures de « backend seul » → **« à éprouver en usage »**
> et fournit le mini-protocole correspondant.

Chaque scénario se joue **de bout en bout dans l'UI** (pas en SQL), avec un compte
réel de rôle indiqué, sur une biblio de test (ou BLMF avec données jetables). Critère
transverse : **un·e non-spécialiste y arrive sans aide**.

---

## 1. #IMPORT — assistant d'import de catalogue partenaire

- **Écran** : `ImportWizard.jsx` · **Backend** : `ingest.partner_catalog_import_runs`,
  EF `probe-partner-catalog` / `process-partner-catalog-import`.
- **Acteur** : coordenador.
- **Scénario** :
  1. Ouvrir l'assistant → choisir une source (CSV / OAI / Zotero).
  2. Lancer la **sonde** (probe) → vérifier l'aperçu des champs détectés.
  3. Mapper les champs → lancer l'import.
  4. Suivre le **run** (statut, compteurs) jusqu'à complétion.
  5. Vérifier que les notices/exemplaires sont créés et consultables au catalogue.
- **Succès** : N notices importées = N attendu ; **doublon ISBN réseau = blocage dur
  + rattachement** (CAT-B) ; run tracé dans `ingest.partner_catalog_import_runs`.
- **Vigilance** : encodage / mojibake (DOC-PS-1) ; volumes importants (perf) ;
  **idempotence** (relancer le même run ne duplique pas) ; messages d'erreur lisibles.

---

## 2. PARTNER — partenariats entre bibliothèques

- **Écran** : `LibraryPartnershipsSection.jsx` / `StabilizedPartnershipsSection.jsx`
  · **Backend** : `library_partnerships`, `partnership_rights`, trigger de symétrie.
- **Acteurs** : coordenador A et coordenador B (2 biblios).
- **Scénario** :
  1. A **propose** un partenariat à B → B le voit et **accepte**.
  2. Activer **droit par droit** (`transparence`, `digital_share`, `mutualisation`, `peb`).
  3. Côté lecteur·rice : vérifier le **consentement opt-in par partenariat**.
  4. A (ou B) **révoque** unilatéralement → vérifier la fermeture immédiate de l'accès.
- **Succès** : **symétrie stricte** (le partenariat apparaît identique des deux côtés) ;
  proposition/acceptation **réservées au coordenador** (PARTNER-D7) ; révocation = **RLS
  ferme l'accès sans copie ni résidu** + trace d'audit.
- **Vigilance** : un·e `librarian` ne doit **pas** pouvoir proposer/accepter ; après
  révocation, plus aucune donnée du partenaire n'est visible.

---

## 3. PEB — prêt entre bibliothèques (physique)

- **Écran** : `PebHistorySection.jsx` · **Backend** : machine à états verrouillée,
  cron `anarbib-peb-detect-overdue-daily`.
- **Acteurs** : biblio demandeuse + biblio source.
- **Scénario** :
  1. La demandeuse crée une **demande PEB**.
  2. La source **accepte** (ou refuse / indisponible).
  3. **Envoi** → **réception** → **retour** → **clôture** (suivre chaque transition).
  4. Laisser passer une échéance → vérifier la **détection auto de retard**.
- **Succès** : transitions **bidirectionnelles** cohérentes des deux côtés ; états
  illégaux refusés ; **bonne partie notifiée** à chaque étape (le **non-acteur**,
  DOC-NOTIF-1).
- **Vigilance** : pas d'état « coincé » sans action possible ; le retard remonte bien.

---

## 4. ILL-digital — partage numérique (matériel gris)

- **Écran** : `LibraryDigitalSharesSection.jsx` · **Backend** : `ill_digital_shares`,
  RPC `fn_ill_*`, EF `read-ill-shared-asset` / `notify-digital-share` /
  `revoke-digital-asset`.
- **Acteurs** : biblio source + lecteur·rice d'une biblio **partenaire**.
- **Scénario** :
  1. La source partage une ressource numérique → choisir **mode** (`ponctuel` / `durable`)
     et **plafond** (`public` / `staff_only`).
  2. Un·e lecteur·rice du partenaire **accède** à la ressource.
  3. La source **révoque** → vérifier que l'accès est **immédiatement coupé**.
- **Succès** : l'export n'est possible que si **partenariat ∧ droit `digital_share` ∧
  plafond compatible** ; **`staff_only` jamais `durable`** (contrainte `ill_staffonly_never_durable_chk`) ;
  révocation **sans résidu** + audit double horodaté ; plafond **non dépassable**.
- **Vigilance** : tester l'accès **au-delà du plafond** (doit échouer) ; après
  révocation, l'asset n'est plus servi (risque de **fuite réseau/BTL**).

---

## Sortie attendue

Pour chaque module : ✅ validé en usage / 🟠 anomalie UX (à corriger) / 🔴 blocant.
Une fois les 4 passés, retirer la mention « backend seul » du backlog (§4) au profit
de « éprouvé en usage le AAAA-MM-JJ ».
