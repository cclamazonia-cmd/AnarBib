# Chantier audit Biblioteca — parité fonctionnelle + qualitative + audit doctrinal

**Date d'ouverture** : 2026-05-21
**Auteur** : Xavier (lead AnarBib) en session avec Claude
**Statut** : ✅ cartographie close — 5 phases livrées en ≈3h de session continue
**Document de référence** : ce fichier est le livrable fondateur du chantier-cadre Biblioteca, et la matrice pour les chantiers Importações et Catalogção à venir

---

## 1. Contexte et arbitrages

### 1.1 Décisions actées avant l'ouverture

| Décision | Date | Source |
|---|---|---|
| Lecture « parité complète » = parité fonctionnelle + qualitative + audit doctrinal | 21/05/2026 | Échange chat |
| Cartographie Biblioteca seule d'abord, décision Importações/Catalogção en sortie | 21/05/2026 | Échange chat |
| BibliotecaPage = page staff uniquement, vue publique ailleurs (hors périmètre) | 21/05/2026 | Échange chat |
| Méthode = session unique de 6-8h en 4 phases | 21/05/2026 | Échange chat |

### 1.2 Périmètre de la cartographie

**Inclus** :
- `BibliotecaPage.jsx` (fichier principal, 1355 lignes)
- Composants extraits appelés depuis BibliotecaPage : `TeamPanel.jsx` (483 l.), `TransitionsPanel.jsx` (474 l.), `LeitoresPanel.jsx` (175 l.), `RetentionPolicySection.jsx` (à mesurer)
- HTML d'origine de référence : `biblioteca.html` (6227 lignes, dont 5317 de JS embarqué)

**Exclus** :
- `LibraryPrivacySection.jsx` (composant lecteur, vue publique)
- Pages voisines (PanelPage, RedePage, ImportacoesPage, CatalogacaoPage)
- Toute mesure i18n détaillée (flaguée pour passe ultérieure)

### 1.3 Doctrines actives au moment de la cartographie

Doctrines applicables aux écarts identifiés ci-dessous :

