#!/usr/bin/env python3
"""strip-cover-metadata.py — retire les metadonnees embarquees des capas.

Auteur  : AnarBib
Session : Metadonnees des capas

Pourquoi. Une image deposee comme capa peut porter, en plus de ses pixels,
des informations sur la personne ou l'appareil qui l'a produite : EXIF (modele
d'appareil, date, parfois coordonnees GPS), XMP, IPTC, commentaires, blocs
C2PA, images secondaires (MPF d'un telephone), texte PNG. Le bucket `covers`
est PUBLIC : tout cela est lisible par n'importe qui. Une capa n'a besoin que
de ses pixels.

Ce qu'il fait, exactement : parcourt le bucket `covers` (originaux ET
vignettes `*.thumb.jpg`), lit chaque fichier, et retire SANS RECOMPRESSION les
segments de metadonnees. Les pixels ne sont pas touches : le fichier nettoye
est decode et compare pixel a pixel a l'original avant tout envoi ; s'ils
different, l'objet est laisse tel quel et signale.

Ce qui est garde, parce que ca change le rendu et ne dit rien de personne :
  - le profil couleur ICC (JPEG APP2 ICC_PROFILE, PNG iCCP, WebP ICCP) ;
  - le segment Adobe APP14 du JPEG (transformation de couleur) ;
  - l'en-tete JFIF (sans sa miniature eventuelle) ;
  - les blocs de rendu PNG (gAMA, cHRM, sRGB, pHYs, tRNS…) et l'animation
    (APNG, WebP ANIM/ANMF, boucle GIF NETSCAPE2.0) ;
  - l'ORIENTATION EXIF quand elle n'est pas 1 : un JPEG de telephone pose de
    travers s'afficherait couche sans elle. Elle est reecrite seule dans un
    EXIF minimal (un unique champ, rien d'autre).

Les objets sont remplaces A LA MEME ADRESSE (upsert). La regle CAPAS « une capa
neuve a une adresse neuve » (src/lib/coverThumbs.js) vise un CHANGEMENT
d'image, que le cache d'une heure masquerait ; ici l'image affichee est
identique, le cache peut resservir l'ancienne version sans consequence, et
aucune des notices qui designent ces chemins n'a a bouger.

SAUVEGARDE. Avant toute ecriture, l'original est copie dans --backup-dir
(par defaut ~/anarbib-backups/covers-metadata-<horodatage>/), a son chemin
d'origine, avec un manifeste JSON (constats, sha256 avant/apres). Restaurer =
renvoyer ces fichiers au meme chemin.

ACTION PROD (outward-facing) : a lancer DELIBEREMENT. Toujours --dry-run d'abord.

Auth :
  --dry-run  n'a besoin d'AUCUNE cle : le bucket est public, la liste vient de
             --paths-file (un chemin par ligne) ou, a defaut, de l'API avec la
             cle publishable de .env.local.
  sinon      cle SERVICE_ROLE (le bucket exige `can_access_catalogacao` en
             ecriture). Elle n'est pas sur le poste : invite masquee, ou
             SUPABASE_SERVICE_ROLE_KEY dans l'environnement.

Usage :
    python3 scripts/strip-cover-metadata.py --dry-run
    python3 scripts/strip-cover-metadata.py

Options :
    --dry-run           n'ecrit rien dans le bucket (la sauvegarde locale et le
                        manifeste sont quand meme produits)
    --paths-file F      liste des chemins a traiter au lieu de parcourir le bucket
    --backup-dir D      dossier de sauvegarde
    --limit N           s'arrete apres N objets (mise au point)
    --workers N         telechargements paralleles (defaut 6)
    --bucket B          autre bucket public d'images (ex. `authors`, photos
                        d'auteurs — passe du 14/10/2026)

Dependance : Pillow (pour la verification pixel a pixel et l'orientation).
"""

import argparse
import concurrent.futures
import getpass
import hashlib
import io
import json
import os
import struct
import sys
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    sys.exit("X Pillow manquant. Installe-le : pip install Pillow")

BUCKET = "covers"
ROOT = Path(__file__).resolve().parent.parent
ORIENTATION = 0x0112


