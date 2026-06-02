---
Genre : référence
Statut : 🟡 cadrée (brouillon — 12 arbitrages à trancher)
Décisions : incarne MAP-A..MAP-L (ouverts) ; cite DOC-I18N-1, DOC-RPC-3, DOC-PERIM-1
Supersédé par : —
---

# Spec — Cartographie du réseau AnarBib

**Version :** 0.1 (squelette d'arbitrages)
**Date :** 27/05/2026
**Statut :** brouillon — arbitrages à trancher
**Auteur·ices :** Xavier (collectif AnarBib)
**Précédents :** carte uMap externe `coletivos-libertarios-com-biblioteca-do-mundo` (121 lieux, 24 pays, mai 2026) ; fichier de données `anarbib_bibliotheques_libertaires.geojson` ; document `AnarBib_recensement_bibliotheques_libertaires.docx`

---

## 0. Objet et contexte

### 0.1 Pourquoi cette spec

La phase de recensement (mai 2026) a produit une carte uMap publique et un fichier de données GeoJSON/CSV répertoriant 121 bibliothèques, archives et centres de documentation libertaires dans 24 pays. Cette carte uMap a rempli son rôle de **première amorce** — préparation de la présentation de Bologna (FICEDL, septembre 2026), démonstration d'existence du réseau, accumulation initiale des données.

Pour la suite, elle présente trois limites structurelles :

1. **Mono-langue.** uMap ne traduit pas le contenu des données. La carte actuelle est en français (langue de travail du recensement), ce qui exclut six des sept publics-cibles d'AnarBib (pt-BR, es, en, it, de, et le pivot pt-BR).
2. **Source de vérité externalisée.** Les données vivent dans un GeoJSON statique réimporté manuellement à chaque mise à jour. Les bibliothèques membres ne peuvent pas mettre à jour leur propre fiche. La carte peut diverger de la réalité du réseau sans qu'on le remarque.
3. **Pas d'intégration avec AnarBib.** Pour un bibliothécaire authentifié dans AnarBib, la carte est un site externe ; aucune interaction métier (PEB, recherche de fonds par langue, identification de bibliothèques sœurs) n'est possible.

Cette spec définit l'architecture cible d'une cartographie pleinement intégrée à AnarBib, articulant **une carte publique externe** (communication, sympathisants, visiteurs) et **un onglet interne au SIGB** (outil de travail pour bibliothécaires et lecteurs membres).

### 0.2 Principes directeurs (non négociables)

- **Une seule source de vérité** : les données vivent dans Supabase. La carte publique et l'onglet interne sont deux vues d'une même réalité.
- **Compatibilité octolingue** : tout champ visible par l'utilisateur final doit pouvoir s'afficher dans les **8 locales** actuelles (pt-BR, fr, es, it, de, en, ca, eo ; cf. registre `DOC-I18N-1`), et l'architecture doit anticiper l'ajout de futures langues sans refonte.
- **Autonomie des collectifs** : chaque bibliothèque membre doit pouvoir éditer sa propre fiche cartographique depuis son interface AnarBib, sans intermédiaire centralisateur, en cohérence avec la définition du membre actée le 27/05/2026 (cf. §0.3).
- **Cohérence avec la doctrine RPC v3** : toute écriture passe par une RPC dédiée ; les lectures simples peuvent utiliser `supabase.from()` avec RLS.
- **Pas de drift identitaire** : la carte est un commun en construction, pas une vitrine ; elle reflète l'extension réelle du réseau, pas une projection marketing.

### 0.3 Définition du membre (actée 27/05/2026)

> Est membre du réseau le collectif ou la bibliothèque dont les données sont **réellement entrées dans la base de données d'AnarBib**. L'adhésion se constate à un fait matériel et vérifiable — la présence dans la base — et non à la signature d'une charte. Chaque membre reste libre de définir son propre axe de fédération et son mode d'apparition publique.

Cette définition a une conséquence directe sur la cartographie : **la base AnarBib est la source de vérité du statut de membre**, la carte n'en est qu'une vue. Cette spec doit garantir que les deux ne peuvent pas diverger.

---

## 1. Modèle de données

### 1.1 Arbitrage A — Localisation des données cartographiques

**Question** : où vivent les coordonnées GPS et les métadonnées cartographiques (catégorie, statut, etc.) ?

**Option A1** — Enrichir la table `libraries` existante avec des champs `lat`, `lon`, `categorie`, `statut_public`, `notes_carte`, etc.
- ➕ Pas de double-saisie pour les membres
- ➕ Cohérence forte : une bibliothèque = une ligne
- ➖ Pollue la table métier avec des champs qui ne concernent que la cartographie
- ➖ Comment représenter les 120 lieux non-membres (« cibles ») qui figurent sur la carte sans être dans AnarBib ?

**Option A2** — Créer une table dédiée `cartography_entries` séparée, avec relation optionnelle vers `libraries`.
- ➕ Séparation propre des préoccupations
- ➕ Permet de cartographier des lieux non-membres sans les promouvoir
- ➕ Schéma cartographique évoluable sans impacter le métier
- ➖ Double-saisie potentielle pour les membres si pas de mécanisme de jointure
- ➖ Risque de désynchronisation (adresse modifiée dans `libraries` mais pas dans `cartography_entries`)

**Option A3** — Table dédiée `cartography_entries`, avec **inheritance** : pour un membre, la fiche cartographique référence l'ID `libraries` et hérite des champs partagés (nom, adresse) via VIEW ou trigger ; les champs spécifiquement cartographiques (lat, lon, catégorie, notes_carte) restent dans `cartography_entries`.
- ➕ Pas de double-saisie effective (le bibliothécaire édite son adresse une fois, ça se répercute)
- ➕ Séparation propre
- ➖ Complexité de jointure et de trigger
- ➖ Que se passe-t-il si un membre veut afficher sur la carte une adresse différente de son adresse postale officielle (sécurité, lieu d'activité distinct du siège) ?

**Recommandation** : **A3** est techniquement le plus propre, **A2** est le plus simple à implémenter. Le choix dépend du nombre de membres prévus à court terme. Tant que le réseau compte moins de ~20 membres, A2 suffit ; au-delà, A3 devient pertinent.

**À trancher** : _____________________________

### 1.2 Arbitrage B — Modèle i18n des contenus cartographiques

**Question** : comment traduire les champs `notes`, `anarbib_label`, et catégories pour les 8 locales ?

**Option B1** — Tout en pt-BR (langue pivot), interface AnarBib en langue locale mais contenu cartographique mono-langue.
- ➕ Trivial à implémenter, zéro effort de traduction
- ➖ Incohérent avec l'identité octolingue d'AnarBib
- ➖ Un utilisateur français de la carte interne lit du pt-BR — c'est régression par rapport à l'uMap actuelle

**Option B2** — Champs JSONB multilingues : `notes_i18n` contient `{"pt-BR": "...", "fr": "...", "es": "...", ...}`.
- ➕ Cohérent avec le pattern AnarBib existant (cf. `signature_short_i18n` chantier mail 18/05)
- ➕ Affichage simple côté front : `notes_i18n[currentLocale] || notes_i18n[default_locale]`
- ➖ 121 fiches × 8 langues = 968 traductions à produire et à maintenir
- ➖ Chaque ajout futur multiplie le travail par 8

**Option B3** — Table de traductions séparée `cartography_translations(entry_id, locale, field, value)`.
- ➕ Évolutif (ajouter une langue = ajouter des lignes, pas modifier le schéma)
- ➕ Permet une traduction collaborative (chaque locale peut être traduite par une personne différente)
- ➖ Plus complexe en lecture (JOIN systématique)
- ➖ Volume de lignes important (968+ pour démarrer)

**Option B4** — Approche hybride : les champs **structurants** (catégorie, statut_anarbib, langue du fonds) traduits humainement via dictionnaires i18n applicatifs ; les **notes éditoriales** laissées en langue d'origine, avec une mention claire de la langue. Chaque collectif rédige ses notes dans la langue qu'il choisit.
- ➕ Effort de traduction réduit à l'essentiel
- ➕ Respecte l'autonomie linguistique des collectifs (cohérent avec l'autonomie d'apparition publique)
- ➕ Authenticité : les notes restent dans la voix du collectif
- ➖ Expérience utilisateur dégradée pour les utilisateurs qui ne lisent pas la langue source
- ➖ Demande un champ `notes_locale` pour signaler la langue d'origine

**Recommandation** : **B4** est conceptuellement le plus juste pour le projet (il assume la nature plurilingue de fait du mouvement libertaire international). **B2** est techniquement le plus simple si on accepte une dépendance forte à la traduction automatique pour les ajouts futurs (DeepL ou équivalent en assistance, validation humaine). **B3** est sur-ingéniering tant que le réseau n'est pas plus large.

**À trancher** : _____________________________

### 1.3 Schéma proposé (sous réserve d'arbitrage A et B)

Hypothèse : A2 (table dédiée) + B4 (i18n hybride).

```sql
-- Table principale
CREATE TABLE cartography_entries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  library_id UUID REFERENCES libraries(id) ON DELETE SET NULL,  -- lien optionnel
  nom TEXT NOT NULL,
  collectif TEXT,
  pays TEXT NOT NULL,
  ville TEXT NOT NULL,
  adresse TEXT,
  lat NUMERIC(8,5) NOT NULL,
  lon NUMERIC(8,5) NOT NULL,
  categorie TEXT NOT NULL CHECK (categorie IN
    ('biblioteca','arquivo','centro_documentacao','ateneu','livraria','espaco_misto')),
  statut_anarbib TEXT NOT NULL DEFAULT 'cible' CHECK (statut_anarbib IN
    ('membre','partenaire','cible')),
  statut_public BOOLEAN NOT NULL DEFAULT FALSE,  -- visible sur carte publique externe ?
  statut_geo TEXT NOT NULL DEFAULT 'ville' CHECK (statut_geo IN ('precis','ville')),
  reseau TEXT,
  langue_fonds TEXT[],  -- ex: ['fr','es','it']
  notes TEXT,            -- texte libre dans la langue d'origine
  notes_locale TEXT NOT NULL DEFAULT 'pt-BR',  -- langue dans laquelle 'notes' est rédigé
  site_url TEXT,
  email TEXT,
  tel TEXT,
  source TEXT,           -- origine de l'info (utile pour audit)
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_by UUID REFERENCES auth.users(id)
);

-- Table catégories (libellés i18n applicatifs)
-- Pas en base : les libellés des 6 catégories vivent dans le i18n applicatif côté front
-- (cf. anarbib_i18n_types.json déjà existant). Idem pour statut_anarbib.

-- RLS
ALTER TABLE cartography_entries ENABLE ROW LEVEL SECURITY;
-- Lecture publique uniquement pour statut_public = true
CREATE POLICY cartography_public_read ON cartography_entries FOR SELECT
  TO anon, authenticated USING (statut_public = true);
-- Membres authentifiés peuvent lire tout
CREATE POLICY cartography_member_read ON cartography_entries FOR SELECT
  TO authenticated USING (true);
-- Édition réservée à la coordination réseau et au membre lié (sa propre fiche)
-- via RPC dédiées (cf. §3)
```

**Points d'attention** :
- `statut_public` est distinct de `statut_anarbib` : une bibliothèque membre peut choisir de ne pas apparaître sur la carte publique externe (autonomie d'apparition publique, cf. définition du membre).
- `library_id` est nullable : permet de cartographier les 120 lieux non-membres actuels sans les inscrire dans la table `libraries`.
- `source` est essentiel pour la qualité documentaire : « FICEDL », « visite terrain », « auto-déclaration par le collectif », etc.

---

## 2. Interfaces

### 2.1 Carte publique externe

**Public** : sympathisants, militants d'autres réseaux, journalistes, visiteurs occasionnels, public découvrant AnarBib à Bologna ou ailleurs.

**Vocation** : montrer l'existence du réseau, sa nature, son extension géographique. Permettre de trouver une bibliothèque proche.

**Caractéristiques** :
- Pas d'authentification
- Lecture seule
- Affiche uniquement les fiches avec `statut_public = true`
- Filtre clair entre **réseau AnarBib** (membres + partenaires) et **paysage libertaire mondial** (toutes catégories confondues)
- I18n côté navigateur : la locale détectée détermine la langue d'interface
- Performance : doit se charger vite, doit fonctionner sur mobile

#### Arbitrage C — Hébergement de la carte publique

**Option C1** — Intégrée au SPA AnarBib (`app.anarbib.org`), route publique sans authentification.
- ➕ Une seule application à maintenir
- ➕ Partage immédiat du code i18n et des composants
- ➖ Charge un SPA React lourd pour un visiteur qui veut juste voir une carte
- ➖ SEO médiocre (SPA = mauvaise indexation par défaut)

**Option C2** — Sous-domaine dédié `carte.anarbib.org` ou `cartografia.anarbib.org`, site statique séparé.
- ➕ Léger, SEO correct, URL parlante
- ➕ Peut être hébergé sur Codeberg Pages avec le frontend
- ➖ Maintenance de deux codes
- ➖ Duplique le système i18n

**Option C3** — Page statique servie depuis le SPA mais pré-rendue (SSG).
- ➕ Compromis entre les deux
- ➖ Complexité de build supplémentaire

**Recommandation** : **C2** si la carte publique est un objet de communication majeur (présentation à Bologna, partage sur réseaux). **C1** si elle reste un complément.

**À trancher** : _____________________________

### 2.2 Onglet interne AnarBib

**Public** : bibliothécaires et lecteurs membres authentifiés.

**Vocation** : outil de travail. Identifier des bibliothèques sœurs, faciliter le PEB, voir l'extension du réseau, éditer sa propre fiche cartographique.

**Caractéristiques** :
- Authentification requise
- Lecture de toutes les fiches (membres, partenaires, cibles)
- Édition de sa propre fiche (pour les bibliothécaires de bibliothèques membres)
- Édition de toutes les fiches (pour la coordination réseau)
- I18n native via le système AnarBib existant
- Filtres avancés (catégorie, langue du fonds, distance, statut PEB actif, etc.)
- Lien direct vers la fiche bibliothèque (catalogue, contact) pour les membres

### 2.3 Carte uMap actuelle

**Question** : que devient la carte uMap actuelle (`coletivos-libertarios-com-biblioteca-do-mundo`) après la mise en place de la cartographie intégrée ?

**Options** :
- L1 : la conserver en parallèle comme « vue archivée » de la phase de recensement, ne plus la mettre à jour
- L2 : la supprimer une fois la carte publique externe en ligne
- L3 : la maintenir comme alternative basse-technologie (pour les bibliothèques ou militant·es préférant uMap à un site AnarBib)

**Recommandation** : **L1** est le plus respectueux du travail accompli et n'a aucun coût. La carte uMap reste une trace de cette phase, à mentionner dans les comm' rétrospectivement.

**À trancher** : _____________________________

---

## 3. Doctrine d'édition et droits

### 3.1 Qui peut éditer quoi

**Hypothèse de travail** à valider :

| Type d'utilisateur          | Lecture                | Création | Édition                     | Suppression |
|-----------------------------|------------------------|----------|-----------------------------|-------------|
| Anon (visiteur public)      | Fiches `statut_public` | ✗        | ✗                           | ✗           |
| Lecteur authentifié AnarBib | Toutes les fiches      | ✗        | ✗                           | ✗           |
| Bibliothécaire d'une bibli  | Toutes les fiches      | ✗        | Sa propre fiche uniquement¹ | ✗           |
| Coordination réseau (RBAC)  | Toutes les fiches      | ✓        | Toutes                      | Toutes      |

¹ « Sa propre fiche » = fiche `cartography_entries` dont `library_id` correspond à la bibliothèque du bibliothécaire.

**Question subsidiaire** : que se passe-t-il si une bibliothèque membre veut **retirer** sa fiche de la carte publique (passer `statut_public` à `false`) ? Doit-elle pouvoir le faire seule, ou doit-elle passer par la coordination ? L'autonomie d'apparition publique (cf. définition du membre) plaide pour l'autonomie totale du collectif sur ce booléen.

**Arbitrage D — Validation des modifications** :
- D1 : édition libre par le bibliothécaire, sans validation (autonomie totale)
- D2 : édition libre, mais notification à la coordination (transparence sans contrôle)
- D3 : édition soumise à validation par la coordination réseau (cohérent avec la doctrine cooptation/admin réseau)

**Recommandation** : **D1** pour les champs identitaires du collectif (nom, notes, statut_public, langues du fonds, site, email) ; **D3** pour les champs structurants partagés (coordonnées GPS, catégorie) qui touchent à la cohérence de la carte. À discuter.

**À trancher** : _____________________________

### 3.2 RPC nécessaires (doctrine RPC v3)

```
rpc.cartography_create_entry(payload)
  → coordination réseau uniquement
rpc.cartography_update_self(entry_id, payload)
  → bibliothécaire d'une bibliothèque membre, sur sa propre fiche
rpc.cartography_update_admin(entry_id, payload)
  → coordination réseau
rpc.cartography_toggle_public(entry_id, new_value)
  → bibliothécaire d'une bibliothèque membre, sur sa propre fiche
rpc.cartography_delete(entry_id)
  → coordination réseau uniquement
```

Lectures via `supabase.from('cartography_entries').select()` avec RLS.

---

## 4. Migration depuis le GeoJSON existant

### 4.1 État de départ

Le fichier `anarbib_bibliotheques_libertaires.geojson` (121 fiches, 24 pays) constitue le matériau de départ. Il a été constitué entre mai 2026 (recensement) et est documenté dans `AnarBib_recensement_bibliotheques_libertaires.docx`.

### 4.2 Stratégie de peuplement

**Phase 0** — sauvegarde et documentation :
- Archiver le GeoJSON et le DOCX dans `docs/cartographie/` du dépôt
- Acter la définition du membre dans `docs/decisions/`

**Phase 1** — création du schéma et import initial :
- Migration SQL pour créer `cartography_entries`
- Script d'import des 121 fiches depuis le GeoJSON (avec `statut_public = true` par défaut, sauf décision contraire)
- Aucune fiche n'est marquée `library_id` à ce stade (sauf la BLMF qui correspond à une bibliothèque membre existante)

**Phase 2** — réconciliation avec les bibliothèques membres :
- Pour chaque bibliothèque dans la table `libraries`, recherche manuelle de correspondance dans `cartography_entries`
- Liaison via `library_id` si match avéré
- Notification au bibliothécaire pour qu'il valide/édite sa fiche

**Phase 3** — ouverture de l'édition aux bibliothécaires :
- Composant React d'édition de fiche cartographique dans l'interface AnarBib
- Notification email aux bibliothécaires des bibliothèques membres
- Période de transition de quelques semaines pour que chaque collectif s'approprie sa fiche

**Phase 4** — mise en ligne de la carte publique externe :
- Une fois les fiches consolidées
- Marketing minimal mais à temps pour Bologna si calendrier le permet

### 4.3 Calendrier

**À discuter — questions ouvertes** :
- Bologna FICEDL est en septembre 2026. La carte intégrée doit-elle être prête à ce moment ? Ou la carte uMap actuelle suffit-elle pour Bologna et la carte intégrée arrive plus tard ?
- Quel calendrier réaliste compte tenu des autres chantiers en cours (Chantier-cadre Biblioteca, consultations phases 3-6, migration Resend, #114) ?

**Recommandation** : **ne pas viser Bologna pour la carte intégrée**. La carte uMap est suffisante pour la présentation FICEDL. La cartographie intégrée est un chantier post-Bologna, à inscrire dans la séquence longue (Biblioteca → Importações → Catalogação). Une fenêtre raisonnable pour la phase 1 (schéma + import) serait fin 2026 / début 2027.

**À trancher** : _____________________________

---

## 5. Questions non résolues

Liste des points qui méritent réflexion mais qui ne bloquent pas la première itération :

1. **Moteur cartographique côté front** : Leaflet (libre, mature, simple) vs MapLibre GL (plus moderne, plus lourd). Décision technique, peu structurante.
2. **Fond de carte** : OpenStreetMap (cohérent avec le reste de l'écosystème AnarBib) — quasi acté par défaut, mais à confirmer.
3. **Géocodage** : qui transforme une adresse en lat/lon quand un bibliothécaire saisit sa fiche ? Nominatim (OSM) en self-hosted ? Service tiers (à risque vis-à-vis de la doctrine anti-tracking, cf. migration Brevo → Resend) ?
4. **Affichage des lieux non-membres** : la décision politique de continuer à les afficher (utilité documentaire) ou de ne montrer que le réseau (lisibilité du projet) reste à trancher. Mon avis : les deux, avec un filtre clair.
5. **Vue spécifique « Réseau AnarBib »** : icône distincte pour les membres (logo AnarBib), comme dans l'uMap actuelle ? À conserver.
6. **Articulation avec le module PEB** (#114 et suites) : la carte interne devrait-elle indiquer le statut PEB de chaque bibliothèque (PEB actif, PEB suspendu, pas de PEB) ? Probablement oui, mais c'est une dépendance à formaliser.
7. **Auto-déclaration nouvelle bibliothèque** : faut-il un parcours public « ma bibliothèque n'est pas sur la carte, je veux l'ajouter » ? Cohérent avec la nature ouverte du projet, mais ouvre des questions de modération.

---

## 6. Récapitulatif des arbitrages à trancher

| Réf. | Sujet                          | Options    | Recommandation | Décision |
|------|--------------------------------|------------|----------------|----------|
| A    | Localisation des données       | A1/A2/A3   | A2 court terme, A3 si croissance | _____ |
| B    | Modèle i18n des contenus       | B1/B2/B3/B4 | B4             | _____ |
| C    | Hébergement carte publique     | C1/C2/C3   | C2             | _____ |
| D    | Validation des modifications   | D1/D2/D3   | D1 + D3 hybride | _____ |
| L    | Sort de la carte uMap actuelle | L1/L2/L3   | L1             | _____ |
| —    | Calendrier (Bologna ou post-)  | —          | Post-Bologna   | _____ |

---

## 7. Documents liés

- `docs/decisions/DEFINITION_MEMBRE_2026-05-27.md` *(à créer)*
- `docs/cartographie/anarbib_bibliotheques_libertaires.geojson` *(à archiver)*
- `docs/cartographie/AnarBib_recensement_bibliotheques_libertaires.docx` *(à archiver)*
- `docs/specs/spec-administrateur-reseau-v0_4.md` (articulation droits)
- `docs/specs/spec-gouvernance-roles.md` (RBAC coordination réseau)
- Doctrine RPC v3 actée 21/05/2026

---

**Fin v0.1 — squelette d'arbitrages.**
