# Spec — Onboarding `/criar-conta`

**Version :** 0.2
**Date :** 2026-05-20
**Auteur·rice :** Xavier (AnarBib)
**Statut :** Brouillon de cadrage, à relire à froid puis à valider avant exécution
**Périmètre :** Restructuration de la page `/criar-conta` pour clarifier les usages possibles d'un compte AnarBib et lever l'ambiguïté actuelle entre exploration libre et action sur un catalogue.

**Historique :**
- v0.1 (2026-05-20) — première rédaction, 9 décisions cadrées dont 6 validées d'emblée et 3 en suspens (D7 cible du lien explorer, D8 stockage cas orpheline et migration CHECK, D9 ordre des paquets).
- v0.2 (2026-05-20) — D7 résolu (option 2 : route provisoire + galerie type RebAL en chantier dédié phase 2) ; D8 résolu (piste A : pas de claim en v0.1, rattachement automatique reporté en phase 2) ; ajout §4.6 privacy notice ; D9 validé.

---

## 1. Contexte et cas motivant

### 1.1 Le cas Karina (18/05/2026)

Le 18 mai 2026 à 20:42 UTC, une personne (ci-après *K.*) crée un compte sur AnarBib en pt-BR. La séquence backend est propre :

- 20:42:37 — compte `auth.users` créé, email confirmé
- 20:43:55 — profil rempli (`consent_email = true`, téléphone E.164, gender)
- 20:44:24 — première connexion
- 20:46:52 — changement de mot de passe (fin onboarding)

À partir de 20:46, plus rien. Aucune trace dans `library_membership_audit`, aucun membership créé (même `inactive` ou `removed`), aucune `library_request` soumise, aucune nouvelle connexion dans les 48h qui suivent.

K. avait évoqué en discussion un intérêt pour la **Biblioteca Terra Livre de São Paulo**. Elle n'apparaît dans aucun membership BTL.

### 1.2 Diagnostic

L'absence totale de trace technique post-onboarding écarte l'hypothèse d'une cassure de parcours (un bug aurait typiquement laissé une trace partielle, ou aurait provoqué une seconde tentative de connexion). L'hypothèse retenue est un **arrêt volontaire** :

> *« Je n'ai pas choisi de bibliothèque pour ne pas faire une bêtise en créant une fausse demande d'adhésion. »*

Cette hypothèse est cohérente avec deux indices : (i) K. a accepté `consent_email` une minute après création — comportement de quelqu'un qui lit avant de cliquer ; (ii) elle n'est pas revenue, ce qui distingue son cas d'une frustration technique (typiquement suivie de retry).

### 1.3 Cause structurelle

La page `/criar-conta` actuelle présente **un sélecteur de bibliothèque obligatoire** comme premier choix, sans :

- expliquer que la consultation des catalogues publics ne nécessite pas de compte ;
- distinguer clairement les usages légitimes d'un compte (action sur catalogue d'une biblio active vs ouverture d'une nouvelle biblio vs cas intermédiaires) ;
- offrir une porte de sortie pour quelqu'un qui voudrait juste explorer.

L'option « sem biblioteca / solicitar criação » (valeur sentinelle `__solicitar__` dans le code) couvre actuellement **deux cas sémantiquement distincts** mais sans les distinguer :

- collectif candidat qui veut ouvrir une bibliothèque sur AnarBib ;
- lectrice/lecteur d'une bibliothèque qui n'est pas (encore) sur AnarBib.

Ces deux cas ont des flux radicalement différents (dossier candidat vs simple compte en attente) mais reçoivent aujourd'hui le même traitement (CTA vers `/solicitar-biblioteca?claim=<token>` dans le mail post-inscription).

---

## 2. Doctrine cadrante

### 2.1 À quoi sert un compte AnarBib

**Doctrine v0.1 (stricte) :** un compte AnarBib sert exclusivement à **agir sur un catalogue** :

- comme lectrice/lecteur d'une bibliothèque membre du réseau (réserver, consulter sur place, emprunter, proposer une donation) ;
- comme membre de l'équipe d'une bibliothèque (librarian, coordenador·a) — cas qui passe par un flux invitation distinct (voir §2.4) ;
- comme représentant·e d'un collectif candidat qui ouvre une nouvelle bibliothèque sur AnarBib.