# ── Configuration ────────────────────────────────────────────────────────

def read_env_local():
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


def resolve_config(dry_run):
    env_local = read_env_local()
    url = os.environ.get("VITE_SUPABASE_URL") or env_local.get("VITE_SUPABASE_URL")
    if not url:
        sys.exit("X VITE_SUPABASE_URL introuvable (ni environnement, ni .env.local).")
    if dry_run:
        return url.rstrip("/"), None, env_local.get("VITE_SUPABASE_PUBLISHABLE_KEY")

    key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY") or os.environ.get("SERVICE_ROLE_KEY")
    if not key:
        key = getpass.getpass("  Cle service_role (rien ne s'affichera) : ")
    # Un collage dans le terminal peut apporter les balises de « bracketed
    # paste » (ESC[200~ … ESC[201~) ou des blancs : on ne garde que le visible.
    key = key.replace("\x1b[200~", "").replace("\x1b[201~", "")
    key = "".join(ch for ch in key if ch.isprintable() and not ch.isspace())
    if not key:
        sys.exit("X Aucune cle fournie. Rien n'a ete lance.")
    if not (key.startswith("eyJ") or key.startswith("sb_secret_")):
        sys.exit("X Ca ne ressemble ni a un JWT (eyJ...) ni a une cle sb_secret_.")
    return url.rstrip("/"), key, key


# ── Acces Storage (meme reprise que backfill-cover-thumbs.py) ─────────────

TENTATIVES = 4
ATTENTES = (2, 5, 12)


def call(url, key=None, method="GET", json_body=None, raw_body=None, headers=None):
    payload = None
    hdrs = {}
    if key:
        hdrs.update({"apikey": key, "Authorization": f"Bearer {key}"})
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
            time.sleep(ATTENTES[essai])
    raise derniere


def list_folder(base, key, prefix):
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
    """(chemin, metadata) de chaque fichier du bucket."""
    for entry in list_folder(base, key, prefix):
        name = entry.get("name")
        if not name:
            continue
        path = f"{prefix}/{name}" if prefix else name
        if entry.get("id") is None:
            yield from walk(base, key, path)
        else:
            yield path, entry.get("metadata") or {}


def q(path):
    return urllib.parse.quote(path, safe="/")


# ── JPEG ─────────────────────────────────────────────────────────────────

def _jpeg_label(marker, seg):
    if marker == 0xFE:
        return "commentaire JPEG"
    n = marker - 0xE0
    if n == 1 and seg.startswith(b"Exif\0"):
        return "EXIF"
    if n == 1 and (seg.startswith(b"http://ns.adobe.com/xap/1.0/") or
                   seg.startswith(b"http://ns.adobe.com/xmp/extension/")):
        return "XMP"
    if n == 2 and seg.startswith(b"MPF\0"):
        return "MPF (images secondaires)"
    if n == 2 and seg.startswith(b"FPXR"):
        return "FlashPix"
    if n == 13:
        return "IPTC/Photoshop"
    if n == 11:
        return "JUMBF/C2PA"
    if n == 0 and seg.startswith(b"JFXX"):
        return "miniature JFXX"
    return f"APP{n}"


def _minimal_orientation_app1(orientation):
    exif = Image.Exif()
    exif[ORIENTATION] = orientation
    payload = exif.tobytes()
    if not payload.startswith(b"Exif\0\0"):
        payload = b"Exif\0\0" + payload
    return b"\xff\xe1" + struct.pack(">H", len(payload) + 2) + payload


