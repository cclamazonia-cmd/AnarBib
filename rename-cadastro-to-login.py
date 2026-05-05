#!/usr/bin/env python3
"""
Renomme les clés i18n auth.cadastro.title/subtitle -> auth.login.title/subtitle
dans les 6 locales d'AnarBib.

Approche surgicale en byte-level :
  - préserve les fins de ligne (CRLF/LF)
  - préserve l'absence (ou la présence) de newline final
  - préserve l'ordre des clés et l'indentation
  - idempotent : peut être relancé sans dommage

Usage (depuis la racine du repo) :
    python rename-cadastro-to-login.py

Le script valide aussi que chaque fichier reste un JSON valide après modification.
"""
import json
import sys
from pathlib import Path

LOCALES_DIR = Path("src/i18n/locales")
LOCALES = ["pt-BR.json", "fr.json", "es.json", "en.json", "it.json", "de.json"]

REPLACEMENTS = [
    (b'"auth.cadastro.title"',    b'"auth.login.title"'),
    (b'"auth.cadastro.subtitle"', b'"auth.login.subtitle"'),
]


def main() -> int:
    if not LOCALES_DIR.exists():
        print(f"ERREUR : répertoire {LOCALES_DIR} introuvable.", file=sys.stderr)
        print("Lance ce script depuis la racine du repo AnarBib.", file=sys.stderr)
        return 1

    total_changed = 0
    total_already_done = 0
    errors = []

    for name in LOCALES:
        path = LOCALES_DIR / name
        if not path.exists():
            errors.append(f"{name} : fichier manquant")
            continue

        with path.open("rb") as fh:
            original = fh.read()

        modified = original
        for old, new in REPLACEMENTS:
            modified = modified.replace(old, new)

        if modified == original:
            # Vérifie si c'est déjà migré ou si les clés sont absentes
            if b'"auth.login.title"' in modified and b'"auth.login.subtitle"' in modified:
                print(f"  {name} : déjà migré (idempotent)")
                total_already_done += 1
            else:
                errors.append(f"{name} : aucune clé auth.cadastro.title/subtitle trouvée et pas de auth.login.title/subtitle non plus — fichier inattendu")
            continue

        # Validation JSON avant écriture
        try:
            json.loads(modified.decode("utf-8"))
        except json.JSONDecodeError as e:
            errors.append(f"{name} : JSON invalide après modification ({e}) — fichier non écrit")
            continue

        with path.open("wb") as fh:
            fh.write(modified)
        print(f"  {name} : OK (modifié)")
        total_changed += 1

    print()
    print(f"Bilan : {total_changed} fichier(s) modifié(s), {total_already_done} déjà à jour.")

    if errors:
        print()
        print("Erreurs :", file=sys.stderr)
        for e in errors:
            print(f"  - {e}", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    sys.exit(main())
