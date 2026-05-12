"""
Paquet 25.7bis — Injection des 2 cles i18n auth.create.noLibInfo.* dans les 6 fichiers de locale.

Usage:
    cd "C:\\Users\\accat\\Claude's AnarBib\\anarbib-app"
    python inject_paquet25_7bis_i18n.py
"""
import json
import os
import sys

PROJECT_ROOT = r"C:\Users\accat\Claude's AnarBib\anarbib-app"
LOCALES_DIR = os.path.join(PROJECT_ROOT, "src", "i18n", "locales")

KEYS = {
    "pt-BR": {
        "auth.create.noLibInfo.title": "Inscrição sem biblioteca vinculada",
        "auth.create.noLibInfo.body": "Você está se inscrevendo sem vincular sua conta a uma biblioteca já cadastrada. Depois de criar sua conta, você receberá um e-mail com um link para enviar a solicitação institucional da sua biblioteca à coordenação da rede AnarBib.",
    },
    "fr": {
        "auth.create.noLibInfo.title": "Inscription sans bibliothèque rattachée",
        "auth.create.noLibInfo.body": "Tu t'inscris sans rattacher ton compte à une bibliothèque déjà enregistrée. Après création de ton compte, tu recevras un e-mail contenant un lien pour soumettre la demande institutionnelle de ta bibliothèque à la coordination du réseau AnarBib.",
    },
    "es": {
        "auth.create.noLibInfo.title": "Inscripción sin biblioteca vinculada",
        "auth.create.noLibInfo.body": "Te estás inscribiendo sin vincular tu cuenta a una biblioteca ya registrada. Después de crear tu cuenta, recibirás un correo con un enlace para enviar la solicitud institucional de tu biblioteca a la coordinación de la red AnarBib.",
    },
    "en": {
        "auth.create.noLibInfo.title": "Registration without an attached library",
        "auth.create.noLibInfo.body": "You are registering without attaching your account to an existing library. After your account is created, you will receive an email with a link to submit the institutional request for your library to the AnarBib network coordination.",
    },
    "it": {
        "auth.create.noLibInfo.title": "Iscrizione senza biblioteca collegata",
        "auth.create.noLibInfo.body": "Ti stai iscrivendo senza collegare il tuo account a una biblioteca già registrata. Dopo la creazione del tuo account, riceverai un'e-mail con un link per inviare la richiesta istituzionale della tua biblioteca al coordinamento della rete AnarBib.",
    },
    "de": {
        "auth.create.noLibInfo.title": "Anmeldung ohne angehängte Bibliothek",
        "auth.create.noLibInfo.body": "Du meldest dich an, ohne dein Konto mit einer bereits registrierten Bibliothek zu verknüpfen. Nach Erstellung deines Kontos erhältst du eine E-Mail mit einem Link, um den institutionellen Antrag deiner Bibliothek an die Koordination des AnarBib-Netzwerks zu übermitteln.",
    },
}


def inject_one(locale):
    path = os.path.join(LOCALES_DIR, f"{locale}.json")
    if not os.path.exists(path):
        print(f"[ERREUR] Fichier introuvable : {path}")
        return False

    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)

    added = 0
    skipped = 0
    for key, value in KEYS[locale].items():
        if key in data:
            skipped += 1
        else:
            data[key] = value
            added += 1

    with open(path, "w", encoding="utf-8", newline="\n") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write("\n")

    print(f"[OK] {locale}.json : ajoute={added}, deja_present={skipped}")
    return True


def main():
    print(f"Repertoire des locales : {LOCALES_DIR}\n")
    ok = True
    for locale in ["pt-BR", "fr", "es", "en", "it", "de"]:
        if not inject_one(locale):
            ok = False
    if ok:
        print("\nTermine avec succes.")
    else:
        print("\nERREUR pendant l'injection.")
        sys.exit(1)


if __name__ == "__main__":
    main()
