#!/usr/bin/env python3
"""
Ajoute 5 clés i18n manquantes pour les messages d'erreur de renouvellement
d'emprunt (RPC fn_renew_my_loan).

Bug identifié : la RPC peut renvoyer 6 valeurs distinctes pour `data.reason`
(`not_authenticated`, `not_found`, `already_extended`, `overdue`,
`reserved_by_other`, `renewed`), mais seul `account.renew.renewed` existait
dans les locales. Résultat : dès qu'un renouvellement échoue (cas courants :
emprunt en retard, livre réservé par autrui), la popup d'alerte affichait
la clé brute du genre "account.renew.reserved_by_other".

Approche surgicale en byte-level :
  - préserve les fins de ligne (CRLF/LF)
  - préserve l'indentation et l'ordre alphabétique des clés
  - idempotent : peut être relancé sans dommage
  - valide le JSON avant d'écrire

Insertion alphabétique : les nouvelles clés s'insèrent juste avant
account.renew.renewed qui existe déjà (ordre alphabétique :
already_extended, not_authenticated, not_found, overdue, renewed,
reserved_by_other).

Usage (depuis la racine du repo) :
    python add-account-renew-reasons.py
"""
import json
import re
import sys
from pathlib import Path

LOCALES_DIR = Path("src/i18n/locales")

# Les 5 nouvelles clés à ajouter, dans l'ordre alphabétique de leur suffixe.
# La clé `renewed` existe déjà et n'est pas touchée.
# Ordre alphabétique du suffixe :
#   already_extended < not_authenticated < not_found < overdue < renewed < reserved_by_other
# Donc 4 clés s'insèrent AVANT renewed, et 1 clé (reserved_by_other) APRÈS.

KEYS_BEFORE_RENEWED = [
    "already_extended",
    "not_authenticated",
    "not_found",
    "overdue",
]

KEYS_AFTER_RENEWED = [
    "reserved_by_other",
]

TRANSLATIONS = {
    "pt-BR.json": {
        "already_extended":   "Este empréstimo já foi renovado uma vez.",
        "not_authenticated":  "Você precisa estar conectada ao AnarBib para renovar um empréstimo.",
        "not_found":          "Empréstimo não encontrado ou já encerrado.",
        "overdue":            "Empréstimo em atraso. Devolva o livro à biblioteca antes de renovar uma próxima vez.",
        "reserved_by_other":  "Este livro está reservado por outra pessoa. Renovação impossível.",
    },
    "fr.json": {
        "already_extended":   "Cet emprunt a déjà été renouvelé une fois.",
        "not_authenticated":  "Tu dois être connecté·e à AnarBib pour renouveler un emprunt.",
        "not_found":          "Emprunt introuvable ou déjà clôturé.",
        "overdue":            "Emprunt en retard. Rends le livre à la bibliothèque avant un prochain renouvellement.",
        "reserved_by_other":  "Ce livre est réservé par une autre personne. Renouvellement impossible.",
    },
    "es.json": {
        "already_extended":   "Este préstamo ya fue renovado una vez.",
        "not_authenticated":  "Tenés que estar conectade a AnarBib para renovar un préstamo.",
        "not_found":          "Préstamo no encontrado o ya cerrado.",
        "overdue":            "Préstamo atrasado. Devolvé el libro a la biblioteca antes de renovar la próxima vez.",
        "reserved_by_other":  "Este libro está reservado por otra persona. Renovación imposible.",
    },
    "en.json": {
        "already_extended":   "This loan has already been renewed once.",
        "not_authenticated":  "You must be signed in to AnarBib to renew a loan.",
        "not_found":          "Loan not found or already closed.",
        "overdue":            "Loan overdue. Return the book to the library before renewing next time.",
        "reserved_by_other":  "This book is reserved by another person. Renewal not possible.",
    },
    "it.json": {
        "already_extended":   "Questo prestito è già stato rinnovato una volta.",
        "not_authenticated":  "Devi essere collegato/a ad AnarBib per rinnovare un prestito.",
        "not_found":          "Prestito non trovato o già chiuso.",
        "overdue":            "Prestito in ritardo. Restituisci il libro alla biblioteca prima di rinnovare la prossima volta.",
        "reserved_by_other":  "Questo libro è prenotato da un'altra persona. Rinnovo non possibile.",
    },
    "de.json": {
        "already_extended":   "Diese Ausleihe wurde bereits einmal verlängert.",
        "not_authenticated":  "Du musst bei AnarBib angemeldet sein, um eine Ausleihe zu verlängern.",
        "not_found":          "Ausleihe nicht gefunden oder bereits abgeschlossen.",
        "overdue":            "Ausleihe überfällig. Bring das Buch in die Bibliothek zurück, bevor du das nächste Mal verlängerst.",
        "reserved_by_other":  "Dieses Buch ist von einer anderen Person reserviert. Verlängerung nicht möglich.",
    },
}


