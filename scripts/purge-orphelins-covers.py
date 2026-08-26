#!/usr/bin/env python3
"""purge-orphelins-covers.py — retire du bucket `covers` les objets que plus
rien ne reference, en epargnant les couvertures perdues.

CE QU'IL FAIT, ET SURTOUT CE QU'IL REFUSE DE FAIRE.

Un objet de `covers` est ORPHELIN quand aucun `cover_object_path` ne le designe,
dans aucune des trois tables qui portent ce champ : books, book_drafts,
import_blmf_books_rows. Mais tous les orphelins ne sont pas des dechets. Le
script les classe en trois, et n'en supprime que deux :

  A  aucune notice ni brouillon ne porte la reference du dossier
     -> debris. Supprime.
  B  la notice existe et porte DEJA une autre couverture
     -> version remplacee. Supprime.
  C  une notice OU un brouillon porte cette reference et n'a AUCUNE couverture,
     alors qu'un fichier l'attend au bon emplacement
     -> depot de catalogage qui n'a pas abouti : le fichier est monte, le
        chemin n'a jamais ete enregistre sur la notice. CONSERVE.
        Les supprimer detruirait un travail de catalogage. Il y en avait trois
        au 26/08/2026 (MLEG-0266, 0000262, 0000181).

Le classement est RECALCULE a chaque execution, jamais lu dans une liste figee :
si une notice a ete illustree ou videe depuis la derniere analyse, le script en
tient compte. C'est le point important — une liste de suppression vieillit mal.

Les vignettes (`*.thumb.jpg`) suivent le sort de leur original : elles n'ont
d'existence que par lui. Convention identique a src/lib/coverThumbs.js.

REVERSIBILITE. Les objets supprimes sont dans le flux restic `storage`
(retention 7 quotidiens / 4 hebdomadaires / 6 mensuels). Verifier qu'un
instantane RECENT existe avant de lancer :
    RESTIC_REPOSITORY=sftp:anarbib@bricolage.herbesfolles.org:/data/anarbib-storage \\
    restic snapshots --latest 1

ACTION PROD (outward-facing) : a lancer DELIBEREMENT. Toujours --dry-run d'abord.

Auth : cle SERVICE_ROLE du projet cloud. Elle n'est nulle part sur le poste —
la fournir a l'execution. Invite masquee par defaut (hors historique du shell).

Usage :
    python3 purge-orphelins-covers.py --dry-run
    python3 purge-orphelins-covers.py
"""

import argparse
import getpass
import json
import os
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

BUCKET = "covers"
THUMB_SUFFIX = ".thumb.jpg"
ROOT = Path(__file__).resolve().parent
PLAFOND = 300  # garde-fou : au-dela, on refuse et on demande une verification humaine


# ── Configuration ────────────────────────────────────────────────────────

def read_env_local():
    env = {}
    for candidat in (ROOT / ".env.local", ROOT.parent / ".env.local"):
        if candidat.exists():
            for ligne in candidat.read_text(encoding="utf-8").splitlines():
                ligne = ligne.strip()
                if ligne and not ligne.startswith("#") and "=" in ligne:
                    k, _, v = ligne.partition("=")
                    env[k.strip()] = v.strip().strip('"').strip("'")
            break
    return env


def resolve_config():
    env_local = read_env_local()
    url = os.environ.get("VITE_SUPABASE_URL") or env_local.get("VITE_SUPABASE_URL")
    if not url:
        sys.exit("X VITE_SUPABASE_URL introuvable (environnement ou .env.local).")
    key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY") or os.environ.get("SERVICE_ROLE_KEY")
    if not key:
        key = getpass.getpass("  Cle service_role (rien ne s'affichera) : ").strip()
    if not key:
        sys.exit("X Aucune cle fournie. Rien n'a ete lance.")
    if not (key.startswith("eyJ") or key.startswith("sb_secret_")):
        sys.exit("X Ca ne ressemble ni a un JWT (eyJ...) ni a une cle sb_secret_.")
    return url.rstrip("/"), key


