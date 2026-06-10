---
Genre : trace
Statut : 🔵 historique
Décisions : incarne MULTI-* (REGISTRE §20) ; cite VALID-β1, VALID-γ1
Supersédé par : spec-multi-appartenance-lecteur (design) + REGISTRE_decisions §20 MULTI (arbitrages)
---

# Cadrage doctrinal — `spec-multi-appartenance-lecteur` (à venir)

> ⚠️ **Document de travail — historique (tamponné le 02/06/2026).** Le contenu normatif a gradué dans `spec-multi-appartenance-lecteur` (design — charpente v0.3) et `REGISTRE_decisions.md` §20 `MULTI` (arbitrages). **Ne pas utiliser comme source** : pour les décisions, le registre fait foi ; pour le design, la spec. Conservé comme trace du raisonnement du 31/05.

**Date** : 31/05/2026
**Statut** : 🔵 historique — voir le tampon ci-dessus
**Réfère à** : #CL.10 du méga-item conta, cahier Dunkerque §2.10
**Auteur·rice·s** : Xavier (CCLA) + Claude

---

## Objet du document

Ce document n'est **pas** la spec. C'est le cadrage doctrinal préalable :
les questions que la spec devra trancher, et les arbitrages déjà posés en
fin de session du 31/05/2026 (~17h Dunkerque). Il sert de base pour la
session de rédaction à venir.

La structure suit 8 clusters de questions identifiés en pré-rédaction. Les
clusters A à E sont tranchés. F (articulation avec les doctrines actées
cette semaine) reste à creuser en session de rédaction. G est partiellement
tranché. H demande des informations techniques que la session de rédaction
récoltera.

---

## Cluster A — Modèle d'appartenance

**A.1 — Une lectrice peut-elle être active dans plusieurs biblios simultanément ?**
➜ **Oui**. C'est la prémisse de la spec.

**A.2 — Existe-t-il un statut « biblio principale » ?**
➜ **Non pensé jusqu'à présent**. À trancher en rédaction si nécessaire,
en regard de la décision B.1 (sélecteur de biblio courante) : si on a un
sélecteur, peut-être qu'on n'a pas besoin de hiérarchie statutaire. À
arbitrer.

**A.3 — Acquisition d'une nouvelle appartenance ?**
➜ **Auto-inscription par la lectrice**. La biblio elle-même n'invite pas
unilatéralement. (G.1 ci-dessous précise que c'est la lectrice qui initie la
démarche.)

**A.4 — Comment quitter une biblio ?**
➜ **Action lectrice** avec **vérification de la situation d'emprunts en cours**.
Sous-questions à creuser en rédaction : que se passe-t-il si la lectrice a un
emprunt en cours ? blocage de la sortie ? sortie possible avec engagement
de retourner ? bascule en « ex-membre avec emprunt à régulariser » ?

---

## Cluster B — Biblio courante / contexte d'action

**B.1 — La lectrice agit-elle toujours « depuis une biblio » ?**
➜ **Oui — sélecteur dans l'onglet d'arrivée sur conta** avec les biblios
d'appartenance en choix. Ce sélecteur portera l'identité courante pour
toute action de la session.

**B.2 — Reflet du contexte dans l'UI ?**
➜ **À approfondir en rédaction**. B.1 esquisse une réponse (sélecteur
d'entrée) mais il faut détailler : visibilité permanente du contexte
courant ? bascule possible en cours de navigation ? indicateur dans chaque
page ?

**B.3 — Emprunt en cours dans A + réservation active dans B : affichage ?**
➜ **Affichage agrégé sur conta**, qui est un poste de commande du compte.
La lectrice voit l'ensemble de ses engagements en cours, toutes biblios
confondues. Le contexte courant influe sur l'action (réserver depuis B
crée une réservation à B), pas sur la lecture (l'affichage est global).

---

## Cluster C — Droits cumulés vs droits par-appartenance

**C.1 — Rôle (`reader`/`librarian`/`coordenador`) ?**
➜ **Par biblio**. Cohérent avec la doctrine de validation par-appartenance
β.1/γ.1 déjà actée.

**C.2 — Lectrice `librarian` dans A et `reader` dans B ?**
➜ **Droits respectifs de chaque biblio, pas plus**. Pas de transfert de
privilège entre biblios. Le rôle est strictement local.

**C.3 — Restrictions (`is_restricted`) ?**
➜ **Par appartenance**. Une lectrice peut être restreinte dans A et active
dans B. Cohérent avec C.1 et avec la doctrine d'autonomie des biblios.

**C.4 — Cotisations ?**
➜ **Par biblio**. Pas d'agrégation. Chaque biblio gère sa propre cotisation,
ses règles, ses cycles.

---

## Cluster D — Validation et conflits cross-biblio

**D.1 — Emprunter simultanément dans A et B sans coordination des biblios ?**
➜ **A priori oui, sauf cas limites gênants à identifier en rédaction**.
Question ouverte : un cas-limite serait-il par exemple qu'une lectrice
emprunte le même titre dans deux biblios différentes ? Cohérent
doctrinalement (la lectrice peut vouloir lire deux exemplaires différents),
mais peut sembler bizarre dans les stats. À trancher.

**D.2 — Plafond d'emprunts ?**
➜ **Plafond propre à chaque biblio**. Pas de plafond agrégé. Cohérent avec
C.4 et l'autonomie biblio.

**D.3 — Conflits de retrait cross-biblio (même jour, deux endroits) ?**
➜ **Affichage centralisé** côté conta lectrice. La biblio elle-même ne sait
pas qu'il y a un conflit cross-biblio (ce n'est pas son rôle de coordonner),
mais la lectrice voit l'ensemble dans son tableau de bord.

