# CADRAGE — Récolement / Veille du commun

| | |
|---|---|
| **Genre** | Cadrage *forward* — document de débat **pour Bologne** (FICEDL, sept. 2026). |
| **Statut** | 🔵 **Non implémenté.** Aucune ligne de code ; ce document fixe la doctrine *avant* le chantier. |
| **Date** | 19 juin 2026. |
| **Origine** | Triage des « specs absentes » de l'Audit 360° (19/06) : `récolement` est vraiment vierge (zéro table/RPC/page) → on le **cadre** avant tout code. |
| **Décisions prises** | Avec Xavier, 19/06/2026 (cf. §4). Les **bornes ouvertes** (§7) restent à trancher en collectif. |
| **Voisins** | scanner d'exemplaire (`?ex=id`) · `exemplares` (tombo) · PWA · `spec-flux-partage-numerique` (offre au réseau) · `spec-historico-retencao-lectrice` (minimisation). |

> **Note de vocabulaire.** « Récolement » est un terme archivistique/administratif : vérifier le stock, traquer le manque. Pour une biblio militante c'est un contresens. On ancre la doctrine sous **« veille du commun »** : *qu'avons-nous, en quel état, où* — au service du **soin**, pas du contrôle. (On garde « récolement » comme terme de recherche.)

---

## 1. Objet

Savoir ce que le commun détient, dans quel état — pour en **prendre soin** (réparer, relier, désherber) et **mieux partager** dans le réseau.

**Le manque actuel (vérifié au baseline).** Aucun état d'inventaire sur l'exemplaire. Les statuts `perdido`/`danificado` existent mais sur les **lignes de prêt/PEB** (`item_status`) — *un livre perdu pendant un emprunt, avec un·e emprunteur·euse attaché·e*. Rien au niveau de l'exemplaire en tant qu'objet du commun. `last_seen_at` n'existe que sur `network_administrators` (détection d'inactivité douce).

## 2. Le retournement : recensement-*soin*, pas inventaire-*contrôle*

Dans une biblio marchande : le livre est un actif, le manquant une perte ou un vol. Chez AnarBib, le livre est un **commun en circulation** — économie du don où les bouquins **vagabondent légitimement** (prêtés de la main à la main, emportés en manif, offerts). Un exemplaire « non vu » n'est **pas une déviance à punir**, c'est une **information sur la façon dont le commun vit**.

## 3. Le joyau : objets, jamais lectrices

Le couplage à **interdire by design** : **veille ↔ lecteur·rice**. Un système carcéral corrélerait « manquant » avec « qui l'avait en dernier » → soupçon, ardoise, fichage. **La veille touche les exemplaires, JAMAIS les personnes** (minimisation, cohérent `spec-historico-retencao-lectrice`).

Étayé par le schéma : le « non vu » de la veille **ne doit pas** être confondu avec le `perdido` de prêt (contextuel à une transaction, avec emprunteur·euse). **Deux concepts, jamais fusionnés** : le `perdido` a une personne attachée ; le « non vu » est un constat d'étagère **sans personne**.

## 4. Décisions prises (19/06)

**D1 — Déclenchement hybride (passif + campagne).**
- **Passif (gratuit)** : chaque **retour de prêt / consultation** « voit » l'exemplaire → rafraîchit `exemplares.last_seen_at` (patron `network_administrators.last_seen_at`). Le catalogue *se récole tout seul* au fil de la circulation.
- **Actif (le scanner existe)** : on lance une **campagne**, on marche les rayons en scannant l'étiquette `?ex=id` → l'exemplaire est « vu ». Non-scannés en fin de balayage = « non vus ». Mobile-first (PWA), **file d'attente hors-ligne** (scanner sans wifi, sync au retour).

**D2 — Le « non vu » = drapeau doux, patient, auto-effaçable.**
- « *Non vu lors de la veille AAAA* », **daté, sans accusation**. **S'efface seul** si l'objet réapparaît (prochain retour/scan). Le commun est **patient** : le livre peut revenir.
- **Jamais** de bascule automatique en « perdu ». L'escalade vers « égaré » reste une **délibération humaine** (motif) — et même là, *le commun a perdu la trace d'un objet*, pas *quelqu'un a volé*.

