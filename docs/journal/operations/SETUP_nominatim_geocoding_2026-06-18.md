# Runbook — Nominatim self-hosted (géocodage carte, MAP-F)

**Date :** 2026-06-18
**Statut :** 🟡 travaux préliminaires — toolchain validée (smoke test), import réel à décider
**Auteur·ices :** AnarBib (session « Carte réseau 10 locales »)
**Réfs :** `spec-cartographie-reseau` §7 (MAP-F) ; REGISTRE §34 ; INV-5 (anti-tracking) ;
`scripts/nominatim/docker-compose.yml`. Voisin : `SETUP_runner_wsl2_2026-06-11.md`.

---

## 0. Objet

Géocodeur **OSM auto-hébergé** (Nominatim) pour transformer une adresse en lat/lon
lors de l'édition/auto-déclaration d'une fiche carto, **sans fuite vers un tiers**
(INV-5) : le front n'appelle jamais Nominatim directement — un **proxy Edge Function
côté serveur** s'interpose (à câbler, §5). Tant que ce service n'existe pas, le
**positionnement manuel par pin** (déjà livré, CARTO-6/7) reste la solution.

---

## 1. Hôte (WSL2 de Xavier, = runner CI) — relevé du 18/06

| Ressource | Valeur | Verdict |
|---|---|---|
| Docker | 29.5.3 (overlayfs) | ✅ |
| Disque | **950 Go libres** (/dev/sdf, 1 To) | ✅ large |
| RAM | **15 Go** | ⚠️ **bottleneck** des gros imports |
| CPU | 8 cœurs | ✅ |

> ⚠️ **Pas de VPS payant** (doctrine, cf. `ci-self-hosted-runner-plan`). Tout tourne
> sur cette machine ; ne pas saturer la RAM (le runner CI vit dessus).

## 2. Couverture à géocoder — 34 pays (relevé cartography_entries)

Le réseau est **mondial** mais **à dominante européenne** :
- **Europe (~130/184 fiches)** : Italie 49, France 17, Espagne 13, Allemagne 7, RU 6,
  Pays-Bas 4, Portugal 3, Grèce 3, Suisse 3, + BE/HR/HU/AT/CZ/PL/RO/RS/SI.
- **Amériques (~46)** : USA 13, Argentine 9, Brésil 8, Chili 7, Canada 6, Mexique 4,
  Uruguay 2, Colombie 2, Bolivie 2, Paraguay 1, Cuba 1.
- **Asie/Pacifique (~8)** : Nouvelle-Zélande 4, Australie 2, Japon 1, Népal 1, Israël/Palestine 1.

## 3. Dimensionnement des extraits OSM (Geofabrik, ordres de grandeur)

| Extrait | PBF | RAM conseillée import | Sur 15 Go ? |
|---|---|---|---|
| Petit pays (Andorre, Uruguay…) | < 0,1 Go | triviale | ✅ |
| Pays moyen (France, Allemagne, Italie) | 2–4 Go | ~8–12 Go | ✅ (un à la fois) |
| **Europe** | ~28 Go | ~32 Go+ recommandé | ⚠️ faisable avec **flatnode**, lent/risqué |
| Amérique du Nord | ~14 Go | ~24 Go+ | ⚠️ tendu |
| **Planet** (tout) | ~80 Go | **64 Go+** | ❌ pas sur 15 Go |

Disque : non bloquant (950 Go). **La RAM est le seul vrai plafond.**

## 4. Stratégie recommandée (phasée)

Le géocodage est **occasionnel** (à la saisie d'une fiche) et le corpus est petit
(184 fiches + soumissions ponctuelles). On n'a donc pas besoin d'un Nominatim
planétaire permanent. Proposition :

- **Phase 0 — smoke test (FAIT)** : import Andorre → valide Docker + Nominatim sur l'hôte
  (cf. §6).
- **Phase 1 (recommandée) — Europe** (`europe-latest.osm.pbf`, défaut du compose) :
  couvre la **majorité** des fiches ; import long mais une fois (FREEZE=true). Sur 15 Go,
  utiliser le **flatnode** (déjà dans le compose) ; surveiller la RAM. Repli pin manuel
  pour les fiches hors Europe.
- **Phase 2 (optionnelle) — Amériques** : ajouter un second Nominatim (ou ré-importer un
  PBF **fusionné** des pays couverts via `osmium merge`) si le géocodage hors-Europe
  devient nécessaire. Alternative légère : extraits **par pays couverts** fusionnés
  (≈ 40 Go PBF au total) plutôt que des continents entiers.
- **Toujours** : le **pin manuel** reste le filet (aucune fiche ne dépend du géocodage).

> Si un jour un géocodage **mondial** est requis : envisager un import planet sur une
> machine à RAM suffisante (emprunt ponctuel), pas un VPS payant permanent.

## 5. Mise en place

```bash
# Europe (défaut) — import long, en arrière-plan ; FREEZE=true (pas de MAJ incrémentale)
PBF_URL=https://download.geofabrik.de/europe-latest.osm.pbf \
NOMINATIM_PASSWORD=<motdepasse-local> \
  docker compose -f scripts/nominatim/docker-compose.yml up -d

docker logs -f anarbib-nominatim          # suivre l'import (peut durer des heures pour l'Europe)
# Test une fois "Import finished" :
curl 'http://127.0.0.1:8089/search?q=Belém,+Brasil&format=jsonv2&limit=1'
```

Port exposé **en local uniquement** (`127.0.0.1:8089`). Jamais public.

## 6. Smoke test (Phase 0) — Andorre

Conteneur `anarbib-nominatim-smoke` (port 8088), import `europe/andorra`. **✅ Concluant** :
image pull OK, Postgres OK, import OK, Apache sert, et géocodage réel validé —
`GET /search?q=Andorra+la+Vella` → `lat 42.49792, lon 1.50323` (display_name
« Andorra la Vella, AD500, Andorra »). La toolchain Nominatim self-hosted (import +
adresse→GPS) **fonctionne sur l'hôte**. Conteneur de test retiré après validation :
```bash
docker rm -f anarbib-nominatim-smoke
```

## 7. Câblage AnarBib (proxy + bouton LIVRÉS le 19/06, commit 45f7dfbc)

> ✅ Fait : (1) l'EF `supabase/functions/geocode` (proxy serveur, secret `NOMINATIM_URL`,
> rate-limit, anti-fuite) et (2) le bouton « Localiser depuis l'adresse » de la **modale
> d'édition** (repli pin manuel). Reste : le bouton dans le **formulaire public anonyme**
> (à garder avec Turnstile). Description d'origine ci-dessous.