---

## Cluster E — Affichage de l'identité d'appartenance

**E.1 — Liste des biblios en bandeau permanent ou seulement la courante ?**
➜ **Seulement la biblio courante** affichée dans le bandeau. La liste
complète des appartenances apparaît dans le **menu déroulant du sélecteur**.

**E.2 — Attributs transverses vs par appartenance ?**
➜ **Tous les attributs cités (nom, e-mail, langue préférée, UUID AnarBib)
sont transverses**. L'UUID est celui d'AnarBib, partagé par toutes les
appartenances. Sous-question pour la rédaction : et le numéro lectrice
visible (type `U000130`) ? Est-il par appartenance ou transverse ? À
trancher (probablement par appartenance, car chaque biblio peut avoir sa
numérotation interne).

**E.3 — La biblio A voit-elle, côté painel, que la lectrice est aussi membre de B ?**
➜ **À creuser en rédaction**. Question doctrinale qui croise la mémoire
collective non-occulte (cf. spec rétention historique livrée ce jour).
Position de défaut probable : **oui, transparence** — A voit que la
lectrice est membre de B (sans voir les détails internes de B). Mais à
arbitrer explicitement.

---

## Cluster F — Articulation avec les spécifications déjà actées

**F.1 à F.4 : À CREUSER EN SESSION DE RÉDACTION**.

Xavier a explicitement marqué ce cluster comme nécessitant plus de détails.
Le creuser exigera :

- **F.1 (validation par-appartenance β.1/γ.1)** : comment se déclinent
  concrètement les droits d'engagement (emprunt, réservation, consultation)
  pour une lectrice multi-biblio ? Réponse partielle déjà via C.1-C.3, à
  préciser pour les cas-limites.
- **F.2 (souveraineté biblio Position 1)** : quelle biblio est souveraine
  sur quel attribut ? Le profil lectrice (qui est transverse, cf. E.2) est-il
  hors souveraineté biblio ? Et l'historique consolidé ?
- **F.3 (notifications-lecteur)** : la spec actée le 31/05 matin pose les
  préférences par lectrice **globalement** (table `user_notification_preferences`
  avec clé `user_id` seul). À réviser pour passer en clé composée
  `(user_id, library_id)` ? Ou garder global ? Question doctrinale réelle :
  une lectrice multi-biblio a-t-elle UNE préférence ou N préférences ?
  Cohérent avec C : par biblio probablement. Mais nécessite une migration
  rétro-compatible.
- **F.4 (rétention historique, spec livrée le 31/05 après-midi)** : déjà
  par biblio (cf. D.9 de cette spec), donc en cohérence avec C.4. Mais
  l'affichage agrégé de l'historique côté lectrice (cf. B.3) demande de
  bien clarifier comment on présente l'historique cross-biblio.

---

## Cluster G — Cas particuliers de transition

