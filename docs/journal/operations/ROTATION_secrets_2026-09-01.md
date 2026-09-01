# Liste de rotation — 2026-09-01

Ordre de traitement. Rien ici n'est théorique : chaque ligne correspond à une valeur
qui a séjourné en clair sur le disque, et pour les quatre premières, à une valeur
qui a en plus été affichée dans une conversation.

---

## Priorité 1 — aujourd'hui

### 1. Codes de récupération Cloudflare
Les huit codes se sont affichés en clair pendant le tri du 2026-09-01.
→ Compte Cloudflare › **Mon profil › Authentification à deux facteurs › Régénérer les codes de secours**.
La régénération invalide les huit anciens d'un coup. Ranger les nouveaux dans Dashlane, pas dans un fichier.

### 2. Trois valeurs affichées pendant le tri
- le `x-import-secret` des catalogues partenaires (`ANARBIB_PARTNER_IMPORT_SECRET.txt`)
- le mot de passe de CLI locale, ligne 1 de `anarbib-staging-rede secrets e credenciais.txt`
- le mot de passe non étiqueté, ligne 3 de `Secrets.txt`

Le premier est sous ton contrôle : change la valeur attendue côté fonction d'import et préviens
les bibliothèques partenaires qui l'utilisent. Les deux autres se changent là où ils servent.

### 3. Clé service_role Supabase
Elle est restée dans un `functions.env` **à l'intérieur d'une archive zip** — un objet fait pour
circuler. Tant que tu ne sais pas où cette archive est passée, considère la clé comme sortie.

Plutôt que de faire tourner le secret JWT (ce qui invaliderait aussi la clé anon et tous les
jetons de session en cours), le chemin propre est la migration vers les nouvelles clés :

1. Tableau de bord › **Settings › API Keys › onglet « Publishable and secret API keys »**
2. Créer une clé secrète `sb_secret_…` (tu as déjà une `sb_publishable_`, le nouveau système est actif sur le projet)
3. Remplacer `SUPABASE_SERVICE_ROLE_KEY` par cette clé dans les Edge Functions, et l'envoyer
   dans l'en-tête `apikey` et non `Authorization: Bearer`
4. Vérifier les webhooks de base et les appels `pg_net`, qui portent souvent la clé dans un en-tête `Authorization`
5. Une fois tout migré, désactiver les clés héritées depuis le même écran — l'opération est réversible

Avantage durable : les clés secrètes se révoquent une par une, ce que `service_role` ne permet pas.

---

## Priorité 2 — cette semaine

### 4. Les six clés Brevo
Cinq étaient dans l'archive qui circulait. Elles appartiennent toutes au même compte.
→ https://app.brevo.com/settings/keys/api : révoquer, en recréer **une par fonction qui en a
vraiment besoin**, et pas une par variable d'environnement héritée.

Au passage, tranche la contradiction : `BREVO_API_KEY_NOTIFY_INTERNAL_TASK` existe en deux valeurs,
l'une clé SMTP (`xsmtp-`), l'autre clé API v3 (`xkeysib-`). Le code n'en attend qu'une.

### 5. Les huit secrets de webhook + `VAULT_SECRET`
Ce sont des valeurs que tu génères toi-même, la rotation ne coûte rien :

```
openssl rand -base64 30
```

Regénérer les huit, les mettre dans Dashlane, puis :

```
npx supabase secrets set --env-file functions.env --project-ref uflwmikiyjfnikiphtcp
```

et supprimer le `functions.env` local juste après.

Ici aussi une contradiction à trancher : `WEBHOOK_SECRET_NOTIFY_INTERNAL_TASK` porte deux valeurs
selon le fichier. La rotation la règle d'elle-même — la nouvelle valeur devient la seule.

### 6. Mot de passe de la base Postgres
Cinq URI de connexion différentes traînaient, mot de passe inclus.
→ Tableau de bord › **Settings › Database › Reset database password**.
Ne le recolle nulle part : la CLI le redemande, et Dashlane le garde.

---

## Priorité 3 — quand tu peux

### 7. OVH
- **Codes de récupération 2FA** : dix codes en clair dans un fichier. Régénérer depuis l'espace client.
- **Mot de passe Zimbra** : à changer, et à ranger correctement — le fichier d'origine collait
  identifiant et mot de passe sur une seule ligne sans séparateur.