def strip_jpeg(raw, orientation):
    if raw[:2] != b"\xff\xd8":
        raise ValueError("JPEG sans SOI")
    head, body, found = [], bytearray(), []
    seen_sos = False
    i, n = 2, len(raw)
    trailing = b""
    while i < n:
        if raw[i] != 0xFF:
            raise ValueError(f"marqueur attendu a l'octet {i}")
        while i < n and raw[i] == 0xFF:
            i += 1
        if i >= n:
            break
        marker = raw[i]
        i += 1
        if marker == 0xD9:
            body += b"\xff\xd9"
            trailing = raw[i:]
            break
        if 0xD0 <= marker <= 0xD7 or marker == 0x01:
            body += bytes([0xFF, marker])
            continue
        seglen = struct.unpack(">H", raw[i:i + 2])[0]
        seg = raw[i + 2:i + seglen]
        full = bytes([0xFF, marker]) + raw[i:i + seglen]
        i += seglen

        if marker == 0xDA:
            seen_sos = True
            body += full
            j = i
            while True:
                j = raw.find(b"\xff", j)
                if j < 0 or j + 1 >= n:
                    body += raw[i:]
                    i = n
                    break
                nxt = raw[j + 1]
                if nxt == 0x00 or 0xD0 <= nxt <= 0xD7 or nxt == 0xFF:
                    j += 1 if nxt == 0xFF else 2
                    continue
                body += raw[i:j]
                i = j
                break
            continue

        is_app = 0xE0 <= marker <= 0xEF
        if not (is_app or marker == 0xFE):
            if seen_sos:
                body += full
            else:
                head.append(full)
            continue

        if marker == 0xE0 and seg.startswith(b"JFIF\0") and len(seg) >= 14:
            if seg[12] or seg[13]:
                found.append("miniature JFIF")
                seg = seg[:12] + b"\0\0"
                full = b"\xff\xe0" + struct.pack(">H", len(seg) + 2) + seg
            head.append(full)
        elif marker == 0xE2 and seg.startswith(b"ICC_PROFILE\0"):
            head.append(full)
        elif marker == 0xEE and seg.startswith(b"Adobe"):
            head.append(full)
        else:
            found.append(_jpeg_label(marker, seg))

    if trailing.strip(b"\0"):
        found.append(f"donnees apres la fin d'image ({len(trailing)} o)")

    if not found:
        return raw, []
    if orientation and orientation != 1:
        # Apres APP0/JFIF s'il est en tete, sinon tout de suite apres SOI.
        pos = 1 if head and head[0][:2] == b"\xff\xe0" else 0
        head.insert(pos, _minimal_orientation_app1(orientation))
    out = b"\xff\xd8" + b"".join(bytes(h) for h in head) + bytes(body)
    return out, found


# ── PNG ──────────────────────────────────────────────────────────────────

PNG_SIG = b"\x89PNG\r\n\x1a\n"
PNG_KEEP = {b"IHDR", b"PLTE", b"IDAT", b"IEND", b"tRNS", b"gAMA", b"cHRM",
            b"sRGB", b"iCCP", b"sBIT", b"bKGD", b"pHYs", b"hIST", b"acTL",
            b"fcTL", b"fdAT", b"cICP", b"mDCV", b"cLLI"}


def strip_png(raw):
    if not raw.startswith(PNG_SIG):
        raise ValueError("PNG sans signature")
    out, found, i = [PNG_SIG], [], 8
    while i < len(raw):
        length = struct.unpack(">I", raw[i:i + 4])[0]
        ctype = raw[i + 4:i + 8]
        chunk = raw[i:i + 12 + length]
        data = raw[i + 8:i + 8 + length]
        i += 12 + length
        if ctype in PNG_KEEP:
            out.append(chunk)
        else:
            label = ctype.decode("latin-1")
            if ctype in (b"tEXt", b"zTXt", b"iTXt"):
                kw = data.split(b"\0", 1)[0].decode("latin-1", "replace")
                label = "XMP" if "xmp" in kw.lower() else f"texte PNG « {kw} »"
            elif ctype == b"eXIf":
                label = "EXIF"
            elif ctype == b"tIME":
                label = "date PNG (tIME)"
            elif ctype == b"caBX":
                label = "JUMBF/C2PA"
            found.append(label)
        if ctype == b"IEND":
            if raw[i:].strip(b"\0"):
                found.append(f"donnees apres la fin d'image ({len(raw) - i} o)")
            break
    return (b"".join(out), found) if found else (raw, [])


# ── WebP ─────────────────────────────────────────────────────────────────

WEBP_KEEP = {b"VP8 ", b"VP8L", b"VP8X", b"ALPH", b"ANIM", b"ANMF", b"ICCP"}


