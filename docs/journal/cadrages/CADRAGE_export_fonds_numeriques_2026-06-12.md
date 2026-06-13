# CADRAGE — Exportação de fonds numériques (remise d'un lot à une companheira)

| | |
|---|---|
| **Genre** | cadrage (trace de framing — non normatif tant que non ratifié au REGISTRE) |
| **Date** | 12 juin 2026 |
| **Statut** | 🟢 v0.2 — **conception actée** (P1-P4 tranchés Xavier 12/06) ; reste l'implémentation (§9) |
| **Chantier** | Importações/Exportações — face **Export**, niveau 2 (lots) |
| **Réfère à** | `spec-importacoes-exportacoes` §8 (sorties Export) ; `spec-flux-partage-numerique` (ILL ponctuel — niveau 1, **distinct**) ; `spec-acquisition-provenance` ; pipeline import `ingest`. |

> **Origine.** Arbitrage Xavier 12/06 : le partage numérique a **deux niveaux**. Le niveau 1
> (ponctuel, PEB-like, un doc à la demande) = `spec-flux-partage-numerique` / backend ILL-I1
> (déjà construit). Le **niveau 2** — remettre **en masse** un fonds de matériel gris numérisé
> (cartes postales, affiches, tracts, brochures) à une companheira — n'est PAS ce flux : il a sa
> place dans la **face Export d'Importações/Exportações**. Ce cadrage le pose.

---

## 1. Objet
Permettre à une bibliothèque de **remettre un lot** de documents numérisés (notices **+ fichiers**)
à une **companheira**, en une opération, dans le sens **Exportações** (sortie de fonds). Acte de
mutualisation patrimoniale, pas de consultation à la demande.

## 2. Distinction des autres sorties Export (cf. `spec-importacoes-exportacoes` §8)
| Sortie | Quoi | État |
|---|---|---|
| `exportação de lote` (IMP-13) | **notices seules** (sérialisation MARCXML/DC/CSV/JSON) | ✅ fait |
| `partilha de documento` / ILL-digital (niveau 1) | **un** doc, à la demande, ponctuel/durable | ✅ backend (ILL-I1) |
| `ser fonte` (OAI-PMH) | expose les **notices** au moissonnage | ✅ fait (OAI-O1..O4) |
| **`exportação de fonds`** (niveau 2, **CE cadrage**) | **un lot** : notices **+ fichiers**, remis à une companheira | ⬜ à construire |

→ Le niveau 2 = `exportação de lote` **augmentée des fichiers** + destinataire companheira.

## 3. Cible & périmètre — libre de droits par construction
- **Matériel gris non commercialisé** (cohérent ILL-1 ; demi-verrou ISBN/ISSN réutilisable).
- **Libre de droits** : la remise en lot vise un **versement durable** (catalogage chez la
  companheira), donc — cohérent ILL-5 (« cataloguer = affirmer libre de tous droits ») — **seuls
  les assets `digital_assets.rights_status = public_domain_confirmed`** sont éligibles (**décision
  P3 : strict**). Le gris **sous plafond restreint** reste du **ponctuel** (niveau 1, sans copie).
  Pas de bulk sous plafond `staff_only`.

## 4. Modèle (miroir de l'import)
1. **Sélection** : la source choisit un ensemble éligible (par collection, filtre, ou sélection
   manuelle) de notices + leurs `digital_assets` libres de droits.
2. **Empaquetage** : notices sérialisées (**réutilise `serialize.ts`** : MARCXML/DC/CSV/JSON) +
   fichiers (buckets publics) + un **manifeste** (lien notice↔fichier, provenance, licence,
   attribution — la provenance **voyage avec** le lot).
3. **Remise** : modes à trancher (§8 P1).
4. **Réception** : la companheira **ré-importe** via le **pipeline import existant**
   (`importação de arquivo` → `ingest` staging → `book_drafts`) + dépôt des fichiers dans ses
   buckets. **Export-fonds ↔ import-arquivo sont donc miroirs** — on réutilise toute la plomberie
   d'import (matching, dédoublonnage ISBN, file de revisão).

## 5. Gouvernance
- Gaté par **partenariat actif** + le droit **`mutualisation`** (**décision P2** ; existe déjà dans
  `partnership_rights` ; distinct de `digital_share` = ponctuel restreint) ; acte de **coordenador**.
- **Provenance & attribution** portées par chaque notice (réutilise `catalog_ref_*`, provenance
  `book_drafts`) — la companheira sait d'où vient chaque pièce.
- **Traçabilité** : un « **run d'export de fonds** », miroir du run d'import
  `ingest.partner_catalog_import_runs` (compteurs, acteur, horodatages, statut).

## 6. Implications techniques
- **Réutilise** : `serialize.ts` (notices) · buckets publics (fichiers) · pipeline `ingest` côté
  récepteur · plomberie provenance.
- **Nouveau** : UI de sélection (face Export) · EF d'empaquetage (bundle notices+fichiers, **ZIP**
  via Deno) · selon P1 : copie storage cross-projet **ou** ZIP téléchargeable.
- **Volumétrie** : un lot de fichiers peut être lourd → empaquetage **asynchrone / streaming** ;
  borne de taille par lot ; reprise.

## 7. Où ça vit
Face **Export** d'`ImportacoesPage` (`sentido = export`) : nouveau panneau **« Exportação de
fonds »** à côté d'`exportação de lote`. (≠ l'ILL ponctuel niveau 1, qui vit côté Biblioteca,
zone PEB/échanges.)

## 8. Décisions (actées Xavier 12/06/2026)
- **P1 — Mode de remise : LES DEUX.** (b) **paquet ZIP téléchargeable** (MVP, marche hors-AnarBib)
  **puis** (a) **transfert direct fédéré** (storage→storage entre biblios AnarBib).
- **P2 — Droit : `mutualisation`** (existant dans `partnership_rights` ; distinct de `digital_share`
  = ponctuel restreint). Le bulk libre-de-droits est un acte de **mutualisation de fonds**.
- **P3 — Éligibilité : `rights_status = public_domain_confirmed` STRICT** (le plus prudent).
- **P4 — Réception (découle de P1)** : ZIP → **ré-import manuel** par la companheira (via
  `importação de arquivo`) ; transfert direct → **dépôt semi-auto** en `ingest` staging chez elle.

## 9. Plan de lots (indicatif, si on construit)
- **EX-1** : sélection + manifeste + sérialisation notices (réutilise `serialize.ts`) → ZIP (mode b).
- **EX-2** : empaquetage des **fichiers** + run d'export de fonds (traçabilité, asynchrone).
- **EX-3** : réception = brancher le paquet sur `importação de arquivo` (miroir).
- **EX-4** : *(option P1.a)* transfert direct fédéré storage→storage.
- **EX-5** : UI face Export + i18n ×10 + doctrine (REGISTRE §17, nouveaux `IMP-16..`).

---

*v0.1 (cadrage, 12/06/2026). À ratifier au REGISTRE §17 une fois P1-P4 tranchés. Distinct de
`spec-flux-partage-numerique` (ILL ponctuel). Réutilise massivement la plomberie import/export
existante (serialize.ts, ingest, provenance).*
