# Cadrage — Entraide au catalogage (onglet « Entraide » de la Fédération)

**Date** : 2026-06-15
**Statut** : **cadrage / projet** — réflexion exploratoire qui pose la *vision*,
l'*architecture* et les *décisions de principe*. **Ce n'est pas encore une spec à
construire** : à discuter, éprouver, puis décliner en specs.
**Socle éthique** : [`notes-audit/anarbib-charte-relationnelle-v0.1.md`](../../../notes-audit/anarbib-charte-relationnelle-v0.1.md)
(« la main tendue »). **Chaque écran ci-dessous a été passé à la grille « ça tend ou
ça saisit ? ».** Ce cadrage est, en quelque sorte, la première mise à l'épreuve
concrète de la charte.

---

## 1. Le besoin

Le catalogage est le point de douleur des biblios débutantes (cf. les chantiers
autorités, indexation matière, wizard de découverte). Une biblio seule face aux
autorités, aux sujets, à la classification, est intimidée. L'onglet « Entraide »
répond à ce besoin précis — mais le catalogage anarchiste n'est pas neutre : les
vedettes-matière mainstream pathologisent, effacent, mé-nomment. **L'entraide
transmet un *artisanat politique* que ni les standards ni une IA n'encodent.**

Principe transversal : **l'appel à l'aide est générique** (entraide sur *tout* sujet
technique épineux), le **catalogage est le premier domaine câblé**.

## 2. Trois degrés d'entraide — une échelle, par subsidiarité

Non « l'un OU l'autre » mais trois *intensités* ; l'appel à l'aide est le pivot, la
réponse prend l'une des trois formes, du plus léger au plus lourd :

1. **Le commun de savoir** (vademecums, cas, thésaurus) — zéro coût, zéro dépendance,
   100 % entre pairs. La base durable.
2. **Mini-wizards** — guident la biblio pour qu'elle fasse *elle-même* (autonomisant,
   pas dépendant).
3. **Aide humaine directe** (appel → réponse → éventuelle visio) — la plus
   relationnelle, pour quand le commun et le wizard ne suffisent pas.

**La boucle descendante** : un cas dur réglé en degré 3 → résumé → devient un cas/wizard
de degré 1-2 → la prochaine fois, le wizard suffit. *Le savoir descend les degrés avec
le temps ; le réseau devient plus malin et plus autosuffisant à chaque épisode.*

## 3. Le commun de savoir — la couche d'autonomie

Trois couches, et la plus profonde est **le vocabulaire lui-même** :

- **Le thésaurus, cœur politique.** Pas une liste de mots : un *graphe de concepts*. La
  politique y vit dans les **termes**, les **relations** (broader/narrower/related) et les
  **notes d'application** (qui sont des micro-vademecums). Bâtir sur **SKOS** (standard
  libre) — léguer une norme, pas un bricolage. Une graine existe (thésaurus ~30 catégories).
- **Cas & vademecums** — exemples travaillés, éditables, surgissant *au point de besoin*.
- **Wizards en *données*, pas en *code*** — *le pari d'autonomie* : si un wizard est du
  code, on dépend de dev pour toujours ; s'il est un **document structuré** (arbre de
  cartes-questions → cartes-fin) qu'un moteur écrit-une-fois déroule, **toute biblio en
  écrit un sans coder**. Garde-fous pour qu'il ne devienne pas un langage de prog déguisé :
  pas de variables/calcul/condition libre ; seul état = le chemin parcouru ; conditions
  éventuelles depuis une liste fermée ; **le wizard *conseille*, n'*écrit* jamais** (pire
  échec = « pas utile », jamais « cassé le catalogue ») ; petits wizards mono-sujet.

**Multilingue sans IA** : la coque i18n (10 locales) porte l'interface ; la *substance*
(termes, cas) s'écrit **par communauté de langue** (écriture parallèle cross-liée, pas
traduction descendante) — lent mais durable et gratuit. **Gouvernance** : ajout/modif de
terme via le flux **consentement/objection** des cercles ; curseur politique « variantes
admises vs convergence » à placer par le réseau.

## 4. Le déclenchement — au point de besoin (charte ③)

