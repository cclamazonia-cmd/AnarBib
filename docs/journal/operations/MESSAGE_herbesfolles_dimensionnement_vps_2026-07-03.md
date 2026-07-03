# Message à Herbes Folles — héberger AnarBib chez vous ? (au-delà des sauvegardes)

> Brouillon prêt à envoyer (mail). Rédigé le 2026-07-03, **révisé** le même jour après
> relecture du fil HF (29-30/06) : l'accès actuel est un **espace de sauvegarde
> SFTP-only** (pas un hébergement), la **clé SSH backup est déjà transmise**, HF **fait
> tourner du mail**, et le **don est déjà évoqué**. Base :
> [`DECISION_arbitrage_migration_vps_2026-07-03`](../arbitrages/DECISION_arbitrage_migration_vps_2026-07-03.md).
> À relire / adapter au ton de la relation avant envoi. **Pas encore envoyé.**

---

Objet : **AnarBib — et si on hébergeait tout chez vous ? (au-delà des sauvegardes)**

Salut les camarades,

Merci encore pour l'espace de sauvegarde que vous nous avez monté (le SFTP tourne, la
clé arrive). On aimerait maintenant **aller plus loin** : à terme, quitter Supabase
(notre hébergeur actuel, états-unien) et **héberger l'ensemble d'AnarBib chez vous** —
la base, les fichiers, le site, les mails. Et, comme je le demandais déjà, **contribuer
financièrement** à la hauteur de ce que ça représente pour vous (on pensait ~50 €/mois,
à ajuster ensemble).

Avant de s'engager, il faut qu'on sache ce que votre infra permet — parce que ce dont
on parle est **très différent** de l'espace de sauvegarde actuel.

**Le contexte en deux phrases.** L'espace SFTP actuel sert juste à déposer des dumps.
Héberger l'appli vivante, c'est autre chose : AnarBib est un **assemblage de services**
(base de données, authentification, API, stockage, fonctions serveur, tâches
planifiées) qui se remonte le plus proprement via une **pile Docker** (≈ 10 conteneurs)
— ça demande donc une **machine avec un shell et des ressources**, pas seulement un
dossier de dépôt.

**Rassurez-vous côté volume : c'est léger.** La base fait **~100 Mo**, les fichiers
**~430 Mo**, soit **~530 Mo au total**. Le nerf de la guerre, c'est la **RAM** et la
**maintenance dans la durée**, pas le disque.

## Nos questions

**La question qui décide de tout**

1. **Proposez-vous ce type d'hébergement ?** Au-delà du stockage de sauvegardes,
   pouvez-vous nous fournir un endroit où **faire tourner une pile Docker** — une VM
   ou un conteneur avec **shell**, **Docker + Docker Compose**, et de la **RAM dédiée
   (~4 Go minimum, 8 Go confortable)** ? *(Si ce n'est pas dans vos offres, dites-le
   sans souci : on prendra un VPS ailleurs et on gardera HF pour les sauvegardes —
   et peut-être les mails, cf. Q5.)*

**Si oui, quelques précisions**

2. **PostgreSQL 17.** Peut-on faire tourner **PostgreSQL version 17** ? *(Notre base
   est en 17.6 ; une version différente peut coincer à la restauration.)*

3. **Disque.** Au-delà des ~530 Mo de données, **images Docker + volumes + marge de
   sauvegardes** pèsent quelques Go. Peut-on compter sur **~20 Go dédiés** ?

4. **Le site (frontend).** C'est un **site statique** (quelques Mo) ; aujourd'hui sur
   Codeberg Pages, qu'on trouve **trop instable**. Pourriez-vous le **servir**
   (fichiers statiques + domaine `app.anarbib.org` en HTTPS) ? *(Léger, juste des
   fichiers à distribuer — vous avez déjà Caddy en frontal.)*

**L'e-mail (vous en faites déjà !)**

5. On a vu que vous faites tourner du mail (webmail + SMTP `mail.herbesfolles.org`).
   AnarBib envoie des mails importants — confirmations, **réinitialisations de mot de
   passe**, notifications — qu'on veut faire sortir de notre prestataire américain.
   Pourrait-on les **envoyer depuis `@anarbib.org` via votre serveur** (un compte ou
   un relais d'envoi authentifié) ? Et comment se porte la **réputation d'envoi** de
   vos IP (déjà « chaudes », reverse-DNS, SPF/DKIM/DMARC) — pour que nos mails
   n'atterrissent pas en spam ? *(Si c'est trop, on prendra un service transactionnel
   européen — mais on préférerait rester chez vous.)*

**Sur la durée (le vrai enjeu)**

6. Une fois chez vous, **c'est vous qui sauvegardez et exploitez**. Qui, côté Herbes
   Folles, **lancera et surveillera la pile**, et **testera une restauration chaque
   mois** ? C'est précisément ce que la **contribution mensuelle** vise à rendre
   soutenable — dites-nous aussi **comment vous verser ce soutien** (ma question du
   dernier message tient toujours).

On peut évidemment en discuter de vive voix si c'est plus simple pour vous.

Merci pour tout ce boulot, et à bientôt.

*(AnarBib)*

---

### Aide-mémoire interne (ne pas envoyer)

- **Le pivot** : l'accès actuel = **sauvegarde SFTP chroot, sans shell** (BG2). Q1
  teste si HF offre un **hébergement Docker** (VM/conteneur+shell) — service *différent*.
  **Si non → VPS ailleurs**, HF reste backup (+ mail éventuel). C'est le vrai
  make-or-break, avant la RAM.
- **Clé SSH backup** : déjà transmise (`…anarbib-backup`) → **plus une question ici**.
  ⚠️ Les mots de passe SFTP ont circulé en clair dans le fil → à **retirer/rotater**
  une fois l'auth par clé + désactivation du mot de passe confirmées côté serveur.
- **Q5 e-mail (D2)** : HF **est mail-capable** (webmail/SMTP) → piste crédible. Reste à
  valider l'envoi *depuis un domaine tiers* `@anarbib.org` + la **délivrabilité**
  (réputation IP). Repli si insuffisant : transactionnel EU (Scaleway TEM / Infomaniak)
  ou Autistici. Ne jamais dépendre d'une IP à mauvaise réputation pour les réinit. MDP.
- **Q4 frontend (D3)** : quasi acquis — statique, trivial à servir via leur Caddy ;
  remplace Codeberg (instable).
- **Don ~50 €/mois (D6)** : déjà évoqué auprès d'eux ; renforce la durabilité (Q6).
- **Charte HF « A4 »** : https://www.herbesfolles.org/charte — relire pour être raccord.