def strip_webp(raw):
    if raw[:4] != b"RIFF" or raw[8:12] != b"WEBP":
        raise ValueError("WebP sans en-tete RIFF/WEBP")
    end = min(len(raw), 8 + struct.unpack("<I", raw[4:8])[0])
    chunks, found, i = [], [], 12
    while i + 8 <= end:
        fourcc = raw[i:i + 4]
        size = struct.unpack("<I", raw[i + 4:i + 8])[0]
        total = 8 + size + (size & 1)
        chunk = bytearray(raw[i:i + total])
        i += total
        if fourcc in WEBP_KEEP:
            chunks.append(chunk)
        else:
            found.append({b"EXIF": "EXIF", b"XMP ": "XMP"}.get(fourcc, fourcc.decode("latin-1")))
    if len(raw) > end and raw[end:].strip(b"\0"):
        found.append(f"donnees apres la fin d'image ({len(raw) - end} o)")
    if not found:
        return raw, []
    for c in chunks:
        if c[:4] == b"VP8X":
            c[8] &= ~(0x08 | 0x04) & 0xFF   # drapeaux EXIF et XMP
    body = b"WEBP" + b"".join(bytes(c) for c in chunks)
    return b"RIFF" + struct.pack("<I", len(body)) + body, found


# ── GIF ──────────────────────────────────────────────────────────────────

def _gif_subblocks(raw, i):
    start = i
    while True:
        size = raw[i]
        i += 1 + size
        if size == 0:
            return raw[start:i], i


def strip_gif(raw):
    if raw[:3] != b"GIF":
        raise ValueError("GIF sans en-tete")
    flags = raw[10]
    i = 13 + (3 * (2 << (flags & 7)) if flags & 0x80 else 0)
    out, found = [raw[:i]], []
    while i < len(raw):
        b = raw[i]
        if b == 0x3B:
            out.append(b"\x3b")
            if raw[i + 1:].strip(b"\0"):
                found.append(f"donnees apres la fin d'image ({len(raw) - i - 1} o)")
            break
        if b == 0x21:
            label = raw[i + 1]
            blocks, j = _gif_subblocks(raw, i + 2)
            whole = raw[i:j]
            if label == 0xFE:
                found.append("commentaire GIF")
            elif label == 0xFF:
                app = blocks[1:12]
                if app in (b"NETSCAPE2.0", b"ANIMEXTS1.0", b"ICCRGBG1012"):
                    out.append(whole)
                else:
                    found.append("XMP" if app.startswith(b"XMP Data") else
                                 f"extension GIF {app.decode('latin-1', 'replace')}")
            else:
                out.append(whole)
            i = j
        elif b == 0x2C:
            lflags = raw[i + 9]
            j = i + 10 + (3 * (2 << (lflags & 7)) if lflags & 0x80 else 0)
            _, j = _gif_subblocks(raw, j + 1)
            out.append(raw[i:j])
            i = j
        else:
            raise ValueError(f"bloc GIF inattendu 0x{b:02x} a l'octet {i}")
    return (b"".join(out), found) if found else (raw, [])


# ── AVIF / HEIF (ISOBMFF) ────────────────────────────────────────────────
#
# Les metadonnees y sont des ITEMS (`Exif`, `mime` pour XMP) declares dans
# meta/iinf et localises par meta/iloc. Les retirer sans recompresser oblige a
# reecrire les decalages d'iloc : on ne le fait pas a l'aveugle. Le script les
# DETECTE et les signale a la main ; un AVIF sans tel item est propre.

def _isobmff_boxes(b, i, end):
    while i + 8 <= end:
        size, typ = struct.unpack(">I4s", b[i:i + 8])
        hdr = 8
        if size == 1:
            size = struct.unpack(">Q", b[i + 8:i + 16])[0]
            hdr = 16
        elif size == 0:
            size = end - i
        if size < hdr:
            raise ValueError(f"boite ISOBMFF invalide a l'octet {i}")
        yield typ, i + hdr, i + size
        i += size


