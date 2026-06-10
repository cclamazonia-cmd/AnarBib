# Décision — Cleanup biblio FRT du 15/05/2026

**Date :** 15 mai 2026
**Contexte :** session refonte 4 specs + démarrage paquet A profils
**Décideur :** Xavier (lead dev AnarBib)

---

## Contexte

La biblio FRT (`id = ab36f7a8-1fa1-4701-9c46-f534d795359d`, slug `frt`, nom « frt ») a été créée le 8 avril 2026 comme **biblio de test résiduelle** lors d'expérimentations sur le workflow d'onboarding. Elle n'a jamais été utilisée pour de l'activité réelle :

- `is_active = false`
- `visibility_level = private`
- 0 membership, 0 holding, 0 emprunt, 0 réservation, 0 consultation
- Seules 2 lignes de config par défaut (library_commons, library_service_state)

## Décision

Suppression définitive de la biblio FRT **avant** la livraison du paquet A profils d'adoption.

## Justification

1. **Cohérence avec le paquet A** : la spec profils v0.3 §9.1 prévoit que « les 3 biblios en prod » reçoivent automatiquement le profil D maximaliste comme DEFAULT. Or FRT n'a aucune raison politique d'être en profil D (elle ne tourne pas, elle est désactivée). Sa présence parasiterait les tests d'acceptation.

2. **Spec profils §11.1 risque "DEFAULT contradictoire"** : la spec recommande explicitement un audit préalable pour éviter qu'une biblio mal configurée ne contredise les DEFAULTs paquet A. FRT est exactement ce cas.

3. **Hygiène DB** : 1 ligne fantôme dans `libraries` + 2 lignes de config orphelines, c'est de la dette accumulée depuis 5 semaines. Le moment est bon (entre la clôture admin réseau et le démarrage profils).

## Vérifications faites avant cleanup

- ✅ `user_library_memberships` : 0 ligne sur FRT
- ✅ `book_holdings` : 0 ligne sur FRT
- ✅ `library_membership_rules` : 0 ligne sur FRT
- ✅ `library_commons` : 1 ligne (config par défaut, CASCADE)
- ✅ `library_service_state` : 1 ligne (config par défaut, CASCADE)
- ✅ Audit FK : 19 CASCADE / 6 RESTRICT (toutes à 0 lignes) / 12 SET NULL ou NO ACTION
- ✅ Tables RESTRICT à 0 : `emprestimos_v2`, `exemplares`, `reservas_v2`, `interlibrary_loans_v2` (3 FK), `book_holdings`

## Procédure d'exécution

1. Script SQL `cleanup-frt-2026-05-15.sql` exécuté manuellement dans Supabase SQL Editor
2. Encapsulé dans une transaction `BEGIN`/`COMMIT` avec DO-blocks de vérification pré et post
3. Pas de migration formelle dans `supabase/migrations/` (action ponctuelle de cleanup, pas évolution de schéma)
4. Vérification post-cleanup : `libraries` contient exactement 2 lignes (BLMF + BTL)

## Conséquences

- **Pas de régression** : aucune donnée métier n'a été perdue (rien à perdre)
- **Paquet A profils peut démarrer proprement** sur 2 biblios bien réelles qui héritent légitimement du profil D maximaliste
- **Aucun utilisateur affecté** : FRT n'avait aucun lien avec aucun compte

## Note pour le futur

À l'avenir, créer les biblios de test :
- **Dans un environnement Supabase staging** (à mettre en place ?), pas en prod
- **Ou marquées explicitement** avec un préfixe `_test_` dans le slug, et un cleanup script automatique en CI hebdomadaire
- **Ou via une vue de filtrage** par défaut qui exclut les biblios `is_active=false` depuis plus de 30 jours

---

*Trace par Xavier + Claude, 15/05/2026.*
