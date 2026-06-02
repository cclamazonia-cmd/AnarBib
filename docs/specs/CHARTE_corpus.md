---
Genre : référence
Statut : 🟢 référence
Décisions : incarne DOC-CLOSE-1 ; cite DOC-I18N-1, DOC-DEPLOY-1/2/3, DOC-RPC-3
Supersédé par : —
---

# 📜 CHARTE DU CORPUS — AnarBib

- **Version :** 0.1 (02/06/2026)
- **Rôle :** règles de tenue du corpus de textes (specs, décisions, traces). Une page, volontairement. Au-delà, c'est de la bureaucratie qu'on abandonnera — donc pire que le drift.
- **Compagnons :** [`REGISTRE_decisions.md`](./REGISTRE_decisions.md) (foyer des décisions) · [`INDEX.md`](./INDEX.md) (porte d'entrée + préséance) · [`INVENTAIRE.md`](./INVENTAIRE.md) (carte des dépendances).

---

## §0 — Principe directeur

**On suppose que Claude n'a aucune mémoire.** La cohérence ne repose pas sur ce qu'un·e humain·e ou l'IA *retient*, mais sur ce qui est **bâti dans ce qu'on lit**. Un·e étranger·ère compétent·e doit pouvoir ouvrir l'INDEX, ouvrir n'importe quel texte, consulter le registre, et savoir ce qui fait foi — sans rien se rappeler. Tout le reste de la charte découle de là.

## §1 — Genres de documents & préséance

Deux familles, et un ordre qui tranche les conflits.

**Couche référence** (normative — ce qui est vrai *maintenant*), par ordre de préséance :
1. **`REGISTRE_decisions.md`** — *ce qui a été choisi et si ça tient* (arbitrages + doctrines transverses).
2. **La spec courante** du domaine (version la plus récente) — *le design/comportement*.
3. **Le backlog** (`AnarBib-Backlog-…-vN`) — *l'état et les priorités*.

**Couche trace** (non-normative — un raisonnement à un instant T) : `CADRAGE_*`, `CHANTIER_*`, `SESSION_*`, `BILAN_*`, `AUDIT_*`, `QA_*`.

**Règle de conflit :** la couche référence prime toujours sur la couche trace. Une trace qui contredit une référence est **périmée par définition** — jamais une consigne.

## §2 — Une vérité, un foyer

Chaque fait a **un seul foyer**, et partout ailleurs **on cite, on ne recopie pas**.
- un *choix* → une entrée du registre (ID `DOC-…`, `RES-…`, `CAT-…`) ;
- un *design* → sa spec ;
- un *état* → le backlog ;
- un *fait transverse* (nombre de locales, doctrine de déploiement, RPC v3…) → une doctrine `DOC-…` du registre.

Une note qui **cite** un ID ne peut pas dériver ; une note qui **recopie** une valeur dérivera toujours. *(C'est la racine du drift « 6 locales » : un fait transverse recopié dans 13 specs.)*

## §3 — En-tête standard de chaque document *(le cœur)*

Tout texte du corpus porte, en première ligne, ce bloc de 4 champs :

```
---
Genre : référence | trace
Statut : 🟢 référence | 🟠 en cours | 🟡 cadrée | 🔵 historique
Décisions : incarne <IDs> ; cite <IDs>          # IDs du registre
Supersédé par : <cible>  (ou —)
---
```

Pourquoi c'est la pièce maîtresse : l'en-tête **voyage avec le document**. Même si on rate la préséance globale, le texte qu'on ouvre **se déclare lui-même** — son autorité (genre/statut), ce dont il dépend (décisions citées), et s'il est mort (supersédé par). Le drift cesse de se cacher : il s'auto-signale. C'est le seul crochet qui marche en incognito, mémoire coupée, ou project knowledge non attaché.

## §4 — Cycle de vie & tampon de supersession

Quand le contenu normatif d'un document a **gradué** ailleurs (dans une spec et/ou le registre), le document de travail reçoit, en tête, ce tampon — et son `Statut` passe à 🔵 :

> ⚠️ **Document de travail — historique.** Contenu normatif passé dans : `spec-X` (design), `DEC-Y` (arbitrages). **Ne pas utiliser comme source.**

C'est la note de clôture en blockquote déjà pratiquée sur les specs 🔵, généralisée à *tous* les genres trace.

## §5 — Checklist de clôture de chantier *(extension de « close before open »)*

Un chantier n'est **pas** clos quand le code part en prod. Il est clos quand :

- [ ] ses **choix** sont inscrits au registre (un ID par décision, statut ✅) ;
- [ ] son **design** est à jour dans la (les) spec(s) concernée(s), en-tête `Décisions` renseigné ;
- [ ] son **état** est reporté au backlog ;
- [ ] ses **documents de travail** (cadrage, session…) sont **tamponnés** (§4) ;
- [ ] INDEX/INVENTAIRE reflètent les éventuelles nouvelles specs ou dépendances.

Tant qu'une case manque, le chantier est ouvert — même si « ça marche ».

## §6 — Comment Claude s'y repère *(les 3 crochets, inscrits ici pour ne pas dépendre d'une conversation)*

1. **Point d'entrée unique** — la préséance est en tête d'`INDEX.md`, formulée avec des mots cherchables (« préséance », « source de vérité », « registre »). Premier réflexe : lire l'INDEX.
2. **En-tête par document** (§3) — le filet de sécurité, parce qu'il est *dans* le fichier.
3. **Crochet mémoire** — une instruction durable (« avant tout travail doc/code, consulter le registre + la préséance ; référence > trace ») chargée à chaque session.

Ordre de robustesse : 2 > 1 > 3. Le crochet 2 survit à tout ; les crochets 1 et 3 sautent en incognito / mémoire coupée / project knowledge non attaché. **Donc : investir d'abord dans les en-têtes.**

## §7 — Ce qu'on ne fait PAS

- **Pas de réécriture de masse.** Corriger les ~13 « 6 locales » d'un coup n'est pas prioritaire : la préséance (`DOC-I18N-1` + bloc INDEX) les neutralise. On les corrige spec par spec, à la réouverture.
- **Pas de doc pour la doc.** Plafond : **1 page de charte + un en-tête de 4 lignes.** Si une règle ne tient pas dans ce budget, elle ne mérite pas d'exister.

---

*Fin v0.1. Cette charte est elle-même une référence : elle porte l'en-tête qu'elle prescrit, et toute évolution passe par une décision tracée au registre.*
