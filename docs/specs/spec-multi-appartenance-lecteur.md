---
Genre : référence
Statut : 🟡 cadrée
Décisions : incarne MULTI-MODEL/CTX/F3/D1/Z19/B2/PRIMARY ; cite VALID-β1, VALID-γ1, ACCT-MIGRATION, PARTNER-* (parallèle)
Supersédé par : —
---

# spec-multi-appartenance-lecteur

| | |
|---|---|
| **Version** | v0.3 — charpente figée (5 arbitrages soldés, audit Zone 23 intégré, §17.2 clos) |
| **Date** | 2 juin 2026 |
| **Emplacement cible** | `docs/specs/` |
| **Statut** | Charpente complète et arbitrée — **aucun point ouvert**. Conforme à `CHARTE_corpus` (en-tête standard). Prête à remplir d'un seul tenant. |
| **Réfère à** | #CL.10 (cahier Dunkerque §2.10). Socle : `CADRAGE_spec-multi-appartenance-lecteur_2026-05-31.md` + `DECISION_validation_par_appartenance_2026-05-30.md`. |
| **Absorbe** | `spec-migration-compte v1.0` (à archiver *après* livraison, pas avant). |
| **Dépendances** | `spec-gouvernance-roles` (Q12/Q15), `spec-validation-physique` (à étendre : numéro local), `spec-partenariat-biblios` (parallèle, non bloquante), rétention #CL.8, notifications-lecteur (F.3 acté). |

> **Convention.** **[A]** = acté (cadrage 31/05 ou arbitrages 02/06). Plus aucun **[T]** : tous les points sont tranchés.

---

## 1. Préambule & objet
- Lectrice membre actif de plusieurs biblios simultanément **[A — A.1]**.
- Objet : modèle d'appartenance multiple, contexte d'action, droits, identité, transparence inter-biblios.
- Déclencheur #CL.10 ; absorbe `spec-migration-compte` ; s'articule avec gouvernance-roles, validation-physique, rétention #CL.8, partenariat-biblios.

## 2. Modèle d'appartenance
- Appartenance = `(user_id, library_id)` + attributs **locaux** ; clé composée **[A]**.
- **Huit statuts** **[A]** : `active`, `inactive`, `pending_removal`, `removed` (existants) + `suspended`, `left_with_pending_circulation`, `terminated`, `pending_validation` (nouveaux). Deux mécanismes à articuler : retrait staff (`fn_team_*`) vs sortie volontaire.
- Biblio principale = `is_primary` (existant) + contrainte unique partielle **[A — A.2]**. Basculement du sélecteur éphémère, re-marquage explicite séparé **[A — A.2bis]**.
- Acquisition = auto-inscription (détail §8, sous garde β.1) **[A — A.3]**. Sortie = suspension vs résiliation **[A — A.4]**.

## 3. Biblio courante / contexte d'action
- Sélecteur de biblio courante à l'entrée de `/conta` **[A — B.1]** ; persistance `sessionStorage` **[A]**.
- Lecture **agrégée**, action **contextuelle** **[A — B.3]**.
- **Visibilité du contexte (B.2 → option a) [A — 02/06]** : bandeau de contexte permanent (uniquement en multi-biblio), cliquable pour rebasculer ; **renforcé** par bascule des variables `--brand-*` de `/conta` sur le thème de la biblio courante quand celle-ci a personnalisé son environnement (le bandeau reste le filet explicite). Renfort sur les pages d'engagement (« réserver à <biblio> »).
- Cas mono-biblio : **sélecteur masqué, apparaît à partir de 2 appartenances (Zone 19 → option b) [A — 02/06]** ; bandeau de contexte également réservé au multi-biblio.

