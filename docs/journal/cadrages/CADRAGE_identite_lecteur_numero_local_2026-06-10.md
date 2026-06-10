---
Genre : trace (cadrage de chantier)
Statut : 🟡 ouvert — à arbitrer puis exécuter
Date : 2026-06-10
Session : Catalogação work completion
Préséance : ce document est une TRACE non normative. Les décisions, une fois prises,
sont inscrites au REGISTRE_decisions.md (qui fait foi). Ne pas recopier une décision ici.
---

# CADRAGE — Identité lecteur·rice : numéro local de bibliothèque + recherche + roster

## 1. Problème (cas réel rapporté)

AnarBib attribue à la création du compte un **UUID / `public_id`** stable, connu de
la lectrice et de sa **première** bibliothèque. Mais sur le terrain :

- La lectrice arrive dans une **seconde** biblio pour la validation physique, **oublie
  de donner son UUID** ; le·la bibliothécaire ne le réclame pas et lui attribue un
  **numéro de lecteur·rice au format de SA biblio** (registre interne, parfois ancien).
- Plus tard, ce·tte bibliothécaire cherche le compte avec **ce numéro** dans le painel…
  **ça ne marche pas** : la recherche n'accepte que l'**UUID**, pas le numéro local.
- Chaque biblio se retrouve avec **deux populations** : les ancien·nes lecteur·rices
  (registre papier, format « à l'ancienne ») et les arrivées AnarBib (numéro AnarBib).
  Résultat : numéros hétérogènes, non conformes aux standards locaux encore en vigueur,
  et **personne ne s'y retrouve** (staff comme lecteur·rice qui s'inscrit a posteriori
  pour suivre son historique).

**Besoin** : que chaque bibliothèque puisse **attribuer, chercher, relier et exporter**
par **son** numéro local, tout en gardant l'UUID comme identifiant transverse.

## 2. Principe directeur

- **UUID (`public_id`)** = identifiant **transverse, stable, inter-biblios** (carte-lecteur).
  Jamais réécrit, sert de pont entre biblios.
- **Numéro local** = identifiant **par bibliothèque, au format propre de la biblio**.
  Plusieurs biblios → plusieurs numéros pour la même personne, c'est **attendu**.
- Les deux **coexistent** : la lectrice n'a pas à connaître le format de l'autre biblio ;
  chaque biblio retrouve « sa » personne par « son » numéro **ou** par l'UUID.
- Tout ce qui touche au numéro local est **toujours dans le contexte d'une biblio**.

## 3. Existant (fondation déjà en place)

- `user_library_memberships.local_reader_number` (text) + index unique
  **`ux_ulm_local_reader_number (library_id, local_reader_number)`** (MULTI-E.2) :
  le numéro local, **unique par biblio**, est déjà modélisé.