def isobmff_items(raw):
    """Types d'items declares (b'av01', b'Exif', b'mime'…)."""
    types = []
    for typ, c, e in _isobmff_boxes(raw, 0, len(raw)):
        if typ != b"meta":
            continue
        for t2, c2, e2 in _isobmff_boxes(raw, c + 4, e):
            if t2 != b"iinf":
                continue
            off = c2 + 4 + (2 if raw[c2] == 0 else 4)
            for t3, c3, _ in _isobmff_boxes(raw, off, e2):
                if t3 == b"infe" and raw[c3] >= 2:
                    id_len = 2 if raw[c3] == 2 else 4
                    types.append(raw[c3 + 4 + id_len + 2:c3 + 4 + id_len + 6])
    return types


# ── Analyse d'un objet ───────────────────────────────────────────────────

def pixels(data):
    img = Image.open(io.BytesIO(data))
    frames = getattr(img, "n_frames", 1)
    img.seek(0)
    img.load()
    return img.format, img.size, img.mode, frames, img.tobytes()


def analyse(raw):
    """-> (format, constats, octets nettoyes ou None, remarque)."""
    if raw[4:8] == b"ftyp":
        fmt = raw[8:12].decode("latin-1").strip().upper()
        meta = [t for t in isobmff_items(raw) if t in (b"Exif", b"mime")]
        if not meta:
            return fmt, [], None, None
        found = ["EXIF" if t == b"Exif" else "XMP" for t in meta]
        return fmt, found, None, "metadonnees dans un AVIF/HEIF : a nettoyer a la main"

    img = Image.open(io.BytesIO(raw))
    fmt = img.format
    orientation = None
    try:
        orientation = img.getexif().get(ORIENTATION)
    except Exception:
        pass

    if fmt == "JPEG":
        clean, found = strip_jpeg(raw, orientation)
    elif fmt == "PNG":
        clean, found = strip_png(raw)
    elif fmt == "WEBP":
        clean, found = strip_webp(raw)
    elif fmt == "GIF":
        clean, found = strip_gif(raw)
    else:
        return fmt, [], None, f"format {fmt} non traite"

    if not found:
        return fmt, [], None, None
    if fmt != "JPEG" and orientation and orientation != 1:
        return fmt, found, None, f"orientation EXIF {orientation} hors JPEG : a revoir a la main"
    if pixels(raw) != pixels(clean):
        return fmt, found, None, "pixels differents apres nettoyage : laisse tel quel"
    if orientation and orientation != 1:
        found = found + [f"(orientation {orientation} conservee)"]
    return fmt, found, clean, None


# ── Programme ────────────────────────────────────────────────────────────

