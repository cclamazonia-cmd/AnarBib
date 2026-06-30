#!/usr/bin/env node
/* Clés i18n front du dépôt de garantie (DEPOT-*).
 * Surface 1 — config par biblio (BibliotecaPage) + scope + statuts partagés.
 * Append textuel, parité stricte 10 locales, idempotent (DOC-PS-1 / DOC-I18N-1).
 * Les surfaces suivantes (flux d'emprunt, /conta, rapports, erreurs codées)
 * ajouteront leurs clés au même fichier en ré-exécutant ce script enrichi. */
const fs = require('fs');
const path = require('path');

const dir = path.join(__dirname, '..', 'src', 'i18n', 'locales');

// key -> { locale: value } ; 10 locales obligatoires.
const KEYS = {
  'deposit.config.title': {
    'pt-BR': 'Caução (depósito de garantia)', fr: 'Dépôt de garantie', es: 'Depósito de garantía',
    en: 'Security deposit', it: 'Cauzione', de: 'Kaution', ca: 'Dipòsit de garantia',
    eo: 'Garantia depono', nl: 'Waarborg', el: 'Εγγύηση',
  },
  'deposit.config.hint': {
    'pt-BR': 'Opcional, por biblioteca: uma caução reembolsável cobrada no empréstimo e devolvida na entrega da obra.',
    fr: "Optionnel, par biblio : une caution remboursable perçue à l'emprunt et restituée au retour de l'ouvrage.",
    es: 'Opcional, por biblioteca: un depósito reembolsable cobrado en el préstamo y devuelto al devolver la obra.',
    en: 'Optional, per library: a refundable deposit collected at loan time and returned when the item comes back.',
    it: 'Opzionale, per biblioteca: una cauzione rimborsabile riscossa al prestito e restituita alla riconsegna.',
    de: 'Optional, pro Bibliothek: eine erstattbare Kaution, die bei der Ausleihe erhoben und bei Rückgabe zurückgegeben wird.',
    ca: "Opcional, per biblioteca: un dipòsit reemborsable cobrat en el préstec i retornat en tornar l'obra.",
    eo: 'Nedeviga, laŭ biblioteko: repagebla depono kolektita je la prunto kaj redonita je la repreno de la verko.',
    nl: 'Optioneel, per bibliotheek: een terugbetaalbare waarborg die bij de uitlening wordt geïnd en bij teruggave wordt terugbetaald.',
    el: 'Προαιρετικό, ανά βιβλιοθήκη: μια επιστρεπτέα εγγύηση που εισπράττεται κατά τον δανεισμό και επιστρέφεται κατά την επιστροφή.',
  },
  'deposit.config.enabled': {
    'pt-BR': 'Ativar a caução', fr: 'Activer le dépôt de garantie', es: 'Activar el depósito de garantía',
    en: 'Enable the security deposit', it: 'Attivare la cauzione', de: 'Kaution aktivieren',
    ca: 'Activar el dipòsit de garantia', eo: 'Ŝalti la garantian deponon', nl: 'Waarborg inschakelen',
    el: 'Ενεργοποίηση της εγγύησης',
  },
  'deposit.config.enabledHint': {
    'pt-BR': 'Uma caução é pedida no empréstimo e devolvida na entrega.',
    fr: "Une caution est demandée à l'emprunt et restituée au retour.",
    es: 'Se pide un depósito en el préstamo y se devuelve al devolver.',
    en: 'A deposit is requested at loan time and returned on item return.',
    it: 'Una cauzione è richiesta al prestito e restituita alla riconsegna.',
    de: 'Bei der Ausleihe wird eine Kaution verlangt und bei Rückgabe zurückerstattet.',
    ca: 'Es demana un dipòsit en el préstec i es retorna en tornar.',
    eo: 'Depono estas petata je la prunto kaj redonita je la repreno.',
    nl: 'Bij de uitlening wordt een waarborg gevraagd en bij teruggave terugbetaald.',
    el: 'Ζητείται εγγύηση κατά τον δανεισμό και επιστρέφεται κατά την επιστροφή.',
  },
  'deposit.config.disabledHint': {
    'pt-BR': 'Desativado: nenhuma caução é pedida.', fr: "Désactivé : aucune caution n'est demandée.",
    es: 'Desactivado: no se pide ningún depósito.', en: 'Disabled: no deposit is requested.',
    it: 'Disattivato: nessuna cauzione è richiesta.', de: 'Deaktiviert: keine Kaution wird verlangt.',
    ca: 'Desactivat: no es demana cap dipòsit.', eo: 'Malŝaltita: neniu depono estas petata.',
    nl: 'Uitgeschakeld: er wordt geen waarborg gevraagd.', el: 'Απενεργοποιημένο: δεν ζητείται εγγύηση.',
  },
  'deposit.config.msg.enabledOn': {
    'pt-BR': 'Caução ativada.', fr: 'Dépôt de garantie activé.', es: 'Depósito de garantía activado.',
    en: 'Security deposit enabled.', it: 'Cauzione attivata.', de: 'Kaution aktiviert.',
    ca: 'Dipòsit de garantia activat.', eo: 'Garantia depono ŝaltita.', nl: 'Waarborg ingeschakeld.',
    el: 'Η εγγύηση ενεργοποιήθηκε.',
  },
  'deposit.config.msg.enabledOff': {
    'pt-BR': 'Caução desativada.', fr: 'Dépôt de garantie désactivé.', es: 'Depósito de garantía desactivado.',
    en: 'Security deposit disabled.', it: 'Cauzione disattivata.', de: 'Kaution deaktiviert.',
    ca: 'Dipòsit de garantia desactivat.', eo: 'Garantia depono malŝaltita.', nl: 'Waarborg uitgeschakeld.',
    el: 'Η εγγύηση απενεργοποιήθηκε.',
  },
  'deposit.config.rules.title': {
    'pt-BR': 'Regras de caução', fr: 'Règles de dépôt', es: 'Reglas de depósito',
    en: 'Deposit rules', it: 'Regole di cauzione', de: 'Kautionsregeln',
    ca: 'Regles de dipòsit', eo: 'Reguloj de depono', nl: 'Waarborgregels', el: 'Κανόνες εγγύησης',
  },
  'deposit.config.rules.add': {
    'pt-BR': 'Adicionar uma regra', fr: 'Ajouter une règle', es: 'Añadir una regla',
    en: 'Add a rule', it: 'Aggiungi una regola', de: 'Regel hinzufügen',
    ca: 'Afegir una regla', eo: 'Aldoni regulon', nl: 'Regel toevoegen', el: 'Προσθήκη κανόνα',
  },
  'deposit.config.rules.empty': {
    'pt-BR': 'Nenhuma regra de caução. Adicione uma para começar.',
    fr: 'Aucune règle de dépôt. Ajoutes-en une pour commencer.',
    es: 'Ninguna regla de depósito. Añade una para empezar.',
    en: 'No deposit rules. Add one to get started.',
    it: 'Nessuna regola di cauzione. Aggiungine una per iniziare.',
    de: 'Keine Kautionsregeln. Füge eine hinzu, um zu beginnen.',
    ca: 'Cap regla de dipòsit. Afegeix-ne una per començar.',
    eo: 'Neniu regulo de depono. Aldonu unu por komenci.',
    nl: 'Geen waarborgregels. Voeg er een toe om te beginnen.',
    el: 'Κανένας κανόνας εγγύησης. Προσθέστε έναν για να ξεκινήσετε.',
  },
  'deposit.config.rule.name': {
    'pt-BR': 'Nome', fr: 'Nom', es: 'Nombre', en: 'Name', it: 'Nome', de: 'Name',
    ca: 'Nom', eo: 'Nomo', nl: 'Naam', el: 'Όνομα',
  },
  'deposit.config.rule.namePlaceholder': {
    'pt-BR': 'ex. Caução padrão', fr: 'ex. Caution standard', es: 'ej. Depósito estándar',
    en: 'e.g. Standard deposit', it: 'es. Cauzione standard', de: 'z. B. Standardkaution',
    ca: 'p. ex. Dipòsit estàndard', eo: 'ekz. Norma depono', nl: 'bijv. Standaardwaarborg',
    el: 'π.χ. Τυπική εγγύηση',
  },
  'deposit.config.rule.description': {
    'pt-BR': 'Descrição', fr: 'Description', es: 'Descripción', en: 'Description', it: 'Descrizione',
    de: 'Beschreibung', ca: 'Descripció', eo: 'Priskribo', nl: 'Omschrijving', el: 'Περιγραφή',
  },
  'deposit.config.rule.descriptionPlaceholder': {
    'pt-BR': 'ex. 3 € devolvidos na entrega', fr: 'ex. 3 € remboursés au retour',
    es: 'ej. 3 € devueltos al devolver', en: 'e.g. €3 refunded on return',
    it: 'es. 3 € rimborsati alla riconsegna', de: 'z. B. 3 € bei Rückgabe erstattet',
    ca: 'p. ex. 3 € retornats en tornar', eo: 'ekz. 3 € redonitaj je la repreno',
    nl: 'bijv. € 3 terugbetaald bij teruggave', el: 'π.χ. 3 € επιστρέφονται κατά την επιστροφή',
  },
  'deposit.config.rule.scope': {
    'pt-BR': 'Abrangência', fr: 'Portée', es: 'Alcance', en: 'Scope', it: 'Ambito', de: 'Geltung',
    ca: 'Abast', eo: 'Amplekso', nl: 'Bereik', el: 'Εμβέλεια',
  },
  'deposit.config.rule.amount': {
    'pt-BR': 'Valor', fr: 'Montant', es: 'Importe', en: 'Amount', it: 'Importo', de: 'Betrag',
    ca: 'Import', eo: 'Sumo', nl: 'Bedrag', el: 'Ποσό',
  },
  'deposit.config.rule.currency': {
    'pt-BR': 'Moeda', fr: 'Devise', es: 'Moneda', en: 'Currency', it: 'Valuta', de: 'Währung',
    ca: 'Moneda', eo: 'Valuto', nl: 'Munt', el: 'Νόμισμα',
  },
  'deposit.config.rule.isActive': {
    'pt-BR': 'Regra ativa', fr: 'Règle active', es: 'Regla activa', en: 'Active rule',
    it: 'Regola attiva', de: 'Aktive Regel', ca: 'Regla activa', eo: 'Aktiva regulo',
    nl: 'Actieve regel', el: 'Ενεργός κανόνας',
  },
  'deposit.config.msg.amountRequired': {
    'pt-BR': 'O valor deve ser positivo ou zero.', fr: 'Le montant doit être positif ou nul.',
    es: 'El importe debe ser positivo o cero.', en: 'The amount must be zero or positive.',
    it: "L'importo deve essere positivo o zero.", de: 'Der Betrag muss null oder positiv sein.',
    ca: "L'import ha de ser positiu o zero.", eo: 'La sumo devas esti nula aŭ pozitiva.',
    nl: 'Het bedrag moet nul of positief zijn.', el: 'Το ποσό πρέπει να είναι μηδέν ή θετικό.',
  },
  'deposit.config.msg.created': {
    'pt-BR': 'Regra de caução criada.', fr: 'Règle de dépôt créée.', es: 'Regla de depósito creada.',
    en: 'Deposit rule created.', it: 'Regola di cauzione creata.', de: 'Kautionsregel erstellt.',
    ca: 'Regla de dipòsit creada.', eo: 'Regulo de depono kreita.', nl: 'Waarborgregel aangemaakt.',
    el: 'Ο κανόνας εγγύησης δημιουργήθηκε.',
  },
  'deposit.config.msg.saved': {
    'pt-BR': 'Regra de caução salva.', fr: 'Règle de dépôt enregistrée.', es: 'Regla de depósito guardada.',
    en: 'Deposit rule saved.', it: 'Regola di cauzione salvata.', de: 'Kautionsregel gespeichert.',
    ca: 'Regla de dipòsit desada.', eo: 'Regulo de depono konservita.', nl: 'Waarborgregel opgeslagen.',
    el: 'Ο κανόνας εγγύησης αποθηκεύτηκε.',
  },
  'deposit.config.msg.deactivated': {
    'pt-BR': 'Regra desativada.', fr: 'Règle désactivée.', es: 'Regla desactivada.',
    en: 'Rule deactivated.', it: 'Regola disattivata.', de: 'Regel deaktiviert.',
    ca: 'Regla desactivada.', eo: 'Regulo malaktivigita.', nl: 'Regel gedeactiveerd.',
    el: 'Ο κανόνας απενεργοποιήθηκε.',
  },
  'deposit.config.msg.reactivated': {
    'pt-BR': 'Regra reativada.', fr: 'Règle réactivée.', es: 'Regla reactivada.',
    en: 'Rule reactivated.', it: 'Regola riattivata.', de: 'Regel reaktiviert.',
    ca: 'Regla reactivada.', eo: 'Regulo reaktivigita.', nl: 'Regel heractiveerd.',
    el: 'Ο κανόνας επανενεργοποιήθηκε.',
  },
  'deposit.config.msg.deleted': {
    'pt-BR': 'Regra excluída.', fr: 'Règle supprimée.', es: 'Regla eliminada.',
    en: 'Rule deleted.', it: 'Regola eliminata.', de: 'Regel gelöscht.',
    ca: 'Regla suprimida.', eo: 'Regulo forigita.', nl: 'Regel verwijderd.',
    el: 'Ο κανόνας διαγράφηκε.',
  },
  'deposit.config.action.save': {
    'pt-BR': 'Salvar', fr: 'Enregistrer', es: 'Guardar', en: 'Save', it: 'Salva', de: 'Speichern',
    ca: 'Desar', eo: 'Konservi', nl: 'Opslaan', el: 'Αποθήκευση',
  },
  'deposit.config.action.cancel': {
    'pt-BR': 'Cancelar', fr: 'Annuler', es: 'Cancelar', en: 'Cancel', it: 'Annulla', de: 'Abbrechen',
    ca: 'Cancel·lar', eo: 'Nuligi', nl: 'Annuleren', el: 'Ακύρωση',
  },
  'deposit.config.action.edit': {
    'pt-BR': 'Editar', fr: 'Modifier', es: 'Editar', en: 'Edit', it: 'Modifica', de: 'Bearbeiten',
    ca: 'Editar', eo: 'Redakti', nl: 'Bewerken', el: 'Επεξεργασία',
  },
  'deposit.config.action.deactivate': {
    'pt-BR': 'Desativar', fr: 'Désactiver', es: 'Desactivar', en: 'Deactivate', it: 'Disattiva',
    de: 'Deaktivieren', ca: 'Desactivar', eo: 'Malaktivigi', nl: 'Deactiveren', el: 'Απενεργοποίηση',
  },
  'deposit.config.action.reactivate': {
    'pt-BR': 'Reativar', fr: 'Réactiver', es: 'Reactivar', en: 'Reactivate', it: 'Riattiva',
    de: 'Reaktivieren', ca: 'Reactivar', eo: 'Reaktivigi', nl: 'Heractiveren', el: 'Επανενεργοποίηση',
  },
  'deposit.config.action.deactivateConfirm': {
    'pt-BR': 'Desativar esta regra de caução?', fr: 'Désactiver cette règle de dépôt ?',
    es: '¿Desactivar esta regla de depósito?', en: 'Deactivate this deposit rule?',
    it: 'Disattivare questa regola di cauzione?', de: 'Diese Kautionsregel deaktivieren?',
    ca: 'Voleu desactivar aquesta regla de dipòsit?', eo: 'Ĉu malaktivigi ĉi tiun regulon de depono?',
    nl: 'Deze waarborgregel deactiveren?', el: 'Απενεργοποίηση αυτού του κανόνα εγγύησης;',
  },
  'deposit.config.action.delete': {
    'pt-BR': 'Excluir', fr: 'Supprimer', es: 'Eliminar', en: 'Delete', it: 'Elimina', de: 'Löschen',
    ca: 'Suprimir', eo: 'Forigi', nl: 'Verwijderen', el: 'Διαγραφή',
  },
  'deposit.config.action.deleteConfirm': {
    'pt-BR': 'Excluir definitivamente a regra « {name} »?',
    fr: 'Supprimer définitivement la règle « {name} » ?',
    es: '¿Eliminar definitivamente la regla « {name} »?',
    en: 'Permanently delete the rule "{name}"?',
    it: 'Eliminare definitivamente la regola « {name} »?',
    de: 'Die Regel „{name}“ endgültig löschen?',
    ca: 'Voleu suprimir definitivament la regla « {name} »?',
    eo: 'Ĉu forigi definitive la regulon « {name} »?',
    nl: 'De regel “{name}” definitief verwijderen?',
    el: 'Οριστική διαγραφή του κανόνα « {name} »;',
  },
  'deposit.scope.per_loan': {
    'pt-BR': 'Por empréstimo', fr: 'Par emprunt', es: 'Por préstamo', en: 'Per loan',
    it: 'Per prestito', de: 'Pro Ausleihe', ca: 'Per préstec', eo: 'Po prunto',
    nl: 'Per uitlening', el: 'Ανά δανεισμό',
  },
  'deposit.scope.per_item': {
    'pt-BR': 'Por obra', fr: 'Par livre', es: 'Por obra', en: 'Per item',
    it: 'Per opera', de: 'Pro Werk', ca: 'Per obra', eo: 'Po verko',
    nl: 'Per werk', el: 'Ανά τεκμήριο',
  },
  'deposit.rule.amount': {
    'pt-BR': '{amount} {currency}', fr: '{amount} {currency}', es: '{amount} {currency}',
    en: '{amount} {currency}', it: '{amount} {currency}', de: '{amount} {currency}',
    ca: '{amount} {currency}', eo: '{amount} {currency}', nl: '{amount} {currency}',
    el: '{amount} {currency}',
  },
  'deposit.status.detenu': {
    'pt-BR': 'Retida', fr: 'Détenu', es: 'Retenido', en: 'Held', it: 'Trattenuta', de: 'Einbehalten',
    ca: 'Retingut', eo: 'Tenata', nl: 'Aangehouden', el: 'Παρακρατείται',
  },
  'deposit.status.rembourse': {
    'pt-BR': 'Devolvida', fr: 'Remboursé', es: 'Devuelto', en: 'Refunded', it: 'Restituita',
    de: 'Erstattet', ca: 'Retornat', eo: 'Redonita', nl: 'Terugbetaald', el: 'Επιστράφηκε',
  },
  'deposit.status.retenu': {
    'pt-BR': 'Retida (perda/dano)', fr: 'Retenu', es: 'Retenido (pérdida/daño)', en: 'Withheld',
    it: 'Trattenuta (perdita/danno)', de: 'Einbehalten (Verlust/Schaden)', ca: 'Retingut',
    eo: 'Retenita', nl: 'Ingehouden', el: 'Παρακρατήθηκε',
  },
  'deposit.status.partiel': {
    'pt-BR': 'Parcial', fr: 'Partiel', es: 'Parcial', en: 'Partial', it: 'Parziale', de: 'Teilweise',
    ca: 'Parcial', eo: 'Parta', nl: 'Gedeeltelijk', el: 'Μερική',
  },

  // ── Surface 2 — encart au comptoir (LoanDepositPanel) ──
  'deposit.panel.title': {
    'pt-BR': 'Caução', fr: 'Dépôt de garantie', es: 'Depósito de garantía', en: 'Security deposit',
    it: 'Cauzione', de: 'Kaution', ca: 'Dipòsit de garantia', eo: 'Garantia depono', nl: 'Waarborg', el: 'Εγγύηση',
  },
  'deposit.panel.heldLabel': {
    'pt-BR': 'Caução retida', fr: 'Dépôt détenu', es: 'Depósito retenido', en: 'Deposit held',
    it: 'Cauzione trattenuta', de: 'Kaution einbehalten', ca: 'Dipòsit retingut', eo: 'Tenata depono',
    nl: 'Waarborg aangehouden', el: 'Παρακρατούμενη εγγύηση',
  },
  'deposit.panel.amount': {
    'pt-BR': 'Valor', fr: 'Montant', es: 'Importe', en: 'Amount', it: 'Importo', de: 'Betrag',
    ca: 'Import', eo: 'Sumo', nl: 'Bedrag', el: 'Ποσό',
  },
  'deposit.panel.method': {
    'pt-BR': 'Método', fr: 'Méthode', es: 'Método', en: 'Method', it: 'Metodo', de: 'Methode',
    ca: 'Mètode', eo: 'Metodo', nl: 'Methode', el: 'Μέθοδος',
  },
  'deposit.panel.collectCta': {
    'pt-BR': 'Registrar caução', fr: 'Collecter le dépôt', es: 'Cobrar el depósito', en: 'Collect deposit',
    it: 'Riscuoti cauzione', de: 'Kaution einnehmen', ca: 'Cobrar el dipòsit', eo: 'Kolekti deponon',
    nl: 'Waarborg innen', el: 'Είσπραξη εγγύησης',
  },
  'deposit.panel.refundCta': {
    'pt-BR': 'Devolver', fr: 'Rembourser', es: 'Devolver', en: 'Refund', it: 'Rimborsa', de: 'Erstatten',
    ca: 'Retornar', eo: 'Redoni', nl: 'Terugbetalen', el: 'Επιστροφή',
  },
  'deposit.panel.retainCta': {
    'pt-BR': 'Reter', fr: 'Retenir', es: 'Retener', en: 'Withhold', it: 'Trattieni', de: 'Einbehalten',
    ca: 'Retenir', eo: 'Reteni', nl: 'Inhouden', el: 'Παρακράτηση',
  },
  'deposit.panel.retainReasonPrompt': {
    'pt-BR': 'Motivo da retenção (perda, dano…):', fr: 'Motif de la rétention (perte, dégât…) :',
    es: 'Motivo de la retención (pérdida, daño…):', en: 'Reason for withholding (loss, damage…):',
    it: 'Motivo della trattenuta (perdita, danno…):', de: 'Grund für die Einbehaltung (Verlust, Schaden …):',
    ca: 'Motiu de la retenció (pèrdua, dany…):', eo: 'Kialo de la reteno (perdo, damaĝo…):',
    nl: 'Reden voor inhouding (verlies, schade…):', el: 'Λόγος παρακράτησης (απώλεια, ζημιά…):',
  },
  'deposit.panel.noActiveRule': {
    'pt-BR': 'Ative uma regra de caução para cobrar um depósito.',
    fr: 'Activez une règle de dépôt pour percevoir une caution.',
    es: 'Activa una regla de depósito para cobrar una caución.',
    en: 'Add an active deposit rule to collect a deposit.',
    it: 'Attiva una regola di cauzione per riscuotere un deposito.',
    de: 'Aktiviere eine Kautionsregel, um eine Kaution einzunehmen.',
    ca: 'Activa una regla de dipòsit per cobrar una caució.',
    eo: 'Aktivigu regulon de depono por kolekti deponon.',
    nl: 'Activeer een waarborgregel om een waarborg te innen.',
    el: 'Ενεργοποιήστε έναν κανόνα εγγύησης για να εισπράξετε εγγύηση.',
  },
  'deposit.panel.msg.collected': {
    'pt-BR': 'Caução registrada.', fr: 'Dépôt collecté.', es: 'Depósito cobrado.', en: 'Deposit collected.',
    it: 'Cauzione riscossa.', de: 'Kaution eingenommen.', ca: 'Dipòsit cobrat.', eo: 'Depono kolektita.',
    nl: 'Waarborg geïnd.', el: 'Η εγγύηση εισπράχθηκε.',
  },
  'deposit.panel.msg.refunded': {
    'pt-BR': 'Caução devolvida.', fr: 'Dépôt remboursé.', es: 'Depósito devuelto.', en: 'Deposit refunded.',
    it: 'Cauzione rimborsata.', de: 'Kaution erstattet.', ca: 'Dipòsit retornat.', eo: 'Depono redonita.',
    nl: 'Waarborg terugbetaald.', el: 'Η εγγύηση επιστράφηκε.',
  },
  'deposit.panel.msg.retained': {
    'pt-BR': 'Caução retida.', fr: 'Dépôt retenu.', es: 'Depósito retenido.', en: 'Deposit withheld.',
    it: 'Cauzione trattenuta.', de: 'Kaution einbehalten.', ca: 'Dipòsit retingut.', eo: 'Depono retenita.',
    nl: 'Waarborg ingehouden.', el: 'Η εγγύηση παρακρατήθηκε.',
  },

  // ── Erreurs codées des fonctions dépôt (panel.apiError.<code>) ──
  'panel.apiError.painel_access_required': {
    'pt-BR': 'Acesso bibliotecário obrigatório.', fr: 'Accès bibliothécaire requis.',
    es: 'Se requiere acceso bibliotecario.', en: 'Library staff access required.',
    it: 'Accesso bibliotecario richiesto.', de: 'Bibliothekszugang erforderlich.',
    ca: 'Cal accés bibliotecari.', eo: 'Biblioteka aliro bezonata.',
    nl: 'Bibliotheektoegang vereist.', el: 'Απαιτείται πρόσβαση προσωπικού βιβλιοθήκης.',
  },
  'panel.apiError.emprestimo_not_found': {
    'pt-BR': 'Empréstimo não encontrado.', fr: 'Emprunt introuvable.', es: 'Préstamo no encontrado.',
    en: 'Loan not found.', it: 'Prestito non trovato.', de: 'Ausleihe nicht gefunden.',
    ca: 'Préstec no trobat.', eo: 'Prunto ne trovita.', nl: 'Uitlening niet gevonden.',
    el: 'Ο δανεισμός δεν βρέθηκε.',
  },
  'panel.apiError.not_staff_of_loan_library': {
    'pt-BR': 'Você não é da equipe da biblioteca deste empréstimo.',
    fr: "Tu n'es pas du staff de la bibliothèque de cet emprunt.",
    es: 'No eres del personal de la biblioteca de este préstamo.',
    en: "You are not staff of this loan's library.",
    it: 'Non fai parte dello staff della biblioteca di questo prestito.',
    de: 'Du gehörst nicht zum Team der Bibliothek dieser Ausleihe.',
    ca: "No ets del personal de la biblioteca d'aquest préstec.",
    eo: 'Vi ne estas el la stabo de la biblioteko de ĉi tiu prunto.',
    nl: 'Je hoort niet bij het team van de bibliotheek van deze uitlening.',
    el: 'Δεν ανήκεις στο προσωπικό της βιβλιοθήκης αυτού του δανεισμού.',
  },
  'panel.apiError.item_not_in_loan': {
    'pt-BR': 'Este exemplar não pertence ao empréstimo.', fr: "Cet exemplaire n'appartient pas à l'emprunt.",
    es: 'Este ejemplar no pertenece al préstamo.', en: 'This item does not belong to the loan.',
    it: 'Questa copia non appartiene al prestito.', de: 'Dieses Exemplar gehört nicht zur Ausleihe.',
    ca: "Aquest exemplar no pertany al préstec.", eo: 'Ĉi tiu ekzemplero ne apartenas al la prunto.',
    nl: 'Dit exemplaar hoort niet bij de uitlening.', el: 'Αυτό το αντίτυπο δεν ανήκει στον δανεισμό.',
  },
  'panel.apiError.deposit_already_held': {
    'pt-BR': 'Já há uma caução retida para este empréstimo.', fr: 'Un dépôt est déjà détenu pour cet emprunt.',
    es: 'Ya hay un depósito retenido para este préstamo.', en: 'A deposit is already held for this loan.',
    it: 'Esiste già una cauzione trattenuta per questo prestito.', de: 'Für diese Ausleihe wird bereits eine Kaution gehalten.',
    ca: 'Ja hi ha un dipòsit retingut per a aquest préstec.', eo: 'Jam estas tenata depono por ĉi tiu prunto.',
    nl: 'Er wordt al een waarborg aangehouden voor deze uitlening.', el: 'Υπάρχει ήδη παρακρατούμενη εγγύηση για αυτόν τον δανεισμό.',
  },
  'panel.apiError.deposit_rule_not_found': {
    'pt-BR': 'Regra de caução não encontrada.', fr: 'Règle de dépôt introuvable.',
    es: 'Regla de depósito no encontrada.', en: 'Deposit rule not found.',
    it: 'Regola di cauzione non trovata.', de: 'Kautionsregel nicht gefunden.',
    ca: 'Regla de dipòsit no trobada.', eo: 'Regulo de depono ne trovita.',
    nl: 'Waarborgregel niet gevonden.', el: 'Ο κανόνας εγγύησης δεν βρέθηκε.',
  },
  'panel.apiError.deposit_rule_other_library': {
    'pt-BR': 'Esta regra de caução é de outra biblioteca.',
    fr: 'Cette règle de dépôt appartient à une autre bibliothèque.',
    es: 'Esta regla de depósito es de otra biblioteca.', en: 'This deposit rule belongs to another library.',
    it: "Questa regola di cauzione appartiene a un'altra biblioteca.",
    de: 'Diese Kautionsregel gehört zu einer anderen Bibliothek.',
    ca: "Aquesta regla de dipòsit és d'una altra biblioteca.",
    eo: 'Ĉi tiu regulo de depono apartenas al alia biblioteko.',
    nl: 'Deze waarborgregel hoort bij een andere bibliotheek.',
    el: 'Αυτός ο κανόνας εγγύησης ανήκει σε άλλη βιβλιοθήκη.',
  },
  'panel.apiError.deposit_rule_inactive': {
    'pt-BR': 'Esta regra de caução está desativada.', fr: 'Cette règle de dépôt est désactivée.',
    es: 'Esta regla de depósito está desactivada.', en: 'This deposit rule is inactive.',
    it: 'Questa regola di cauzione è disattivata.', de: 'Diese Kautionsregel ist deaktiviert.',
    ca: 'Aquesta regla de dipòsit està desactivada.', eo: 'Ĉi tiu regulo de depono estas malaktiva.',
    nl: 'Deze waarborgregel is uitgeschakeld.', el: 'Αυτός ο κανόνας εγγύησης είναι ανενεργός.',
  },
  'panel.apiError.amount_required': {
    'pt-BR': 'É necessário um valor.', fr: 'Un montant est requis.', es: 'Se requiere un importe.',
    en: 'An amount is required.', it: 'È richiesto un importo.', de: 'Ein Betrag ist erforderlich.',
    ca: 'Cal un import.', eo: 'Sumo estas bezonata.', nl: 'Een bedrag is vereist.', el: 'Απαιτείται ποσό.',
  },
  'panel.apiError.amount_must_be_positive': {
    'pt-BR': 'O valor deve ser positivo (ou use « isenção »).',
    fr: 'Le montant doit être positif (ou utilise « exonération »).',
    es: 'El importe debe ser positivo (o usa « exención »).', en: 'The amount must be positive (or use "exemption").',
    it: "L'importo deve essere positivo (o usa « esenzione »).", de: 'Der Betrag muss positiv sein (oder „Befreiung" verwenden).',
    ca: "L'import ha de ser positiu (o usa « exempció »).", eo: 'La sumo devas esti pozitiva (aŭ uzu « sendevigo »).',
    nl: 'Het bedrag moet positief zijn (of gebruik "vrijstelling").', el: 'Το ποσό πρέπει να είναι θετικό (ή χρησιμοποιήστε «απαλλαγή»).',
  },
  'panel.apiError.deposit_not_found': {
    'pt-BR': 'Caução não encontrada.', fr: 'Dépôt introuvable.', es: 'Depósito no encontrado.',
    en: 'Deposit not found.', it: 'Cauzione non trovata.', de: 'Kaution nicht gefunden.',
    ca: 'Dipòsit no trobat.', eo: 'Depono ne trovita.', nl: 'Waarborg niet gevonden.',
    el: 'Η εγγύηση δεν βρέθηκε.',
  },
  'panel.apiError.deposit_not_held': {
    'pt-BR': 'Esta caução já foi liquidada (devolvida ou retida).',
    fr: 'Ce dépôt est déjà soldé (remboursé ou retenu).',
    es: 'Este depósito ya está liquidado (devuelto o retenido).',
    en: 'This deposit is already settled (refunded or withheld).',
    it: 'Questa cauzione è già liquidata (rimborsata o trattenuta).',
    de: 'Diese Kaution ist bereits abgewickelt (erstattet oder einbehalten).',
    ca: 'Aquest dipòsit ja està liquidat (retornat o retingut).',
    eo: 'Ĉi tiu depono jam estas likvidita (redonita aŭ retenita).',
    nl: 'Deze waarborg is al afgewikkeld (terugbetaald of ingehouden).',
    el: 'Αυτή η εγγύηση έχει ήδη διευθετηθεί (επιστροφή ή παρακράτηση).',
  },
  'panel.apiError.refund_must_be_positive': {
    'pt-BR': 'O valor devolvido deve ser positivo (senão, use « reter »).',
    fr: 'Le montant remboursé doit être positif (sinon, utilise « retenir »).',
    es: 'El importe devuelto debe ser positivo (si no, usa « retener »).',
    en: 'The refunded amount must be positive (otherwise use "withhold").',
    it: "L'importo rimborsato deve essere positivo (altrimenti usa « trattieni »).",
    de: 'Der erstattete Betrag muss positiv sein (sonst „Einbehalten" verwenden).',
    ca: "L'import retornat ha de ser positiu (si no, usa « retenir »).",
    eo: 'La redonita sumo devas esti pozitiva (alie uzu « reteni »).',
    nl: 'Het terugbetaalde bedrag moet positief zijn (gebruik anders "inhouden").',
    el: 'Το επιστρεφόμενο ποσό πρέπει να είναι θετικό (αλλιώς «παρακράτηση»).',
  },
  'panel.apiError.refund_exceeds_amount': {
    'pt-BR': 'O reembolso excede o valor da caução.', fr: 'Le remboursement dépasse le montant du dépôt.',
    es: 'El reembolso supera el importe del depósito.', en: 'The refund exceeds the deposit amount.',
    it: "Il rimborso supera l'importo della cauzione.", de: 'Die Erstattung übersteigt den Kautionsbetrag.',
    ca: "El reemborsament supera l'import del dipòsit.", eo: 'La repago superas la sumon de la depono.',
    nl: 'De terugbetaling overschrijdt het waarborgbedrag.', el: 'Η επιστροφή υπερβαίνει το ποσό της εγγύησης.',
  },
  'panel.apiError.partial_refund_reason_required': {
    'pt-BR': 'Um reembolso parcial exige uma nota.', fr: 'Un remboursement partiel exige une note.',
    es: 'Un reembolso parcial requiere una nota.', en: 'A partial refund requires a note.',
    it: 'Un rimborso parziale richiede una nota.', de: 'Eine Teilerstattung erfordert eine Notiz.',
    ca: 'Un reemborsament parcial requereix una nota.', eo: 'Parta repago postulas noton.',
    nl: 'Een gedeeltelijke terugbetaling vereist een notitie.', el: 'Η μερική επιστροφή απαιτεί σημείωση.',
  },
  'panel.apiError.retention_reason_required': {
    'pt-BR': 'É necessário um motivo para reter a caução.', fr: 'Un motif est requis pour retenir le dépôt.',
    es: 'Se requiere un motivo para retener el depósito.', en: 'A reason is required to withhold the deposit.',
    it: 'È richiesto un motivo per trattenere la cauzione.', de: 'Ein Grund ist erforderlich, um die Kaution einzubehalten.',
    ca: 'Cal un motiu per retenir el dipòsit.', eo: 'Kialo estas bezonata por reteni la deponon.',
    nl: 'Een reden is vereist om de waarborg in te houden.', el: 'Απαιτείται λόγος για την παρακράτηση της εγγύησης.',
  },
  'panel.apiError.partial_refund_out_of_range': {
    'pt-BR': 'O reembolso parcial deve ser ≥ 0 e menor que o valor.',
    fr: 'Le remboursement partiel doit être ≥ 0 et inférieur au montant.',
    es: 'El reembolso parcial debe ser ≥ 0 y menor que el importe.',
    en: 'The partial refund must be ≥ 0 and less than the amount.',
    it: "Il rimborso parziale deve essere ≥ 0 e inferiore all'importo.",
    de: 'Die Teilerstattung muss ≥ 0 und kleiner als der Betrag sein.',
    ca: "El reemborsament parcial ha de ser ≥ 0 i inferior a l'import.",
    eo: 'La parta repago devas esti ≥ 0 kaj malpli ol la sumo.',
    nl: 'De gedeeltelijke terugbetaling moet ≥ 0 en kleiner dan het bedrag zijn.',
    el: 'Η μερική επιστροφή πρέπει να είναι ≥ 0 και μικρότερη από το ποσό.',
  },

  // ── Surface 3 — section /conta lectrice (AccountPage) ──
  'deposit.account.title': {
    'pt-BR': 'Caução', fr: 'Dépôt de garantie', es: 'Depósito de garantía', en: 'Security deposit',
    it: 'Cauzione', de: 'Kaution', ca: 'Dipòsit de garantia', eo: 'Garantia depono', nl: 'Waarborg', el: 'Εγγύηση',
  },
  'deposit.account.hint': {
    'pt-BR': 'Caução(ões) que você pagou, devolvida(s) na entrega da obra.',
    fr: "Caution(s) que tu as versée(s), restituée(s) au retour de l'ouvrage.",
    es: 'Depósito(s) que pagaste, devuelto(s) al devolver la obra.',
    en: 'Deposit(s) you have paid, returned when you bring the item back.',
    it: 'Cauzione/i che hai versato, restituita/e alla riconsegna.',
    de: 'Von dir hinterlegte Kaution(en), bei Rückgabe des Werks zurückerstattet.',
    ca: "Dipòsit(s) que has pagat, retornat(s) en tornar l'obra.",
    eo: 'Depono(j) kiun vi pagis, redonita(j) je la repreno de la verko.',
    nl: 'Waarborg(en) die je hebt betaald, terugbetaald bij teruggave.',
    el: 'Εγγύηση/εις που έχεις καταβάλει, επιστρέφεται κατά την επιστροφή του τεκμηρίου.',
  },

  // ── Surface 4 — rapports (FinanceReportsSection) ──
  'deposit.report.cotisTitle': {
    'pt-BR': 'Acompanhamento das contribuições', fr: 'Suivi des cotisations', es: 'Seguimiento de cuotas',
    en: 'Membership tracking', it: 'Monitoraggio dei contributi', de: 'Beitragsübersicht',
    ca: 'Seguiment de les quotes', eo: 'Spurado de kotizoj', nl: 'Overzicht bijdragen', el: 'Παρακολούθηση συνδρομών',
  },
  'deposit.report.depositsTitle': {
    'pt-BR': 'Acompanhamento das cauções', fr: 'Suivi des dépôts de garantie', es: 'Seguimiento de depósitos',
    en: 'Deposit tracking', it: 'Monitoraggio delle cauzioni', de: 'Kautionsübersicht',
    ca: 'Seguiment dels dipòsits', eo: 'Spurado de garantiaj deponoj', nl: 'Overzicht waarborgen', el: 'Παρακολούθηση εγγυήσεων',
  },
  'deposit.report.member': {
    'pt-BR': 'Membro', fr: 'Membre', es: 'Miembro', en: 'Member', it: 'Membro', de: 'Mitglied',
    ca: 'Membre', eo: 'Membro', nl: 'Lid', el: 'Μέλος',
  },
  'deposit.report.status': {
    'pt-BR': 'Estado', fr: 'Statut', es: 'Estado', en: 'Status', it: 'Stato', de: 'Status',
    ca: 'Estat', eo: 'Stato', nl: 'Status', el: 'Κατάσταση',
  },
  'deposit.report.dueDate': {
    'pt-BR': 'Vencimento', fr: 'Échéance', es: 'Vencimiento', en: 'Due date', it: 'Scadenza', de: 'Fällig am',
    ca: 'Venciment', eo: 'Limdato', nl: 'Vervaldatum', el: 'Λήξη',
  },
  'deposit.report.lastPayment': {
    'pt-BR': 'Último pagamento', fr: 'Dernier paiement', es: 'Último pago', en: 'Last payment',
    it: 'Ultimo pagamento', de: 'Letzte Zahlung', ca: 'Últim pagament', eo: 'Lasta pago',
    nl: 'Laatste betaling', el: 'Τελευταία πληρωμή',
  },
  'deposit.report.amount': {
    'pt-BR': 'Valor', fr: 'Montant', es: 'Importe', en: 'Amount', it: 'Importo', de: 'Betrag',
    ca: 'Import', eo: 'Sumo', nl: 'Bedrag', el: 'Ποσό',
  },
  'deposit.report.loan': {
    'pt-BR': 'Empréstimo', fr: 'Emprunt', es: 'Préstamo', en: 'Loan', it: 'Prestito', de: 'Ausleihe',
    ca: 'Préstec', eo: 'Prunto', nl: 'Uitlening', el: 'Δανεισμός',
  },
  'deposit.report.date': {
    'pt-BR': 'Data', fr: 'Date', es: 'Fecha', en: 'Date', it: 'Data', de: 'Datum',
    ca: 'Data', eo: 'Dato', nl: 'Datum', el: 'Ημερομηνία',
  },
  'deposit.report.exportCsv': {
    'pt-BR': 'Exportar CSV', fr: 'Exporter CSV', es: 'Exportar CSV', en: 'Export CSV', it: 'Esporta CSV',
    de: 'CSV exportieren', ca: 'Exportar CSV', eo: 'Eksporti CSV', nl: 'CSV exporteren', el: 'Εξαγωγή CSV',
  },
  'deposit.report.exportPdf': {
    'pt-BR': 'Exportar PDF', fr: 'Exporter PDF', es: 'Exportar PDF', en: 'Export PDF', it: 'Esporta PDF',
    de: 'PDF exportieren', ca: 'Exportar PDF', eo: 'Eksporti PDF', nl: 'PDF exporteren', el: 'Εξαγωγή PDF',
  },
  'deposit.report.heldTotal': {
    'pt-BR': 'Total retido (em custódia)', fr: 'Total détenu (en fiducie)', es: 'Total retenido (en custodia)',
    en: 'Total held (in trust)', it: 'Totale trattenuto (in custodia)', de: 'Einbehalten gesamt (treuhänderisch)',
    ca: 'Total retingut (en custòdia)', eo: 'Sumo tenata (en fido)', nl: 'Totaal aangehouden (in beheer)',
    el: 'Σύνολο παρακρατούμενο (υπό φύλαξη)',
  },
  'deposit.report.refundedTotal': {
    'pt-BR': 'Total devolvido', fr: 'Total remboursé', es: 'Total devuelto', en: 'Total refunded',
    it: 'Totale rimborsato', de: 'Erstattet gesamt', ca: 'Total retornat', eo: 'Sumo redonita',
    nl: 'Totaal terugbetaald', el: 'Σύνολο επιστροφών',
  },
  'deposit.report.retainedTotal': {
    'pt-BR': 'Total retido (perda/dano)', fr: 'Total retenu', es: 'Total retenido', en: 'Total withheld',
    it: 'Totale trattenuto', de: 'Behalten gesamt', ca: 'Total retingut', eo: 'Sumo retenita',
    nl: 'Totaal ingehouden', el: 'Σύνολο παρακράτησης',
  },
  'deposit.report.empty': {
    'pt-BR': 'Nenhum dado.', fr: 'Aucune donnée.', es: 'Sin datos.', en: 'No data.', it: 'Nessun dato.',
    de: 'Keine Daten.', ca: 'Cap dada.', eo: 'Neniuj datumoj.', nl: 'Geen gegevens.', el: 'Καμία εγγραφή.',
  },

  // ── Surface 5 — plafonds (config BibliotecaPage + erreurs codées) ──
  'deposit.config.capPerReader': {
    'pt-BR': 'Teto por leitor(a)', fr: 'Plafond par lecteur·rice', es: 'Tope por lector(a)',
    en: 'Cap per reader', it: 'Tetto per lettore', de: 'Obergrenze pro Leser·in',
    ca: 'Límit per lector·a', eo: 'Plafono po leganto', nl: 'Maximum per lezer', el: 'Ανώτατο όριο ανά αναγνώστη',
  },
  'deposit.config.capPerReaderHint': {
    'pt-BR': 'Cumulação máx. das cauções retidas de uma pessoa (vazio = ilimitado).',
    fr: "Cumul max des dépôts détenus d'une personne (vide = illimité).",
    es: 'Acumulación máx. de los depósitos retenidos de una persona (vacío = sin límite).',
    en: "Max total of a person's held deposits (empty = no limit).",
    it: 'Cumulo max delle cauzioni trattenute di una persona (vuoto = illimitato).',
    de: 'Max. Summe der einbehaltenen Kautionen einer Person (leer = unbegrenzt).',
    ca: "Acumulació màx. dels dipòsits retinguts d'una persona (buit = sense límit).",
    eo: 'Maks. sumo de tenataj deponoj de persono (malplena = senlima).',
    nl: 'Max. totaal van aangehouden waarborgen van een persoon (leeg = onbeperkt).',
    el: 'Μέγ. σύνολο παρακρατούμενων εγγυήσεων ενός ατόμου (κενό = χωρίς όριο).',
  },
  'deposit.config.maxPerRule': {
    'pt-BR': 'Valor máx. por regra', fr: 'Montant max par règle', es: 'Importe máx. por regla',
    en: 'Max amount per rule', it: 'Importo max per regola', de: 'Höchstbetrag pro Regel',
    ca: 'Import màx. per regla', eo: 'Maks. sumo po regulo', nl: 'Max. bedrag per regel', el: 'Μέγ. ποσό ανά κανόνα',
  },
  'deposit.config.maxPerRuleHint': {
    'pt-BR': 'Limita o valor que uma regra pode fixar (vazio = ilimitado).',
    fr: "Borne le montant qu'une règle peut fixer (vide = illimité).",
    es: 'Limita el importe que una regla puede fijar (vacío = sin límite).',
    en: 'Caps the amount a rule can set (empty = no limit).',
    it: "Limita l'importo che una regola può fissare (vuoto = illimitato).",
    de: 'Begrenzt den Betrag, den eine Regel festlegen kann (leer = unbegrenzt).',
    ca: "Limita l'import que una regla pot fixar (buit = sense límit).",
    eo: 'Limigas la sumon kiun regulo povas fiksi (malplena = senlima).',
    nl: 'Beperkt het bedrag dat een regel kan instellen (leeg = onbeperkt).',
    el: 'Περιορίζει το ποσό που μπορεί να ορίσει ένας κανόνας (κενό = χωρίς όριο).',
  },
  'deposit.config.noLimit': {
    'pt-BR': 'Ilimitado', fr: 'Illimité', es: 'Sin límite', en: 'No limit', it: 'Illimitato',
    de: 'Unbegrenzt', ca: 'Sense límit', eo: 'Senlima', nl: 'Onbeperkt', el: 'Χωρίς όριο',
  },
  'deposit.config.msg.limitsSaved': {
    'pt-BR': 'Tetos salvos.', fr: 'Plafonds enregistrés.', es: 'Topes guardados.', en: 'Limits saved.',
    it: 'Tetti salvati.', de: 'Obergrenzen gespeichert.', ca: 'Límits desats.', eo: 'Plafonoj konservitaj.',
    nl: 'Limieten opgeslagen.', el: 'Τα όρια αποθηκεύτηκαν.',
  },
  'panel.apiError.deposit_cap_reached': {
    'pt-BR': 'Teto de caução atingido para este(a) leitor(a) — coleta recusada (o empréstimo pode ser feito sem caução).',
    fr: 'Plafond de dépôt atteint pour ce·tte lecteur·rice — collecte refusée (le prêt peut se faire sans dépôt).',
    es: 'Tope de depósito alcanzado para este(a) lector(a) — cobro rechazado (el préstamo puede hacerse sin depósito).',
    en: 'Deposit cap reached for this reader — collection refused (the loan can proceed without a deposit).',
    it: 'Tetto di cauzione raggiunto per questo lettore — riscossione rifiutata (il prestito può avvenire senza cauzione).',
    de: 'Kautionsobergrenze für diese·n Leser·in erreicht — Einnahme abgelehnt (die Ausleihe ist ohne Kaution möglich).',
    ca: 'Límit de dipòsit assolit per a aquest·a lector·a — cobrament rebutjat (el préstec es pot fer sense dipòsit).',
    eo: 'Depona plafono atingita por ĉi tiu leganto — kolekto rifuzita (la prunto eblas sen depono).',
    nl: 'Waarborglimiet bereikt voor deze lezer — inning geweigerd (de uitlening kan zonder waarborg).',
    el: 'Επιτεύχθηκε το όριο εγγύησης για αυτόν τον αναγνώστη — η είσπραξη απορρίφθηκε (ο δανεισμός μπορεί να γίνει χωρίς εγγύηση).',
  },
  'panel.apiError.deposit_rule_exceeds_max': {
    'pt-BR': 'O valor da regra excede o teto por regra da biblioteca.',
    fr: 'Le montant de la règle dépasse le plafond par règle de la bibliothèque.',
    es: 'El importe de la regla supera el tope por regla de la biblioteca.',
    en: "The rule amount exceeds the library's per-rule cap.",
    it: "L'importo della regola supera il tetto per regola della biblioteca.",
    de: 'Der Regelbetrag überschreitet die Obergrenze pro Regel der Bibliothek.',
    ca: "L'import de la regla supera el límit per regla de la biblioteca.",
    eo: 'La sumo de la regulo superas la plafonon po regulo de la biblioteko.',
    nl: 'Het regelbedrag overschrijdt de limiet per regel van de bibliotheek.',
    el: 'Το ποσό του κανόνα υπερβαίνει το όριο ανά κανόνα της βιβλιοθήκης.',
  },
};