**Hors périmètre v0.1, à creuser ultérieurement (backlog) :** usages « latéraux » sans biblio (favoris/liste d'envies sur catalogues publics, suivi de plusieurs biblios sans en être lectrice). Cette piste a été évoquée pour la première fois lors de la session du 20/05/2026 ; elle n'est pas exclue mais n'est pas instruite ici.

### 2.2 Ce qui ne nécessite pas de compte

**Consultation des catalogues publics** : libre. Les bibliothèques qui ont choisi de rendre leur catalogue public sont consultables comme une vitrine de magasin. Cette information doit apparaître **avant** toute proposition de création de compte, sur la page `/criar-conta` elle-même, sous forme d'un bandeau explicite avec lien sortant.

La cible définitive de ce lien sortant est une **page galerie multi-bibliothèques inspirée du site RebAL** (cf. §3.3), hébergée sur le site de présentation `anarbib.org`. Cette page constitue un chantier dédié de phase 2 (cf. §7.4).

En v0.1, le lien pointe vers une **route minimale provisoire** dans l'app AnarBib (cf. §3.3).

### 2.3 Trois cas de figure dans le sélecteur

Le sélecteur de bibliothèque de `/criar-conta` propose trois grandes familles de choix, dans cet ordre :

1. **Une bibliothèque active de la liste** — la personne veut devenir lectrice/lecteur de cette bibliothèque. Sa demande sera transmise à l'équipe pour validation.
2. **« Quero abrir uma nova biblioteca no AnarBib »** — collectif candidat. Flow vers `/solicitar-biblioteca` (dossier d'ouverture).
3. **« Sou leitor·a de uma biblioteca que ainda não está no AnarBib »** — *lectrice orpheline*. Création d'un compte en attente, mail explicatif, possibilité d'explorer les catalogues publics en attendant. Pas de dossier candidat.

### 2.4 Hors périmètre `/criar-conta` : le cas équipe

**Le cas « je fais partie de l'équipe d'une bibliothèque existante » ne passe PAS par `/criar-conta`.**

Ce choix est délibéré et reflète la doctrine politique d'AnarBib :

- une bibliothèque militante anarchiste constitue son équipe par cooptation, pas par auto-candidature web ;
- la grammaire « les bibliothèques sont premières, les comptes sont leur conséquence » doit être visible dans le parcours ;
- la cohérence avec `spec-administrateur-reseau.md` v0.3 (cooptation collective unanime) et `spec-gouvernance-roles.md` (RPCs `fn_team_*`, événements `team.*`) impose un flux invitation distinct ;
- techniquement, le flux équipe légitime est : une coordenadora ou un·e librarian invite quelqu'un depuis `painel`, AnarBib envoie un mail avec lien magique, la personne clique → son compte se crée *ou* s'enrichit (si elle en avait déjà un comme lectrice), et le membership équipe est créé avec status `active`.

Conséquence pratique : si quelqu'un de l'équipe d'une biblio existante atterrit sur `/criar-conta` par erreur, il/elle s'inscrit comme lectrice. La régularisation se fait ensuite via le flux invitation côté coordenadora.

---

## 3. Spécification fonctionnelle de la page

### 3.1 Structure de la page (du haut vers le bas)

#### Bloc A — Bandeau « vitrine »

Position : tout en haut, après le titre et le sous-titre, **avant** le sélecteur de bibliothèque.

Contenu (pt-BR canonique) :

> **Você não precisa de uma conta para explorar.**
> Os catálogos das bibliotecas que escolheram torná-los públicos podem ser consultados livremente, como uma vitrine. Crie uma conta apenas se você quiser **agir** sobre um catálogo : reservar uma obra, consultar no local, pegar emprestado, ou propor uma doação.
>
> [→ Explorar os catálogos públicos]

Le lien sortant pointe vers la route provisoire `/explorar` (cf. §3.3).

#### Bloc B — Sélecteur de bibliothèque (restructuré)

Position : juste après le bandeau vitrine.

Structure du `<select>` :

```
<placeholder>
─── Bibliotecas no AnarBib ───
  Biblioteca Terra Livre — Biblioteca Terra Livre (São Paulo)
  CIRA Marseille — CIRA (Marseille)
  […]
─── Outros casos ───
  Quero abrir uma nova biblioteca no AnarBib
  Sou leitor·a de uma biblioteca que ainda não está no AnarBib
```

Les deux séparateurs visuels (`─── … ───`) regroupent visuellement la liste active vs les deux cas particuliers, sans forcer de logique de scroll/ouverture supplémentaire.

#### Bloc C — Encadré contextuel selon le choix

- **Si une bibliothèque active est choisie** : affichage du logo + bandeau « Você está pedindo para se tornar leitor·a de [Nom]. Sua inscrição será validada pela equipe da biblioteca. » + acceptation du regimento si pertinent (comportement actuel).
- **Si « abrir uma nova biblioteca » est choisi** : encadré orangé « Você representa um coletivo que quer abrir uma biblioteca no AnarBib. Após criar sua conta, você receberá um mail com um link para preencher o dossiê de candidatura. »
- **Si « leitor·a de uma biblioteca não-AnarBib » est choisi** : encadré bleuté avec un **champ texte libre optionnel** « Qual é a sua biblioteca ? (opcional) » + texte « Após criar sua conta, você receberá um mail explicativo. Você poderá explorar livremente os catálogos públicos enquanto sua biblioteca não aderir ao AnarBib. »

#### Blocs D-F — Reste du formulaire

Inchangé : nom, prénom, email, téléphone, gender, adresse, RGPD, consentement email. Le bloc « bibliothèque de rattachement » ne s'affiche qu'en présence d'une bibliothèque active choisie (logique actuelle).

### 3.2 Comportement après soumission

| Cas | `signup_intent` | Mail envoyé | CTA dans le mail |
|---|---|---|---|
| Bibliothèque active choisie | `'reader_pending'` | Bienvenue + en attente de validation | Lien vers `/conta` |
| Abrir nova biblioteca | `'collective_candidate'` | Bienvenue + dossier candidat | Lien `/solicitar-biblioteca?claim=<token>` |
| Lectrice orpheline | `'reader_orphan'` | Bienvenue + explication + invitation à parler à sa biblio | Liens vers `/explorar` + `/sobre-anarbib` |

### 3.3 Route provisoire `/explorar` (v0.1)

La route `/explorar` est une **route transitoire** dans l'app `app.anarbib.org`. Elle existe pendant la période séparant la livraison de cette spec et la livraison de la galerie multi-bibliothèques sur `anarbib.org` (chantier dédié, cf. §7.4).

**Contenu minimal de la route :**

- Bandeau d'introduction : « Catálogos públicos das bibliotecas no AnarBib »
- Liste simple en prose des bibliothèques dont le catalogue est public, avec pour chacune : nom, ville, lien direct vers son catalogue dans l'app (route `/catalogo/{slug}` ou équivalent à confirmer)
- Pas de carte, pas de chiffres, pas de badge — du texte propre suffit
- Lien en bas de page : « Quer saber mais sobre o projeto AnarBib ? [anarbib.org] »

**Source de données :** vue déjà existante `api.libraries_public_v1` (filtrée par la doctrine `fn_library_visible_to_caller`), ou nouvelle vue dédiée si besoin de filtrer plus finement (bibliothèques qui ont *explicitement* rendu leur catalogue public, pas juste leur fiche). À cadrer en paquet 3.

**Migration vers la cible définitive :** quand la galerie sur `anarbib.org` sera livrée, le lien du bandeau de `/criar-conta` sera mis à jour pour pointer dessus, et la route `/explorar` côté app sera soit supprimée, soit conservée comme miroir technique simplifié. À trancher dans le chantier dédié.

---

## 4. Spécification technique

### 4.1 Base de données

#### 4.1.1 Nouveaux champs sur `profiles`

```sql
ALTER TABLE public.profiles
  ADD COLUMN signup_intent text,
  ADD COLUMN signup_intent_metadata jsonb DEFAULT '{}'::jsonb,
  ADD COLUMN signup_intent_set_at timestamptz;

ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_signup_intent_chk
  CHECK (signup_intent IS NULL OR signup_intent IN (
    'reader_pending',
    'reader_orphan',
    'collective_candidate'
  ));
```

`signup_intent_metadata` peut contenir :

- pour `reader_orphan` : `{ "library_name_mentioned": "Biblioteca Terra Livre" }` si la personne a renseigné le champ optionnel ;
- pour `reader_pending` : `{ "library_id": "<uuid>", "library_slug": "<slug>" }` ;
- pour `collective_candidate` : `{ "claim_id": "<uuid>" }` (référence vers `library_request_claims`).

`signup_intent_set_at` est posé au moment de la création par l'Edge Function `register`. Il ne change plus ensuite — c'est un marqueur historique, pas un état courant. L'état courant est dérivé des memberships et requests.

**Note sur `library_request_claims` :** aucune modification de cette table en v0.1. Le CHECK actuel sur `claim_purpose = 'library_request'` reste tel quel. L'introduction d'un éventuel nouveau purpose (`reader_attachment` pour le rattachement automatique des lectrices orphelines) est explicitement reportée en phase 2, avec sa propre spec (cf. §7.4). Doctrine appliquée : pas de migration cosmétique sans code consommateur immédiat.

#### 4.1.2 RLS sur les nouveaux champs

`signup_intent` et `signup_intent_metadata` doivent être :

- **lisibles par la personne elle-même** (RLS `profiles_self_select` existante doit déjà couvrir, à vérifier) ;
- **lisibles par les network_administrators** (pour pouvoir un jour contacter une lectrice orpheline si sa biblio rejoint le réseau — chantier phase 2, mais le droit de lecture doit déjà exister) ;
- **non lisibles par les coordenadores/librarians des autres bibliothèques** (pas de fuite cross-biblio) ;
- **non modifiables par la personne** après la création (read-only post-signup pour préserver la trace historique). Modification possible uniquement via RPC SECURITY DEFINER `fn_admin_clear_signup_intent` réservée aux network_administrators.

### 4.2 Edge Function `register`

#### 4.2.1 Modifications du payload entrant

Le frontend passe :

```ts
{
  // … champs actuels
  signup_intent: 'reader_pending' | 'reader_orphan' | 'collective_candidate',
  library_slug?: string,                  // si reader_pending
  orphan_library_name_mentioned?: string, // si reader_orphan, optionnel
}
```

La sentinelle actuelle `__solicitar__` est **supprimée** côté frontend. Le frontend envoie explicitement `signup_intent`.

#### 4.2.2 Logique interne (pseudocode)

```ts
switch (signup_intent) {
  case 'reader_pending':
    // 1. Créer auth.users + profiles
    // 2. Créer user_library_memberships (role='reader', status='pending')
    //    [comportement actuel - inchangé]
    // 3. Stocker signup_intent + metadata { library_id, library_slug }
    // 4. Envoyer mail "bienvenue + en attente de validation"
    break;

  case 'collective_candidate':
    // 1. Créer auth.users + profiles
    // 2. Créer library_request_claims (claim_purpose='library_request', expires +30j)
    //    [comportement actuel - inchangé]
    // 3. Stocker signup_intent + metadata { claim_id }
    // 4. Envoyer mail "bienvenue + dossier candidat" avec CTA /solicitar-biblioteca?claim=<token>
    break;

  case 'reader_orphan':
    // 1. Créer auth.users + profiles
    // 2. PAS de membership, PAS de claim
    // 3. Stocker signup_intent + metadata { library_name_mentioned? }
    // 4. Envoyer mail "bienvenue + explication orpheline" avec liens /explorar + /sobre-anarbib
    break;
}
```

#### 4.2.3 Garde-fous

- Validation côté EF : `signup_intent` doit être l'une des 3 valeurs autorisées. Sinon → 400.
- Si `signup_intent = 'reader_pending'`, alors `library_slug` doit être présent et correspondre à une biblio listée dans `v_libraries_for_signup`. Sinon → 400.
- Si `signup_intent = 'reader_orphan'`, alors `orphan_library_name_mentioned` est optionnel, longueur max 200 caractères, sanitization XSS.
- Si `signup_intent = 'collective_candidate'`, alors `library_slug` doit être absent ou vide.

### 4.3 Frontend (`CriarContaPage.jsx`)

#### 4.3.1 État local à modifier

Le state `form` ne change pas radicalement. La valeur `library_slug = '__solicitar__'` disparaît. À la place :

```js
const [form, setForm] = useState({
  signup_intent: '',           // '', 'reader_pending', 'collective_candidate', 'reader_orphan'
  library_slug: '',            // utilisé seulement si signup_intent='reader_pending'
  orphan_library_name: '',     // utilisé seulement si signup_intent='reader_orphan'
  // … reste inchangé (first_name, last_name, email, phone, gender, adresse, consents)
});
```

Le `<select>` est restructuré (cf. §3.1 bloc B). Le handler `handleLibChange` devient `handleIntentChange` et résout :

- valeur = slug d'une biblio active → `signup_intent='reader_pending'`, `library_slug=slug`
- valeur = `'_new_library'` → `signup_intent='collective_candidate'`, `library_slug=''`, `acceptRules=true` (pas de regimento)
- valeur = `'_orphan'` → `signup_intent='reader_orphan'`, `library_slug=''`, `acceptRules=true` (pas de regimento)

#### 4.3.2 Suppression du wording ambigu

- L'option actuelle `auth.create.noLibrary` ("Não tenho biblioteca / Solicitar criação") est **supprimée**. Remplacée par deux options distinctes.
- La sentinelle `__solicitar__` disparaît du code (recherche `grep` à faire dans tout le repo, attention aux usages éventuels dans `register/index.ts`).

### 4.4 Internationalisation (clés i18n × 6 locales)

Nouvelles clés à créer dans `pt-BR`, `fr`, `es`, `en`, `it`, `de` :

```
auth.create.showcase.title              # "Você não precisa de uma conta para explorar."
auth.create.showcase.body               # paragraphe du bandeau vitrine
auth.create.showcase.exploreCta         # "Explorar os catálogos públicos"

auth.create.intent.groupActiveLibraries # "─── Bibliotecas no AnarBib ───"
auth.create.intent.groupOtherCases      # "─── Outros casos ───"
auth.create.intent.optionNewLibrary     # "Quero abrir uma nova biblioteca no AnarBib"
auth.create.intent.optionOrphan         # "Sou leitor·a de uma biblioteca que ainda não está no AnarBib"

auth.create.intent.readerPending.box    # "Você está pedindo para se tornar leitor·a de…"
auth.create.intent.newLibrary.box       # encadré orangé candidat
auth.create.intent.orphan.box           # encadré bleuté lectrice orpheline
auth.create.intent.orphan.libNameLabel  # "Qual é a sua biblioteca ? (opcional)"
auth.create.intent.orphan.libNameHint   # hint sous le champ
```

Clés obsolètes à **supprimer** :

```
auth.create.noLibrary
auth.create.noLibInfo.title
auth.create.noLibInfo.body
```

Le nettoyage des 6 locales suit le pattern établi le 5 mai (156 chaînes obsolètes nettoyées après refactor formulaires d'adresse).

### 4.5 Mails (Resend, post-migration Brevo)

Trois nouveaux templates ou variantes à produire dans `_shared/mail/` :

- `welcome-reader-pending.ts` (existe probablement déjà sous un autre nom, à auditer) ;
- `welcome-collective-candidate.ts` (existe déjà comme `register-with-claim.ts` ou similaire, à renommer/clarifier) ;
- `welcome-reader-orphan.ts` (**nouveau**).

Chaque template suit la doctrine établie (`renderEmail` avec `actionBox`, recipient mail → `preferred_language`, admin copy → `ctx.default_locale`, contract `actionBox = {kind, title, ctaUrl, ctaLabel}`).

Pour `welcome-reader-orphan.ts`, contenu pt-BR :

> **Bem-vinda ao AnarBib.**
>
> Sua conta foi criada. Como você nos indicou, sua biblioteca ainda não está na rede AnarBib.
>
> Em paralelo, fale do AnarBib com a equipe da sua biblioteca. Se elas decidirem aderir, você poderá ser integrada como leitor·a com a mesma conta que você acaba de criar.
>
> Enquanto isso, você pode explorar livremente os catálogos das bibliotecas que escolheram torná-los públicos.
>
> [→ Explorar os catálogos]
>
> Para saber mais sobre o projeto AnarBib e como sua biblioteca pode aderir : [/sobre-anarbib]

`actionBox` :
```ts
{
  kind: 'action',
  title: t('mail.orphan.exploreTitle'),
  ctaUrl: `${APP_URL}/explorar`,
  ctaLabel: t('mail.orphan.exploreCta')
}
```

### 4.6 Privacy notice — incidence du champ `library_name_mentioned`

Le champ optionnel « Qual é a sua biblioteca ? » (cas `reader_orphan`) introduit une donnée déclarative supplémentaire stockée dans `profiles.signup_intent_metadata.library_name_mentioned`. Cette donnée n'est pas sensible au sens de l'art. 9 RGPD mais doit faire l'objet d'une information explicite préalable au consentement (art. 13 RGPD).

#### 4.6.1 Texte à intégrer à la page `/privacidade`

Ajouter une sous-section dédiée (pt-BR canonique) :

> **Informações declarativas opcionais**
>
> Se ao criar sua conta você nos indicou o nome de uma biblioteca que ainda não está no AnarBib, esta informação é conservada para que, se essa biblioteca aderir um dia à nossa rede, possamos lhe propor um rattachement como leitor·a.
>
> Esta informação não é compartilhada com terceiros. Ela é legível apenas pela equipe administradora da rede AnarBib. Você pode visualizar, modificar ou apagar esta informação a qualquer momento na sua conta (seção *Meus dados*).

À traduire dans les 6 locales selon doctrine inclusive établie. Total : ~6 strings × 6 locales = 36 strings.

#### 4.6.2 Exposition lecture sur `/conta`

Dans la section *Meus dados* (existante) de `/conta`, ajouter un encadré conditionnel — visible **uniquement si** `signup_intent_metadata` contient `library_name_mentioned` non vide :

> **Biblioteca mencionada na inscrição :** *Biblioteca Terra Livre*
> [→ Apagar esta informação]

Le bouton « Apagar » appelle une RPC dédiée `fn_clear_my_signup_metadata_field` (SECURITY DEFINER, INVOKER-scoped à `auth.uid()`) qui efface la clé `library_name_mentioned` du JSON metadata. Pas de suppression du `signup_intent` lui-même (qui reste un marqueur historique stable).

#### 4.6.3 Politique de rétention

Cette donnée a la même durée de vie que le compte. Suppression du compte → suppression du profile → suppression de cette donnée. Pas de durée de conservation spécifique à ajouter. Aligné sur la politique générale d'AnarBib.

#### 4.6.4 Limites

- Champ non indexé : pas de matching automatique en v0.1. Le rattachement automatique des lectrices orphelines quand une biblio rejoint est un chantier de phase 2.
- Sanitization XSS appliquée à l'entrée (Edge Function `register`) ET à l'affichage (frontend `/conta`).
- Longueur max 200 caractères, refus au-delà (côté EF et côté frontend).

---

## 5. Plan d'exécution par paquets

### Paquet 1 — Migration DB (priorité haute)

1. Migration `2026_XX_XX_profiles_signup_intent.sql` : ajout des 3 colonnes + CHECK constraint
2. RLS sur les nouveaux champs (vérifier que la policy `profiles_self_select` existante couvre, sinon en ajouter une)
3. RPC `fn_clear_my_signup_metadata_field` (SECURITY DEFINER, scoped `auth.uid()`)
4. Vérification par `DO` block dans la migration (cf. doctrine création objets sécurisés v2)

### Paquet 2 — Edge Function `register`

1. Modifier le contrat d'entrée (ajout `signup_intent`, suppression sentinelle `__solicitar__`)
2. Logique switch sur `signup_intent`
3. Garde-fous (validation 400 sur valeurs invalides)
4. Stockage `signup_intent` + `signup_intent_metadata` + `signup_intent_set_at`
5. Routage mail selon le cas
6. Tests d'intégration sur les 3 cas

### Paquet 3 — Route provisoire `/explorar`

1. Créer la route dans le frontend
2. Source de données : `api.libraries_public_v1` ou nouvelle vue filtrée selon doctrine (biblios à catalogue *explicitement* public)
3. UI minimale : liste prose, pas de cartes
4. Lien sortant vers `anarbib.org`
5. i18n × 6 locales (clés `explore.*`)

### Paquet 4 — Frontend `CriarContaPage.jsx`

1. Refactor du `<select>` (3 groupes : placeholder + biblios actives + cas particuliers)
2. State `signup_intent` + `orphan_library_name`
3. Encadrés contextuels conditionnels (3 cas)
4. Bandeau vitrine en haut de page + lien sortant vers `/explorar`
5. Suppression des références à `__solicitar__` dans tout le repo
6. Build + test prod en navigation privée

### Paquet 5 — i18n × 6 locales

1. Création des nouvelles clés (12+ clés × 6 = ~72 strings militants)
2. Suppression des clés obsolètes (3 × 6 = 18 strings)
3. Vérification doctrine inclusive (`leitor·a`, etc. selon convention par locale)

### Paquet 6 — Mail `welcome-reader-orphan`

1. Création du template avec layout standard
2. Routage dans `library-mail-routing.ts`
3. Tests d'envoi sur les 6 locales

### Paquet 7 — Privacy notice + exposition lecture `/conta`

1. Ajout de la sous-section dans `/privacidade` (~6 strings × 6 locales = 36 strings)
2. Encadré conditionnel dans `/conta` section *Meus dados*
3. Câblage du bouton « Apagar » sur `fn_clear_my_signup_metadata_field`
4. Tests : compte avec/sans `library_name_mentioned`, suppression du champ

### Paquet 8 — Tests E2E

1. Scénario "lectrice pending" (BTL)
2. Scénario "collectif candidat" (nouvelle biblio)
3. Scénario "lectrice orpheline" avec nom de biblio mentionné
4. Scénario "lectrice orpheline" sans nom de biblio mentionné
5. Suppression de `library_name_mentioned` depuis `/conta`
6. Vérification que les mails arrivent au bon format dans la bonne langue

### Paquet 9 — Régularisation du cas Karina

Hors-bande : contacter K. (si politiquement opportun et si elle a consenti à des relances) pour l'informer que le parcours a été clarifié, ou simplement la laisser revenir d'elle-même. À discuter avec Patricia FELLINI (coordenadora BTL). Pas d'action automatique côté code.

---

## 6. Risques et points d'attention

### 6.1 Migration des comptes existants

Les comptes créés **avant** cette spec n'ont pas de `signup_intent`. Ils restent à `NULL`. C'est cohérent (la colonne admet NULL). Pas de backfill nécessaire. Si on voulait reconstituer l'intent rétroactivement pour les comptes existants, il faudrait croiser `user_library_memberships` (présence → `reader_pending` ou `reader_active`) et `library_requests` (présence → `collective_candidate`). Pas dans la v0.1.

### 6.2 Cas Karina lui-même

K. a un compte sans membership, sans signup_intent (car créé avant la spec). Si elle revient, elle verra son compte fonctionner mais sans rattachement. Deux options :

- la laisser dans cet état et lui proposer dans `/conta` un encadré « Vous n'êtes rattachée à aucune bibliothèque. [Rejoindre une biblio] [Ma biblio n'est pas sur AnarBib] » ;
- backfill manuel (UPDATE direct) pour lui poser `signup_intent = 'reader_orphan'` si on sait quelle était son intention.

Recommandation : l'option 1 (UI de `/conta` qui gère gracieusement les comptes sans rattachement) est de toute façon nécessaire indépendamment de Karina, et résout son cas comme effet de bord. À traiter dans un chantier séparé sur `/conta`.

### 6.3 Risque d'allongement du select

Avec 2 nouvelles entrées sous la liste des biblios, le select peut sembler chargé. Atténuations :

- les deux séparateurs visuels (`─── … ───`) structurent la lecture ;
- l'encadré contextuel qui apparaît au choix rassure et explique ;
- les biblios actives restent en premier, ce qui correspond au cas majoritaire.

À long terme (hors v0.1), envisager une UI en deux temps : d'abord choisir le type de cas (3 boutons radio), puis seulement si pertinent afficher la liste des biblios. Pas dans cette spec.

### 6.4 Couplage avec d'autres chantiers en cours

- **Chantier #114** (`notify-event` événements `network.*`) : indépendant, pas de chevauchement.
- **Chantier Resend (#110)** : les nouveaux mails de cette spec doivent être créés directement en stack Resend (pas via Brevo), pour ne pas créer de dette à migrer.
- **Phases 3-6 consultas (#91-#94)** : indépendant.
- **LanguagePicker refactor** : indépendant.
- **Galerie multi-biblios sur `anarbib.org`** (§7.4) : *bloque la migration définitive* du lien sortant `/criar-conta` → galerie, mais ne bloque pas la livraison v0.1 (route provisoire `/explorar`).

### 6.5 Transition `/explorar` → galerie `anarbib.org`

Quand la galerie sera livrée :
- Mise à jour du lien dans le bandeau vitrine de `/criar-conta` (1 string i18n × 6 locales : la `ctaUrl` ; le label reste identique)
- Mise à jour du lien dans le mail `welcome-reader-orphan` (idem)
- Décision sur le sort de la route `/explorar` : suppression, ou conservation comme miroir technique simple. À trancher dans la spec dédiée galerie.

---

## 7. Hors périmètre, mais à inscrire au backlog

### 7.1 Doctrine 2 (usages latéraux sans biblio)

Évoquée pour la première fois le 20/05/2026. Idée : permettre à quelqu'un comme K., même sans bibliothèque de rattachement, d'avoir une utilité concrète à son compte AnarBib :

- liste d'envies sur catalogues publics ;
- suivi de plusieurs bibliothèques (notifications de nouveautés sur des catalogues qu'elle aime) ;
- contribution à la mutualisation du catalogue (signaler une donation potentielle, etc.).

À instruire à froid dans une session dédiée. Implications doctrinales fortes : ça change la définition même de ce qu'est un compte AnarBib.

### 7.2 Flux invitation équipe

Mentionné en §2.4 mais pas spécifié ici. À instruire dans une spec dédiée `spec-invitation-equipe.md` qui s'articulera avec `spec-gouvernance-roles.md`.

### 7.3 Rattachement automatique des lectrices orphelines (phase 2)

Le cas où Karina, après avoir indiqué « Biblioteca Terra Livre » dans son inscription orpheline, voit sa biblio rejoindre AnarBib 6 mois plus tard. Trois scénarios à arbitrer dans la spec dédiée :

- **Scénario A — Proposition côté admin réseau** : un network_admin voit dans son tableau de bord les lectrices orphelines dont la biblio vient de rejoindre, et peut leur envoyer un mail avec lien magique de rattachement (claim `reader_attachment`).
- **Scénario B — Détection côté `/conta`** : quand Karina se reconnecte, l'app détecte que sa biblio mentionnée est active et lui propose un encadré « Sua biblioteca agora está no AnarBib. Quer pedir para se tornar leitor·a ? ».
- **Scénario C — Hybride** : les deux mécanismes co-existent, l'un proactif (mail), l'autre passif (encadré à la connexion).

Cette spec entraînera :
- l'ouverture du CHECK `library_request_claims_purpose_chk` pour autoriser `'reader_attachment'` ;
- la spécification du flux de consommation du claim (transformation en membership avec status `pending`) ;
- la logique de matching `library_name_mentioned ↔ libraries.name` (faillible, doctrine à cadrer : exact, normalisé, fuzzy, validation humaine ?).

À traiter dans `spec-rattachement-lectrice-orpheline.md`.

### 7.4 Galerie multi-bibliothèques sur `anarbib.org`

Inspirée du site RebAL ([rebal.info/vufind/](https://rebal.info/vufind/)). Page hébergée sur le **site de présentation** `anarbib.org` (et pas dans l'app `app.anarbib.org`).

**Concept :** une galerie de cartes/cards, une par bibliothèque membre du réseau ayant rendu son catalogue public. Chaque carte présente :
- nom de la bibliothèque (titre)
- ville (avec indicateur géographique discret)
- contexte/affiliation (« Circolo Anarchico Berneri », « Archivio del movimento operaio », etc.)
- volumétrie du catalogue (« 2 746 record »)
- badge de statut technique (sur RebAL : « Automatizzato » indique les biblios avec catalogue effectivement automatisé)
- deux boutons côte à côte : **Voir le catalogue** (lien profond vers `app.anarbib.org/catalogo/{slug}` ou équivalent) et **Site web** (lien externe vers le site propre de la biblio si renseigné)

**Pourquoi sur `anarbib.org` et pas dans l'app :**
- séparation propre **présentation du projet** vs **outil de travail** ;
- valorisation de l'écosystème pour quelqu'un qui hésite à créer un compte ;
- l'app n'a pas vocation à devenir une vitrine — elle est l'outil d'action sur les catalogues ;
- politiquement : `anarbib.org` est le visage public du projet, c'est là qu'on accueille les curieuses.

**Décisions à trancher dans la spec dédiée :**
- source de données (API publique d'AnarBib ? static généré périodiquement ? hybride ?)
- granularité du « catalogue public » (toute la biblio, ou seulement certaines collections ?)
- gestion des biblios sans site web propre (cacher le bouton ? bouton désactivé ?)
- badge de statut (faut-il un équivalent du « Automatizzato » de RebAL ?)
- ordre d'affichage (alphabétique ? par ville ? par taille ? aléatoire ? par date d'adhésion ?)
- pagination ou affichage complet
- i18n (la galerie est sur le site de présentation, qui n'a peut-être pas la même infra i18n que l'app)

À traiter dans `spec-galerie-bibliotheques-anarbib-org.md`.

### 7.5 Backfill `signup_intent` pour les comptes existants

Si un jour on en a besoin (analytics, contact des lectrices orphelines quand leur biblio rejoint), prévoir un script de reconstitution à partir de `user_library_memberships` + `library_requests` + audit logs.

---

## 8. Décisions validées

| # | Décision | Choix retenu | Validé ? |
|---|---|---|---|
| D1 | Doctrine `/criar-conta` v0.1 = stricte (compte = action) | Oui | ✓ |
| D2 | Doctrine 2 (usages latéraux) reportée au backlog | Oui | ✓ |
| D3 | Cas équipe ne passe PAS par `/criar-conta` | Oui (cooptation, cohérence avec spec admin réseau) | ✓ |
| D4 | 3 cas dans le select : biblio active / nova biblio / orfã | Oui | ✓ |
| D5 | Stockage via `profiles.signup_intent` + `signup_intent_metadata` | Oui | ✓ |
| D6 | Bandeau vitrine + lien sortant en tête de page | Oui | ✓ |
| D7 | Lien sortant pointe vers route provisoire `/explorar` puis vers galerie anarbib.org (phase 2) | Oui | ✓ |
| D8 | Champ optionnel « nom de la biblio » pour orpheline + privacy notice ; pas de claim `reader_attachment` en v0.1 (reporté phase 2) | Oui | ✓ |
| D9 | Ordre des paquets : DB → EF → /explorar → frontend → i18n → mail → privacy + /conta → tests E2E → Karina | Oui | ✓ |

---

*Fin de la spec v0.2 — à relire à froid, à amender si besoin, puis à exécuter par paquets.*
