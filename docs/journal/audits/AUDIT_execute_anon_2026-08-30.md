# Audit — les 33 fonctions `SECURITY DEFINER` exécutables par `anon`

**30 août 2026** · base `uflwmikiyjfnikiphtcp` interrogée en lecture seule · item **B2**, lot 4
**Critère repris de l'audit du 18/05/2026** : *que renvoie-t-elle, à partir de quel
paramètre, et qu'est-ce qui interdit à un tiers non connecté de le demander ?*

---

## Pourquoi ces 33, et pas 500

Le Security Advisor affichait 500 avertissements le 30/08 au matin. Ce sont deux
lints et rien d'autre : `anon_security_definer_function_executable` (0028) et
`authenticated_security_definer_function_executable` (0029). Trois grants que la
fonction elle-même contredisait ont été retirés dans la journée (migration
`20260830181207`), ramenant 0028 de 36 à 33. Cet audit passe ces 33.

**Rappel de la cause.** Ce ne sont pas 33 décisions. Le schéma `public` porte
`ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON
FUNCTIONS TO anon, authenticated, service_role` : toute fonction créée là naît
exécutable par `anon`. Le dépôt porte 141 lignes `REVOKE … anon` — la trace d'une
lutte à la main contre une cause jamais retournée. C'est le lot 3 de B2, et il se
prend **après** cet audit, une fois connue la liste de ce qui doit rester ouvert.

---

## A. Intouchables — appelées depuis des policies évaluées par `anon` (5)

| Fonction | Policies | dont `anon` |
|---|---|---|
| `user_can_act_as_staff_on_library(uuid)` | 33 | 17 |
| `user_can_engage_library(uuid)` | 32 | 5 |
| `fn_caller_is_network_admin()` | 28 | 3 |
| `fn_library_visible_to_caller(uuid)` | 13 | 13 |
| `fn_caller_is_library_staff(uuid)` | 1 | 1 |

Leur retirer `EXECUTE` ne ferme rien : la lecture publique échoue avec
`permission denied for function`. Elles portent depuis le 30/08 un
`COMMENT ON FUNCTION` qui le dit, et les tests **T8/T9** de
`grants_herites_tests.sql` gardent l'invariant dans les deux sens.

**Verdict : légitimes, et à ne jamais fermer.**

---

## B. Légitimes — un usage anonyme réel (23)

**Catalogue public (3).** `api.search_catalog_v1(text)`,
`api.audio_tracklist_public(bigint)`, `api.subject_related_v1(bigint)`.
Le catalogue est publié : c'est la raison d'être de l'OPAC.

**Lecteurs de mode (4).** `fn_library_catalog_mode`, `fn_library_circulation_mode`,
`fn_library_governance_mode`, `fn_library_network_mode`. Une visiteuse non
connectée doit savoir si une bibliothèque publie son catalogue pour que sa page
se rende. Gardés par le **TEST 15** de `paquetA`, dans les deux sens.

**Moissonnage OAI-PMH (3).** `fn_oai_harvestable_libraries`,
`fn_oai_harvestable_records`, `fn_oai_library_is_harvest_eligible`. OAI-PMH est
un protocole anonyme par construction, et ces trois-là filtrent déjà sur
l'éligibilité déclarée par la bibliothèque.

**Candidature d'une bibliothèque, sans compte (4).**
`fn_get_library_request_claim_context`, `fn_consume_library_request_claim`,
`fn_submit_library_request`, `fn_submit_library_request_via_claim`. Une
bibliothèque qui veut rejoindre le réseau n'a pas encore de compte : le parcours
doit fonctionner sans. Le secret est le jeton, pas le droit d'appeler.
*Réserve notée* : `fn_get_library_request_claim_context` renvoie un
`email_snapshot`. Un jeton fuité donne donc une adresse. C'est assumé et
documenté, mais c'est le point le plus exposé de ce groupe.

**Fiche publique d'un livre (6).** `fn_book_due_dates`,
`fn_book_restricted_pdf_state`, `fn_book_restricted_pdf_state_for_current_user`,
`get_book_contributors_public`, `get_book_primary_public_digital_asset_v2`,
`get_accessible_digital_asset_by_id_v2`.
La dernière a été relue de près parce qu'elle renvoie `storage_bucket` et
`storage_path` : **elle est bien construite**. Le contrôle d'accès est dans la
clause `WHERE`, pas dans une colonne de sortie — un actif restreint ne rend
**aucune ligne** à `anon`, au lieu de rendre une ligne avec
`access_granted = false` et le chemin de stockage à côté. C'est la bonne forme.

**Prédicats sur l'appelant, ou configuration d'affichage (3).**
`fn_reading_notes_enabled_for`, `fn_serial_caller_is_library_staff`,
`fn_current_user_is_member_of_holding_library`. Ne renseignent que sur soi-même,
et rendent `false` pour qui n'a pas de session.

**Verdict : légitimes.**

---

## C. À traiter (5)

### C.1 — `fn_oai_network_vote_progress(p_request_id uuid)` — **la vraie**

```sql
SELECT count(*), count(*) FILTER (WHERE vote = 'yes'), count(*) FILTER (WHERE vote IS NULL)
  FROM public.oai_opening_votes WHERE request_id = p_request_id;
```

**Aucun contrôle.** Qui possède l'UUID d'une demande d'ouverture réseau lit le
décompte de la délibération : combien de bibliothèques concernées, combien ont
consenti, combien n'ont pas répondu. Sans compte.