- `api.fn_my_memberships_status` expose déjà « n° local » côté lectrice (/conta).
- Carte-lecteur : résolution UUID/token (`api.resolve_reader_card`, `ResolveCardBox`).
- Recherche painel : `public.fn_painel_find_profile_by_lookup(text)` (UUID/public_id
  uniquement aujourd'hui) → point d'extension de N1.
- Plomberie export §12 (CSV/MARCXML/JSON) réutilisable pour le roster (N3).

→ On n'ajoute **pas** de modèle d'identité ; on ouvre les **portes** autour du champ existant.

## 4. Sous-lots

### N1 — Recherche par numéro local *(quick win, le plus urgent)*
Étendre la recherche painel pour accepter **aussi** le numéro local, **scopé à la biblio
courante** (les numéros ne sont pas uniques entre biblios → désambiguïsation par
`library_id` du contexte). Backend : faire que `fn_painel_find_profile_by_lookup` (ou un
nouveau `_v2` prenant `p_library_id`) matche `local_reader_number` de la biblio. Frontend :
le champ de recherche existant accepte UUID **ou** numéro local.

### N2 — Attribution / édition du numéro local (UI staff)
Dans la gestion lecteur·rice (`TabLeitor`), un champ pour **créer/éditer le numéro au
format de la biblio**, pour **tout·e** lecteur·rice (ancien·ne « papier » comme arrivée
AnarBib). RPC d'écriture gardée staff, respect de l'unicité par biblio (message clair si
collision). Permet à la **première** biblio aussi d'attribuer un numéro maison (pas
seulement l'UUID).

### N3 — Roster exportable (par biblio)
Liste à jour d'une biblio : **NOM, Prénom, inscrit·e depuis, e-mail, UUID, numéro local**
\+ en option : **emprunts en cours, réservations ouvertes, consultations demandées**.
Export CSV (réutilise la plomberie §12). Gardé staff/coordenador.

### N4 — Notification e-mail de réconciliation
À la validation physique (ou à l'attribution du numéro), mail à la biblio (et/ou à la
lectrice ?) reliant **UUID ↔ numéro local**, pour la réconciliation avec le registre
papier. Passe par `notify-event` (⚠️ déploiement bloqué tant que Woodpecker dort).

## 5. Décisions à trancher (à porter au REGISTRE)

1. **Périmètre de recherche N1** : si le staff gère plusieurs biblios (admin réseau /
   coordenador multi), cherche-t-on le numéro **dans toutes ses biblios** ou **dans la
   biblio du contexte courant uniquement** ? (Reco : contexte courant, avec repli « toutes
   mes biblios » si zéro résultat, en signalant la biblio d'origine du match.)
2. **Format du numéro** : **libre** (texte saisi par le staff, colle aux registres
   existants) ou **format imposé/validé par biblio** (préfixe + séquence) ? (Reco v1 :
   libre ; format/séquence auto = évolution ultérieure.)
3. **Attribution manuelle vs auto** : à la validation, propose-t-on un numéro **auto**
   (prochaine séquence) ou **saisie manuelle** ? (Reco v1 : manuel ; bouton « auto » optionnel
   plus tard, par biblio.)
4. **Numéro à l'inscription AnarBib** : à l'auto-inscription, pose-t-on un numéro local
   par défaut (= public_id ? séquence ?) ou **laisse-t-on vide** jusqu'à attribution staff ?
   (Reco : laisser vide ; le numéro local est un acte du staff de la biblio.)
5. **Notif N4** : déclencheur (validation physique ? attribution du numéro ?), destinataires
   (coordenador ? tout staff ? la lectrice aussi ?).
6. **Roster N3** : qui peut exporter (staff vs coordenador), champs optionnels inclus par
   défaut, et confidentialité (e-mail/UUID dans un CSV → manipulation interne uniquement).
7. **Unicité & collisions** : déjà garantie par l'index ; définir le message UX en cas de
   numéro déjà pris dans la biblio.

## 6. Dépendances

- **MULTI-E.2** (`local_reader_number` + index unique) : ✅ en place.
- **Carte-lecteur** (UUID/token) : ✅ en place (l'UUID reste l'id transverse).
- **Export §12** : réutilisé par N3.
- **notify-event** : requis par N4 — **déploiement bloqué par la panne Woodpecker**.
- **Woodpecker** : N1-N4 impliquent migrations + déploiements ; à exécuter de préférence
  **CI rétabli** (sinon applications manuelles à la chaîne, cf. session du 10/06).

## 7. Séquencement recommandé

**N1** (soulagement immédiat du staff) → **N2** (attribution) → **N3** (roster) → **N4**
(notif, dès que `notify-event` redéployable). N1 et N2 forment le cœur ; N3/N4 sont des
compléments.

## 8. Hors scope (pour l'instant)

- Refonte du format de numéro / séquences automatiques par biblio (évolution de N2).
- Import en masse des registres papier existants (chantier séparé, lié §12).
- Unification visuelle UUID/numéro sur la carte-lecteur physique.

---
*Fin du cadrage. Décisions §5 à arbitrer puis à inscrire au REGISTRE (nouvelle section,
ex. `CARD-LOCAL-*` ou rattachement à `CARD`/MULTI-E.2). Exécution selon §7.*
