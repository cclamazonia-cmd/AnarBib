# Décision — Validation physique : par-appartenance, et règles d'enchaînement multi-biblios

**Date** : 30/05/2026
**Contexte** : Préalable à l'implémentation de `spec-validation-physique` et au cadrage de la future `spec-multi-appartenance-lecteur`.
**Statut** : ✅ Actée

---

## 1. Décision principale — validation par-appartenance

La validation physique est portée par **l'appartenance** (`user_library_memberships`), **pas par le compte** (`profiles`).

Ce qui veut dire que chaque ligne de `user_library_memberships` porte ses propres colonnes :

- `physically_validated_at` (timestamp)
- `physically_validated_by_user_id` (FK vers `profiles.id` du validateur·rice)
- `physical_validation_note` (texte libre, optionnel)

Et que la table de journalisation prévue par la spec (`profile_validation_log` dans la rédaction initiale) devient **`membership_validation_log`**, avec une FK vers `user_library_memberships`.

### Pourquoi

La validation physique est un **acte local, situé** : des personnes physiques dans une biblio confirment qu'un contact inscrit *chez elles* sous tel nom existe bien et n'est pas malveillant. C'est un témoignage, pas une attestation universelle. Lyon ne peut pas valider l'identité d'un·e camarade paulista ; Madrid ne peut pas se reposer sur la validation faite à São Paulo pour décider d'accueillir.

La conséquence se voit dans le modèle réel d'AnarBib :

