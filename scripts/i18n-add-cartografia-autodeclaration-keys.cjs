#!/usr/bin/env node
/* eslint-disable */
// Clés i18n du parcours d'auto-déclaration (MAP-J / CARTO-7) : form public + modération.
// Parité 10 locales, idempotent, UTF-8 sans BOM. Auteur : AnarBib · Session : Carte réseau 10 locales.
const fs = require('node:fs');
const path = require('node:path');
const DIR = path.join(__dirname, '..', 'src', 'i18n', 'locales');

const T = {
  'cartografia.add': { fr:'Ajouter ma bibliothèque', 'pt-BR':'Adicionar minha biblioteca', es:'Añadir mi biblioteca', it:'Aggiungi la mia biblioteca', de:'Meine Bibliothek hinzufügen', en:'Add my library', ca:'Afegir la meva biblioteca', eo:'Aldoni mian bibliotekon', nl:'Mijn bibliotheek toevoegen', el:'Προσθήκη της βιβλιοθήκης μου' },
  'cartografia.add.title': { fr:'Ajouter ma bibliothèque à la carte', 'pt-BR':'Adicionar minha biblioteca ao mapa', es:'Añadir mi biblioteca al mapa', it:'Aggiungere la mia biblioteca alla mappa', de:'Meine Bibliothek zur Karte hinzufügen', en:'Add my library to the map', ca:'Afegir la meva biblioteca al mapa', eo:'Aldoni mian bibliotekon al la mapo', nl:'Mijn bibliotheek aan de kaart toevoegen', el:'Προσθήκη της βιβλιοθήκης μου στον χάρτη' },
  'cartografia.add.intro': { fr:"Votre collectif n'est pas encore sur la carte ? Proposez-le ici.", 'pt-BR':'Seu coletivo ainda não está no mapa? Proponha-o aqui.', es:'¿Tu colectivo aún no está en el mapa? Proponlo aquí.', it:'Il tuo collettivo non è ancora sulla mappa? Proponilo qui.', de:'Euer Kollektiv ist noch nicht auf der Karte? Schlagt es hier vor.', en:"Your collective isn't on the map yet? Suggest it here.", ca:"El teu col·lectiu encara no és al mapa? Proposa'l aquí.", eo:'Via kolektivo ankoraŭ ne estas sur la mapo? Proponu ĝin ĉi tie.', nl:'Staat jullie collectief nog niet op de kaart? Stel het hier voor.', el:'Το συλλογικό σας δεν είναι ακόμη στον χάρτη; Προτείνετέ το εδώ.' },
  'cartografia.add.consent': { fr:"Ne déclarez que votre propre bibliothèque. Rien n'apparaît publiquement sans validation par la coordination et votre accord.", 'pt-BR':'Declare apenas a sua própria biblioteca. Nada aparece publicamente sem validação da coordenação e o seu consentimento.', es:'Declara solo tu propia biblioteca. Nada aparece públicamente sin validación de la coordinación y tu consentimiento.', it:'Dichiara solo la tua biblioteca. Nulla appare pubblicamente senza la validazione del coordinamento e il tuo consenso.', de:'Meldet nur eure eigene Bibliothek. Nichts erscheint öffentlich ohne Prüfung durch die Koordination und euer Einverständnis.', en:'Only declare your own library. Nothing appears publicly without coordination review and your consent.', ca:'Declara només la teva pròpia biblioteca. Res no apareix públicament sense validació de la coordinació i el teu consentiment.', eo:'Deklaru nur vian propran bibliotekon. Nenio aperas publike sen kontrolo de la kunordigo kaj via konsento.', nl:'Meld alleen je eigen bibliotheek aan. Niets verschijnt openbaar zonder controle door de coördinatie en jouw toestemming.', el:'Δηλώστε μόνο τη δική σας βιβλιοθήκη. Τίποτα δεν εμφανίζεται δημόσια χωρίς έλεγχο από τον συντονισμό και τη συγκατάθεσή σας.' },
  'cartografia.add.submitterNote': { fr:'Message à la coordination (facultatif)', 'pt-BR':'Mensagem à coordenação (opcional)', es:'Mensaje a la coordinación (opcional)', it:'Messaggio al coordinamento (facoltativo)', de:'Nachricht an die Koordination (optional)', en:'Message to the coordination (optional)', ca:'Missatge a la coordinació (opcional)', eo:'Mesaĝo al la kunordigo (nedeviga)', nl:'Bericht aan de coördinatie (optioneel)', el:'Μήνυμα προς τον συντονισμό (προαιρετικό)' },
  'cartografia.add.submit': { fr:'Envoyer', 'pt-BR':'Enviar', es:'Enviar', it:'Invia', de:'Senden', en:'Submit', ca:'Envia', eo:'Sendi', nl:'Versturen', el:'Υποβολή' },
  'cartografia.add.sending': { fr:'Envoi…', 'pt-BR':'Enviando…', es:'Enviando…', it:'Invio…', de:'Senden…', en:'Sending…', ca:'Enviant…', eo:'Sendante…', nl:'Versturen…', el:'Αποστολή…' },
  'cartografia.add.success': { fr:'Merci ! Votre proposition a été envoyée à la coordination.', 'pt-BR':'Obrigado! Sua proposta foi enviada à coordenação.', es:'¡Gracias! Tu propuesta se ha enviado a la coordinación.', it:'Grazie! La tua proposta è stata inviata al coordinamento.', de:'Danke! Euer Vorschlag wurde an die Koordination gesendet.', en:'Thank you! Your suggestion has been sent to the coordination.', ca:"Gràcies! La teva proposta s'ha enviat a la coordinació.", eo:'Dankon! Via propono estis sendita al la kunordigo.', nl:'Bedankt! Je voorstel is naar de coördinatie gestuurd.', el:'Ευχαριστούμε! Η πρότασή σας στάλθηκε στον συντονισμό.' },
  'cartografia.add.error': { fr:"Échec de l'envoi. Réessayez.", 'pt-BR':'Falha no envio. Tente novamente.', es:'Error al enviar. Inténtalo de nuevo.', it:'Invio non riuscito. Riprova.', de:'Senden fehlgeschlagen. Bitte erneut versuchen.', en:'Sending failed. Please try again.', ca:'Error en enviar. Torna-ho a provar.', eo:'Sendado malsukcesis. Bonvolu reprovi.', nl:'Verzenden mislukt. Probeer opnieuw.', el:'Η αποστολή απέτυχε. Δοκιμάστε ξανά.' },
  'cartografia.mod': { fr:'Modérer les ajouts', 'pt-BR':'Moderar adições', es:'Moderar añadidos', it:'Modera le aggiunte', de:'Einträge moderieren', en:'Moderate additions', ca:'Modera les addicions', eo:'Moderigi aldonojn', nl:'Toevoegingen modereren', el:'Έλεγχος προσθηκών' },
  'cartografia.mod.title': { fr:'Modération des ajouts à la carte', 'pt-BR':'Moderação das adições ao mapa', es:'Moderación de añadidos al mapa', it:'Moderazione delle aggiunte alla mappa', de:'Moderation der Karteneinträge', en:'Moderate map additions', ca:'Moderació de les addicions al mapa', eo:'Moderigo de aldonoj al la mapo', nl:'Moderatie van kaarttoevoegingen', el:'Έλεγχος προσθηκών στον χάρτη' },
  'cartografia.mod.empty': { fr:'Aucune proposition en attente.', 'pt-BR':'Nenhuma proposta pendente.', es:'No hay propuestas pendientes.', it:'Nessuna proposta in attesa.', de:'Keine offenen Vorschläge.', en:'No pending submissions.', ca:'Cap proposta pendent.', eo:'Neniu atendanta propono.', nl:'Geen openstaande voorstellen.', el:'Καμία εκκρεμής πρόταση.' },
  'cartografia.mod.approve': { fr:'Approuver', 'pt-BR':'Aprovar', es:'Aprobar', it:'Approva', de:'Genehmigen', en:'Approve', ca:'Aprova', eo:'Aprobi', nl:'Goedkeuren', el:'Έγκριση' },
  'cartografia.mod.reject': { fr:'Refuser', 'pt-BR':'Recusar', es:'Rechazar', it:'Rifiuta', de:'Ablehnen', en:'Reject', ca:'Rebutja', eo:'Malakcepti', nl:'Afwijzen', el:'Απόρριψη' },
  'cartografia.mod.rejectReason': { fr:'Motif du refus (facultatif) :', 'pt-BR':'Motivo da recusa (opcional):', es:'Motivo del rechazo (opcional):', it:'Motivo del rifiuto (facoltativo):', de:'Grund der Ablehnung (optional):', en:'Reason for rejection (optional):', ca:'Motiu del rebuig (opcional):', eo:'Kialo de malakcepto (nedeviga):', nl:'Reden voor afwijzing (optioneel):', el:'Λόγος απόρριψης (προαιρετικό):' },
  'cartografia.mod.done': { fr:'Fait.', 'pt-BR':'Feito.', es:'Hecho.', it:'Fatto.', de:'Erledigt.', en:'Done.', ca:'Fet.', eo:'Farite.', nl:'Klaar.', el:'Έγινε.' },
  'cartografia.mod.error': { fr:'Action impossible (réservé à la coordination).', 'pt-BR':'Ação não permitida (reservado à coordenação).', es:'Acción no permitida (reservado a la coordinación).', it:'Azione non consentita (riservato al coordinamento).', de:'Aktion nicht möglich (nur Koordination).', en:'Action not allowed (coordination only).', ca:'Acció no permesa (només coordinació).', eo:'Ago malpermesita (nur kunordigo).', nl:'Actie niet toegestaan (alleen coördinatie).', el:'Μη επιτρεπτή ενέργεια (μόνο συντονισμός).' },
};

let total = 0;
for (const file of fs.readdirSync(DIR).filter((f) => f.endsWith('.json'))) {
  const loc = file.replace(/\.json$/, '');
  const p = path.join(DIR, file);
  const obj = JSON.parse(fs.readFileSync(p, 'utf8'));
  let added = 0;
  for (const [key, byLoc] of Object.entries(T)) {
    const val = byLoc[loc];
    if (val == null) { console.warn(`[warn] ${key} manque pour ${loc}`); continue; }
    if (!(key in obj)) { obj[key] = val; added++; }
  }
  if (added) { fs.writeFileSync(p, JSON.stringify(obj, null, 2) + '\n', 'utf8'); total += added; }
  console.log(`${file.padEnd(11)} +${added}`);
}
console.log(`Total : ${total}`);
