# Message à Herbes Folles — hébergement d'AnarBib (partenariat + dimensionnement)

> Brouillon prêt à envoyer (mail / messagerie). Rédigé le 2026-07-03, **révisé** le
> même jour pour intégrer l'orientation « tout héberger chez HF + contribution
> ~50 €/mois » (réouverture des décisions D2 e-mail / D3 frontend). Base :
> [`DECISION_arbitrage_migration_vps_2026-07-03`](../arbitrages/DECISION_arbitrage_migration_vps_2026-07-03.md).
> À relire / adapter au ton de la relation avant envoi. **Ce n'est pas encore envoyé.**

---

Objet : **AnarBib — vous héberger tout ? (partenariat + quelques questions)**

Salut les camarades,

On prépare le déménagement d'AnarBib depuis Supabase (l'hébergeur actuel, états-unien)
vers votre infra. Et plutôt que de saupoudrer entre plusieurs prestataires, on
aimerait, **si ça vous intéresse, héberger l'ensemble chez vous** — base de données,
fichiers, et même le site — **en contribuant financièrement, de l'ordre de 50 €/mois**.
L'idée est autant militante (sortir des GAFAM et des USA) que pratique (un seul
interlocuteur de confiance). Avant de s'engager, quelques questions pour savoir ce qui
est faisable de votre côté. Rien d'urgent.

**Le contexte en deux phrases.** AnarBib n'est pas « un site » mais un petit
assemblage de services (base de données, authentification, API, stockage de fichiers,
fonctions serveur, tâches planifiées). La façon la plus propre de le remonter chez
vous, c'est via **la version auto-hébergeable de Supabase** : une **pile Docker** clé
en main qui regroupe tout ça — d'où plusieurs questions autour de Docker et de la RAM.

**Bonne nouvelle côté volume : c'est léger.** La base fait **~100 Mo** et les fichiers
(couvertures, PDF, logos…) **~430 Mo**, soit **~530 Mo au total**. Le disque n'est
donc pas le sujet ; la RAM et la maintenance dans la durée, si.

## Nos questions

**Sur la pile principale (base + services)**

1. **RAM.** La pile Docker complète demande **au moins ~4 Go de RAM, 8 Go pour être
   à l'aise**. Combien pouvez-vous allouer durablement à AnarBib ? *(C'est LA
   question qui décide de tout : si c'est trop juste, on adaptera.)*

2. **Docker.** **Docker et Docker Compose** sont-ils disponibles / autorisés ?

3. **PostgreSQL 17.** Peut-on faire tourner **PostgreSQL version 17** ? *(Notre base
   est en 17.6 ; migrer vers une version différente peut coincer.)*

4. **Disque.** Au-delà des ~530 Mo de données, les **images Docker + volumes + marge
   de sauvegardes** pèsent quelques Go. Peut-on compter sur **~20 Go dédiés** ?

5. **Accès.** Un **accès SSH par clé** (identifiant, port, ajout de notre clé
   publique) ? *(Même principe que la clé de sauvegarde qu'on vous a déjà transmise
   pour `bricolage.herbesfolles.org`.)*

**Sur le reste qu'on aimerait consolider chez vous**

6. **Le site (frontend).** C'est un **site statique** (quelques Mo de fichiers) ;
   aujourd'hui sur Codeberg Pages, qu'on trouve **trop instable**. Pourriez-vous le
   **servir** (fichiers statiques + un domaine `app.anarbib.org` avec certificat
   HTTPS) ? *(Léger, sans base ni traitement — juste des fichiers à distribuer.)*

7. **L'envoi des e-mails.** AnarBib envoie des mails importants (confirmations,
   **réinitialisations de mot de passe**, notifications) — aujourd'hui via un
   prestataire américain qu'on veut quitter. **Faites-vous tourner un serveur mail /
   relais** qu'on pourrait utiliser pour envoyer depuis `@anarbib.org` ? Si oui,
   comment se porte votre **réputation d'envoi** (IP déjà « chaude », reverse-DNS,
   SPF/DKIM/DMARC) ? *(C'est le point le plus délicat : un serveur mail neuf finit
   souvent en spam. Si vous ne faites pas de mail, aucun souci — on prendra un
   service transactionnel européen ; on ne vous demande pas d'en monter un pour nous.)*

**Sur la durée (le vrai enjeu)**

8. **Maintenance.** Une fois chez vous, **c'est vous qui sauvegardez**. Qui, côté
   Herbes Folles, **lancera et surveillera la pile**, et surtout **testera une
   restauration de sauvegarde chaque mois** ? On a déjà notre chaîne de sauvegarde de
   notre côté ; la contribution mensuelle vise justement à rendre ce suivi soutenable
   dans le temps.

On peut aussi en discuter de vive voix si c'est plus simple.

Merci à vous, et à bientôt.

*(AnarBib)*

---

### Aide-mémoire interne (ne pas envoyer)

- **Partenariat ~50 €/mois (D6)** : sert autant à soutenir HF qu'à **rendre la Q8
  maintenance soutenable** (hébergement rémunéré > bénévolat pur).
- **Q1/Q4** = besoin réel de la pile Supabase self-hosted (≈ 10 conteneurs) ;
  **Q1 RAM** décide stratégie A (self-hosted) vs B (repli si RAM trop juste).
- **Q3** = base source en **17.6**. **Q5** = clé `id_ed25519_bg2` déjà posée (BG2).
- **Q6 frontend (D3)** : quasi acquis — statique, trivial à servir depuis leur
  reverse-proxy ; remplace Codeberg (instable). Repli = rester sur Pages.
- **Q7 e-mail (D2)** : le **seul point à ne pas décider à l'aveugle**. Si HF n'a pas
  de mail réputé → **transactionnel européen** (Scaleway TEM / Infomaniak), ou
  Autistici (déjà utilisé pour la visio). **Ne jamais** monter un SMTP sur IP fraîche
  juste pour nous : la délivrabilité prime (réinit. de mot de passe = ne doit pas
  spammer). Resend gardé seulement en transition/dernier recours.
