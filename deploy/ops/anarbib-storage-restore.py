#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
anarbib-storage-restore.py — remettre les fichiers des buckets en place.

POURQUOI CE SCRIPT EXISTE. deploy/bootstrap.sh annonçait « rsync depuis la
sauvegarde `storage` ». C'est faux, et ça a été mesuré le 26/08/2026 : les deux
dispositions n'ont rien à voir.

    sauvegarde  : <bucket>/<nom>
                  ex. covers/books/0000046/1773334818127-41Tq7ZVw2KL.jpg
                  — un fichier ordinaire, tel que `supabase storage cp` le pose

    service     : <s3>/<tenant>/<bucket>/<nom>/<version>
                  ex. anarbib/anarbib/covers/essai/photo.png/86fefe96-c622-…
                  — le NOM DE L'OBJET EST UN DOSSIER, et le fichier porte
                    l'UUID de version

Un `rsync` produirait donc une arborescence que le service ne lit pas : les
requêtes rendraient 404 sur une base pourtant complète. Le catalogue
s'afficherait sans une seule couverture, sans que rien ne signale d'erreur.

CONSÉQUENCE D'ORDRE, ET ELLE EST STRUCTURELLE. Le lien entre les deux
dispositions est `storage.objects.version`, qui vit DANS LA BASE. On ne peut
donc pas remettre les fichiers avant d'avoir restauré la base : c'est elle qui
dit où chaque fichier doit aller. Ce script se lance APRÈS bootstrap.sh.

USAGE
    ./anarbib-storage-restore.py --source ~/anarbib-ops/.storage-work
    ./anarbib-storage-restore.py --source <dir> --simulation
    ./anarbib-storage-restore.py --source <dir> --deploy ~/anarbib/deploy

Il lit la table `storage.objects` par `docker compose exec db`, construit
l'arborescence dans un dossier temporaire, puis la verse dans le volume du
service par `docker cp`.

CE QU'IL SIGNALE, ET QU'IL FAUT LIRE
  - « objets sans fichier » : la base connaît un objet dont la sauvegarde n'a
    pas le fichier. Cas normal si le dump de la base est plus RÉCENT que la
    sauvegarde `storage` — les deux ne sont pas prises au même instant, et
    elles dérivent. Le jour de la bascule, les prendre au plus près l'une de
    l'autre, et lire ce compteur.
  - « fichiers orphelins » : l'inverse — un fichier que plus aucune ligne ne
    désigne. Sans gravité, il ne sera simplement pas versé.
"""
import argparse, collections, os, shutil, subprocess, sys

SEP = "\x1f"


def psql(deploy, sql):
    r = subprocess.run(
        ["docker", "compose", "exec", "-T", "db", "psql", "-U", "supabase_admin",
         "-d", "postgres", "-tAF" + SEP, "-c", sql],
        cwd=deploy, capture_output=True, text=True)
    if r.returncode != 0:
        sys.exit("✗ psql a échoué : %s" % (r.stderr.strip() or "raison inconnue"))
    return r.stdout


def env_de(deploy, cle, defaut):
    """Lit une valeur du compose rendu, pour ne pas deviner tenant/bucket."""
    r = subprocess.run(["docker", "compose", "config"], cwd=deploy,
                       capture_output=True, text=True)
    for ligne in r.stdout.splitlines():
        ligne = ligne.strip()
        if ligne.startswith(cle + ":"):
            return ligne.split(":", 1)[1].strip().strip('"')
    return defaut


def main():
    ap = argparse.ArgumentParser(add_help=True)
    ap.add_argument("--source", required=True,
                    help="dossier de la sauvegarde storage (<bucket>/<nom>)")
    ap.add_argument("--deploy", default=os.path.expanduser("~/anarbib/deploy"))
    ap.add_argument("--simulation", action="store_true",
                    help="ne verse rien, dit ce qui serait fait")
    a = ap.parse_args()

    source = os.path.expanduser(a.source)
    if not os.path.isdir(source):
        sys.exit("✗ source introuvable : %s" % source)

    tenant = env_de(a.deploy, "TENANT_ID", "anarbib")
    s3 = env_de(a.deploy, "GLOBAL_S3_BUCKET", "anarbib")
    print("Disposition cible : <%s>/<%s>/<bucket>/<nom>/<version>" % (s3, tenant))

    brut = psql(a.deploy,
                "select bucket_id, name, version from storage.objects "
                "order by bucket_id, name;")
    objets = [tuple(l.split(SEP)) for l in brut.splitlines()
              if l.strip() and len(l.split(SEP)) == 3]
    print("Objets en base : %d" % len(objets))
    if not objets:
        sys.exit("✗ aucune ligne dans storage.objects — restaurer la base d'abord.")

    sortie = "/tmp/anarbib-storage-restore"
    shutil.rmtree(sortie, ignore_errors=True)
    poses, absents = 0, []
    par_bucket = collections.Counter()

    for bucket, nom, version in objets:
        src = os.path.join(source, bucket, nom)
        if not os.path.isfile(src):
            absents.append("%s/%s" % (bucket, nom))
            continue
        dst_dir = os.path.join(sortie, s3, tenant, bucket, nom)
        os.makedirs(dst_dir, exist_ok=True)
        shutil.copy2(src, os.path.join(dst_dir, version))
        poses += 1
        par_bucket[bucket] += 1

    connus = set(os.path.join(b, n) for b, n, _ in objets)
    orphelins = 0
    for racine, _, fics in os.walk(source):
        for f in fics:
            if f.startswith(".log-"):
                continue
            rel = os.path.relpath(os.path.join(racine, f), source)
            if rel not in connus:
                orphelins += 1

    print("Fichiers transposés : %d" % poses)
    print("Objets SANS fichier : %d%s" % (len(absents),
          "  ← la sauvegarde storage est plus ancienne que le dump ?" if absents else ""))
    for x in absents[:10]:
        print("    manquant : %s" % x)
    if len(absents) > 10:
        print("    … et %d autres" % (len(absents) - 10))
    print("Fichiers orphelins  : %d" % orphelins)
    print()
    for b, n in sorted(par_bucket.items()):
        print("  %-28s %d" % (b, n))
    print()

    if a.simulation:
        print("SIMULATION : rien n'a été versé. Arborescence prête dans %s" % sortie)
        return 0

    ctn = subprocess.run(["docker", "compose", "ps", "-q", "storage"],
                         cwd=a.deploy, capture_output=True, text=True).stdout.strip()
    if not ctn:
        sys.exit("✗ conteneur `storage` introuvable — la pile est-elle démarrée ?")

    r = subprocess.run(["docker", "cp", sortie + "/.", ctn + ":/var/lib/storage/"],
                       capture_output=True, text=True)
    if r.returncode != 0:
        sys.exit("✗ docker cp a échoué : %s" % r.stderr.strip())

    n = subprocess.run(["docker", "exec", ctn, "sh", "-c",
                        "find /var/lib/storage -type f | wc -l"],
                       capture_output=True, text=True).stdout.strip()
    print("✓ Versé. Fichiers dans le volume : %s" % n)
    print()
    print("ÉPREUVE, à faire et pas à supposer — télécharger un objet public et")
    print("comparer ses octets à ceux de la sauvegarde :")
    print("  curl -sk -H \"apikey: $ANON\" \\")
    print("    https://localhost/storage/v1/object/public/<bucket>/<nom> | sha256sum")
    print("  sha256sum <source>/<bucket>/<nom>")
    return 0


if __name__ == "__main__":
    sys.exit(main())