C'est la même famille que le défaut corrigé le matin même sur les votes de
retrait collectif — mais dans l'autre sens. Là, la personne visée lisait « 0 »
au lieu du décompte réel ; ici, n'importe qui lit le décompte réel. Un UUID
n'est pas un secret : il circule dans les URL, les journaux, les copier-coller.

**Verdict : à restreindre.** `authenticated` au minimum ; le bon périmètre est
les bibliothèques concernées par la demande, comme pour les votes de cooptation.
**Une délibération en cours n'est pas une donnée publique.**

### C.2 — `fn_library_timezones()` — énumère tout le réseau

```sql
SELECT lss.library_id, coalesce(nullif(btrim(lss.consultation_timezone),''),'America/Belem')
  FROM public.library_service_state lss;
```

Aucun filtre de visibilité. Un appel anonyme rend **l'identifiant de toutes les
bibliothèques de l'instance**, y compris celles qui ont choisi `network_mode =
isolated` ou un catalogue non publié.

Le fuseau horaire n'est pas sensible. **L'existence d'une bibliothèque l'est** :
pour un réseau de bibliothèques militantes, la liste complète des lieux est
précisément ce qu'une bibliothèque isolée a choisi de ne pas publier. La fonction
sert un besoin technique interne (les crons de consultation) qui n'a aucune
raison d'être anonyme.

**Verdict : à restreindre.** Fermer à `anon`, ou filtrer par
`fn_library_visible_to_caller(library_id)`. À vérifier avant : elle est
consommée par une Edge Function en `service_role`, qui n'est pas concernée.

### C.3 — `fn_partnership_reciprocal_id(p_partnership_id uuid)` — oracle id→id

Rend l'identifiant du partenariat réciproque. Aucune donnée nominative, mais
aucun usage anonyme non plus : les partenariats se gèrent connecté.
**Verdict : à restreindre à `authenticated`.**

### C.4 — `fn_circulation_concurrent_max(p_library_id, p_mode)` — configuration interne

Rend un plafond de politique de circulation. Pas un secret, pas un usage public.
**Verdict : à restreindre à `authenticated`.**

### C.5 — `list_catalog_libraries()` — grant mort, **et une question de conception**

```sql
SELECT l.id, l.name, l.slug FROM public.libraries l
 WHERE l.catalog_mode = 'network_published' AND public.fn_caller_is_network_admin();
```

Pour `anon`, `fn_caller_is_network_admin()` est faux : la fonction rend **une
liste vide**. Le grant est donc mort, comme les trois retirés le matin.

Mais le nom promet une liste de bibliothèques *au catalogue publié*, et le corps
la réserve aux administratrices réseau. **Les deux ne peuvent pas être justes en
même temps.** Ou bien la garde est trop stricte et une page publique affiche
silencieusement une liste vide — un bug visible seulement pour qui n'est pas
admin, donc jamais pour qui développe ; ou bien la fonction est bien
admin-seulement et son nom ment.

**Verdict : à trancher avec le frontend avant tout `REVOKE`.** C'est le seul des
cinq qui puisse cacher un défaut d'affichage plutôt qu'une sur-exposition.

---

## Ce que cet audit change pour le lot 3

Après traitement de C.1 à C.5, la liste des fonctions légitimement ouvertes à
`anon` compte **28 entrées nommées** (5 + 23). C'est cette liste que doit garder
la suite SQL prévue au dernier critère de B2, sur le modèle du TEST 15 de
`paquetA` : *aucune fonction ouverte à `anon` hors de cette liste*.

Une fois cette suite en place, retourner le privilège par défaut du schéma
(lot 3) devient sûr : si l'`ALTER DEFAULT PRIVILEGES` casse quelque chose, c'est
un test qui le dira, pas une page publique.

Et le lint 0028 aura une valeur attendue — **28**. Un avertissement attendu n'est
plus un avertissement.

---

## Addendum — 01/09/2026 : les cinq verdicts sont exécutés, le compte est tenu

**C.1 à C.4** ont été fermées le soir même de l'audit (migration
`20260830191108_une_deliberation_en_cours_n_est_pas_publique`).

**C.5 (`list_catalog_libraries`) est tranchée le 01/09, par les faits.** L'unique
appelant est `BookDraftForm.jsx` — le choix de la bibliothèque cible au
catalogage, réservé aux administrateur·rices réseau **par décision** (17/08,
flux création œuvre/édition). La garde du corps est donc voulue ; c'est le nom
qui promettait trop, et il porte désormais un `COMMENT` qui le dit. Pour `anon`
la fonction rendait une liste vide : grant mort, retiré sans changement de
comportement (migration `20260831195348`). Aucune policy ne la cite.

**Remesuré après déploiement** : 28 fonctions `SECURITY DEFINER` exécutables par
`anon` dans `api` + `public`, zéro hors de la liste nommée du `T10`, zéro
attendue-mais-fermée — et le **lint 0028 affiche 28**, la valeur attendue
annoncée par cet audit. Un avertissement attendu n'est plus un avertissement.

Le défaut du schéma est retourné depuis le 31/08 (`20260831105114`, entrée
`FOR ROLE postgres` seulement — celle de `supabase_admin` reste ouverte et
revient à **B14**). La doctrine est au REGISTRE : `DOC-GRANT-1`.
