---
Genre : trace (note de cadrage)
Statut : 🔵 historique — gradué
Décisions : a gradué au REGISTRE §19 (ILL-1..ILL-9) ; incarné par spec-flux-partage-numerique v0.2
Supersédé par : REGISTRE §19 (foyer des décisions) + spec-flux-partage-numerique (design)
---

> **🔵 Document de travail — historique (tampon du 02/06/2026).** Les questions ouvertes de la section 4 ont toutes été arbitrées le 02/06/2026 (mandat BLMF). Les décisions font foi au **REGISTRE §19** (`ILL-1` à `ILL-9`) et sont incarnées dans `spec-flux-partage-numerique` v0.2 (charpente figée côté conception). Le point structurant de la section 3 (circuit distinct du PEB) est confirmé. Conservé pour mémoire du raisonnement ; en cas de divergence, le REGISTRE prime.

# AnarBib — #ILL-digital — Note de cadrage
## Partage numérique entre bibliothèques

*Document de cadrage — 25/05/2026. Sous-travail #ILL-digital du chantier PEB. Statut (à l'origine) : à spécifier. Ce document NE contient PAS de spécification technique : il pose les questions ouvertes à trancher avant toute conception. Plusieurs de ces questions relèvent d'un choix politique du collectif, non d'une décision technique.*

## 1. Pourquoi ce document

Le chantier PEB (prêt entre bibliothèques) est clos : cinq de ses six sous-travaux sont livrés et en production. Le sixième, #ILL-digital — le partage numérique de documents entre bibliothèques — a été délibérément laissé de côté, non par manque de temps mais parce que le besoin lui-même n'est pas encore spécifié.

Ce document recense les questions à trancher. Il a vocation à être discuté — éventuellement porté aux bibliothèques utilisatrices — avant qu'une seule ligne de code ou de schéma ne soit écrite. Tant que ces questions restent ouvertes, #ILL-digital demeure au backlog au statut « à spécifier », et non « à coder ».

## 2. Le besoin esquissé

Entre deux bibliothèques éloignées, faire circuler un document épuisé, rare ou fragile passe rarement par l'envoi physique de l'objet. La voie courante est la dématérialisation : la bibliothèque qui détient le document le numérise (scan, photographie), transmet un fichier (PDF, images) à la bibliothèque demandeuse, qui le consulte à l'écran ou l'imprime localement.

La caractéristique déterminante : il n'y a pas de retour d'objet. Le fichier est transmis, point. Ce n'est pas un prêt au sens habituel — rien ne fait l'aller-retour.

## 3. Le point structurant : un circuit distinct, pas une extension du PEB

C'est la décision de cadrage la plus importante, et elle est déjà prise : le partage numérique ne sera PAS modélisé comme un PEB d'un genre particulier. Il constituera un circuit à part entière.

**Pourquoi pas une extension du PEB.** Toute la machinerie du PEB — les statuts (emprestado, em_devolucao, devolvido), les triggers de cycle de vie, la détection de retard, le pointage de retour exemplaire par exemplaire, l'archivage — présuppose un objet physique qui part puis revient. Le partage numérique casse ce présupposé : rien ne revient, il n'y a ni retour ni retard possible. Greffer une exception « numérique » sur cette machine à états, tout juste verrouillée par le sous-travail #ILL-lifecycle, la fragiliserait : chaque trigger, chaque calcul devrait désormais se demander s'il a affaire à un PEB ordinaire ou numérique. Le coût de maintenance et le risque de régression seraient disproportionnés.

**Un circuit distinct, plus simple.** Modélisé à part, le partage numérique se réduit à un flux court : une demande de numérisation, une transmission, une clôture. Deux ou trois états, pas de cycle de retour. Chaque circuit reste simple et lisible séparément.

**Un circuit à cheval sur trois domaines.** Le partage numérique ne se range pas dans un seul module de l'application. Il traverse au moins trois domaines fonctionnels : Biblioteca (la demande naît entre deux bibliothèques, comme une relation de réseau), Catalogação (le document numérisé est rattaché à une notice, à un exemplaire — quel statut documentaire pour une version numérique ?), et Importações (un fichier reçu d'une autre bibliothèque entre dans le fonds local — par quel canal, avec quelles métadonnées ?). Cette transversalité est elle-même une question de conception : le circuit devra être pensé comme un fil traversant ces trois domaines, non comme une fonctionnalité isolée. C'est aussi ce qui en fait un chantier à part entière, et non un appendice.

