# Message à Herbes Folles — dimensionnement du VPS pour AnarBib

> Brouillon prêt à envoyer (mail / messagerie). Rédigé le 2026-07-03 à partir de
> [`DECISION_arbitrage_migration_vps_2026-07-03`](../arbitrages/DECISION_arbitrage_migration_vps_2026-07-03.md)
> et du [`MEMO_migration_supabase_vers_vps_2026-06-19`](../cadrages/MEMO_migration_supabase_vers_vps_2026-06-19.md).
> À relire / adapter au ton de la relation avant envoi. **Ce n'est pas encore envoyé.**

---

Objet : **AnarBib — quelques questions avant de migrer chez vous**

Salut les camarades,

On prépare le déménagement d'AnarBib depuis Supabase (l'hébergeur actuel) vers votre
VPS. Avant de s'engager dans la bascule, on a besoin de savoir si la machine peut
accueillir l'appli confortablement. Rien d'urgent, mais vos réponses décident de la
suite.

**Le contexte en deux phrases.** AnarBib n'est pas « un site » mais un petit
assemblage de services (base de données, authentification, API, stockage de
fichiers, fonctions serveur, tâches planifiées). La façon la plus propre de le
remonter chez vous, c'est via **la version auto-hébergeable de Supabase** : une
**pile Docker** clé en main qui regroupe tout ça. C'est cette piste qu'on privilégie
— d'où plusieurs questions autour de Docker et de la RAM.

**Bonne nouvelle côté volume : c'est léger.** Aujourd'hui la base fait **~100 Mo** et
les fichiers (couvertures, PDF, logos…) **~430 Mo**, soit **~530 Mo de données au
total**. Le disque n'est donc pas le sujet ; la RAM et la maintenance dans la durée,
si.

## Nos 6 questions

1. **RAM.** La pile Docker complète demande **au moins ~4 Go de RAM, 8 Go pour être
   à l'aise**. Combien pouvez-vous allouer durablement à AnarBib ? *(C'est LA
   question qui décide de tout : si c'est trop juste, on adaptera la stratégie.)*

2. **Docker.** **Docker et Docker Compose** sont-ils disponibles / autorisés sur la
   machine ?

3. **PostgreSQL 17.** Peut-on faire tourner **PostgreSQL version 17** ? *(Notre base
   est en 17.6 ; migrer vers une version différente peut coincer.)*

4. **Disque.** Les données sont petites (~530 Mo), mais les **images Docker + les
   volumes + une marge pour les sauvegardes** pèsent quelques Go. Peut-on compter
   sur **~20 Go dédiés** ?

5. **Accès.** Un **accès SSH par clé** (plutôt que par mot de passe) : identifiant,
   port, et l'ajout de notre clé publique ? *(Même principe que la clé de
   sauvegarde qu'on vous a déjà transmise pour `bricolage.herbesfolles.org`.)*

6. **Maintenance dans la durée.** C'est le point le plus important, et il n'est pas
   technique : une fois chez vous, **c'est vous qui sauvegardez**. Qui, côté
   Herbes Folles, **lancera et surveillera la pile**, et surtout **testera une
   restauration de sauvegarde chaque mois** ? On a déjà mis en place notre chaîne de
   sauvegarde de notre côté ; l'idée est de savoir comment on se répartit le suivi
   pour que ça tienne dans le temps.

On peut aussi en discuter de vive voix si c'est plus simple — dites-nous ce qui vous
arrange.

Merci à vous, et à bientôt.

*(AnarBib)*

---

### Aide-mémoire interne (ne pas envoyer)

- **Pourquoi ces valeurs** : Q1/Q4 = besoin réel de la pile Supabase self-hosted
  (≈ 10 conteneurs) ; Q3 = la base source est en **17.6** ; Q5 = on a déjà la clé
  `id_ed25519_bg2` posée chez eux (BG2), donc le rapport SSH existe.
- **Ce qu'on fait de la réponse Q1** : ≥ 4 Go → stratégie **A** (self-hosted Docker)
  confirmée ; RAM trop juste → rebascule sur la stratégie B (décomposition) ou une
  pile allégée. Cf. `DECISION_arbitrage_migration_vps_2026-07-03` §2 (D1) et §4.
- **Non demandé volontairement** : SMTP interne (on reste sur Resend, décision D2) et
  hébergement du frontend (reste sur Codeberg Pages, décision D3) → pas de charge
  supplémentaire pour eux sur ces deux points.
