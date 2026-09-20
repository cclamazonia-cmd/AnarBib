# RUNBOOK — Câbler `.org.br` et `.is` comme routes d'accès

> **Versé au dépôt le 20/09/2026** depuis le poste (rédigé le 07/09, jamais exécuté). Les deux
> domaines sont enregistrés et payés ; rien n'est câblé. **Relevé du 17 et du 20/09, qui amende
> le texte ci-dessous sur trois points :**
>
> 1. **`api.anarbib.org` n'existe pas** (aucun enregistrement), et l'application parle
>    directement à Supabase, dont l'adresse est en dur dans le front (couvertures, vignettes,
>    règlements : `BibliotecaPage`, `AccountPage`, `AuthorPage`, `BookPage`). Tant que la
>    production est chez Supabase, **la phase 1.2 (API sur la VM) est sans objet** : un domaine
>    de repli ne concerne que le front (Codeberg Pages), les URL de redirection de
>    l'authentification (phase 3) et les listes blanches CORS.
> 2. **Les zones DNS sont chez les registres eux-mêmes** : `anarbib.is` sur les serveurs de
>    forwarding d'ISNIC, `anarbib.org.br` sur le DNS automatique de Registro.br (`a.auto.dns.br`) ;
>    `anarbib.org` est chez OVH. **Aucun `ALIAS`/`ANAME` sur l'apex** chez ces deux registres :
>    ce sera A + AAAA vers les adresses de Codeberg, avec la vérification annuelle que la
>    phase 1.1 prévoit.
> 3. **Phase 0 faite en lecture seule** : 162 occurrences d'`anarbib.org` côté application
>    (courriels, tests, une migration : identité et décor), 854 côté vitrine (494 liens vers
>    `anarbib.org`, 257 vers `app.anarbib.org`). Côté CORS, 27 Edge Functions posent l'en-tête ;
>    au moins une, `submit-cartography-entry`, n'accepte que `https://app.anarbib.org` — la
>    liste complète reste à dresser (annexe B, point 1).
>
> Partage des gestes : les enregistrements chez ISNIC et Registro.br et les URL de redirection
> du tableau de bord Supabase demandent les accès de Xavier ; le reste (tri, correctifs CORS,
> adresse Supabase configurable, script de l'annexe A, entrée au REGISTRE) se prépare sans eux.

**Rédigé le 07/09/2026.** À exécuter quand les deux enregistrements sont validés et payés,
et **après la levée du gel de production** (gel en vigueur depuis le 08/09).

**Principe.** `anarbib.org` reste le domaine canonique. `.org.br` et `.is` sont des
**routes d'accès** que l'on câble à froid, que l'on éprouve une fois, puis que l'on
laisse dormir. Le but n'est pas de déménager : c'est d'avoir une porte de sortie
dont on sait qu'elle ouvre.

**Durée.** ~2 h de travail, plus 24 h de propagation DNS avant la phase 6.
**Retour arrière.** Chaque phase est réversible en retirant les enregistrements DNS
posés. Rien dans ce runbook ne modifie le service en place.

---

## Ce qui est déjà vrai — vérifié le 07/09/2026

À lire avant d'exécuter : ces quatre constats évitent quatre fausses inquiétudes.

1. **Les identifiants OAI ne contiennent pas de nom de domaine.** Ils sont de la forme
   `oai:anarbib:<slug-biblio>:<id>`. Un changement de domaine ne casse donc **aucune**
   déduplication chez les moissonneurs. (Vérifié dans `oai-pmh-provider/index.ts`.)
2. **La `baseURL` annoncée par `Identify`, elle, suit le domaine** : elle est reconstruite
   à partir de l'en-tête `x-forwarded-host`. Servir OAI sur deux domaines annonce deux
   `baseURL` différentes — voir phase 4, c'est une question de coordination avec RebAl,
   pas un défaut.
3. **Le CORS ne bloquera rien** : les fonctions lues (`login`, `altcha-challenge`,
   `oai-pmh-provider`) répondent en `Access-Control-Allow-Origin: *`.
   *Non vérifié : les 49 autres. Voir annexe B.*
4. **Codeberg Pages n'utilise plus de fichier `.domains`.** L'autorisation passe
   désormais par un enregistrement TXT dans le DNS.

---

## Phase 0 — Inventaire (30 min, à faire une fois)

Repérer tout ce qui contient un domaine en dur. À lancer dans chacun des deux dépôts.

```bash
# Dépôt applicatif
cd ~/AnarBib
grep -rn "anarbib\.org" --include="*.js" --include="*.jsx" --include="*.ts" \
  --include="*.tsx" --include="*.json" --include="*.html" --include="*.sql" . \
  | grep -v node_modules | tee /tmp/domaines-app.txt

# Dépôt vitrine (10 pages écrites à la main : c'est là qu'il y en a le plus)
cd ~/Codeberg/anarbib_site
grep -rn "anarbib\.org" --include="*.html" --include="*.json" --include="*.cjs" . \
  | tee /tmp/domaines-vitrine.txt

wc -l /tmp/domaines-app.txt /tmp/domaines-vitrine.txt
```

Trier le résultat en trois tas, et ne rien modifier à ce stade :

| Tas | Quoi | Action |
|---|---|---|
| **Identité** | identifiants OAI, espace de noms, adresses de courriel, mentions légales | **ne bouge jamais** |
| **Accès** | URL de l'API, liens internes, `baseURL`, flux OPDS/RSS | doit devenir configurable |
| **Décor** | textes, exemples, documentation | sans effet technique |

Noter aussi le TTL actuel des enregistrements de `anarbib.org` :

```bash
dig +nocmd anarbib.org A +noall +answer
dig +nocmd app.anarbib.org A +noall +answer
dig +nocmd api.anarbib.org A +noall +answer
```

---

## Phase 1 — DNS (20 min par domaine, puis 24 h d'attente)

Deux zones à poser par domaine : le **front** (servi par Codeberg Pages) et l'**API**
(servie par la VM des Herbes Folles).

### 1.1 — Front, sur Codeberg Pages

Trois enregistrements, dans cet ordre :

```
# Routage — apex : pas de CNAME possible, donc A + AAAA
anarbib.is.        300  IN  A     217.197.84.141
anarbib.is.        300  IN  AAAA  2a0a:4580:103f:c0de::2

# ou, sur un sous-domaine, un CNAME est préférable
app.anarbib.is.    300  IN  CNAME codeberg.page.

# Autorisation — sans lui, Codeberg refuse de servir le dépôt
_git-pages-forge-allowlist.anarbib.is.  300  IN  TXT  "https://codeberg.org/anarbib/pages.git"
```

> **Le TXT est en `_git-pages-forge-allowlist`** parce que le déploiement passe par
> Forgejo Actions. Si un jour ça repasse par webhook, le nom devient
> `_git-pages-repository`. Se tromper de préfixe donne un domaine qui résout et ne sert rien.

> **Les adresses IP de Codeberg sont codées en dur** dans leur documentation. Si ton
> hébergeur DNS propose `ALIAS`/`ANAME` sur l'apex, le préférer : ça survit à un
> changement d'IP chez eux. Sinon, poser une alerte de vérification annuelle.

Répéter pour `anarbib.org.br` avec le même dépôt cible.

### 1.2 — API, sur la VM

```
api.anarbib.is.    300  IN  A  <IPv4 de la VM Herbes Folles>
```

> **Ne pas poser d'enregistrement AAAA.** La VM est en IPv4 seulement. Annoncer une
> adresse IPv6 injoignable est exactement le défaut qui a bloqué la répétition d'août :
> le client tente l'IPv6 en premier, échoue, et le diagnostic prend une heure.

### 1.3 — Garde-fous, sur les trois domaines

- **TTL à 300 s** partout tant que la bascule n'a pas été éprouvée. Le remonter à 3600 après.
- **CAA** : si tu en poses, y autoriser explicitement Let's Encrypt, sinon Codeberg ne peut pas
  émettre le certificat.
  ```
  anarbib.is.  IN  CAA  0 issue "letsencrypt.org"
  ```
- **DNSSEC** activé, **verrouillage du domaine** activé chez le registre.
- **2FA** sur les comptes ISNIC et Registro.br, et **deux personnes** avec accès.

---

## Phase 2 — Certificats (10 min, après propagation)

```bash
for d in anarbib.is anarbib.org.br; do
  echo "=== $d"
  dig +short A "$d"
  dig +short TXT "_git-pages-forge-allowlist.$d"
  curl -sS -o /dev/null -w "  HTTP %{http_code}  cert=%{ssl_verify_result}\n" "https://$d/"
done
```

Attendu : `HTTP 200` et `cert=0`. Un `526` ou une erreur TLS signifie que le certificat
n'est pas encore émis — attendre, ne pas retoucher le DNS.

---

## Phase 3 — Authentification (20 min) — **le seul vrai point de blocage**

C'est ici, et nulle part ailleurs, qu'un domaine non déclaré fait échouer les parcours
de connexion et de réinitialisation de mot de passe, **en silence**.

**Sur Supabase hébergé** — tableau de bord, *Authentication → URL Configuration* :
- `Site URL` : laisser `https://app.anarbib.org` (le lien des courriels est construit à
  partir de cette valeur — voir l'avertissement plus bas) ;
- `Redirect URLs` : **ajouter** les nouveaux domaines, sans retirer les anciens.
  ```
  https://app.anarbib.org/**
  https://anarbib.is/**
  https://app.anarbib.is/**
  https://anarbib.org.br/**
  ```

**Sur la pile auto-hébergée** — `deploy/.env` :
```dotenv
SITE_URL=https://app.anarbib.org
URI_ALLOW_LIST=https://app.anarbib.org/**,https://anarbib.is/**,https://app.anarbib.is/**,https://anarbib.org.br/**
API_EXTERNAL_URL=https://api.anarbib.org
API_DOMAIN=api.anarbib.org
```

> **À savoir avant de s'étonner** : le lien contenu dans un courriel de réinitialisation
> est fabriqué à partir de `SITE_URL`, pas du domaine sur lequel la personne a fait sa
> demande. Quelqu'un qui demande une réinitialisation depuis `anarbib.is` recevra donc
> un lien vers `app.anarbib.org`. **Ce n'est pas un défaut, c'est une décision** : tant
> que le domaine canonique répond, c'est le comportement voulu. Le jour d'une bascule
> réelle, changer `SITE_URL` fait partie de la manœuvre — c'est la ligne à ne pas oublier.

**Test, à faire depuis chaque domaine :**
1. ouvrir la page de connexion, se connecter avec un compte d'essai → doit aboutir ;
2. demander une réinitialisation → le courriel doit arriver, et son lien doit ouvrir une
   page fonctionnelle ;
3. créer un compte sur le bac à sable → le défi Altcha doit se résoudre.

---

## Phase 4 — Fédération OAI-PMH (15 min) — celle qu'on oublie

Les identifiants ne bougent pas (constat 1). Ce qui bouge, c'est la `baseURL` annoncée.

**Décision à prendre, et à écrire :** garder **un seul point d'entrée OAI annoncé**, celui
du domaine canonique. Ne pas communiquer les autres à RebAl ni à Ola : un moissonneur qui
enregistre deux `baseURL` pour le même dépôt moissonne deux fois.

Vérifier que l'endpoint répond, sur le domaine canonique :

```bash
BASE="https://<host>/functions/v1/oai-pmh-provider"

curl -sS "$BASE?verb=Identify"            | head -20
curl -sS "$BASE?verb=ListSets"            | head -20
curl -sS "$BASE?verb=ListMetadataFormats" | head -20
# une notice précise, en remplaçant slug et id par des valeurs réelles
curl -sS "$BASE?verb=GetRecord&identifier=oai:anarbib:<slug>:<id>&metadataPrefix=oai_dc"
```

Dans la réponse `Identify`, contrôler que `<baseURL>` correspond bien à l'adresse que tu
as donnée à la fédération, et que `<adminEmail>` est celle que tu veux publier — elle vaut
`fede@anarbib.org` par défaut, surchargeable par la variable `OAI_ADMIN_EMAIL`.

---

## Phase 5 — Les autres surfaces (30 min)

| Surface | À vérifier | Commande / geste |
|---|---|---|
| **OPDS** | le flux contient-il des URL absolues ? | `curl -sS "https://<host>/functions/v1/opds" \| grep -o 'https://[^"<]*' \| sort -u` |
| **RSS** | idem | `curl -sS "https://<host>/functions/v1/rss-novidades" \| grep -o 'https://[^"<]*' \| sort -u` |
| **Vitrine** | 10 pages écrites à la main, liens en dur | résultat de la phase 0 |
| **Générateurs** | `build-finances-pages.cjs`, `build-privacy-pages.cjs` | relancer et vérifier les liens produits |
| **Courriel** | expéditeur inchangé → **rien à faire** | si un jour il change : SPF, DKIM **et** DMARC sur le nouveau domaine, plus la vérification du domaine chez le prestataire d'envoi |

> Le courriel est le piège classique : un domaine expéditeur changé sans DMARC ne part pas
> en indésirable, il est **rejeté**. Ne jamais changer l'expéditeur dans la même soirée
> qu'un changement de domaine d'accès.

---

## Phase 6 — L'essai de bascule (1 h) — **la seule étape qui prouve quelque chose**

À faire un jour calme, jamais la veille d'un événement.

1. Basculer `api.anarbib.is` vers l'IPv4 de la VM, si ce n'est pas déjà fait, et servir
   l'application depuis `anarbib.is`.
2. Dérouler la liste ci-dessous, dans l'ordre, en notant l'heure de début et de fin.
3. Remettre en place et vérifier que tout refonctionne sur le domaine canonique.

**Liste de contrôle — tout doit passer :**

- [ ] catalogue public consultable **sans compte**
- [ ] recherche unifiée : une requête de 4 caractères renvoie des suggestions
- [ ] connexion avec un compte d'essai
- [ ] réinitialisation de mot de passe : courriel reçu, lien fonctionnel
- [ ] création de compte : défi Altcha résolu, courriel de confirmation reçu
- [ ] une action authentifiée qui écrit en base (une réservation sur le bac à sable)
- [ ] `Identify` OAI répond, et `<baseURL>` annonce le bon hôte
- [ ] flux OPDS et RSS accessibles
- [ ] une page de la vitrine dans chacune des 10 locales

**Consigner le temps réel de la manœuvre.** C'est ce chiffre — et pas la théorie — qui dira
si le repli est utilisable un dimanche soir.

---

## Phase 7 — Écrire la décision

Porter au REGISTRE (`docs/specs/REGISTRE_decisions.md`, dans le dépôt applicatif) une
entrée qui fixe la doctrine, pas seulement les gestes :

> **Domaines.** `anarbib.org` est le domaine canonique et l'adresse annoncée à la
> fédération. `anarbib.org.br` (titulaire : CCLA) et `anarbib.is` sont des routes d'accès
> de repli, câblées et éprouvées le <date>, non annoncées. Les identifiants OAI
> (`oai:anarbib:…`) sont indépendants du domaine et ne changent en aucun cas. Une bascule
> réelle suppose de modifier `SITE_URL` et de prévenir RebAl du changement de `baseURL`.

L'identifiant d'entrée est à toi ; je ne l'invente pas.

---

## Essai de bascule du 20/09/2026 — partie publique, faite et verte

*Phase 6, moins ses parcours authentifiés. Durée mesurée de la passe : **15 secondes** pour les
quinze contrôles automatisables (script `bascule_essai.sh`, hors dossier). Ce n'est pas le
chiffre que la phase 6 demande — celui d'une manœuvre complète — mais c'est celui d'un contrôle
de santé, et il peut se rejouer à chaque changement de DNS.*

| Contrôle | Canonique | Repli `anarbib.is` |
|---|---|---|
| Application servie | 200, 4 165 o | 200, 4 165 o |
| Même version servie | empreinte `48f8cfcd2fb5` | identique, même bundle `index-CHU28CMf.js` |
| Vitrine | 200 (IPv6 seulement, voir plus bas) | 307 vers le canonique |
| Vitrine, dix langues | — | 307 pour les dix |
| Catalogue public sans compte | 3 bibliothèques publiques, 200 | — (même API) |
| Recherche unifiée, 4 caractères | 10 résultats, 200 | — |
| Préflight CORS des 3 formulaires | origine rendue = celle demandée | origine rendue = `app.anarbib.is` |
| OAI `Identify` | `baseURL` = celle du canonique, `adminEmail` = `fede@anarbib.org` | inchangée, à dessein |
| OPDS racine / acquisition | 1 / 18 entrées | — |
| RSS `blmf` | 30 entrées | — |
| `www.anarbib.org` | 307 vers le canonique (réparé le 20/09) | — |

**Ce que l'essai a trouvé, et qui ne se voyait pas autrement.** Le script tournait dans WSL, qui
n'a pas d'IPv6 : la vitrine canonique y répondait `000` pour les dix langues, alors qu'elle
répond 200 depuis Windows. Ce n'était pas un faux positif du script mais un vrai défaut, que
seule une machine sans IPv6 pouvait voir — **l'enregistrement A de la racine de `anarbib.org`
avait été remplacé par l'adresse de parking d'OVH (`213.186.33.5`)** dans la journée, si bien
que le site n'était plus joignable qu'en IPv6. Corollaire à garder : **un contrôle qui ne teste
qu'une pile d'adresses ne teste pas le site** ; `curl -4` et `curl -6` séparément, ou une sonde
sur une machine sans IPv6.

**Reste à faire, avec un compte d'essai** (les quatre lignes authentifiées de la liste de la
phase 6) : connexion, réinitialisation de mot de passe (le courriel mène à `SITE_URL`, donc au
canonique — c'est voulu), création de compte avec défi Altcha, et une écriture en base depuis le
domaine de repli. Elles demandent des identifiants : à faire avec Xavier, un jour calme, jamais
la veille d'une soirée de formation.

## Annexe A — Toutes les vérifications en un bloc

```bash
#!/usr/bin/env bash
# verif-domaines.sh — à lancer après chaque modification DNS
set -u
DOMAINES=("anarbib.org" "anarbib.is" "anarbib.org.br")
API=("api.anarbib.org" "api.anarbib.is")

for d in "${DOMAINES[@]}"; do
  printf '\n=== FRONT %s\n' "$d"
  printf '  A     : %s\n' "$(dig +short A "$d" | tr '\n' ' ')"
  printf '  AAAA  : %s\n' "$(dig +short AAAA "$d" | tr '\n' ' ')"
  printf '  TXT   : %s\n' "$(dig +short TXT "_git-pages-forge-allowlist.$d")"
  printf '  CAA   : %s\n' "$(dig +short CAA "$d" | tr '\n' ' ')"
  curl -sS -o /dev/null -w "  HTTP %{http_code} cert=%{ssl_verify_result} en %{time_total}s\n" "https://$d/" || echo "  injoignable"
done

for a in "${API[@]}"; do
  printf '\n=== API %s\n' "$a"
  printf '  A     : %s\n' "$(dig +short A "$a" | tr '\n' ' ')"
  aaaa=$(dig +short AAAA "$a")
  [ -n "$aaaa" ] && printf '  !! AAAA présent (%s) alors que la VM est IPv4 seule\n' "$aaaa"
  curl -sS -o /dev/null -w "  HTTP %{http_code} en %{time_total}s\n" "https://$a/functions/v1/health-probe" || echo "  injoignable"
done
```

## Annexe B — Ce que je n'ai pas pu vérifier

À contrôler toi-même avant d'exécuter ; je ne les ai pas contrôlés et je ne les suppose pas.

1. **Le CORS des 49 autres Edge Functions.** Trois sur cinquante-deux ont été lues.
   ```bash
   grep -rn "Access-Control-Allow-Origin" supabase/functions/ | grep -v "'\*'" | grep -v '"\*"'
   ```
   Toute ligne renvoyée est une fonction à liste blanche explicite, donc à compléter.
2. **L'URL de l'API dans le frontend** : constante en dur ou variable d'environnement ?
   ```bash
   grep -rn "supabase\.co\|api\.anarbib" src/ | grep -v node_modules
   ```
3. **Les enregistrements CAA existants** sur `anarbib.org`, qui pourraient bloquer
   l'émission d'un certificat sur les nouveaux domaines s'ils sont recopiés tels quels.
4. **La possibilité, chez ISNIC et Registro.br, d'un titulaire personne morale étrangère**
   et les pièces demandées — leurs FAQ ne le disent pas.
5. **La durée d'enregistrement maximale** proposée par ISNIC au-delà d'un an.
