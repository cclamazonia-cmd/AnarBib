# 🧭 CADRAGE — Assemblée du réseau : mécanisme de décision & tenue non-présentielle

| Champ | Valeur |
|---|---|
| Référence | `docs/journal/cadrages/CADRAGE_assembleias_reseau_2026-06-16.md` |
| Date | 16 juin 2026 |
| Statut doctrinal | **Trace (non-normative).** Précurseur du **`spec-assembleias`** (non encore créée), annoncé par `spec-outils-federalistes` (onglet *Assembleias* « charpenté & renvoyé », étape 5). Les décisions ci-dessous se canoniseront ultérieurement au **REGISTRE, section `FED`** (ou une section assemblées dédiée). **N'implémente rien.** |
| Périmètre | (a) Mécanisme de choix de **date/horaire** d'une AG ; (b) **machinerie de tenue non-présentielle** (réemploi Jitsi d'entraide) ; (c) cadrage des **deux sujets de fond** déjà identifiés à débattre en AG. **Hors périmètre** : régime de vote des décisions de fond (renvoyé au consentement), implémentation, mandat impératif vs représentatif (hérité chantier §8.2). |
| Méthode | Discussion de conception du 16/06 (ligne de travail fédération). Appuis : `spec-outils-federalistes` (REGISTRE §`FED`), `CADRAGE_modele_acces_concentrique_2026-06-04`, `HEBERGEURS_jitsi_militants_2026-06-16`. Doctrine mémoire : *l'ouverture des permissions contributeur·rices aux sujets/mots-clés est une décision d'AG réseau, pas unilatérale.* |
| Préséance | En cas de conflit : REGISTRE (`FED-…`) + spec courante + backlog font foi. Ce cadrage est périmé par définition s'il contredit la couche référence. |

---

## 1. Objet

La tenue d'une AG du réseau AnarBib est **encore lointaine**, mais le **mécanisme de décision** est précisément ce qu'on bâcle dans l'urgence de la première convocation — alors que c'est lui qui **fonde la légitimité** de tout ce qui en sortira. Ce cadrage pose le **fond avant la forme** (méthode du projet) sur trois points déjà mûrs : comment **choisir la date/l'horaire**, comment **tenir l'AG à distance**, et comment **formuler les deux sujets de fond** déjà sur la table. Il **ne tranche rien** : il prépare la discussion et le futur `spec-assembleias`.

## 2. Doctrine d'ancrage (rappel normatif — REGISTRE §`FED`)

Le cadre politique de la face fédération s'applique tel quel à l'AG :

- **Le consentement plutôt que le décompte** (FED) — grammaire de l'absence d'objection motivée, réutilisée de la cooptation des admins réseau et de l'adhésion aux cercles (FED-O5, anti-blackball B).
- **Autonomie locale souveraine** — **une décision d'assemblée est une recommandation**, jamais une contrainte qui s'impose à une bibliothèque. Cela **dédramatise** le choix de la machinerie : on n'élit pas un pouvoir, on coordonne un commun.
- **Fédéralisme, pas hiérarchie** — aucune AG « mère », aucune voix prépondérante, aucun échelon au-dessus des bibliothèques.
- **Légitimité = étalement, pas masse** — ce qui fait foi est *combien de collectifs distincts* participent et *leur diversité* (langues / régions), pas le nombre de têtes.

## 3. Distinction clé — deux natures de décision à ne jamais confondre

| | **Logistique** (date, horaire, plateforme) | **Fond** (sujets, termes, normes) |
|---|---|---|
| Nature | Optimisation sous contrainte | Décision politique |
| Critère | Participation effective la plus large | Adhésion / absence d'objection |
| Outil légitime | Méthode majoritaire / de score (cf. §4) | **Consentement / objection** (grammaire FED) |
| Risque si on se trompe d'outil | — | Importer une logique « gagnants/perdants » là où le réseau veut du consentement |