def main():
    global BUCKET
    ap = argparse.ArgumentParser(description="Retire les metadonnees embarquees des capas.")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--paths-file")
    ap.add_argument("--backup-dir")
    ap.add_argument("--limit", type=int, default=0)
    ap.add_argument("--workers", type=int, default=6)
    ap.add_argument("--bucket", default=BUCKET,
                    help="bucket a traiter (defaut covers ; `authors` pour les photos d'auteurs)")
    args = ap.parse_args()
    BUCKET = args.bucket

    base, write_key, list_key = resolve_config(args.dry_run)
    stamp = datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S")
    backup = Path(args.backup_dir or Path.home() / "anarbib-backups" / f"{BUCKET}-metadata-{stamp}")
    backup.mkdir(parents=True, exist_ok=True)

    print(f"\n  Projet     : {base}")
    print(f"  Bucket     : {BUCKET}")
    print(f"  Sauvegarde : {backup}")
    if args.dry_run:
        print("  Mode       : essai a blanc, rien n'est ecrit dans le bucket")
    print()

    if args.paths_file:
        objets = [(p.strip(), {}) for p in Path(args.paths_file).read_text("utf-8").splitlines() if p.strip()]
    else:
        objets = list(walk(base, list_key))
    if args.limit:
        objets = objets[:args.limit]
    print(f"  {len(objets)} objet(s) a examiner.\n")
    if not objets:
        sys.exit("X Liste vide (en --dry-run sans cle, passer --paths-file).")

    verrou = threading.Lock()
    manifeste = []

    def traiter(item):
        path, meta = item
        url = (f"{base}/storage/v1/object/{BUCKET}/{q(path)}" if write_key
               else f"{base}/storage/v1/object/public/{BUCKET}/{q(path)}")
        raw = call(url, write_key)
        dest = backup / "originaux" / path
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_bytes(raw)
        fmt, found, clean, remarque = analyse(raw)
        rec = {"path": path, "format": fmt, "constats": found, "remarque": remarque,
               "octets_avant": len(raw), "sha256_avant": hashlib.sha256(raw).hexdigest()}
        if clean is not None:
            rec.update(octets_apres=len(clean), sha256_apres=hashlib.sha256(clean).hexdigest())
            if not args.dry_run:
                ctype = meta.get("mimetype") or Image.MIME.get(fmt, "application/octet-stream")
                hdrs = {"Content-Type": ctype, "x-upsert": "true"}
                if meta.get("cacheControl"):
                    hdrs["cache-control"] = meta["cacheControl"]
                call(f"{base}/storage/v1/object/{BUCKET}/{q(path)}", write_key,
                     method="PUT", raw_body=clean, headers=hdrs)
                rec["nettoye"] = True
        return rec

    with concurrent.futures.ThreadPoolExecutor(max_workers=args.workers) as pool:
        futs = {pool.submit(traiter, it): it[0] for it in objets}
        for k, fut in enumerate(concurrent.futures.as_completed(futs), 1):
            path = futs[fut]
            try:
                rec = fut.result()
            except Exception as err:  # noqa: BLE001 — regroupe en fin de course
                rec = {"path": path, "erreur": f"{type(err).__name__}: {err}"}
            with verrou:
                manifeste.append(rec)
                if rec.get("constats") or rec.get("erreur") or rec.get("remarque"):
                    etat = ("ERREUR " + rec["erreur"]) if rec.get("erreur") else \
                           ", ".join(rec["constats"]) + (f"  [{rec['remarque']}]" if rec.get("remarque") else "")
                    print(f"  [{k}/{len(objets)}] {path}\n      {etat}")

    manifeste.sort(key=lambda r: r["path"])
    (backup / "manifeste.json").write_text(json.dumps(manifeste, ensure_ascii=False, indent=1), "utf-8")

    avec = [r for r in manifeste if r.get("constats")]
    nettoyables = [r for r in avec if "sha256_apres" in r]
    erreurs = [r for r in manifeste if r.get("erreur")]
    remarques = [r for r in manifeste if r.get("remarque")]
    compte = {}
    for r in avec:
        for c in set(r["constats"]):
            compte[c] = compte.get(c, 0) + 1

    print(f"\n  Examines                 : {len(manifeste)}")
    print(f"  Sans metadonnees         : {len(manifeste) - len(avec) - len(erreurs)}")
    print(f"  Avec metadonnees         : {len(avec)}")
    if args.dry_run:
        print(f"  Nettoyables              : {len(nettoyables)}")
    else:
        print(f"  Nettoyes                 : {sum(1 for r in avec if r.get('nettoye'))}")
    print(f"  A revoir / laisses       : {len(remarques)}")
    print(f"  Erreurs                  : {len(erreurs)}")
    if compte:
        print("\n  Ce qui a ete trouve (nombre de fichiers) :")
        for c, nb in sorted(compte.items(), key=lambda kv: -kv[1]):
            print(f"    {nb:4d}  {c}")
    gain = sum(r["octets_avant"] - r["octets_apres"] for r in nettoyables)
    if gain:
        print(f"\n  Poids retire : {gain // 1024} ko")
    print(f"\n  Manifeste : {backup / 'manifeste.json'}\n")
    return 1 if erreurs else 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        print("\n  Interrompu. Les objets deja envoyes sont propres ; relancer reprend "
              "(un objet propre est simplement saute).\n")
        sys.exit(130)
    except urllib.error.HTTPError as err:
        try:
            detail = err.read().decode("utf-8", "replace")[:300]
        except Exception:
            detail = ""
        print(f"\nX L'API Storage a rendu HTTP {err.code} ({err.reason}). {detail}")
        if err.code in (401, 403) or "JWS" in detail or "signature" in detail.lower():
            print("  Cle refusee : verifier qu'il s'agit bien de la cle service_role de CE projet,")
            print("  copiee en entier (Dashboard > Project Settings > API Keys).")
            print("  Rien n'a ete ecrit dans le bucket.\n")
        sys.exit(1)
