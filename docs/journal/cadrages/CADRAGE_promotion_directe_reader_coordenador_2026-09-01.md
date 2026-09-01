# CADRAGE — Passage direct lecteur·rice → coordination (biblios en collectif horizontal)

**Date** : 2026-09-01
**Statut** : évaluation préalable — **aucune décision prise, aucune ligne de code écrite**
**Demande** : évaluer les besoins, la portée et les conséquences concrètes sur la coordination d'une
bibliothèque d'une nouvelle option de gestion : la promotion directe `reader` → `coordenador`,
pensée pour les biblios qui fonctionnent en **collectif horizontal** (cas type : BTL).
**Rattachement** : `spec-gouvernance-roles.md` v1.4.1 (candidate v1.5 si l'option est actée) ;
registre §GOUV (`GOUV-1` à `GOUV-10` posés le 26/08/2026, suite disponible à partir de `GOUV-11`).

> Ce document est une **trace** au sens de l'INDEX du corpus : il prépare une décision, il n'en
> prend aucune. Sur un conflit avec le registre ou la spec gouvernance, ceux-ci font foi.

---

## 1. Le besoin : d'où vient la demande

### 1.1. Le décalage entre le modèle et la réalité de BTL

Le modèle AnarBib connaît trois rôles locaux (`reader`, `librarian`, `coordenador`) et une
échelle : on entre dans l'équipe comme `librarian`, on passe éventuellement à la coordination
ensuite. La spec gouvernance affirme pourtant que **les rôles ne sont pas des grades** (P1) : ce
sont des fonctions déléguées par le collectif, révocables, en rotation.

Or dans un collectif horizontal comme BTL, la décision politique typique n'est pas « untel devient
bibliothécaire, on verra plus tard pour la coordination » : c'est **« cette personne rejoint le
collectif »**, et le collectif partage la coordination. L'échelle du logiciel impose alors un état
intermédiaire (`librarian`) qui ne correspond à **aucune réalité du groupe** — un grade de
passage, précisément ce que P1 récuse.

### 1.2. Le coût concret du circuit actuel

Pour exécuter dans le SIGB une seule décision d'AG (« X rejoint le collectif, donc la
coordination »), il faut aujourd'hui **deux circuits successifs** :

| Étape | Circuit | Gestes | Personnes impliquées |
|---|---|---|---|
| `reader` → `librarian` | invitation collégiale **ou** promotion directe (voir §2.3) | 3 (proposer, endosser, accepter) ou 1 | 3 ou 1 |
| `librarian` → `coordenador` | promotion collégiale (obligatoire depuis le 26/08/2026) | 3 (proposer, ratifier, accepter) | 3 |

Soit au mieux 4 gestes, au pire 6, étalés sur plusieurs jours (chaque invitation expire à 30
jours, les gens ne se connectent pas tous les jours), avec **deux vagues de notifications** et deux
acceptations demandées à la même personne pour une seule décision du collectif. C'est de la
friction pure : le collectif a déjà décidé (P8 — le SIGB ne modélise pas l'AG, il exécute), et le
logiciel lui fait exécuter sa décision en deux fois.

### 1.3. Ce que le besoin n'est pas

Le besoin n'est **pas** d'affaiblir la collégialité. La promotion collégiale
(proposition → ratification → acceptation) vient d'être conquise sur l'ancienne promotion
unilatérale (v1.4 de la spec, 26/08/2026) ; personne ne demande à revenir en arrière. Le besoin
est de **raccourcir l'échelle, pas les consentements**.

---

## 2. État des lieux : ce qui existe déjà (vérifié en prod le 01/09/2026)

### 2.1. Le garde-fou qu'il s'agirait d'assouplir

Le saut `reader` → `coordenador` est aujourd'hui **explicitement interdit**, à deux endroits de
`fn_team_propose_invitation` / `fn_team_accept_invitation` (migration `20260826120000`) :

- à la proposition : `precondition_failed: target must be active librarian first` ;
- revérifié à l'acceptation (la personne a pu être retirée de l'équipe entre-temps).

Le commentaire de la migration dit son origine : « précondition **héritée** de
`fn_team_promote_to_coordenador` §5 ». C'est un héritage d'implémentation, **pas un principe** de
la spec — aucun des principes P1–P8 n'exige une échelle progressive ; P2 exige la cooptation, qui
est ailleurs (le circuit collégial).