> **Règle :** pour *fixer une date*, une méthode d'optimisation est légitime (c'est de la coordination, pas un acte politique). Pour les *sujets de fond*, c'est la **machine consentement/objection** qui tranche — **jamais** un vote préférentiel. Garder ces deux outils distincts est le garde-fou principal de ce cadrage.

## 4. Choix de date/horaire

### 4.1 Pourquoi le vote préférentiel « à l'australienne » (IRV) n'est pas l'outil idéal

L'intuition (classer ses préférences dans l'ordre, façon scrutin australien / *instant-runoff*) est séduisante, mais l'IRV est conçu pour **désigner UN gagnant parmi des candidatures rivales** — pas pour une **optimisation sous contrainte de disponibilité**. Deux problèmes :

1. **Le classement capte la préférence, pas la contrainte dure.** « Je préfère mardi » et « je ne *peux pas* mardi » se ressemblent dans un rang bas, alors qu'ils sont opposés. Pour une AG, l'indisponibilité réelle prime sur le goût.
2. **Effets contre-intuitifs documentés** de l'élimination par tours (non-monotonie : mieux classer un créneau peut le faire perdre ; report de voix opaque). Devoir expliquer « pourquoi B gagne alors que plus de collectifs ont mis A en premier » est un **coût de légitimité** injustifié pour fixer une date.

### 4.2 Les deux méthodes envisagées — **option A retenue (16/06)**

- **Option A — Disponibilité + préférence en départage** *(✅ **orientation retenue, 16/06** — colle au consentement).* Chaque collectif marque d'abord ce qu'il **peut** (contrainte dure : oui / non / si vraiment nécessaire), puis, *parmi ce qu'il peut*, ordonne. On retient le créneau qui **maximise la participation effective**, départagé par les préférences. Récit : *« le créneau qui laisse le moins de collectifs dehors »* — exactement le cadre minimisation-des-exclusions, cohérent avec la grammaire d'objection.
- **Option B — Vote par score** *(alternative écartée, conservée pour trace).* Note 0–5 par créneau (`0 = impossible`) ; plus riche qu'un oui/non, **monotone**, trivial à expliquer, réintroduit la contrainte dure via le 0 ; plus simple à coder que l'IRV. Écartée au profit de A, qui distingue mieux *contrainte* et *préférence*.

### 4.3 Garde-fous transverses (valables pour A comme B)

- **Pré-filtrage des créneaux par la coordination** : proposer **4–6 fenêtres** respectant déjà l'éventail de fuseaux, plutôt que laisser proposer n'importe quoi (sinon l'espace explose et rien ne converge).
- **Quorum par collectif, pas par tête** : le critère gagnant = « le créneau qui atteint le quorum avec le **spectre de collectifs le plus large** » (étalement langues/régions pondéré).
- **Fuseaux horaires** : réseau multilingue, collectifs sur plusieurs continents (pt-BR par défaut, Europe, Amérique latine) → fenêtre commune **étroite**. Stockage **UTC**, affichage en heure locale. Ce point conditionne la faisabilité même de la fenêtre.

### 4.4 Forme concrète de l'option A retenue

1. **Saisie — par collectif et par créneau pré-filtré (§4.3)** : un marqueur de disponibilité `oui` / `non` / `si vraiment nécessaire` (la contrainte dure), puis, parmi les créneaux `oui` / `si nécessaire`, un **ordre de préférence**.
2. **Faisabilité** : pour chaque créneau, l'ensemble des collectifs qui peuvent (les `oui`, le `si nécessaire` comptant de façon **escomptée** — il élargit la faisabilité sans masquer qu'un collectif est à la peine).
3. **Filtre quorum (§4.3)** : ne garder que les créneaux atteignant le quorum — **nombre de collectifs distincts ET diversité** langues/régions.
4. **Sélection** : parmi les créneaux qualifiés, celui qui **maximise la participation effective** ; **départage** par préférence agrégée, puis si besoin par diversité.

