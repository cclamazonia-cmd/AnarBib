# Les secrets réellement en service — 2026-09-01

Établi en lisant le code déployé (`supabase/functions/*` à HEAD du dépôt `Codeberg/anarbib`),
et non les fichiers du dossier, qui datent d'avril.

## Ce que le code réclame, et ce qui en existe une copie

| Variable | Rôle | Copie hors Supabase ? |
|---|---|---|
| `RESEND_API_KEY` | envoi de tous les mails (10 fonctions) | **aucune** |
| `ANTHROPIC_API_KEY` | gazette mensuelle, traduction des contributions | **aucune** |
| `GAZETTE_CRON_SECRET` | authentifie le cron de la gazette | **aucune** |
| `ALTCHA_HMAC_SECRET` | anti-robots des formulaires publics | **aucune** |
| `ACOUSTID_API_KEY` | empreintes audio (fonds sonores) | **aucune** |
| `NOTIFY_INTERLIBRARY_LOAN_WEBHOOK_SECRET` | webhook prêt inter-bibliothèques | **aucune** |
| `WEBHOOK_SECRET_NOTIFY_EVENT` | webhook notify-event | oui, dans Dashlane |
| `WEBHOOK_SECRET_NOTIFY_INTERNAL_TASK` | webhook tâches internes | oui — mais **deux valeurs contradictoires** |
| `SUPABASE_SERVICE_ROLE_KEY` | repli hérité | oui, dans Dashlane |
| `SUPABASE_ANON_KEY` | clé publique | oui (et publique de toute façon) |
| `SUPABASE_SECRET_KEYS` | injecté par la plateforme | sans objet |

Six secrets vivants n'ont de copie nulle part. Ils n'existent que dans les secrets Supabase
du projet `uflwmikiyjfnikiphtcp`.

## La nuance qui compte

Une clé Resend ou Anthropic ne se relit pas. Le tableau de bord ne l'affiche qu'une fois, à la
création. Donc « faire une copie » de `RESEND_API_KEY` n'existe pas comme opération : soit tu
as gardé la valeur quelque part, soit il faut **en créer une nouvelle**, la ranger dans Dashlane,
puis remplacer l'ancienne dans les secrets Supabase et révoquer celle-ci.

C'est une demi-heure de travail, et c'est ce qui te sépare d'un projet reconstructible.
Avec la migration vers le VPS au programme, ça ne peut pas rester en l'état.

## Bonne surprise : la migration `sb_secret_` est déjà écrite

`supabase/functions/_shared/core/secret-key.ts` lit `SUPABASE_SECRET_KEYS` — l'objet JSON
`{nom: clé}` que la plateforme injecte — et ne retombe sur `SUPABASE_SERVICE_ROLE_KEY` que si
la clé « default » manque. Neuf fonctions le documentent en tête de fichier.

Autrement dit, le chantier que je te proposais est déjà fait côté code. Il reste à vérifier
que la plateforme injecte bien la clé, puis à désactiver les clés héritées dans
Settings › API Keys. L'opération est réversible.

## Deux incohérences relevées au passage

- `deploy/functions.env.example` liste `ACOUSTID_API_KEY`, `ALTCHA_HMAC_SECRET`,
  `WEBHOOK_SECRET_NOTIFY_DIGITAL_SHARE` et `WEBHOOK_SECRET_NOTIFY_OAI_OPENING`, qui n'apparaissent
  dans aucun `Deno.env.get` des fonctions — ils sont lus ailleurs (`_shared/altcha.ts`,
  `audio_fingerprint_lookup`, `notify-digital-share`, `notify-oai-opening`). Le gabarit et le
  code ne se recoupent pas exactement.
- quatre secrets de webhook du lot rangé (`NOTIFY_WEEKLY_REPORT`, `NOTIFY_MID_LOAN`,
  `NOTIFY_LIBRARY_REQUEST`, `NOTIFY_NETWORK_WEEKLY_REPORT`) n'apparaissent plus nulle part dans
  le code courant. Soit les fonctions ont été renommées, soit ces secrets sont orphelins et
  peuvent être supprimés côté Supabase.

## Pour confirmer

Une seule commande, qui n'affiche que les noms et des empreintes, jamais les valeurs :

```
npx supabase secrets list --project-ref uflwmikiyjfnikiphtcp
```

Colle-moi la sortie et je te dis exactement quels secrets sont posés, lesquels sont orphelins,
et laquelle des deux valeurs de `WEBHOOK_SECRET_NOTIFY_INTERNAL_TASK` est celle qui tourne —
son empreinte SHA suffit à trancher.

---

# Réconciliation avec les secrets réellement posés (2026-09-01)

`supabase secrets list` donne le SHA-256 de chaque valeur. Comparé aux empreintes de
l'inventaire, cela tranche tout ce qui restait en suspens.

## Ce qui est confirmé en service

