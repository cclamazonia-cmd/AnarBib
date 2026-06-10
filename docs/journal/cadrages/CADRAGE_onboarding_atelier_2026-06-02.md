# CADRAGE — Onboarding : atelier de constitution (Biblioteca) & prise en main (Painel)

| | |
|---|---|
| **Genre** | Cadrage — **trace non-normative** |
| **Date** | 2026-06-02 |
| **Auteur·rices** | Xavier (arbitrages) · Claude (rédaction) |
| **Statut** | Cadré 02/06/2026, **tous arbitrages clos** — alimente le **chantier #111** (Q3 2026) |
| **Décisions normatives** | `REGISTRE_decisions.md` : **DOC-COLLECTIVE-1** (§0) ; **ONBO-Q1..Q12, ONBO-D1, ONBO-D2** (§26) ; **RES-Q11/Q12** réalignées. *Ce document ne reformule pas ces décisions : il les met en récit.* |
| **Préséance** | Registre + spec courante + backlog **priment**. Ce cadrage est une trace ; l'ID au registre fait foi. |
| **Supersession** | Complète `spec-onboarding-biblioteca v2.0` (à graduer **v2.1** : intégrer ONBO + corriger le drift i18n « ×6 » → 8) ; absorbe les TODO 1-7 ; amorce **`spec-onboarding-painel`** (à créer). |
| **Maquettes de référence** | `atelier-constitution-biblioteca.html` · `prise-en-main-painel.html` (prototypes cliquables, hors backend). |

---

## 1. Le nœud tranché