**G.1 — Lectrice initie l'ajout d'une nouvelle biblio ?**
➜ **Oui**. La démarche est lectrice. À **détailler en rédaction** :
- D'où la lectrice clique-t-elle pour ajouter une biblio ?
- Validation staff de la biblio cible (cf. workflow d'auto-inscription) ?
- Délai d'attente ? Statut intermédiaire « en attente d'inscription » ?
- Que voit la lectrice pendant l'attente ?

**G.2 — Biblio dissoute / sortant du réseau ?**
➜ **Les comptes sont archivés au niveau des emprunts** ; la lectrice
**continue à être active dans ses autres appartenances**. Bonne nouvelle
doctrinale : pas de cascade d'effondrement.

**G.3 — Compte sans biblio ?**
➜ **Existe déjà depuis ~10 jours** (déjà implémenté). À documenter en
rédaction : que voit la lectrice sans biblio dans `/conta` ? Quels boutons
d'action ?

---

## Cluster H — Implications techniques

**H.1 — Structure de `user_library_memberships` ?**
➜ **À récolter en session de rédaction**. Commandes :

```sql
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'user_library_memberships'
ORDER BY ordinal_position;

-- Et les contraintes (PK, FK, UK)
SELECT tc.constraint_name, tc.constraint_type,
       kcu.column_name,
       ccu.table_name AS references_table, ccu.column_name AS references_column
FROM information_schema.table_constraints tc
LEFT JOIN information_schema.key_column_usage kcu USING (constraint_schema, constraint_name)
LEFT JOIN information_schema.constraint_column_usage ccu USING (constraint_schema, constraint_name)
WHERE tc.table_schema = 'public' AND tc.table_name = 'user_library_memberships';
```

Avec ces deux résultats, la session de rédaction saura si :
- la table est déjà clé composée `(user_id, library_id)` ;
- elle porte un champ `role`, `status`, `is_active`, etc. ;
- les FK sont en CASCADE (probable).

**H.2 — `is_default_library` côté membership ou `default_library_id` côté profil ?**
➜ **Discussion technique** :

L'audit du 31/05 après-midi (chantier RGPD) a confirmé qu'**il n'existe
pas** de colonne `default_library_id` dans `profiles`. Donc la première
option (champ côté membership) est la seule qui ne demande pas de migration
de profil.

Recommandation : **`is_default_library boolean` sur `user_library_memberships`**,
avec une contrainte unique partielle garantissant qu'au plus une rangée par
`user_id` a `is_default_library = true`. Avantages :
- pas de migration de la table `profiles`
- la doctrine « biblio courante » se rapproche de l'appartenance, pas du
  profil global
- une lectrice qui quitte une biblio par défaut bascule naturellement
  (cascade ou trigger)

Mais à confronter avec **A.2** (qui dit que la notion de « biblio
principale » n'a pas été pensée). Si on retient `is_default_library`,
on introduit un statut hiérarchique implicite. À trancher
explicitement en rédaction.

**H.3 — Comment exposer la biblio courante à l'API ?**
➜ **Explication accessible** :

Quand la lectrice clique dans son sélecteur de biblio courante (B.1),
l'app doit propager ce choix à toutes les requêtes qui suivent, sinon la
base ne sait pas dans quel contexte la lectrice agit. Trois approches
techniques classiques :

- **Option α — Paramètre RPC explicite** : chaque RPC sensible au contexte
  prend un `p_library_id uuid` en argument. Côté frontend, le sélecteur le
  passe à chaque appel. **Avantage** : explicite, auditable, pas de magie.
  **Inconvénient** : verbeux, possible oubli côté code, le frontend doit
  systématiquement injecter.

- **Option β — Header HTTP custom** : le frontend ajoute un header
  `X-AnarBib-Library-Context: <uuid>` à toutes les requêtes Supabase. Côté
  backend, un middleware le lit. **Avantage** : transparent côté code RPC.
  **Inconvénient** : Supabase ne lit pas nativement les headers custom dans
  les RPC, il faudrait un wrapper.

- **Option γ — JWT claim** : le sélecteur déclenche un re-login ou un
  refresh du JWT avec un claim `current_library` dedans. Côté RPC,
  `auth.jwt() ->> 'current_library'` est disponible. **Avantage** :
  cryptographiquement propre, Supabase-natif. **Inconvénient** : changer
  de contexte exige un refresh JWT (latence visible), et impose une
  manipulation explicite côté login flow.

Recommandation provisoire : **α** pour la v1 (verbeux mais simple et sûr).
Évoluer vers γ si la verbosité devient pénible et qu'une fonctionnalité
de session lourde émerge. À arbitrer en rédaction.

---

## Récapitulatif des questions à creuser en session de rédaction

Pour cadrer cleanement la prochaine session :

1. **A.2** : statut « biblio principale » oui ou non — cohérence avec H.2.
2. **A.4** : sous-questions sur la sortie avec emprunts en cours.
3. **B.2** : détail de la propagation du contexte courant dans l'UI.
4. **D.1** : cas-limite « même titre dans deux biblios différentes » à arbitrer.
5. **E.2** : numéro lectrice visible — transverse ou par appartenance.
6. **E.3** : la biblio A voit-elle l'appartenance B ?
7. **F.1** : déclinaison concrète des droits d'engagement par biblio.
8. **F.2** : souveraineté biblio sur le profil transverse.
9. **F.3** : migration `user_notification_preferences` vers clé composée — ou pas.
10. **F.4** : affichage cross-biblio de l'historique côté lectrice.
11. **G.1** : workflow complet d'auto-inscription d'une nouvelle biblio.
12. **G.3** : UX du compte sans biblio dans `/conta`.
13. **H.1** : récolter le schéma réel de `user_library_memberships`.
14. **H.2** : arbitrage final `is_default_library` vs autre.
15. **H.3** : arbitrage final α/β/γ pour propagation du contexte courant.

15 questions à creuser. Volumétrie de la session de rédaction : ~3-4h pour
trancher + ~3-4h pour rédiger une spec de ~800-1000 lignes. À faire en
session dédiée à tête reposée.

---

## Lien avec #CL.10 (infos retrait)

#CL.10 (cahier Dunkerque §2.10 — infos pratiques de retrait intégrées au
parcours) **dépend** de cette spec pour la raison suivante : afficher le
nom de la biblio de retrait, son adresse, ses horaires, son téléphone,
n'a de sens *qu'à condition* que la lectrice ait un cadre clair pour
distinguer ses différentes appartenances et savoir quelle biblio est
concernée par tel ou tel emprunt/réservation.

Concrètement, une fois `spec-multi-appartenance-lecteur` rédigée et
implémentée, #CL.10 devient un sous-chantier UX léger qui se branche
naturellement : chaque ligne d'engagement (emprunt, réservation,
consultation) sera taggée par sa biblio, et un clic sur le tag ouvre une
fiche biblio courte (adresse, horaires, contact, lien règlement).