| Variable | Où la valeur se trouvait |
|---|---|
| `ANARBIB_PARTNER_IMPORT_SECRET` | `ANARBIB_PARTNER_IMPORT_SECRET.txt` |
| `WEBHOOK_SECRET_NOTIFY_INTERNAL_TASK` | **« Secrets perdus.docx » ligne 3** (étiquetée `VAULT_SECRET`) |
| `WEBHOOK_SECRET_NOTIFY_LIBRARY_REQUEST` | `SECRETS STAGING COMPLET.template` |
| `WEBHOOK_SECRET_NOTIFY_MID_LOAN` | idem |
| `WEBHOOK_SECRET_NOTIFY_NETWORK_WEEKLY_REPORT` | idem |
| `WEBHOOK_SECRET_NOTIFY_WEEKLY_REPORT` | idem |
| `SUPABASE_ANON_KEY` | contient en fait la clé `sb_publishable_`, pas un JWT |

## Trois corrections à ce que j'avais écrit

1. **La contradiction sur `WEBHOOK_SECRET_NOTIFY_INTERNAL_TASK` n'avait pas deux termes mais
   trois.** Aucune des deux valeurs de 40 caractères n'est en service. La valeur active est
   celle de 64 caractères rangée sous l'étiquette `VAULT_SECRET`. Le fichier « Secrets perdus.docx »
   contenait donc le seul exemplaire d'un secret vivant.
2. **`WEBHOOK_SECRET_NOTIFY_EVENT` du lot est périmé** — la valeur en service est différente.
3. **Les quatre webhooks que je disais orphelins ne le sont pas.** Ils sont bien lus, mais par
   le câblage `pg_net` des migrations et par `notify-library-request`, `notify-loan-cycle`,
   `notify-mid-loan-reading`, `notify-weekly-report`, `notify-network-weekly-report` — pas par
   un `Deno.env.get` littéral, ce que ma première recherche manquait.

## La clé service_role : la bonne et la mauvaise nouvelle

La valeur posée dans `SUPABASE_SERVICE_ROLE_KEY` (`e8bb3a65…`) **n'est pas** celle qui circulait
dans l'archive (`2bd50e84…`). La copie qui traînait n'est donc pas celle que les fonctions utilisent.

Cela ne la rend pas inoffensive. Une clé `service_role` est un JWT signé par le secret du projet :
elle reste valable jusqu'à son expiration — 2036 — **quelle que soit la variable d'environnement**,
tant que les clés héritées ne sont pas désactivées. Celle de l'archive ouvre donc toujours la base.

C'est ce qui rend l'étape « désactiver les clés héritées » nécessaire et non plus optionnelle.
Le code est prêt : la plateforme injecte bien `SUPABASE_SECRET_KEYS`, et `secret-key.ts` la
préfère déjà au repli hérité.

## Dix-huit secrets vivants sans copie

`RESEND_API_KEY` · `ANTHROPIC_API_KEY` · `ACOUSTID_API_KEY` · `ALTCHA_HMAC_SECRET` ·
`GAZETTE_CRON_SECRET` · `TURNSTILE_SECRET_KEY` · `NOTIFY_INTERLIBRARY_LOAN_WEBHOOK_SECRET` ·
`SUPABASE_DB_URL` · `SUPABASE_JWKS` · `SUPABASE_SECRET_KEYS` · `SUPABASE_PUBLISHABLE_KEYS` ·
`SUPABASE_SERVICE_ROLE_KEY` · et six webhooks : `NOTIFY_EVENT`, `NOTIFY_CROSS_LIBRARY_DIGEST`,
`NOTIFY_DIGITAL_SHARE`, `NOTIFY_DOCUMENT_PERMISSION_REQUEST`, `NOTIFY_OAI_OPENING`,
`NOTIFY_REDE_DIGEST`.

Les six webhooks se régénèrent sans rien casser d'autre. Les clés de fournisseur ne se relisent
pas : il faut en créer de nouvelles.

## Deux scories

- **`TURNSTILE_SECRET_KEY` est toujours posé** alors que le compte Cloudflare est supprimé.
  L'anti-robots est passé à Altcha, mais Turnstile apparaît encore dans `login`, `register`,
  `submit-cartography-entry` et `_shared/altcha.ts` — à vérifier que ce ne sont que des restes
  de commentaires, sinon ces chemins échouent silencieusement. Le secret est à supprimer.
- **Treize variables sont définies mais vides** (`ADMIN_NAME`, `BRAND_NAME`, `FOOTER_TEXT`,
  `REGIMENTO_URL`, `REPLY_TO_EMAIL`, `LIBRARY_*`, `BLMF_INTERNAL_REDIRECT_EMAIL`,
  `BTL_INTERNAL_REDIRECT_EMAIL`, `ADMIN_EMAIL_NOTIFY_EVENT`). Vérifié : aucune n'est lue avec
  `??`, donc la chaîne vide tombe bien sur les replis `||`. C'est du bruit, pas un bug —
  mais autant les supprimer.

## Vingt-six valeurs du lot sont périmées

Elles ne correspondent à aucun secret posé : les clés Brevo, la clé service_role d'avril,
les URI Postgres de « Récupérer le SQL du projet.txt », les deux valeurs de 40 c du webhook
internal-task, la clé anon JWT. Elles sont marquées « (périmé) » dans le CSV — importe-les
quand même, elles documentent l'histoire, ou supprime ces lignes avant l'import si tu préfères.
