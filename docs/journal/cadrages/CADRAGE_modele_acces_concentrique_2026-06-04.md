# 🧭 CADRAGE — Modèle d'accès concentrique & face fédération (« Ferramentas federalistas »)

| Champ | Valeur |
|---|---|
| Référence | `docs/journal/cadrages/CADRAGE_modele_acces_concentrique_2026-06-04.md` |
| Date | 4 juin 2026 |
| Statut doctrinal | **Trace** (non-normative). Les décisions ci-dessous se canonisent dans le **REGISTRE, section `FED`** (à créer, §24). Ce document en est le foyer / la justification. |
| Périmètre | Modèle d'accès par anneau (qui voit / qui agit) ; relocalisation de `círculos` ; nommage du bloc fédératif ; 2 arbitrages tranchés. **N'implémente rien** — fonde le fond avant la forme (schéma Bologne) et avant la spec des outils. |
| Méthode | Discussion de conception 04/06 ; appui sur `CHANTIER_reseau_federatif_2026-05-25` (trace), `spec-administrateur-reseau-v0.4` (RES), `spec-cartographie-reseau-v0.1` (MAP), chantier `#PARTNERS`. |
| Préséance | En cas de conflit : REGISTRE (`FED-…`) + spec courante + backlog. Ce cadrage est périmé par définition s'il contredit la couche référence. |

---

## 1. Objet

La préparation du schéma « Cerchi concentrici di responsabilità » pour FICEDL Bologne a révélé une tension entre une **forme** élégante (le diagramme concentrique inspiré de la théorie des cercles de la FAU) et le **fond** réel de l'application (qui voit et qui agit, anneau par anneau). Ce cadrage tranche le fond, relocalise l'objet `círculos`, nomme le bloc fédératif, et fixe deux arbitrages d'accès. Le schéma de Bologne sera **régénéré ensuite**, à partir de ce fond — et non l'inverse.

## 2. Le constat : la forme avait précédé le fond

Le diagramme initial collait **deux axes différents** comme s'ils marchaient au pas :

- l'**échelle de l'objet** — du plus intime au plus collectif : `catálogo → conta → painel → catalogação → importações/exportações → biblioteca → círculos → rede` ;
- la **portée des rôles** — `leitor → bibliotecário → coordenador → administrador`.

En postulant que chaque rôle possède exactement deux anneaux contigus (symétrie 2-2-2-2), le schéma plaçait `círculos` dans la portée de l'`administrador` (compagnon de `rede`). Or agir sur les cercles **engage la bibliothèque**, ce qui relève du `coordenador` — pas de l'admin réseau. Surtout, réserver la vie fédérative au sommet en aurait fait le **domaine privé de l'administrateur**, soit précisément la hiérarchie que « *non è gerarchia, è portata* » récuse. La belle symétrie masquait une hiérarchie.

## 3. La correction : décoller les deux axes

On conserve les **anneaux concentriques comme échelle d'objet** (forme juste), mais on **décolle la portée des rôles** : elle devient un calque honnête, non contigu, qui déborde par endroits (la lecture de `círculos` descend jusqu'au `leitor`) et s'arrête ailleurs (le `coordenador` agit jusqu'à `círculos`, pas `rede`). La symétrie 2-2-2-2 est abandonnée.

## 4. Tableau d'accès par anneau (figé)

| Anneau (échelle) | Qui **voit** | Qui **agit / engage** | Rôle pivot (agir) | Nature |
|---|---|---|---|---|
| **catálogo** | public, tout le monde | consulter, réserver, emprunter | leitor | ouvert |
| **conta** | soi seulement | gérer son compte, sa carte-lecteur | soi (1ʳᵉ personne) | intime |
| **painel** | staff + **vue limitée des comptes lecteurs** (à la demande, au comptoir) | tenir le comptoir (consultas, empréstimos) | bibliotecário | opérationnel |
| **catalogação** | staff | créer/éditer notices et exemplares | bibliotecário | opérationnel |
| **importações / exportações** | staff | configurer sources & partenaires, lancer un run, exporter | coordenador | engage (relations extérieures) |
| **biblioteca** | staff (profil public : tous) | gérer la biblio ; *ce qui engage* (partenaires, membros, paramètres) | coordenador (`user_can_manage_library`) | engage la biblio |
| **círculos** | **tous les membres rattachés** (leitor inclus) | rejoindre/quitter, escrever ao círculo, compartilhar catálogo, traiter le signal | coordenador | **fédératif** |
| **rede** | administradores de rede | admettre/coopter, gérer les admins (audit), traiter les demandes | administrador (`isNetworkAdmin`) | réseau |