Le cahier Dunkerque §2.10 demande explicitement :
- nom de la bibliothèque de retrait — *trivial une fois multi-appartenance posée*
- adresse, horaires, téléphone ou email — *à exposer côté libraries*
- rappel de la date limite de retrait — *déjà présent dans le rendu réservation*
- ouvrir les infos de la bibliothèque — *fiche biblio publique à créer ou réutiliser*
- voir le règlement ou les modalités de retrait — *déjà existant via `library_commons`*

Donc #CL.10 = ~1 session UX une fois multi-appartenance livrée.

---

# ANNEXE — Arbitrages doctrinaux du 31/05/2026 (suite de session, ~17h-19h Dunkerque)

Cette annexe consigne les arbitrages tranchés en fin de session, après la
clôture de la spec rétention historique et la première rédaction du cadrage
ci-dessus. Elle complète et ajuste les arbitrages préalables.

## Récapitulatif des arbitrages tranchés

### Cluster A — Modèle d'appartenance (complété)

- **A.1** : Oui (multi-biblio possible). [déjà acté]
- **A.2** : **Biblio principale persistée (option β)**. Champ
  `is_default_library` sur `user_library_memberships`, contrainte unique
  partielle garantissant au plus une rangée par `user_id` avec
  `is_default_library = true`.
- **A.2bis** (basculement dans le sélecteur) : **éphémère par défaut avec
  option de re-marquer (option iii)**. Le sélecteur change le contexte
  pour la session ; une action séparée explicite permet de redéfinir la
  principale.
- **A.3** : Auto-inscription par la lectrice. [déjà acté]
- **A.4** : **Sortie avec distinction suspension / résiliation**.
  - **A.4.Q.A** (qui décide) : la lectrice choisit explicitement (option i).
  - **A.4.Q.B** (résiliation = définitive ?) : oui, retour uniquement
    par nouvelle auto-inscription (option y).
  - **A.4.Q.C** (durée de suspension) : **lecture 1** — la suspension
    s'éteint automatiquement quand toutes les données circulation de la
    lectrice dans cette biblio ont été purgées par la rétention RGPD.
  - **A.4.Q.D** (droits pendant suspension) : accès lecture conservé
    (consultation catalogue + ancien historique), pas d'engagement nouveau
    (option s).

**Statuts d'appartenance dans `user_library_memberships.status`** :
- `active`
- `suspended`
- `left_with_pending_circulation`
- `terminated`
- `pending_validation` (ajouté en E.2)

**Transitions valides** :
- `active` → `suspended` (geste lectrice explicite, suspension)
- `active` → `left_with_pending_circulation` (geste lectrice « quitter »
  avec circulation active)
- `active` → `terminated` (geste lectrice « quitter » résiliation
  immédiate sans circulation active)
- `suspended` → `active` (geste lectrice de réactivation)
- `suspended` → `terminated` (automatique quand toutes les données
  circulation sont purgées RGPD)
- `left_with_pending_circulation` → `terminated` (automatique quand toute
  la circulation est régularisée)
- `pending_validation` → `active` (validation staff via spec-validation-physique)
- Aucun retour possible depuis `terminated` (nouvelle inscription requise).

**Préférences de rétention** (`user_history_retention_preferences`) :
considérées comme préférences, pas comme données circulation. **Ne bloquent
pas la bascule** automatique `suspended` → `terminated`.

**Notification e-mail** au moment de la bascule auto
`suspended` → `terminated` (option ii).

### Cluster B — Contexte d'action (complété)

