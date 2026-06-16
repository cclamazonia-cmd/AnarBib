---
Genre : référence
Statut : 🟢 implémentée & déployée en prod — MAJ 16/06/2026, lots OAI-O1..O3 désormais poussés/déployés (fn_oai_* + tables oai_opening_requests/oai_opening_votes + frontend OaiSourcePanel). Cf. INVENTAIRE Resync 16/06.
Décisions : incarne `OAI-1..OAI-9` (à ratifier au REGISTRE §17, prolonge `IMP-13` « ser fonte ») ; cite `PARTNER-*`, `DOC-RPC-3`, `DOC-I18N-1`
Supersédé par : —
---

# spec-oai-provider-gouvernance

| | |
|---|---|
| **Version** | v0.1 — conception actée (arbitrages Xavier 12/06/2026) |
| **Date** | 12 juin 2026 |
| **Emplacement cible** | `docs/specs/` |
| **Statut** | Modèle de gouvernance tranché ; backend (OAI-O1) + EF provider (OAI-O2) + frontend rede (OAI-O3) **construits** (non poussés). Reste O4 (notif) + ratification REGISTRE. |
| **Réfère à** | `spec-importacoes-exportacoes` §8 (« ser fonte », `IMP-13`) ; `spec-partenariat-biblios` ; `spec-flux-partage-numerique` (circuit **distinct** — ILL ≠ OAI). |
| **Dépendances** | `libraries` (`visibility_level`, `catalog_mode`, `network_mode`, `is_active`, `slug`) · `user_library_memberships` · `network_administrators` · `v_books_public_catalog_v2` · `book_holdings` · pg_cron · pg_net · Supabase Edge Functions. |

> **Objet.** « Être source » = exposer le catalogue d'AnarBib au **moissonnage OAI-PMH** par
> d'autres bibliothèques. Miroir sortant de « fontes externas » (import). Ce n'est **jamais** un
> simple interrupteur : l'ouverture est **gouvernée** et **toujours temporaire** (fermeture
> manuelle ; bannière d'alerte permanente tant que c'est ouvert).

---

