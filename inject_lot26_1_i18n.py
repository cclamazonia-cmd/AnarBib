"""
Lot 26.1 — Injection des cles i18n pour :
  - 8 cles "account.changePassword.*" (section Mudar minha senha)
  - 1 cle "account.alert.incomplete.cta" (CTA bandeau cadastro incompleto)

Total : 9 cles x 6 locales = 54 entrees. Idempotent (skip si deja present).

Usage:
    cd "C:\\Users\\accat\\Claude's AnarBib\\anarbib-app"
    python inject_lot26_1_i18n.py
"""
import json
import os
import sys

PROJECT_ROOT = r"C:\Users\accat\Claude's AnarBib\anarbib-app"
LOCALES_DIR = os.path.join(PROJECT_ROOT, "src", "i18n", "locales")

KEYS = {
    "pt-BR": {
        "account.changePassword.title": "Mudar minha senha",
        "account.changePassword.hint": "Defina uma nova senha de pelo menos 8 caracteres. A confirmação é obrigatória.",
        "account.changePassword.newPassword": "Nova senha",
        "account.changePassword.confirmPassword": "Confirmar nova senha",
        "account.changePassword.submit": "Atualizar senha",
        "account.changePassword.success": "Senha atualizada com sucesso.",
        "account.changePassword.error.tooShort": "A nova senha deve ter pelo menos 8 caracteres.",
        "account.changePassword.error.mismatch": "A confirmação não corresponde à nova senha.",
        "account.alert.incomplete.cta": "Solicitar inscrição da biblioteca",
    },
    "fr": {
        "account.changePassword.title": "Changer mon mot de passe",
        "account.changePassword.hint": "Définis un nouveau mot de passe d'au moins 8 caractères. La confirmation est obligatoire.",
        "account.changePassword.newPassword": "Nouveau mot de passe",
        "account.changePassword.confirmPassword": "Confirmer le nouveau mot de passe",
        "account.changePassword.submit": "Mettre à jour le mot de passe",
        "account.changePassword.success": "Mot de passe mis à jour avec succès.",
        "account.changePassword.error.tooShort": "Le nouveau mot de passe doit faire au moins 8 caractères.",
        "account.changePassword.error.mismatch": "La confirmation ne correspond pas au nouveau mot de passe.",
        "account.alert.incomplete.cta": "Solliciter l'inscription de la bibliothèque",
    },
    "es": {
        "account.changePassword.title": "Cambiar mi contraseña",
        "account.changePassword.hint": "Define una nueva contraseña de al menos 8 caracteres. La confirmación es obligatoria.",
        "account.changePassword.newPassword": "Nueva contraseña",
        "account.changePassword.confirmPassword": "Confirmar nueva contraseña",
        "account.changePassword.submit": "Actualizar contraseña",
        "account.changePassword.success": "Contraseña actualizada con éxito.",
        "account.changePassword.error.tooShort": "La nueva contraseña debe tener al menos 8 caracteres.",
        "account.changePassword.error.mismatch": "La confirmación no coincide con la nueva contraseña.",
        "account.alert.incomplete.cta": "Solicitar la inscripción de la biblioteca",
    },
    "en": {
        "account.changePassword.title": "Change my password",
        "account.changePassword.hint": "Set a new password of at least 8 characters. Confirmation is required.",
        "account.changePassword.newPassword": "New password",
        "account.changePassword.confirmPassword": "Confirm new password",
        "account.changePassword.submit": "Update password",
        "account.changePassword.success": "Password updated successfully.",
        "account.changePassword.error.tooShort": "The new password must be at least 8 characters long.",
        "account.changePassword.error.mismatch": "The confirmation does not match the new password.",
        "account.alert.incomplete.cta": "Request library registration",
    },
    "it": {
        "account.changePassword.title": "Cambiare la mia password",
        "account.changePassword.hint": "Imposta una nuova password di almeno 8 caratteri. La conferma è obbligatoria.",
        "account.changePassword.newPassword": "Nuova password",
        "account.changePassword.confirmPassword": "Conferma nuova password",
        "account.changePassword.submit": "Aggiornare la password",
        "account.changePassword.success": "Password aggiornata con successo.",
        "account.changePassword.error.tooShort": "La nuova password deve avere almeno 8 caratteri.",
        "account.changePassword.error.mismatch": "La conferma non corrisponde alla nuova password.",
        "account.alert.incomplete.cta": "Richiedere la registrazione della biblioteca",
    },
    "de": {
        "account.changePassword.title": "Mein Passwort ändern",
        "account.changePassword.hint": "Lege ein neues Passwort mit mindestens 8 Zeichen fest. Die Bestätigung ist erforderlich.",
        "account.changePassword.newPassword": "Neues Passwort",
        "account.changePassword.confirmPassword": "Neues Passwort bestätigen",
        "account.changePassword.submit": "Passwort aktualisieren",
        "account.changePassword.success": "Passwort erfolgreich aktualisiert.",
        "account.changePassword.error.tooShort": "Das neue Passwort muss mindestens 8 Zeichen lang sein.",
        "account.changePassword.error.mismatch": "Die Bestätigung stimmt nicht mit dem neuen Passwort überein.",
        "account.alert.incomplete.cta": "Bibliotheksregistrierung beantragen",
    },
}


def inject_one(locale):
    path = os.path.join(LOCALES_DIR, f"{locale}.json")
    if not os.path.exists(path):
        print(f"[ERREUR] Fichier introuvable : {path}")
        return False
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)
    added, skipped = 0, 0
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
    print("Injection cles i18n lot 26.1...")
    print("-" * 60)
    ok = True
    for locale in ["pt-BR", "fr", "es", "en", "it", "de"]:
        if not inject_one(locale):
            ok = False
    print("-" * 60)
    if ok:
        print("Termine avec succes.")
    else:
        print("ERREUR lors de l'injection.")
        sys.exit(1)


if __name__ == "__main__":
    main()