### 8. WorldCat
`WORLDCAT_WSKEY` et `WORLDCAT_SECRET` portent des valeurs de quatre à sept caractères :
ce sont vraisemblablement des restes de remplissage, pas de vrais identifiants. À vérifier
avant de brancher quoi que ce soit dessus.

---

## Ce qui ne demande aucune rotation

- les clés **anon** et **publishable** — publiques par conception, protégées par les politiques RLS,
  et normalement présentes dans les bundles du frontend
- les UUID, les noms de bucket, les adresses e-mail de service, les enregistrements DNS Brevo
- la référence du projet abandonné `asptfmokzykwzlshsncw`

---

## Après l'import dans Dashlane

1. Importer `ANARBIB_import_dashlane.csv` (Dashlane web › **Mon compte › Importer des données › Autre**)
2. Vérifier les 38 entrées et leurs quatre collections
3. **Supprimer le CSV**, il est en clair — Dashlane le rappelle dans sa propre documentation
4. Supprimer le dossier `_SECRETS_a_detruire_apres_import/`
5. Vider la corbeille

---

# Correctif du 2026-09-01 — Brevo et Cloudflare ne sont plus en service

Vérifié dans le dépôt :

- `RESEND_API_KEY` apparaît le **2026-05-21** (chantier #110 R.2, wrapper `sendEmail`)
- le code Brevo est retiré des transports mail le **2026-06-07** (R.6.1)

Conséquence : tout le matériel Brevo de ce lot est un fossile d'avril 2026. Les sept clés
ne sont plus **à faire tourner** mais **à révoquer**, ou à laisser mourir avec le compte.
La priorité 2.4 de la liste ci-dessus est caduque.

## Ce que le dépôt attend réellement aujourd'hui

D'après `deploy/functions.env.example` à HEAD :

```
RESEND_API_KEY                            ANTHROPIC_API_KEY
ALTCHA_HMAC_SECRET                        ACOUSTID_API_KEY
GAZETTE_CRON_SECRET                       NOTIFY_INTERLIBRARY_LOAN_WEBHOOK_SECRET
WEBHOOK_SECRET_NOTIFY_EVENT               WEBHOOK_SECRET_NOTIFY_DIGITAL_SHARE
WEBHOOK_SECRET_NOTIFY_INTERNAL_TASK       WEBHOOK_SECRET_NOTIFY_OAI_OPENING
```

**Aucune de ces valeurs n'est dans ce lot.** Pas une seule clé Resend, pas un
`ALTCHA_HMAC_SECRET`, pas un `GAZETTE_CRON_SECRET`. Elles n'existent que dans les secrets
Supabase du projet — c'est-à-dire à un seul endroit, sans copie.

C'est le vrai trou, et il est plus sérieux que le désordre qu'on vient de ranger : si l'accès
au projet Supabase se perd, ou si la migration vers le VPS tourne mal, ces valeurs partent avec.

## Priorités révisées

1. Codes de récupération Cloudflare — **seulement si le compte Cloudflare existe encore**
   (voir plus bas)
2. Le `x-import-secret` et les deux mots de passe affichés pendant le tri
3. Mettre les secrets **courants** à l'abri dans Dashlane (voir ci-dessous)
4. Clé service_role : migration vers `sb_secret_`
5. Mots de passe Postgres, OVH
6. Brevo : révocation ou fermeture du compte — sans urgence, mais à ne pas oublier,
   une clé API oubliée sur un compte dormant reste une clé API valide

---

# Correctif du 2026-09-01 (2) — comptes Brevo et Cloudflare supprimés

Xavier confirme que **les deux comptes sont supprimés**. Conséquences :

- **Cloudflare** : les huit codes de récupération ne donnent plus accès à rien. La priorité 1
  de cette liste est sans objet, y compris la valeur affichée pendant le tri.
- **Brevo** : les huit clés API ne donnent plus accès à rien non plus. Rien à révoquer,
  le compte a emporté les clés avec lui.

Les entrées correspondantes ont été retirées du CSV d'import — inutile de charger dans un
gestionnaire de mots de passe des identifiants qui ne mènent nulle part. Les lignes `BREVO_*`
ont aussi été retirées de `SECRETS_STAGING.template`.

**Il reste donc, dans les valeurs affichées pendant le tri, deux choses à traiter** et non quatre :
le `x-import-secret` des catalogues partenaires, et le mot de passe non étiqueté de la ligne 3
de `Secrets.txt` — plus le mot de passe de CLI locale, sans gravité mais à changer par principe.
