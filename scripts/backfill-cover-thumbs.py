#!/usr/bin/env python3
"""backfill-cover-thumbs.py — produit les vignettes des capas deja en place.

Pourquoi. La grille du catalogue n'appelle plus l'endpoint de transformation de
Supabase Storage (`/storage/v1/render/image/...`) : elle sert des derives
pre-generes, ranges a cote de leur original selon la convention portee par
`src/lib/coverThumbs.js`. Les depots faits DEPUIS ce changement produisent leur
derive dans le navigateur. Ce script rattrape le stock anterieur.

Ce qu'il fait, exactement : parcourt le bucket `covers`, et pour chaque image
qui n'est pas deja un derive, ecrit `<meme chemin sans extension>.thumb.jpg`
redimensionne dans une boite de 128x192 sans recadrage. Il n'ecrit QUE des
fichiers `.thumb.jpg`, et ne supprime rien sauf si on lui passe --purge-legacy.
Idempotent : relancable sans dommage, il saute ce qui existe deja (sauf --force).

Il traite TOUT le bucket, y compris les objets qu'aucune notice ne reference
(il y en avait 49 au 26/08/2026, pour 11 Mo). C'est volontaire : filtrer sur
`books.cover_object_path` obligerait ce script a parler a la base en plus du
stockage, pour economiser quelques centaines de ko de vignettes.

Formats : JPEG, PNG, WebP et GIF passent avec le Pillow de Debian. L'AVIF
demande un Pillow compile avec libavif (les roues PyPI recentes le sont) ; sans
lui, ces capas restent servies en original, ce que le catalogue sait faire.
Les echecs sont regroupes en fin de course.

Ce qu'il ne fait PAS : passer par l'endpoint de transformation. Redimensionner
les 244 capas par `render/image` couterait 244 images d'origine distinctes au
compteur mensuel, soit un paquet facture, pour un travail qui se fait ici en
local pour rien. C'est le piege a ne pas tomber dedans.

ACTION PROD (outward-facing) : a lancer DELIBEREMENT, jamais en automatique.

Auth : cle SERVICE_ROLE (le bucket exige `can_access_catalogacao` en INSERT ;
service_role contourne la RLS). Elle n'est PAS dans .env.local. Deux facons de
la fournir, la seconde etant preferable :

    SUPABASE_SERVICE_ROLE_KEY=eyJ... python3 scripts/backfill-cover-thumbs.py
    python3 scripts/backfill-cover-thumbs.py      # invite masquee, hors historique

VITE_SUPABASE_URL est lu depuis .env.local automatiquement.

Options :
    --dry-run   n'ecrit rien, dit ce qui serait fait
    --force     regenere meme si le derive existe deja
    --limit N   s'arrete apres N images (mise au point)
    --purge-legacy
                supprime les vignettes orphelines, c'est-a-dire tout objet
                `*.thumb.jpg` dont on ne retrouve pas l'original en retirant le
                suffixe. Sert a nettoyer celles produites par la premiere
                version de la convention, qui remplacait l'extension au lieu de
                suffixer le chemin complet (deux originaux de meme racine s'y
                ecrasaient). A combiner avec --dry-run pour voir la liste
                d'abord.

Dependance : Pillow (deja presente sous WSL ; `pip install Pillow` sinon).
"""

import argparse
import getpass
import io
import json
import os
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    sys.exit("X Pillow manquant. Installe-le : pip install Pillow")

BUCKET = "covers"
THUMB_SUFFIX = ".thumb.jpg"
THUMB_BOX = (128, 192)          # doit rester aligne sur THUMB_MAX_W/H de coverThumbs.js
THUMB_QUALITY = 72
ROOT = Path(__file__).resolve().parent.parent


# ── Configuration ────────────────────────────────────────────────────────

def read_env_local():
    """Lit .env.local sans dependance (meme role que scripts/lib/env-local.mjs)."""
    env = {}
    path = ROOT / ".env.local"
    if not path.exists():
        return env
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, value = line.partition("=")
        env[key.strip()] = value.strip().strip('"').strip("'")
    return env


def resolve_config():
    env_local = read_env_local()
    url = os.environ.get("VITE_SUPABASE_URL") or env_local.get("VITE_SUPABASE_URL")
    if not url:
        sys.exit("X VITE_SUPABASE_URL introuvable (ni environnement, ni .env.local).")

    key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY") or os.environ.get("SERVICE_ROLE_KEY")
    if not key:
        # Invite masquee : ce qui est saisi ici n'entre pas dans l'historique du
        # shell, contrairement a `VAR=... commande`.
        key = getpass.getpass("  Cle service_role (rien ne s'affichera) : ").strip()
    if not key:
        sys.exit("X Aucune cle fournie. Rien n'a ete lance.")
    if not (key.startswith("eyJ") or key.startswith("sb_secret_")):
        sys.exit("X Ca ne ressemble ni a un JWT (eyJ...) ni a une cle sb_secret_.")

    return url.rstrip("/"), key