- **Doctrine RPC obligatoire** (post-chantier #150, 18/05) : pas de `.from()` direct sur tables sensibles, RPC dédié pour chaque opération
- **Doctrine §9.14.2 Biblioteca = délibération politique** (spec profils v0.7, 20/05) : tout onglet est ou délibération collective ou configuration politique, l'opérationnel quotidien va dans Painel
- **Doctrine onboarding asymétrie création vs évolution** (spec profils v0.7 §13.3) : choix initial = wizard individuel, évolution = vote collectif via E.5
- **Doctrine i18n 6 locales** (post-paquet F, 20/05) : aucune string PT-BR hardcodée hors charte langue inclusive
- **Doctrine admin réseau** (spec admin réseau v0.3, 13/05) : certaines relations bilatérales du HTML sont désormais médiées par le réseau (cooptation collective)
- **Doctrine consultas R8** (#141, 16/05) : traçabilité coordination, ordre UPDATE narrative-avant-état
- **Doctrine RGPD Phase 4a** (en cours) : politique de rétention, consentement, droit à l'oubli

---

## 2. Cartographie technique des 12 onglets

| Onglet (JSX) | Homologue HTML | Densité HTML | Densité JSX | Câblage RPC | Statut |
|---|---|---|---|---|---|
| identity | identidade | 9 IDs DOM, lecture seule | 43 l. + `LibraryVisualAssetsSection` + `LocaleSelector` | 3 `.from()` direct (libraries, library_commons, library_service_state) via `saveIdentity` | **JSX plus riche que HTML (édition vs lecture), viole EA-00** |
| comms | comunicacoes | 7 IDs DOM, lecture seule (kv-grids) | 84 l. (4 sous-sections : identité mail, destinataires admin, flags notifs, négociation créneaux PATCH 3A) | 3 `.from()` direct (commons, mail_channels, notification_policies) via `saveComms` | **JSX très enrichi (refonte, pas traduction), viole EA-00** |
| regulation | regimento | 63 IDs DOM, 5 sous-éditeurs (état, docs, policy_sets, rules, etc.) | 307 l., 3 sous-sections (docs, rules, membership.config) | 9 `.from()` direct via loadAll + saveRegulation + saveRule + deleteRule + saveMembershipRules | **Onglet le plus dense, JSX a 3 sous-sections sur 5 du HTML : éditeur policy_sets absent, regimeStateBox/regimeActionBox absents. Viole EA-00.** |
| privacy | *absent (nouveau)* | — | 10 l. wrapper + `RetentionPolicySection` (335 l.) | 2 RPC (`fn_get_retention_policy`, `fn_set_retention_policy`) | **Nouveau, doctrinalement aligné (RPC + i18n), RGPD Phase 4a** |
| documents | documentos | 22 IDs DOM, 6 sous-sections (politique gouvernance documentale, workspace, partenaires, pedidos/acordos, JSON détaillé) | 15 l. (liste partenaires lecture seule, pas d'actions) | 1 `.from('catalog_partners').select` (loadAll) | **Massivement appauvri : 5/6 sous-sections HTML absentes (notamment éditeur `library_document_governance`). Viole EA-00 + appauvrissement fonctionnel** |
| transicoes | *absent (nouveau)* | — | 5 l. wrapper + `TransitionsPanel` (474 l.) | 3 RPC (`fn_propose/vote/cancel_library_profile_change`) + **3 `.from()` direct** (library_profile_proposals × 2, library_profile_votes) | **Nouveau (refactor §9.14, 20/05). RPC pour actions, mais lectures via `.from()`. Violation partielle EA-00.** |
| team | *absent (nouveau)* | — | 11 l. wrapper + `TeamPanel` (483 l.) | 1 RPC `fn_team_list_memberships` + 5 RPC `fn_team_*` (actions) | **Nouveau, doctrinalement aligné (full RPC), Phase B1 hotfix 07/05** |
| leitores | *absent (nouveau)* | — | 5 l. wrapper + `LeitoresPanel` (175 l.) | 1 RPC `fn_team_promote_to_librarian` + **1 `.from('user_library_memberships')` direct** (chargement) | **Nouveau. Action en RPC mais lecture via `.from()`. Violation partielle EA-00.** |
| exchanges | interbib | 49 IDs DOM, **~118 fonctions JS** (`partner`, `exchange`, `relation`) | 25 l. mock UI (boutons disabled, mention `implementationPending`) | aucun appel | **Mock non câblé. Module entier (~118 fonctions JS HTML) absent. Aucune violation EA-00 *parce que rien n'est branché*.** |
| ill | emprestimos-interbib | 24 IDs DOM, **51 fonctions JS** (`InterlibraryLoan*`) | 89 l. + handlers (saveIll, updateIllStatus, deleteIll) | **5 `.from()` direct** (interlibrary_loans_v2 × 3, interlibrary_loan_items_v2 × 2) malgré RPC `fn_peb_authorized` existant | **Chantier PEB-1 connu. Triple défense backend en place mais court-circuitée. Viole EA-00. Module partiellement câblé (peut-être 30-40% des 51 fonctions JS d'origine).** |
| reports | relatorios | 25 IDs DOM | 46 l. (11 indicateurs + top books 90j) | 2 `.from()` (books/authors counts) + 1 vue `api.library_circulation_stats` via `.schema('api').from()` | **JSX très enrichi (11 indicateurs vs HTML modeste). Vue API dédiée = pratique propre. `sendReport` via mailto (note pour `notify-event` à venir). « Envoi semanal opcional » du HTML absent. Viole EA-00 partiellement.** |
| tasks | tarefas | 19 IDs DOM | 48 l. (création/édition/suppression + invitation par mail) | **4 `.from()` direct** (painel_internal_tasks × 3 + painel_internal_task_invites × 1) | **JSX fonctionnellement complet, viole EA-00. String PT-BR hardcodée ligne 1297 (« Gera um resumo… »).** |

*Tableau complet — phase 2 close.*

**Résumé chiffré du périmètre Biblioteca staff :**
- 12 onglets JSX, dont 8 avec homologue HTML et 4 nouveaux
- 1355 lignes BibliotecaPage.jsx (fichier principal)
- 1467 lignes de composants extraits (TeamPanel 483 + TransitionsPanel 474 + LeitoresPanel 175 + RetentionPolicySection 335)
- **47 appels `.from()` direct cumulés** (43 dans le fichier principal + 4 dans deux composants extraits) — violation EA-00
- **14 RPC utilisés cumulés** (12 dans composants extraits + 2 dans RetentionPolicySection)
- 4 onglets enrichis vs HTML (identity, comms, reports, transicoes/team/leitores/privacy nouveaux), 3 onglets équivalents (regulation partiel, tasks, ill partiel), **2 onglets massivement appauvris** (documents, exchanges)

---

## 3. Grille d'écarts doctrinaux

| ID | Onglet | Nature de l'écart | Doctrine en jeu | Arbitrage requis | Décision |
|---|---|---|---|---|---|
| **EA-00** | **tous (cadre)** | **`BibliotecaPage.jsx` principal (1355 l.) = 0 RPC, 43 `.from()` direct. Composants extraits = 7 RPC mais aussi **4 `.from()` direct** (TransitionsPanel × 3 + LeitoresPanel × 1). Seuls TeamPanel et RetentionPolicySection sont 100% RPC. Le câblage direct PEB-1 n'est pas un cas isolé : c'est le motif structurel du périmètre Biblioteca dans son ensemble (47 `.from()` direct cumulés).** | **Doctrine RPC obligatoire post-#150 (18/05)** | **Refondre tous les appels en RPC ? avec quelle séquence ? avec ou sans création de nouvelles RPC backend pour les opérations qui n'en ont pas encore ?** | **✅ Acté doctrine RPC v3 (post-EA-09/EA-10/EA-17) à formuler ainsi : (1) RPC obligatoire pour les *actions DB* (insert/update/delete, multi-tables, validations métier) ; (2) `supabase.from()` direct autorisé pour les *lectures DB simples* protégées par RLS ; (3) `supabase.storage.from()` (API Storage) hors périmètre — c'est l'API native, pas de question de doctrine RPC. Compte à refondre selon cette nuance : sur les 47 `.from()` cumulés, environ 4 sont des lectures DB simples acceptables (EA-09 ×3 + EA-10 ×1) et 3 sont du storage natif (LibraryVisualAssetsSection), reste **~40 actions DB à basculer en RPC**. À traiter onglet par onglet en sous-chantiers ultérieurs. Doctrine RPC v3 à inscrire en GLB v15 ou spec dédiée.** |
| EA-01 | identity | HTML porte un sous-encart `workspace JSON / Ver tudo` (avec `<details>` pour configuration brute). JSX ne le porte pas. | Transparence configuration vs minimalisme UI staff | Reproduire ? remplacer par un bouton « voir config brute » dans un modale ? laisser tomber ? | **✅ Acté Option B : bouton « voir config brute » qui ouvre une modale lisible avec JSON formaté. Vérifier au passage qu'aucun champ sensible (clés API, tokens, secrets transport mail) n'est exposé.** |
| EA-02 | identity | HTML a un bouton « Atualizar » explicite pour rafraîchir manuellement. JSX rafraîchit auto via `loadAll()` après chaque save. | Contrôle utilisateur vs auto-magique | Garder l'auto-refresh seul ? ajouter un bouton refresh manuel ? le rendre optionnel par profil ? | **✅ Acté Option B : ajouter bouton « Atualizar » discret par onglet (~30 min, utile multi-coordenador). À implémenter en quickwin post-cartographie.** |
| EA-03 | identity | JSX intègre `LibraryVisualAssetsSection` (logo, assets) ; HTML ne portait rien d'équivalent. **Composant non lu en phase 2 — état doctrinal inconnu** (RPC ? `.from()` ? i18n ?). | Audit doctrinal du composant extrait | Lire `LibraryVisualAssetsSection.jsx` (à uploader) et l'auditer comme les autres composants, puis identifier les écarts qu'il porte | **✅ Audit fait (368 l.) : 3 `supabase.storage.from()` (API Storage, pas DB → hors doctrine RPC v3) + 1 RPC `fn_ensure_library_theme` légitime. I18n complet (`biblioteca.visualAssets.*`), aucun PT-BR hardcodé. Composant doctrinalement aligné, aucun écart nouveau.** |
| EA-04 | comms | JSX ajoute paquet 3A « négociation symétrique des créneaux » (PATCH 08/05) avec toggle + timeout 7-60j. HTML ne porte rien d'équivalent. | Refonte politique implicite (asymétrie créneaux → symétrie) | Refonte validée tacitement par usage en prod ? rétro-écriture en spec confidentialité Phase 4 ? | **✅ Acté Option B : inscrire dans GLB v15 comme refonte tacite validée par usage. Cas particulier d'EA-18 (déjà acquis) — la doctrine « symétrie des réservations » sera explicitée à cette occasion.** |
| EA-05 | regulation | HTML porte un éditeur explicite de **`policy_sets`** (conjuntos de regras) avec champs riches : `effective_from`, `effective_until`, `config_version`, `activation_note`, `metadata JSON`. JSX ne porte qu'un éditeur de règles individuelles, pas de leurs conjuntos. | Granularité politique : règles isolées vs conjuntos versionnés | Implémenter l'éditeur policy_sets manquant ? le rétroporter en RPC `fn_create/update_policy_set` ? le laisser tomber au profit d'un modèle plus simple ? | **✅ Acté Option A : implémenter à parité HTML (~6-10h). Vision multi-régimes avec versioning, archivage, transitions planifiées. 4 RPC à créer (`fn_create/update/activate/archive_policy_set`) + UI dédiée. Cohérent avec doctrine §9.14.2 (Biblioteca = délibération politique).** |
| EA-06 | regulation | HTML porte `regimeStateBox` + `regimeActionBox` (lecture du « mode de fonctionnement actuel »). JSX n'a pas d'équivalent visible (ou alors c'est dans `serviceState` côté identity). | Doctrine §9.14 : config politique cohérente sur une seule page | Vérifier si le contenu est déplacé vers identity (cohérent §9.14) ou si c'est un manque réel ; documenter | **✅ Acté Option A : restaurer un encart synthétique de lecture en haut de regulation. Complément d'EA-05 (affichage du régime actif issu de `policy_sets` + serviceState). Cohérent avec doctrine §9.14.2 sans imposer de déduplication entre onglets.** |
| EA-07 | regulation | HTML porte un champ `regulationDocBucket` éditable (« Pasta do arquivo »). JSX hardcode `library-regimentos-public` ligne 295. | Sécurité (bucket forcé) vs flexibilité (bucket choisi) | Hardcode reste-t-il pertinent ? Faut-il introduire une whitelist de buckets autorisés ? | **✅ Acté Option A : hardcode reste pertinent. Cohérent avec resserrement RLS storage #150. Documenter dans la doctrine RPC v3 (cf. livrable post-chantier).** |
| EA-08 | documents | **5 sous-sections HTML sur 6 absentes en JSX** : politique gouvernance documentale (6 booléens + 6 champs `library_document_governance`), workspace résumé, pedidos/acordos, JSON détaillé, éditeur de governance complet. JSX = liste partenaires en lecture seule. La table backend existe pourtant. | Refonte ou perte fonctionnelle massive | **Restaurer la gouvernance documentale complète à parité HTML ? remodeler en un système plus simple aligné sur les doctrines admin réseau actuelles ? Reporter à plus tard avec bandeau « en construction » ?** | **✅ Acté Option A : restaurer à parité HTML (~6-10h). Doctrine actée : gouvernance documentale = attribut local par biblio, souveraineté de chaque biblio sur ses propres conditions de mutualisation. 6 booléens + 6 champs + RPC d'édition + UI. Cohérent avec lecture libertaire classique.** |
| EA-09 | transicoes | `TransitionsPanel` fait 3 lectures via `.from('library_profile_proposals')` × 2 et `.from('library_profile_votes')` × 1. Pas de RPC de lecture. | Doctrine RPC post-#150 appliquée seulement aux actions, pas aux lectures | Créer `fn_list_library_profile_proposals` + `fn_list_library_profile_votes` ? laisser les lectures via `.from()` si RLS suffit ? | **✅ Acté Option B : RLS suffit pour les lectures simples. À documenter dans la doctrine RPC v3.** |
| EA-10 | leitores | `LeitoresPanel` charge la liste via `.from('user_library_memberships').select(...)`. Pas de RPC. | Doctrine RPC post-#150 (lecture) | Créer `fn_team_list_readers` ? laisser `.from()` si RLS suffit ? | **✅ Acté Option B : RLS suffit. Doctrine RPC v3 à acter.** |
| EA-11 | exchanges | **~118 fonctions JS HTML absentes** côté JSX. Le module entier (propositions de troca, partenaires, suivi exécution, eligibility rules, logistics mode, etc.) est un mock visuel. **C'est de la refonte intégrale, pas du recâblage.** | Module fonctionnellement vide | **Réimplémenter à parité HTML ? réimplémenter en l'alignant sur la doctrine admin réseau v0.3 (cooptation collective au lieu de bilatéral) ? reporter à un chantier ultérieur ?** | **✅ Acté Option A : parité HTML complète (~40-60h, 2-3 semaines). Cohérent avec doctrine locale (EA-08) et choix initial « parité + audit doctrinal » (cf. §1.1). Engagement structurel : ajoute 2-3 semaines au chantier-cadre Biblioteca. Place dans la séquence à déterminer en phase 4 (recommandation : en dernier, comme non bloquant pour usage immédiat).** |
| EA-12 | ill | 5 `.from()` direct sur `interlibrary_loans_v2` et `interlibrary_loan_items_v2` malgré l'existence de la triple défense backend (RLS permissive + RLS composite + RPC `fn_peb_authorized`). Le module JSX couvre probablement 30-40 % des 51 fonctions JS d'origine. | Câblage direct vs RPC + parité fonctionnelle partielle | **Chantier PEB-1 cadré (3-5h estimées). Étendre à la parité fonctionnelle des 51 fonctions JS d'origine ? boucler PEB-1 au sens strict d'abord ?** | **✅ Acté Option C : deux phases successives. Phase 1 = PEB-1 strict (5 `.from()` → RPC, 3-5h) en livrable rapide pour fermer risque sécurité. Phase 2 = parité fonctionnelle HTML (15-25h additionnelles) pilotée par retours BLMF↔BTL. Phase 1 prioritaire dans la séquence post-cartographie. ✅ **Phase 1 livrée 21/05 (commit f87200119c + migration 20260520150000)**. Tests fumée validés : (1) test négatif avec BLT-test-informal isolated → RLS bloque correctement, (2) test positif avec BTL fédérée → RPC fonctionne. **3 dettes révélées par le test fumée à traiter en phase 2** : (a) libellé bouton « Salvar empréstimo » sémantiquement faux — devrait être « Criar pedido de empréstimo » côté biblio prêteuse (workflow demande/acceptation absent), (b) dropdown borrower autorise sélection de biblios non-fédérées (devrait griser ou exclure les `network_mode != 'federated'`), (c) message d'erreur RLS brut en anglais affiché à l'utilisateur (mappage erreurs RLS → i18n militante à inventer, possiblement transverse à toute la doctrine RLS). (d) Bug technique confirmé : `holding_id` et `item_id` absents du mapping `illItems` — le frontend ne sélectionne pas l'exemplaire physique précis (51 fonctions JS HTML absentes type `populateInterlibraryLoanExemplarSelect`).** |
| EA-13 | reports | `sendReport` utilise `window.open('mailto:...')` avec note honnête « a proper email send would use `notify-event` ». | Transport mail : mailto vs notify-event | Boucler le câblage vers `notify-event` maintenant ? attendre la migration Resend (#110) ? | **✅ Acté Option B : attendre migration Resend (#110), câbler dans la foulée. Dépendance explicite : sous-chantier `sendReport` chaîné après #110.** |
| EA-14 | reports | « Envoi semanal opcional » du HTML (contas-rendidas hebdomadaires automatiques) absent du JSX. | Automation politique : digest hebdomadaire | Implémenter (cron + `notify-event`) ? reporter post-Resend ? abandonner la fonctionnalité ? | **✅ Acté Option B : reporter post-Resend (#110), chaîné avec EA-13. Sous-chantier groupé « envois mail propres reports » = EA-13 + EA-14, à programmer juste après la migration #110.** |
| EA-15 | tasks | 4 `.from()` direct sur `painel_internal_tasks` × 3 et `painel_internal_task_invites` × 1 (createTask, updateTaskStatus, delete, inviteToTask). | Doctrine RPC post-#150 | Créer 4 RPC `fn_task_*` ? laisser `.from()` si RLS suffit ? | **✅ Acté Option A : créer 4 RPC `fn_task_create`, `fn_task_update_status`, `fn_task_delete`, `fn_task_invite` maintenant (~2-3h). Sous-chantier clair sans halo, alignement strict doctrine RPC v3 (actions = insert/update/delete).** |
| EA-16 | tasks | String PT-BR hardcodée ligne 1295 (« Gera um resumo com indicadores, equipe e tarefas internas… »). | Doctrine i18n 6 locales post-paquet F | Extraire en clé i18n + traduire 6 locales (≤ 15 min) — quickwin | **✅ Quickwin acté : extraire en clé `biblioteca.reports.generateHint`, 6 traductions fournies en cartographie, à appliquer en session pratique. Note : la string est en réalité ligne 1295 et appartient au bloc `reports`, pas `tasks` — à reclasser.** |
| EA-17 | transverse | **3 composants extraits non examinés en phase 2** : `LibraryProfileBanner`, `LibraryVisualAssetsSection`, `LocaleSelector`. État doctrinal inconnu. | Audit incomplet | Uploader les 3 composants pour audit complet ? laisser hors périmètre (auditer ultérieurement) ? | **✅ Résolu : `LibraryProfileBanner` (124 l.) audité, purement visuel + sessionStorage, aucun appel Supabase, i18n complet, aligné. `LibraryVisualAssetsSection` (368 l.) audité, aligné (cf. EA-03). `LocaleSelector` confirmé hors périmètre (composant générique). Aucun écart nouveau révélé.** |
| EA-18 | transverse | **2 onglets en refonte tacite** : identity (lecture HTML → édition JSX) et comms (kv-grid HTML → 4 sous-sections JSX dont paquet 3A). Refontes validées par usage en prod mais pas inscrites en spec. | Doctrine traçabilité (specs à jour des décisions de prod) | Rétro-écriture en spec biblioteca (à créer) ? acter dans le GLB v15 ? laisser implicite ? | **✅ Acté Option B : inscrire dans GLB v15 comme « refontes validées par usage » (paquet 3A négociation symétrique + paradigme lecture→édition). ~30 min dans le GLB.** |
| EA-19 | tasks | **Mail d'invitation de tâche absent.** `fn_task_invite` ajoute l'email aux `tags`, le trigger `trg_sync_task_invites_from_task` crée bien la ligne d'invite, mais aucune notification mail n'est envoyée à la personne invitée. Deux causes cumulées : (a) le trigger `trg_enqueue_task_level_notifications_from_task` écoute `UPDATE OF due_date, priority, status, owner, owner_user_id` — **pas `tags`** ; (b) la fonction `enqueue_task_level_notifications_from_task` n'a pas de branche destinataire `invited` (uniquement `organizer` et `library`). Révélé par le test fumée EA-15 du 21/05. | Doctrine notifications mail | **✅ Acté Option C : rattaché à l'étape 8 (chantiers mail post-Resend #110). Traiter avec EA-13 + EA-14. Correctif requis en 2 volets : étendre la clause `UPDATE OF` du trigger à `tags`, et ajouter une branche destinataire `invited` dans `enqueue_task_level_notifications_from_task` + handler mail dans `notify-event`.** |

*Grille hybride : EA-00 cadre transverse + EA-01 à EA-19 par onglet ou transverse spécifique. **Total : 20 écarts** (19 issus de la cartographie + EA-19 révélé par le test fumée EA-15). Phase 3 = arbitrage de chaque écart.*

---

## 4. Premier arbitrage de priorité

*Phase 4 close — séquence ordonnée selon 4 critères :*
1. Risque sécurité immédiat
2. Quickwins sans halo
3. Valeur métier maximale
4. Dépendances externes
5. Engagement long sans urgence immédiate

| Étape | Sous-chantier | Effort estimé | Critère dominant | Dépendance |
|---|---|---|---|---|
| 1 | **EA-16** — extraction string PT-BR + 6 traductions | ≤15 min | quickwin | — |
| 2 | **EA-12 phase 1** — PEB-1 strict (5 `.from()` → RPC) | 3-5h | sécurité immédiate | — |
| 3 | **EA-15** — 4 RPC `fn_task_*` (create, update_status, delete, invite) | 2-3h | doctrine RPC v3 | — |
| 4 | **EA-08** — gouvernance documentale (6 booléens + 6 champs `library_document_governance`) | 6-10h | valeur métier majeure (souveraineté locale) | — |
| 5 | **EA-05 + EA-06** — éditeur policy_sets + encart de lecture régime actuel | 6-10h + 1h | gouvernance multi-régimes | — |
| 6 | **EA-01 + EA-02** — modale workspace JSON formatée + bouton « Atualizar » par onglet | 2h + 30 min | quickwins UI | — |
| 7 | **Inscription doctrine RPC v3 + refontes tacites dans GLB v15** (EA-04, EA-18, EA-00 v3) | 1-2h | traçabilité doctrinale | — |
| 8 | **EA-13 + EA-14 + EA-19** — câblage `sendReport` vers `notify-event` + envoi semanal automatique + mail d'invitation de tâche | 7-12h | dépendance #110 | **#110 Resend** |
| 9 | **EA-12 phase 2** — parité fonctionnelle PEB (15-25h additionnelles, ~45 fn JS manquantes) | 15-25h | parité fonctionnelle | retour BLMF↔BTL en prod |
| 10 | **EA-11** — exchanges à parité HTML (~118 fn JS, refonte intégrale) | 40-60h | parité HTML radicale | — |

### 4.1 Résumé numérique

- **Total estimé : 82-127 heures** soit ≈ **2,5 à 4 semaines en plein temps** (6h/jour effectives)
- Étapes 1-7 = **20-30 heures** (3-5 jours) — livrable cohérent avec usage immédiat possible
- Étape 8 = **6-10 heures** (1 jour) — différée par dépendance externe #110
- Étapes 9-10 = **55-85 heures** (2-3 semaines) — engagement long, non bloquant pour usage immédiat

### 4.2 Écarts non listés en séquence

- **EA-03 et EA-17** : résolus en phase 3 (composants alignés doctrinalement, aucune action requise)
- **EA-09 et EA-10** : résolus par la doctrine RPC v3 nuancée (option B actée), aucune action de code
- **EA-07** : résolu (hardcode reste pertinent), aucune action de code

### 4.3 Notes de séquencement

- **L'étape 2 (PEB-1 strict) est urgente** au sens où elle ferme un risque sécurité existant. Ne pas la reporter sans raison.
- **Les étapes 3 et 5 incluent une création de RPC backend** ; elles nécessitent une session continue, pas un découpage en petites tranches, pour préserver la cohérence des migrations.
- **L'étape 7 (GLB v15) peut s'insérer en respiration** entre n'importe quelles deux étapes selon la fatigue.
- **L'étape 9 (parité PEB) est conditionnée par les retours BLMF↔BTL** : ne pas la lancer avant d'avoir des PEBs en production réelle qui révèlent les manques. La phase 2 attend la phase 1 et un retour terrain.
- **L'étape 10 (exchanges parité) ne bloque rien d'autre.** Peut être lancée en parallèle d'autres chantiers (Importações ? Catalogção ?) ou en série, au choix.

---

## 5. Implications pour Importações et Catalogção

*Phase 5 close — décisions actées en sortie de cartographie Biblioteca.*

### 5.1 Mesures sortantes

**Cartographie Biblioteca (mesures réelles)**
- 20 écarts identifiés : 19 issus de la cartographie initiale (1 cadre + 18 spécifiques/transverses) + EA-19 révélé par le test fumée EA-15
- 9 écarts d'implémentation à traiter en sous-chantiers (entre 30 min et 60h chacun)
- 6 écarts de traçabilité/doctrine sans coût de code significatif
- 5 écarts résolus sans action requise (composants alignés ou doctrine nuancée)
- **Total effort estimé Biblioteca : 82-127 heures**, soit 2,5 à 4 semaines en plein temps
- Concentration : 40 % du coût concentré sur EA-11 (exchanges parité, 40-60h)
- Temps réel cartographie : ~3h en session continue (vs estimation initiale 6-8h)

**Extrapolation honnête vers les deux autres modules**
- Importações (densité présumée comparable Biblioteca) : ~2-3 semaines
- Catalogção (densité présumée supérieure, « du lourd surtout catalogção » dixit Xavier 20/05) : ~3-5 semaines
- **Total trinité staff projeté : 8-12 semaines** en plein temps, soit ≈ 6 mois calendaires en rythme militant réaliste

### 5.2 Décisions actées

**Décision 5.2.1 — Périmètre d'extension**
✅ La méthode parité + audit doctrinal s'étend à Importações et Catalogção. La trinité staff complète est l'objet du chantier-cadre.

**Décision 5.2.2 — Ordre de traitement**
✅ Séquence séquentielle : Biblioteca → Importações → Catalogção. Pas de parallélisation, pas d'imbrication. La cohérence de la méthode prime sur l'optimisation temporelle.

**Décision 5.2.3 — Échéance Bologna FICEDL**
✅ Bologna FICEDL (septembre 2026) est **transformée de deadline en étape**. Le projet sera présenté en état réel à cette date, avec :
- Biblioteca probablement complète (étapes 1-7 et 9-10 de §4 livrées)
- Importações en cours de cartographie ou de traitement
- Catalogção en l'état actuel avec bandeau « cartographie à venir »
- **Posture politique assumée** : AnarBib comme commun en construction, méthode parité + audit doctrinal explicitement revendiquée comme acte politique de transparence et de rigueur libertaire.

### 5.3 Implications calendaires

**Horizon à 1 mois (mi-juin 2026)** — Biblioteca étapes 1-7 livrées (gouvernance documentale, policy_sets, PEB-1 strict, RPC tasks, quickwins UI, doctrine RPC v3 inscrite GLB v15). Usage immédiat possible par BLMF, BTL, BLT-test-informal.

**Horizon à 2-3 mois (juillet-août 2026)** — Biblioteca étape 10 (EA-11 exchanges parité) en cours ou close, étape 9 (EA-12 phase 2 parité PEB) lancée selon retours BLMF↔BTL. Cartographie Importações lancée.

**Horizon à 4-5 mois (septembre-octobre 2026)** — Présentation Bologna FICEDL avec Biblioteca complète, Importações en traitement, Catalogção en attente.

**Horizon à 6-8 mois (novembre 2026 - janvier 2027)** — Importações close, Catalogção cartographiée et en traitement.

**Horizon à 12 mois (mai 2027)** — Trinité staff complète, parité doctrinale assumée sur les trois modules.

### 5.4 Conditions de robustesse de cette séquence

Cette trajectoire ne tient que sous trois conditions :

1. **Aucun écart majeur ne révèle un chantier backend secondaire d'envergure** — par exemple, si EA-11 exchanges ouvre un besoin de doctrine admin réseau v0.4, le coût peut doubler
2. **Le rythme militant tient** — pas de surcharge personnelle, pas d'épuisement, pas de chantier parasite imposé par contexte externe
3. **CIRA Marseille ou autre biblio tierce ne s'active pas avant que Biblioteca soit livré au sens de la séquence 4** — sinon il faut bloquer l'activation ou accepter un usage dégradé

Si l'une de ces conditions ne tient plus, la séquence est à réviser. Cet audit (le présent document) est l'instrument de référence pour cette révision : il pourra être re-itéré sur les modules suivants par la même méthode.

---

## 6. Annexes

### 6.1 Méthode de mesure
- Densité HTML mesurée en IDs DOM dans la `<section id="tab-X">` correspondante, et en nombre de fonctions JS dédiées au module (préfixe sémantique)
- Densité JSX mesurée en lignes du bloc `{tab==='X' && (...)}` dans BibliotecaPage.jsx, plus lignes du composant extrait s'il y en a un
- Câblage RPC mesuré en `supabase.rpc(...)` vs `supabase.from(...)` dans le composant concerné

### 6.2 Fichiers source consultés
- `anarbib-app/src/pages/BibliotecaPage.jsx` (1355 l., commit *à noter*)
- `anarbib-app/src/components/TeamPanel.jsx` (483 l.)
- `anarbib-app/src/components/TransitionsPanel.jsx` (474 l.)
- `anarbib-app/src/components/LeitoresPanel.jsx` (175 l.)
- `anarbib-app/src/components/RetentionPolicySection.jsx` (à confirmer)
- HTML legacy de référence : `biblioteca.html` (6227 l., dont 5317 l. de JS embarqué, 267 fonctions JS)

### 6.3 Écarts pré-identifiés hors périmètre Biblioteca

Écarts repérés au cours de l'audit Biblioteca mais qui n'appartiennent pas à la page Biblioteca. Inscrits ici pour mémoire, à verser au chantier d'audit du module concerné lorsqu'il s'ouvrira.

**ER-01 — Absence d'éditeur applicatif pour `catalog_partners` (page réseau).**
La table `catalog_partners` (partenaires de catalogage du réseau : CIRA Lausanne, Centro Pinelli Milan) n'a aucune politique RLS INSERT/UPDATE/DELETE — elle est en lecture seule pour tous les rôles, y compris l'administration réseau. Ses 2 lignes ont été créées par insertion manuelle directe le 31/03/2026 (même timestamp, jamais modifiées depuis), sans migration de seed traçable ni mécanisme applicatif d'alimentation. Le bloc « Bibliotecas parceiras » de l'onglet `documents` de Biblioteca n'est qu'un affichage en lecture seule de cette table — fidèle au HTML d'origine, donc pas un écart de Biblioteca. Mais l'absence de tout moyen d'éditer `catalog_partners` depuis l'application *est* un écart réel : il relève de la **page réseau** (administration réseau), pas de la page Biblioteca locale. À traiter dans le futur chantier d'audit de la page réseau. Cohérent avec la doctrine de périmètre admin réseau (« page = périmètre, pas de cross-calculation ») : la liste des partenaires du réseau est une donnée transverse, son éditeur a sa place côté réseau. Repéré le 21/05/2026 lors du test fumée d'EA-08.

