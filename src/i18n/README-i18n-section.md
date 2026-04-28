## i18n — Internationalisation

L'interface est disponible en **6 langues** :

| Locale | Statut | Convention de langage inclusif |
|---|---|---|
| `pt-BR` | Locale de référence | Forme triple `(o/a/e)` ou `(a/e)` |
| `fr` | Cohérente | Point médian (`lecteur·rice`) |
| `es` | Cohérente | `e` neutre argentin (`compañere`) + articles neutres (`le`, `les`, `une`) |
| `en` | Cohérente | Termes épicènes par défaut |
| `it` | Cohérente | Slash (`compagno/a`) — convention provisoire |
| `de` | Cohérente | Genderstern (`Genoss*in`) |

L'application détecte automatiquement la langue du navigateur. Un sélecteur permet de la changer manuellement.

### Architecture

```
src/i18n/
├── index.js              # Configuration react-intl + détection navigateur
└── locales/
    ├── pt-BR.json        # Locale de référence (~1393 clés)
    ├── fr.json
    ├── es.json
    ├── en.json
    ├── it.json
    └── de.json
```

### Documents de référence

Avant toute traduction ou ajout de clé, consulter **obligatoirement** :

- `docs/charte-langage-inclusif.md` — Charte v1.0 fixant les conventions inclusives par langue, les termes politiques de référence et **les termes proscrits** (notamment `camerata` en italien).
- `notes-audit/` — Rapports d'audit de cohérence i18n.

### Workflow d'ajout d'une nouvelle clé

1. **Ajouter la clé dans le code** : utiliser `t({id:'mon.nouveau.label'})` (jamais de chaîne en dur).
2. **Définir la clé dans `pt-BR.json`** (référence).
3. **Traduire dans les 5 autres locales** en respectant la charte de langage inclusif.
4. **Lancer les tests** : `npm test` — le test `i18n.test.js` vérifie automatiquement que toutes les clés du code sont définies dans toutes les locales.

Une clé partiellement traduite est un bug — le test fera échouer le build.

### Modèle de prompt pour traduction par IA

Si tu utilises une IA (Claude, GPT…) pour traduire, **toujours fournir la charte en contexte** :

```
Tu traduis pour AnarBib (SIGB de bibliothèques militantes anarchistes).
Convention de langage inclusif obligatoire pour [LANGUE] : voir docs/charte-langage-inclusif.md.
Ne jamais utiliser : camerata/camerati (italien, fasciste), Compas non traduit (allemand), 
formes bureaucratiques /a ou (a) seul (espagnol et portugais).
Privilégier les formes épicènes quand elles existent.

Texte à traduire : [...]
```

### Ajouter une nouvelle langue

1. Créer `src/i18n/locales/xx.json` (copier `pt-BR.json` et traduire).
2. Ajouter la locale dans `src/i18n/index.js` (`SUPPORTED_LOCALES` + `MESSAGES`).
3. Compléter la section "Charte par langue" du document `docs/charte-langage-inclusif.md` avec la convention typographique militante locale.
4. Lancer `npm test` pour vérifier la couverture complète.

### Tests de garde-fou

`i18n.test.js` exécute trois familles de tests :

- **Cohérence inter-locales** : toutes les locales ont le même ensemble de clés que `pt-BR.json`.
- **Couverture code ↔ locales** : toute clé `t({id:'...'})` utilisée dans `src/` est définie dans toutes les locales. Empêche le merge de toute clé manquante.
- **Conformité à la charte** : aucune occurrence de `camerata` en italien, aucun `Compas` non traduit en allemand, pas de formes bureaucratiques en pt-BR/es au-delà d'un seuil de tolérance.

Lancer avec : `npm test` ou `npx vitest`.