# ── Acces Storage (urllib, pas de dependance HTTP) ───────────────────────

# Le parcours du bucket enchaine des centaines d'appels, et l'API Storage rend
# parfois un 504 sans raison durable. Sans reprise, un seul hoquet perd tout le
# travail au milieu — vecu le 26/08/2026 sur `list`. On ne reessaie que ce qui
# peut passer au coup suivant : 5xx, 429, et les coupures reseau. Un 4xx est de
# notre fait (chemin, droits), le repeter n'apporte rien.
TENTATIVES = 4
ATTENTES = (2, 5, 12)


def call(url, key, method="GET", json_body=None, raw_body=None, headers=None):
    payload = None
    hdrs = {"apikey": key, "Authorization": f"Bearer {key}"}
    if json_body is not None:
        payload = json.dumps(json_body).encode("utf-8")
        hdrs["Content-Type"] = "application/json"
    elif raw_body is not None:
        payload = raw_body
    if headers:
        hdrs.update(headers)

    derniere = None
    for essai in range(TENTATIVES):
        try:
            req = urllib.request.Request(url, data=payload, headers=hdrs, method=method)
            with urllib.request.urlopen(req, timeout=120) as res:
                return res.read()
        except urllib.error.HTTPError as err:
            if err.code < 500 and err.code != 429:
                raise
            derniere = err
        except (urllib.error.URLError, TimeoutError, OSError) as err:
            derniere = err
        if essai < TENTATIVES - 1:
            attente = ATTENTES[essai]
            print(f"    … {derniere} — nouvel essai dans {attente} s", flush=True)
            time.sleep(attente)
    raise derniere


def list_folder(base, key, prefix):
    """Un niveau du bucket. L'API Storage ne liste pas recursivement."""
    entries, offset = [], 0
    while True:
        body = {"prefix": prefix, "limit": 100, "offset": offset,
                "sortBy": {"column": "name", "order": "asc"}}
        page = json.loads(call(f"{base}/storage/v1/object/list/{BUCKET}", key,
                               method="POST", json_body=body))
        entries.extend(page)
        if len(page) < 100:
            return entries
        offset += 100


def walk(base, key, prefix=""):
    """Chemins de fichiers du bucket. Un dossier a `id` a None."""
    for entry in list_folder(base, key, prefix):
        name = entry.get("name")
        if not name:
            continue
        path = f"{prefix}/{name}" if prefix else name
        if entry.get("id") is None:
            yield from walk(base, key, path)
        else:
            yield path


def thumb_path_for(cover_path):
    """Doit rester identique a thumbPathFor() de src/lib/coverThumbs.js.

    Le chemin COMPLET est suffixe, pas sa racine : `front.jpg` et `front.png`
    coexistent dans ce bucket et doivent donner deux vignettes distinctes.
    Les deux versions sont couvertes par les memes cas dans
    src/tests/coverThumbs.test.js — s'il faut toucher a l'une, toucher a l'autre.
    """
    if cover_path.endswith(THUMB_SUFFIX):
        return cover_path
    return cover_path + THUMB_SUFFIX


def make_thumb(raw):
    img = Image.open(io.BytesIO(raw))
    # GIF anime : on garde la premiere image. EXIF : Pillow ne la recopie pas
    # dans notre sortie, ce qui purge au passage d'eventuelles coordonnees.
    if getattr(img, "is_animated", False):
        img.seek(0)
    if img.mode not in ("RGB", "L"):
        # Aplat blanc : le JPEG n'a pas de couche alpha, et un PNG transparent
        # virerait au noir. Meme choix que le canvas cote navigateur.
        fond = Image.new("RGB", img.size, (255, 255, 255))
        img = img.convert("RGBA")
        fond.paste(img, mask=img.split()[-1])
        img = fond
    else:
        img = img.convert("RGB")
    img.thumbnail(THUMB_BOX, Image.LANCZOS)
    out = io.BytesIO()
    img.save(out, format="JPEG", quality=THUMB_QUALITY, optimize=True, progressive=True)
    return out.getvalue()


# ── Programme ────────────────────────────────────────────────────────────