**Le déclencheur, c'est le *champ*, la *donnée*, ou la *demande* — jamais la surveillance
de la personne.** Bannir les signaux comportementaux (« 5 min sur le champ », hésitations) :
c'est Clippy *et* surveillance du travail. Trois déclencheurs honnêtes :
- **intrinsèque au champ** (sujets/autorité sont durs *pour tous* → aide toujours là) ;
- **dérivé de la donnée** (pas d'ISBN, auteur·rice ambigu → le livre signale, pas la personne) ;
- **demande explicite** (« à l'aide » calme, toujours à portée).

L'aide monte **l'échelle un-clic-plus-loin** (inline → wizard → cercle), **discrète mais
découvrable** (placement fiable, jamais modale/gamifiée), avec une **présence en courbe par
domaine** (un peu plus avenant si champ vide + faible nombre de notices ; s'efface avec la
maîtrise ; toujours pliable à la main).

## 5. Deux écrans déjà passés à la grille

### 5.1 — Le « ? » sous un champ dur (catalogage)
Présent *parce que le champ est coton pour chacun·e* (cadrage dignité, pas « tu sembles en
difficulté »). En l'ouvrant : suggestions thésaurus inline + cas du commun → « chemin
guidé » (wizard) → « demander au cercle » (degré 3, moment du consentement).
**La grille a tué deux features tentantes** : ❌ détecter l'hésitation pour proposer
l'aide (surveillance, facette ③) ; ❌ badges/séries/barre vers « expert·e » (facette ⑥).
**Défauts retenus** : filet « première fois ? chemin guidé » *offert mais en registre
d'offre* ; « ? » toujours visible, suggestions **dépliées au clic** (discret + découvrable).

### 5.2 — La clôture d'épisode + capture du commun
Fin **initiée par l'aidée** (pas d'auto-close, pas de clôture par l'aidant·e). Écran
« merci » sobre, **rien d'accroché** (découplage anti-dette). **Barreau-plume** « garder le
contact ? » symétrique, ignorable, ne crée rien sauf double-oui.
**Capture du commun sans dette** : on invite l'**aidant·e** (détient le savoir neuf), pas
l'aidée ; **micro-contribution accrochée à l'objet** (note sur un terme/champ), **amorcée
par la trace** de l'épisode ; puis l'**aidée est invitée à relire/enrichir** (« ce qui était
vraiment difficile ») — *sa voix, déclinable, jamais un jugement de l'aidant·e*, et **non
bloquante** (la note tient seule).
**La grille a tué** : ❌ « note ton expérience » (classement déguisé) ; ❌ badge de complétion.

## 6. Confidentialité

La donnée de catalogue est *moins* sensible que la donnée lecteur·rice (métadonnées sur des
*livres*, jamais d'exemplaires/emprunts/identités), **mais pas zéro** (les fonds d'une biblio
anar peuvent être politiquement sensibles ; cf. la distinction `visibility_level='network'` /
BTL). Donc :
- **opt-in par item** (jamais un dump), **BTL/sensibles exclus par défaut** ;
- **l'aidant·e *propose*, la propriétaire *valide*** — jamais d'écriture directe d'un tiers ;
  accès **scopé, révocable, audité** ;
- le cran **« demander au cercle » EST le moment du consentement** (« tu vas montrer ces
  items à la biblio X — voici ce qui sort ») ;
- **le commun capte de l'artisanat *générique dé-identifié*, pas des *cas* identifiants** ;
  les spécificités sont strippées ou consenties.

Réponse à la question « droit absolu de déléguer ? » : **oui à l'autonomie, mais consentement
*éclairé et cadré*, pas blanc-seing** — rendre le risque petit et le faire prendre en
connaissance de cause.

## 7. Appariement & maturation en partenariat

- **Tri doux, pas filtre dur.** Dans un réseau épars, un ET (même langue ET géo ET dispo ET
  expert) = ensemble vide. On **classe** par affinité (langue ↑, fuseau ↑, volontaire ↑) sans
  **exclure** ; subsidiarité **cercle d'abord → réseau si silence**. Le **cercle pertinent
  dépend du type d'aide** (catalogage → linguistique ; matériel/répression → géographique).
- **Premier geste sans préalable** : se porter volontaire pour *un* acte n'exige aucun cercle
  ni profil. **L'appartenance s'accrète des gestes** (reconnaissance consentie, jamais étiquette).
- **Anti-hiérarchie** : pas de réputation individuelle, pas de marketplace ; disponibilité
  déclarée, réciprocité visible sans score, rotation.
- **Maturation en partenariat (§21)** — *seconde phase qui dissout la rareté* : un bon épisode
  peut **mûrir** en partenariat → l'aide future est *pré-appariée* (langue, fuseau, consentement
  déjà donné) ; le réseau se **densifie**. **Découplé** de l'épisode (jamais dans l'instant =
  dette) ; **après répétition** (reconnaissance, pas création) ; **double-opt-in symétrique** ;
  **échelle de profondeur** (0 → garder-contact → compagnonnage → partenariat formel) ;
  **inversion de la dette** (le partenariat est un *cadeau* à l'aidée : « un·e camarade à
  rappeler sans re-consentir », pas un dû) ; toujours **sécable**.