## 4. Droits par appartenance
- Rôle local, restrictions, cotisations : **strictement par biblio** **[A — C.1–C.4]**.
- **Cinq conditions** pour engager une circulation dans X **[A — Zone 7/F.1]** : appartenance `active` ; **validation physique acquise sur le membership X** (`physically_validated_at IS NOT NULL`, *par-appartenance* — décision 30/05) ; pas de restriction à X ; cotisation à jour si X l'exige ; plafonds de X non atteints.
- Plafonds par biblio **[A — D.2]**.
- Action cross-contexte : refus + proposition de bascule (option γ) **[A]**.

## 5. Identité & attributs
- Transverses : nom, e-mail, langue, UUID AnarBib **[A — E.2]**. Numéro lectrice **local** par appartenance **[A]**.
- Souveraineté : profil transverse = lectrice seule, sans validation biblio **[A — Zone 8/F.2]**.
- Bandeau = biblio courante ; liste complète dans le menu du sélecteur **[A — E.1]**.

## 6. Transparence inter-biblios
- **Transparence minimale par défaut** (existence des appartenances, pas les détails) **[A — E.3 / E.2.5]**.
- Vue staff painel : infos de A + mention discrète du nombre d'autres appartenances **[A — Zone 21]**.
- Enrichissement via partenariat stabilisé → `spec-partenariat-biblios` ; opt-out individuel = première décision de cette spec dédiée **[A]**. **Borne γ.1 (cf. §17.3)** : la transparence enrichie *expose* une restriction posée ailleurs, elle n'*impose* aucune action — pas de cascade.

## 7. Validation & conflits cross-biblio
- Emprunt simultané A/B : oui **[A — D.1]**. **Même titre dans deux biblios : toléré, signalé côté lectrice, jamais bloqué (D.1 → option b) [A — 02/06]** — signal informatif sur `/conta` agrégé ; la biblio ne voit rien et ne coordonne pas (cohérent D.3). Base de comparaison = l'œuvre/notice (à préciser au remplissage).
- Conflits de retrait : affichage centralisé côté lectrice **[A — D.3]**.

