/* ===========================================================================
 * i18n-it-de-nl-el-tu.cjs
 * DOC-ADDR-1 (le registre informel de chaque langue, sans exception) — relevé
 * le 27/09/2026 : it, de, nl et el n'avaient jamais été relus. Ils tutoyaient
 * déjà pour l'essentiel ; le formel restait par îlots :
 *   — it (65) : la politique de confidentialité entière au « Lei » en
 *     minuscule (« il suo account », « Può esportare i suoi dati », « comunicare
 *     con lei »), les fenêtres de cooptation et de retrait au « voi »
 *     (« Verificate », « la vostra decisione »), « Verifichi », « la Sua foto » ;
 *   — de (147) : « Sie » dans les assistants de catalogage (« Klicken Sie »,
 *     « Wählen Sie »), les erreurs, la politique de confidentialité ;
 *   — nl (18) : « u / uw » ;
 *   — el (172) : la 2e personne du pluriel (« Επιλέξτε », « Μπορείτε »,
 *     « σας ») dans les assistants, les erreurs, l'import, la cartographie.
 *
 * Réécriture par SUBSTITUTIONS écrites clé par clé (jamais par motif global) :
 * « Sie / sie », « Ihr / ihr », « suo », « σας » désignent aussi, dans les
 * mêmes fichiers, une bibliothèque, un prêt ou des lecteurs — « Sie verlässt
 * die aktive Liste » (la Fernleihe), « la biblioteca e i suoi lettori ». Ces
 * valeurs-là ne sont pas touchées. Chaque substitution doit se trouver une et
 * une seule fois dans la valeur d'origine.
 *
 * Aussi : accents rétablis dans importacoes.oai.noSources (el, « Επικοινωνηστε
 * με τον διαχειριστη ») et dans deux « Aendern … Veroeffentlichung » (de) ;
 * « coordinatie » → « coördinatie » (nl) ; « jullie » (pluriel familier adressé
 * à une seule personne) → « je » en nl, « ihr / euer » → « du / dein » en de.
 * Restent au pluriel les adresses à un collectif (PLURIEL_LEGITIME).
 *
 * Réécriture DE → PARA, rejouable. Sources corrigées dans le même commit.
 * La garde : src/tests/i18n-ecriture.test.js, chemin (4) — VOUVOIEMENT_IT,
 * VOUVOIEMENT_DE, VOUVOIEMENT_NL, VOUVOIEMENT_EL, et le test croisé fr ↔ it.
 * Usage : node scripts/i18n-it-de-nl-el-tu.cjs
 * =========================================================================== */
const fs = require('fs');
const path = require('path');

const DOSSIER = path.join(__dirname, '..', 'src', 'i18n', 'locales');