## 5. La règle « voir ≠ agir »

Les **actions** se nichent vers l'extérieur (logique FAU : plus d'anneaux = plus de leviers, sans retirer ceux du centre). La **lecture** suit le même emboîtement, **sauf deux exceptions** — et ce sont exactement les deux points où le schéma trop symétrique se trompait :

1. **conta** reste *first-person* : un `coordenador` ne lit pas les comptes personnels des lecteurs (intimité, RLS).
2. **círculos** s'ouvre *vers le dedans* : un `leitor` **voit** les cercles sans pouvoir **agir** dessus. La fédération est visible de tous, engagée par qui en a le mandat.

---

## 6. Décisions (à canoniser dans REGISTRE §`FED`)

> Énoncés normatifs proposés. À reporter en une ligne chacun dans le REGISTRE ; ce cadrage reste leur foyer.

- **FED-1 — Relocalisation de `círculos`.** Les cercles d'affinité relient des **bibliothèques** (objet niveau biblio, multi-appartenance) ; ils relèvent de la **face fédération**, **pas** de la face administration `rede`. **Voir** = tout membre rattaché à la biblio (leitor inclus). **Agir/engager** (rejoindre, quitter, *escrever ao círculo*, *compartilhar catálogo*, traiter le signal) = `coordenador` (`user_can_manage_library`). — ✅ acté 04/06. *Justif. : agir engage la biblio (cohérent #PARTNERS) ; placer `círculos` sous l'admin ferait de la fédération le domaine du sommet (anti-FAU).*
- **FED-2 — Bloc « Ferramentas federalistas ».** Les outils fédéralistes (dont `círculos` est le premier) forment un bloc nommé **Ferramentas federalistas** (Outils fédéralistes), placé dans la navigation **entre `biblioteca` et `rede`**, avec un **contrôle d'accès propre** (rattachement à la biblio + mandat coordenador pour agir), **distinct de `isNetworkAdmin`**. — ✅ acté 04/06. *Label pt-BR exact et terminologie (`círculo` / `coletivo` / `afinidade`) à confirmer : FED-O4.*
- **FED-3 — Deux axes décollés.** Le modèle concentrique distingue l'**échelle de l'objet** (anneaux `catálogo → rede`) et la **portée des rôles** (`leitor → administrador`). La portée n'est pas une attribution contiguë de deux anneaux par rôle ; la symétrie 2-2-2-2 est **abandonnée** (fausse symétrie masquant une hiérarchie). — ✅ acté 04/06.
- **FED-4 — « voir ≠ agir » + deux exceptions.** Actions emboîtées vers l'extérieur ; lecture emboîtée **sauf** (a) `conta` *first-person* et (b) `círculos` ouvert vers le dedans (lecture jusqu'au leitor). — ✅ acté 04/06. *Cf. DOC-PERIM-1, RLS.*
- **FED-5 — Importações/exportações = coordenador (intégral).** Configurer les sources/partenaires, lancer un run, exporter relèvent **entièrement** du `coordenador` : ce sont des définitions politiques des relations avec des partenaires extérieurs. Pas de délégation de l'exécution au bibliotecário. — ✅ acté 04/06. *Cf. DOC-COLLECTIVE-1, section PARTNER.*
- **FED-6 — Vue limitée des comptes dans `painel`.** `conta` reste *first-person* intégral. Une **vue limitée** des comptes lecteurs vit **dans `painel`** (anneau opérationnel), accessible au staff (`librarian`/`coordenador` tenant le comptoir), **finalisée** par l'intervention à la demande du lecteur présent. L'accès est une **fonction de service**, pas un privilège de rang (« fonctions, pas hiérarchie »). — ✅ acté 04/06. *Bordures ouvertes : FED-O1, FED-O2.*
- **FED-7 — Doctrine anti-panoptique des outils fédéralistes.** Aucun outil fédéraliste ne produit de **vue agrégée du tissu relationnel** (cercles + partenariats) du réseau. La donnée n'est servie qu'à la **première personne** (une biblio voit ses cercles/partenaires, jamais le graphe du réseau). Les signaux de santé (cercle atone, etc.) sont **situés** — adressés aux membres du cercle, qui décident (autogestion) — jamais un tableau de surplomb. Pas de carte relationnelle **persistée** (recalcul à la volée si jamais nécessaire). — ✅ acté 04/06. *Justif. : un agrégat relationnel est instrumentalisable en **police idéologique intra-mouvement** (signaler les « déviances » de croisement de tendances) et concentre un **pouvoir informationnel** dans une fédération horizontale. Sœur de DOC-PERIM-1 et de ONBO-Q12 / RES-Q11-Q12 (pas de scoring du silence).*

