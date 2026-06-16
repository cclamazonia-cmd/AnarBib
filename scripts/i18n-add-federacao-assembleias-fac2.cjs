/* ===========================================================================
 * i18n-add-federacao-assembleias-fac2.cjs
 * P2c-front : 16 clés federacao.assembleias.fac.* (volontariat, désignation,
 * ordre de l'ODJ, rappel rotativité) dans les 10 locales. Idempotent
 * (sentinelle federacao.assembleias.fac.volunteer).
 * Auteur : Claude (assistant)
 * Session : Fédération — Assemblée du réseau (AG)
 * =========================================================================== */
const fs = require('fs');
const path = require('path');

const LOCALES = ['ca', 'de', 'el', 'en', 'eo', 'es', 'fr', 'it', 'nl', 'pt-BR'];
const DIR = path.join(__dirname, '..', 'src', 'i18n', 'locales');
const SENTINEL = 'federacao.assembleias.fac.volunteer';

const ADD = {
  'pt-BR': {
    "federacao.assembleias.fac.volunteer": "Proponho-me para facilitar",
    "federacao.assembleias.fac.volunteer.done": "Proposta registrada.",
    "federacao.assembleias.fac.unvolunteer": "Retirar minha proposta",
    "federacao.assembleias.fac.unvolunteer.done": "Proposta retirada.",
    "federacao.assembleias.fac.youFacilitate": "Você facilita esta assembleia.",
    "federacao.assembleias.fac.volunteers.label": "Quem se propôs a facilitar",
    "federacao.assembleias.fac.volunteers.none": "Nenhuma proposta por enquanto.",
    "federacao.assembleias.fac.designate": "Designar",
    "federacao.assembleias.fac.designate.done": "Pessoa designada para facilitar.",
    "federacao.assembleias.fac.designated.label": "Pessoas que facilitam",
    "federacao.assembleias.fac.remove": "Retirar",
    "federacao.assembleias.fac.remove.done": "Pessoa retirada da facilitação.",
    "federacao.assembleias.fac.order.up": "↑ Subir",
    "federacao.assembleias.fac.order.down": "↓ Descer",
    "federacao.assembleias.fac.anon": "Membro",
    "federacao.assembleias.fac.rotativityHint": "Funções rotativas: alternem de uma AG para outra — para evitar o esgotamento militante e que um poder se instale."
  },
  fr: {
    "federacao.assembleias.fac.volunteer": "Je me propose pour faciliter",
    "federacao.assembleias.fac.volunteer.done": "Proposition enregistrée.",
    "federacao.assembleias.fac.unvolunteer": "Retirer ma proposition",
    "federacao.assembleias.fac.unvolunteer.done": "Proposition retirée.",
    "federacao.assembleias.fac.youFacilitate": "Tu facilites cette assemblée.",
    "federacao.assembleias.fac.volunteers.label": "Volontaires pour faciliter",
    "federacao.assembleias.fac.volunteers.none": "Aucune proposition pour l’instant.",
    "federacao.assembleias.fac.designate": "Désigner",
    "federacao.assembleias.fac.designate.done": "Facilitateur·rice désigné·e.",
    "federacao.assembleias.fac.designated.label": "Facilitateur·rices désigné·es",
    "federacao.assembleias.fac.remove": "Retirer",
    "federacao.assembleias.fac.remove.done": "Retiré·e de la facilitation.",
    "federacao.assembleias.fac.order.up": "↑ Remonter",
    "federacao.assembleias.fac.order.down": "↓ Descendre",
    "federacao.assembleias.fac.anon": "Membre",
    "federacao.assembleias.fac.rotativityHint": "Fonctions tournantes : alternez d’une AG à l’autre — pour éviter l’épuisement militant et qu’un pouvoir s’installe."
  },
  es: {
    "federacao.assembleias.fac.volunteer": "Me propongo para facilitar",
    "federacao.assembleias.fac.volunteer.done": "Propuesta registrada.",
    "federacao.assembleias.fac.unvolunteer": "Retirar mi propuesta",
    "federacao.assembleias.fac.unvolunteer.done": "Propuesta retirada.",
    "federacao.assembleias.fac.youFacilitate": "Facilitas esta asamblea.",
    "federacao.assembleias.fac.volunteers.label": "Quienes se proponen para facilitar",
    "federacao.assembleias.fac.volunteers.none": "Ninguna propuesta por ahora.",
    "federacao.assembleias.fac.designate": "Designar",
    "federacao.assembleias.fac.designate.done": "Persona designada para facilitar.",
    "federacao.assembleias.fac.designated.label": "Quienes facilitan",
    "federacao.assembleias.fac.remove": "Retirar",
    "federacao.assembleias.fac.remove.done": "Persona retirada de la facilitación.",
    "federacao.assembleias.fac.order.up": "↑ Subir",
    "federacao.assembleias.fac.order.down": "↓ Bajar",
    "federacao.assembleias.fac.anon": "Integrante",
    "federacao.assembleias.fac.rotativityHint": "Funciones rotativas: alternen de una AG a otra — para evitar el agotamiento militante y que se instale un poder."
  },
  en: {
    "federacao.assembleias.fac.volunteer": "Volunteer to facilitate",
    "federacao.assembleias.fac.volunteer.done": "Offer recorded.",
    "federacao.assembleias.fac.unvolunteer": "Withdraw my offer",
    "federacao.assembleias.fac.unvolunteer.done": "Offer withdrawn.",
    "federacao.assembleias.fac.youFacilitate": "You facilitate this assembly.",
    "federacao.assembleias.fac.volunteers.label": "Volunteers to facilitate",
    "federacao.assembleias.fac.volunteers.none": "No offers yet.",
    "federacao.assembleias.fac.designate": "Designate",
    "federacao.assembleias.fac.designate.done": "Facilitator designated.",
    "federacao.assembleias.fac.designated.label": "Designated facilitators",
    "federacao.assembleias.fac.remove": "Remove",
    "federacao.assembleias.fac.remove.done": "Removed from facilitation.",
    "federacao.assembleias.fac.order.up": "↑ Move up",
    "federacao.assembleias.fac.order.down": "↓ Move down",
    "federacao.assembleias.fac.anon": "Member",
    "federacao.assembleias.fac.rotativityHint": "Rotating roles: alternate from one AG to the next — to avoid activist burnout and prevent entrenched power."
  },
  it: {
    "federacao.assembleias.fac.volunteer": "Mi propongo per facilitare",
    "federacao.assembleias.fac.volunteer.done": "Proposta registrata.",
    "federacao.assembleias.fac.unvolunteer": "Ritirare la mia proposta",
    "federacao.assembleias.fac.unvolunteer.done": "Proposta ritirata.",
    "federacao.assembleias.fac.youFacilitate": "Faciliti questa assemblea.",
    "federacao.assembleias.fac.volunteers.label": "Chi si propone per facilitare",
    "federacao.assembleias.fac.volunteers.none": "Nessuna proposta per ora.",
    "federacao.assembleias.fac.designate": "Designare",
    "federacao.assembleias.fac.designate.done": "Persona designata per facilitare.",
    "federacao.assembleias.fac.designated.label": "Chi facilita",
    "federacao.assembleias.fac.remove": "Rimuovere",
    "federacao.assembleias.fac.remove.done": "Rimossa dalla facilitazione.",
    "federacao.assembleias.fac.order.up": "↑ Su",
    "federacao.assembleias.fac.order.down": "↓ Giù",
    "federacao.assembleias.fac.anon": "Persona",
    "federacao.assembleias.fac.rotativityHint": "Funzioni a rotazione: alternatevi da un’AG all’altra — per evitare l’esaurimento militante e che si installi un potere."
  },
  de: {
    "federacao.assembleias.fac.volunteer": "Ich melde mich zum Moderieren",
    "federacao.assembleias.fac.volunteer.done": "Angebot gespeichert.",
    "federacao.assembleias.fac.unvolunteer": "Mein Angebot zurückziehen",
    "federacao.assembleias.fac.unvolunteer.done": "Angebot zurückgezogen.",
    "federacao.assembleias.fac.youFacilitate": "Du moderierst diese Versammlung.",
    "federacao.assembleias.fac.volunteers.label": "Wer sich zum Moderieren meldet",
    "federacao.assembleias.fac.volunteers.none": "Noch keine Meldung.",
    "federacao.assembleias.fac.designate": "Benennen",
    "federacao.assembleias.fac.designate.done": "Person zum Moderieren benannt.",
    "federacao.assembleias.fac.designated.label": "Wer moderiert",
    "federacao.assembleias.fac.remove": "Entfernen",
    "federacao.assembleias.fac.remove.done": "Aus der Moderation entfernt.",
    "federacao.assembleias.fac.order.up": "↑ Hoch",
    "federacao.assembleias.fac.order.down": "↓ Runter",
    "federacao.assembleias.fac.anon": "Mitglied",
    "federacao.assembleias.fac.rotativityHint": "Rotierende Funktionen: wechselt euch von einer VV zur nächsten ab — gegen Aktivismus-Erschöpfung und festgesetzte Macht."
  },
  ca: {
    "federacao.assembleias.fac.volunteer": "Em proposo per facilitar",
    "federacao.assembleias.fac.volunteer.done": "Proposta registrada.",
    "federacao.assembleias.fac.unvolunteer": "Retirar la meva proposta",
    "federacao.assembleias.fac.unvolunteer.done": "Proposta retirada.",
    "federacao.assembleias.fac.youFacilitate": "Facilites aquesta assemblea.",
    "federacao.assembleias.fac.volunteers.label": "Qui es proposa per facilitar",
    "federacao.assembleias.fac.volunteers.none": "Cap proposta de moment.",
    "federacao.assembleias.fac.designate": "Designar",
    "federacao.assembleias.fac.designate.done": "Persona designada per facilitar.",
    "federacao.assembleias.fac.designated.label": "Qui facilita",
    "federacao.assembleias.fac.remove": "Retirar",
    "federacao.assembleias.fac.remove.done": "Persona retirada de la facilitació.",
    "federacao.assembleias.fac.order.up": "↑ Pujar",
    "federacao.assembleias.fac.order.down": "↓ Baixar",
    "federacao.assembleias.fac.anon": "Membre",
    "federacao.assembleias.fac.rotativityHint": "Funcions rotatives: alterneu d’una AG a l’altra — per evitar l’esgotament militant i que s’instal·li un poder."
  },
  eo: {
    "federacao.assembleias.fac.volunteer": "Mi proponas min por faciligi",
    "federacao.assembleias.fac.volunteer.done": "Propono registrita.",
    "federacao.assembleias.fac.unvolunteer": "Retiri mian proponon",
    "federacao.assembleias.fac.unvolunteer.done": "Propono retirita.",
    "federacao.assembleias.fac.youFacilitate": "Vi faciligas ĉi tiun asembleon.",
    "federacao.assembleias.fac.volunteers.label": "Kiuj proponas sin por faciligi",
    "federacao.assembleias.fac.volunteers.none": "Neniu propono ĝis nun.",
    "federacao.assembleias.fac.designate": "Nomumi",
    "federacao.assembleias.fac.designate.done": "Persono nomumita por faciligi.",
    "federacao.assembleias.fac.designated.label": "Kiuj faciligas",
    "federacao.assembleias.fac.remove": "Forigi",
    "federacao.assembleias.fac.remove.done": "Forigita el la faciligado.",
    "federacao.assembleias.fac.order.up": "↑ Supren",
    "federacao.assembleias.fac.order.down": "↓ Malsupren",
    "federacao.assembleias.fac.anon": "Membro",
    "federacao.assembleias.fac.rotativityHint": "Rotaciaj funkcioj: alternu de unu AG al alia — por eviti la aktivulan elĉerpiĝon kaj ke potenco enradikiĝu."
  },
  nl: {
    "federacao.assembleias.fac.volunteer": "Ik stel me kandidaat om te faciliteren",
    "federacao.assembleias.fac.volunteer.done": "Aanbod geregistreerd.",
    "federacao.assembleias.fac.unvolunteer": "Mijn aanbod intrekken",
    "federacao.assembleias.fac.unvolunteer.done": "Aanbod ingetrokken.",
    "federacao.assembleias.fac.youFacilitate": "Jij faciliteert deze vergadering.",
    "federacao.assembleias.fac.volunteers.label": "Wie zich aanbiedt om te faciliteren",
    "federacao.assembleias.fac.volunteers.none": "Nog geen aanbod.",
    "federacao.assembleias.fac.designate": "Aanwijzen",
    "federacao.assembleias.fac.designate.done": "Persoon aangewezen om te faciliteren.",
    "federacao.assembleias.fac.designated.label": "Wie faciliteert",
    "federacao.assembleias.fac.remove": "Verwijderen",
    "federacao.assembleias.fac.remove.done": "Uit de facilitatie verwijderd.",
    "federacao.assembleias.fac.order.up": "↑ Omhoog",
    "federacao.assembleias.fac.order.down": "↓ Omlaag",
    "federacao.assembleias.fac.anon": "Lid",
    "federacao.assembleias.fac.rotativityHint": "Roterende functies: wissel elkaar af van de ene AV naar de andere — tegen activisme-uitputting en vastgeroeste macht."
  },
  el: {
    "federacao.assembleias.fac.volunteer": "Προτείνομαι για διευκόλυνση",
    "federacao.assembleias.fac.volunteer.done": "Η πρόταση καταγράφηκε.",
    "federacao.assembleias.fac.unvolunteer": "Απόσυρση της πρότασής μου",
    "federacao.assembleias.fac.unvolunteer.done": "Η πρόταση αποσύρθηκε.",
    "federacao.assembleias.fac.youFacilitate": "Διευκολύνεις αυτή τη συνέλευση.",
    "federacao.assembleias.fac.volunteers.label": "Όσα άτομα προτείνονται για διευκόλυνση",
    "federacao.assembleias.fac.volunteers.none": "Καμία πρόταση προς το παρόν.",
    "federacao.assembleias.fac.designate": "Ορισμός",
    "federacao.assembleias.fac.designate.done": "Ορίστηκε άτομο για τη διευκόλυνση.",
    "federacao.assembleias.fac.designated.label": "Όσα άτομα διευκολύνουν",
    "federacao.assembleias.fac.remove": "Αφαίρεση",
    "federacao.assembleias.fac.remove.done": "Αφαιρέθηκε από τη διευκόλυνση.",
    "federacao.assembleias.fac.order.up": "↑ Πάνω",
    "federacao.assembleias.fac.order.down": "↓ Κάτω",
    "federacao.assembleias.fac.anon": "Μέλος",
    "federacao.assembleias.fac.rotativityHint": "Εναλλασσόμενες λειτουργίες: εναλλάσσεστε από τη μία ΓΣ στην άλλη — για να αποφεύγεται η ακτιβιστική εξάντληση και η παγίωση εξουσίας."
  }
};

for (const loc of LOCALES) {
  const file = path.join(DIR, loc + '.json');
  let content = fs.readFileSync(file, 'utf8');
  if (!content.includes('"' + SENTINEL + '"')) {
    const map = ADD[loc];
    const keys = Object.keys(ADD['pt-BR']);
    const entries = keys.map((k) => {
      if (map[k] == null) throw new Error('Traduction manquante: ' + k + ' / ' + loc);
      return '  ' + JSON.stringify(k) + ': ' + JSON.stringify(map[k]);
    });
    const marker = content.lastIndexOf('}');
    content = content.slice(0, marker).replace(/\s*$/, '') + ',\n' + entries.join(',\n') + '\n' + content.slice(marker);
    if (!content.endsWith('\n')) content += '\n';
  }
  fs.writeFileSync(file, content, 'utf8');
  JSON.parse(fs.readFileSync(file, 'utf8'));
  console.log(loc + ': 16 clés fac.* P2c (si absentes), JSON valide.');
}
console.log('\nTerminé.');