const LOCALES = ['pt-BR', 'fr', 'es', 'en', 'it', 'de', 'ca', 'eo', 'nl', 'el'];

// Garde-fou : chaque clé doit fournir les 10 locales.
for (const [k, vals] of Object.entries(KEYS)) {
  for (const loc of LOCALES) {
    if (typeof vals[loc] !== 'string') {
      console.error(`MANQUE ${loc} pour ${k}`); process.exit(1);
    }
  }
}

let changed = 0;
for (const loc of LOCALES) {
  const file = path.join(dir, `${loc}.json`);
  const txt = fs.readFileSync(file, 'utf8');
  const obj = JSON.parse(txt);
  const toAdd = Object.entries(KEYS).filter(([k]) => !(k in obj));
  if (!toAdd.length) { console.log(`${loc}: déjà à jour`); continue; }

  const eol = txt.includes('\r\n') ? '\r\n' : '\n';
  const close = txt.lastIndexOf('}');
  const head = txt.slice(0, close).replace(/\s+$/, '');
  const tail = txt.slice(close);
  const additions = toAdd
    .map(([k, vals]) => `  ${JSON.stringify(k)}: ${JSON.stringify(vals[loc])}`)
    .join(`,${eol}`);
  const out = `${head},${eol}${additions}${eol}${tail}`;
  JSON.parse(out); // valide le JSON avant écriture
  fs.writeFileSync(file, out, 'utf8');
  console.log(`${loc}: +${toAdd.length} clé(s)`);
  changed += 1;
}
console.log(`Terminé (${changed} fichier(s) modifié(s)).`);