## 1. Deux sens de décision [OAI-1]
L'ouverture du endpoint se décide dans **deux sens** :
- **Ascendant** (une biblio s'ouvre elle-même) : le **coordenador** demande l'ouverture de **sa**
  biblio aux admins du réseau (via l'adresse fédérale). **Un seul admin** suffit à approuver.
- **Descendant** (le réseau s'ouvre à un tiers) : un **admin** propose d'ouvrir le catalogue de
  **tout le réseau** à une **entité externe**. Décidé par un **vote** des biblios concernées.

## 2. Biblios « concernées » (sens descendant) [OAI-2]
Une biblio est concernée (vote + exposition) **ssi** elle publie déjà son catalogue au réseau :
`is_active` ∧ `visibility_level ∈ {public, network}` ∧ `catalog_mode = network_published` ∧
`network_mode ≠ isolated`. Les `private` / `local_only` (qui ont **refusé** la visibilité) ne
votent pas et ne sont **jamais** exposées. (Helper `fn_oai_library_is_harvest_eligible`.)

## 3. Le vote descendant [OAI-3]
- **Une voix par biblio**, portée par son **coordenador**. Fenêtre de **21 jours**.
- **Silence = consentement tacite** : à l'échéance, tout non-répondant → « oui ».
- **Unanimité requise** : un seul **non** explicite bloque (→ `refused`). Résolution **anticipée**
  (un non referme tout de suite ; tous oui ouvrent sans attendre l'échéance ; cron quotidien pour
  l'échéance). Verdict porté par le **statut** de la demande (`open` | `refused`).

## 4. Scrutin secret [OAI-4]
L'intérêt du vote n'est **pas** de voir qui a voté quoi, mais **seulement** si l'unanimité est
atteinte. Donc : chaque coordenador ne lit que la ligne de **sa propre** biblio (RLS) ; personne
ne lit le vote d'autrui. La **progression** vers l'unanimité est exposée en **comptes sans
identité** (`fn_oai_network_vote_progress` : concernées / consenties / en attente). Les RPC
`SECURITY DEFINER` lisent tout (bypass RLS) pour la mécanique, sans rien divulguer.

## 5. Adresse fédérale [OAI-5]
Toute la correspondance de gouvernance passe par une **adresse mail d'administration dédiée**
(`admins@` / `fede@anarbib.org`, provisionnée par Xavier). Elle **reçoit** les demandes
ascendantes et **émet** les sollicitations descendantes. Côté code : env `OAI_ADMIN_EMAIL` +
secret vault `WEBHOOK_SECRET_NOTIFY_OAI_OPENING`. Notification **découplée** (jamais bloquante
pour la gouvernance).

## 6. Fermeture & exposition [OAI-6]
- **Fermeture manuelle** : ascendant → coordenador de la biblio **ou** admin ; descendant → admin.
- **Bannière d'alerte permanente** tant qu'une ouverture concerne l'usager·ère (« referme dès que
  le partenaire a confirmé avoir terminé »).
- **Exposition réelle** : le endpoint ne sert **que** les biblios à ouverture **active**
  (ascendante propre, ou descendante active + concernée). **Catalogue fermé ⇒ rien servi.** Gate
  applicatif `fn_oai_harvestable_libraries` / `fn_oai_harvestable_records` (service_role).

## 7. Le endpoint OAI-PMH [OAI-7]
EF publique `oai-pmh-provider` (`verify_jwt=false` — un harvester externe n'a pas de JWT).
Verbes **Identify · ListMetadataFormats · ListSets · ListIdentifiers · ListRecords · GetRecord**,
pagination `resumptionToken`, erreurs OAI normalisées. Formats **`oai_dc`** (Dublin Core) et
**`marcxml`** (MARC21-slim, mapping reflétant `serialize.ts`). **Sets** = une biblio ouverte par
set (`lib:<slug>`). N'expose que `visibility = public` du catalogue scopé biblio.

## 8. Rôles [OAI-8]
- **coordenador** : demande l'ouverture de sa biblio (ascendant), vote (descendant), referme sa biblio.
- **admin réseau** (`network_administrators`) : approuve une demande ascendante (un seul suffit),
  propose une ouverture descendante, referme une ouverture réseau.
- Accès UI : onglet « être source » de la page **rede**, admis aux admins **et** aux coordenadores
  (ces derniers n'y voient que cet onglet, scopé à leurs biblios + leurs votes).

## 9. Implémentation [OAI-9]
- **OAI-O1** (DB) : `oai_opening_requests`, `oai_opening_votes` (RLS scrutin secret), 11 fonctions
  `fn_oai_*` (gouvernance + lecture EF + agrégat), cron quotidien de résolution tacite (3h45).
- **OAI-O2** (EF) : `oai-pmh-provider` + `_shared/oai/metadata.ts` (+ `config.toml`).
- **OAI-O3** (front) : onglet rede + `OaiSourcePanel.jsx` (autonome) + 6 edits balisés dans `RedePage.jsx`.
- **OAI-O4** (à faire) : EF `notify-oai-opening` (adresse fédérale).
- i18n : clés `rede.oai.*` × 10 locales (`DOC-I18N-1`).

## 10. Articulation avec le corpus
Prolonge `spec-importacoes-exportacoes` §8 / `IMP-13` (« ser fonte » = la sortie OAI). **Distinct**
de `spec-flux-partage-numerique` (ILL : partage *document à document* entre biblios fédérées ; ici
on expose des **notices bibliographiques** au moissonnage de masse). Le consentement de
mutualisation reste aligné sur la doctrine PARTNER (`mutualize_allowed` au niveau collectif).

---

*v0.1 (conception actée 12/06/2026). À ratifier au REGISTRE §17 (`OAI-1..OAI-9`, prolonge `IMP-13`).
Cadrage des décisions : session « OAI / Être source » (arbitrages Xavier). Implémentation lots
OAI-O1..O4.*