### 2.2. La tuyauterie collégiale est en place et généralisée

Le circuit invitation (`library_team_invitations` + ratifications) gère déjà **les deux rôles**
(`librarian` et `coordenador`), avec :

- quorum : `coordenador_seul` ⇒ 1 endossement ; moins de 2 staff actifs (hors personne visée) ⇒ 1 ;
  sinon 2 (`cosignature`, le mode de toutes les biblios actuelles) ;
- consentement obligatoire de la personne visée (elle accepte, elle ne ratifie pas) ;
- péremption à 30 jours (cron quotidien `anarbib-team-invitations-expire`) ;
- traçage transverse des propositions de coordination (`fn_log_cross_library_action`) ;
- gabarits mail à deux rôles (migration `20260826130000`) ;
- droit de proposition pour l'admin réseau, cas `coordenador` seulement (migration
  `20260826160000`, rattrapage d'une biblio sans coordination).

**Conséquence de cadrage** : l'option demandée n'exige aucun nouvel appareil. C'est un
**assouplissement de précondition** dans un circuit existant, pas une construction.

### 2.3. Deux asymétries existantes qui éclairent la discussion

1. **La montée courte existe déjà… en unilatéral.** `fn_team_promote_to_librarian` (T1 directe)
   est toujours vivante : un·e coordenador·a **seul·e** fait d'un·e reader un·e librarian en un
   clic, sans ratification ni acceptation. Autrement dit : le chemin rapide actuel est *moins*
   collégial que ce que la présente option propose. L'incohérence T1 (relevée mais non traitée
   lors de la v1.4) mérite d'être posée dans la même discussion (→ Q3, §6).
2. **La descente directe est permise.** `fn_team_self_demote` accepte `p_target_role = 'reader'` :
   un·e coordenador·a peut « passer la main » directement jusqu'à reader. L'échelle n'est donc
   obligatoire **que dans le sens montant** — dissymétrie difficile à justifier politiquement si
   l'on tient que les rôles sont des fonctions et non des grades.

### 2.4. État des biblios en prod (au 01/09/2026)

| Biblio | governance_mode | team_admission_mode | Coord. actifs | Librarians | Readers actifs | Validation lecteur |
|---|---|---|---|---|---|---|
| BLMF | full_governance | cosignature | 3 | 3 | 3 | none |
| **BTL** | full_governance | cosignature | **3** | 1 | 1 | présentielle |
| MLEG | full_governance | cosignature | **1** | 0 | 0 | présentielle |
| blmf-teste | full_governance | cosignature | 5 | 0 | 1 | présentielle |

À noter :

- **BTL a déjà 3 coordinateur·rices** : le quorum de cosignature (2) y est atteignable sans
  bootstrap. L'option n'y créerait pas de situation de décision solitaire.
- **MLEG est le cas sensible** : 1 seule coordinatrice ⇒ règle de bootstrap ⇒ 1 endossement
  suffit. Là, un saut direct reader → coordenador tiendrait à **une proposition d'une seule
  personne + l'acceptation de l'intéressé·e** (voir §4.3).
- `governance_mode` existe en colonne mais **n'est appliqué par aucune RPC** (l'activation par
  mode prévue au §1.4 de la spec gouvernance n'a jamais été câblée ; toutes les biblios sont en
  `full_governance`). Si l'on voulait adosser l'option à un « profil de gouvernance », il faudrait
  d'abord livrer ce chantier-là — disproportionné (voir §5.2).
- `team_admission_mode` n'a **pas d'UI de réglage** : il se change en base. Précédent utile pour
  décider du niveau d'outillage de la nouvelle option (→ Q2, §6).

---

## 3. Portée de l'option proposée

### 3.1. Définition proposée

> Une bibliothèque peut autoriser que la **proposition collégiale de coordination**
> (`fn_team_propose_invitation` avec `p_role = 'coordenador'`) vise aussi un·e **reader
> actif·ve** de la biblio, et plus seulement un·e librarian actif·ve. **Tout le reste du circuit
> est inchangé** : quorum de ratification selon `team_admission_mode`, acceptation obligatoire par
> la personne concernée, péremption, notifications, audit, traçage réseau.

