# Cadrage doctrinal — `spec-multi-appartenance-lecteur` (à venir)

**Date** : 31/05/2026
**Statut** : Cadrage en cours, rédaction de la spec à venir dans une session dédiée
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
