#!/usr/bin/env python3
"""
Ajoute 10 clés i18n génériques dans le namespace `address.*` pour les libellés
du formulaire d'adresse, dans les 6 locales d'AnarBib.

Ces clés sont destinées à être utilisées par tout formulaire d'adresse
(/conta, /criar-conta, parcours de constitution biblio futur, etc.) pour éviter
la duplication entre namespaces (auth.create.addr*, account.address.*, etc.).

Clés ajoutées :
  - address.title              (titre de section)
  - address.line1              (label "Voie / Calle / Street")
  - address.line1.placeholder
  - address.line2              (label "Complément")
  - address.line2.placeholder
  - address.unit               (label "Numéro")
  - address.unit.placeholder
  - address.district           (label "Quartier / Bairro")
  - address.city               (label "Ville")
  - address.city.placeholder

Approche surgicale en byte-level :
  - préserve les fins de ligne (CRLF/LF)
  - préserve l'indentation et l'ordre alphabétique des clés
  - idempotent : peut être relancé sans dommage
  - valide le JSON avant d'écrire

Usage (depuis la racine du repo) :
    python add-address-generic-keys.py
"""
import json
import re
import sys
from pathlib import Path

LOCALES_DIR = Path("src/i18n/locales")

# Les 10 nouvelles clés à ajouter, dans l'ordre alphabétique de leur suffixe.
# Insertion : juste avant address.country (qui existe déjà).
KEYS_ORDER = [
    "city",
    "city.placeholder",
    "district",
    "line1",
    "line1.placeholder",
    "line2",
    "line2.placeholder",
    "title",
    "unit",
    "unit.placeholder",
]

# Mais l'ordre alphabétique strict avec les address.* existants est :
#   address.city < address.city.placeholder < address.country < address.country.* (existants)
#   < address.district < address.line1 < address.line1.placeholder < address.line2
#   < address.line2.placeholder < address.phone.* (existants) < address.postalCode.* (existants)
#   < address.state.* (existants) < address.title < address.unit < address.unit.placeholder
#
# Pour rester simple et préserver l'ordre alphabétique, on insère chaque clé
# à sa bonne place via un point d'ancrage différent.

# Plan d'insertion : pour chaque nouvelle clé, on définit un "point d'ancrage" qui est
# la première clé existante alphabétiquement supérieure. On insère JUSTE AVANT.
#
# Ordre alphabétique des préfixes existants : address.country, address.phone, address.postalCode, address.state
INSERTIONS = [
    # (clé à ajouter, ancre = clé existante supérieure alphabétiquement)
    ("address.city",              "address.country"),               # avant le 1er address.country
    ("address.city.placeholder",  "address.country"),               # juste après address.city, donc avant address.country
    ("address.district",          "address.phone.hint"),            # district vient après country.* et avant phone.*
    ("address.line1",             "address.phone.hint"),            # idem
    ("address.line1.placeholder", "address.phone.hint"),
    ("address.line2",             "address.phone.hint"),
    ("address.line2.placeholder", "address.phone.hint"),
    ("address.title",             None),                            # title > state.*, on l'ajoute en dernier après address.state.*
    ("address.unit",              None),                            # unit > title
    ("address.unit.placeholder",  None),                            # unit.placeholder > unit
]

TRANSLATIONS = {
    "pt-BR.json": {
        "title":              "Endereço",
        "line1":              "Logradouro",
        "line1.placeholder":  "Rua, avenida, etc.",
        "line2":              "Complemento",
        "line2.placeholder":  "Apto, sala, etc.",
        "unit":               "Número",
        "unit.placeholder":   "Número da casa",
        "district":           "Bairro",
        "city":               "Cidade",
        "city.placeholder":   "",
    },
    "fr.json": {
        "title":              "Adresse",
        "line1":              "Voie",
        "line1.placeholder":  "Rue, avenue, etc.",
        "line2":              "Complément",
        "line2.placeholder":  "Apt, étage, etc.",
        "unit":               "Numéro",
        "unit.placeholder":   "Numéro de rue",
        "district":           "Quartier",
        "city":               "Ville",
        "city.placeholder":   "",
    },
    "es.json": {
        "title":              "Dirección",
        "line1":              "Calle",
        "line1.placeholder":  "Calle, avenida, etc.",
        "line2":              "Complemento",
        "line2.placeholder":  "Apto, piso, etc.",
        "unit":               "Número",
        "unit.placeholder":   "Número de calle",
        "district":           "Barrio",
        "city":               "Ciudad",
        "city.placeholder":   "",
    },
    "en.json": {
        "title":              "Address",
        "line1":              "Street",
        "line1.placeholder":  "Street, avenue, etc.",
        "line2":              "Additional info",
        "line2.placeholder":  "Apt, floor, etc.",
        "unit":               "Number",
        "unit.placeholder":   "Street number",
        "district":           "District",
        "city":               "City",
        "city.placeholder":   "",
    },
    "it.json": {
        "title":              "Indirizzo",
        "line1":              "Via",
        "line1.placeholder":  "Via, viale, ecc.",
        "line2":              "Complemento",
        "line2.placeholder":  "Int., piano, ecc.",
        "unit":               "Numero",
        "unit.placeholder":   "Numero civico",
        "district":           "Quartiere",
        "city":               "Città",
        "city.placeholder":   "",
    },
    "de.json": {
        "title":              "Adresse",
        "line1":              "Straße",
        "line1.placeholder":  "Straße, Allee, usw.",
        "line2":              "Zusatz",
        "line2.placeholder":  "Wohnung, Etage, usw.",
        "unit":               "Nummer",
        "unit.placeholder":   "Hausnummer",
        "district":           "Stadtteil",
        "city":               "Stadt",
        "city.placeholder":   "",
    },
}


