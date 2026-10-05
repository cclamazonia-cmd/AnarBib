# AnarBib

**Français** · [English](README.en.md) · [Português](README.pt-BR.md)

AnarBib est un logiciel libre pour faire vivre des bibliothèques anarchistes et libertaires : cataloguer un fonds, prêter des livres, ouvrir des documents à la lecture, et relier les bibliothèques entre elles en un réseau fédéré, sans centre ni propriétaire.

- **L'application** : [app.anarbib.org](https://app.anarbib.org)
- **Le site du projet** : [anarbib.org](https://anarbib.org)
- **Le code** : [codeberg.org/anarbib/anarbib](https://codeberg.org/anarbib/anarbib)
- **Écrire** : anarbib@proton.me

---

## Pourquoi un outil de plus

Des logiciels de bibliothèque libres existent déjà — PMB, Koha. AnarBib n'a de sens que s'il fait autre chose : un outil pensé depuis les pratiques du milieu libertaire, où **les choix politiques passent avant les choix techniques**, et où une technique qui contredit ces principes doit céder. Sans purisme pour autant : entre deux principes qui se contredisent dans la pratique, le projet choisit ce qui est faisable plutôt que de ne rien faire.

Concrètement, cela donne :

- **Chaque bibliothèque décide pour elle-même.** Comment elle catalogue, prête, s'ouvre au réseau et se gouverne : ce sont des réglages qu'elle choisit, pas des règles imposées d'en haut.
- **Les décisions communes se prennent à plusieurs.** Coopter une personne à l'administration du réseau, confier la coordination d'une bibliothèque : l'outil en fait des actes collégiaux, pas les décisions d'une seule personne.
- **Un réseau sans centre.** Les catalogues se partagent par un protocole ouvert (OAI-PMH) ; une bibliothèque garde la main sur ce qu'elle publie.
- **Pas de pistage.** Aucun traceur, publicitaire ou statistique ; l'anti-robot et le fond de carte sont servis par l'infrastructure du projet, sans appel à un service extérieur.
- **Un vocabulaire commun, pas confisqué.** L'indexation par sujet s'appuie sur le [thésaurus partagé de la FICEDL](https://thesaurus.ficedl.info), dont AnarBib reprend les libellés sans jamais les réécrire.
- **Dix langues, une écriture inclusive.** L'interface existe en portugais du Brésil, français, espagnol, anglais, italien, allemand, catalan, espéranto, néerlandais et grec, selon une [charte de langage inclusif](docs/notes-audit/anarbib-charte-langage-inclusif-v2.md) propre à chaque langue.

## Qui l'utilise

Au 5 octobre 2026, trois bibliothèques ont leur catalogue ouvert au public dans AnarBib :

- la **Biblioteca Terra Livre** ;
- la **Biblioteca Libertária Maxwell Ferreira**, portée par le Centro de Cultura Libertária da Amazônia (CCLA), à Belém do Pará, au Brésil ;
- la **Maloca Libertária / Biblioteca Emma Goldman**.

Deux autres préparent leur arrivée : la **Bibliothèque Solidaires** (Paris) et **Anarchief.Org**.

## Ce que fait l'application

- **Un catalogue public** qu'on parcourt par œuvre, par auteur·rice, par sujet ou par bibliothèque, avec une carte du réseau.
- **Le catalogage** : notices, fiches d'autorité, sujets, exemplaires ; import et export de catalogues (dont les fichiers de PMB) pour qu'aucune bibliothèque ne soit prisonnière de l'outil.
- **La circulation** : prêts, réservations, consultations sur place, prêt entre bibliothèques.
- **Le numérique** : lecture en ligne de documents, ouverte au public ou réservée aux membres selon les droits de chaque œuvre.
- **Les outils du réseau** : biens communs, entraide, annuaire des collectifs, assemblées, et une gazette mensuelle.

## Rejoindre, aider

- **Une bibliothèque veut rejoindre le réseau ?** La demande se fait depuis l'application ([app.anarbib.org/solicitar-biblioteca](https://app.anarbib.org/solicitar-biblioteca)), ou en écrivant à anarbib@proton.me. Aucune condition technique : on en parle d'abord.
- **Aider sans écrire de code** — relire une langue, indexer par sujet, tenir un rôle dans le réseau, tester l'installation : [`AIDER.md`](AIDER.md) dit ce qui est le plus utile aujourd'hui.
- **Soutenir les frais** (hébergement, courriel, nom de domaine) : les comptes sont publics sur [anarbib.org](https://anarbib.org).
- **Contribuer au code** : [`CONTRIBUTING.md`](CONTRIBUTING.md), puis [`docs/CHANTIERS_OUVERTS.md`](docs/CHANTIERS_OUVERTS.md).

## Un projet fragile, et qui le dit

AnarBib repose aujourd'hui sur très peu de mains : une seule personne qui maintient le code, une seule qui administre le réseau, et un seul serveur d'intégration continue, sur un poste de travail. Nous préférons l'écrire que le taire : toute aide qui réduit l'une de ces dépendances compte plus qu'une fonctionnalité de plus.

**Sur l'usage de l'IA** *(état au 5 octobre 2026)*. AnarBib est développé avec l'assistance d'un modèle de langage, et nous le disons plutôt que de le laisser deviner. C'est cette assistance qui a permis à l'outil d'exister, porté par une personne sans formation en développement ; elle crée en retour une dépendance que le projet cherche à réduire : en documentant le fonctionnement plutôt que le code, en gardant la technique aussi simple que possible, et en ouvrant le développement à d'autres mains. Les décisions restent humaines et collectives ; elles sont écrites dans le [registre des décisions](docs/specs/REGISTRE_decisions.md). Côté application, trois fonctions font appel à un modèle de langage : la préparation et la traduction de la gazette du réseau, et une pré-traduction des titres d'œuvres, toujours signalée comme « à relire » et qui n'écrase jamais un titre saisi à la main. Ni la circulation, ni les données des lecteur·rices n'en dépendent.

## Pour développer

AnarBib est une application web (React et Vite) appuyée sur Supabase (PostgreSQL et fonctions Deno).

**Installer une copie complète chez soi**, en une commande (Docker requis) :

```bash
./install.sh
```

L'installateur parle les dix langues du projet ; le détail est dans [`deploy/README.md`](deploy/README.md).

**Lancer les tests** :

```bash
npm test
```

**Où trouver quoi** :

- [`CONTRIBUTING.md`](CONTRIBUTING.md) — mettre en route, le rythme du travail, ce qu'il faut lire avant de toucher au code.
- [`docs/INDEX.md`](docs/INDEX.md) — la carte de la documentation (spécifications, guides, manuels en dix langues).
- [`docs/specs/REGISTRE_decisions.md`](docs/specs/REGISTRE_decisions.md) — le registre des décisions, qui fait foi.
- [`docs/backlogs/`](docs/backlogs/INDEX.md) — ce qui est en cours, ce qui reste à faire, et l'état chiffré du projet, daté.

Le dépôt de référence est sur Codeberg ; chaque envoi sur la branche `main` y déclenche l'intégration continue (tests, puis déploiement). Le miroir GitHub n'est plus synchronisé.

## Licences

- **Le code** est sous [GNU AGPL v3](LICENSE) : quiconque met en ligne une version modifiée doit en publier les modifications sous la même licence.
- **La documentation** est sous [Creative Commons BY-SA 4.0](LICENSE-docs).

Les bibliothèques sont encouragées à reprendre, adapter, traduire et republier l'un comme l'autre, à condition de partager leurs adaptations sous les mêmes licences.

---

*Ce README ne porte volontairement aucun chiffre qui vieillit vite : ils vivent, datés, dans le [backlog](docs/backlogs/INDEX.md). L'ancienne version, plus technique, est archivée dans [`docs/archive/README-2026-08-30.md`](docs/archive/README-2026-08-30.md).*