**D3 — Soin au sens plein : présence + état physique.**
- L'exemplaire porte un **état** (`bon` / `à réparer` / `à relier` / `à désherber`) qui alimente une **file de soin** (ce qui demande attention).
- **Désherbage = le geste grave de la veille** (retrait du commun) :
  - **Délibéré**, jamais un clic unilatéral de bibliothécaire (motif + collégialité) ;
  - **Offert au réseau d'abord** : avant tout retrait, l'objet est **proposé aux autres biblios** (économie du don, anti-gaspillage ; raccord `spec-flux-partage-numerique` / catalogue collectif). Le tract qu'une biblio désherbe est un trésor pour une autre ;
  - **Prudence accrue** pour le **matériel gris militant rare** (la mémoire que le réseau protège) : ne pas laisser le désherbage détruire une trace rare.

## 5. Le fil rouge des trois chantiers

> **Dans AnarBib, retirer du commun est toujours le geste solennel.**
> Accueillir un·e camarade = léger (co-sign×2) ; le **retirer** = lourd (motif/carence/contradictoire). Garder un livre = passif ; le **désherber** = délibéré + offert au réseau d'abord. **L'ajout est facile, le retrait est grave** — même éthique pour les personnes et pour les œuvres. (Cohérent `CADRAGE_accueil_equipe` : l'asymétrie accueil/révocation.)

## 6. Esquisse technique (v1, *forward* — rien n'est codé)

- `exemplares.last_seen_at` (timestamptz) + `last_seen_via` (retour / consultation / scan campagne) — rafraîchi passivement.
- `exemplares.condition_status` (`bom` / `a_reparar` / `a_encadernar` / `a_desbastar`) + éventuel motif/horodatage.
- Table `inventory_campaigns` (biblio, périmètre = totalité / par localisation / par collection, `started_by/at`, `closed_at`, `status`).
- RPC `fn_record_inventory_scan(campaign, exemplar)` **idempotent** ; rapport de réconciliation **vus / non-vus / inattendus** (scanné hors périmètre ou tombo inconnu).
- **Désherbage** = flux distinct : motif + collégialité + **étape « offrir au réseau »** (liste les biblios susceptibles d'être intéressées avant retrait) + retrait effectif tracé.
- **RLS stricte par biblio** (le réseau n'audite pas les étagères d'une biblio) ; **agrégat opt-in** vers le catalogue collectif (« le réseau détient N exemplaires de X, en tel état »).
- Notifications éventuelles (file de soin, offre de désherbage au réseau) **bicanales localisées**.

## 7. Bornes ouvertes — à trancher à Bologne

- **Collégialité du désherbage** : co-signature ? assemblée ? aligné sur le mode d'admission de l'équipe (`team_admission_mode`) ou règle propre ?
- **« Offrir au réseau » avant désherbage** : obligatoire (gate dur) ou recommandé (opt-out) ? délai d'attente avant retrait effectif ?
- **Seuil « non vu depuis X »** : à partir de quand un exemplaire jamais re-circulé est-il signalé (le passif seul ne « voit » jamais un livre jamais emprunté) ? 6 mois ? campagne annuelle conseillée ?
- **Agrégat fédéral** : opt-in par biblio, et quel niveau de détail exposé (présence/état) sans surveillance ?
- **Vocabulaire d'état** : liste fermée définitive (`bom`/`a_reparar`/`a_encadernar`/`a_desbastar`) + faut-il « à numériser » (raccord ressources numériques / partage) ?

## 8. Précédents AnarBib mobilisés

`network_administrators.last_seen_at` (signal passif → statut doux) · scanner d'exemplaire (`?ex=id`, [[scanner-architecture]]) · PWA (socle hors-ligne) · `spec-flux-partage-numerique` (offre au réseau / matériel gris) · `spec-historico-retencao-lectrice` (minimisation, anti-corrélation lecteur) · `CADRAGE_accueil_equipe` (fil rouge : retrait du commun = geste grave) · doctrine « note obligatoire » (`paquetA1_cancel_note_required`, pour le motif de désherbage).

---

*Cadrage forward produit le 19/06/2026 — fixe la doctrine de la veille du commun avant tout code, pour débat à Bologne. La feature reste non construite.*
