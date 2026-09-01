# Clôture du chantier des secrets — 2026-09-01

Point d'arrivée d'une journée partie d'un dossier en vrac, `Ficheiros diversos`, et finie avec
une cartographie complète des identifiants d'AnarBib.

## Où vivent les secrets, désormais

| Emplacement | Contenu | Rôle |
|---|---|---|
| **Dashlane** | 32 entrées du lot rangé + 21 du Vault + 4 clés de fournisseur | la référence |
| **Vault Postgres** | 21 secrets, lisibles par un rôle privilégié | ce que l'appelant SQL utilise |
| **Secrets Edge Functions** | 78 variables | ce que le code lit |
| **Clé USB hors ligne** | sel de pseudonymisation, clé de récupération du gestionnaire, phrase de passe des sauvegardes, clé GPG privée | dernier recours |

**Plus aucun secret en clair sur les disques de la machine de travail.** Douze emplacements ont
été comparés par empreinte SHA aux 84 valeurs en service, et les trois dépôts git fouillés objet
par objet, historique compris : aucun secret réel, ni à HEAD ni dans le passé. Ce que git
contient est public par conception — clé anon, nom de bucket, UUID, adresses de service,
enregistrements DNS.

## Fait le 2026-09-01

- 17 fichiers porteurs de secrets rangés puis supprimés
- `index_register_staging.ts` assaini (clé Brevo codée en dur) puis retiré
- `anarbib_edge_bundle_rewritten.zip`, qui transportait un `functions.env` complet, remplacé par
  une copie assainie
- `.gitignore` posé sur le dossier de travail
- clés Resend, Anthropic et AcoustID recréées ; `ALTCHA_HMAC_SECRET` régénéré ; les quatre rangés
- comptes Brevo et Cloudflare supprimés : leurs clés du lot d'avril ne mènent nulle part

Voir `INVENTAIRE_secrets_2026-09-01.md`, `ROTATION_secrets_2026-09-01.md` et
`SECRETS_COURANTS_2026-09-01.md` dans ce même dossier.

## Reste à faire

**Court terme** — révoquer les anciennes clés Resend et Anthropic, une fois un mail de test passé.

**Après Bologne**

1. Désactiver les clés héritées (Settings › API Keys). C'est la seule chose qui neutralise la clé
   `service_role` d'avril, encore valable jusqu'en 2036 quelle que soit la variable
   d'environnement. Le code est prêt : `_shared/core/secret-key.ts` lit déjà
   `SUPABASE_SECRET_KEYS` et la plateforme l'injecte.
2. Supprimer `TURNSTILE_SECRET_KEY` — compte Cloudflare supprimé, anti-robots passé à Altcha — et
   vérifier que `login`, `register` et `submit-cartography-entry` n'appellent plus Turnstile
   ailleurs qu'en commentaire.
3. Supprimer les 13 variables Edge Functions définies mais vides.
4. Regarder ce qu'est `anarbib_staging_anon_key` dans le Vault : 18 caractères, ce n'est pas une clé.

## Deux règles à retenir

**Un secret de webhook vit des deux côtés** — dans le Vault, d'où l'appelant SQL le lit avant
`net.http_post`, et dans les secrets Edge Functions, où le destinataire le vérifie. N'en
régénérer qu'un seul coupe les notifications, sans erreur visible.

**Une clé de fournisseur ne se relit pas.** Chez Resend comme chez Anthropic, elle ne s'affiche
qu'à la création. « En faire une copie » n'existe pas comme opération : soit on la range au
moment où elle apparaît, soit il faut en créer une nouvelle.
