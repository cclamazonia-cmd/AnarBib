# DÉCISION — EA-01 : porte d'entrée du Painel (logique tâche vs objet)

- **Date** : 2026-05-30
- **Chantier** : #PAINEL (chantier-cadre, audit du 26/05/2026)
- **Écart traité** : EA-01 — « Le bon modèle n'est pas généralisé » (majeur)
- **Source** : `CHANTIER_audit_systematique_painel_2026-05-26.docx`, §2.1 / §4
- **Statut** : **ACTÉ** (volets 1 et 2) — volet 3 reporté

---

## 1. Le constat (rappel de l'audit)

Le Painel est organisé **par objets de base de données** : un onglet par table
(Reservas, Consultas, Empréstimos, Empréstimos groupés…). Un seul onglet,
**Trabalho do dia**, raisonne **par tâches** — « ce que la personne a à faire
aujourd'hui ». L'audit en fait sa « référence positive » : il prouve que
l'équipe sait concevoir tâche-centré.

Le problème central : huit onglets sur neuf demandent à la personne de savoir,
avant de cliquer, si ce qu'elle cherche est une « réservation » ou une
« consultation » au sens du SIGB — **un vocabulaire de spécialiste imposé à des
non-spécialistes**, alors que le public d'AnarBib est précisément
non-spécialiste.

EA-01 pose donc une question **stratégique**, pas un bug :
> Fait-on de Trabalho do dia la porte d'entrée par défaut du Painel, les
> onglets-objet devenant des vues de détail consultées au besoin ?

---

## 2. La tension politique

L'arbitrage n'est pas seulement ergonomique, il est politique — d'où sa
qualification d'« arbitrage politique » et son traitement collectif.

**En faveur** d'une synthèse-tâche en façade :
- Réponse directe au constat central : une liste « voici ce qu'il y a à faire »
  parle humain, abaisse la barrière pour des bénévoles tournants.
- Aligné sur la mission d'AnarBib (outil pour non-spécialistes).
- Le message « ✓ Tudo em dia » quand il n'y a rien à faire est un geste
  **anti-productiviste** : l'outil dit *quand on peut souffler*, il ne harcèle pas.

**Réserves** :
- Une to-do list obligatoire en façade peut se lire comme prescriptive, voire
  managériale (« le système m'assigne du travail »), ce qui frotte avec
  l'horizontalité.
- Le tâche-centré **masque** le modèle sous-jacent ; une pédagogie libertaire
  valorise la lisibilité du système, pas seulement la commodité. Reléguer les
  onglets-objet au rang de « détails » peut désempouvoir qui veut *comprendre*
  l'outil, pas seulement l'exécuter.

**Position retenue** : la porte d'entrée tâche est adoptée pour son gain
d'accessibilité, **sans supprimer ni masquer** les onglets-objet — qui restent
pleinement accessibles. La lisibilité du modèle est préservée ; seule la
*hiérarchie de lecture* est posée (vue d'ensemble d'abord, détails au besoin).
La généralisation plus poussée du modèle tâche (volet 3) reste soumise à une
validation collective ultérieure, conformément à l'esprit de l'audit
(« aucune décision n'est imposée »).

---

## 3. Décision

Trois volets étaient possibles ; **les volets 1 et 2 sont actés**, le volet 3
est explicitement reporté.

### Volet 1 — Ratification (la porte d'entrée est déjà en place)

Constat de code (post-refactor E.1/E.3) :
- `PanelPage.jsx` ouvre par défaut sur `useState('trabalho-do-dia')`.
- Trabalho do dia est toujours **premier** dans la barre et **toujours
  disponible** (garde-fou de redirection si l'onglet actif devient indisponible).
- Le hero pointe dessus (« ✓ Tudo em dia → Ver a síntese » / « X ações hoje »).

→ Le volet strict d'EA-01 (« Trabalho do dia comme porte d'entrée ») est
**déjà tranché « oui » en code**. La présente décision le **ratifie**
formellement comme choix de conception assumé.

### Volet 2 — Pas structurel léger (livré avec cette décision)

Marquer visuellement la hiérarchie « vue d'ensemble → détails » sans rien
retirer :
- Séparateur dans la barre d'onglets **après** Trabalho do dia
  (`.ab-painel-tab-divider`), distinguant la vue d'ensemble des vues de détail.
- Responsive (barre horizontale et colonne ≤ 640px).
- Aucun onglet supprimé, aucun changement de comportement, **réversible**.

Implémentation : `PanelPage.jsx` (Fragment + élément séparateur dans le `map`
des onglets) + `PanelPage.css` (règles `.ab-painel-tab-divider`).

### Volet 3 — Refonte tâche-centrée (REPORTÉ)

Généraliser le modèle tâche à l'ensemble du Painel (actions inline depuis la
synthèse, visibilité « qui a fait quoi », onglets-objet réduits à de vrais
détails) est une **re-architecture de moyen terme**. Elle recoupe le chantier D
(traçabilité / horizontalité, EA-10/EA-12) et mérite **son propre cadrage et une
validation collective** — elle n'est pas tranchée ici.

---

## 4. Ce qui n'est PAS fait (pour mémoire)

- Aucune généralisation du modèle tâche aux onglets-objet (volet 3).
- Aucune suppression / masquage d'onglet.
- Aucune persistance de l'onglet actif (le Painel revient sur la synthèse au
  rechargement — comportement conservé, cohérent avec « la synthèse est le foyer »).

---

## 5. Suite

- EA-01 → **Acquis (volets 1+2)** au backlog.
- Le volet 3 reste au backlog comme chantier distinct de moyen terme, à cadrer
  et arbitrer collectivement (lien avec chantier D).