- **B.1** : Sélecteur de biblio courante sur conta. [déjà acté]
- **B.2** : **Persistance en `sessionStorage`** (durée de l'onglet
  navigateur). À chaque nouvelle session, défaut sur biblio principale.
  Pas de stockage côté backend ni dans le JWT en v1.
- **B.2bis** (visibilité du contexte courant) : **badge contextuel sur
  pages d'action sensible** (catalogue, fiche livre, formulaires de
  réservation/emprunt/consultation). Pas de bandeau permanent en haut de
  toutes les pages.
- **B.3** : Affichage agrégé sur conta. [déjà acté]

### Cluster C — Droits cumulés vs par-appartenance (déjà acté)

- **C.1, C.2, C.3, C.4** : tout par biblio. [déjà acté]

### Cluster D — Validation et conflits cross-biblio (complété)

- **D.1** : **Autorisé avec avertissement non-bloquant** quand la
  lectrice tente d'emprunter un `book_id` déjà actif chez elle dans une
  autre biblio. Détection sur `book_id` strict (pas sur titre+auteur, ni
  sur ISBN). Décision finale lectrice.
- **D.2, D.3** : Plafond par biblio + affichage centralisé. [déjà acté]

### Cluster E — Identité d'appartenance (complété et révisé)

- **E.1** : Sélecteur déroulant avec biblio courante en bandeau. [déjà acté]
- **E.2** : **Numéro lectrice par appartenance**, format **libre par
  biblio** (pas de convention AnarBib imposée), contrainte d'unicité par
  biblio (`UNIQUE (library_id, local_reader_number)`). **Saisie manuelle
  staff** lors de la validation physique (cf. articulation avec
  `spec-validation-physique`). Pas d'auto-séquence en v1.
- **E.2bis** (UUID auth) : transverse, inchangé. Un compte = une
  authentification = un UUID. Le numéro lectrice visible est purement
  fonctionnel.
- **E.2ter** (workflow d'auto-inscription en deux temps) : lectrice initie
  l'inscription → appartenance créée en statut `pending_validation` →
  staff valide via `spec-validation-physique` qui attribue le numéro
  local et éventuellement édite/donne la carte lectrice. Pendant
  `pending_validation` : lectrice voit la biblio listée dans son
  sélecteur avec badge d'attente, accès catalogue en lecture seule, pas
  d'engagement de circulation.
- **E.2quater** (migration des données existantes) : aucune migration —
  les données actuelles à très rares exceptions près (deux comptes test
  BTL) sont du test. Démarrage propre.
- **E.3** : **Transparence minimale par défaut** — la biblio A sait que
  la lectrice est aussi membre d'autres biblios (existence des
  appartenances), mais ne voit pas les détails internes (numéro local,
  historique, notes). **Enrichissement possible via partenariat
  stabilisé déclaré** entre A et B (cf. articulation avec future
  `spec-partenariat-biblios`).
- **E.2.5** (visibilité numéro local côté painel staff) : résolu par
  E.3 — par défaut, A ne voit que son propre numéro local pour la
  lectrice. Visibilité enrichie possible selon partenariat stabilisé.

### Articulation avec les autres specs (clarifié)

**`spec-validation-physique`** (amendée le 30/05/2026) :
- Couche d'appartenance déjà en place pour porter les validations.
- Doit être **étendue à la rédaction** pour couvrir l'attribution du
  numéro lectrice local par biblio (geste staff au moment de la
  validation) et éventuellement l'édition de la carte lectrice.

**Future `spec-partenariat-biblios`** (à écrire ultérieurement) :
- Nouveau chantier doctrinal identifié dans cette session.
- Définira concrètement ce qu'est un partenariat stabilisé entre deux
  biblios, sa réciprocité, sa granularité de partage d'information, son
  cycle de vie (création, modification, rupture), ses implications
  côté lectrice (consentement, transparence, opt-out éventuel).
- L'infrastructure UI amorce existe déjà dans la page biblio (section
  *Parcerias de correspondência*, boutons « Adicionar uma biblioteca
  federada » / « Adicionar um coletivo parceiro »).
- N'est **pas une dépendance bloquante** pour la rédaction de
  `spec-multi-appartenance-lecteur` — celle-ci peut s'écrire avec
  mention du dispositif comme parallèle.

---

## Zones d'ombre restantes (mise à jour)

Sur les 23 zones d'ombre initiales identifiées, **arbitrées** :
- 1 (A.2), 1bis (A.2bis), 2 (A.4), 3 (B.2), 4 (D.1), 5 (E.2), 6 (E.3)
- Conséquences 1 et 2 de A.4
- 18 (existence du sélecteur — émerge, doit être créé)

**Toujours à creuser en session de rédaction** :

### Critiques (impactent l'architecture)

- **9 (F.3) — Migration `user_notification_preferences` vers clé composée ?**
  Encore non tranché. Cohérence stricte avec C demande passage à clé
  `(user_id, library_id)` ; coût = migration de la table livrée le matin
  même.