## 8. Workflow d'auto-inscription
- Points d'entrée : page biblio publique `/biblioteca/<slug>` + raccourci onglet `perfil` **[A — Zone 11/G.1]**.
- **Garde β.1 [A — 30/05, intégrée par l'audit Zone 23]** : la **première** inscription est libre ; toute inscription **supplémentaire** exige qu'au moins une appartenance existante soit déjà **validée** (n'importe laquelle). Protège contre l'inscription parallèle malveillante.
- Pas de délai imposé ; `pending_validation` jusqu'à validation staff ; pendant l'attente : badge dans le sélecteur, catalogue en lecture seule, pas d'engagement **[A]**.
- Validation staff via `spec-validation-physique` (attribution du numéro local, carte) ; notification `validation_confirmed` ; journalisée dans `membership_validation_log` (décision 30/05) **[A]**. → `spec-validation-physique` **à étendre**.

## 9. Affichage cross-biblio de l'historique
- Toutes les lignes, taggées par biblio, + filtres **[A — Zone 10/F.4]**.
- Rétention #CL.8 : masquage/suppression ligne par ligne ; préférences par biblio ; rendu agrégé = présentation seule **[A]**.

## 10. Cas de transition
- Biblio dissoute : emprunts archivés, autres appartenances intactes — pas de cascade **[A — G.2]** (aligné γ.1, cf. §17.3).
- Compte sans biblio : la spec documente l'existant **[A — G.3]**.

## 11. Implications techniques
- `user_library_memberships` porte déjà `is_primary`, `status`, `history_enabled`, `is_restricted`(+`restricted_*`), `pending_removal_*` → enrichir **[A]**. Plus, par décision 30/05 : `physically_validated_at`, `physically_validated_by_user_id`, `physical_validation_note` (par-appartenance) + table `membership_validation_log`.
- Propagation du contexte : **option α — `p_library_id` en paramètre RPC** **[A — Zone 15]**.
- `history_enabled` synchronisé avec les préférences #CL.8 via trigger **[A — Arbitrage B]**.
- `fn_my_account_status` : évalue la validation de la **primaire** — déjà câblé, sans refonte (décision 30/05 §4) ; complété par `fn_my_memberships_status` (RPC par-biblio) pour le détail, cf. §17.2.

## 12. Articulation avec le corpus
- `spec-validation-physique` (à étendre) · `spec-gouvernance-roles` (Q12/Q15) · `spec-partenariat-biblios` (parallèle) · rétention #CL.8 · `DECISION_validation_par_appartenance_2026-05-30` (β.1/γ.1).
- **notifications-lecteur — F.3 acté (option c, hybride) [A — 02/06]** : `user_notification_preferences` passe en clé composée `(user_id, library_id)` pour les préférences **liées à une biblio** (rappels d'emprunt, réservations, consultations) ; les préférences **transverses** (sécurité du compte, profil) restent globales — via `library_id` sentinelle `NULL` ou mini-table dédiée (à trancher techniquement au remplissage). Migration rétro-compatible, faite tant que la table est neuve.

## 13. Migration
- Aucune migration automatique ; deux comptes test BTL traités manuellement **[A — Zone 22]**.

## 14. Branchement #CL.10
- `<LibraryInfoCard>` par ligne de circulation, taggée par biblio ; liens page biblio publique + règlement (`library_commons`). ~150 l. JSX + ~30 clés × 8 = ~1 session UX **[A — Zone 17]**.

## 15. Annexe — table des décisions actées
*(à remplir : reprise systématique A.1→H.3 + Arbitrages A/B + les 5 arbitrages du 02/06, avec justification. Au remplissage, chaque décision recevra son ID registre — cf. note de gouvernance.)*

---

## 16. Points d'arbitrage — TOUS SOLDÉS le 02/06
- **F.3** → **option c** (hybride : circulation par biblio, transverse global). Cf. §12.
- **D.1** → **option b** (toléré, signalé côté lectrice). Cf. §7.
- **Zone 19** → **option b** (sélecteur conditionnel ≥ 2 biblios). Cf. §3.
- **B.2** → **option a** + thème `--brand-*` de la biblio courante. Cf. §3.
- **Zone 23** → audit mené (résultat §17), **§17.2 clos**.

Aucun point ouvert.

---

## 17. Résultat de l'audit Zone 23 (cohérence β.1 / γ.1)

**Verdict : compatible.** Même colonne vertébrale (validation par-appartenance, souveraineté locale, non-cascade). Trois résultats :

1. **β.1 intégré au workflow d'auto-inscription (§8).** Le cadrage l'avait omise : première inscription libre, inscription supplémentaire conditionnée à ≥ 1 appartenance validée. Comblé.
2. **is_primary ↔ `fn_my_account_status` — clos le 02/06.** Aucun couplage en DB entre `is_primary` et la validation (β.2 reste rejeté, conformément à la décision 30/05 §2). `fn_my_account_status` conserve la « vérité vue de la primaire » (acté décision 30/05 §4). Le cas « primaire `pending` alors qu'une autre appartenance est active validée » est levé par **`fn_my_memberships_status`** (RPC par-biblio prévue par la décision 30/05) alimentant un onglet « mes biblios » qui montre le statut de chacune. Garde UX douce : déconseiller (sans interdire en base) de marquer une appartenance `pending` comme primaire.
3. **γ.1 confirmé** : non-cascade alignée avec G.2 ; borne la transparence du partenariat (expose sans imposer, §6). Formule reprise telle quelle dans `spec-partenariat-biblios` : *« la confiance n'est pas transitive dans une fédération sans hiérarchie »*.

Raccordements techniques tracés : `membership_validation_log` (§8/§11) et la branche `pending` de `fn_my_account_status` (§11).

---

*Fin de la charpente — v0.3, figée. Aucun point ouvert. Le remplissage (~800 lignes) suit en session dédiée, selon le modèle de `CHARTE_corpus` (en-tête standard, foyer unique, citer plutôt que recopier).*
