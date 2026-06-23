# Addenda de confidentialité par bibliothèque

Sources versionnées des sections « spécifiques à la bibliothèque » de la
politique de confidentialité, rendues par
[`src/components/privacy/LibraryPrivacySection.jsx`](../../../src/components/privacy/LibraryPrivacySection.jsx).

- **Structure** : `library-privacy/<slug>/privacy-<locale>.md`
- **Bucket public** : `library-privacy-public/<slug>/privacy-<locale>.md`
- **Locales servies** (DOC-I18N-1) : `pt-BR, fr, es, it, de, en, ca, eo, nl, el`
  (repli automatique sur `pt-BR` si une locale manque pour une biblio).

## Déploiement

Action prod délibérée — la clé `service_role` se fournit à l'exécution (jamais
stockée) :

```
SUPABASE_SERVICE_ROLE_KEY=eyJ... node scripts/upload-library-privacy.mjs [slug]
```

Idempotent (`upsert`). Vérification : ouvrir `/privacidade/<slug>` dans l'app et
basculer la langue.

## État (2026-06-23)

- `blmf/` : les 6 versions historiques (`de, en, es, fr, it, pt-BR`) ont été
  déposées **à la main** dans le bucket avant ce dossier ; seules les 4
  traductions ajoutées le 2026-06-23 (`ca, eo, nl, el`) sont versionnées ici.
  Pour un dépôt git complet, on pourra y rapatrier aussi les 6 historiques.