Cohérent avec §3, la date reste une **optimisation sans droit de veto** : un collectif gêné par le créneau retenu n'objecte pas (ce serait importer le consentement dans la logistique) — sa contrainte est déjà portée par son marqueur de disponibilité.

## 5. Tenue non-présentielle (réemploi Jitsi)

La visio est le morceau **déjà résolu** : l'entraide pointe sur Jitsi via une **unique variable de build** `VITE_JITSI_DOMAIN` (défaut `meet.jit.si`), salle non devinable `anarbib-entraide-<uuid de l'appel>`. Une AG réutilise tel quel ce socle — salle `anarbib-assembleia-<uuid>` — **sans changement de code**. Le choix d'un **hôte militant** (idéalement lusophone) est traité par `HEBERGEURS_jitsi_militants_2026-06-16`. **Hôte confirmé (16/06) : Autistici/Inventati — `vc.autistici.org`** (italophone, ~35 pers., aucun enregistrement) : `VITE_JITSI_DOMAIN` y pointe désormais, en **link-out** (onglet dédié, plus de modale embarquée — le composant `VisioRoom` a été retiré). Salle d'AG : `anarbib-assembleia-<uuid>`, ouverte dans un onglet.

> **Ce qui est neuf**, ce n'est donc pas la salle, c'est la **machinerie amont** : convocation (réemploi de `notify-event`, fan-out par `library_id`), recueil des disponibilités/préférences (§4), calcul du créneau + **quorum par collectif**, et publication dans l'onglet *Início* / *Assembleias* de la face fédération.

## 6. Les deux sujets de fond (à *débattre* en AG — non tranchés ici)

> Le fil rouge des deux : **une seule tension posée deux fois** — jusqu'où le réseau **converge sur une norme unique** vs jusqu'où il **laisse coexister des variantes fédérées** (consensus ↔ fédéralisme/pluralisme). Il peut être utile de la nommer comme telle en AG.

### 6.1 Ouvrir aux contributeur·rices l'édition sujets/mots-clés (actuellement coordination seule)

- **État actuel** : les contributeur·rices éditent les **autorités dans leur langue** ; les **libellés de sujets** (thésaurus matière) restent **coordination seule**. L'élargissement aux sujets/mots-clés est **explicitement une décision d'AG réseau**, pas un arbitrage unilatéral (doctrine mémoire).
- **À débattre** : périmètre de l'ouverture (proposer vs valider ?), articulation avec le **thésaurus matière** existant (cf. `CADRAGE_thesaurus_matiere_v2_2026-06-16`), garde-fous (qui arbitre un désaccord ?).

### 6.2 Machine consentement/objection des termes + curseur « variantes admises ↔ convergence »

- **À débattre** : la **grammaire de décision sur les termes** (réemploi de la grammaire FED : délai d'objection, motivation longue obligatoire, traçabilité, anti-blackball) **et** le réglage du **curseur** : impose-t-on une norme unique, ou admet-on des variantes fédérées ?
- **Note de réalité** : le réseau **admet déjà des variantes de fait** — la charte de langage inclusif fixe des conventions **par locale** (point médian fr, `e` neutre es, astérisque it, Genderstern de…), et certaines sont encore **provisoires (`nl`)** ou **à définir (`el`)**. Le curseur n'est donc pas « variantes ou pas » mais *« où placer le seuil de convergence, langue par langue »*. La grammaire d'objection est le bon outil ; le **régime de vote des décisions de fond** reste un point ouvert (hérité chantier §8.2).

## 6bis. Ordre du jour — inscription d'un point (modèle retenu 16/06)

**Modèle retenu : pas de gardien, l'assemblée adopte son ODJ.** Tout collectif membre peut inscrire un point, à condition de le déposer **avant J-15** (quinze jours avant l'AG). Trois principes :

- **Aucune autorité ne décide de l'admission.** Le dépôt avant l'échéance **inscrit** le point. Une **facilitation** (coordination ou cercle tournant) ne fait qu'**organiser** : regrouper les doublons, proposer un ordre et un temps par point, signaler ce qui relèverait d'un autre espace — **jamais supprimer**. Toute réorganisation est **visible et contestable** par le collectif proposant (la transparence est le garde-fou, comme pour l'objection FED-O5).
- **L'assemblée est souveraine sur son ODJ.** À l'ouverture, l'AG **adopte l'ordre du jour par consentement** : elle peut ajouter un point tardif (par consentement, motif d'urgence), en différer un, fusionner. Le pouvoir reste à l'assemblée, pas à un filtre amont.
- **Le délai n'est pas un filtre, c'est une condition de préparation.** Son rôle : laisser à chaque collectif le temps de **traduire** le point (réseau multilingue) et surtout de **mandater** sa·son délégué·e dessus. Les dépôts après l'échéance vont en *varia* / prochaine AG, sauf consentement de l'assemblée à les ajouter.

**Lien avec le mandat — calendrier retenu (16/06).** Le réseau retient le **mandat impératif** (le·la délégué·e porte la position mandatée par sa base, pas la sienne). L'horloge qui compte n'est donc pas « dépôt → AG » mais la **fenêtre de mandatement** (ODJ figé + traduit → AG). D'où **trois jalons** :
- **Convocation** (date + ODJ en formation) : **J-30 minimum**, pour que chaque collectif cale sa réunion locale de mandatement ;
- **Dépôt d'un point** : **J-15** (plancher) ;
- **ODJ figé, traduit (10 langues) et publié** : **~J-10** → ~10 jours de fenêtre de mandatement.

Un collectif à cadence lente s'appuie sur la **convocation précoce (J-30)**, pas sur le délai de dépôt — c'est elle qui rend le mandat impératif praticable.

## 6ter. Quorum, mandat & AG constitutive (retenu 16/06)

**Quorum permanent : 60% des zones géographiques ∧ 50% des langues** présentes — les **deux** conditions (le « et » empêche qu'un seul bloc régional/linguistique fasse quorum à lui seul ; légitimité = étalement, §2). Trois précisions tranchées :

- **Dénominateur sur les constituantes réelles**, pas l'interface : le % se calcule sur les **zones et langues ayant au moins un collectif membre**, jamais sur les 10 locales d'UI (plusieurs — eo, el, nl… — sont des traductions sans collectif derrière ; les inclure rendrait le seuil quasi inatteignable).
- **Présence = ≥ 1 collectif mandaté** par zone/langue. Si le quorum n'est pas atteint, **filet** : l'AG se tient quand même, mais ses décisions sont **provisoires**, à ratifier en asynchrone — pas d'échec sec qu'une absence ponctuelle déclencherait.
- **AG constitutive exemptée.** La toute première AG a pour objet de **se doter de ces règles** (dont le quorum) : la verrouiller d'emblée derrière 60/50 serait circulaire (pas de quorum → pas de règles). Elle tourne donc sous **quorum allégé/indicatif**, ne **pose que des jalons** (décisions provisoires), et le 60/50 devient la règle permanente qu'elle adopte pour les AG suivantes.

## 6quater. Régime linguistique de l'AG (retenu 16/06)

La langue, en assemblée, est une question de **pouvoir**. Principe : **aucune langue-trône**, et en particulier **pas d'anglais par défaut** — ce serait importer la hégémonie linguistique qu'un réseau anarchiste à base lusophone / Sud-global refuse (et c'est **pt-BR, non l'anglais**, qui est la langue de référence de l'app).

- **Séance plurilingue.** On intervient dans sa langue ; les échanges sont résumés vers un **socle restreint de langues-pivots** (proposition : **pt + es + en** — pt = base, es = bloc hispanophone proche, en = relais de seconde langue ; l'anglais est *un* relais, pas le trône). Relais d'interprétation **bénévole** par grappes linguistiques ; **canal texte** (chat Jitsi) en parallèle de la voix (accessible, traduisible, nourrit le PV).
- **Compréhension chargée en amont.** L'ODJ et la **motivation écrite de chaque point** sont **traduits et diffusés avant l'AG** (calendrier J-30/J-15/J-10, §6bis) : chacun·e arrive en ayant lu, dans sa langue, ce qui se décide — et en ayant mandaté. Le live ne porte plus toute la traduction.
- **PV multilingue = pièce porteuse.** Décisions **et motivations** consignées dans un **procès-verbal multilingue** — non négociable : avec le **mandat impératif**, les collectifs **ratifient et agissent à partir du PV**, il doit donc être dans leur langue. PV concis (pas verbatim) ; brouillon éventuellement machine-assisté, mais **relecture humaine obligatoire des termes** (charte inclusive — c'est le curseur variantes ↔ convergence, §6). La **fenêtre de ratification asynchrone** (filet quorum, §6ter) donne le temps de traduire.
- **Secrétariat & souveraineté.** La **convocation déclare** le régime par défaut (langues-pivots, séance plurilingue, PV multilingue) et **appelle au secrétariat et aux relais d'interprétation** (volontaires signalés en amont). L'**assemblée nomme son secrétariat à l'ouverture** et peut **amender** le régime — le régime linguistique est lui-même une **règle que l'AG constitutive acte** (§6ter).

## 6quinquies. Facilitation — rôle, phasage, bornes (retenu 16/06)

La facilitation (préparer/publier l'ODJ, poser les dates, ordonner les points, tenir le temps) est une **fonction de service**, pas une autorité — et elle **ne doit pas devenir une prérogative des admins réseau** (qui tiennent les clés techniques). Décision :

- **Phasage & cycle « créer vs faciliter » (tranché 16/06).** *Créer* une assemblée = acte de **convocation neutre** → `network_admin`. *Animer* (dater, publier l'ODJ, ordonner, différer) = **admins réseau en bootstrap**, puis — **dès que la 1ʳᵉ AG en aura statué** (c'est un **point d'ODJ** de cette AG : instituer le rôle + désigner les facilitateur·rices) — **le travail des facilitateur·rices désigné·es**. La 1ʳᵉ AG est donc animée par les admins ; elle institue, en séance, le passage de relais.
- **Accès propre, pas « instruction aux admins ».** Les facilitateur·rices désigné·es ont leur **propre accès** à l'outil (créer / dater / ordonner directement) — *pas* un schéma où iels dicteraient à des admins « exécutants » (qui resteraient alors un **goulot** et un **pouvoir de fait** : tarder, être absent·e, mal interpréter). Les admins réseau sortent **complètement** de l'animation politique : ils ne font plus que l'**infrastructure** (serveurs, comptes, sauvegardes).
- **Rotation / par AG — contre l'épuisement militant.** Désignation **pour une AG donnée** (cercle tournant), jamais un corps installé : la **rotativité des fonctions évite l'épuisement militant** (personne ne porte l'animation indéfiniment) **et** empêche qu'un petit pouvoir s'installe.
- **Bornée.** Quel que soit qui facilite, la règle « **organise, ne supprime jamais** » (§6bis) tient : l'AG adopte son ODJ. Démocratiser *qui* tient le rôle ne suffit pas — c'est la **borne sur ce que le rôle peut faire** qui protège.
- **≠ délégation.** Les facilitateur·rices animent (service), ne décident pas → pas de mandat impératif comme les délégué·es, mais **révocables par l'AG** et redevables devant elle.
- **Désignation sur volontariat (anti-panoptique).** On ne « pioche » pas les gens dans un annuaire réseau (refus **FED-7** + vie privée) : une personne **se propose** pour faciliter une AG (opt-in, en écho à l'**appel à facilitateur·rices** de la convocation, §6quater), et l'AG / l'admin **désigne parmi les volontaires**. On ne voit que celles et ceux qui ont levé la main.

**Outillage (P2b).** Rôle `facilitateur·rice` **attribué par assemblée** (p. ex. table `assembleia_facilitators`) ; RPC de facilitation gardées **`network_admin` OU facilitateur·rice désigné·e de cette AG** (la migration P1 ne gardait que `fn_caller_is_network_admin()` — P2b ajoute l'**OU**). 1ʳᵉ AG = cas-limite sans facilitateur·rice désigné·e → les admins agissent. **P2c** : désignation **sur volontariat** — colonne `status` (`volunteer`/`designated`) sur `assembleia_facilitators`, RPC `fn_assembleia_volunteer` (soi-même, opt-in) ; désigner = passage `volunteer`→`designated` ; seuls les `designated` ont les droits d'animation.

## 7. Articulation outillage (neuf vs réemploi)

| Brique | Statut |
|---|---|
| Salle visio | **Réemploi** Jitsi (`VITE_JITSI_DOMAIN`) |
| Convocation / notifications | **Réemploi** `notify-event` (fan-out `library_id`, désactivable) |
| Décision de fond (termes, permissions) | **Réemploi** grammaire consentement/objection (FED-O5) |
| Recueil disponibilités/préférences + créneau + **quorum par collectif** | **Neuf** — cœur probable d'une migration `spec-assembleias` (tables assemblée / créneaux / disponibilités, RPC-first, RLS, vues `*_v1` selon DOC-OBJ-2/DOC-RPC-3) |
| Dépôt / adoption d'un point d'**ODJ** (§6bis) | **Neuf** — table des points proposés + RPC de dépôt (garde *membre rattaché*), clôture auto à `D-X`, vue d'ODJ ; la facilitation **ordonne sans supprimer** (différé/archive, jamais `delete` — mémoire) |

## 7bis. Paquet P3 — notifications de l'AG (cadrage 17/06)

**Objet.** Le *push* qui complète le *pull* de l'onglet : prévenir les collectifs **aux jalons**. Sans lui, le **calendrier de mandatement** (J-30/J-15/J-10) est lettre morte — personne ne reçoit la convocation à temps pour mandater sa base. P3 rend la convocation **vivante**.

**Events & déclencheurs** (préfixe `network.assembleia.*`) :
- **`…convocada`** — à la convocation (statut → `convocada`, ~J-30) → fan-out **tout le réseau** (coordenador·es des biblios membres) : « AG convoquée, l'ODJ se constitue, mandatez-vous ».
- **`…agenda_published`** — ODJ figé/traduit publié (~J-10) → fan-out réseau : « voici les points, préparez le mandat ».
- **`…item_proposed`** — au dépôt d'un point → vers la **facilitation** (DOC-NOTIF-1 : pas l'auteur·rice).
- *(option P3b)* **rappels** J-15 (« le dépôt ferme ») et J-1 (« demain, lien Jitsi ») via **pg_cron** (motif `fn_circle_resolve_due`).

**Le point dur `uuid`↔`bigint` est RÉSOLU par la voie outbox/jsonb (vérifié 17/06).** On **n'utilise pas** le dispatcher historique `fn_dispatch_notify_event` (qui exige un `record_id bigint` — ce qui avait différé les events cercles). On réemploie la voie **moderne** (gouvernance d'équipe / lettre) : `fn_network_notify_event(p_event 'network.%', p_payload jsonb)` → insère dans `team_notification_outbox` → trigger `trg_team_outbox_dispatch` → POST vers l'EF `notify-event`, qui **résout le fan-out depuis le payload**. **L'uuid de l'assemblée voyage dans le payload** — aucun `bigint`.

**Ce que P3 ajoute :**
1. **Émission** des events dans les RPC existantes — `fn_assembleia_set_status` (convocada / publication), `fn_assembleia_propose_item` (item_proposed) — en **best-effort** (l'échec d'émission ne casse jamais la RPC métier, motif `fn_network_notify_event`).
2. **Handler outbox** dans l'EF `notify-event` pour les `network.assembleia.*` : résolution des **destinataires** (réseau pour convocada/published ; facilitation pour item_proposed) + rendu via **`_shared/i18n/mail-strings.ts` / `tMail`** — ⚠️ **8 langues** (système e-mail distinct des 10 locales React).
3. **Désactivable** (gouvernance d'équipe) ; **DOC-NOTIF-1** (notifier qui n'a pas initié).

**À confirmer en build** : la branche **outbox** exacte de l'EF (comment elle calcule le fan-out depuis le payload — champ destinataires explicite ? scope « réseau » ?) et la résolution « tout collectif membre » pour la convocation.

**Périmètre P3** : `convocada` + `agenda_published` + `item_proposed`. **Différé P3b** : rappels J-15/J-1 (pg_cron). **Backend surtout** (émission + handler EF + mail-strings) ; pas de frontend.

## 8. Points ouverts (à trancher pour `spec-assembleias`)

**Tranchés le 16/06** (orientations, à canoniser au REGISTRE §`FED`) :
- ✅ **Méthode de date : option A** — disponibilité + préférence en départage (§4.4).
- ✅ **Inscription à l'ODJ** : pas de gardien, l'assemblée adopte son ODJ par consentement (§6bis).
- ✅ **Mandat : impératif** ; **calendrier** J-30 convocation / J-15 dépôt / ~J-10 ODJ publié (§6bis).
- ✅ **Quorum permanent** : 60% des zones ∧ 50% des langues, dénominateur sur les constituantes réelles, présence = ≥ 1 collectif mandaté, filet « décisions provisoires » ; **AG constitutive à quorum allégé** (§6ter).
- ✅ **Facilitation : rôle distinct dès la 2ᵉ AG** (1ʳᵉ = admins réseau, bootstrap) — **accès propre** (pas « instruction aux admins »), désigné par l'AG, rotatif, borné, ≠ délégation (§6quinquies).
- ✅ **Cycle « créer vs faciliter » (16/06)** : *créer* = `network_admin` (convocation neutre) ; *animer* = admins en bootstrap → facilitateur·rices **dès que la 1ʳᵉ AG l'a statué** (point d'ODJ : instituer/désigner) (§6quinquies).

**Restent ouverts :**
- **Liste canonique des zones géographiques** (et des langues-constituantes) servant de dénominateur au quorum.- **Langues-pivots de séance** (proposition pt/es/en, §6quater) — à acter, candidat à décision de l'AG constitutive.
- **Mécanique de ratification asynchrone** des décisions provisoires (filet quorum + jalons de l'AG constitutive).
- Sémantique exacte du « si vraiment nécessaire » et **forme de la saisie** disponibilités/préférences (§4.4).
- Qui **propose les créneaux** pré-filtrés (coordination ? un cercle ?).
- Statut d'une AG **non-présentielle** vs présentielle (équivalence décisionnelle ?).
- **Régime de vote des décisions de fond** (au-delà du consentement par défaut — hérité chantier §8.2).

## 9. Prochaine étape

Ce cadrage est le **germe** du `spec-assembleias`. Quand les points ouverts §8 seront mûrs, ils se **canonisent au REGISTRE §`FED`** (ou section assemblées dédiée), puis se déclinent en spec + migration. D'ici là, ce document **raisonne, il ne tranche pas**.

---

*Fin du cadrage (trace, non-normative). Décisions opposables : REGISTRE §`FED`. Ce document prépare le `spec-assembleias` ; il ne crée aucune décision.*
