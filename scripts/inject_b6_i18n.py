#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Inject i18n keys B6 — Modal annulation biblio consulta
========================================================
Ajoute 11 clés × 6 locales = 66 chaînes dans les fichiers JSON i18n.

Doctrine militante AnarBib respectée :
- pt-BR : forme triple ou triple-genre
- fr : point médian inclusif
- es : neutre 'e' argentin
- it : compagn*o (jamais camerati)
- de : Genderstern (*in)
- en : neutre par défaut

Utilisation :
    cd C:\\Users\\accat\\Claude's AnarBib\\anarbib-app
    python "$env:USERPROFILE\\Downloads\\inject_b6_i18n.py"
"""

import json
import os
import sys
from pathlib import Path

# ============================================================
# Configuration
# ============================================================

REPO_ROOT = Path(__file__).resolve().parent.parent / "Claude's AnarBib" / "anarbib-app"
# Fallback si exécuté depuis le repo lui-même
if not REPO_ROOT.exists():
    REPO_ROOT = Path.cwd()

I18N_DIR = REPO_ROOT / "src" / "i18n" / "locales"

LOCALES = ['pt-BR', 'fr', 'es', 'en', 'it', 'de']

# ============================================================
# Clés à injecter (11 clés × 6 locales = 66 chaînes)
# ============================================================

KEYS = {
    'pt-BR': {
        'panel.consultation.cancel.title': 'Anular consulta',
        'panel.consultation.cancel.subtitle': 'Leitor·a·e',
        'panel.consultation.cancel.book': 'Livro',
        'panel.consultation.cancel.description': 'Esta ação será notificada ao·à leitor·a·e. Indique brevemente o motivo da anulação. A nota é obrigatória e ficará registrada no histórico da consulta.',
        'panel.consultation.cancel.noteLabel': 'Motivo da anulação',
        'panel.consultation.cancel.notePlaceholder': 'Ex.: Livro indisponível temporariamente, doblee com outro pedido, problema técnico…',
        'panel.consultation.cancel.noteHint': 'Mínimo 5 caracteres',
        'panel.consultation.cancel.backButton': 'Voltar',
        'panel.consultation.cancel.confirmButton': 'Confirmar anulação',
        'panel.consultation.cancel.submitting': 'Anulando…',
        'panel.consultation.cancel.errorNoteTooShort': 'A nota deve ter pelo menos 5 caracteres.',
        'panel.consultation.cancel.errorNoteTooLong': 'A nota não pode exceder 300 caracteres.',
        'panel.consultation.cancel.errorBackend': 'O servidor recusou a anulação: nota obrigatória de pelo menos 5 caracteres.',
        'panel.consultation.cancel.errorGeneric': 'Erro ao anular a consulta. Tente novamente ou contate a coordenação.',
    },
    'fr': {
        'panel.consultation.cancel.title': 'Annuler la consultation',
        'panel.consultation.cancel.subtitle': 'Lecteur·rice',
        'panel.consultation.cancel.book': 'Livre',
        'panel.consultation.cancel.description': 'Cette action sera notifiée au·à la lecteur·rice. Indique brièvement le motif de l\'annulation. La note est obligatoire et sera enregistrée dans l\'historique de la consultation.',
        'panel.consultation.cancel.noteLabel': 'Motif de l\'annulation',
        'panel.consultation.cancel.notePlaceholder': 'Ex. : Livre temporairement indisponible, doublon avec une autre demande, problème technique…',
        'panel.consultation.cancel.noteHint': 'Minimum 5 caractères',
        'panel.consultation.cancel.backButton': 'Retour',
        'panel.consultation.cancel.confirmButton': 'Confirmer l\'annulation',
        'panel.consultation.cancel.submitting': 'Annulation…',
        'panel.consultation.cancel.errorNoteTooShort': 'La note doit faire au moins 5 caractères.',
        'panel.consultation.cancel.errorNoteTooLong': 'La note ne peut pas dépasser 300 caractères.',
        'panel.consultation.cancel.errorBackend': 'Le serveur a refusé l\'annulation : note obligatoire d\'au moins 5 caractères.',
        'panel.consultation.cancel.errorGeneric': 'Erreur lors de l\'annulation. Réessaie ou contacte la coordination.',
    },
    'es': {
        'panel.consultation.cancel.title': 'Anular consulta',
        'panel.consultation.cancel.subtitle': 'Lectore',
        'panel.consultation.cancel.book': 'Libro',
        'panel.consultation.cancel.description': 'Esta acción será notificada a le lectore. Indica brevemente el motivo de la anulación. La nota es obligatoria y quedará registrada en el historial de la consulta.',
        'panel.consultation.cancel.noteLabel': 'Motivo de la anulación',
        'panel.consultation.cancel.notePlaceholder': 'Ej.: Libro temporalmente no disponible, duplicado con otra solicitud, problema técnico…',
        'panel.consultation.cancel.noteHint': 'Mínimo 5 caracteres',
        'panel.consultation.cancel.backButton': 'Volver',
        'panel.consultation.cancel.confirmButton': 'Confirmar anulación',
        'panel.consultation.cancel.submitting': 'Anulando…',
        'panel.consultation.cancel.errorNoteTooShort': 'La nota debe tener al menos 5 caracteres.',
        'panel.consultation.cancel.errorNoteTooLong': 'La nota no puede exceder 300 caracteres.',
        'panel.consultation.cancel.errorBackend': 'El servidor rechazó la anulación: nota obligatoria de al menos 5 caracteres.',
        'panel.consultation.cancel.errorGeneric': 'Error al anular la consulta. Vuelve a intentarlo o contacta a la coordinación.',
    },
    'en': {
        'panel.consultation.cancel.title': 'Cancel consultation',
        'panel.consultation.cancel.subtitle': 'Reader',
        'panel.consultation.cancel.book': 'Book',
        'panel.consultation.cancel.description': 'This action will be notified to the reader. Please briefly indicate the reason for cancellation. The note is mandatory and will be recorded in the consultation history.',
        'panel.consultation.cancel.noteLabel': 'Cancellation reason',
        'panel.consultation.cancel.notePlaceholder': 'E.g.: Book temporarily unavailable, duplicate with another request, technical issue…',
        'panel.consultation.cancel.noteHint': 'Minimum 5 characters',
        'panel.consultation.cancel.backButton': 'Back',
        'panel.consultation.cancel.confirmButton': 'Confirm cancellation',
        'panel.consultation.cancel.submitting': 'Cancelling…',
        'panel.consultation.cancel.errorNoteTooShort': 'The note must be at least 5 characters long.',
        'panel.consultation.cancel.errorNoteTooLong': 'The note cannot exceed 300 characters.',
        'panel.consultation.cancel.errorBackend': 'Server rejected the cancellation: mandatory note of at least 5 characters.',
        'panel.consultation.cancel.errorGeneric': 'Error cancelling the consultation. Please try again or contact the coordination.',
    },
    'it': {
        'panel.consultation.cancel.title': 'Annulla consultazione',
        'panel.consultation.cancel.subtitle': 'Lettor*',
        'panel.consultation.cancel.book': 'Libro',
        'panel.consultation.cancel.description': 'Questa azione sarà notificata al·la lettor*. Indica brevemente il motivo dell\'annullamento. La nota è obbligatoria e sarà registrata nella cronologia della consultazione.',
        'panel.consultation.cancel.noteLabel': 'Motivo dell\'annullamento',
        'panel.consultation.cancel.notePlaceholder': 'Es.: Libro temporaneamente non disponibile, duplicato con un\'altra richiesta, problema tecnico…',
        'panel.consultation.cancel.noteHint': 'Minimo 5 caratteri',
        'panel.consultation.cancel.backButton': 'Indietro',
        'panel.consultation.cancel.confirmButton': 'Conferma annullamento',
        'panel.consultation.cancel.submitting': 'Annullamento…',
        'panel.consultation.cancel.errorNoteTooShort': 'La nota deve contenere almeno 5 caratteri.',
        'panel.consultation.cancel.errorNoteTooLong': 'La nota non può superare i 300 caratteri.',
        'panel.consultation.cancel.errorBackend': 'Il server ha rifiutato l\'annullamento: nota obbligatoria di almeno 5 caratteri.',
        'panel.consultation.cancel.errorGeneric': 'Errore durante l\'annullamento. Riprova o contatta la coordinazione.',
    },
    'de': {
        'panel.consultation.cancel.title': 'Konsultation absagen',
        'panel.consultation.cancel.subtitle': 'Leser*in',
        'panel.consultation.cancel.book': 'Buch',
        'panel.consultation.cancel.description': 'Diese Aktion wird der*dem Leser*in mitgeteilt. Gib bitte kurz den Grund der Absage an. Die Notiz ist obligatorisch und wird im Verlauf der Konsultation gespeichert.',
        'panel.consultation.cancel.noteLabel': 'Grund der Absage',
        'panel.consultation.cancel.notePlaceholder': 'Z. B.: Buch vorübergehend nicht verfügbar, Duplikat mit einer anderen Anfrage, technisches Problem…',
        'panel.consultation.cancel.noteHint': 'Mindestens 5 Zeichen',
        'panel.consultation.cancel.backButton': 'Zurück',
        'panel.consultation.cancel.confirmButton': 'Absage bestätigen',
        'panel.consultation.cancel.submitting': 'Wird abgesagt…',
        'panel.consultation.cancel.errorNoteTooShort': 'Die Notiz muss mindestens 5 Zeichen lang sein.',
        'panel.consultation.cancel.errorNoteTooLong': 'Die Notiz darf 300 Zeichen nicht überschreiten.',
        'panel.consultation.cancel.errorBackend': 'Der Server hat die Absage abgelehnt: obligatorische Notiz von mindestens 5 Zeichen.',
        'panel.consultation.cancel.errorGeneric': 'Fehler beim Absagen der Konsultation. Versuche es erneut oder wende dich an die Koordination.',
    },
}

# Clé i18n à supprimer (obsolète depuis le patch frontend)
OBSOLETE_KEYS = [
    'panel.consultation.cancelledByPanel',
]


# ============================================================
# Logique d'injection
# ============================================================

def main():
    print(f"===== Injection i18n B6 =====")
    print(f"I18N dir : {I18N_DIR}\n")
    
    if not I18N_DIR.exists():
        print(f"[FATAL] Dossier i18n introuvable : {I18N_DIR}")
        sys.exit(1)
    
    total_added = 0
    total_removed = 0
    total_already_present = 0
    
    for locale in LOCALES:
        locale_file = I18N_DIR / f"{locale}.json"
        if not locale_file.exists():
            print(f"[FATAL] Fichier locale introuvable : {locale_file}")
            sys.exit(1)
        
        print(f"--- {locale} ---")
        
        # Lecture
        with open(locale_file, 'r', encoding='utf-8') as f:
            data = json.load(f)
        
        # Injection
        keys_for_locale = KEYS[locale]
        added_count = 0
        already_count = 0
        
        for key, value in keys_for_locale.items():
            if key in data:
                if data[key] == value:
                    already_count += 1
                else:
                    print(f"  WARN : cle {key} existe avec valeur differente, ecrasee")
                    data[key] = value
                    added_count += 1
            else:
                data[key] = value
                added_count += 1
        
        # Suppression des cles obsoletes
        removed_count = 0
        for obsolete in OBSOLETE_KEYS:
            if obsolete in data:
                del data[obsolete]
                removed_count += 1
        
        # Ecriture (tri alphabetique des cles pour stabilite)
        with open(locale_file, 'w', encoding='utf-8') as f:
            json.dump(dict(sorted(data.items())), f, ensure_ascii=False, indent=2)
            f.write('\n')  # newline final
        
        print(f"  Ajoutees : {added_count}, deja presentes : {already_count}, obsoletes supprimees : {removed_count}")
        total_added += added_count
        total_already_present += already_count
        total_removed += removed_count
    
    print(f"\n===== Total =====")
    print(f"Cles ajoutees     : {total_added}")
    print(f"Deja presentes    : {total_already_present}")
    print(f"Obsoletes virees  : {total_removed}")
    print(f"\nProchaine etape : npm run build pour valider")


if __name__ == "__main__":
    main()