# ── HTTP, avec reprises sur incident passager ────────────────────────────

TENTATIVES = 4
ATTENTES = (2, 5, 12)


def call(url, key, method="GET", json_body=None, headers=None, attendre_corps=True):
    payload = json.dumps(json_body).encode() if json_body is not None else None
    hdrs = {"apikey": key, "Authorization": f"Bearer {key}"}
    if payload:
        hdrs["Content-Type"] = "application/json"
    if headers:
        hdrs.update(headers)
    derniere = None
    for essai in range(TENTATIVES):
        try:
            req = urllib.request.Request(url, data=payload, headers=hdrs, method=method)
            with urllib.request.urlopen(req, timeout=120) as res:
                return res.read() if attendre_corps else b""
        except urllib.error.HTTPError as err:
            if err.code < 500 and err.code != 429:
                raise
            derniere = err
        except (urllib.error.URLError, TimeoutError, OSError) as err:
            derniere = err
        if essai < TENTATIVES - 1:
            print(f"    … {derniere} — nouvel essai dans {ATTENTES[essai]} s", flush=True)
            time.sleep(ATTENTES[essai])
    raise derniere


def lire_table(base, key, table, colonnes):
    """Lit une table entiere via PostgREST, par tranches de 1000."""
    lignes, decalage = [], 0
    while True:
        u = f"{base}/rest/v1/{table}?select={colonnes}&limit=1000&offset={decalage}"
        page = json.loads(call(u, key))
        lignes.extend(page)
        if len(page) < 1000:
            return lignes
        decalage += 1000


def lister_dossier(base, key, prefixe):
    entrees, decalage = [], 0
    while True:
        corps = {"prefix": prefixe, "limit": 100, "offset": decalage,
                 "sortBy": {"column": "name", "order": "asc"}}
        page = json.loads(call(f"{base}/storage/v1/object/list/{BUCKET}", key,
                               method="POST", json_body=corps))
        entrees.extend(page)
        if len(page) < 100:
            return entrees
        decalage += 100


def parcourir(base, key, prefixe=""):
    for e in lister_dossier(base, key, prefixe):
        nom = e.get("name")
        if not nom:
            continue
        chemin = f"{prefixe}/{nom}" if prefixe else nom
        if e.get("id") is None:
            yield from parcourir(base, key, chemin)
        else:
            yield chemin, (e.get("metadata") or {}).get("size", 0)


# ── Programme ────────────────────────────────────────────────────────────