## 8. Le greffon visio (degré 3)

Coupler l'aide humaine à une **visio Jitsi** (synchrone = transmission efficace) ; vivier =
**cercle linguistique**. **Async d'abord, visio en turbo optionnel** (la plus précaire est mal
connectée → degrés 0-2 en texte/hors-ligne).
Technique, « gratuitement » : **coder l'intégration une fois via l'iframe API avec le `domain`
en config** → jamais verrouillé à un fournisseur. Pointer par défaut vers une **instance Jitsi
militante** (le plus dans la doctrine, gratuit, pas de GAFAM) ; à défaut `meet.jit.si` (en
assumant l'auth du créateur de salle). Salles **éphémères, nom non-devinable, lobby**. **Zéro
serveur, zéro secret, zéro coût récurrent.** L'auto-hébergé reste *parking* (VPS écarté).

## 9. Coût & autonomie

Tout (commun, wizards, panneaux, matching, visio link-out) **tourne sur la stack existante**
(Supabase + front statique) : **zéro coût marginal, sans IA pour tourner**. L'IA reste un
**accélérateur optionnel et débranchable** (pré-catalogage du *neutre* uniquement ; le politique
reste entre camarades). **Les organes existent déjà** : graine de thésaurus, wizard de
découverte, i18n 10 locales, flux consentement/objection des cercles, §21 partenariat. **Ce
cadrage relie des organes existants — d'où sa modicité, et son indépendance vis-à-vis du coût
et de toute dépendance externe.**

## 10. Décisions actées / questions ouvertes

**Actées (au fil de la réflexion) :**
- Trois degrés en échelle + boucle descendante du savoir.
- Commun = thésaurus (SKOS, cœur politique) + cas + **wizards en données**.
- Déclenchement par champ/donnée/demande, **jamais surveillance** ; échelle un-clic ;
  présence en courbe par domaine.
- Écran « ? » : défauts (offre, suggestions au clic) ; refus (détection-hésitation, gamification).
- Clôture : aidée clôt ; **aidant·e rédige → aidée enrichit** (zéro dette) ; commun = **craft
  générique** ; gouvernance **additif = 2 personnes / vocabulaire = collectif**.
- Matching **tri doux + cercle d'abord** ; cercle **selon le type d'aide** ; premier geste sans
  préalable ; **appartenance par le geste**.
- Maturation §21 **découplée, après répétition, double-opt-in, échelle de profondeur, inversion
  de dette, sécable**.
- Visio **Jitsi `domain` configurable**, async-first, zéro infra/secret.
- (Rappel mail, déjà câblé hors ce cadrage) locale du destinataire = **sa préférence perso**.

**Ouvertes (curseurs politiques à placer par le réseau) :**
- **Niveau d'accueil initial** (hospitalité) et **qui le pose** : réseau / cercle / biblio /
  personne. Piste : *demander* à la nouvelle venue son accueil (consentement) + subsidiarité
  (le haut ne comble que le silence) + option *parrainage incarné* par un·e volontaire du cercle.
- Niveau de **présence du barreau-plume** et de l'invitation au commun (offert vs disponible) —
  largement désamorcé par la **sémantique** (registre d'offre ≠ injonction).
- Forme concrète de **l'éditeur de wizard-en-données** (jusqu'où sans devenir du code).
- Curseur **variantes vs convergence** du thésaurus.

## 11. Statut

Cadrage à **discuter et éprouver**, pas un ordre de construction. Quand un volet sera mûr, il
se déclinera en spec, et chaque écran repassera à la **grille de la charte relationnelle**.
