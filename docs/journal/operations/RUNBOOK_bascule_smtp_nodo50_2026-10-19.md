# Runbook — bascule du courrier sortant vers le relais Nodo50 (étape 7)

> Chantier « sortir de Resend par Nodo50 » (guide du 26/10/2026, étape 7).
> Rédigé le 19/10/2026. Session : Sortie de Resend par Nodo50.

## En une phrase

On passe le secret `MAIL_TRANSPORT` de `resend` à `smtp` : toutes les Edge Functions
envoient alors par `correo.nodo50.org:465`. Le retour arrière est le même geste en sens
inverse, sans déploiement.

## État de départ (vérifié le 19/10/2026)

| Élément | État |
|---|---|
| Code | Transport SMTP, port 465 SSL direct (`_shared/mail/smtp.ts`), cadence canal `smtp` (1 envoi/s), rejeu 4xx/timeout ×2, jamais de rejeu d'authentification, pause réseau 15 min après un échec d'authentification (a96452ff, run 1892 vert) |
| Secrets Edge Functions | `MAIL_TRANSPORT=resend`, `SMTP_HOST=correo.nodo50.org`, `SMTP_PORT=465`, `SMTP_USER=anarbib`, `SMTP_PASS` (nouveau mot de passe), `SENDER_EMAIL=no-reply@notifications.anarbib.org` (empreinte vérifiée) |
| DNS `notifications.anarbib.org` | SPF `v=spf1 include:nodo50.org ~all` ; DKIM sélecteur `notifications.anarbib.org` publié (clé 2048 bits de Nodo50) ; DMARC `p=none` |
| Essai depuis Supabase | 19/10 17:21 UTC : livré en 685 ms, SPF pass, DMARC pass, score Proton 3 |
| Plafond Nodo50 | plus de 1000 mails/jour (réponse de Nodo50, 19/10) ; AnarBib ≈ 100/jour, pointes ≈ 70 en quelques minutes |
| Hors périmètre | Les courriels de Supabase Auth passent par un SMTP propre (OVH, `ssl0.ovh.net`) : la bascule ne les touche pas |

`SMTP_ESSAI_DEST` ne sert plus (la fonction `smtp-essai` est supprimée) : on peut l'effacer.

## Quand basculer

- **Pas le lundi matin** : les rapports et digests partent le lundi entre 08:00 et 09:15 UTC
  (`notify-weekly-report` 08:00, `notify-network-weekly-report` 08:15,
  `notify-cross-library-digest` 08:30, `rede-digest` 09:00, `notify-loan-cycle` 09:15).
- Un moment où l'on peut **surveiller pendant une heure** et refaire les quatre envois.
- Idéalement **en début de semaine**, pour que le rapport hebdomadaire du lundi suivant
  serve de test grandeur nature.

## Le geste

1. Tableau de bord Supabase → Edge Functions → Secrets → « Add or replace secrets » :
   `MAIL_TRANSPORT` = `smtp` → Save. Noter l'heure UTC.
2. Aucun déploiement : les fonctions lisent le secret à leur prochain démarrage.
3. Contrôle : au premier envoi, le journal doit porter
   `[transport] envoi via SMTP (correo.nodo50.org)` et non plus `envoi via Resend`.

## Les quatre envois du chemin critique (dans l'heure)

Utiliser **une adresse Gmail** pour au moins l'un d'eux : les essais précédents n'ont visé que Proton.

| # | Envoi | Comment le déclencher | Vérifier |
|---|---|---|---|
| 1 | Inscription (`register`) | Créer un compte de test sur app.anarbib.org | Mail reçu, lien valide, en boîte de réception |
| 2 | Réinitialisation du mot de passe (`request-password-reset`) | « Mot de passe oublié » sur ce compte de test | Mail reçu, lien valide |
| 3 | Notification (`notify-event`) | Une action qui écrit à une coordination de test, par exemple un message de lecteur·rice à la bibliothèque (copie à l'équipe et accusé au lecteur·rice) | Les deux mails reçus, nom de la bibliothèque juste |
| 4 | Rapport hebdomadaire (`notify-weekly-report`) | Attendre le lundi suivant, 08:00 UTC | Reçu, logo affiché |

Pour chacun, dans les en-têtes : `spf=pass`, `dkim=pass` (`d=notifications.anarbib.org`)
et `dmarc=pass`. Le DKIM n'a pas encore été vu en `pass` : c'est le premier envoi où le
vérifier.

## Surveillance

Journaux des fonctions (les adresses y sont masquées) :

```sql
select timestamp, event_message from logs
where source = 'function_logs' and event_message like '%[transport]%'
order by timestamp desc limit 50
```

Échecs notés par le transport (la sonde `health-probe` en fait un incident) :

```sql
select occurred_at, label, recipients, error
from public.mail_transport_failures
where occurred_at > now() - interval '1 day'
order by occurred_at desc;
```

À lire pendant les deux à quatre semaines qui suivent :

- **La boîte anarbib@nodo50.org, deux fois par semaine.** C'est là que reviennent les
  « Undelivered Mail Returned to Sender ». Un renvoi automatique vers les
  administrateur·rices peut se poser dans Usermin (`https://correo.nodo50.org:20000/`).
- **Un `Échec auth SMTP` dans les échecs** veut dire mot de passe faux ou changé : le SMTP
  du réseau se met en pause 15 min (`SMTP_AUTH_PAUSE_MS`). Corriger `SMTP_PASS` ou revenir à Resend.
- **Des 4xx en rafale** veulent dire un plafond atteint : la cadence et le rejeu absorbent
  les pointes ; si ça persiste, baisser le débit (`SMTP_MIN_INTERVAL_MS`, plafonné à 2000 par la base).
- **Resend reste actif** (compte, clé `RESEND_API_KEY`, DNS `send.notifications` et
  `resend._domainkey.notifications`) pendant toute la période : c'est le filet.

## Retour arrière

- **Immédiat** : `MAIL_TRANSPORT` = `resend` dans les secrets. Aucun déploiement ;
  au premier envoi suivant, le journal reprend `envoi via Resend`.
- **Les envois déjà refusés** restent notés dans `mail_transport_failures` (libellé et
  erreur, sans adresse) : les rejouer au cas par cas si nécessaire.
- Le SPF et le DKIM Nodo50 peuvent rester en place, ils ne gênent pas Resend.

## Critère de réussite (guide)

Quatre semaines sans retour d'erreur inexpliqué ni plainte d'une bibliothèque. On passe
alors à l'étape 8 : retirer Resend (code, secret, DNS, compte, politique de
confidentialité, REGISTRE). L'étape 8 retire aussi les deux CNAME Brevo oubliés
(`brevo1._domainkey.notifications`, `brevo2._domainkey.notifications`).