### Points ouverts (🟡)

- **FED-O1** — Périmètre exact de la vue `painel` : empréstimos / consultas en cours + état de la carte-lecteur **oui** ; données personnelles sensibles + historique complet **non**. À border à la spec.
- **FED-O2** — Traçabilité : journaliser les consultations de compte par le staff (qui, quel compte, quand), pour que ça reste un service rendu et jamais une surveillance. Cohérent doctrine audit-transparence.
- **FED-O3** — Scope = **une** biblio (les cercles sont niveau biblio) : prévoir un **sélecteur de biblio** en tête de page si la personne est staff de plusieurs.
- **FED-O4** — Label pt-BR du bloc (*Ferramentas federalistas* / *Federalismo* ?) et terminologie de l'objet (`círculo` / `coletivo` / `afinidade`).

---

## 7. Articulations avec le corpus

- **`rede` reste l'admin réseau** (face administration : adhésions, cooptation, audit) — cf. RES (`spec-administrateur-reseau-v0.4`). `círculos` n'y appartient pas.
- **Prolonge `CHANTIER_reseau_federatif_2026-05-25`** (trace) : la face fédération y était esquissée ; ce cadrage tranche l'accès et fait de `círculos` son premier outil.
- **`spec-cartographie-reseau` (MAP)** : la carte uMap est un **gisement de données**, pas le support visuel des cercles ; le risque relationnel agrégé est verrouillé par **FED-7**.
- **#PARTNERS / section PARTNER** : `library_partnerships` (déclaration unilatérale, engage la biblio) → cohérent avec « agir = coordenador » (FED-1, FED-5).
- Doctrines transverses citées : **DOC-COLLECTIVE-1**, **DOC-PERIM-1**, **DOC-RPC-3**, **DOC-OBJ-2**, **RES-D9** (anti-méga-machine).

## 8. Conséquences à propager (étape suivante)

1. **REGISTRE_decisions.md** — créer la **section §24 `FED`** (face fédération / outils fédéralistes) avec FED-1..FED-7 + FED-O1..O4 ; header citant ce cadrage comme foyer.
2. **INDEX.md** — sous « Gouvernance et structure » (ou nouvelle sous-famille « Réseau fédératif »), annoncer la future `spec-outils-federalistes` et lister ce cadrage en trace ; noter que `círculos` / la face fédération est gouvernée par `FED`.
3. **INVENTAIRE.md** — inscrire le cadrage + ses dépendances (RES, MAP, #PARTNERS, CHANTIER réseau fédératif).
4. **Forme (Bologne)** — régénérer le schéma concentrique en cohérence, et **assumer la correction comme contenu** (la fédération n'est pas le domaine de l'administrateur) : c'est la posture « commun en construction / méthode comme acte de transparence » (RES-D9).

## 9. Prompt de reprise

> Le fond du modèle d'accès concentrique est figé (tableau §4, décisions FED-1..7). Étape immédiate : reporter FED-1..7 + FED-O1..O4 dans le REGISTRE (nouvelle section §24 `FED`), puis aligner INDEX et INVENTAIRE. Ensuite seulement : régénérer le schéma de Bologne à partir de ce fond, puis ouvrir la **spec des outils fédéralistes** (premier outil = l'annuaire des cercles ouverts, vue première personne, lecture membres / action coordenador). Bordures à spécifier le moment venu : FED-O1 (périmètre vue painel), FED-O2 (traçabilité), FED-O3 (sélecteur de biblio), FED-O4 (nommage).

---

*Fin du cadrage. Trace non-normative — voir REGISTRE §`FED` pour les décisions opposables.*
