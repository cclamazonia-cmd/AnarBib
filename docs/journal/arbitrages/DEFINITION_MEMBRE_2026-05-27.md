# DECISION — Définition du membre du réseau AnarBib

**Date :** 27/05/2026
**Statut :** actée
**Contexte de formulation :** session de travail sur la cartographie du réseau (recensement de 121 lieux libertaires, conception de la spec `spec-cartographie-reseau.md`)
**Portée :** gouvernance du réseau, dépasse le cadre cartographique

---

## Formulation

> Est membre du réseau le collectif ou la bibliothèque dont les données sont **réellement entrées dans la base de données d'AnarBib**. L'adhésion se constate à un fait matériel et vérifiable — la présence dans la base — et non à la signature d'une charte ou à l'acceptation d'un cadre imposé. Chaque membre reste **libre de définir son propre axe de fédération et son mode d'apparition publique** : le réseau ne prescrit ni degré d'engagement ni visibilité.

## Conséquences pratiques

1. **Source de vérité unique** : la base Supabase d'AnarBib est l'unique référence pour le statut de membre. Toute représentation dérivée (carte, document, communication) en est une vue qui doit pouvoir y être resynchronisée.

2. **Pas de charte d'adhésion** : il n'existe pas de document à signer ni de processus de validation par une instance centrale. L'entrée dans la base constitue l'adhésion ; la sortie de la base constitue la fin de l'adhésion.

3. **Autonomie d'apparition publique** : un collectif membre peut choisir de ne pas figurer sur les supports de communication publics du réseau (carte, présentations, listes). Cette décision lui appartient et ne remet pas en cause son statut de membre.

4. **Autonomie d'axe** : le réseau ne prescrit pas à ses membres une ligne, une pratique militante, ou un degré d'engagement particulier. Chaque collectif définit son propre rapport au réseau.

## Cohérence avec la doctrine libertaire du projet

Cette définition formalise le minimalisme adhésionnel comme un acte de transparence libertaire : on évite à la fois l'opacité (un statut de membre flou, négociable) et l'autoritarisme (un statut de membre conditionné à une allégeance). Elle est cohérente avec les choix infrastructurels du projet (migration Brevo → Resend pour raisons anti-tracking, refus des outils de surveillance) et avec la posture politique d'AnarBib comme commun en construction.

---

**Documents liés :**
- `docs/specs/spec-cartographie-reseau.md` (§0.3 reprend cette définition)
- `docs/cartographie/AnarBib_recensement_bibliotheques_libertaires.docx` (intégrée dans la section « Champ statut_anarbib »)