- **13 (H.1) — Récolter le schéma `user_library_memberships`**. Commandes
  SQL fournies dans le cadrage initial.
- **19 — Lectrice mono-biblio : UX du sélecteur quand on n'a qu'une biblio**.
  Sélecteur affiché ou non ? Si affiché, dégénère à un menu d'un seul
  élément — bizarre. Si caché, ajoute une logique conditionnelle.

### Structurantes (orientent la doctrine)

- **7 (F.1) — Déclinaison concrète des droits d'engagement par biblio**.
  Cohérent avec C, mais demande explicitation cas par cas.
- **8 (F.2) — Souveraineté biblio sur le profil transverse**. Quelle
  biblio est souveraine pour valider une modification de profil
  transverse (nom, e-mail, langue préférée) ?
- **11 (G.1) — Workflow complet d'auto-inscription d'une nouvelle biblio**.
  Maintenant partiellement éclairé (workflow en deux temps via
  `spec-validation-physique`), mais détails à creuser : d'où la lectrice
  clique, délai d'attente, communication à elle pendant l'attente.
- **15 (H.3) — Propagation du contexte courant (α / β / γ)**. B.2 a
  tranché pour `sessionStorage` côté frontend ; il reste à arbitrer
  comment le backend reçoit le contexte courant : paramètre RPC explicite,
  header HTTP, ou autre.
- **21 — Comportement du staff qui consulte une lectrice multi-biblio
  depuis painel**. Maintenant éclairé par E.3 — voit l'existence des
  autres appartenances, pas les détails sauf partenariat stabilisé.
  Mais à expliciter en rédaction.

### Secondaires (détails à arbitrer une fois doctrine cadre)

- **10 (F.4) — Affichage cross-biblio de l'historique côté lectrice**.
- **12 (G.3) — UX du compte sans biblio dans `/conta`**.
- **14 (H.2) — `is_default_library` côté membership** — partiellement
  acté par A.2, à finaliser techniquement.
- **17 — Estimation du chantier #CL.10**.
- **20 — Réservations et consultations cross-biblio dans le contexte
  courant**. Si je suis en contexte A et je clique « réserver » sur
  livre de B, que se passe-t-il ?
- **22 — Migration des lectrices existantes**. Résolu en grande partie
  par E.2quater (pas de migration de données existantes — tout est test).
  Mais workflow de transition à expliciter pour les deux comptes BTL.
- **23 — Audit doctrinal de cohérence avec validation par-appartenance
  β.1/γ.1**.
- **Nouveau** — Articulation détaillée avec `spec-partenariat-biblios`
  une fois cette dernière rédigée.

### Récap chiffré

- 9 zones initialement classées « critiques » : **2 tranchées** (1, 18),
  **3 restantes** (9, 13, 19) dont 13 est juste une récolte SQL.
- 7 zones « structurantes » : **3 tranchées** (2, 3, 6 ; 21 partiellement),
  **4-5 restantes**.
- 7 zones « secondaires » : **3 tranchées** (4, 5), **4 restantes**.

**Bilan honnête** : sur 23 zones, **environ 10-12 sont tranchées** en
fin de cette session de cadrage. Il reste **11-13 zones à arbitrer** en
session de rédaction. C'est un excellent ratio pour un cadrage de cette
durée — la session de rédaction commencera sur une base solide.


---

# ANNEXE — Arbitrages doctrinaux du 31/05/2026, seconde moitié de session

Cette annexe complète l'annexe précédente avec les arbitrages tranchés en
fin de session. Elle couvre les zones d'ombre identifiées dans la première
annexe ainsi que les surprises découvertes à l'audit du schéma
`user_library_memberships`.

## Surprises de l'audit du schéma existant

L'audit `information_schema` de `user_library_memberships` a révélé que
plusieurs éléments doctrinaux qu'on supposait à créer **existent déjà** :

1. **`is_primary boolean NOT NULL DEFAULT false`** — résout H.2 (biblio
   principale persistée acté en A.2). La spec multi-appartenance s'écrit
   sur `is_primary`, pas sur un nouveau champ `is_default_library`.
2. **`status text NOT NULL DEFAULT 'active'`** avec CHECK existante
   autorisant `active`, `pending_removal`, `removed`, `inactive`. Statuts
   à enrichir, pas à refondre.
3. **`history_enabled boolean NOT NULL DEFAULT true`** — précurseur de la
   spec rétention historique livrée le 31/05/2026 après-midi. Articulation
   nécessaire (cf. option ρ ci-dessous).
4. **`is_restricted`, `restricted_reason`, `restricted_by`, `restricted_at`** —
   restriction par appartenance déjà implémentée.