def build_line(key: str, value: str, eol: bytes) -> bytes:
    """Construit une ligne JSON `  "key": "value",<EOL>`."""
    encoded_key = json.dumps(key, ensure_ascii=False)
    encoded_value = json.dumps(value, ensure_ascii=False)
    return (f"  {encoded_key}: {encoded_value},").encode("utf-8") + eol


def insert_before_anchor(data: bytes, anchor_pattern: re.Pattern, lines_to_insert: bytes) -> bytes | None:
    """Insère des lignes juste avant la ligne contenant l'ancre."""
    match = anchor_pattern.search(data)
    if not match:
        return None
    # Remonte au début de la ligne contenant l'ancre
    line_start = data.rfind(b'\n', 0, match.start()) + 1
    return data[:line_start] + lines_to_insert + data[line_start:]


def main() -> int:
    if not LOCALES_DIR.exists():
        print(f"ERREUR : répertoire {LOCALES_DIR} introuvable.", file=sys.stderr)
        print("Lance ce script depuis la racine du repo AnarBib.", file=sys.stderr)
        return 1

    total_changed = 0
    total_already_done = 0
    errors = []

    # Ancre 1 : la ligne de account.renew.renewed (pour insérer les 4 clés AVANT)
    anchor_renewed = re.compile(rb'  "account\.renew\.renewed":')
    # Ancre 2 : la 1re ligne après account.renew.renewed (pour insérer reserved_by_other APRÈS)
    # On utilise comme ancre la clé suivante alphabétiquement : account.reserve.* est probable
    # mais peut varier. On utilise donc un pattern qui matche la clé suivante directement.
    # En fait c'est plus simple : on insère reserved_by_other AVANT la 1re clé qui n'est pas
    # account.renew.* — typiquement account.reserve.*

    for fname, labels in TRANSLATIONS.items():
        path = LOCALES_DIR / fname
        if not path.exists():
            errors.append(f"{fname} : fichier manquant")
            continue

        with path.open("rb") as fh:
            data = fh.read()

        # Idempotence : compter combien de clés sont déjà présentes
        all_keys_to_add = KEYS_BEFORE_RENEWED + KEYS_AFTER_RENEWED
        already_present = [k for k in all_keys_to_add if f'"account.renew.{k}"'.encode() in data]

        if len(already_present) == len(all_keys_to_add):
            print(f"  {fname} : déjà à jour (les 5 clés sont présentes)")
            total_already_done += 1
            continue

        if already_present:
            errors.append(
                f"{fname} : état partiel détecté — {len(already_present)}/{len(all_keys_to_add)} "
                f"clés présentes ({', '.join(already_present)}). Vérifier manuellement."
            )
            continue

        # Détecter le type de fin de ligne
        eol = b'\r\n' if b'\r\n' in data[:200] else b'\n'

        # ÉTAPE 1 : insérer les 4 clés AVANT account.renew.renewed
        lines_before = b''.join(
            build_line(f"account.renew.{k}", labels[k], eol)
            for k in KEYS_BEFORE_RENEWED
        )
        new_data = insert_before_anchor(data, anchor_renewed, lines_before)
        if new_data is None:
            errors.append(f"{fname} : ancre 'account.renew.renewed' introuvable")
            continue
        data = new_data

        # ÉTAPE 2 : insérer reserved_by_other APRÈS account.renew.renewed
        # Stratégie : trouver la ligne renewed, puis insérer juste après son EOL.
        renewed_line_pattern = re.compile(
            rb'(  "account\.renew\.renewed":\s*"[^"]*",)(\r\n|\n)',
            re.DOTALL
        )
        match = renewed_line_pattern.search(data)
        if not match:
            errors.append(f"{fname} : ligne 'account.renew.renewed' introuvable après insertion")
            continue
        insert_pos = match.end()
        line_after = build_line(
            "account.renew.reserved_by_other",
            labels["reserved_by_other"],
            eol
        )
        data = data[:insert_pos] + line_after + data[insert_pos:]

        # Validation JSON finale
        try:
            json.loads(data.decode("utf-8"))
        except json.JSONDecodeError as e:
            errors.append(f"{fname} : JSON invalide après insertion ({e}) — fichier non écrit")
            continue

        with path.open("wb") as fh:
            fh.write(data)
        print(f"  {fname} : OK (5 clés ajoutées)")
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