- Le projet supporte la **multi-appartenance** (rare en pratique — peut-être huit ou neuf villes au monde comptent plus d'une biblio anarchiste — mais réelle : Lyon, São Paulo, Madrid et quelques autres).
- Chaque biblio est souveraine de sa politique d'accueil (cf. `network_access_mode` sur `libraries`, qui reste local).
- La doctrine périmètre du Grand Livre blanc v17 (II) inscrit explicitement qu'*« un·e lecteur·rice membre de trois bibliothèques apparaît trois fois (une par appartenance) dans les comptages locaux »*.

Mettre `physically_validated_at` sur `profiles` reviendrait à dire que la validation faite par une biblio engage le réseau entier. Ce n'est ni techniquement souhaitable, ni politiquement cohérent avec la fédération anarchiste sans hiérarchie.

---

## 2. Règle d'enchaînement multi-biblios — β.1

**Une personne peut ajouter une seconde (ou nième) appartenance dès lors qu'au moins une de ses appartenances existantes est validée.**

- L'inscription **initiale** à AnarBib (premier `user_library_memberships`) ne requiert aucune validation préalable — sinon le système serait fermé.
- Pour ajouter une **seconde** appartenance, le compte doit avoir **au moins une appartenance déjà validée** (n'importe laquelle, primaire ou non).
- La validation de la nouvelle appartenance reste de la responsabilité de la biblio d'accueil, indépendamment du témoignage déjà reçu ailleurs.

### Pourquoi β.1 plutôt que β.2 ou β.3

- **β.2 (la primaire doit être validée)** crée une dépendance artificielle entre `is_primary` et le droit d'extension. Si une lectrice bascule sa primaire vers une biblio non encore validée, elle perd le droit d'ajouter une troisième — comportement inattendu.
- **β.3 (toutes les appartenances doivent être validées)** devient kafkaïen : une personne en cours de validation à Lyon ne pourrait pas s'inscrire à Madrid tant que Lyon n'a pas tranché, même si BLMF l'a déjà validée.
- **β.1** respecte la souveraineté de chaque biblio : un témoignage local suffit pour que le réseau considère qu'une personne est réelle et non malveillante. Chaque biblio d'accueil décide ensuite de son propre acte.

### Protection contre l'abus

Le risque qu'une personne malveillante s'inscrive simultanément à plusieurs biblios avant que la première ait le temps de la repérer est limité par β : la fenêtre d'inscription parallèle ne dépasse pas le temps de validation de la première appartenance. Après, β.1 bloque toute extension tant qu'aucune validation n'est confirmée.

---

## 3. Sort des autres appartenances en cas de révocation — γ.1

**Si une appartenance validée est ensuite révoquée par sa biblio, les autres appartenances de la même personne ne sont PAS affectées automatiquement.**

- Chaque biblio reste souveraine de son acte de validation. Une révocation à BLMF ne déclenche **aucune cascade automatique** vers les appartenances Lyon, Madrid, etc.
- Si la révocation a une cause grave (usurpation, comportement violent…), la biblio qui révoque peut communiquer avec les autres biblios concernées **par canal humain** (cohérent avec la doctrine anti-méga-machine du GLB v17). Chaque biblio destinataire évalue alors si elle révoque à son tour.
- AnarBib n'enverra **pas** de notification automatique inter-biblios sur révocation. Ce serait introduire une cascade hiérarchique que le projet refuse, et ouvrirait un débat RGPD/LGPD complexe (quel niveau d'information partager, qui décide).

### Pourquoi γ.1 plutôt que γ.2 ou γ.3

- **γ.2 (notification automatique aux autres biblios)** ouvre un Pandora : quelles données partager, sous quel statut juridique, avec quelle force contraignante.
- **γ.3 (passage automatique des autres appartenances en attention/restricted)** transforme la décision d'une biblio en sanction réseau, ce qui contredit la souveraineté locale.
- **γ.1** maintient le canal humain comme premier (doctrine GLB v17 I.2), et la souveraineté locale comme principe.

### Conséquence visible

Après révocation à BLMF, une lectrice avec une seconde appartenance toujours valide à Lyon continue de pouvoir circuler à Lyon. C'est intentionnel : la confiance n'est pas transitive dans une fédération sans hiérarchie. Si BLMF veut alerter, elle écrit ; si Lyon veut réévaluer, elle réévalue.

---

## 4. Conséquences pour `fn_my_account_status`

La fonction lit aujourd'hui `is_primary = true` pour récupérer une appartenance. Le statut `pending` à ajouter évaluera donc la validation de l'appartenance primaire **uniquement**.

Conséquence visible : une lectrice validée à sa primaire (BLMF) mais inscrite récemment à Lyon (non encore validée à Lyon) verra sur `/conta` un bandeau actif (sa primaire est OK). Côté Lyon, l'interface staff la verra en `pending`. C'est cohérent avec la doctrine périmètre : chaque biblio voit sa propre vérité, et `fn_my_account_status` est l'évaluation du compte global vu de la primaire.

Pas de fonction supplémentaire pour l'instant — si un jour le besoin émerge d'évaluer le statut « par-biblio » côté frontend lecteur (par exemple, un onglet « mes biblios » qui montrerait la validation de chacune), ce sera une RPC distincte (`fn_my_memberships_status` ou équivalent) à cadrer à ce moment-là.

---

## 5. Documents à amender

Suite à cette décision, deux documents existants ont un cadrage à ajuster :

- **`docs/specs/spec-validation-physique.md`** — section 3 (schéma DB : colonnes sur `user_library_memberships`, pas `profiles` ; table `membership_validation_log`), et la sous-section sur l'évolution de `fn_my_account_status` reste valide à un nuage près (elle lit déjà l'appartenance primaire, donc la branche `pending` y fonctionne sans changement). Note d'amendement en tête, pas de réécriture.
- **`spec-multi-appartenance-lecteur`** (à écrire) — devra trancher d'autres points connexes (historique par biblio ou global, cotisation par biblio, conditions de retrait d'une appartenance, rôle exact de `is_primary` au-delà de `fn_my_account_status`).

---

## 6. Hors scope de cette décision

Cette décision tranche **uniquement** :
- Où vit la validation physique en DB (par-appartenance).
- Quand on peut ajouter une nouvelle appartenance (β.1).
- Ce qu'une révocation impacte (γ.1, non-cascade).

Elle ne tranche pas :
- Le cadrage complet du multi-appartenance (cotisations, historique, retrait) — à venir dans `spec-multi-appartenance-lecteur`.
- L'UX staff de validation (interface dans le Painel, scan QR, validation hors-ligne) — à cadrer en phase 3 frontend de la spec validation physique.
- Les questions de migration des données existantes (grandfathering : que devient `physically_validated_at` des comptes déjà créés avant cette décision) — couvert par la section 8 de la spec validation physique, à adapter au nouveau schéma.