5. **`pending_removal_until`, `pending_removal_requested_by`** — mécanisme
   de retrait staff avec délai déjà industrialisé (13 fonctions
   `fn_team_*`, `fn_network_admin_*`, `fn_cron_*` le consomment).

**Conséquence doctrinale** : deux mécanismes distincts coexistent dans la
table — celui du retrait staff initié par l'équipe (statuts
`pending_removal` → `removed`, géré par les `fn_team_*`) et celui de la
sortie volontaire lectrice/staff initiée par la personne (statuts
`suspended`, `left_with_pending_circulation`, `terminated`, à créer).
Les deux ne se confondent pas — il faut articuler les deux dans la spec.

## Arbitrages tranchés

### Arbitrage A — Statuts d'appartenance (posture α : enrichissement)

Vocabulaire final, 8 statuts :

- `active` (existant, inchangé)
- `inactive` (existant — suspension staff via `fn_team_suspend_member`)
- `pending_removal` (existant — workflow staff de retrait avec délai)
- `removed` (existant — retrait staff effectif)
- **`suspended`** (nouveau — suspension volontaire lectrice/staff,
  geste individuel)
- **`left_with_pending_circulation`** (nouveau — sortie volontaire avec
  circulation active)
- **`terminated`** (nouveau — résiliation volontaire ou bascule auto de
  `suspended` quand toutes les données circulation sont purgées RGPD)
- **`pending_validation`** (nouveau — en attente de validation physique)

Migration nécessaire : extension de la CHECK existante pour autoriser
les 4 nouveaux statuts.

**Distinction conceptuelle entre `suspended` et `inactive`** :
- `inactive` = geste collectif staff (équipe suspend un membre)
- `suspended` = geste individuel (la personne se suspend elle-même)

### Arbitrage B — `history_enabled` (option ρ : spec rétention prend précédence)

La table `user_history_retention_preferences` créée par la spec rétention
historique livrée le 31/05/2026 reste la référence pour les préférences
prospectives par domaine (loans/reservations/consultations).

`history_enabled` sur `user_library_memberships` est maintenu en
**synchronisation** : un trigger met `history_enabled = false` quand les
trois préférences par domaine sont à `disable_retention = true`, et
`true` sinon. Pont propre pour `fn_export_my_data` qui continue de
fonctionner sans modification.

### Zone 7 (F.1) + Zone 20 — Droits d'engagement et action cross-contexte

**Conditions pour engager une circulation dans la biblio X** :
1. Appartenance à X en statut `active`
2. Validation physique acquise (`physically_validated_at IS NOT NULL`)
3. Pas de restriction active à X (`is_restricted = false` sur ce membership)
4. Cotisation à jour à X si la politique de X l'exige
5. Plafonds de X non atteints

**Action cross-contexte** : si la lectrice est en contexte A et clique
« réserver » sur un livre détenu par B, **option γ** — refus avec proposition
de bascule de contexte (modale : « ce livre est détenu par B. Veux-tu
basculer ton contexte sur B pour le réserver ? »).

UI catalogue : un livre détenu par une biblio autre que le contexte
courant affiche son bouton de réservation différemment (préfixe « réserver
à B » qui annonce la bascule).

### Zone 8 (F.2) — Souveraineté biblio sur le profil transverse

Modification du profil transverse (nom, e-mail, langue préférée,
adresse) = action de la lectrice seule, **sans validation biblio**. Le
nom transverse fait foi pour toutes les biblios. Si une biblio veut un
alias interne différent, elle le maintient hors AnarBib.

### Zone 11 (G.1) — Workflow d'auto-inscription complet

**Position du bouton « ajouter une biblio »** : depuis la page biblio
publique `/biblioteca/<slug>` (γ) avec un raccourci depuis l'onglet
`perfil` de conta dans une section « Mes appartenances » (α).

**Pas de délai imposé** par AnarBib entre l'auto-inscription et la
validation physique. La lectrice reste en `pending_validation` jusqu'à
ce qu'un staff valide. Une RPC staff de nettoyage périodique des
`pending_validation` anciennes peut être ajoutée.

**Pendant `pending_validation`** : badge d'attente sur la biblio dans
le sélecteur, accès catalogue lecture seule, pas d'engagement de
circulation. Cf. E.2ter.

**Notification de validation** : e-mail + in-app au moment de la
validation. Déjà couvert par `spec-validation-physique` (mail
`validation_confirmed`).

### Zone 15 (H.3) — Propagation du contexte courant côté backend

**Option α — Paramètre RPC explicite** `p_library_id` dans chaque RPC
sensible au contexte. Verbeux mais simple, auditable, sans dépendance
à un middleware ni à un re-issuance JWT.

### Zone 21 — Comportement du staff côté painel sur lectrice multi-biblio