def main():
    ap = argparse.ArgumentParser(description="Purge les orphelins du bucket covers.")
    ap.add_argument("--dry-run", action="store_true", help="n'efface rien, montre le classement")
    args = ap.parse_args()

    base, key = resolve_config()
    print(f"\n  Projet : {base}\n  Bucket : {BUCKET}")
    print("  Mode   : essai a blanc, aucune suppression\n" if args.dry_run else "  Mode   : SUPPRESSION REELLE\n")

    print(">>> 1/4 — lecture des references en base")
    livres = lire_table(base, key, "books", "bib_ref,cover_object_path")
    brouillons = lire_table(base, key, "book_drafts", "bib_ref,cover_object_path")
    imports = lire_table(base, key, "import_blmf_books_rows", "cover_object_path")
    references = {r["cover_object_path"] for r in (livres + brouillons + imports)
                  if r.get("cover_object_path")}
    # Une reference peut porter plusieurs notices : on retient si AU MOINS une
    # notice de cette reference est depourvue de couverture.
    notices_par_ref, sans_capa = {}, set()
    for r in livres:
        ref = r.get("bib_ref")
        if not ref:
            continue
        notices_par_ref.setdefault(ref, 0)
        notices_par_ref[ref] += 1
        if not r.get("cover_object_path"):
            sans_capa.add(ref)
    refs_brouillons = {r.get("bib_ref") for r in brouillons if r.get("bib_ref")}
    # Meme raisonnement que pour les notices : un brouillon qui porte cette
    # reference et n'a aucune couverture attend peut-etre ce fichier-la.
    sans_capa |= {r.get("bib_ref") for r in brouillons
                  if r.get("bib_ref") and not r.get("cover_object_path")}
    print(f"    {len(livres)} notices, {len(brouillons)} brouillons, "
          f"{len(references)} chemins references")

    print(">>> 2/4 — inventaire du bucket")
    objets = dict(parcourir(base, key))
    originaux = {n: t for n, t in objets.items() if not n.endswith(THUMB_SUFFIX)}
    print(f"    {len(objets)} objets, dont {len(originaux)} originaux")

    print(">>> 3/4 — classement des orphelins")
    a_supprimer, conserves = [], []
    for nom, taille in sorted(originaux.items()):
        if nom in references:
            continue
        dossier = nom.split("/")[1] if "/" in nom else ""
        if dossier in sans_capa:
            conserves.append((nom, taille, dossier))
            continue
        cas = ("B — notice deja illustree autrement" if dossier in notices_par_ref
               else "D — brouillon" if dossier in refs_brouillons
               else "A — aucune notice ni brouillon")
        a_supprimer.append((nom, taille, cas))

    if conserves:
        print(f"\n    CONSERVES — {len(conserves)} couverture(s) perdue(s), "
              f"notice sans capa :")
        for nom, taille, dossier in conserves:
            print(f"      GARDE  {nom}  ({taille // 1024} ko, notice {dossier})")

    print(f"\n    A supprimer : {len(a_supprimer)} originaux")
    for nom, taille, cas in a_supprimer:
        print(f"      {cas[:1]}  {nom}  ({taille // 1024} ko)")

    # Les vignettes suivent leur original.
    cibles = []
    for nom, taille, _ in a_supprimer:
        cibles.append((nom, taille))
        vign = nom + THUMB_SUFFIX
        if vign in objets:
            cibles.append((vign, objets[vign]))

    poids = sum(t for _, t in cibles)
    print(f"\n    Total : {len(cibles)} objets ({len(a_supprimer)} originaux + "
          f"{len(cibles) - len(a_supprimer)} vignettes), {poids // 1024} ko")

    if not cibles:
        print("\n  Rien a supprimer.\n")
        return 0
    if len(cibles) > PLAFOND:
        print(f"\nX {len(cibles)} objets depassent le plafond de securite ({PLAFOND}).")
        print("  Ce n'est pas normal pour une purge d'orphelins : verifier a la main.\n")
        return 1

    print("\n>>> 4/4 — suppression")
    if args.dry_run:
        print("    (essai a blanc — rien n'est efface)\n")
        return 0

    efface = echecs = 0
    for nom, _ in cibles:
        if not nom.startswith("books/"):          # garde-fou de forme
            print(f"    ! ignore (hors books/) : {nom}")
            continue
        try:
            call(f"{base}/storage/v1/object/{BUCKET}/{nom}", key,
                 method="DELETE", attendre_corps=False)
            efface += 1
        except (urllib.error.URLError, urllib.error.HTTPError, OSError) as err:
            echecs += 1
            print(f"    ! {nom} : {err}")

    print(f"\n  Supprimes : {efface}")
    print(f"  Echecs    : {echecs}")
    print(f"  Libere    : {poids // 1024} ko\n")
    return 1 if echecs else 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        print("\n  Interrompu.\n")
        sys.exit(130)
    except urllib.error.HTTPError as err:
        print(f"\nX HTTP {err.code} ({err.reason}) malgre {TENTATIVES} tentatives.")
        if err.code in (401, 403):
            print("  Cle refusee : verifier qu'il s'agit bien de la cle service_role.\n")
        else:
            print("  Rien n'a ete casse ; relancer plus tard.\n")
        sys.exit(1)
