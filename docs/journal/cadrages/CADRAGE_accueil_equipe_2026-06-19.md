# CADRAGE — Accueil dans l'équipe (cooptation locale)

| | |
|---|---|
| **Genre** | Cadrage *forward* — document de débat **pour Bologne** (FICEDL, sept. 2026). |
| **Statut** | 🔵 **Non implémenté.** Aucune ligne de code ; ce document fixe la doctrine *avant* le chantier. |
| **Date** | 19 juin 2026. |
| **Origine** | Triage des « specs absentes » de l'Audit 360° (19/06) : `invitation-équipe` n'est pas du code livré-sans-doctrine, c'est une **feature non construite** → on la **cadre** avant de la coder. |
| **Décisions prises** | Avec Xavier, 19/06/2026 (cf. §3–4). Les **bornes ouvertes** (§6) restent à trancher en collectif. |
| **Voisins à ne pas confondre** | ONBO (constitution d'une biblio) · ONBO-Q13 (transfert du mandat coordenador) · #111 (cooptation d'**admins réseau**, vote unanime) · promotion interne (`TeamPanel` → `fn_team_promote_*`) · `self_demote` (départ volontaire). |

> **Note de vocabulaire.** « Invitation » sonne descendant (un hôte invite un convive). Ce qu'on décrit est un **accueil / une cooptation** : ce n'est pas *une personne* qui invite, c'est **le collectif qui admet**. On garde « invitation » comme terme d'usage (le lien, l'e-mail), mais la doctrine s'ancre sous **« accueil dans l'équipe »**.

---

## 1. Objet

Donner une **porte d'entrée directe** dans l'équipe d'une bibliothèque pour une personne qu'on veut y accueillir — qu'elle ait déjà un compte AnarBib (lectrice ailleurs) ou non.

**Le manque actuel.** On n'entre dans une équipe que par **deux chemins** : fondateur·rice via ONBO, ou lecteur·rice **déjà inscrit·e ici** qu'on **promeut** (`TeamPanel`). Aucun chemin « on te veut dans l'équipe » pour quelqu'un d'extérieur. La mécanique (token, lien, e-mail) est triviale ; **le sujet politique est ailleurs**.

## 2. Le vrai sujet : anti-capture, pas anti-intrusion

Un SIGB marchand protège contre l'**accès non autorisé**. Une biblio horizontale court un autre risque : **une personne qui accrète le contrôle** en cooptant ses allié·es jusqu'à la majorité. La règle d'admission n'est donc **pas un verrou de sécurité** — c'est un **dispositif de distribution du pouvoir**. (C'est déjà la logique de #111 : unanimité pour les admins réseau.)

**Principe directeur : le poids de la cooptation croît avec la portée du mandat.**

> `librarian` accueilli·e (léger) → `coordenador` promu·e/transféré·e (acte interne lourd) → **admin réseau coopté·e à l'unanimité** (#111).

## 3. Décisions prises (19/06)

**D1 — Cooptation paramétrable, défaut co-signature×2.**
- Chaque biblio fixe son `team_admission_mode` ∈ { `coordenador_seul`, `cosignature`, `assemblee` }. **Défaut = `cosignature` (2 endosseurs).**
- **Endossement** : 2 mandaté·es **distinct·es** doivent endosser. Le/la proposeur·euse compte pour 1 → il faut **1 co-signature**.
- **Bootstrap (N=1)** : une équipe d'une seule personne **invite seule** (personne avec qui colluder ; déjà adoubée par ONBO). La porte collégiale s'active **dès qu'on est ≥ 2**. *(Seuil = 2 : un petit collectif de 2 joue déjà le jeu — la collégialité est démocratisée, pas réservée aux grosses biblios.)*
- **Méta-règle** : changer le mode **suit le mode en vigueur** — jamais de desserrage unilatéral (doctrine du plafond ILL : « on durcit, on n'assouplit pas seul »). Le défaut étant le plus sûr, on opte vers `coordenador_seul` *explicitement et collégialement*.
- **Résidu d'échelle assumé** : à 8 membres, « 2 endosseurs » est faible face à la capture → c'est pourquoi c'est paramétrable (gros collectif → `assemblee`). Filet en attendant : **transparence + révocabilité**. On le documente franchement.

**D2 — Mandat = rôle révocable, ouvert.** L'accueil confie un **rôle** (`librarian`), sans terme ni mission imposée, **révocable à tout moment** (étend `self_demote` + suspension à carence). Pas de mandat-à-mission ni à-terme en v1 (réserve possible v2).

**D3 — Le coordenador ne s'invite pas.** L'accueil admet à **`librarian` uniquement**. Devenir `coordenador` reste un acte plus lourd, **déjà outillé** : promotion interne (`fn_team_promote_to_coordenador`) ou transfert de mandat (**ONBO-Q13**). Ça ferme la pire faille de capture (« j'invite un·e allié·e *directement* coordenador »).

**D4 — Qui propose : tout·e `librarian` actif·ve.** Horizontalité : le/la coordenador n'a pas le monopole de l'accueil. Proposeur·euse = 1 endosseur, + 1 co-signataire.

**D5 — Consentement symétrique + identité minimisée.** L'invité·e **accepte** (jamais enrôlé·e d'office) ; refus **gratuit et privé**. Accueil par `public_id` (U…, acceptation in-app, **zéro PII**) si la personne est déjà sur AnarBib ; sinon par e-mail + **lien signé TTL court** (→ EF `register` → adhésion).

**D6 — Transparence + audit.** Invitations en attente + trace des endossements **visibles de toute l'équipe** (pas de cooptation en coulisse). Table d'audit calquée sur `library_request_mandate_transfers` (précédent ONBO-Q13).

## 4. Doctrine de la révocation — l'asymétrie voulue

**Accueillir et exclure ne sont pas le même geste.** Exclure d'un collectif est grave et **instrumentalisable** (purge de faction, règlement de comptes). La procédure doit donc **faire sentir** cette gravité — pas seulement un compteur plus haut, une **expérience** plus solennelle. Quatre leviers, tous déjà dans l'ADN d'AnarBib :

1. **Carence** (délai avant effet) — *déjà prévue* : la Phase B2 de `TeamPanel` annonce « retraits **avec carence** ». Le temps suspendu fait la gravité et ouvre la désescalade.
2. **Motif obligatoire** — pas de purge silencieuse : justification écrite versée au registre (doctrine « note obligatoire à l'annulation », testée `paquetA1_cancel_note_required`). *Devoir nommer le pourquoi, c'est déjà peser.*
3. **Contradictoire** — la personne concernée est **notifiée et peut répondre** pendant la carence. Le droit d'être entendu·e, version horizontale : ce qui distingue une décision collective d'un bannissement.
4. **Seuil plus exigeant que l'admission** — admission = co-sign×2 ; révocation = **majorité de l'équipe** (assemblée pour les grosses biblios). *On entre à 2, on ne sort personne à 2.*

**Asymétrie fondatrice conservée :** `self_demote` reste **unilatéral et instantané**. *Rendre son propre mandat n'est jamais lourd ; l'arracher à un·e autre, toujours.*

| Geste | Règle | Poids |
|---|---|---|
| Accueillir (`librarian`) | co-signature×2 | léger, démocratisé |
| Retirer un mandat | majorité + **motif + carence + contradictoire** | **lourd, ressenti** |
| Partir soi-même (`self_demote`) | unilatéral, instantané | nul |

> Distinction utile à trancher : **suspension** (temporaire, pour désamorcer) vs **révocation** (définitive). La suspension pourrait être plus légère (carence + motif), la révocation définitive plus lourde (assemblée). À arbitrer (§6).

## 5. Esquisse technique (v1, *forward* — rien n'est codé)

- Table `library_team_invitations` : `invitee_email | invitee_public_id`, `role_propose` (=`librarian`), `proposed_by`, `endorsers[]`, `status` (pending / ready / accepted / declined / expired / revoked), `token`, `expires_at`, audit horodaté.
- Réglage `team_admission_mode` (par biblio) + son verrou méta (D1).
- RPC : `fn_propose_team_invitation` → `fn_ratify_team_invitation` (atteint le seuil → `ready`) → `fn_accept_team_invitation` (crée l'adhésion `librarian` active) ; `fn_revoke_team_invitation` ; `fn_decline_team_invitation`.
- Révocation d'un mandat = **flux distinct** (séparé de l'accueil) : motif obligatoire + carence + notification contradictoire + seuil majorité (raccord Phase B2 `TeamPanel`).
- Notifications **bicanales localisées** (e-mail 10 locales + in-app), comme la cotisation / #111.
- RLS : strictement **par biblio** (le réseau ne voit/valide pas l'équipe interne d'une biblio — souveraineté locale).

## 6. Bornes ouvertes — à trancher à Bologne

- **Dosage exact de la révocation** : quels leviers parmi carence / motif / contradictoire / seuil-majorité retient-on, et à quel niveau (majorité simple ? assemblée systématique pour les grosses biblios ?).
- **Suspension vs révocation** : deux actes distincts (suspension plus légère, révocation définitive plus lourde) ou un seul ?
- **Contradictoire formalisé** : délai de réponse, forme (note ? in-app ?), effet d'une contestation pendant la carence.
- **Résidu d'échelle** : faut-il un seuil *relatif* (majorité) plutôt qu'absolu (2) dès que l'équipe dépasse une taille, ou laisse-t-on le paramétrage (`assemblee`) gérer ?
- **Souveraineté locale vs visibilité réseau** : le réseau doit-il *voir* (sans valider) qui compose chaque équipe, au nom de la transparence fédérale ?

## 7. Précédents AnarBib mobilisés

#111 (cooptation unanime des admins réseau) · ONBO-Q13 (transfert de mandat + table d'audit) · `fn_team_*` / `TeamPanel` (gestion du roster + Phase B2 « retraits avec carence ») · `self_demote` (sortie unilatérale) · `paquetA1_cancel_note_required` (note obligatoire) · doctrine du plafond ILL (« durcir, jamais assouplir seul ») · `spec-gouvernance-roles` · `spec-assembleias`.

---

*Cadrage forward produit le 19/06/2026 — fixe la doctrine de l'accueil dans l'équipe avant tout code, pour débat à Bologne. La feature reste non construite.*