**Par défaut (sans partenariat stabilisé)** : le staff A voit toutes
les infos de la lectrice comme membre de A, plus une mention discrète
du nombre d'autres appartenances (sans détail).

**Avec partenariat stabilisé entre A et B** : le partenariat définit
**explicitement** quelles catégories d'informations sont partagées
(numéro local, état de cotisation, restrictions, historique récent...).
Le staff A voit ces catégories pour la lectrice chez B, en plus de ses
infos chez A.

**Information de la lectrice** : la lectrice est informée de la
transmission. Visibilité dans son `/conta` (encart listant les
partenariats actifs qui la concernent et les catégories partagées par
chacun). Notification (mail + in-app) au moment de l'établissement
d'un partenariat qui implique des biblios dont elle est membre.

**Droit d'opposition (opt-out) à un partenariat individuellement** :
**reporté à la future `spec-partenariat-biblios`** comme première
décision doctrinale à trancher dans cette spec dédiée.

### Zone 10 (F.4) — Affichage cross-biblio de l'historique côté lectrice

L'historique sur conta affiche **toutes les lignes** (tous domaines,
toutes biblios) mais chaque ligne est **taggée par sa biblio d'origine**
(badge visuel discret). Les filtres UI permettent de filtrer par biblio.

Les actions de masquage/suppression (spec rétention) s'appliquent
ligne par ligne. Les préférences prospectives s'appliquent par biblio
(table `user_history_retention_preferences` à clé composée). Pas
d'incohérence : le rendu agrégé est purement présentation, la doctrine
« par biblio » s'applique sous le capot.

### Zone 12 (G.3) — Compte sans biblio dans `/conta`

Comportement déjà implémenté il y a ~10 jours. La spec **décrit ce qui
existe** sans le modifier. À documenter en session de rédaction depuis
la lecture du code actuel.

### Zone 14 (H.2) — `is_default_library` côté membership

**Résolu par découverte de `is_primary` existant**. La spec utilise
`is_primary` sur `user_library_memberships`. À vérifier en session de
rédaction l'existence d'une contrainte unique partielle garantissant
au plus un `is_primary = true` par `user_id` ; à ajouter par migration
si absente.

### Zone 17 — Estimation du chantier #CL.10

Une fois la spec multi-appartenance livrée et implémentée :

- Composant `<LibraryInfoCard>` (nom, adresse, horaires, contact d'une biblio)
- Insertion à chaque ligne de circulation dans conta, taggée par biblio
- Lien vers la page biblio publique (existante)
- Lien vers le règlement (`library_commons`, existant)

**Volumétrie** : ~150 lignes JSX + ~30 clés i18n × 8 locales =
~1 session UX d'1h30, **à faire dès la rédaction des deux specs
terminée** (c'est le chantier qui a déclenché cette boucle doctrinale,
priorité de fermeture).

### Zone 22 — Migration des lectrices existantes

**Aucune migration automatique**. Les deux comptes test BTL existants
sont à traiter manuellement (suppression ou conservation au choix du
staff BTL). La mise en prod de la spec multi-appartenance ne déclenche
aucune transformation des données existantes.

### Zone 23 — Audit doctrinal de cohérence avec validation par-appartenance

À faire **en début de session de rédaction**, avant d'écrire la spec :
relire `DECISION_validation_par_appartenance_2026-05-30.md`, vérifier
la compatibilité de chaque décision actée hier (β.1, γ.1) avec les
arbitrages rendus en cadrage aujourd'hui, trancher explicitement toute
incompatibilité émergente.

## Inscription d'un chantier doctrinal complémentaire

**`spec-partenariat-biblios`** — spec à écrire ultérieurement, déclenchée
par la doctrine de transparence inter-biblios actée en E.3. Première
décision doctrinale à trancher dans cette spec : opt-out individuel de
la lectrice (α/β/γ comme posé dans le cadrage de session). Infrastructure
UI amorce déjà présente dans la page biblio (section *Parcerias de
correspondência*).

## Récap final

Sur les 23 zones d'ombre initiales, **toutes sont traitées** :
- soit tranchées explicitement avec arbitrage doctrinal
- soit résolues par découverte de l'existant (zones 13 et 14)
- soit reportées à la future `spec-partenariat-biblios` avec mention
  explicite (opt-out partenariat)
- soit identifiées comme étape méthodologique de la session de rédaction
  (zone 23) ou documentation de l'existant (zone 12)

Plus les 5 surprises de l'audit `information_schema`, toutes intégrées
dans la doctrine via les arbitrages A, B et la résolution de H.2.

La session de rédaction de `spec-multi-appartenance-lecteur` peut
démarrer sur ce socle solide. Volumétrie estimée de la rédaction :
~600-800 lignes (spec dense mais structurellement complète),
1 à 2 sessions selon la profondeur de mise en forme.