## 4. Questions ouvertes — à trancher avant toute conception

> *Note historique (02/06/2026) : toutes les questions ci-dessous ont été tranchées. Les réponses font foi au REGISTRE §19 (`ILL-1` à `ILL-9`).*

### 4.1 Périmètre et statut des documents

Ces questions sont d'abord politiques. Elles appellent une position du collectif, pas une réponse technique.

- Que numérise-t-on et que s'autorise-t-on à diffuser ? Domaine public, ouvrages épuisés, brochures et matériel militant, fonds propre de la bibliothèque : ces catégories n'ont pas le même statut. Le circuit doit-il distinguer ?
- La bibliothèque anarchiste a vraisemblablement une position sur la libre circulation des savoirs. Cette position doit être explicitée : elle déterminera ce que le circuit autorise, refuse ou signale.
- Le partage est-il strictement de bibliothèque à bibliothèque, ou un document numérisé peut-il être mis à disposition plus largement (lecteurs et lectrices, public) ? Cela change radicalement la nature du circuit.

*→ Tranché : `ILL-1` (périmètre matériel gris, ISBN/ISSN hors cible), `ILL-2` (demi-verrou ISBN/ISSN), `ILL-3` + `ILL-9` (plafond de diffusion non-élargissable, mécanique), `ILL-5` (catalogage = libre de droits).*

### 4.2 Cycle de vie du fichier

- Que devient le fichier après usage ? Conservation durable par la bibliothèque demandeuse (il rejoint son fonds), ou suppression après consultation (le partage est ponctuel) ?
- Si le fichier est conservé : où ? Rattaché à une notice de catalogue comme un exemplaire numérique ? Stocké comme pièce jointe du circuit ? La réponse engage Catalogação et le stockage (Supabase Storage).
- La bibliothèque qui numérise garde-t-elle une trace du fichier transmis, ou seulement de la demande satisfaite ?

*→ Tranché : `ILL-4` (ponctuel sans copie / versement durable bucket privé), `ILL-6` (conservation patrimoniale de la source ; audit = demande satisfaite, pas copie).*

### 4.3 Le flux et ses états

- Quels états pour le circuit ? Une esquisse minimale : demande émise → numérisation en cours → fichier transmis → clôturé. Faut-il un état de refus ? un état « document indisponible » ?
- Qui peut initier une demande de numérisation : le staff seulement, ou aussi un lecteur ou une lectrice via une bibliothèque ?
- La transmission du fichier passe-t-elle par l'application (upload / download via Supabase Storage) ou hors application ? Ce dernier point est sensible vu la doctrine du projet (cf. migration Resend, choix anti-tracking).

*→ Tranché : `ILL-7` (flux `demandé → accepté|refusé|indisponible → numérisation → transmis → clôturé` ; initiation staff biblio↔biblio ; transmission via l'app ; section dédiée aux comptes-rendus hebdo). Rôles précis : remplissage de la spec.*

### 4.4 Articulation avec l'existant

- Le circuit numérique réutilise-t-il la notion de partenaires de correspondance (chantier #PARTNERS) pour savoir entre quelles bibliothèques le partage est ouvert ?
- Un document déjà présent au catalogue sous forme physique peut-il recevoir une version numérique « de partage » ? Quelle granularité côté Catalogação ?
- Le circuit numérique doit-il apparaître dans les comptes-rendus hebdomadaires, au même titre que la section PEB ajoutée par #ILL-reports ?

*→ Tranché : `ILL-8` (droit du partenariat stabilisé, réutilise `library_partnerships`), `ILL-5` (granularité catalogage), `ILL-7` (comptes-rendus).*

## 5. Prochaine étape

Ce document n'appelait pas une réponse immédiate. La prochaine étape n'était pas une migration ni un composant : c'était une discussion. Les questions de la section 4.1 en particulier engageaient un positionnement politique.

> *Étape franchie (02/06/2026) : les questions ont été arbitrées sous mandat BLMF (`ILL-1..ILL-9`), et la spécification `spec-flux-partage-numerique` a été charpentée (v0.2, figée côté conception). Le sous-travail #ILL-digital passe au backlog du statut « à spécifier » au statut « charpenté, à coder après remplissage ».*

*Fin du document de cadrage #ILL-digital. Classé dans `docs/decisions/`. Converti de `.docx` en `.md` le 02/06/2026 (doctrine : les documents de travail ne circulent pas, donc restent en `.md`).*