def build_line(key: str, value: str, eol: bytes) -> bytes:
    """Construit une ligne JSON `  "key": "value",<EOL>`."""
    encoded_key = json.dumps(key, ensure_ascii=False)
    encoded_value = json.dumps(value, ensure_ascii=False)
    return (f"  {encoded_key}: {encoded_value},").encode("utf-8") + eol


def insert_key_alphabetically(data: bytes, new_key: str, new_value: str, eol: bytes) -> bytes:
    """
    Insère une nouvelle clé JSON dans `data` en respectant l'ordre alphabétique
    des clés existantes.

    Stratégie : on parcourt toutes les lignes ressemblant à `  "key": value,`
    et on trouve la première clé qui est alphabétiquement SUPÉRIEURE à `new_key`.
    On insère juste avant cette ligne.

    Si new_key est alphabétiquement supérieure à toutes les clés existantes,
    on insère juste avant la dernière ligne (l'accolade fermante `}`).
    """
    # Pattern pour matcher une ligne JSON de type `  "key": ...`
    line_pattern = re.compile(rb'^(  "([^"]+)": )', re.MULTILINE)

    # Trouve toutes les clés et leurs positions de début de ligne
    keys_with_positions = []
    for match in line_pattern.finditer(data):
        key_str = match.group(2).decode('utf-8')
        # Position du début de la ligne (le \n précédent + 1, ou 0 si début de fichier)
        line_start = data.rfind(b'\n', 0, match.start()) + 1
        keys_with_positions.append((key_str, line_start))

    if not keys_with_positions:
        # Fichier sans clés — ne devrait pas arriver
        return data

    # Trouve la 1re clé alphabétiquement supérieure à new_key
    insert_position = None
    for key_str, line_start in keys_with_positions:
        if key_str > new_key:
            insert_position = line_start
            break

    new_line = build_line(new_key, new_value, eol)

    if insert_position is None:
        # new_key est alphabétiquement la plus grande : insérer avant la dernière ligne
        # qui est l'accolade fermante `}`. On cherche la dernière clé et on insère après.
        last_key_pos = keys_with_positions[-1][1]
        # Trouver la fin de cette dernière ligne (le \n suivant)
        last_line_end = data.find(b'\n', last_key_pos) + 1
        return data[:last_line_end] + new_line + data[last_line_end:]
    else:
        return data[:insert_position] + new_line + data[insert_position:]


def main() -> int:
    if not LOCALES_DIR.exists():
        print(f"ERREUR : répertoire {LOCALES_DIR} introuvable.", file=sys.stderr)
        print("Lance ce script depuis la racine du repo AnarBib.", file=sys.stderr)
        return 1

    total_changed = 0
    total_already_done = 0
    errors = []

    # Liste des 10 nouvelles clés (sans le préfixe address.)
    new_keys = list(TRANSLATIONS["pt-BR.json"].keys())

    for fname, labels in TRANSLATIONS.items():
        path = LOCALES_DIR / fname
        if not path.exists():
            errors.append(f"{fname} : fichier manquant")
            continue

        with path.open("rb") as fh:
            data = fh.read()

        # Idempotence : compter combien de clés sont déjà présentes
        full_keys = [f"address.{k}" for k in new_keys]
        already_present = [k for k in full_keys if f'"{k}"'.encode() in data]

        if len(already_present) == len(full_keys):
            print(f"  {fname} : déjà à jour (les 10 clés sont présentes)")
            total_already_done += 1
            continue

        if already_present:
            errors.append(
                f"{fname} : état partiel — {len(already_present)}/{len(full_keys)} clés présentes. "
                f"Vérifier manuellement."
            )
            continue

        # Détecter le type de fin de ligne
        eol = b'\r\n' if b'\r\n' in data[:200] else b'\n'

        # Insertion alphabétique automatique pour chaque clé
        for short_key in new_keys:
            full_key = f"address.{short_key}"
            value = labels[short_key]
            data = insert_key_alphabetically(data, full_key, value, eol)

        # Validation JSON finale
        try:
            json.loads(data.decode("utf-8"))
        except json.JSONDecodeError as e:
            errors.append(f"{fname} : JSON invalide après insertion ({e}) — fichier non écrit")
            continue

        with path.open("wb") as fh:
            fh.write(data)
        print(f"  {fname} : OK (10 clés ajoutées)")
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