Trois objets se confondaient sous « onboarding » : (a) le **wizard de constitution** (#111, pré-activation, `/conta`) ; (b) un **onboarding de première arrivée** sur BibliotecaPage active ; (c) leur **unification**. Retenu : (c) — **un seul atelier réutilisable** sert constitution *et* redéfinition (**ONBO-Q1**). Périmètre : **pas de bilan rétroactif** ; BLMF en direct, BTL en réunion, BLT fictive (**ONBO-Q3**).

## 2. Deux patterns, parce que deux verbes

Le·la coordinateur·rice **configure**, le·la bibliothécaire **opère** — d'où deux UX distinctes.

**Biblioteca — atelier en étoile (hub-and-spoke), pas tunnel.** Tableau central, toutes les étapes visibles, panneaux focalisés, sauvegarde-reprise, progression X/N sur les volets applicables. Ce choix sert **DOC-COLLECTIVE-1** (matérialisée par ONBO-D1 : bannière permanente non-fermable + vocabulaire « discuté en collectif ») et **RES-D9** (anti-méga-machine : canal humain co-présent, jamais relégué).

**Painel — visite guidée, pas formulaire.** Cf. §4.

## 3. Colonne vertébrale : volet ↔ onglet ↔ composant (**ONBO-Q2**)

L'atelier et la page sont **deux vues de la même configuration** ; les panneaux **embarquent les composants de prod** → un seul chemin d'écriture.

| Volet (spec v2.0) | Onglet BibliotecaPage | Composant réutilisé | Conditionné par |
|---|---|---|---|
| 0 — profil | bannière / transicoes | `LibraryProfileWizard` (en prod) | — |
| 1 — identité | identity | `LocaleSelector`, `LibraryVisualAssetsSection`, `LibraryContactProfileSection` | toujours |
| 2 — horaires | identity (service state) | section service_state (in-page) | toujours |
| 3 — personnes | team | `TeamPanel` | `governance_mode ≠ informal` |
| 4 — catalogage | CatalogaçãoPage | déclaration (ONBO-Q7) | `catalog_mode ≠ local_only` |
| 5 — circulation | regulation | `PolicySetManager` + `RegimeStateBox` | `circulation_mode ≠ off` |
| 6 — adhésion lecteur·rice | leitores | `LeitoresPanel` / membership config | `governance ≠ informal` **et** `circulation ≠ off` |
| 7 — e-mails | comms | section comms (in-page) | toujours |
| 8 — visibilité réseau | exchanges | `LibraryPartnershipsSection`, `DocumentGovernanceSection` | `network_mode ≠ isolated` |
| 9 — données | privacy | `RetentionPolicySection` | toujours |
| 10 — règlement | regulation/documents | génération PDF (artefact de délibération, spec §6.6) | toujours |

La table `library_constitution_progress` est **déjà spécifiée** (spec §3.1).

## 4. Painel — orientation profil-pilotée (**ONBO-Q4**)

Le·la bibliothécaire ne configure rien : **prise en main**. Pattern = **coach-marks** (spotlights sur les vrais onglets, langage clair) + **check-list de premières actions**, **pilotée par le profil** réglé en amont dans Biblioteca (« biblioteca détermine painel »). Visibilité = matrice **`usePanelAvailability`** (PROF §9.8) : `trabalho-do-dia`/`acoes`/`leitor`/`historico` toujours ; `consultas-locais`/`emprestimos-livro` si `circulation ∈ {informal, full_sigb}` ; `reservas`/`emprestimos-lote` si `full_sigb` ; `contribuicoes` hors persona bibliothécaire. **`spec-onboarding-painel` à créer.**

## 5. Cycle de vie, gouvernance & garde-fous

- **Expiration** (**ONBO-Q5**) : avertissement + rappels **J+67/J+74**, puis **gel** réveillable.
- **Changement de profil en cours d'atelier** (**ONBO-Q6**) : autorisé sans boucle ; volets inapplicables → « sans objet » **sans effacer**.
- **Mode redéfinition** (**ONBO-D2**) : même atelier ; déclencheur = **demande explicite du collectif** ; axes structurels **sous vote collectif** (PROF E.5).
- **Mandat coordinateur·rice** (**ONBO-Q8**) : **plusieurs coordenadores** possibles ; ajout = **cooptation** ; **auto-retrait libre** ; retrait d'autrui = **collectif** ; **garde-fou « dernier·ère coordenador·a »** (miroir RES-Q5). Réutilise la cooptation de gouvernance v1.1 — rien de neuf hormis le garde-fou.

## 6. Parcours d'entrée (**ONBO-Q9**)

Chemin **éditorial sur `anarbib.org`** (charte, portes différenciées, « écris-nous d'abord ») ; **formulaire `/solicitar-biblioteca` sur l'app**. Dépendance actée : **pages d'entrée en 8 locales** (**DOC-I18N-1**) sur le site militant, pratiques et user-friendly. Direction tranchée ; réalisation au #111.

## 7. Canal humain — co-présent, proactif, sans surveillance

Conforme **RES-D9** (premier, pas recours) :
- **Biblioteca** : bannière permanente (ONBO-D1) + `<HumanChannelInlineCallout>` **en tête de chaque volet** + `<HumanChannelFooter>` global.
- **Painel** : recadré « apprendre le métier » (camarades + coordination locale), même footer.
- **Proactivité admins** (**ONBO-Q10**) : notification **digest in-app** à l'entrée en constitution → « proposer un échange » (RES-D10), en respectant le risque burnout (RES-D11).
- **Jamais de blocage** (**ONBO-Q11**) : incohérence flairée → **nudge non-bloquant**, jamais un verrou.
- **Mesure** (**ONBO-Q12**) : stats **agrégées et non-individualisantes** ; **pas** de watchlist du silence.

## 8. Posture backend (irréprochabilité)

Application du foyer : écritures via RPC (**DOC-RPC-3**), fonctions privées `REVOKE`-ées + `search_path` figé + bloc DO (**DOC-OBJ-2**), `git push` → Woodpecker, jamais MCP/SQL Editor (**DOC-DEPLOY-1**), `npm run build` avant chaque push, clôture paquet par paquet (**DOC-CLOSE-1**). Toute clé i18n nouvelle = **8 locales** (**DOC-I18N-1**).

## 9. Maquetté vs à implémenter ; renvois

Les prototypes démontrent le **modèle** (disposition, conditionnalité live, canal humain, ton). Leurres à remplacer : champs des panneaux (→ vrais composants, ONBO-Q2), génération PDF, barre profil de démo du Painel (en prod : lue du contexte, invisible au·à la bibliothécaire), compteurs fictifs. Typo de maquette sans engagement ; prod sur thème `--brand-*`.

**Aucun arbitrage onboarding n'est laissé ouvert.** Deux renvois explicites, qui ne sont pas des trous de l'onboarding : l'**arbitrage profond de la classification** appartient au chantier **CAT** (l'onboarding n'en fixe que la *déclaration*, ONBO-Q7) ; la **réalisation** des pages d'entrée `anarbib.org` (ONBO-Q9) est planifiée au **#111**.

---

*Fin du cadrage. Document de trace ; les décisions vivent au registre (§0 DOC-COLLECTIVE-1 ; §26 ONBO).*