def main():
    ap = argparse.ArgumentParser(description="Genere les vignettes des capas existantes.")
    ap.add_argument("--dry-run", action="store_true", help="n'ecrit rien")
    ap.add_argument("--force", action="store_true", help="regenere meme si le derive existe")
    ap.add_argument("--limit", type=int, default=0, help="s'arreter apres N images")
    ap.add_argument("--purge-legacy", action="store_true",
                    help="supprime les vignettes dont l'original est introuvable")
    args = ap.parse_args()

    base, key = resolve_config()
    print(f"\n  Projet  : {base}")
    print(f"  Bucket  : {BUCKET}")
    print(f"  Boite   : {THUMB_BOX[0]}x{THUMB_BOX[1]}, JPEG q{THUMB_QUALITY}")
    if args.dry_run:
        print("  Mode    : essai a blanc, aucune ecriture")
    print()

    tous = list(walk(base, key))
    existants = {p for p in tous if p.endswith(THUMB_SUFFIX)}
    sources = [p for p in tous if not p.endswith(THUMB_SUFFIX)]
    print(f"  {len(sources)} image(s) d'origine, {len(existants)} vignette(s) deja presente(s).\n")

    faits = sautes = 0
    echecs = []
    octets_avant = octets_apres = 0

    for i, path in enumerate(sources):
        if args.limit and faits >= args.limit:
            print(f"  (--limit {args.limit} atteint)")
            break
        cible = thumb_path_for(path)
        if cible in existants and not args.force:
            sautes += 1
            continue
        try:
            raw = call(f"{base}/storage/v1/object/{BUCKET}/{path}", key)
            vignette = make_thumb(raw)
            octets_avant += len(raw)
            octets_apres += len(vignette)
            if not args.dry_run:
                call(f"{base}/storage/v1/object/{BUCKET}/{cible}", key, method="POST",
                     raw_body=vignette,
                     headers={"Content-Type": "image/jpeg", "x-upsert": "true"})
            faits += 1
            print(f"  [{i + 1}/{len(sources)}] {path}  {len(raw) // 1024} ko -> {len(vignette) // 1024} ko")
        except (urllib.error.URLError, urllib.error.HTTPError, OSError, ValueError) as err:
            echecs.append((path, str(err)))
            print(f"  ! {path} : {err}")

    print(f"\n  Vignettes ecrites : {faits}")
    print(f"  Deja presentes    : {sautes}")
    print(f"  Echecs            : {len(echecs)}")
    if faits:
        print(f"  Poids  : {octets_avant // 1024} ko d'originaux -> {octets_apres // 1024} ko de vignettes")

    if args.purge_legacy:
        # Une vignette est valide si, suffixe retire, on retrouve son original.
        # Celles de l'ancienne convention ne le sont pas : leur nom derivait de
        # la racine, donc `front.thumb.jpg` renvoie a `front`, qui n'existe pas.
        connus = set(sources)
        orphelines = [p for p in existants if p[:-len(THUMB_SUFFIX)] not in connus]
        print(f"\n  Vignettes orphelines : {len(orphelines)}")
        supprimees = 0
        for p in orphelines:
            if args.dry_run:
                print(f"    (a supprimer) {p}")
                continue
            try:
                call(f"{base}/storage/v1/object/{BUCKET}/{p}", key, method="DELETE")
                supprimees += 1
            except (urllib.error.URLError, urllib.error.HTTPError, OSError) as err:
                print(f"    ! {p} : {err}")
        if not args.dry_run:
            print(f"  Supprimees : {supprimees}")

    if echecs:
        # Regroupe en fin de course : au milieu de 300 lignes, un echec passe
        # inapercu. Une capa sans derive n'est PAS une panne — la grille retombe
        # sur l'original (onError de CatalogPage) — mais elle sert alors le
        # fichier plein, ce qui merite d'etre su.
        print("\n  Capas restees sans vignette :")
        for path, err in echecs:
            print(f"    - {path}\n        {err}")
        if any("AVIF" in e or "avif" in p.lower() for p, e in echecs):
            print("\n  L'AVIF demande un Pillow compile avec libavif : celui de Debian")
            print("  ne l'est pas, les roues PyPI recentes le sont. Sans lui, ces")
            print("  capas-la restent servies en original — quelques dizaines de ko,")
            print("  et tout navigateur depuis 2021 les affiche.")
    print()
    return 1 if echecs else 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        # Interrompre est sans danger : le script n'ecrit que des .thumb.jpg,
        # un par un, et se relance sans refaire ce qui existe.
        print("\n  Interrompu. Relancer la meme commande reprend ou ca s'est arrete.\n")
        sys.exit(130)
    except urllib.error.HTTPError as err:
        print(f"\nX L'API Storage a rendu HTTP {err.code} ({err.reason}) malgre "
              f"{TENTATIVES} tentatives.")
        if err.code >= 500:
            print("  C'est un incident cote serveur, pas une erreur de la commande.")
            print("  Rien n'a ete casse : relancer plus tard reprend le travail.\n")
        elif err.code in (401, 403):
            print("  Cle refusee : verifier qu'il s'agit bien de la cle service_role.\n")
        else:
            print()
        sys.exit(1)
    except urllib.error.URLError as err:
        print(f"\nX Reseau injoignable : {err.reason}")
        print("  Rien n'a ete casse : relancer reprend le travail.\n")
        sys.exit(1)