### 3.2. Ce que l'option n'est pas (périmètre négatif)

- **Pas** une promotion unilatérale : le circuit proposition → ratification → acceptation
  s'applique intégralement. (L'ancienne `fn_team_promote_to_coordenador` reste condamnée.)
- **Pas** un nouveau rôle, ni une modification des pouvoirs du `coordenador`.
- **Pas** un changement des quorums ni du `team_admission_mode`.
- **Pas** une entrée directe depuis l'extérieur : la personne doit être **reader actif·ve de la
  biblio** (recommandation, → Q4). Quelqu'un d'extérieur passe d'abord par l'inscription (et la
  validation présentielle là où elle existe).
- **Pas** une modélisation du fonctionnement horizontal : le SIGB continue de ne pas savoir ce
  qu'est une AG (P8). L'option ne fait que réduire le nombre de gestes nécessaires pour exécuter
  une décision prise ailleurs.

### 3.3. Champ d'application : trois options d'activation

| Option | Description | Pour | Contre |
|---|---|---|---|
| **A. Règle réseau uniforme** | le saut devient possible partout | simple ; la collégialité protège déjà ; une biblio « à échelle » peut simplement ne jamais proposer de saut | impose un défaut politique à des collectifs qui tiennent à la progressivité ; un·e coordenador pressé·e peut sauter l'étape « par facilité » là où le collectif n'a rien décidé de tel |
| **B. Réglage par biblio** (recommandé) | booléen `libraries.allow_direct_coordenador` (nom à fixer), défaut `false` | souveraineté locale (P7) : chaque collectif inscrit **sa** doctrine dans l'outil ; réversible ; sans effet sur les biblios existantes tant qu'elles n'activent pas | un réglage de plus à documenter ; question du geste d'activation (→ Q2) |
| **C. Adossement à `governance_mode`** | réservé à un futur profil « collectif horizontal » | conceptuellement élégant | exige de livrer d'abord l'application effective de `governance_mode` par les RPC — chantier dormant depuis mai, sans rapport d'échelle avec le besoin |

**Recommandation** : **B**. Le défaut `false` fait que la mise en production est un non-événement
pour BLMF et MLEG ; BTL (ou toute biblio qui se reconnaît dans le fonctionnement horizontal)
active après décision de son collectif.

---

## 4. Conséquences concrètes sur la coordination d'une biblio

### 4.1. Ce que la personne obtient d'un coup — le point politique à assumer

C'est **la vraie conséquence** de l'option, à dire clairement au collectif qui l'active.
Aujourd'hui, l'étape `librarian` sert de **sas de fait** : la personne exerce d'abord le
quotidien (circulation, inscriptions, catalogue, et — déjà — l'accès aux données personnelles des
lecteur·rices), avant de recevoir les pouvoirs de configuration. Avec le saut direct, une personne
qui n'a jamais exercé dans l'outil reçoit **en un seul geste** :

- l'accès aux **données personnelles** des lecteur·rices (que `librarian` donne déjà, mais
  qu'elle n'avait pas comme reader) ;
- l'identité publique de la biblio (`library_commons` : nom, logo, contact) ;
- la configuration (politiques de prêt, règlement, cotisations) ;
- la **gestion de l'équipe** : proposer et ratifier des invitations, suspendre, demander une
  exclusion (carence 7 j), y compris à l'égard de gens plus anciens qu'elle dans l'outil.