// locale : { clé : [ancienne valeur, valeur au registre de la langue] }
const DE_PARA = {
  'it': {
    'auth.create.privacyNotice': [
      'Creando il suo account, affida i suoi dati personali ad AnarBib e alla biblioteca aderente. Raccogliamo solo lo strettamente necessario per la circolazione dei libri e rispettiamo i principi di minimizzazione (GDPR/LGPD). Può esportare o eliminare i suoi dati in qualsiasi momento.',
      'Creando il tuo account, affidi i tuoi dati personali ad AnarBib e alla biblioteca aderente. Raccogliamo solo lo strettamente necessario per la circolazione dei libri e rispettiamo i principi di minimizzazione (GDPR/LGPD). Puoi esportare o eliminare i tuoi dati in qualsiasi momento.',
    ],
    'biblioteca.privacy.readonlyHint': [
      'Lei è in modalità di sola lettura. Solo le coordinatrici e i coordinatori, le amministratrici e gli amministratori possono modificare la politica di conservazione.',
      'Sei in modalità di sola lettura. Solo le coordinatrici e i coordinatori, le amministratrici e gli amministratori possono modificare la politica di conservazione.',
    ],
    'federacao.circulos.dormancy.adormecer.done': [
      'Circolo dormiente. Può essere svegliato quando volete.',
      'Circolo dormiente. Può essere svegliato quando vuoi.',
    ],
    'notif.rgpd.purgeWarning.consultations.body': [
      'Alcune consultazioni in sede concluse del suo storico saranno eliminate automaticamente nei prossimi 30 giorni. Può esportare i suoi dati dalla pagina Il mio account prima dell\'eliminazione.',
      'Alcune consultazioni in sede concluse del tuo storico saranno eliminate automaticamente nei prossimi 30 giorni. Puoi esportare i tuoi dati dalla pagina Il mio account prima dell\'eliminazione.',
    ],
    'notif.rgpd.purgeWarning.loans.body': [
      'In conformità alla politica di conservazione della biblioteca, alcuni prestiti del suo storico saranno eliminati automaticamente nei prossimi 30 giorni. Se desidera conservarli, esporti i suoi dati dalla pagina Il mio account prima dell\'eliminazione.',
      'In conformità alla politica di conservazione della biblioteca, alcuni prestiti del tuo storico saranno eliminati automaticamente nei prossimi 30 giorni. Se desideri conservarli, esporta i tuoi dati dalla pagina Il mio account prima dell\'eliminazione.',
    ],
    'notif.rgpd.purgeWarning.reservations.body': [
      'Alcune prenotazioni concluse del suo storico saranno eliminate automaticamente nei prossimi 30 giorni. Può esportare i suoi dati dalla pagina Il mio account prima dell\'eliminazione.',
      'Alcune prenotazioni concluse del tuo storico saranno eliminate automaticamente nei prossimi 30 giorni. Puoi esportare i tuoi dati dalla pagina Il mio account prima dell\'eliminazione.',
    ],
    'privacy.declared.body1': [
      'Se, al momento di creare il suo account, ci ha indicato il nome di una biblioteca che non fa ancora parte di AnarBib, questa informazione viene conservata affinché, se quella biblioteca aderisce un giorno alla nostra rete, possiamo proporle un collegamento come lettore*.',
      'Se, al momento di creare il tuo account, ci hai indicato il nome di una biblioteca che non fa ancora parte di AnarBib, questa informazione viene conservata affinché, se quella biblioteca aderisce un giorno alla nostra rete, possiamo proporti un collegamento come lettore*.',
    ],
    'privacy.declared.body2': [
      'Questa informazione non è condivisa con terzi. È leggibile solo dall\'équipe che amministra la rete AnarBib. Può consultare, modificare o cancellare questa informazione in qualsiasi momento dal suo account (sezione I miei dati).',
      'Questa informazione non è condivisa con terzi. È leggibile solo dall\'équipe che amministra la rete AnarBib. Puoi consultare, modificare o cancellare questa informazione in qualsiasi momento dal tuo account (sezione I miei dati).',
    ],
    'privacy.intro': [
      'Questa politica spiega quali dati personali AnarBib raccoglie, perché vengono raccolti, con chi vengono condivisi e quali diritti ha su di essi. Il testo si applica a tutte le biblioteche che utilizzano il sistema AnarBib.',
      'Questa politica spiega quali dati personali AnarBib raccoglie, perché vengono raccolti, con chi vengono condivisi e quali diritti hai su di essi. Il testo si applica a tutte le biblioteche che utilizzano il sistema AnarBib.',
    ],
    'privacy.lib.fallback': [
      'Questa sezione non è ancora stata tradotta nella sua lingua. Il testo sottostante è in portoghese.',
      'Questa sezione non è ancora stata tradotta nella tua lingua. Il testo sottostante è in portoghese.',
    ],
    'privacy.retention.override': [
      'Ogni biblioteca può adottare durate più brevi (o più lunghe, mediante decisione collettiva motivata). Le durate in vigore nella sua biblioteca possono essere indicate nella sezione specifica qui sotto, se ne ha pubblicata una.',
      'Ogni biblioteca può adottare durate più brevi (o più lunghe, mediante decisione collettiva motivata). Le durate in vigore nella tua biblioteca possono essere indicate nella sezione specifica qui sotto, se ne ha pubblicata una.',
    ],
    'privacy.retention.profile': [
      'Profilo e dati di iscrizione: conservati finché esiste il suo account',
      'Profilo e dati di iscrizione: conservati finché esiste il tuo account',
    ],
    'privacy.retention.title': [
      'Per quanto tempo conserviamo i suoi dati',
      'Per quanto tempo conserviamo i tuoi dati',
    ],
    'privacy.s1.body': [
      'Ogni biblioteca della rete AnarBib è titolare del trattamento dei dati delle/dei sue/suoi lettrici/lettori ai sensi del GDPR (articolo 4.7) e della LGPD brasiliana (articolo 5, VI). AnarBib, come sistema tecnico gestito dal Centro de Cultura Libertária da Amazônia (CCLA), agisce come responsabile del trattamento per conto delle biblioteche — fornisce lo strumento ma non decide sull\'uso dei dati. I contatti di ogni biblioteca aderente sono disponibili sulla pagina della biblioteca interessata. Per domande tecniche sul sistema AnarBib stesso, può scrivere a anarbib@proton.me.',
      'Ogni biblioteca della rete AnarBib è titolare del trattamento dei dati delle/dei sue/suoi lettrici/lettori ai sensi del GDPR (articolo 4.7) e della LGPD brasiliana (articolo 5, VI). AnarBib, come sistema tecnico gestito dal Centro de Cultura Libertária da Amazônia (CCLA), agisce come responsabile del trattamento per conto delle biblioteche — fornisce lo strumento ma non decide sull\'uso dei dati. I contatti di ogni biblioteca aderente sono disponibili sulla pagina della biblioteca interessata. Per domande tecniche sul sistema AnarBib stesso, puoi scrivere a anarbib@proton.me.',
    ],
    'privacy.s1.title': [
      'Chi è responsabile dei suoi dati',
      'Chi è responsabile dei tuoi dati',
    ],
    'privacy.s10.authority': [
      'Può anche contattare l\'autorità di controllo del suo paese (in Italia, il Garante — garanteprivacy.it; in Francia, la CNIL — cnil.fr; in Brasile, l\'ANPD — gov.br/anpd).',
      'Puoi anche contattare l\'autorità di controllo del tuo paese (in Italia, il Garante — garanteprivacy.it; in Francia, la CNIL — cnil.fr; in Brasile, l\'ANPD — gov.br/anpd).',
    ],
    'privacy.s10.body': [
      'Per qualsiasi domanda relativa a questa politica o al trattamento dei suoi dati:',
      'Per qualsiasi domanda relativa a questa politica o al trattamento dei tuoi dati:',
    ],
    'privacy.s2.item.email': [
      'Il suo indirizzo email (per le comunicazioni relative a prestiti e prenotazioni)',
      'Il tuo indirizzo email (per le comunicazioni relative a prestiti e prenotazioni)',
    ],
    'privacy.s2.item.lang': [
      'La sua lingua di interfaccia preferita',
      'La tua lingua di interfaccia preferita',
    ],
    'privacy.s2.item.loans': [
      'Lo storico dei suoi prestiti e prenotazioni nella biblioteca',
      'Lo storico dei tuoi prestiti e prenotazioni nella biblioteca',
    ],
    'privacy.s2.item.name': [
      'Il suo nome o pseudonimo, opzionali',
      'Il tuo nome o pseudonimo, opzionali',
    ],
    'privacy.s2.item.password': [
      'La sua password, archiviata solo in forma cifrata (hash bcrypt) — mai in chiaro, nemmeno bibliotecarie/i possono vederla',
      'La tua password, archiviata solo in forma cifrata (hash bcrypt) — mai in chiaro, nemmeno bibliotecarie/i possono vederla',
    ],
    'privacy.s2.item.username': [
      'Il suo identificativo pubblico (login da lei scelto)',
      'Il tuo identificativo pubblico (login da te scelto)',
    ],
    'privacy.s2.item.phone': [
      'Il suo numero di telefono, solo se sceglie di indicarlo (facoltativo)',
      'Il tuo numero di telefono, solo se scegli di indicarlo (facoltativo)',
    ],
    'privacy.s2.item.address': [
      'Il suo indirizzo postale, solo se sceglie di indicarlo (facoltativo)',
      'Il tuo indirizzo postale, solo se scegli di indicarlo (facoltativo)',
    ],
    'privacy.s3.body': [
      'I dati vengono raccolti unicamente per consentire il funzionamento della biblioteca: gestire il suo account, registrare prestiti e prenotazioni, e comunicare con lei riguardo a queste operazioni (disponibilità di un libro prenotato, promemoria di restituzione, ecc.). Nessun altro uso ne viene fatto. In particolare: nessun marketing, nessuna analisi comportamentale, nessuna profilazione.',
      'I dati vengono raccolti unicamente per consentire il funzionamento della biblioteca: gestire il tuo account, registrare prestiti e prenotazioni, e comunicare con te riguardo a queste operazioni (disponibilità di un libro prenotato, promemoria di restituzione, ecc.). Nessun altro uso ne viene fatto. In particolare: nessun marketing, nessuna analisi comportamentale, nessuna profilazione.',
    ],
    'privacy.s5.body': [
      'Lei ha diritti legali sui suoi dati personali, garantiti dal GDPR europeo e dalla LGPD brasiliana:',
      'Hai diritti legali sui tuoi dati personali, garantiti dal GDPR europeo e dalla LGPD brasiliana:',
    ],
    'privacy.s5.exercise': [
      'La maggior parte di questi diritti può essere esercitata direttamente nell\'applicazione. Per consultare, modificare o eliminare i suoi dati, vada su',
      'La maggior parte di questi diritti può essere esercitata direttamente nell\'applicazione. Per consultare, modificare o eliminare i tuoi dati, vai su',
    ],
    'privacy.s5.linkAccount': [
      'la sua pagina «Il mio account»',
      'la tua pagina «Il mio account»',
    ],
    'privacy.s5.right.access': [
      'Diritto di accesso: vedere quali dati la biblioteca detiene su di lei',
      'Diritto di accesso: vedere quali dati la biblioteca detiene su di te',
    ],
    'privacy.s5.right.delete': [
      'Diritto alla cancellazione («diritto all\'oblio»): eliminare il suo account e i suoi dati',
      'Diritto alla cancellazione («diritto all\'oblio»): eliminare il tuo account e i tuoi dati',
    ],
    'privacy.s5.right.limit': [
      'Diritto di limitazione: chiedere la sospensione temporanea del trattamento dei suoi dati',
      'Diritto di limitazione: chiedere la sospensione temporanea del trattamento dei tuoi dati',
    ],
    'privacy.s5.right.portable': [
      'Diritto alla portabilità: scaricare i suoi dati in un formato riutilizzabile (esportazione .csv disponibile dal suo account)',
      'Diritto alla portabilità: scaricare i tuoi dati in un formato riutilizzabile (esportazione .csv disponibile dal tuo account)',
    ],
    'privacy.s5.title': [
      'I suoi diritti sui suoi dati',
      'I tuoi diritti sui tuoi dati',
    ],
    'privacy.s6.noResale': [
      'AnarBib non vende, non affitta, non condivide mai i suoi dati per scopi commerciali. Mai.',
      'AnarBib non vende, non affitta, non condivide mai i tuoi dati per scopi commerciali. Mai.',
    ],
    'privacy.s6.title': [
      'Con chi vengono condivisi i suoi dati',
      'Con chi vengono condivisi i tuoi dati',
    ],
    'privacy.s7.body': [
      'Le misure tecniche implementate da AnarBib per proteggere i suoi dati:',
      'Le misure tecniche implementate da AnarBib per proteggere i tuoi dati:',
    ],
    'privacy.s7.honest': [
      'Onestamente: nessun sistema è perfettamente sicuro. In caso di violazione di dati che riguardi i suoi diritti, sarà informata/o per email entro il termine previsto dal GDPR (72 ore dopo la constatazione) e l\'autorità di controllo competente sarà anch\'essa notificata.',
      'Onestamente: nessun sistema è perfettamente sicuro. In caso di violazione di dati che riguardi i tuoi diritti, sarai informata/o per email entro il termine previsto dal GDPR (72 ore dopo la constatazione) e l\'autorità di controllo competente sarà anch\'essa notificata.',
    ],
    'privacy.s7.measure.antibot': [
      'La verifica anti-robot è calcolata dal suo browser e controllata dai nostri server: nessun servizio esterno vi partecipa e il suo indirizzo IP non è trasmesso a nessuno',
      'La verifica anti-robot è calcolata dal tuo browser e controllata dai nostri server: nessun servizio esterno vi partecipa e il tuo indirizzo IP non è trasmesso a nessuno',
    ],
    'privacy.s7.title': [
      'Come vengono protetti i suoi dati',
      'Come vengono protetti i tuoi dati',
    ],
    'privacy.s8.body': [
      'In caso di richiesta di comunicazione di dati da parte di un\'autorità giudiziaria o di polizia, AnarBib risponderà unicamente a ciò che è strettamente richiesto dalla legge applicabile, e nulla di più. Le persone interessate saranno informate non appena il segreto dell\'indagine lo permetta. La prima protezione dei suoi dati resta il fatto che essi non vengano raccolti se non sono necessari — è per questo che la minimizzazione (sezione 2) è centrale nella nostra progettazione. La procedura dettagliata è descritta nel documento INCIDENT_RESPONSE.md pubblicato nel nostro repository.',
      'In caso di richiesta di comunicazione di dati da parte di un\'autorità giudiziaria o di polizia, AnarBib risponderà unicamente a ciò che è strettamente richiesto dalla legge applicabile, e nulla di più. Le persone interessate saranno informate non appena il segreto dell\'indagine lo permetta. La prima protezione dei tuoi dati resta il fatto che essi non vengano raccolti se non sono necessari — è per questo che la minimizzazione (sezione 2) è centrale nella nostra progettazione. La procedura dettagliata è descritta nel documento INCIDENT_RESPONSE.md pubblicato nel nostro repository.',
    ],
    'privacy.subtitle': [
      'Come AnarBib protegge i suoi dati personali',
      'Come AnarBib protegge i tuoi dati personali',
    ],
    'privacy.video.body': [
      'Alcuni tutorial video sono ospitati su kolektiva.media, un\'istanza PeerTube militante. Per rispetto della sua privacy, questi video non vengono caricati automaticamente: finché non fa clic su «Carica il video», nulla viene inviato a kolektiva.media. Da quel clic in poi, kolektiva.media riceve il suo indirizzo IP — come qualsiasi sito che visita — per consegnarle il video. Abbiamo disattivato la condivisione P2P su questi video, così il suo IP non viene esposto ad altre persone spettatrici né a server di terze parti.',
      'Alcuni tutorial video sono ospitati su kolektiva.media, un\'istanza PeerTube militante. Per rispetto della tua privacy, questi video non vengono caricati automaticamente: finché non fai clic su «Carica il video», nulla viene inviato a kolektiva.media. Da quel clic in poi, kolektiva.media riceve il tuo indirizzo IP — come qualsiasi sito che visiti — per consegnarti il video. Abbiamo disattivato la condivisione P2P su questi video, così il tuo IP non viene esposto ad altre persone spettatrici né a server di terze parti.',
    ],
    'error.capas.hors_perimetre': [
      'Nessuna delle Sue biblioteche possiede o detiene questa scheda.',
      'Nessuna delle tue biblioteche possiede o detiene questa scheda.',
    ],
    'capas.photo.dejaUneCapa': [
      'Questa scheda ha già una copertina: la Sua foto la sostituirà.',
      'Questa scheda ha già una copertina: la tua foto la sostituirà.',
    ],
    'catalogacao.ui.coverIsbnVolume': [
      'Scheda del volume {volume}: l\'ISBN di un\'opera in più volumi vale spesso per tutti. Verifichi che questa copertina sia proprio quella del volume {volume}.',
      'Scheda del volume {volume}: l\'ISBN di un\'opera in più volumi vale spesso per tutti. Verifica che questa copertina sia proprio quella del volume {volume}.',
    ],
    'rede.collectiveRemoval.propose.modal.motivationPlaceholder': [
      'Esponete in dettaglio le ragioni politiche di questa proposta di ritiro…',
      'Esponi in dettaglio le ragioni politiche di questa proposta di ritiro…',
    ],
    'rede.collectiveRemoval.propose.modal.targetPlaceholder': [
      'Selezionate un* amministratore/trice attiv*…',
      'Seleziona un* amministratore/trice attiv*…',
    ],
    'rede.collectiveRemoval.propose.modal.warning': [
      'Attenzione : decisione politica grave. L\'unanimità de* compagn* amministratori/trici attiv* (esclu* il/la target) è richiesta. Si applica un periodo di grazia di 7 giorni prima dell\'esecuzione. Verificate che questa posizione sia collettivamente condivisa.',
      'Attenzione : decisione politica grave. L\'unanimità de* compagn* amministratori/trici attiv* (esclu* il/la target) è richiesta. Si applica un periodo di grazia di 7 giorni prima dell\'esecuzione. Verifica che questa posizione sia collettivamente condivisa.',
    ],
    'rede.cooptation.propose.modal.description': [
      'La cooptazione è una decisione politica collettiva. L\'unanimità dei compagn* amministratori/trici attiv* della rete è necessaria. Verificate che quest* compagn* abbia la fiducia collettiva della rete.',
      'La cooptazione è una decisione politica collettiva. L\'unanimità dei compagn* amministratori/trici attiv* della rete è necessaria. Verifica che quest* compagn* abbia la fiducia collettiva della rete.',
    ],
    'rede.cooptation.propose.modal.motivationPlaceholder': [
      'Esponete il percorso militante del/la compagn* e il motivo di questa proposta…',
      'Esponi il percorso militante del/la compagn* e il motivo di questa proposta…',
    ],
    'rede.cooptation.vote.discloseIdentityHint': [
      'Questa scelta è obbligatoria e registrata a ogni voto. Gli/le altr* amministratori/trici vedono sempre la vostra identità.',
      'Questa scelta è obbligatoria e registrata a ogni voto. Gli/le altr* amministratori/trici vedono sempre la tua identità.',
    ],
    'rede.cooptation.vote.errors.discloseRequired': [
      'La vostra scelta sulla divulgazione dell\'identità è obbligatoria.',
      'La tua scelta sulla divulgazione dell\'identità è obbligatoria.',
    ],
    'rede.cooptation.vote.modal.description': [
      'La vostra decisione è decisiva : l\'unanimità è richiesta. Un solo voto contrario chiude il processo.',
      'La tua decisione è decisiva : l\'unanimità è richiesta. Un solo voto contrario chiude il processo.',
    ],
    'rede.cooptation.vote.rationalePlaceholder': [
      'Spiegate i motivi politici della vostra opposizione…',
      'Spiega i motivi politici della tua opposizione…',
    ],
    'atelier.revue.retained': [
      'La vostra correzione',
      'La tua correzione',
    ],
    'panel.apiError.split_target_changed': [
      'La scheda è cambiata dopo la proposta: non è stato scritto nulla, per non cancellare il lavoro di qualcun altro. Rifate la proposta sullo stato attuale.',
      'La scheda è cambiata dopo la proposta: non è stato scritto nulla, per non cancellare il lavoro di qualcun altro. Rifai la proposta sullo stato attuale.',
    ],
    'conta.demande.intro': [
      'La domanda di adesione della vostra biblioteca alla rete, e i vostri scambi con l’amministrazione della rete durante l’esame.',
      'La domanda di adesione della tua biblioteca alla rete, e i tuoi scambi con l’amministrazione della rete durante l’esame.',
    ],
    'rede.reviews.intro': [
      'Un lotto nato da un’importazione si pubblica solo dopo la vostra approvazione. Leggete il rapporto, decidete, motivate i ritocchi.',
      'Un lotto nato da un’importazione si pubblica solo dopo la tua approvazione. Leggi il rapporto, decidi, motiva i ritocchi.',
    ],
    'rede.reviews.notes': [
      'Le vostre note',
      'Le tue note',
    ],
    'notif.review.approved.body': [
      'L’amministrazione ha approvato la revisione del vostro lotto: la pubblicazione è aperta.',
      'L’amministrazione ha approvato la revisione del tuo lotto: la pubblicazione è aperta.',
    ],
    'notif.review.changes.body': [
      'L’amministrazione richiede ritocchi prima della pubblicazione. Leggete le note in Catalogazione › Lotti.',
      'L’amministrazione richiede ritocchi prima della pubblicazione. Leggi le note in Catalogazione › Lotti.',
    ],
    'importacoes.run.encoding.fallback': [
      'Letto come {enc}, per ipotesi: il file non è UTF-8 valido. Controllate gli accenti delle prime schede; se sono sbagliati, rielaborate imponendo la codifica.',
      'Letto come {enc}, per ipotesi: il file non è UTF-8 valido. Controlla gli accenti delle prime schede; se sono sbagliati, rielabora imponendo la codifica.',
    ],
    'importacoes.run.encoding.declaredUnsupported': [
      'Il file dichiara un set di caratteri non supportato ({codes}): alcuni caratteri possono essere sbagliati. Riesportate in UTF-8.',
      'Il file dichiara un set di caratteri non supportato ({codes}): alcuni caratteri possono essere sbagliati. Riesporta in UTF-8.',
    ],
    'error.import.reparse_after_promotion': [
      'Questa importazione ha già prodotto bozze: non può più essere rielaborata (le bozze perderebbero il legame con l’importazione). Importate di nuovo il file.',
      'Questa importazione ha già prodotto bozze: non può più essere rielaborata (le bozze perderebbero il legame con l’importazione). Importa di nuovo il file.',
    ],
  },
  'nl': {
    'auth.create.errorProfileFailed': [
      'Het account is aangemaakt, maar er is een fout opgetreden bij het instellen van uw profiel. Neem contact op met de coordinatie.',
      'Het account is aangemaakt, maar er is een fout opgetreden bij het instellen van je profiel. Neem contact op met de coördinatie.',
    ],
    'catalogacao.queue.trashDescription': [
      'Verwijderde concepten. U kunt herstellen of definitief verwijderen.',
      'Verwijderde concepten. Je kunt herstellen of definitief verwijderen.',
    ],
    'catalogacao.wizard.step.autoria.tip': [
      'Automatisch aanvullen stelt bestaande auteurs voor terwijl u typt — vermijd duplicaten!',
      'Automatisch aanvullen stelt bestaande auteurs voor terwijl je typt — vermijd duplicaten!',
    ],
    'catalogacao.wizard.step.dicas.body': [
      '• Het inventarisnummer (tombo) wordt automatisch ingevuld volgens de conventie van uw bibliotheek.\n• Bij het publiceren van een document wordt automatisch een exemplaar aangemaakt.\n• Foutmeldingen verschijnen naast het betreffende veld.\n• Wissel tussen de modi Eenvoudig / Geavanceerd / Volledig in de bovenste balk om meer of minder velden te tonen.',
      '• Het inventarisnummer (tombo) wordt automatisch ingevuld volgens de conventie van je bibliotheek.\n• Bij het publiceren van een document wordt automatisch een exemplaar aangemaakt.\n• Foutmeldingen verschijnen naast het betreffende veld.\n• Wissel tussen de modi Eenvoudig / Geavanceerd / Volledig in de bovenste balk om meer of minder velden te tonen.',
    ],
    'catalogacao.wizard.step.etiquetas.body': [
      'Druk rugetiketten af voor de exemplaren van uw bibliotheek. Selecteer exemplaren uit de lijst, kies welke velden u wilt opnemen (auteur, titel, inventarisnummer, notitie) en genereer een A4-vel klaar om af te drukken, met optionele QR-code.',
      'Druk rugetiketten af voor de exemplaren van je bibliotheek. Selecteer exemplaren uit de lijst, kies welke velden je wilt opnemen (auteur, titel, inventarisnummer, notitie) en genereer een A4-vel klaar om af te drukken, met optionele QR-code.',
    ],
    'catalogacao.wizard.step.etiquetas.tip': [
      'Uw veldvoorkeuren worden automatisch opgeslagen — u hoeft niet elke keer opnieuw te configureren.',
      'Je veldvoorkeuren worden automatisch opgeslagen — je hoeft niet elke keer opnieuw te configureren.',
    ],
    'catalogacao.wizard.step.fila.body': [
      'De Redactiewachtrij toont alle lopende concepten. Partijen groeperen imports. De Catalogus laat u gepubliceerde documenten, auteurs en exemplaren bekijken en bewerken.',
      'De Redactiewachtrij toont alle lopende concepten. Partijen groeperen imports. De Catalogus laat je gepubliceerde documenten, auteurs en exemplaren bekijken en bewerken.',
    ],
    'catalogacao.wizard.step.indexacao.tip': [
      'Het veld Tombo wordt automatisch ingevuld met de volgende referentie volgens de conventie van uw bibliotheek.',
      'Het veld Tombo wordt automatisch ingevuld met de volgende referentie volgens de conventie van je bibliotheek.',
    ],
    'federacao.circulos.dormancy.adormecer.done': [
      'Kring is nu slapend. Hij kan gewekt worden wanneer jullie willen.',
      'Kring is nu slapend. Hij kan gewekt worden wanneer je wilt.',
    ],
    'importacoes.fila.failed.desc': [
      'Deze batch kon niet worden verwerkt. U kunt hem archiveren of verwijderen in de batchlijst.',
      'Deze batch kon niet worden verwerkt. Je kunt hem archiveren of verwijderen in de batchlijst.',
    ],
    'cartografia.add.intro': [
      'Staat jullie collectief nog niet op de kaart? Stel het hier voor.',
      'Staat je collectief nog niet op de kaart? Stel het hier voor.',
    ],
    'catalogacao.dedup.reportPlaceholder': [
      'Wat u hebt vastgesteld (optioneel)',
      'Wat je hebt vastgesteld (optioneel)',
    ],
    'catalogacao.dedup.arbiterOnly': [
      'Samenvoegen en terzijde leggen zijn voorbehouden aan de coördinatie. U kunt twee edities van hetzelfde werk groeperen, of het paar melden.',
      'Samenvoegen en terzijde leggen zijn voorbehouden aan de coördinatie. Je kunt twee edities van hetzelfde werk groeperen, of het paar melden.',
    ],
    'atelier.revue.retained': [
      'Uw correctie',
      'Jouw correctie',
    ],
    'conta.demande.intro': [
      'De aanvraag van uw bibliotheek om tot het netwerk toe te treden, en uw uitwisselingen met het netwerkbeheer tijdens de beoordeling.',
      'De aanvraag van je bibliotheek om tot het netwerk toe te treden, en je uitwisselingen met het netwerkbeheer tijdens de beoordeling.',
    ],
    'rede.reviews.intro': [
      'Een partij uit een import wordt pas gepubliceerd na uw goedkeuring. Lees het rapport, beslis, motiveer aanpassingen.',
      'Een partij uit een import wordt pas gepubliceerd na je goedkeuring. Lees het rapport, beslis, motiveer aanpassingen.',
    ],
    'rede.reviews.notes': [
      'Uw opmerkingen',
      'Jouw opmerkingen',
    ],
    'notif.review.approved.body': [
      'Het beheer heeft de beoordeling van uw partij goedgekeurd: publiceren is mogelijk.',
      'Het beheer heeft de beoordeling van je partij goedgekeurd: publiceren is mogelijk.',
    ],
  },
  'de': {
    'auth.create.privacyNotice': [
      'Mit der Erstellung Ihres Kontos vertrauen Sie Ihre personenbezogenen Daten AnarBib und der beitretenden Bibliothek an. Wir erheben nur das, was für die Buchzirkulation strikt notwendig ist, und respektieren die Grundsätze der Datenminimierung (DSGVO/LGPD). Sie können Ihre Daten jederzeit exportieren oder löschen.',
      'Mit der Erstellung deines Kontos vertraust du deine personenbezogenen Daten AnarBib und der beitretenden Bibliothek an. Wir erheben nur das, was für die Buchzirkulation strikt notwendig ist, und respektieren die Grundsätze der Datenminimierung (DSGVO/LGPD). Du kannst deine Daten jederzeit exportieren oder löschen.',
    ],
    'biblioteca.ill.selectBoth': [
      'Wählen Sie die leihgebende und die leihnehmende Bibliothek.',
      'Wähle die leihgebende und die leihnehmende Bibliothek.',
    ],
    'biblioteca.privacy.editHint': [
      'Lassen Sie ein Feld leer, um den AnarBib-Standard zu verwenden. Geben Sie 0 ein für unbegrenzte Aufbewahrung (nicht empfohlen).',
      'Lass ein Feld leer, um den AnarBib-Standard zu verwenden. Gib 0 ein für unbegrenzte Aufbewahrung (nicht empfohlen).',
    ],
    'biblioteca.privacy.readonlyHint': [
      'Sie befinden sich im Lesemodus. Nur Koordination und Administrator*innen können die Aufbewahrungsrichtlinie ändern.',
      'Du befindest dich im Lesemodus. Nur Koordination und Administrator*innen können die Aufbewahrungsrichtlinie ändern.',
    ],
    'biblioteca.privacy.resetHint': [
      'Die Felder wurden geleert. Klicken Sie auf Speichern, um die Wiederherstellung der Standardwerte zu bestätigen.',
      'Die Felder wurden geleert. Klicke auf Speichern, um die Wiederherstellung der Standardwerte zu bestätigen.',
    ],
    'biblioteca.privacy.subtitle': [
      'Legen Sie fest, wie lange die Bibliothek personenbezogene Daten aufbewahrt, bevor sie automatisch gelöscht werden. Diese Richtlinie setzt den Grundsatz der Datenminimierung um (DSGVO Artikel 5(1)(e) / LGPD Artikel 6).',
      'Lege fest, wie lange die Bibliothek personenbezogene Daten aufbewahrt, bevor sie automatisch gelöscht werden. Diese Richtlinie setzt den Grundsatz der Datenminimierung um (DSGVO Artikel 5(1)(e) / LGPD Artikel 6).',
    ],
    'book.alreadyInWishlist': [
      'Bereits auf Ihrer Merkliste.',
      'Bereits auf deiner Merkliste.',
    ],
    'catalog.avail.unavailUser': [
      'Für Sie nicht verfügbar',
      'Für dich nicht verfügbar',
    ],
    'catalog.table.sortHint': [
      'Klicken Sie auf eine Spaltenüberschrift zum Sortieren',
      'Klicke auf eine Spaltenüberschrift zum Sortieren',
    ],
    'catalogacao.author.nameAssistDesc': [
      'Verwenden Sie dies, wenn der Name roh aus der NB, einem Buch oder einer anderen Quelle stammt.',
      'Verwende dies, wenn der Name roh aus der NB, einem Buch oder einer anderen Quelle stammt.',
    ],
    'catalogacao.author.nameRequired': [
      'Geben Sie den bevorzugten Namen ein.',
      'Gib den bevorzugten Namen ein.',
    ],
    'catalogacao.nameEntry.pickSurname': [
      'Klicken Sie auf das Wort, mit dem der Familienname beginnt',
      'Klicke auf das Wort, mit dem der Familienname beginnt',
    ],
    'catalogacao.nameEntry.caseHint': [
      'Eine eigene Schreibweise des Namens (De Amicis, bell hooks)? Klicken Sie auf das Wort, um den Großbuchstaben wiederherzustellen oder zu entfernen.',
      'Eine eigene Schreibweise des Namens (De Amicis, bell hooks)? Klicke auf das Wort, um den Großbuchstaben wiederherzustellen oder zu entfernen.',
    ],
    'catalogacao.batchHasDrafts': [
      'Dieser Posten enthält noch {count} Entwurf/Entwürfe. Löschen Sie diese zuerst.',
      'Dieser Posten enthält noch {count} Entwurf/Entwürfe. Lösche diese zuerst.',
    ],
    'catalogacao.batchNameRequired': [
      'Geben Sie den Stapelnamen an.',
      'Gib den Stapelnamen an.',
    ],
    'catalogacao.catalog.description': [
      'Durchsuchen Sie veröffentlichte Dokumente, Autoritäten und Exemplare. Wiederaufnehmen zum Bearbeiten oder aus dem Katalog verwerfen.',
      'Durchsuche veröffentlichte Dokumente, Autoritäten und Exemplare. Wiederaufnehmen zum Bearbeiten oder aus dem Katalog verwerfen.',
    ],
    'catalogacao.catalog.refreshBusy': [
      'Aktualisierung läuft bereits — versuchen Sie es gleich erneut.',
      'Aktualisierung läuft bereits — versuche es gleich erneut.',
    ],
    'catalogacao.catalog.retakeCreatedNoEdit': [
      'Wiederaufnahme-Entwurf erstellt (ID {id}). Öffnen Sie den entsprechenden Tab zum Bearbeiten.',
      'Wiederaufnahme-Entwurf erstellt (ID {id}). Öffne den entsprechenden Tab zum Bearbeiten.',
    ],
    'catalogacao.exemplar.autoExemplarInfo': [
      'Beim Veröffentlichen eines neuen Dokuments wird automatisch ein Exemplar mit der bibliografischen Referenz (bib_ref) als Inventarnummer erstellt. Verwenden Sie dieses Formular nur, um zusätzliche Exemplare hinzuzufügen oder ein bestehendes Exemplar zu bearbeiten.',
      'Beim Veröffentlichen eines neuen Dokuments wird automatisch ein Exemplar mit der bibliografischen Referenz (bib_ref) als Inventarnummer erstellt. Verwende dieses Formular nur, um zusätzliche Exemplare hinzuzufügen oder ein bestehendes Exemplar zu bearbeiten.',
    ],
    'catalogacao.exemplar.labelMarked': [
      'Etikett als fertig markiert. Speichern Sie den Entwurf.',
      'Etikett als fertig markiert. Speichere den Entwurf.',
    ],
    'catalogacao.exemplar.labelNeedFields': [
      'Füllen Sie mindestens Autor*in, Titel oder CDD im Etikett aus.',
      'Fülle mindestens Autor*in, Titel oder CDD im Etikett aus.',
    ],
    'catalogacao.exemplar.labelStepDesc': [
      'Das Etikett wird aus dem Quelldokument berechnet. Überschreiben Sie Felder nur bei Bedarf.',
      'Das Etikett wird aus dem Quelldokument berechnet. Überschreibe Felder nur bei Bedarf.',
    ],
    'catalogacao.exemplar.materialStepDesc': [
      'Identifizieren Sie das physische Objekt: Inventarnummer und Standort.',
      'Identifiziere das physische Objekt: Inventarnummer und Standort.',
    ],
    'catalogacao.exemplar.originStepDesc': [
      'Suchen Sie den veröffentlichten Datensatz.',
      'Suche den veröffentlichten Datensatz.',
    ],
    'catalogacao.exemplar.refOrTomboRequired': [
      'Geben Sie mindestens die Referenz oder Inventarnummer ein.',
      'Gib mindestens die Referenz oder Inventarnummer ein.',
    ],
    'catalogacao.titleCase.needLanguage': [
      'Geben Sie die Sprache an, um die Schreibung zu normalisieren',
      'Gib die Sprache an, um die Schreibung zu normalisieren',
    ],
    'catalogacao.titleCase.properHint': [
      'Ein Eigenname? Klicken Sie auf das Wort, um den Großbuchstaben wiederherzustellen (oder zu entfernen).',
      'Ein Eigenname? Klicke auf das Wort, um den Großbuchstaben wiederherzustellen (oder zu entfernen).',
    ],
    'catalogacao.isbd.notGenerated': [
      'ISBD: für diesen Entwurf noch nicht erstellt. Klicken Sie oben auf „ISBD vorbereiten“.',
      'ISBD: für diesen Entwurf noch nicht erstellt. Klicke oben auf „ISBD vorbereiten“.',
    ],
    'catalogacao.msg.bibRefDuplicate': [
      'Die bibliographische Referenz {bibRef} wird bereits verwendet (Datensatz {bookId}). Aendern Sie sie vor der Veroeffentlichung.',
      'Die bibliographische Referenz {bibRef} wird bereits verwendet (Datensatz {bookId}). Ändere sie vor der Veröffentlichung.',
    ],
    'catalogacao.noBatches': [
      'Keine Posten gefunden. Erstellen Sie den ersten Posten oben.',
      'Keine Posten gefunden. Erstelle den ersten Posten oben.',
    ],
    'catalogacao.queue.description': [
      'Aktive Entwürfe von Dokumenten, Autoritäten und Exemplaren. Verwalten Sie den Lebenszyklus: bearbeiten, als bereit markieren, veröffentlichen oder verwerfen.',
      'Aktive Entwürfe von Dokumenten, Autoritäten und Exemplaren. Verwalte den Lebenszyklus: bearbeiten, als bereit markieren, veröffentlichen oder verwerfen.',
    ],
    'catalogacao.queue.selectAtLeast': [
      'Wählen Sie mindestens ein Element aus.',
      'Wähle mindestens ein Element aus.',
    ],
    'catalogacao.queue.trashDescription': [
      'Verworfene Entwürfe. Sie können wiederherstellen oder endgültig löschen.',
      'Verworfene Entwürfe. Du kannst wiederherstellen oder endgültig löschen.',
    ],
    'catalogacao.reassign.multiHint': [
      'Dieser Datensatz hat Exemplare in mehreren Bibliotheken; wählen Sie, welche verschoben werden sollen.',
      'Dieser Datensatz hat Exemplare in mehreren Bibliotheken; wähle, welche verschoben werden sollen.',
    ],
    'catalogacao.wizard.step.autoria.body': [
      'Verwalten Sie Autor*innen (Personen und Organisationen), die mit Dokumenten verknüpft sind. Jede*r hier erstellte Autor*in kann mit mehreren Büchern verknüpft werden und umgekehrt.',
      'Verwalte Autor*innen (Personen und Organisationen), die mit Dokumenten verknüpft sind. Jede*r hier erstellte Autor*in kann mit mehreren Büchern verknüpft werden und umgekehrt.',
    ],
    'catalogacao.wizard.step.autoria.tip': [
      'Die Autovervollständigung schlägt bereits vorhandene Autor*innen vor — vermeiden Sie Duplikate!',
      'Die Autovervollständigung schlägt bereits vorhandene Autor*innen vor — vermeide Duplikate!',
    ],
    'catalogacao.wizard.step.dicas.body': [
      '• Die Inventarnummer (Tombo) wird automatisch gemäß der Konvention Ihrer Bibliothek ausgefüllt.\n• Bei der Veröffentlichung eines Dokuments wird automatisch ein Exemplar erstellt.\n• Fehlermeldungen erscheinen neben dem betroffenen Feld.\n• Wechseln Sie zwischen den Modi Einfach / Erweitert / Vollständig in der oberen Leiste, um mehr oder weniger Felder anzuzeigen.',
      '• Die Inventarnummer (Tombo) wird automatisch gemäß der Konvention deiner Bibliothek ausgefüllt.\n• Bei der Veröffentlichung eines Dokuments wird automatisch ein Exemplar erstellt.\n• Fehlermeldungen erscheinen neben dem betroffenen Feld.\n• Wechsle zwischen den Modi Einfach / Erweitert / Vollständig in der oberen Leiste, um mehr oder weniger Felder anzuzeigen.',
    ],
    'catalogacao.wizard.step.documento.body': [
      'Erstellen und bearbeiten Sie bibliografische Aufnahmen (Bücher, Broschüren, Zeitschriften…). Füllen Sie Titel, Autor*in, ISBN, Materialtyp und bibliografische Referenz aus. Verwenden Sie den Modus Einfach für das Wesentliche oder Vollständig für alle Felder.',
      'Erstelle und bearbeite bibliografische Aufnahmen (Bücher, Broschüren, Zeitschriften…). Fülle Titel, Autor*in, ISBN, Materialtyp und bibliografische Referenz aus. Verwende den Modus Einfach für das Wesentliche oder Vollständig für alle Felder.',
    ],
    'catalogacao.wizard.step.etiquetas.body': [
      'Drucken Sie Rückenschilder für die Exemplare Ihrer Bibliothek. Wählen Sie Exemplare aus der Liste, bestimmen Sie die anzuzeigenden Felder (Autor*in, Titel, Inventarnummer, Notiz) und erzeugen Sie ein druckfertiges A4-Blatt, mit optionalem QR-Code.',
      'Drucke Rückenschilder für die Exemplare deiner Bibliothek. Wähle Exemplare aus der Liste, bestimme die anzuzeigenden Felder (Autor*in, Titel, Inventarnummer, Notiz) und erzeuge ein druckfertiges A4-Blatt, mit optionalem QR-Code.',
    ],
    'catalogacao.wizard.step.etiquetas.tip': [
      'Ihre Feldeinstellungen werden automatisch gespeichert — Sie müssen nicht jedes Mal neu konfigurieren.',
      'Deine Feldeinstellungen werden automatisch gespeichert — du musst nicht jedes Mal neu konfigurieren.',
    ],
    'catalogacao.wizard.step.indexacao.body': [
      'Erfassen Sie Exemplare (physische Kopien), die mit einem Dokument verknüpft sind. Jedes Exemplar hat eine Inventarnummer (Tombo), eine Ausleihrichtlinie und ein Etikett für das Rückenschild.',
      'Erfasse Exemplare (physische Kopien), die mit einem Dokument verknüpft sind. Jedes Exemplar hat eine Inventarnummer (Tombo), eine Ausleihrichtlinie und ein Etikett für das Rückenschild.',
    ],
    'catalogacao.wizard.step.indexacao.tip': [
      'Das Feld Tombo wird automatisch mit der nächsten Referenz gemäß der Konvention Ihrer Bibliothek ausgefüllt.',
      'Das Feld Tombo wird automatisch mit der nächsten Referenz gemäß der Konvention deiner Bibliothek ausgefüllt.',
    ],
    'catalogacao.wizard.step.welcome.body': [
      'Dieser Leitfaden stellt die wichtigsten Funktionen des Katalogisierungsmoduls vor. Navigieren Sie durch die Schritte, um jeden Tab und seine Werkzeuge zu entdecken.',
      'Dieser Leitfaden stellt die wichtigsten Funktionen des Katalogisierungsmoduls vor. Navigiere durch die Schritte, um jeden Tab und seine Werkzeuge zu entdecken.',
    ],
    'error.consulta.all_engaged': [
      'Derzeit sind alle einsehbaren Exemplare dieses Dokuments in Benutzung. Bitte versuchen Sie es später erneut.',
      'Derzeit sind alle einsehbaren Exemplare dieses Dokuments in Benutzung. Bitte versuche es später erneut.',
    ],
    'federacao.circulos.dormancy.adormecer.done': [
      'Kreis ruht. Er kann geweckt werden, wann ihr wollt.',
      'Kreis ruht. Er kann geweckt werden, wann du willst.',
    ],
    'importacoes.enterRssUrl': [
      'Geben Sie die RSS/Atom-Feed-URL an.',
      'Gib die RSS/Atom-Feed-URL an.',
    ],
    'importacoes.enterUrl': [
      'Geben Sie eine URL an.',
      'Gib eine URL an.',
    ],
    'importacoes.fila.failed.desc': [
      'Dieser Stapel konnte nicht verarbeitet werden. Sie können ihn in der Stapelliste archivieren oder löschen.',
      'Dieser Stapel konnte nicht verarbeitet werden. Du kannst ihn in der Stapelliste archivieren oder löschen.',
    ],
    'importacoes.fila.gesturesHelp': [
      'Bei einer Dublette: Exemplar anlegen erfasst Ihr Exemplar am vorhandenen Eintrag; Ablehnen verwirft alles (nur wenn Sie dieses Dokument nicht besitzen).',
      'Bei einer Dublette: Exemplar anlegen erfasst dein Exemplar am vorhandenen Eintrag; Ablehnen verwirft alles (nur wenn du dieses Dokument nicht besitzt).',
    ],
    'importacoes.fila.reconcileRowHint': [
      '→ Besitzt Ihre Bibliothek dieses Dokument? Nutzen Sie Exemplar anlegen (nicht Ablehnen).',
      '→ Besitzt deine Bibliothek dieses Dokument? Nutze Exemplar anlegen (nicht Ablehnen).',
    ],
    'importacoes.fila.reconcileTitle': [
      'Erfasst Ihr Exemplar am bereits vorhandenen Katalogeintrag, ohne einen doppelten Eintrag anzulegen.',
      'Erfasst dein Exemplar am bereits vorhandenen Katalogeintrag, ohne einen doppelten Eintrag anzulegen.',
    ],
    'importacoes.fila.rejectHoldingsWarn': [
      'Achtung: {n} ausgewählte Zeile(n) sind Dubletten eines bereits im Katalog vorhandenen Dokuments — Ihre Bibliothek erklärt, ein Exemplar zu besitzen. Ablehnen verwirft die Zeile und erfasst dieses Exemplar NICHT. Wenn Ihre Bibliothek dieses Dokument besitzt, brechen Sie ab und nutzen Sie die Schaltfläche Exemplar anlegen. Trotzdem ablehnen?',
      'Achtung: {n} ausgewählte Zeile(n) sind Dubletten eines bereits im Katalog vorhandenen Dokuments — deine Bibliothek erklärt, ein Exemplar zu besitzen. Ablehnen verwirft die Zeile und erfasst dieses Exemplar NICHT. Wenn deine Bibliothek dieses Dokument besitzt, brich ab und nutze die Schaltfläche Exemplar anlegen. Trotzdem ablehnen?',
    ],
    'importacoes.fila.rejectTitle': [
      'Verwirft die Zeile (kein Eintrag, kein Exemplar). Nur für eine falsche Dublette oder ein Dokument, das Ihre Bibliothek nicht besitzt.',
      'Verwirft die Zeile (kein Eintrag, kein Exemplar). Nur für eine falsche Dublette oder ein Dokument, das deine Bibliothek nicht besitzt.',
    ],
    'importacoes.fila.selectRun': [
      'Wählen Sie oben eine Verarbeitung, um die Prüfzeilen anzuzeigen.',
      'Wähle oben eine Verarbeitung, um die Prüfzeilen anzuzeigen.',
    ],
    'importacoes.fontes.noCompanheiras': [
      'Keine Partnerbibliothek registriert. Erstellen Sie eine Partnerschaft, um den gegenseitigen Import zu aktivieren.',
      'Keine Partnerbibliothek registriert. Erstelle eine Partnerschaft, um den gegenseitigen Import zu aktivieren.',
    ],
    'importacoes.selectFile': [
      'Wählen Sie eine Datei.',
      'Wähle eine Datei.',
    ],
    'importacoes.selectSource': [
      'Wählen Sie eine Partnerquelle.',
      'Wähle eine Partnerquelle.',
    ],
    'labels.fieldsConfigHint': [
      'Wählen Sie die optionalen Felder, die auf den gedruckten Etiketten erscheinen sollen.',
      'Wähle die optionalen Felder, die auf den gedruckten Etiketten erscheinen sollen.',
    ],
    'labels.format.sectionHint': [
      'Wählen Sie ein handelsübliches Bogenformat oder passen Sie die Maße manuell an.',
      'Wähle ein handelsübliches Bogenformat oder passe die Maße manuell an.',
    ],
    'labels.hint': [
      'Wählen Sie Exemplare aus, um einen druckbaren Etikettenbogen zu erstellen. Klicken Sie auf Zeilen zum Auswählen.',
      'Wähle Exemplare aus, um einen druckbaren Etikettenbogen zu erstellen. Klicke auf Zeilen zum Auswählen.',
    ],
    'notif.rgpd.purgeWarning.consultations.body': [
      'Einige abgeschlossene Konsultationen vor Ort aus Ihrem Verlauf werden in den nächsten 30 Tagen automatisch gelöscht. Sie können Ihre Daten über die Seite Mein Konto vor der Löschung exportieren.',
      'Einige abgeschlossene Konsultationen vor Ort aus deinem Verlauf werden in den nächsten 30 Tagen automatisch gelöscht. Du kannst deine Daten über die Seite Mein Konto vor der Löschung exportieren.',
    ],
    'notif.rgpd.purgeWarning.loans.body': [
      'Gemäß der Aufbewahrungsrichtlinie der Bibliothek werden einige Ausleihen aus Ihrem Verlauf in den nächsten 30 Tagen automatisch gelöscht. Wenn Sie sie behalten möchten, exportieren Sie Ihre Daten über die Seite Mein Konto vor der Löschung.',
      'Gemäß der Aufbewahrungsrichtlinie der Bibliothek werden einige Ausleihen aus deinem Verlauf in den nächsten 30 Tagen automatisch gelöscht. Wenn du sie behalten möchtest, exportiere deine Daten über die Seite Mein Konto vor der Löschung.',
    ],
    'notif.rgpd.purgeWarning.reservations.body': [
      'Einige abgeschlossene Reservierungen aus Ihrem Verlauf werden in den nächsten 30 Tagen automatisch gelöscht. Sie können Ihre Daten über die Seite Mein Konto vor der Löschung exportieren.',
      'Einige abgeschlossene Reservierungen aus deinem Verlauf werden in den nächsten 30 Tagen automatisch gelöscht. Du kannst deine Daten über die Seite Mein Konto vor der Löschung exportieren.',
    ],
    'panel.action.selectAtLeastOne': [
      'Wählen Sie mindestens eine Vormerkung.',
      'Wähle mindestens eine Vormerkung.',
    ],
    'panel.action.selectStep': [
      'Wählen Sie einen Schritt.',
      'Wähle einen Schritt.',
    ],
    'panel.apiError.bib_ref_duplicado': [
      'Diese bibliographische Referenz wird bereits von einem anderen Datensatz verwendet. Aendern Sie sie vor der Veroeffentlichung.',
      'Diese bibliographische Referenz wird bereits von einem anderen Datensatz verwendet. Ändere sie vor der Veröffentlichung.',
    ],
    'panel.apiError.not_authorized': [
      'Diese Aktion ist für Ihre Rolle nicht zulässig.',
      'Diese Aktion ist für deine Rolle nicht zulässig.',
    ],
    'panel.apiError.not_staff_of_this_library': [
      'Sie gehören nicht zum Team dieser Bibliothek.',
      'Du gehörst nicht zum Team dieser Bibliothek.',
    ],
    'panel.loan.enterSubIds': [
      'Geben Sie die Exemplar-IDs an (z.B.: 154.1, 154.2).',
      'Gib die Exemplar-IDs an (z.B.: 154.1, 154.2).',
    ],
    'panel.tasks.createAt': [
      'Erstellen Sie Aufgaben auf der Seite Bibliothek, Reiter «Interne Aufgaben».',
      'Erstelle Aufgaben auf der Seite Bibliothek, Reiter «Interne Aufgaben».',
    ],
    'privacy.declared.body1': [
      'Wenn Sie uns bei der Erstellung Ihres Kontos den Namen einer Bibliothek genannt haben, die noch nicht bei AnarBib ist, wird diese Angabe aufbewahrt, damit wir Ihnen, falls diese Bibliothek eines Tages unserem Netzwerk beitritt, eine Anbindung als Leser*in anbieten können.',
      'Wenn du uns bei der Erstellung deines Kontos den Namen einer Bibliothek genannt hast, die noch nicht bei AnarBib ist, wird diese Angabe aufbewahrt, damit wir dir, falls diese Bibliothek eines Tages unserem Netzwerk beitritt, eine Anbindung als Leser*in anbieten können.',
    ],
    'privacy.declared.body2': [
      'Diese Angabe wird an keine Dritten weitergegeben. Sie ist nur für das Team lesbar, das das AnarBib-Netzwerk verwaltet. Sie können diese Angabe jederzeit in Ihrem Konto einsehen, ändern oder löschen (Bereich Meine Daten).',
      'Diese Angabe wird an keine Dritten weitergegeben. Sie ist nur für das Team lesbar, das das AnarBib-Netzwerk verwaltet. Du kannst diese Angabe jederzeit in deinem Konto einsehen, ändern oder löschen (Bereich Meine Daten).',
    ],
    'privacy.intro': [
      'Diese Erklärung beschreibt, welche personenbezogenen Daten AnarBib sammelt, warum sie gesammelt werden, mit wem sie geteilt werden und welche Rechte Sie an ihnen haben. Der Text gilt für alle Bibliotheken, die das AnarBib-System nutzen.',
      'Diese Erklärung beschreibt, welche personenbezogenen Daten AnarBib sammelt, warum sie gesammelt werden, mit wem sie geteilt werden und welche Rechte du an ihnen hast. Der Text gilt für alle Bibliotheken, die das AnarBib-System nutzen.',
    ],
    'privacy.lib.fallback': [
      'Dieser Abschnitt wurde noch nicht in Ihre Sprache übersetzt. Der folgende Text ist auf Portugiesisch.',
      'Dieser Abschnitt wurde noch nicht in deine Sprache übersetzt. Der folgende Text ist auf Portugiesisch.',
    ],
    'privacy.retention.override': [
      'Jede Bibliothek kann kürzere Fristen wählen (oder längere, durch begründete kollektive Entscheidung). Die in Ihrer Bibliothek geltenden Fristen können im spezifischen Abschnitt unten angegeben werden, falls einer veröffentlicht wurde.',
      'Jede Bibliothek kann kürzere Fristen wählen (oder längere, durch begründete kollektive Entscheidung). Die in deiner Bibliothek geltenden Fristen können im spezifischen Abschnitt unten angegeben werden, falls einer veröffentlicht wurde.',
    ],
    'privacy.retention.profile': [
      'Profil und Registrierungsdaten: aufbewahrt, solange Ihr Konto besteht',
      'Profil und Registrierungsdaten: aufbewahrt, solange dein Konto besteht',
    ],
    'privacy.retention.title': [
      'Wie lange wir Ihre Daten aufbewahren',
      'Wie lange wir deine Daten aufbewahren',
    ],
    'privacy.s1.body': [
      'Jede Bibliothek im AnarBib-Netzwerk ist Verantwortliche der Verarbeitung der Daten ihrer Leser*innen im Sinne der DSGVO (Artikel 4 Nr. 7) und des brasilianischen LGPD (Artikel 5, VI). AnarBib, als technisches System betrieben vom Centro de Cultura Libertária da Amazônia (CCLA), handelt als Auftragsverarbeiter im Auftrag der Bibliotheken — es stellt das Werkzeug zur Verfügung, entscheidet aber nicht über die Verwendung der Daten. Die Kontaktdaten jeder Mitgliedsbibliothek sind auf der Seite der jeweiligen Bibliothek verfügbar. Für technische Fragen zum AnarBib-System selbst können Sie an anarbib@proton.me schreiben.',
      'Jede Bibliothek im AnarBib-Netzwerk ist Verantwortliche der Verarbeitung der Daten ihrer Leser*innen im Sinne der DSGVO (Artikel 4 Nr. 7) und des brasilianischen LGPD (Artikel 5, VI). AnarBib, als technisches System betrieben vom Centro de Cultura Libertária da Amazônia (CCLA), handelt als Auftragsverarbeiter im Auftrag der Bibliotheken — es stellt das Werkzeug zur Verfügung, entscheidet aber nicht über die Verwendung der Daten. Die Kontaktdaten jeder Mitgliedsbibliothek sind auf der Seite der jeweiligen Bibliothek verfügbar. Für technische Fragen zum AnarBib-System selbst kannst du an anarbib@proton.me schreiben.',
    ],
    'privacy.s1.title': [
      'Wer ist für Ihre Daten verantwortlich',
      'Wer ist für deine Daten verantwortlich',
    ],
    'privacy.s10.authority': [
      'Sie können auch die Aufsichtsbehörde Ihres Landes kontaktieren (in Deutschland, BfDI — bfdi.bund.de bzw. die Behörde Ihres Bundeslandes; in Österreich, DSB — dsb.gv.at; in der Schweiz, EDÖB — edoeb.admin.ch).',
      'Du kannst auch die Aufsichtsbehörde deines Landes kontaktieren (in Deutschland, BfDI — bfdi.bund.de bzw. die Behörde deines Bundeslandes; in Österreich, DSB — dsb.gv.at; in der Schweiz, EDÖB — edoeb.admin.ch).',
    ],
    'privacy.s10.body': [
      'Für jede Frage zu dieser Erklärung oder zur Verarbeitung Ihrer Daten:',
      'Für jede Frage zu dieser Erklärung oder zur Verarbeitung deiner Daten:',
    ],
    'privacy.s10.title': [
      'Wie Sie uns kontaktieren',
      'Wie du uns kontaktierst',
    ],
    'privacy.s2.item.email': [
      'Ihre E-Mail-Adresse (für Kommunikationen zu Ausleihen und Reservierungen)',
      'Deine E-Mail-Adresse (für Kommunikationen zu Ausleihen und Reservierungen)',
    ],
    'privacy.s2.item.lang': [
      'Ihre bevorzugte Oberflächensprache',
      'Deine bevorzugte Oberflächensprache',
    ],
    'privacy.s2.item.libraries': [
      'Die Liste der Netzwerk-Bibliotheken, in denen Sie Mitglied sind',
      'Die Liste der Netzwerk-Bibliotheken, in denen du Mitglied bist',
    ],
    'privacy.s2.item.loans': [
      'Die Historie Ihrer Ausleihen und Reservierungen in der Bibliothek',
      'Die Historie deiner Ausleihen und Reservierungen in der Bibliothek',
    ],
    'privacy.s2.item.name': [
      'Ihr Vorname oder Pseudonym, beide optional',
      'Dein Vorname oder Pseudonym, beide optional',
    ],
    'privacy.s2.item.password': [
      'Ihr Passwort, ausschließlich in verschlüsselter Form gespeichert (bcrypt-Hash) — niemals im Klartext, nicht einmal Bibliothekar*innen können es einsehen',
      'Dein Passwort, ausschließlich in verschlüsselter Form gespeichert (bcrypt-Hash) — niemals im Klartext, nicht einmal Bibliothekar*innen können es einsehen',
    ],
    'privacy.s2.item.username': [
      'Ihre öffentliche Kennung (Benutzername Ihrer Wahl)',
      'Deine öffentliche Kennung (Benutzername deiner Wahl)',
    ],
    'privacy.s2.item.phone': [
      'Ihre Telefonnummer, nur wenn Sie sie angeben möchten (optional)',
      'Deine Telefonnummer, nur wenn du sie angeben möchtest (optional)',
    ],
    'privacy.s2.item.address': [
      'Ihre Postanschrift, nur wenn Sie sie angeben möchten (optional)',
      'Deine Postanschrift, nur wenn du sie angeben möchtest (optional)',
    ],
    'privacy.s3.body': [
      'Die Daten werden ausschließlich gesammelt, um den Betrieb der Bibliothek zu ermöglichen: Ihr Konto verwalten, Ausleihen und Reservierungen erfassen und mit Ihnen zu diesen Vorgängen kommunizieren (Verfügbarkeit eines reservierten Buches, Rückgabeerinnerungen usw.). Keine andere Verwendung erfolgt. Insbesondere: kein Marketing, keine Verhaltensanalyse, kein Profiling.',
      'Die Daten werden ausschließlich gesammelt, um den Betrieb der Bibliothek zu ermöglichen: dein Konto verwalten, Ausleihen und Reservierungen erfassen und mit dir zu diesen Vorgängen kommunizieren (Verfügbarkeit eines reservierten Buches, Rückgabeerinnerungen usw.). Keine andere Verwendung erfolgt. Insbesondere: kein Marketing, keine Verhaltensanalyse, kein Profiling.',
    ],
    'privacy.s5.body': [
      'Sie haben gesetzliche Rechte an Ihren persönlichen Daten, die durch die europäische DSGVO und das brasilianische LGPD garantiert sind:',
      'Du hast gesetzliche Rechte an deinen persönlichen Daten, die durch die europäische DSGVO und das brasilianische LGPD garantiert sind:',
    ],
    'privacy.s5.exercise': [
      'Die meisten dieser Rechte können direkt in der Anwendung ausgeübt werden. Um Ihre Daten einzusehen, zu ändern oder zu löschen, gehen Sie auf',
      'Die meisten dieser Rechte können direkt in der Anwendung ausgeübt werden. Um deine Daten einzusehen, zu ändern oder zu löschen, geh auf',
    ],
    'privacy.s5.linkAccount': [
      'Ihre Seite „Mein Konto“',
      'deine Seite „Mein Konto“',
    ],
    'privacy.s5.right.access': [
      'Auskunftsrecht: einsehen, welche Daten die Bibliothek über Sie hat',
      'Auskunftsrecht: einsehen, welche Daten die Bibliothek über dich hat',
    ],
    'privacy.s5.right.delete': [
      'Recht auf Löschung („Recht auf Vergessenwerden“): Ihr Konto und Ihre Daten löschen',
      'Recht auf Löschung („Recht auf Vergessenwerden“): dein Konto und deine Daten löschen',
    ],
    'privacy.s5.right.limit': [
      'Recht auf Einschränkung: vorübergehende Aussetzung der Verarbeitung Ihrer Daten verlangen',
      'Recht auf Einschränkung: vorübergehende Aussetzung der Verarbeitung deiner Daten verlangen',
    ],
    'privacy.s5.right.portable': [
      'Recht auf Datenübertragbarkeit: Ihre Daten in einem wiederverwendbaren Format herunterladen (.csv-Export in Ihrem Konto verfügbar)',
      'Recht auf Datenübertragbarkeit: deine Daten in einem wiederverwendbaren Format herunterladen (.csv-Export in deinem Konto verfügbar)',
    ],
    'privacy.s5.title': [
      'Ihre Rechte an Ihren Daten',
      'Deine Rechte an deinen Daten',
    ],
    'privacy.s6.noResale': [
      'AnarBib verkauft, vermietet oder teilt Ihre Daten niemals zu kommerziellen Zwecken. Niemals.',
      'AnarBib verkauft, vermietet oder teilt deine Daten niemals zu kommerziellen Zwecken. Niemals.',
    ],
    'privacy.s6.title': [
      'Mit wem Ihre Daten geteilt werden',
      'Mit wem deine Daten geteilt werden',
    ],
    'privacy.s7.body': [
      'Technische Maßnahmen, die AnarBib zum Schutz Ihrer Daten umsetzt:',
      'Technische Maßnahmen, die AnarBib zum Schutz deiner Daten umsetzt:',
    ],
    'privacy.s7.honest': [
      'Ehrlich gesagt: kein System ist vollkommen sicher. Im Falle einer Datenschutzverletzung, die Ihre Rechte betrifft, werden Sie per E-Mail innerhalb der von der DSGVO vorgesehenen Frist (72 Stunden nach Feststellung) benachrichtigt, und die zuständige Aufsichtsbehörde wird ebenfalls informiert.',
      'Ehrlich gesagt: kein System ist vollkommen sicher. Im Falle einer Datenschutzverletzung, die deine Rechte betrifft, wirst du per E-Mail innerhalb der von der DSGVO vorgesehenen Frist (72 Stunden nach Feststellung) benachrichtigt, und die zuständige Aufsichtsbehörde wird ebenfalls informiert.',
    ],
    'privacy.s7.measure.antibot': [
      'Die Anti-Bot-Prüfung wird von Ihrem Browser berechnet und von unseren Servern überprüft: kein externer Dienst ist beteiligt und Ihre IP-Adresse wird an niemanden weitergegeben',
      'Die Anti-Bot-Prüfung wird von deinem Browser berechnet und von unseren Servern überprüft: kein externer Dienst ist beteiligt und deine IP-Adresse wird an niemanden weitergegeben',
    ],
    'privacy.s7.title': [
      'Wie Ihre Daten geschützt werden',
      'Wie deine Daten geschützt werden',
    ],
    'privacy.s8.body': [
      'Im Falle einer Anfrage zur Datenherausgabe durch eine Justiz- oder Polizeibehörde wird AnarBib nur das beantworten, was strikt nach geltendem Recht erforderlich ist, und nichts darüber hinaus. Betroffene Personen werden informiert, sobald die Geheimhaltung der Ermittlung dies erlaubt. Der erste Schutz Ihrer Daten bleibt die Tatsache, dass sie nicht gesammelt werden, wenn sie nicht notwendig sind — deshalb steht die Datenminimierung (Abschnitt 2) im Zentrum unseres Designs. Das detaillierte Verfahren ist im Dokument INCIDENT_RESPONSE.md beschrieben, das in unserem Repository veröffentlicht ist.',
      'Im Falle einer Anfrage zur Datenherausgabe durch eine Justiz- oder Polizeibehörde wird AnarBib nur das beantworten, was strikt nach geltendem Recht erforderlich ist, und nichts darüber hinaus. Betroffene Personen werden informiert, sobald die Geheimhaltung der Ermittlung dies erlaubt. Der erste Schutz deiner Daten bleibt die Tatsache, dass sie nicht gesammelt werden, wenn sie nicht notwendig sind — deshalb steht die Datenminimierung (Abschnitt 2) im Zentrum unseres Designs. Das detaillierte Verfahren ist im Dokument INCIDENT_RESPONSE.md beschrieben, das in unserem Repository veröffentlicht ist.',
    ],
    'privacy.subtitle': [
      'Wie AnarBib Ihre persönlichen Daten schützt',
      'Wie AnarBib deine persönlichen Daten schützt',
    ],
    'privacy.video.body': [
      'Einige Video-Tutorials werden auf kolektiva.media gehostet, einer aktivistischen PeerTube-Instanz. Zum Schutz Ihrer Privatsphäre werden diese Videos nicht automatisch geladen: Solange Sie nicht auf «Video laden» klicken, wird nichts an kolektiva.media gesendet. Ab diesem Klick erhält kolektiva.media Ihre IP-Adresse – wie jede Website, die Sie besuchen –, um Ihnen das Video auszuliefern. Wir haben das P2P-Teilen bei diesen Videos deaktiviert, damit Ihre IP nicht anderen Zuschauer*innen oder Drittservern preisgegeben wird.',
      'Einige Video-Tutorials werden auf kolektiva.media gehostet, einer aktivistischen PeerTube-Instanz. Zum Schutz deiner Privatsphäre werden diese Videos nicht automatisch geladen: Solange du nicht auf «Video laden» klickst, wird nichts an kolektiva.media gesendet. Ab diesem Klick erhält kolektiva.media deine IP-Adresse – wie jede Website, die du besuchst –, um dir das Video auszuliefern. Wir haben das P2P-Teilen bei diesen Videos deaktiviert, damit deine IP nicht anderen Zuschauer*innen oder Drittservern preisgegeben wird.',
    ],
    'reader.external.notice': [
      'Diese Ressource wird außerhalb des AnarBib-Netzwerks gehostet. Sie werden zur ursprünglichen Website weitergeleitet, um sie einzusehen.',
      'Diese Ressource wird außerhalb des AnarBib-Netzwerks gehostet. Du wirst zur ursprünglichen Website weitergeleitet, um sie einzusehen.',
    ],
    'reader.generic.notice': [
      'Dieses Format hat noch keinen integrierten Viewer auf der Plattform. Sie können es herunterladen oder in einem neuen Tab öffnen.',
      'Dieses Format hat noch keinen integrierten Viewer auf der Plattform. Du kannst es herunterladen oder in einem neuen Tab öffnen.',
    ],
    'rede.collectiveRemoval.propose.modal.motivationPlaceholder': [
      'Beschreiben Sie ausführlich die politischen Gründe für diesen Rückzugsvorschlag…',
      'Beschreibe ausführlich die politischen Gründe für diesen Rückzugsvorschlag…',
    ],
    'rede.collectiveRemoval.propose.modal.warning': [
      'Warnung: schwerwiegende politische Entscheidung. Die Einstimmigkeit der aktiven Administrator*innen (ausgenommen die Zielperson) ist erforderlich. Eine 7-tägige Karenzfrist gilt vor der Vollziehung. Vergewissern Sie sich, dass diese Position kollektiv geteilt wird.',
      'Warnung: schwerwiegende politische Entscheidung. Die Einstimmigkeit der aktiven Administrator*innen (ausgenommen die Zielperson) ist erforderlich. Eine 7-tägige Karenzfrist gilt vor der Vollziehung. Vergewissere dich, dass diese Position kollektiv geteilt wird.',
    ],
    'rede.cooptation.propose.modal.description': [
      'Die Kooptation ist eine kollektive politische Entscheidung. Die Einstimmigkeit der aktiven Netzwerk-Administrator*innen ist erforderlich. Vergewissern Sie sich, dass diese*r Genoss*in das kollektive Vertrauen des Netzwerks hat.',
      'Die Kooptation ist eine kollektive politische Entscheidung. Die Einstimmigkeit der aktiven Netzwerk-Administrator*innen ist erforderlich. Vergewissere dich, dass diese*r Genoss*in das kollektive Vertrauen des Netzwerks hat.',
    ],
    'rede.cooptation.propose.modal.motivationPlaceholder': [
      'Beschreiben Sie den militanten Werdegang der*s Genoss*in und den Grund für diesen Vorschlag…',
      'Beschreibe den militanten Werdegang der*s Genoss*in und den Grund für diesen Vorschlag…',
    ],
    'rede.cooptation.vote.discloseIdentityHint': [
      'Diese Wahl ist verpflichtend und wird bei jeder Abstimmung erfasst. Andere Administrator*innen sehen Ihre Identität immer.',
      'Diese Wahl ist verpflichtend und wird bei jeder Abstimmung erfasst. Andere Administrator*innen sehen deine Identität immer.',
    ],
    'rede.cooptation.vote.errors.discloseRequired': [
      'Ihre Wahl zur Identitätsoffenlegung ist verpflichtend.',
      'Deine Wahl zur Identitätsoffenlegung ist verpflichtend.',
    ],
    'rede.cooptation.vote.modal.description': [
      'Ihre Entscheidung ist entscheidend: Einstimmigkeit ist erforderlich. Eine einzige Gegenstimme beendet den Prozess.',
      'Deine Entscheidung ist entscheidend: Einstimmigkeit ist erforderlich. Eine einzige Gegenstimme beendet den Prozess.',
    ],
    'rede.cooptation.vote.rationalePlaceholder': [
      'Erläutern Sie die politischen Gründe Ihrer Ablehnung…',
      'Erläutere die politischen Gründe deiner Ablehnung…',
    ],
    'reservation.nextStep.pronta_para_retirada': [
      'Das Dokument ist bereit. Holen Sie es vor Ablauf der Frist ab.',
      'Das Dokument ist bereit. Hol es vor Ablauf der Frist ab.',
    ],
    'reservation.nextStep.retirada_agendada': [
      'Bestätigen oder lehnen Sie den vorgeschlagenen Termin ab.',
      'Bestätige den vorgeschlagenen Termin oder lehne ihn ab.',
    ],
    'reservation.nextStep.solicitada': [
      'Das Bibliotheksteam wird Ihre Anfrage bald prüfen.',
      'Das Bibliotheksteam wird deine Anfrage bald prüfen.',
    ],
    'reservation.pickup.confirmed': [
      'Sie haben diesen Termin bestätigt',
      'Du hast diesen Termin bestätigt',
    ],
    'reservation.pickup.refused': [
      'Sie haben eine Verhinderung gemeldet',
      'Du hast eine Verhinderung gemeldet',
    ],
    'cartografia.add.consent': [
      'Meldet nur eure eigene Bibliothek. Nichts erscheint öffentlich ohne Prüfung durch die Koordination und euer Einverständnis.',
      'Melde nur deine eigene Bibliothek. Nichts erscheint öffentlich ohne Prüfung durch die Koordination und dein Einverständnis.',
    ],
    'catalogacao.dedup.reportPlaceholder': [
      'Was Ihnen aufgefallen ist (optional)',
      'Was dir aufgefallen ist (optional)',
    ],
    'catalogacao.dedup.arbiterOnly': [
      'Zusammenführen und Ausschließen sind der Koordination vorbehalten. Sie können zwei Ausgaben desselben Werks gruppieren oder das Paar melden.',
      'Zusammenführen und Ausschließen sind der Koordination vorbehalten. Du kannst zwei Ausgaben desselben Werks gruppieren oder das Paar melden.',
    ],
    'atelier.revue.retained': [
      'Ihre Korrektur',
      'Deine Korrektur',
    ],
    'panel.apiError.too_soon': [
      'Zu früh: derselbe Vorgang ist gerade gelaufen. Versuchen Sie es in einer Minute erneut.',
      'Zu früh: derselbe Vorgang ist gerade gelaufen. Versuche es in einer Minute erneut.',
    ],
    'conta.demande.intro': [
      'Der Beitrittsantrag Ihrer Bibliothek zum Netzwerk und Ihr Austausch mit der Netzwerkverwaltung während der Prüfung.',
      'Der Beitrittsantrag deiner Bibliothek zum Netzwerk und dein Austausch mit der Netzwerkverwaltung während der Prüfung.',
    ],
    'rede.reviews.intro': [
      'Ein aus einem Import entstandenes Los wird erst nach Ihrer Genehmigung veröffentlicht. Bericht lesen, entscheiden, Nacharbeit begründen.',
      'Ein aus einem Import entstandenes Los wird erst nach deiner Genehmigung veröffentlicht. Bericht lesen, entscheiden, Nacharbeit begründen.',
    ],
    'rede.reviews.notes': [
      'Ihre Anmerkungen',
      'Deine Anmerkungen',
    ],
    'notif.review.approved.body': [
      'Die Verwaltung hat die Prüfung Ihres Loses genehmigt: die Veröffentlichung ist frei.',
      'Die Verwaltung hat die Prüfung deines Loses genehmigt: die Veröffentlichung ist frei.',
    ],
    'relatar.intro': [
      'Hat etwas nicht funktioniert, oder nicht wie erwartet? Beschreiben Sie es hier, ohne Konto und ohne Codeberg. Die Personen, die das Netzwerk verwalten, erhalten Ihre Meldung per E-Mail.',
      'Hat etwas nicht funktioniert, oder nicht wie erwartet? Beschreib es hier, ohne Konto und ohne Codeberg. Die Personen, die das Netzwerk verwalten, erhalten deine Meldung per E-Mail.',
    ],
    'relatar.whatHint': [
      'Mindestens zehn Zeichen. Was Sie auf dem Bildschirm gesehen haben, die genaue Meldung, falls es eine gab.',
      'Mindestens zehn Zeichen. Was du auf dem Bildschirm gesehen hast, die genaue Meldung, falls es eine gab.',
    ],
    'relatar.expected': [
      'Was Sie erwartet haben (optional)',
      'Was du erwartet hast (optional)',
    ],
    'relatar.email': [
      'Ihre E-Mail-Adresse (optional)',
      'Deine E-Mail-Adresse (optional)',
    ],
    'relatar.emailHint': [
      'Nur, um Ihnen zu bestätigen, dass die Meldung angekommen ist. Eine automatische Rückmeldung gibt es nicht.',
      'Nur, um dir zu bestätigen, dass die Meldung angekommen ist. Eine automatische Rückmeldung gibt es nicht.',
    ],
    'relatar.context': [
      'Mitgesendet: die Ausgangsseite ({page}), Ihre Sprache und, falls angemeldet, Ihre Rolle und Bibliothek.',
      'Mitgesendet: die Ausgangsseite ({page}), deine Sprache und, falls angemeldet, deine Rolle und Bibliothek.',
    ],
    'relatar.consent': [
      'Schreiben Sie hier niemals ein Passwort. Was Sie schreiben, wird von Menschen gelesen, nicht veröffentlicht.',
      'Schreib hier niemals ein Passwort. Was du schreibst, wird von Menschen gelesen, nicht veröffentlicht.',
    ],
    'relatar.success': [
      'Angekommen, danke. Die Personen, die das Netzwerk verwalten, werden Ihre Meldung lesen.',
      'Angekommen, danke. Die Personen, die das Netzwerk verwalten, werden deine Meldung lesen.',
    ],
    'relatar.error': [
      'Das Senden ist fehlgeschlagen. Bitte versuchen Sie es gleich noch einmal.',
      'Das Senden ist fehlgeschlagen. Bitte versuche es gleich noch einmal.',
    ],
    'catalogacao.ui.coverIsbnEcart': [
      'Diese ISBN gehört zur Ausgabe {trouvee}; der Datensatz nennt {notice}. Nachdruck, andere Ausgabe oder falsche ISBN: Bitte prüfen Sie das, bevor Sie dieses Cover wählen.',
      'Diese ISBN gehört zur Ausgabe {trouvee}; der Datensatz nennt {notice}. Nachdruck, andere Ausgabe oder falsche ISBN: Bitte prüfe das, bevor du dieses Cover wählst.',
    ],
    'catalogacao.ui.coverIsbnVolume': [
      'Datensatz zu Band {volume}: Die ISBN eines mehrbändigen Werks gilt oft für alle Bände. Bitte prüfen Sie, ob dieses Cover wirklich zu Band {volume} gehört.',
      'Datensatz zu Band {volume}: Die ISBN eines mehrbändigen Werks gilt oft für alle Bände. Bitte prüfe, ob dieses Cover wirklich zu Band {volume} gehört.',
    ],
    'error.capas.hors_perimetre': [
      'Keine Ihrer Bibliotheken besitzt oder führt diesen Datensatz.',
      'Keine deiner Bibliotheken besitzt oder führt diesen Datensatz.',
    ],
    'error.capas.proposition_close': [
      'Dieser Vorschlag wurde bereits bearbeitet, vielleicht von jemand anderem. Bitte laden Sie die Liste neu.',
      'Dieser Vorschlag wurde bereits bearbeitet, vielleicht von jemand anderem. Bitte lade die Liste neu.',
    ],
    'capas.photo.dejaUneCapa': [
      'Dieser Datensatz hat bereits ein Cover: Ihr Foto ersetzt es.',
      'Dieser Datensatz hat bereits ein Cover: dein Foto ersetzt es.',
    ],
  },
  'el': {
    'subject.viewBooks': [
      '{count, plural, =0 {Δείτε τα βιβλία} one {Δείτε # βιβλίο} other {Δείτε # βιβλία}}',
      '{count, plural, =0 {Δες τα βιβλία} one {Δες # βιβλίο} other {Δες # βιβλία}}',
    ],
    'subject.related': [
      'Δείτε επίσης',
      'Δες επίσης',
    ],
    'catalog.related.subjects': [
      'Δείτε επίσης',
      'Δες επίσης',
    ],
    'catalogacao.subjectGov.relTitle': [
      'Δείτε επίσης (σχετικά θέματα)',
      'Δες επίσης (σχετικά θέματα)',
    ],
    'bibliotecaPublica.viewOnMap': [
      'Δείτε στον χάρτη',
      'Δες στον χάρτη',
    ],
    'account.partnerships.hint': [
      'Είστε μέλος δύο συνεργαζόμενων βιβλιοθηκών. Μπορείτε να επιτρέψετε (ή να αρνηθείτε) να μοιράζονται πληροφορίες για τη συμμετοχή σας. Άμεση ισχύς, ανακλητό ανά πάσα στιγμή.',
      'Είσαι μέλος δύο συνεργαζόμενων βιβλιοθηκών. Μπορείς να επιτρέψεις (ή να αρνηθείς) να μοιράζονται πληροφορίες για τη συμμετοχή σου. Άμεση ισχύς, ανακλητό ανά πάσα στιγμή.',
    ],
    'account.partnerships.state.valid': [
      'Κοινοποιείται (συναινέσατε)',
      'Κοινοποιείται (συναίνεσες)',
    ],
    'account.tutorials.hint': [
      'Σύντομα βίντεο για να ξεκινήσετε. Υπότιτλοι διαθέσιμοι σε 10 γλώσσες (κουμπί CC του player).',
      'Σύντομα βίντεο για να ξεκινήσεις. Υπότιτλοι διαθέσιμοι σε 10 γλώσσες (κουμπί CC του player).',
    ],
    'atelier.volet4.classif.thematic': [
      'Δική σας θεματική ταξινόμηση',
      'Δική σου θεματική ταξινόμηση',
    ],
    'biblioteca.extPartner.dupHint': [
      'Παρόμοιοι εταίροι ήδη καταχωρισμένοι — ελέγξτε πριν δημιουργήσετε διπλότυπο:',
      'Παρόμοιοι εταίροι ήδη καταχωρισμένοι — έλεγξε πριν δημιουργήσεις διπλότυπο:',
    ],
    'biblioteca.extPartner.hint': [
      'Καταχωρίστε ένα εξωτερικό συλλογικό σχήμα (που παρέδωσε τον κατάλογό του ως αρχείο, π.χ. εξαγωγή Zotero). Θα δημιουργηθεί ως οντότητα εταίρου και θα γίνει διαθέσιμη πηγή κατά την εισαγωγή.',
      'Καταχώρισε ένα εξωτερικό συλλογικό σχήμα (που παρέδωσε τον κατάλογό του ως αρχείο, π.χ. εξαγωγή Zotero). Θα δημιουργηθεί ως οντότητα εταίρου και θα γίνει διαθέσιμη πηγή κατά την εισαγωγή.',
    ],
    'biblioteca.report.noWeeklyEmail': [
      'Ορίστε email για την εβδομαδιαία αναφορά στην καρτέλα Επικοινωνία.',
      'Όρισε email για την εβδομαδιαία αναφορά στην καρτέλα Επικοινωνία.',
    ],
    'biblioteca.stabPartners.selectLibrary': [
      'Επιλέξτε βιβλιοθήκη…',
      'Επίλεξε βιβλιοθήκη…',
    ],
    'biblioteca.publicFiche.collective': [
      'Η δημοσιοποίηση πληροφοριών αφορά τη συλλογικότητα — αποφασίστε μαζί.',
      'Η δημοσιοποίηση πληροφοριών αφορά τη συλλογικότητα — να αποφασιστεί από κοινού.',
    ],
    'card.resolve.error.card_revoked': [
      'Αυτή η κάρτα αντικαταστάθηκε από νεότερη. Ζητήστε μια ενημερωμένη κάρτα.',
      'Αυτή η κάρτα αντικαταστάθηκε από νεότερη. Ζήτησε μια ενημερωμένη κάρτα.',
    ],
    'card.resolve.scan.error.generic': [
      'Δεν ήταν δυνατό το άνοιγμα της κάμερας. Πληκτρολογήστε τον κωδικό με το χέρι.',
      'Δεν ήταν δυνατό το άνοιγμα της κάμερας. Πληκτρολόγησε τον κωδικό με το χέρι.',
    ],
    'card.resolve.scan.error.nocamera': [
      'Δεν βρέθηκε κάμερα. Πληκτρολογήστε τον κωδικό με το χέρι.',
      'Δεν βρέθηκε κάμερα. Πληκτρολόγησε τον κωδικό με το χέρι.',
    ],
    'card.resolve.scan.error.permission': [
      'Η πρόσβαση στην κάμερα απορρίφθηκε. Επιτρέψτε την για σάρωση ή πληκτρολογήστε τον κωδικό.',
      'Η πρόσβαση στην κάμερα απορρίφθηκε. Επίτρεψέ την για σάρωση ή πληκτρολόγησε τον κωδικό.',
    ],
    'card.resolve.scan.error.unsupported': [
      'Η σάρωση δεν υποστηρίζεται από αυτό το πρόγραμμα περιήγησης. Πληκτρολογήστε τον κωδικό με το χέρι.',
      'Η σάρωση δεν υποστηρίζεται από αυτό το πρόγραμμα περιήγησης. Πληκτρολόγησε τον κωδικό με το χέρι.',
    ],
    'card.resolve.scan.prompt': [
      'Στρέψτε στο QR της κάρτας',
      'Στρέψε στο QR της κάρτας',
    ],
    'catalogacao.authlink.needName': [
      'Εισάγετε ένα όνομα πριν την αναζήτηση.',
      'Γράψε ένα όνομα πριν την αναζήτηση.',
    ],
    'catalogacao.author.cropHint': [
      'Σύρετε για να τοποθετήσετε το πρόσωπο και χρησιμοποιήστε τον ρυθμιστή για μεγέθυνση. Μορφή 3×4.',
      'Σύρε για να τοποθετήσεις το πρόσωπο και χρησιμοποίησε τον ρυθμιστή για μεγέθυνση. Μορφή 3×4.',
    ],
    'catalogacao.author.nameRequired': [
      'Εισάγετε το προτιμώμενο όνομα.',
      'Γράψε το προτιμώμενο όνομα.',
    ],
    'catalogacao.author.portraitNeedName': [
      'Δώστε όνομα ή Wikidata ID.',
      'Δώσε όνομα ή Wikidata ID.',
    ],
    'catalogacao.author.sourceKind.select': [
      'Επιλέξτε…',
      'Επίλεξε…',
    ],
    'catalogacao.authority.clickToLink': [
      'Κάντε κλικ σε ένα αποτέλεσμα για να συνδέσετε την αρχή και να συμπληρώσετε VIAF/ISNI/εναλλακτικές μορφές.',
      'Κάνε κλικ σε ένα αποτέλεσμα για να συνδέσεις την αρχή και να συμπληρώσεις VIAF/ISNI/εναλλακτικές μορφές.',
    ],
    'catalogacao.authority.needName': [
      'Εισάγετε το προτιμώμενο όνομα πριν αναζητήσετε αρχή.',
      'Γράψε το προτιμώμενο όνομα πριν αναζητήσεις αρχή.',
    ],
    'catalogacao.batchHasDrafts': [
      'Αυτή η παρτίδα έχει ακόμα {count} πρόσχεδιο/α. Διαγράψτε τα πριν διαγράψετε την παρτίδα.',
      'Αυτή η παρτίδα έχει ακόμα {count} πρόσχεδιο/α. Διάγραψέ τα πριν διαγράψεις την παρτίδα.',
    ],
    'catalogacao.catalog.description': [
      'Περιηγηθείτε δημοσιευμένα έγγραφα, αρχεία και αντίτυπα.',
      'Περιηγήσου στα δημοσιευμένα έγγραφα, αρχεία και αντίτυπα.',
    ],
    'catalogacao.catalog.refreshBusy': [
      'Η ανανέωση είναι ήδη σε εξέλιξη — δοκιμάστε ξανά σε λίγο.',
      'Η ανανέωση είναι ήδη σε εξέλιξη — δοκίμασε ξανά σε λίγο.',
    ],
    'catalogacao.catalog.retakeCreatedNoEdit': [
      'Προσχέδιο επανάληψης δημιουργήθηκε (ID {id}). Ανοίξτε την αντίστοιχη καρτέλα.',
      'Προσχέδιο επανάληψης δημιουργήθηκε (ID {id}). Άνοιξε την αντίστοιχη καρτέλα.',
    ],
    'catalogacao.digital.empty': [
      'Κανένας ψηφιακός πόρος δεν είναι συνδεδεμένος. Κάντε κλικ στο «+ Νέος πόρος» για να προσθέσετε.',
      'Κανένας ψηφιακός πόρος δεν είναι συνδεδεμένος. Κάνε κλικ στο «+ Νέος πόρος» για να προσθέσεις.',
    ],
    'catalogacao.digital.bucketScopeMismatch': [
      'Ο κάδος αποθήκευσης ({actual}) δεν αντιστοιχεί στο επιλεγμένο εύρος πρόσβασης, που απαιτεί {expected}. Ανεβάστε ξανά το αρχείο αφού ορίσετε το εύρος — ο περιορισμός επιβάλλεται από τον κάδο, όχι από την ετικέτα.',
      'Ο κάδος αποθήκευσης ({actual}) δεν αντιστοιχεί στο επιλεγμένο εύρος πρόσβασης, που απαιτεί {expected}. Ανέβασε ξανά το αρχείο αφού ορίσεις το εύρος — ο περιορισμός επιβάλλεται από τον κάδο, όχι από την ετικέτα.',
    ],
    'catalogacao.exemplar.autoExemplarInfo': [
      'Κατά τη δημοσίευση ενός νέου εγγράφου, δημιουργείται αυτόματα ένα αντίτυπο με τη βιβλιογραφική αναφορά (bib_ref) ως αριθμό εισαγωγής. Χρησιμοποιήστε αυτή τη φόρμα μόνο για να προσθέσετε επιπλέον αντίτυπα ή να τροποποιήσετε ένα υπάρχον αντίτυπο.',
      'Κατά τη δημοσίευση ενός νέου εγγράφου, δημιουργείται αυτόματα ένα αντίτυπο με τη βιβλιογραφική αναφορά (bib_ref) ως αριθμό εισαγωγής. Χρησιμοποίησε αυτή τη φόρμα μόνο για να προσθέσεις επιπλέον αντίτυπα ή να τροποποιήσεις ένα υπάρχον αντίτυπο.',
    ],
    'catalogacao.exemplar.bibRefHint': [
      'Εισάγετε και αφήστε το πεδίο.',
      'Γράψε και άφησε το πεδίο.',
    ],
    'catalogacao.exemplar.labelMarked': [
      'Η ετικέτα σημειώθηκε. Αποθηκεύστε.',
      'Η ετικέτα σημειώθηκε. Αποθήκευσε.',
    ],
    'catalogacao.exemplar.labelNeedFields': [
      'Συμπληρώστε τουλάχιστον συγγραφέα, τίτλο ή CDD.',
      'Συμπλήρωσε τουλάχιστον συγγραφέα, τίτλο ή CDD.',
    ],
    'catalogacao.exemplar.labelStepDesc': [
      'Η ετικέτα υπολογίζεται. Αντικαταστήστε μόνο αν χρειάζεται.',
      'Η ετικέτα υπολογίζεται. Αντικατάστησε μόνο αν χρειάζεται.',
    ],
    'catalogacao.exemplar.materialStepDesc': [
      'Αναγνωρίστε το φυσικό αντικείμενο.',
      'Αναγνώρισε το φυσικό αντικείμενο.',
    ],
    'catalogacao.exemplar.originStepDesc': [
      'Βρείτε τη δημοσιευμένη κοινή κάρτα.',
      'Βρες τη δημοσιευμένη κοινή κάρτα.',
    ],
    'catalogacao.exemplar.refOrTomboRequired': [
      'Εισάγετε τουλάχιστον την αναφορά.',
      'Γράψε τουλάχιστον την αναφορά.',
    ],
    'catalogacao.infocard.exemplarUnsaved': [
      'Αποθηκεύστε την καρτέλα για διαχείριση αντιτύπων',
      'Αποθήκευσε την καρτέλα για διαχείριση αντιτύπων',
    ],
    'catalogacao.isbd.notGenerated': [
      'ISBD: δεν έχει δημιουργηθεί ακόμα. Κάντε κλικ στο "Prepare ISBD" παραπάνω.',
      'ISBD: δεν έχει δημιουργηθεί ακόμα. Κάνε κλικ στο "Prepare ISBD" παραπάνω.',
    ],
    'catalogacao.isbn.scan.prompt': [
      'Στρέψτε στο barcode ISBN του βιβλίου',
      'Στρέψε στο barcode ISBN του βιβλίου',
    ],
    'catalogacao.msg.bibRefDuplicate': [
      'Η βιβλιογραφική αναφορά {bibRef} χρησιμοποιείται ήδη (εγγραφή {bookId}). Αλλάξτε την πριν τη δημοσίευση.',
      'Η βιβλιογραφική αναφορά {bibRef} χρησιμοποιείται ήδη (εγγραφή {bookId}). Άλλαξέ την πριν τη δημοσίευση.',
    ],
    'catalogacao.msg.needIsbnForBn': [
      'Εισάγετε ένα ISBN πριν την αναζήτηση στην Εθνική Βιβλιοθήκη.',
      'Γράψε ένα ISBN πριν την αναζήτηση στην Εθνική Βιβλιοθήκη.',
    ],
    'catalogacao.msg.needIssn': [
      'Εισάγετε ένα ISSN.',
      'Γράψε ένα ISSN.',
    ],
    'catalogacao.msg.needPathOrUrl': [
      'Εισάγετε τουλάχιστον μια διαδρομή αποθήκευσης ή ένα URL πηγής.',
      'Γράψε τουλάχιστον μια διαδρομή αποθήκευσης ή ένα URL πηγής.',
    ],
    'catalogacao.msg.saveBeforeDigital': [
      'Αποθηκεύστε πρώτα το πρόχειρο πριν συνδέσετε ψηφιακό πόρο.',
      'Αποθήκευσε πρώτα το πρόχειρο πριν συνδέσεις ψηφιακό πόρο.',
    ],
    'catalogacao.msg.saveBeforePublish': [
      'Αποθηκεύστε το πρόχειρο πριν τη δημοσίευση.',
      'Αποθήκευσε το πρόχειρο πριν τη δημοσίευση.',
    ],
    'catalogacao.noBatches': [
      'Δεν βρέθηκαν παρτίδες. Δημιουργήστε την πρώτη παρτίδα παραπάνω.',
      'Δεν βρέθηκαν παρτίδες. Δημιούργησε την πρώτη παρτίδα παραπάνω.',
    ],
    'catalogacao.preview.explain': [
      'Έτσι θα εμφανίζεται η εγγραφή στον κατάλογο. Ενημερώνεται καθώς πληκτρολογείτε.',
      'Έτσι θα εμφανίζεται η εγγραφή στον κατάλογο. Ενημερώνεται καθώς πληκτρολογείς.',
    ],
    'catalogacao.queue.selectAtLeast': [
      'Επιλέξτε τουλάχιστον ένα στοιχείο.',
      'Επίλεξε τουλάχιστον ένα στοιχείο.',
    ],
    'catalogacao.queue.trashDescription': [
      'Απορριφθέντα προσχέδια. Μπορείτε να επαναφέρετε ή να διαγράψετε οριστικά.',
      'Απορριφθέντα προσχέδια. Μπορείς να επαναφέρεις ή να διαγράψεις οριστικά.',
    ],
    'catalogacao.reassign.multiHint': [
      'Αυτή η εγγραφή έχει αντίτυπα σε πολλές βιβλιοθήκες· επιλέξτε ποια θα μετακινηθούν.',
      'Αυτή η εγγραφή έχει αντίτυπα σε πολλές βιβλιοθήκες· επίλεξε ποια θα μετακινηθούν.',
    ],
    'catalogacao.reassign.placeholder': [
      'Επιλέξτε βιβλιοθήκη…',
      'Επίλεξε βιβλιοθήκη…',
    ],
    'catalogacao.reassign.sourcePick': [
      'Επιλέξτε τη βιβλιοθήκη προέλευσης…',
      'Επίλεξε τη βιβλιοθήκη προέλευσης…',
    ],
    'catalogacao.subjects.saveFirst': [
      'Αποθηκεύστε το πρόχειρο για ευρετηρίαση κατά θέμα.',
      'Αποθήκευσε το πρόχειρο για ευρετηρίαση κατά θέμα.',
    ],
    'catalogacao.ui.bnApplyHint': [
      'Κάντε κλικ σε ένα αποτέλεσμα για να το εφαρμόσετε στα κενά πεδία.',
      'Κάνε κλικ σε ένα αποτέλεσμα για να το εφαρμόσεις στα κενά πεδία.',
    ],
    'catalogacao.wizard.step.autoria.body': [
      'Διαχειριστείτε συγγραφείς (πρόσωπα και οργανισμούς) που συνδέονται με έγγραφα. Κάθε συγγραφέας που δημιουργείται εδώ μπορεί να συσχετιστεί με πολλά βιβλία και αντίστροφα.',
      'Διαχειρίσου συγγραφείς (πρόσωπα και οργανισμούς) που συνδέονται με έγγραφα. Κάθε συγγραφέας που δημιουργείται εδώ μπορεί να συσχετιστεί με πολλά βιβλία και αντίστροφα.',
    ],
    'catalogacao.wizard.step.autoria.tip': [
      'Η αυτόματη συμπλήρωση προτείνει υπάρχοντες συγγραφείς καθώς πληκτρολογείτε — αποφύγετε τα διπλότυπα!',
      'Η αυτόματη συμπλήρωση προτείνει υπάρχοντες συγγραφείς καθώς πληκτρολογείς — απόφυγε τα διπλότυπα!',
    ],
    'catalogacao.wizard.step.dicas.body': [
      '• Ο αριθμός εισαγωγής (tombo) συμπληρώνεται αυτόματα σύμφωνα με τη σύμβαση της βιβλιοθήκης σας.\n• Κατά τη δημοσίευση ενός εγγράφου, δημιουργείται αυτόματα ένα αντίτυπο.\n• Τα μηνύματα σφάλματος εμφανίζονται δίπλα στο σχετικό πεδίο.\n• Εναλλάξτε μεταξύ των λειτουργιών Απλή / Προχωρημένη / Πλήρης στην επάνω γραμμή για να εμφανίσετε περισσότερα ή λιγότερα πεδία.',
      '• Ο αριθμός εισαγωγής (tombo) συμπληρώνεται αυτόματα σύμφωνα με τη σύμβαση της βιβλιοθήκης σου.\n• Κατά τη δημοσίευση ενός εγγράφου, δημιουργείται αυτόματα ένα αντίτυπο.\n• Τα μηνύματα σφάλματος εμφανίζονται δίπλα στο σχετικό πεδίο.\n• Άλλαξε μεταξύ των λειτουργιών Απλή / Προχωρημένη / Πλήρης στην επάνω γραμμή για να εμφανίσεις περισσότερα ή λιγότερα πεδία.',
    ],
    'catalogacao.wizard.step.documento.body': [
      'Δημιουργήστε και επεξεργαστείτε βιβλιογραφικές εγγραφές (βιβλία, φυλλάδια, περιοδικά…). Συμπληρώστε τον τίτλο, τον συγγραφέα, το ISBN, τον τύπο υλικού και τη βιβλιογραφική αναφορά. Χρησιμοποιήστε τη λειτουργία Απλή για τα βασικά ή Πλήρης για όλα τα πεδία.',
      'Δημιούργησε και επεξεργάσου βιβλιογραφικές εγγραφές (βιβλία, φυλλάδια, περιοδικά…). Συμπλήρωσε τον τίτλο, τον συγγραφέα, το ISBN, τον τύπο υλικού και τη βιβλιογραφική αναφορά. Χρησιμοποίησε τη λειτουργία Απλή για τα βασικά ή Πλήρης για όλα τα πεδία.',
    ],
    'catalogacao.wizard.step.etiquetas.body': [
      'Εκτυπώστε ετικέτες ράχης για τα αντίτυπα της βιβλιοθήκης σας. Επιλέξτε αντίτυπα από τη λίστα, διαλέξτε ποια πεδία θα συμπεριληφθούν (συγγραφέας, τίτλος, αριθμός εισαγωγής, σημείωση) και δημιουργήστε ένα φύλλο A4 έτοιμο για εκτύπωση, με προαιρετικό κωδικό QR.',
      'Εκτύπωσε ετικέτες ράχης για τα αντίτυπα της βιβλιοθήκης σου. Επίλεξε αντίτυπα από τη λίστα, διάλεξε ποια πεδία θα συμπεριληφθούν (συγγραφέας, τίτλος, αριθμός εισαγωγής, σημείωση) και δημιούργησε ένα φύλλο A4 έτοιμο για εκτύπωση, με προαιρετικό κωδικό QR.',
    ],
    'catalogacao.wizard.step.etiquetas.tip': [
      'Οι προτιμήσεις πεδίων σας αποθηκεύονται αυτόματα — δεν χρειάζεται επαναρρύθμιση κάθε φορά.',
      'Οι προτιμήσεις πεδίων σου αποθηκεύονται αυτόματα — δεν χρειάζεται επαναρρύθμιση κάθε φορά.',
    ],
    'catalogacao.wizard.step.indexacao.body': [
      'Καταχωρίστε αντίτυπα (φυσικά αντίγραφα) που συνδέονται με ένα έγγραφο. Κάθε αντίτυπο έχει αριθμό εισαγωγής (tombo), πολιτική δανεισμού και ετικέτα για τη ράχη.',
      'Καταχώρισε αντίτυπα (φυσικά αντίγραφα) που συνδέονται με ένα έγγραφο. Κάθε αντίτυπο έχει αριθμό εισαγωγής (tombo), πολιτική δανεισμού και ετικέτα για τη ράχη.',
    ],
    'catalogacao.wizard.step.indexacao.tip': [
      'Το πεδίο Tombo συμπληρώνεται αυτόματα με την επόμενη αναφορά σύμφωνα με τη σύμβαση της βιβλιοθήκης σας.',
      'Το πεδίο Tombo συμπληρώνεται αυτόματα με την επόμενη αναφορά σύμφωνα με τη σύμβαση της βιβλιοθήκης σου.',
    ],
    'catalogacao.wizard.step.welcome.body': [
      'Αυτός ο οδηγός παρουσιάζει τις κύριες λειτουργίες της ενότητας καταλογογράφησης. Πλοηγηθείτε στα βήματα για να ανακαλύψετε κάθε καρτέλα και τα εργαλεία της.',
      'Αυτός ο οδηγός παρουσιάζει τις κύριες λειτουργίες της ενότητας καταλογογράφησης. Πλοηγήσου στα βήματα για να ανακαλύψεις κάθε καρτέλα και τα εργαλεία της.',
    ],
    'catalogacao.wizard.step.welcome.title': [
      'Καλώς ήρθατε στην Καταλογογράφηση!',
      'Καλώς ήρθες στην Καταλογογράφηση!',
    ],
    'common.error.system': [
      'Παρουσιάστηκε τεχνικό σφάλμα. Δοκιμάστε ξανά· αν συνεχιστεί, ενημερώστε την ομάδα.',
      'Παρουσιάστηκε τεχνικό σφάλμα. Δοκίμασε ξανά· αν συνεχιστεί, ενημέρωσε την ομάδα.',
    ],
    'digishare.inactive': [
      'Ενεργοποιήστε το δικαίωμα « ψηφιακή κοινοποίηση » σε μια σύμπραξη (ενότητα Συμπράξεις) για να χρησιμοποιήσετε αυτή τη λειτουργία.',
      'Ενεργοποίησε το δικαίωμα « ψηφιακή κοινοποίηση » σε μια σύμπραξη (ενότητα Συμπράξεις) για να χρησιμοποιήσεις αυτή τη λειτουργία.',
    ],
    'error.publish.tombo_duplicate': [
      'Αυτός ο αριθμός καταχώρισης (tombo) χρησιμοποιείται ήδη από άλλο αντίτυπο. Επιλέξτε άλλον.',
      'Αυτός ο αριθμός καταχώρισης (tombo) χρησιμοποιείται ήδη από άλλο αντίτυπο. Επίλεξε άλλον.',
    ],
    'federacao.carte.lead': [
      'Οι ελευθεριακές συλλογικότητες με βιβλιοθήκη σε όλο τον κόσμο. Το χρώμα του δείκτη δηλώνει τον τύπο του χώρου· κάντε κλικ σε ένα σημείο για λεπτομέρειες.',
      'Οι ελευθεριακές συλλογικότητες με βιβλιοθήκη σε όλο τον κόσμο. Το χρώμα του δείκτη δηλώνει τον τύπο του χώρου· κάνε κλικ σε ένα σημείο για λεπτομέρειες.',
    ],
    'federacao.circulos.dormancy.adormecer.done': [
      'Ο κύκλος τέθηκε σε αδράνεια. Μπορεί να αφυπνιστεί όποτε θέλετε.',
      'Ο κύκλος τέθηκε σε αδράνεια. Μπορεί να αφυπνιστεί όποτε θέλεις.',
    ],
    'federacao.inicio.pending': [
      'Τι σας περιμένει',
      'Τι σε περιμένει',
    ],
    'federacao.inicio.welcome': [
      'Καλώς ήρθατε στην ομοσπονδία',
      'Καλώς ήρθες στην ομοσπονδία',
    ],
    'importacoes.export.fonds.directNoPartner': [
      'Καμία συνεργαζόμενη βιβλιοθήκη με ενεργό το δικαίωμα « αμοιβαιοποίηση ». Ενεργοποιήστε το πρώτα σε μια σύμπραξη.',
      'Καμία συνεργαζόμενη βιβλιοθήκη με ενεργό το δικαίωμα « αμοιβαιοποίηση ». Ενεργοποίησέ το πρώτα σε μια σύμπραξη.',
    ],
    'importacoes.export.fonds.truncated': [
      'Η παρτίδα περικόπηκε (επιτεύχθηκε το όριο όγκου): {count} αρχεία περιλήφθηκαν. Περιορίστε την επιλογή για πλήρη εξαγωγή.',
      'Η παρτίδα περικόπηκε (επιτεύχθηκε το όριο όγκου): {count} αρχεία περιλήφθηκαν. Περιόρισε την επιλογή για πλήρη εξαγωγή.',
    ],
    'importacoes.fila.failed.desc': [
      'Αυτή η παρτίδα δεν μπόρεσε να επεξεργαστεί. Μπορείτε να την αρχειοθετήσετε ή να τη διαγράψετε στη λίστα παρτίδων.',
      'Αυτή η παρτίδα δεν μπόρεσε να επεξεργαστεί. Μπορείς να την αρχειοθετήσεις ή να τη διαγράψεις στη λίστα παρτίδων.',
    ],
    'importacoes.fila.gesturesHelp': [
      'Σε διπλότυπο: Δημιουργία αντιτύπου καταχωρεί το αντίτυπό σας στην υπάρχουσα εγγραφή· Απόρριψη απορρίπτει τα πάντα (μόνο αν δεν κατέχετε αυτό το τεκμήριο).',
      'Σε διπλότυπο: Δημιουργία αντιτύπου καταχωρεί το αντίτυπό σου στην υπάρχουσα εγγραφή· Απόρριψη απορρίπτει τα πάντα (μόνο αν δεν κατέχεις αυτό το τεκμήριο).',
    ],
    'importacoes.fila.processing.desc': [
      'Οι γραμμές αναλύονται ακόμη και αντιπαραβάλλονται με τον κατάλογο. Περιμένετε και ανανεώστε σε λίγο.',
      'Οι γραμμές αναλύονται ακόμη και αντιπαραβάλλονται με τον κατάλογο. Περίμενε και ανανέωσε σε λίγο.',
    ],
    'importacoes.fila.reconcileRowHint': [
      '→ Κατέχει η βιβλιοθήκη σας αυτό το τεκμήριο; Χρησιμοποιήστε Δημιουργία αντιτύπου (όχι Απόρριψη).',
      '→ Κατέχει η βιβλιοθήκη σου αυτό το τεκμήριο; Χρησιμοποίησε Δημιουργία αντιτύπου (όχι Απόρριψη).',
    ],
    'importacoes.fila.reconcileTitle': [
      'Καταχωρεί το αντίτυπό σας στην υπάρχουσα εγγραφή του καταλόγου, χωρίς να δημιουργεί διπλή εγγραφή.',
      'Καταχωρεί το αντίτυπό σου στην υπάρχουσα εγγραφή του καταλόγου, χωρίς να δημιουργεί διπλή εγγραφή.',
    ],
    'importacoes.fila.rejectHoldingsWarn': [
      'Προσοχή: {n} επιλεγμένη/ες γραμμή/ές είναι διπλότυπα ενός τεκμηρίου που υπάρχει ήδη στον κατάλογο — η βιβλιοθήκη σας δηλώνει ότι κατέχει ένα αντίτυπο. Η Απόρριψη απορρίπτει τη γραμμή και ΔΕΝ καταχωρεί αυτό το αντίτυπο. Αν η βιβλιοθήκη σας κατέχει αυτό το τεκμήριο, ακυρώστε και χρησιμοποιήστε το κουμπί Δημιουργία αντιτύπου. Απόρριψη παρ\' όλα αυτά;',
      'Προσοχή: {n} επιλεγμένη/ες γραμμή/ές είναι διπλότυπα ενός τεκμηρίου που υπάρχει ήδη στον κατάλογο — η βιβλιοθήκη σου δηλώνει ότι κατέχει ένα αντίτυπο. Η Απόρριψη απορρίπτει τη γραμμή και ΔΕΝ καταχωρεί αυτό το αντίτυπο. Αν η βιβλιοθήκη σου κατέχει αυτό το τεκμήριο, ακύρωσε και χρησιμοποίησε το κουμπί Δημιουργία αντιτύπου. Απόρριψη παρ\' όλα αυτά;',
    ],
    'importacoes.fila.rejectTitle': [
      'Απορρίπτει τη γραμμή (ούτε εγγραφή, ούτε αντίτυπο). Χρησιμοποιήστε το μόνο για ψευδές διπλότυπο ή τεκμήριο που δεν κατέχει η βιβλιοθήκη σας.',
      'Απορρίπτει τη γραμμή (ούτε εγγραφή, ούτε αντίτυπο). Χρησιμοποίησέ το μόνο για ψευδές διπλότυπο ή τεκμήριο που δεν κατέχει η βιβλιοθήκη σου.',
    ],
    'importacoes.fila.selectRun': [
      'Επιλέξτε μια επεξεργασία παραπάνω για να δείτε τις γραμμές αναθεώρησης.',
      'Επίλεξε μια επεξεργασία παραπάνω για να δεις τις γραμμές αναθεώρησης.',
    ],
    'importacoes.fontes.noCompanheiras': [
      'Καμία συντρόφισσα βιβλιοθήκη δεν είναι καταχωρημένη. Δημιουργήστε μια σχέση συνεργασίας για να ενεργοποιήσετε την αμοιβαία εισαγωγή.',
      'Καμία συντρόφισσα βιβλιοθήκη δεν είναι καταχωρημένη. Δημιούργησε μια σχέση συνεργασίας για να ενεργοποιήσεις την αμοιβαία εισαγωγή.',
    ],
    'importacoes.oai.noSources': [
      'Δεν εχουν ρυθμιστει πηγες OAI-PMH. Επικοινωνηστε με τον διαχειριστη δικτυου.',
      'Δεν έχουν ρυθμιστεί πηγές OAI-PMH. Επικοινώνησε με τον διαχειριστή δικτύου.',
    ],
    'importacoes.wizard.preview.dupBody': [
      'Σε έναν κοινό κατάλογο, η δημιουργία διπλότυπου προκαλεί σοβαρές ασυνέπειες. Αυτές οι γραμμές ΔΕΝ θα προαχθούν αυτόματα — ελέγξτε τες και προτιμήστε τη σύνδεση με την υπάρχουσα εγγραφή.',
      'Σε έναν κοινό κατάλογο, η δημιουργία διπλότυπου προκαλεί σοβαρές ασυνέπειες. Αυτές οι γραμμές ΔΕΝ θα προαχθούν αυτόματα — έλεγξέ τες και προτίμησε τη σύνδεση με την υπάρχουσα εγγραφή.',
    ],
    'importacoes.wizard.promote.heldBack': [
      '{n} γραμμή/ές σε αναμονή, δεν προήχθησαν (πιθανά διπλότυπα ή προς έλεγχο) — χειριστείτε τες χειροκίνητα για αποφυγή ασυνεπειών.',
      '{n} γραμμή/ές σε αναμονή, δεν προήχθησαν (πιθανά διπλότυπα ή προς έλεγχο) — χειρίσου τες χειροκίνητα για αποφυγή ασυνεπειών.',
    ],
    'importacoes.wizard.source.ingested': [
      'Η εγγραφή εισήχθη. Πηγαίνετε στην προεπισκόπηση.',
      'Η εγγραφή εισήχθη. Πήγαινε στην προεπισκόπηση.',
    ],
    'importacoes.wizard.source.noSources': [
      'Καμία πηγή-εταίρος. Δημιουργήστε μία από τη σελίδα Importações.',
      'Καμία πηγή-εταίρος. Δημιούργησε μία από τη σελίδα Importações.',
    ],
    'importacoes.wizard.source.ready': [
      'Η παρτίδα εισήχθη (run #{id}). Πηγαίνετε στην προεπισκόπηση.',
      'Η παρτίδα εισήχθη (run #{id}). Πήγαινε στην προεπισκόπηση.',
    ],
    'labels.fieldsConfigHint': [
      'Επιλέξτε τα προαιρετικά πεδία για συμπερίληψη στις εκτυπωμένες ετικέτες.',
      'Επίλεξε τα προαιρετικά πεδία για συμπερίληψη στις εκτυπωμένες ετικέτες.',
    ],
    'labels.format.sectionHint': [
      'Επιλέξτε μορφή εμπορικού φύλλου ή προσαρμόστε τις διαστάσεις χειροκίνητα.',
      'Επίλεξε μορφή εμπορικού φύλλου ή προσάρμοσε τις διαστάσεις χειροκίνητα.',
    ],
    'labels.format.unverifiedHint': [
      'Εκτιμώμενες διαστάσεις (μη επιβεβαιωμένες στο τεχνικό φυλλάδιο του κατασκευαστή) — προσαρμόστε στο «Προσαρμοσμένο» αν χρειάζεται.',
      'Εκτιμώμενες διαστάσεις (μη επιβεβαιωμένες στο τεχνικό φυλλάδιο του κατασκευαστή) — προσάρμοσε στο «Προσαρμοσμένο» αν χρειάζεται.',
    ],
    'panel.apiError.bib_ref_duplicado': [
      'Αυτή η βιβλιογραφική αναφορά χρησιμοποιείται ήδη από άλλη εγγραφή. Αλλάξτε την πριν τη δημοσίευση.',
      'Αυτή η βιβλιογραφική αναφορά χρησιμοποιείται ήδη από άλλη εγγραφή. Άλλαξέ την πριν τη δημοσίευση.',
    ],
    'recolement.error.generic': [
      'Παρουσιάστηκε σφάλμα, δοκιμάστε ξανά.',
      'Παρουσιάστηκε σφάλμα, δοκίμασε ξανά.',
    ],
    'recolement.error.not_authenticated': [
      'Πρέπει να έχετε συνδεθεί.',
      'Πρέπει να έχεις συνδεθεί.',
    ],
    'recolement.intro': [
      'Ξεκινήστε μια συνεδρία και σαρώστε τις ετικέτες QR των αντιτύπων για να ελέγξετε τη συλλογή. Στο τέλος, λάβετε την αναφορά παρόντων, ελλειπόντων και ξένων.',
      'Ξεκίνησε μια συνεδρία και σάρωσε τις ετικέτες QR των αντιτύπων για να ελέγξεις τη συλλογή. Στο τέλος, λάβε την αναφορά παρόντων, ελλειπόντων και ξένων.',
    ],
    'recolement.scan.prompt': [
      'Στοχεύστε στον κωδικό QR της ετικέτας του αντιτύπου',
      'Στόχευσε στον κωδικό QR της ετικέτας του αντιτύπου',
    ],
    'rede.oai.admin.network.desc': [
      'Προτείνετε το άνοιγμα όλου του καταλόγου του δικτύου σε συγκομιδή. Ομόφωνη ψήφος των εμπλεκόμενων βιβλιοθηκών, 21 ημέρες, σιωπή = συναίνεση.',
      'Πρότεινε το άνοιγμα όλου του καταλόγου του δικτύου σε συγκομιδή. Ομόφωνη ψήφος των εμπλεκόμενων βιβλιοθηκών, 21 ημέρες, σιωπή = συναίνεση.',
    ],
    'rede.oai.banner.body': [
      'Μία ή περισσότερες οντότητες μπορούν να ανακτήσουν τις εγγραφές σας τώρα. Κλείστε το μόλις ο εταίρος επιβεβαιώσει ότι ολοκλήρωσε.',
      'Μία ή περισσότερες οντότητες μπορούν να ανακτήσουν τις εγγραφές σου τώρα. Κλείσε το μόλις ο εταίρος επιβεβαιώσει ότι ολοκλήρωσε.',
    ],
    'rede.oai.banner.title': [
      'Ο κατάλογός σας είναι ανοιχτός σε συγκομιδή',
      'Ο κατάλογός σου είναι ανοιχτός σε συγκομιδή',
    ],
    'rede.oai.coord.desc': [
      'Ζητήστε το άνοιγμα από τις διαχειρίστριες του δικτύου. Αρκεί η έγκριση μίας. Μπορείτε να το κλείσετε ανά πάσα στιγμή.',
      'Ζήτησε το άνοιγμα από τις διαχειρίστριες του δικτύου. Αρκεί η έγκριση μίας. Μπορείς να το κλείσεις ανά πάσα στιγμή.',
    ],
    'rede.oai.intro': [
      'Διαθέστε τον κατάλογο της βιβλιοθήκης σας ώστε άλλες βιβλιοθήκες να τον ανακτούν αυτόματα. Το άνοιγμα αποφασίζεται συλλογικά και είναι πάντα προσωρινό.',
      'Διάθεσε τον κατάλογο της βιβλιοθήκης σου ώστε άλλες βιβλιοθήκες να τον ανακτούν αυτόματα. Το άνοιγμα αποφασίζεται συλλογικά και είναι πάντα προσωρινό.',
    ],
    'rede.oai.votes.deadline': [
      'Προθεσμία: {date} — χωρίς απάντηση, τεκμαίρεται η συναίνεσή σας.',
      'Προθεσμία: {date} — χωρίς απάντηση, τεκμαίρεται η συναίνεσή σου.',
    ],
    'rede.oai.votes.prompt': [
      'Η/Ο {entity} ζητά να συγκομίσει τον κατάλογο του δικτύου. Η ψήφος σας για {lib}:',
      'Η/Ο {entity} ζητά να συγκομίσει τον κατάλογο του δικτύου. Η ψήφος σου για {lib}:',
    ],
    'rede.transfer.needPid': [
      'Εισαγάγετε το αναγνωριστικό του νέου ατόμου συντονισμού.',
      'Γράψε το αναγνωριστικό του νέου ατόμου συντονισμού.',
    ],
    'team.governance.directCoord.confirmOn': [
      'Ενεργοποίηση του συλλογικού άλματος; Μια πρόταση συντονισμού θα μπορεί να αφορά ενεργό αναγνώστη/στρια, χωρίς βήμα βιβλιοθηκαρίου. Η συλλογική διαδικασία (υποστήριξη, αποδοχή) ισχύει πλήρως — αλλά το άτομο θα λάβει με μία κίνηση πρόσβαση στα προσωπικά δεδομένα, στις ρυθμίσεις και στη διαχείριση της ομάδας. Ενεργοποιήστε μόνο με απόφαση της συλλογικότητας.',
      'Ενεργοποίηση του συλλογικού άλματος; Μια πρόταση συντονισμού θα μπορεί να αφορά ενεργό αναγνώστη/στρια, χωρίς βήμα βιβλιοθηκαρίου. Η συλλογική διαδικασία (υποστήριξη, αποδοχή) ισχύει πλήρως — αλλά το άτομο θα λάβει με μία κίνηση πρόσβαση στα προσωπικά δεδομένα, στις ρυθμίσεις και στη διαχείριση της ομάδας. Ενεργοποίησέ το μόνο με απόφαση της συλλογικότητας.',
    ],
    'team.modal.error.missingPublicId': [
      'Λείπει το δημόσιο αναγνωριστικό σε αυτή τη γραμμή. Ανανεώστε τη σελίδα και δοκιμάστε ξανά.',
      'Λείπει το δημόσιο αναγνωριστικό σε αυτή τη γραμμή. Ανανέωσε τη σελίδα και δοκίμασε ξανά.',
    ],
    'federacao.communs.doc.thesaurusFicedl.desc': [
      'Το κοινό λεξιλόγιο θεμάτων της ομοσπονδίας: τι είναι, πώς συνδέεται το AnarBib και πώς να το χρησιμοποιείτε.',
      'Το κοινό λεξιλόγιο θεμάτων της ομοσπονδίας: τι είναι, πώς συνδέεται το AnarBib και πώς να το χρησιμοποιείς.',
    ],
    'catalogacao.ocr.title': [
      'OCR στο πρόγραμμα περιήγησης — αποθέστε ένα σαρωμένο PDF',
      'OCR στο πρόγραμμα περιήγησης — απόθεσε ένα σαρωμένο PDF',
    ],
    'catalogacao.ocr.intro': [
      'Αφήστε ένα σαρωμένο PDF. Αν έχει ήδη επίπεδο κειμένου, χρησιμοποιείται απευθείας· αλλιώς οι βασικές σελίδες αναγνωρίζονται με OCR — όλα στο πρόγραμμα περιήγησης, τίποτα δεν αποστέλλεται. Τα πεδία προσυμπληρώνονται ευρετικά (χωρίς ΤΝ) και είναι επεξεργάσιμα.',
      'Άφησε ένα σαρωμένο PDF. Αν έχει ήδη επίπεδο κειμένου, χρησιμοποιείται απευθείας· αλλιώς οι βασικές σελίδες αναγνωρίζονται με OCR — όλα στο πρόγραμμα περιήγησης, τίποτα δεν αποστέλλεται. Τα πεδία προσυμπληρώνονται ευρετικά (χωρίς ΤΝ) και είναι επεξεργάσιμα.',
    ],
    'catalogacao.ocr.dropHint': [
      'Σύρετε ένα PDF εδώ ή κάντε κλικ για να επιλέξετε αρχείο',
      'Σύρε ένα PDF εδώ ή κάνε κλικ για να επιλέξεις αρχείο',
    ],
    'catalogacao.ocr.lowConfidenceWarn': [
      'Χαμηλή αξιοπιστία OCR — ελέγξτε προσεκτικά τα πεδία πριν την αποθήκευση.',
      'Χαμηλή αξιοπιστία OCR — έλεγξε προσεκτικά τα πεδία πριν την αποθήκευση.',
    ],
    'catalogacao.ocr.handoffIntro': [
      'Ελέγξτε και συμπληρώστε το προσυμπληρωμένο πρόχειρο, μετά αποθηκεύστε. Το PDF θα επισυναφθεί αυτόματα.',
      'Έλεγξε και συμπλήρωσε το προσυμπληρωμένο πρόχειρο, μετά αποθήκευσε. Το PDF θα επισυναφθεί αυτόματα.',
    ],
    'federacao.carte.edit.localeNote': [
      'Το όνομα και οι σημειώσεις επεξεργάζονται στη γλώσσα εμφάνισής σας.',
      'Το όνομα και οι σημειώσεις επεξεργάζονται στη γλώσσα εμφάνισής σου.',
    ],
    'federacao.carte.edit.position': [
      'Θέση (κάντε κλικ ή σύρετε τον δείκτη)',
      'Θέση (κάνε κλικ ή σύρε τον δείκτη)',
    ],
    'cartografia.add.intro': [
      'Το συλλογικό σας δεν είναι ακόμη στον χάρτη; Προτείνετέ το εδώ.',
      'Το συλλογικό σου δεν είναι ακόμη στον χάρτη; Πρότεινέ το εδώ.',
    ],
    'cartografia.add.consent': [
      'Δηλώστε μόνο τη δική σας βιβλιοθήκη. Τίποτα δεν εμφανίζεται δημόσια χωρίς έλεγχο από τον συντονισμό και τη συγκατάθεσή σας.',
      'Δήλωσε μόνο τη δική σου βιβλιοθήκη. Τίποτα δεν εμφανίζεται δημόσια χωρίς έλεγχο από τον συντονισμό και τη συγκατάθεσή σου.',
    ],
    'cartografia.add.success': [
      'Ευχαριστούμε! Η πρότασή σας στάλθηκε στον συντονισμό.',
      'Ευχαριστούμε! Η πρότασή σου στάλθηκε στον συντονισμό.',
    ],
    'cartografia.add.error': [
      'Η αποστολή απέτυχε. Δοκιμάστε ξανά.',
      'Η αποστολή απέτυχε. Δοκίμασε ξανά.',
    ],
    'federacao.carte.edit.geocodeFail': [
      'Η διεύθυνση δεν βρέθηκε — τοποθετήστε το σημείο χειροκίνητα.',
      'Η διεύθυνση δεν βρέθηκε — τοποθέτησε το σημείο χειροκίνητα.',
    ],
    'team.invite.publicId.hint': [
      'Ζητήστε από το άτομο το δημόσιο αναγνωριστικό του (εμφανίζεται στην καρτέλα / κάρτα).',
      'Ζήτησε από το άτομο το δημόσιο αναγνωριστικό του (εμφανίζεται στην καρτέλα / κάρτα).',
    ],
    'team.invite.error.emptyPublicId': [
      'Δώστε ένα δημόσιο αναγνωριστικό.',
      'Δώσε ένα δημόσιο αναγνωριστικό.',
    ],
    'team.invitations.endorsed': [
      'Υποστηρίξατε',
      'Υποστήριξες',
    ],
    'account.invitations.ready': [
      'έτοιμη: μπορείτε να αποδεχτείτε',
      'έτοιμη: μπορείς να αποδεχτείς',
    ],
    'account.invitations.acceptSuccess': [
      'Είστε πλέον μέλος της ομάδας.',
      'Είσαι πλέον μέλος της ομάδας.',
    ],
    'error.catalog.discard.forbidden': [
      'Δεν έχετε δικαίωμα για αυτήν την ενέργεια.',
      'Δεν έχεις δικαίωμα για αυτήν την ενέργεια.',
    ],
    'error.catalog.discard.bookHasHoldings': [
      'Αυτό το τεκμήριο έχει αντίτυπα σε μία ή περισσότερες βιβλιοθήκες. Απορρίψτε πρώτα τα αντίτυπα.',
      'Αυτό το τεκμήριο έχει αντίτυπα σε μία ή περισσότερες βιβλιοθήκες. Απόρριψε πρώτα τα αντίτυπα.',
    ],
    'error.catalog.discard.authorLinked': [
      'Αυτή η καθιερωμένη εγγραφή συνδέεται ακόμη με ένα ή περισσότερα τεκμήρια. Αποσυνδέστε την πρώτα.',
      'Αυτή η καθιερωμένη εγγραφή συνδέεται ακόμη με ένα ή περισσότερα τεκμήρια. Αποσύνδεσέ την πρώτα.',
    ],
    'catalogacao.catalog.mergeHelp': [
      'Επιλέξτε την καθιερωμένη εγγραφή που θα διατηρηθεί: το «{name}» θα συνδεθεί με αυτήν (έργα, συνεισφορές, ψευδώνυμα) και έπειτα θα διαγραφεί. Μη αναστρέψιμη ενέργεια.',
      'Επίλεξε την καθιερωμένη εγγραφή που θα διατηρηθεί: το «{name}» θα συνδεθεί με αυτήν (έργα, συνεισφορές, ψευδώνυμα) και έπειτα θα διαγραφεί. Μη αναστρέψιμη ενέργεια.',
    ],
    'catalogacao.create.question': [
      'Τι καταλογογραφείτε;',
      'Τι καταλογογραφείς;',
    ],
    'error.catalog.work.needTwo': [
      'Επιλέξτε τουλάχιστον δύο τεκμήρια.',
      'Επίλεξε τουλάχιστον δύο τεκμήρια.',
    ],
    'catalogacao.audio.seg.intro': [
      'Χωρίστε αυτή την ηχογράφηση σε τμήματα (ομιλίες, τραγούδια…), καθένα συνδεδεμένο με ένα έργο και τους συντελεστές του.',
      'Χώρισε αυτή την ηχογράφηση σε τμήματα (ομιλίες, τραγούδια…), καθένα συνδεδεμένο με ένα έργο και τους συντελεστές του.',
    ],
    'deposit.config.rules.empty': [
      'Κανένας κανόνας εγγύησης. Προσθέστε έναν για να ξεκινήσετε.',
      'Κανένας κανόνας εγγύησης. Πρόσθεσε έναν για να ξεκινήσεις.',
    ],
    'deposit.panel.noActiveRule': [
      'Ενεργοποιήστε έναν κανόνα εγγύησης για να εισπράξετε εγγύηση.',
      'Ενεργοποίησε έναν κανόνα εγγύησης για να εισπράξεις εγγύηση.',
    ],
    'panel.apiError.amount_must_be_positive': [
      'Το ποσό πρέπει να είναι θετικό (ή χρησιμοποιήστε «απαλλαγή»).',
      'Το ποσό πρέπει να είναι θετικό (ή χρησιμοποίησε «απαλλαγή»).',
    ],
    'panel.apiError.standing_deposit_has_open_loans': [
      'Η επιστροφή δεν είναι δυνατή: υπάρχουν ακόμη ενεργοί δανεισμοί. Επιστρέψτε τη μόνιμη εγγύηση μόλις επιστραφούν όλα.',
      'Η επιστροφή δεν είναι δυνατή: υπάρχουν ακόμη ενεργοί δανεισμοί. Επίστρεψε τη μόνιμη εγγύηση μόλις επιστραφούν όλα.',
    ],
    'altcha.reessayer': [
      'Δοκιμάστε ξανά',
      'Δοκίμασε ξανά',
    ],
    'catalogacao.dedup.scanHelpCross': [
      'Το ίδιο έργο καταλογογραφημένο χωριστά από διαφορετικές βιβλιοθήκες. Η συγχώνευση θα σήμαινε κοινή χρήση της εγγραφής: προτιμήστε « Ίδιο έργο ».',
      'Το ίδιο έργο καταλογογραφημένο χωριστά από διαφορετικές βιβλιοθήκες. Η συγχώνευση θα σήμαινε κοινή χρήση της εγγραφής: προτίμησε « Ίδιο έργο ».',
    ],
    'catalogacao.dedup.reportPlaceholder': [
      'Τι διαπιστώσατε (προαιρετικό)',
      'Τι διαπίστωσες (προαιρετικό)',
    ],
    'catalogacao.dedup.arbiterOnly': [
      'Η συγχώνευση και η εξαίρεση προορίζονται για τον συντονισμό. Μπορείτε να ομαδοποιήσετε δύο εκδόσεις του ίδιου έργου ή να αναφέρετε το ζεύγος.',
      'Η συγχώνευση και η εξαίρεση προορίζονται για τον συντονισμό. Μπορείς να ομαδοποιήσεις δύο εκδόσεις του ίδιου έργου ή να αναφέρεις το ζεύγος.',
    ],
    'catalogacao.digital.rights.hint': [
      'Το πεδίο περιγράφει τα δικαιώματα, όχι το τι διατίθεται. «Υπό δικαιώματα» = μόνο το εξώφυλλο, εκτός αν η βιβλιοθήκη κατέχει το φυσικό αντίτυπο: τότε είναι δυνατό το πλήρες κείμενο, μόνο για τα μέλη της. Αιτιολογήστε παρακάτω.',
      'Το πεδίο περιγράφει τα δικαιώματα, όχι το τι διατίθεται. «Υπό δικαιώματα» = μόνο το εξώφυλλο, εκτός αν η βιβλιοθήκη κατέχει το φυσικό αντίτυπο: τότε είναι δυνατό το πλήρες κείμενο, μόνο για τα μέλη της. Αιτιολόγησε παρακάτω.',
    ],
    'catalogacao.dedupAssist.confirmPrompt': [
      'Για επιβεβαίωση, πληκτρολογήστε τον κωδικό της διαγραφόμενης εγγραφής ({ref}):',
      'Για επιβεβαίωση, πληκτρολόγησε τον κωδικό της διαγραφόμενης εγγραφής ({ref}):',
    ],
    'atelier.revue.retained': [
      'Η διόρθωσή σας',
      'Η διόρθωσή σου',
    ],
    'panel.apiError.split_target_changed': [
      'Η εγγραφή άλλαξε μετά την πρόταση: δεν γράφτηκε τίποτα, ώστε να μη σβηστεί η δουλειά κάποιου άλλου. Επαναλάβετε την πρόταση στην τρέχουσα κατάσταση.',
      'Η εγγραφή άλλαξε μετά την πρόταση: δεν γράφτηκε τίποτα, ώστε να μη σβηστεί η δουλειά κάποιου άλλου. Επανάλαβε την πρόταση στην τρέχουσα κατάσταση.',
    ],
    'panel.apiError.too_soon': [
      'Πολύ νωρίς: η ίδια ενέργεια μόλις εκτελέστηκε. Δοκιμάστε ξανά σε ένα λεπτό.',
      'Πολύ νωρίς: η ίδια ενέργεια μόλις εκτελέστηκε. Δοκίμασε ξανά σε ένα λεπτό.',
    ],
    'catalogacao.serialGov.coordOnly': [
      'Μπορείτε να δείτε αυτή τη λίστα· η προαγωγή ή η απόσυρση ανήκει στον συντονισμό καταλογογράφησης.',
      'Μπορείς να δεις αυτή τη λίστα· η προαγωγή ή η απόσυρση ανήκει στον συντονισμό καταλογογράφησης.',
    ],
    'catalogacao.serialGov.viewPublic': [
      'δείτε τη δημόσια σελίδα',
      'δες τη δημόσια σελίδα',
    ],
    'catalogacao.serialGov.holdings.declaredWins': [
      'Αυτό που δηλώνετε είναι αυτό που εμφανίζεται. Ο παρακάτω υπολογισμός απλώς συνοδεύει: λέει τι έχει καταλογογραφηθεί, ποτέ ότι ένα κενό είναι οριστικό.',
      'Αυτό που δηλώνεις είναι αυτό που εμφανίζεται. Ο παρακάτω υπολογισμός απλώς συνοδεύει: λέει τι έχει καταλογογραφηθεί, ποτέ ότι ένα κενό είναι οριστικό.',
    ],
    'conta.demande.intro': [
      'Η αίτηση ένταξης της βιβλιοθήκης σας στο δίκτυο, και οι ανταλλαγές σας με τη διαχείριση του δικτύου κατά την εξέτασή της.',
      'Η αίτηση ένταξης της βιβλιοθήκης σου στο δίκτυο, και οι ανταλλαγές σου με τη διαχείριση του δικτύου κατά την εξέτασή της.',
    ],
    'catalog.works.yourLibrary': [
      'η βιβλιοθήκη σας',
      'η βιβλιοθήκη σου',
    ],
    'catalogacao.dedupAssist.helpSplit': [
      'Δύο έργα του ίδιου συγγραφέα με παρόμοιο τίτλο. Αν είναι το ίδιο κείμενο, συγχώνευση: οι εκδόσεις ενώνονται, τίποτα δεν καταστρέφεται. Αλλιώς κρατήστε τα χωριστά, και η σάρωση δεν θα τα ξαναπροτείνει.',
      'Δύο έργα του ίδιου συγγραφέα με παρόμοιο τίτλο. Αν είναι το ίδιο κείμενο, συγχώνευση: οι εκδόσεις ενώνονται, τίποτα δεν καταστρέφεται. Αλλιώς κράτησέ τα χωριστά, και η σάρωση δεν θα τα ξαναπροτείνει.',
    ],
    'catalogacao.work.titleSource.auto': [
      'αυτόματη μετάφραση — διορθώστε με',
      'αυτόματη μετάφραση — διόρθωσέ με',
    ],
    'catalogacao.dedupAssist.helpVolumes': [
      'Εγγραφές του ίδιου συγγραφέα με τον ίδιο τίτλο εκτός από έναν αριθμό τόμου. Ένας τόμος δεν είναι έργο: το « Ίδιο έργο σε πολλούς τόμους » ορίζει τον αριθμό κάθε τόμου και τους ενώνει σε ένα έργο, τίποτα δεν καταστρέφεται. Αλλιώς απορρίψτε τους.',
      'Εγγραφές του ίδιου συγγραφέα με τον ίδιο τίτλο εκτός από έναν αριθμό τόμου. Ένας τόμος δεν είναι έργο: το « Ίδιο έργο σε πολλούς τόμους » ορίζει τον αριθμό κάθε τόμου και τους ενώνει σε ένα έργο, τίποτα δεν καταστρέφεται. Αλλιώς απόρριψέ τους.',
    ],
    'rede.reviews.intro': [
      'Μια παρτίδα από εισαγωγή δημοσιεύεται μόνο μετά την έγκρισή σας. Διαβάστε την έκθεση, αποφασίστε, αιτιολογήστε τις διορθώσεις.',
      'Μια παρτίδα από εισαγωγή δημοσιεύεται μόνο μετά την έγκρισή σου. Διάβασε την έκθεση, αποφάσισε, αιτιολόγησε τις διορθώσεις.',
    ],
    'rede.reviews.notes': [
      'Οι σημειώσεις σας',
      'Οι σημειώσεις σου',
    ],
    'notif.review.approved.body': [
      'Η διαχείριση ενέκρινε την αναθεώρηση της παρτίδας σας: η δημοσίευση είναι ανοιχτή.',
      'Η διαχείριση ενέκρινε την αναθεώρηση της παρτίδας σου: η δημοσίευση είναι ανοιχτή.',
    ],
    'notif.review.changes.body': [
      'Η διαχείριση ζητά διορθώσεις πριν τη δημοσίευση. Διαβάστε τις σημειώσεις στην Καταλογογράφηση › Παρτίδες.',
      'Η διαχείριση ζητά διορθώσεις πριν τη δημοσίευση. Διάβασε τις σημειώσεις στην Καταλογογράφηση › Παρτίδες.',
    ],
    'error.review.notes_required': [
      'Οι διορθώσεις αιτιολογούνται: προσθέστε σημείωση.',
      'Οι διορθώσεις αιτιολογούνται: πρόσθεσε σημείωση.',
    ],
    'catalogacao.batch.reassign.pickPlaceholder': [
      'Επιλέξτε βιβλιοθήκη…',
      'Επίλεξε βιβλιοθήκη…',
    ],
    'error.batch.reassign.review_approved': [
      'Αυτή η παρτίδα έχει εγκεκριμένη αναθεώρηση για άλλη βιβλιοθήκη: ζητήστε νέο γύρο αναθεώρησης πριν την επανανάθεση.',
      'Αυτή η παρτίδα έχει εγκεκριμένη αναθεώρηση για άλλη βιβλιοθήκη: ζήτησε νέο γύρο αναθεώρησης πριν την επανανάθεση.',
    ],
    'catalogacao.batch.rubrics.intro': [
      'Κάθε θεματική που βρέθηκε στην παρτίδα « {name} » λαμβάνει έναν κωδικό ταξιθέτησης (τάξη), που γράφεται στα προσχέδια που δεν έχουν ακόμη. Αφήστε κενό για να παραλείψετε μια θεματική.',
      'Κάθε θεματική που βρέθηκε στην παρτίδα « {name} » λαμβάνει έναν κωδικό ταξιθέτησης (τάξη), που γράφεται στα προσχέδια που δεν έχουν ακόμη. Άφησε κενό για να παραλείψεις μια θεματική.',
    ],
    'error.bibref.batch.mixed_owner': [
      'Τα προσχέδια χωρίς ταξιθετικό αυτής της παρτίδας ανήκουν σε πολλές βιβλιοθήκες : επανααναθέστε πρώτα την παρτίδα.',
      'Τα προσχέδια χωρίς ταξιθετικό αυτής της παρτίδας ανήκουν σε πολλές βιβλιοθήκες : επανανάθεσε πρώτα την παρτίδα.',
    ],
    'error.bibref.batch.no_owner': [
      'Τα προσχέδια αυτής της παρτίδας δεν έχουν βιβλιοθήκη-ιδιοκτήτρια : επανααναθέστε πρώτα την παρτίδα.',
      'Τα προσχέδια αυτής της παρτίδας δεν έχουν βιβλιοθήκη-ιδιοκτήτρια : επανανάθεσε πρώτα την παρτίδα.',
    ],
    'error.bibref.batch.no_convention': [
      'Η βιβλιοθήκη-ιδιοκτήτρια δεν έχει σύμβαση αυτόματου ταξιθετικού : ορίστε την στο Βιβλιοθήκη › Αρίθμηση.',
      'Η βιβλιοθήκη-ιδιοκτήτρια δεν έχει σύμβαση αυτόματου ταξιθετικού : όρισέ την στο Βιβλιοθήκη › Αρίθμηση.',
    ],
    'importacoes.run.encoding.fallback': [
      'Διαβάστηκε ως {enc}, κατ’ υπόθεση: το αρχείο δεν είναι έγκυρο UTF-8. Ελέγξτε τους τόνους των πρώτων εγγραφών· αν είναι λάθος, επανεπεξεργαστείτε επιβάλλοντας την κωδικοποίηση.',
      'Διαβάστηκε ως {enc}, κατ’ υπόθεση: το αρχείο δεν είναι έγκυρο UTF-8. Έλεγξε τους τόνους των πρώτων εγγραφών· αν είναι λάθος, επανεπεξεργάσου επιβάλλοντας την κωδικοποίηση.',
    ],
    'importacoes.run.encoding.declaredUnsupported': [
      'Το αρχείο δηλώνει μη υποστηριζόμενο σύνολο χαρακτήρων ({codes}): ορισμένοι χαρακτήρες μπορεί να είναι λάθος. Εξαγάγετε ξανά σε UTF-8.',
      'Το αρχείο δηλώνει μη υποστηριζόμενο σύνολο χαρακτήρων ({codes}): ορισμένοι χαρακτήρες μπορεί να είναι λάθος. Κάνε ξανά εξαγωγή σε UTF-8.',
    ],
    'importacoes.run.reprocess.locked': [
      'Αυτή η εισαγωγή έχει ήδη δημιουργήσει πρόχειρα: δεν μπορεί πλέον να επανεπεξεργαστεί. Για νέα ανάγνωση, εισαγάγετε ξανά το αρχείο.',
      'Αυτή η εισαγωγή έχει ήδη δημιουργήσει πρόχειρα: δεν μπορεί πλέον να επανεπεξεργαστεί. Για νέα ανάγνωση, κάνε ξανά εισαγωγή του αρχείου.',
    ],
    'error.import.reparse_after_promotion': [
      'Αυτή η εισαγωγή έχει ήδη δημιουργήσει πρόχειρα: δεν μπορεί πλέον να επανεπεξεργαστεί (τα πρόχειρα θα έχαναν τον σύνδεσμο με την εισαγωγή). Εισαγάγετε ξανά το αρχείο.',
      'Αυτή η εισαγωγή έχει ήδη δημιουργήσει πρόχειρα: δεν μπορεί πλέον να επανεπεξεργαστεί (τα πρόχειρα θα έχαναν τον σύνδεσμο με την εισαγωγή). Κάνε ξανά εισαγωγή του αρχείου.',
    ],
  },
};

for (const [loc, cles] of Object.entries(DE_PARA)) {
  const fichier = path.join(DOSSIER, `${loc}.json`);
  const j = JSON.parse(fs.readFileSync(fichier, 'utf8'));
  let reecrites = 0;
  let deja = 0;
  const absentes = [];
  const autres = [];
  for (const [k, [de, para]] of Object.entries(cles)) {
    if (!(k in j)) absentes.push(k);
    else if (j[k] === de) { j[k] = para; reecrites++; }
    else if (j[k] === para) deja++;
    else autres.push(k);
  }
  fs.writeFileSync(fichier, JSON.stringify(j, null, 2) + '\n');
  console.log(`${loc} : ${reecrites} réécrite(s), ${deja} déjà faite(s)`);
  if (absentes.length) console.log(`  absentes (laissées) : ${absentes.join(', ')}`);
  if (autres.length) console.log(`  modifiées depuis, ni l'ancienne ni la nouvelle valeur (laissées) : ${autres.join(', ')}`);
}
