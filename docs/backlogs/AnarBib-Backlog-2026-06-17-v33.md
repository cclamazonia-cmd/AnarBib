# AnarBib — Backlog technique **v33** (mise à jour 2026-06-17)

> **Pourquoi v33.** Reporte le **v32** (12/06). Cette version intègre un **audit
> complet de la « longue traîne » OPAC** (item #14 / §2.4) mené en lecture seule
> sur la prod (`uflwmikiyjfnikiphtcp`) le 16-17/06, et **5 livrables de session**
> produits **hors worktree** (sandbox `~/anarbib-traine`, **non déployés**, en
> attente d'intégration). Constat principal : **la longue traîne OPAC est
> très largement LIVRÉE en prod** — le v32 la listait « ouverte » à tort. Ce qui
> reste est surtout de la **donnée** (indexation, traductions, enrichissement),
> chiffrée ici. **REGISTRE > spec > backlog** inchangé.
>
> **Provenance de vérification (légende).**
> - **✅ prod** — constaté cette session (requête lecture seule / code en prod lu).
> - **📦 sandbox** — livré + testé hors worktree, **pas encore déployé**.
> - **↩︎ v32** — report tel quel, **non re-vérifié cette session**.
> - **🟡 ouvert** · **🟠 en cours** · **⚪ cosmétique/différé**.

---

## 0. Livrables de cette session (16-17/06) — sandbox `~/anarbib-traine`, à intégrer

> Écrits **hors du worktree main** (session parallèle active : `~/anarbib` à
> `e154072c`, `~/anarbib-p2`). Testés ; **horodatages de migration à re-vérifier
> `> max` canonique au push** (le canonique a déjà dépassé `…210916`).

| # | Livrable | Fichier(s) sandbox | Test | Solde / avance |
|---|---|---|---|---|
| **(1a)** | Recherche catalogue **multi-mots** (+ corrige une collision `or` recherche↔multi-biblio) | `src/lib/catalogFilters.js` (extrait), `CatalogPage.jsx`, `src/tests/catalogFilters.test.js` | ✅ 8 tests Vitest + build | avance #58/#62 |
| **(2)** | Fiche auteur·rice : **formes du nom** (`variant_forms`) + `activityPlace`/`pseudonyms` | `AuthorPage.jsx` + `.css`, **10 locales** (+5 clés, parité) | ✅ build + 84 tests + **capture live** (Kropotkin) | avance #AUT |
| **(1b)** | Recherche **accents + pertinence** (RPC anon `api.catalog_search_ids_v1`) | `docs/drafts/opac_catalog_search_accent_rank_DRAFT.sql (hors migrations)` | 🟡 **brouillon** : requête validée read-only, enrobage à éprouver **sur branche** | #58/#62, accent gap |
| **i18n-sujets** | **30 sujets ×10 locales** (6 manquantes + trous fr/es/en) | `migrations/20260617020228_opac_subject_labels_i18n.sql` | ✅ validé read-only (10 clés/sujet) | **solde #I18N-sujets** |
| **enrich-AUT** | `variant_forms` de **9 auteur·rices** (API Wikidata, haute confiance) | `migrations/20260617020229_..._wikidata.sql` (+ `scripts/enrich-variant-forms-wikidata.cjs`) | ✅ validé read-only (JSON/apostrophes) | avance enrichissement |

> **Intégration** : (1a)+(2) = frontend (testables symlink) ; les 3 migrations =
> **données/DB** (validées en `SELECT` sans modifier la prod) → déploiement via CI/branche.
> **(1b)** ne couvre que le chemin **anon** ; le chemin **connecté** (session) reste à
> écrire sur le même patron — **ne pas câbler (1b) pour les connecté·es** d'ici là (régression).

---

## 0bis. Longue traîne OPAC — réconciliation (correction du v32 §2.4)

Le v32 listait ces items « ouverts ». **Vérifié ce 16/06 — la plupart sont en prod :**

| Item v32 | Réalité vérifiée |
|---|---|
| #OPAC4 similaires (UI) | ✅ **prod** — `api.similar_books` (fiche livre), `api.similar_authors` (fiche auteur) affichés |
| #OPAC6 description | ✅ **prod** — champ `notas` affiché |
| #OPAC9 favoris/wishlist | ✅ **prod** — ajout liste + fiche, **consultation/gestion** onglet « desejos » du compte (`user_wishlist`) |
| #OPAC10 parcours | ✅ **prod** — A–Z par auteur·rice + « nouveautés » |
| #AUT1-4 auteur·rices | ✅ **prod** — réseau intellectuel, nuage de sujets, dispo session-aware, export BibTeX/RIS |
| #61 date limite de retrait | ✅ **prod** — `earliest_due_back_at` affiché (fiche livre) |
| #58/#62 refonte/filtres | ✅ **prod** (facettes, recherche avancée, multi-biblio) + 📦 multi-mots (1a) |
| #OPAC5 tags | 🟡 **partiel** — `assuntos` en chips cliquables ✅ ; **tags contributifs (folksonomie) ouverts** (décision communauté/vie privée) |
| #OPAC11 RSS | ⚪ **différé** anti-tracking (partage lien/courriel livré à la place) |
| #152 proches-doublons | facette **catalogage** ✅ (12/06) ; **facette OPAC lecteur·rice ouverte** |

→ **#14 #CATALOG-EXT** n'est plus « partiel avancé » mais **quasi complet**.

---

## 1. Macro-chantiers — statuts

| # | Macro-chantier | Statut | Note |
|---|---|---|---|
| 1 | #BIBLIO | ↩︎ ✅ Clos | report v32 |
| 2 | #PAINEL | ↩︎ ✅ Clos | report v32 |
| 3 | #IMPORT | ↩︎ ⚠️ backend livré, UX à auditer | report v32 |
| 4 | #CL (carte-lecteur) | ↩︎ ✅ Clos (+ CARD-LOCAL Lot 0, suite N1-N5) | report v32 |
| 5 | #CATALOGACAO | ↩︎ ✅ Bouclé | report v32 |
| 6 | #110 mail | ↩︎ ✅ Clos | report v32 |
| 7 | #MOBILE | 🟠 socle **PWA livré 15/06** (mémoire `pwa-socle-p0`), scanner cadré ; reste P3-P5 | non re-vérifié ici |
| 8 | #NOTIFY-Painel | ↩︎ ✅ Livré | report v32 |
| 9 | #COTISATIONS | ↩︎ 🟡 Partiel (#25/#33/#36) | report v32 |
| 10 | #MM | ↩︎ 🟡 Ouvert | report v32 |
| 11 | #FED | ↩︎ 🟡 Ouvert | report v32 |
| 12 | #MODEL | ↩︎ ✅ specs implémentées | report v32 |
| 13 | #BG-PREP (sécurité) | ↩︎ 🟠 En cours — **advisors non re-sondés cette session** | cf. mémoire `secu-advisors-definer-intentional` (NE PAS revoke de masse) |
| 14 | **#CATALOG-EXT (OPAC)** | ✅ **quasi complet** (cf. §0bis) | reliquats = #OPAC5 user-tags, #OPAC11 différé, #152 facette OPAC, (1b) chemin session |
| 15 | #HYGIENE-PERF-i18n | 🟡 Partiel — **#I18N-sujets 📦 réglé en sandbox** ; rollout-10 / charte / INVENTAIRE ouverts | — |
| — | #CI / infra | ↩︎ ✅ Refondé (Forgejo + runner) | report v32 |
| — | #PARTNER notifications | ↩︎ ✅ Livré (UX à auditer) | report v32 |

---

## 2. Backlog réel — ce qui reste

### 2.1 — Frontend / terrain  ↩︎ (report v32, non re-vérifié)
- **#MOBILE** : socle **PWA livré 15/06** (mémoire `pwa-socle-p0`) ; reste scanner P2 (cadré), P3 permanence, P4 récolement, P5 push, `#MOB-QR-A4`.
- **#MM** (MM1-5), **#FED** (page + primitive `círculo`), **#LIB-SIGNUP-UI P2** (écran on/off inscriptions) — report v32.

### 2.2 — Cotisations  ↩︎ (report v32)
- **#25** cron expiration (7j/1j/J) ouvert, **#33** test blocage, **#36** CIRA Marseille, **#22** COALESCE trivial.

### 2.3 — Sécurité / Bologne  ↩︎ (report v32, **à re-sonder**)
- **#BG4** advisors (non re-sondés ici), **#BG2** sauvegardes, **#BG3** journalisation, **STR-2..5**, **#4**, **#119**, **#79** RBAC catalogage. Squash migrations (non urgent).

### 2.4 — OPAC / découverte  ✅ **quasi soldé** (cf. §0bis) — restent :
- **#OPAC5** tags contributifs (folksonomie) — 🟡 ouvert, **gated décision communauté/vie privée**.
- **#152** facette proches-doublons **côté OPAC lecteur·rice** — 🟡 ouvert (facette catalogage ✅).
- **#OPAC11** RSS — ⚪ différé anti-tracking.
- **(1b)** classement pertinence + accents — 📦 brouillon (chemin anon) ; **chemin session à écrire**.

### 2.5 — i18n / hygiène
- **#I18N-sujets** — 📦 **réglé en sandbox** (30 sujets ×10 locales ; déploiement = migration `…020228`). *(Reste à supprimer le sujet parasite `pierre-joseph-proudhon`, cf. §5.)*
- **#I18N-rollout-10**, **#I18N-charte-inclusive**, **#PERF-accountpage-split** — ↩︎ report v32 (non re-vérifiés).

### 2.6 — Reliquats cosmétiques / différés  ↩︎
- ⚪ Cosmétiques soldés 11/06. 🟡 **EA-12 ph.2** gelé (BIBLIO-9). 🟡 **#OPAC11 RSS** différé.

---

## 5. Données de découverte — état chiffré (lecture seule prod, 16-17/06)

> La longue traîne OPAC est **codée mais affamée de données**. Le gain marginal le
> plus élevé n'est plus du code mais de l'**indexation + enrichissement** (humain,
> délégué — cf. mémoires `indexation-sujets-decision`, `orphelins-autorite-decision`).

- **Indexation par sujet** : 2 673 livres au total, **1 144 indexés** (1 285 affectations, 31 sujets). Distribution ultra-concentrée : *Anarquismo* 797 (~62 %). **Côté catalogue public anon : 499 livres dont 361 (72 %) sans sujet** → facettes/nuages couvrent **~28 %** du public. → chantier **Baqueiro**.
- **Traductions du thésaurus** : avant = pt-BR 31, fr/es/en 29, **it/de/ca/nl/eo/el 0** ; **après migration sandbox = 30 sujets ×10 locales** (termes rares de/nl/eo/el à faire relire natif).
- **Enrichissement auteur** (donnée derrière le code (2)) : `variant_forms` **13/1316** (→ **22** avec les 9 du sandbox) ; `structured_meta` : affiliation 5, activityPeriod 5, activityPlace 4, pseudonyms 1. **Code prêt, couverture ~1-2 %.** Seuls **22 auteur·rices ont un `wikidata_id`** (automatisable) ; au-delà = **identification** (Baqueiro).
- **Qualité de données (sujets)** : **`pierre-joseph-proudhon`** = sujet parasite (personne-comme-sujet, libellé « Pierre-Joseph Proudhon ; », 0 livre) → **à SUPPRIMER (catalogage)** ; **`anarcocomunismo`** 0 livre (vérifier).

---

## 3. Dérive documentaire à résorber (méta)
1. **`INDEX.md`** → pointer **v33** ; **`git mv` v32 → `archive/`** (règle #11) à l'intégration.
2. **`INVENTAIRE.md`** / specs — report v32.
3. **ce backlog** : règle #12 — items OPAC soldés annotés ci-dessus avec renvoi aux migrations sandbox.

---

## 4. Réserves — ce que la base ne prouve pas
- Clôtures **⚠️ backend seul** (#IMPORT, PARTNER, PEB/ILL-digital) : surface backend tourne, **UX/terrain non audité** — report v32.
- **(1b)** : requête de classement validée read-only, mais **enrobage RPC + grants + perfs + chemin session = à éprouver sur branche** avant déploiement (touche la chaîne de visibilité du catalogue → risque de fuite réseau/BTL si mal câblé).
- Items marqués **↩︎ report v32** : **non re-vérifiés** cette session — la session a porté sur la **longue traîne OPAC** et ses dépendances (fiche livre/auteur, indexation, traductions, enrichissement).

---

*Backlog v33 — 17 juin 2026. Reporte le v32 (12/06). Audit longue traîne OPAC +
5 livrables de session (sandbox hors worktree, à intégrer). Base prod vérifiée
`uflwmikiyjfnikiphtcp`. Ce qui fait doctrine est au REGISTRE (`../specs/REGISTRE_decisions.md`).*