Aucun de ces pouvoirs n'est nouveau ni élargi — mais leur **acquisition simultanée et sans
période d'exercice préalable** est le prix du raccourci. C'est cohérent avec un collectif où la
confiance se construit hors logiciel (l'AG coopte, le SIGB exécute) ; c'est incohérent avec un
fonctionnement où l'échelle *est* le mécanisme de confiance. D'où l'opt-in par biblio.

### 4.2. Ce qui ne change pas (garde-fous conservés)

- **Quorum** : inchangé. Détail vérifié : le décompte du staff exclut la personne visée
  (`user_id <> v_invited`) — pour un·e reader ce filtre est neutre (elle n'est pas staff), le
  calcul reste correct sans modification.
- **Consentement** : l'intéressé·e accepte ou rien ne se passe (P3 symétrique).
- **Transparence** : audit `promoted_to_coordenador` (P5), notifications à la personne et à toute
  la coordination (P6), traçage `team_promote_to_coordenador` dans le log transverse.
- **Rotation et retrait** : self-demote (y compris directement vers `reader`), suspension,
  exclusion avec carence — tout s'applique à l'identique au nouveau ou à la nouvelle coordenador·a.
- **Souveraineté locale** (P7) : aucun effet inter-biblios.

### 4.3. Points d'attention identifiés

1. **Biblio à coordination unique (MLEG aujourd'hui)** : bootstrap ⇒ 1 endossement suffit ⇒ le
   saut direct = *une* proposition + l'acceptation. C'est déjà vrai pour l'accueil `librarian` et
   pour la promotion d'un·e librarian existant·e ; le saut ne crée pas la situation, il en élargit
   la portée. À trancher : soit on l'assume (c'est le sens du mode bootstrap), soit on exige
   `staff actif ≥ 2` pour le saut direct (→ Q5). Noter que l'option B rend le point théorique tant
   qu'une biblio à coordination unique n'active pas le réglage.
2. **Statut du reader** : exiger `status = 'active'` strictement. Leçon de la faille BLMF
   (validation présentielle) : tout garde-fou d'AnarBib qui filtre sur le statut doit viser
   `active`, pas l'absence de `pending`. Une inscription non validée ne doit pas pouvoir être
   propulsée à la coordination.
3. **Rôle exclusif (doctrine Q15/v1.2)** : à l'acceptation, la branche `coordenador` de
   `fn_team_accept_invitation` ferme aujourd'hui la ligne `librarian`. Elle devra fermer **la
   ligne active inférieure quelle qu'elle soit** (`reader` ou `librarian`), avec l'entrée d'audit
   `removal_completed` correspondante — même mécanique que la branche accueil, à généraliser.
4. **Trace fidèle du saut** : l'entrée d'audit et le log transverse doivent dire d'où vient la
   personne (`metadata.from_role = 'reader'`). Le CHECK de `library_membership_audit` n'a pas
   besoin de changer.
5. **Redescente** : une personne venue directement de `reader` qui « passe la main » atterrit par
   défaut sur `librarian` — un rôle qu'elle n'a jamais exercé. Non bloquant (elle peut viser
   `reader` directement), mais l'UI de self-demote pourrait proposer `reader` par défaut pour ces
   profils. Confort, pas garde-fou.
6. **Textes des mails et de l'UI** : les gabarits disent « une autre personne de l'équipe » ; pour
   un·e reader visé·e, certains libellés (« déjà membre de l'équipe », préconditions affichées)
   sont à relire. Dix locales à produire d'emblée (doctrine Communs / DOC-I18N-1 au registre).
7. **Admin réseau** : la garde de `20260826160000` (l'admin réseau peut proposer une coordination)
   s'appliquerait mécaniquement au saut direct **si la biblio a activé le réglage**. Cohérent avec
   sa raison d'être (rattraper une biblio sans coordination) ; à mentionner dans la spec pour que
   ce soit un choix et non un effet de bord.

### 4.4. Ce que l'option ne règle pas

- L'incohérence T1 (promotion directe unilatérale `reader` → `librarian` toujours possible) reste
  entière — et devient plus visible par contraste (→ Q3).
- Le fait qu'un collectif horizontal doive quand même désigner *qui* clique : le SIGB continue
  d'exiger des gestes individuels identifiés. C'est un choix assumé (P8), pas un défaut.

---

## 5. Esquisse d'implémentation et effort (pour dimensionner, pas pour agir)

### 5.1. Périmètre technique estimé

| Couche | Contenu | Volume |
|---|---|---|
| **Migration SQL** | colonne `libraries.allow_direct_coordenador` (défaut false) + assouplissement de la précondition dans `fn_team_propose_invitation` (branche `coordenador` : librarian actif **ou** reader actif si réglage) + généralisation de la fermeture de ligne inférieure et revérification de précondition dans `fn_team_accept_invitation` + metadata `from_role` | 1 migration + miroir repo + rollback |
| **Tests SQL** | cas : saut autorisé/refusé selon réglage, reader `pending` refusé, fermeture de la ligne reader, quorum inchangé | banc `tests/sql` existant (stub cron en place depuis le 31/08) |
| **Frontend** | `roles.js` (action `propose_coordenador` offerte sur une cible reader si réglage actif), `TeamActionModal`/`LeitoresPanel` (point d'entrée), libellés | petit |
| **i18n** | ~4–6 clés × 10 locales, produites d'emblée | mécanique |
| **Docs** | spec-gouvernance-roles → v1.5 (§3.1, §5, §6, §15) ; registre §GOUV (décision + arbitrages Q1–Q5) ; guides gouvernance ×10 si le réglage devient visible des équipes | le vrai coût |
| **UI de réglage** | optionnelle en v1 : précédent `team_admission_mode` = réglage en base, documenté | 0 en v1 |

**Estimation globale** : petit chantier — une journée de dev + tests, la tuyauterie collégiale
existant déjà ; le gros du travail est **documentaire et politique** (spec, registre, guides,
décision des collectifs).

### 5.2. Fausse pistes écartées

- **Passer par `governance_mode`** : exigerait de câbler enfin l'activation par mode dans toutes
  les RPC de gouvernance — chantier dormant sans commune mesure avec le besoin (§3.3, option C).
- **Créer un rôle « membre du collectif »** : multiplierait les rôles pour exprimer une nuance qui
  tient dans une précondition. Contraire à la réduction 4 → 3 rôles déjà actée.
- **Court-circuiter le circuit d'invitation** (promotion directe « parce que collectif
  horizontal ») : reviendrait sur la v1.4, conquise il y a une semaine. Exclu d'office.

---

## 6. Questions à trancher avant d'agir

| # | Question | Recommandation (à confirmer) |
|---|---|---|
| **Q1** | Règle réseau ou option par biblio ? | Option par biblio, défaut désactivé (§3.3 B) |
| **Q2** | Qui active le réglage, et comment ? | v1 : en base, sur demande du collectif à la coordination technique (précédent `team_admission_mode`) ; UI de réglage seulement si la demande se répète |
| **Q3** | Traiter dans le même geste l'incohérence T1 (promotion directe unilatérale reader → librarian) ? | Chantier séparé mais **posé au registre en même temps** : la même discussion politique couvre les deux, autant ne convoquer l'AG qu'une fois |
| **Q4** | La cible doit-elle être reader actif·ve de la biblio, ou peut-on viser une personne sans aucune adhésion ? | Reader actif·ve requis : l'ancrage local d'abord ; l'extérieur passe par l'inscription et la validation présentielle le cas échéant |
| **Q5** | Exiger `staff ≥ 2` pour un saut direct (neutraliser le bootstrap à 1 endossement) ? | Non en v1 : le bootstrap est une règle assumée du circuit, et l'opt-in par biblio suffit ; à réévaluer si une biblio à coordination unique active le réglage |

---

## 7. Synthèse et recommandation

**Faisabilité** : bonne. L'option est un assouplissement de précondition dans un circuit collégial
livré, testé et en production depuis le 26/08/2026 — pas une construction nouvelle.

**Cohérence politique** : l'échelle progressive n'est adossée à aucun principe de la spec ; elle
est un héritage d'implémentation, déjà contredit par la promotion directe T1 (unilatérale !) et
par la redescente directe autorisée. Le saut **collégial** reader → coordenador est plus fidèle à
P1/P2/P8 que l'état actuel, pour les collectifs qui fonctionnent ainsi.

**Le point à assumer** : la disparition du sas d'exercice préalable — la personne reçoit d'un coup
données personnelles, configuration et gestion d'équipe. C'est précisément pourquoi l'option doit
être un **choix explicite de chaque collectif** (opt-in par biblio, défaut désactivé), et non un
nouveau comportement par défaut du réseau.

**Prochain pas suggéré** (hors périmètre de ce cadrage) : trancher Q1–Q5 — dont la partie qui
appartient à BTL (veulent-iels réellement cette option, et avec quels mots dans leur langue de
travail ?) —, inscrire la décision au registre §GOUV, puis seulement ouvrir le chantier (spec
v1.5 + migration).