1. **Proxy Edge Function `geocode`** : reçoit une adresse, interroge
   `http://<host>:8089/search` **côté serveur** (URL = secret vault `NOMINATIM_URL`),
   renvoie `{lat, lon, confiance}`. Rate-limité. **Jamais** appelé depuis le navigateur.
2. **Front** : bouton « localiser depuis l'adresse » dans la modale d'édition (CARTO-5)
   et le formulaire d'auto-déclaration (CARTO-7) → appelle le proxy, pré-remplit le pin
   (toujours ajustable). Repli silencieux sur le pin manuel si indisponible.
3. **Garde anti-tracking (INV-5)** : vérifier qu'aucune requête ne parte vers
   `nominatim.openstreetmap.org` ni un tiers.

## 8. Maintenance

- `FREEZE=true` ⇒ pas de mise à jour incrémentale : pour rafraîchir les données, **ré-importer**
  (acceptable vu l'usage occasionnel). Sinon, retirer FREEZE et brancher les replication updates.
- Le conteneur `restart: unless-stopped` redémarre avec la machine. Données dans les volumes
  `nominatim-data` / `nominatim-flatnode`.

## 9. Tunnel cloudflared (bridge temporaire) — montage & démontage

⚠️ L'Edge Function `geocode` tourne sur le **cloud Supabase** ; le Nominatim est en
**local** (conteneur sur la WSL2). Le cloud ne peut pas joindre `localhost` → on l'expose
via un **tunnel cloudflared** (quick tunnel, gratuit, sans compte), **le temps que le VPS
camarades prenne le relais** (cf. mémo migration Supabase→VPS).

### Monté le 19/06 (état actuel)
```bash
# cloudflared branché sur le réseau Docker de Nominatim, vise le conteneur (évite le loopback)
NET=$(docker network ls --format '{{.Name}}' | grep -i nominatim | head -1)
docker run -d --name anarbib-cloudflared --restart unless-stopped \
  --network "$NET" cloudflare/cloudflared:latest \
  tunnel --no-autoupdate --url http://anarbib-nominatim:8080
# récupérer l'URL https://<random>.trycloudflare.com :
docker logs anarbib-cloudflared 2>&1 | grep -oE 'https://[a-z0-9-]+\.trycloudflare\.com' | head -1
# la poser comme secret de l'Edge Function :
supabase secrets set NOMINATIM_URL=<url> --project-ref uflwmikiyjfnikiphtcp
```
⚠️ **URL éphémère** : un quick tunnel change d'URL à chaque redémarrage de cloudflared (ou
de la machine). Après un (re)démarrage, **un seul geste** rétablit le géocodage :
```bash
bash scripts/nominatim/refresh-tunnel-secret.sh
```
(le script recrée le tunnel au besoin, lit l'URL courante et repose le secret `NOMINATIM_URL`).
URL stable sans ce geste = named tunnel (compte Cloudflare + domaine) ; inutile pour un bridge
temporaire. L'URL n'est PAS committée (semi-secrète) : elle ne vit que dans les logs
cloudflared + le secret Supabase.

### DÉMONTAGE quand le VPS camarades prend le relais
Quand Nominatim tournera sur le VPS (co-localisé avec Supabase self-hosted, ou joignable en
réseau interne), le tunnel n'a plus lieu d'être :
```bash
# 1) Re-pointer le secret vers le Nominatim du VPS (URL interne/privée du VPS)
supabase secrets set NOMINATIM_URL=http://<nominatim-interne-VPS>:8080 --project-ref <ref>
#    Cas Supabase AUSSI self-hosted sur le VPS : l'EF joint Nominatim sur le même réseau
#    Docker → NOMINATIM_URL=http://nominatim:8080, plus de tunnel ni d'URL publique.
# 2) Arrêter et supprimer le tunnel
docker rm -f anarbib-cloudflared
# 3) (option) déplacer/arrêter le Nominatim local s'il migre sur le VPS
#    docker compose -f scripts/nominatim/docker-compose.yml down       # garde les volumes
#    docker compose -f scripts/nominatim/docker-compose.yml down -v    # supprime AUSSI les données
# 4) Vérifier : un géocodage depuis la modale d'édition doit toujours répondre.
```
**Aucun code applicatif ne change** au passage VPS : seule la valeur du secret
`NOMINATIM_URL` bascule (+ on retire le conteneur cloudflared).
