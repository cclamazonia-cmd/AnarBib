/* ===========================================================================
 * i18n-update-federacao-assembleias-host.cjs
 * Actualise federacao.assembleias.how.body dans les 10 locales :
 * Autistici a CONFIRMÉ l'hébergement (vc.autistici.org) → on retire
 * « probablement » et la mention meet.jit.si (devenues fausses). Mise à jour
 * par setKey (remplacement de valeur), idempotente.
 * Auteur : Claude (assistant)
 * Session : Fédération — Assemblée du réseau (AG)
 * =========================================================================== */
const fs = require('fs');
const path = require('path');

const LOCALES = ['ca', 'de', 'el', 'en', 'eo', 'es', 'fr', 'it', 'nl', 'pt-BR'];
const DIR = path.join(__dirname, '..', 'src', 'i18n', 'locales');
const KEY = 'federacao.assembleias.how.body';

const VAL = {
  'pt-BR': "A assembleia acontecerá a distância, por videoconferência, com a ferramenta livre Jitsi já usada no apoio mútuo — sem criar conta, sem instalar nada, sem gravação. É hospedada por um coletivo militante amigo, a Autistici (vc.autistici.org), e não por um serviço comercial. O link de acesso será comunicado junto com a convocação.",
  fr: "L’assemblée se tiendra à distance, en visioconférence, avec l’outil libre Jitsi déjà utilisé pour l’entraide — sans compte à créer, sans installation, sans enregistrement. Elle est hébergée par un collectif militant ami, Autistici (vc.autistici.org), et non par un service commercial. Le lien d’accès sera communiqué avec la convocation.",
  es: "La asamblea se realizará a distancia, por videollamada, con la herramienta libre Jitsi que ya usamos para el apoyo mutuo — sin crear cuenta, sin instalar nada, sin grabación. La aloja un colectivo militante amigo, Autistici (vc.autistici.org), no un servicio comercial. El enlace de acceso se comunicará junto con la convocatoria.",
  en: "The assembly will be held remotely, by video call, using the free software Jitsi already used for mutual aid — no account to create, nothing to install, no recording. It is hosted by a friendly activist collective, Autistici (vc.autistici.org), not a commercial service. The access link will be shared with the convening notice.",
  it: "L’assemblea si svolgerà a distanza, in videoconferenza, con lo strumento libero Jitsi già usato per il supporto reciproco — senza creare un account, senza installare nulla, senza registrazione. È ospitata da un collettivo militante amico, Autistici (vc.autistici.org), e non da un servizio commerciale. Il link di accesso sarà comunicato insieme alla convocazione.",
  de: "Die Versammlung findet aus der Ferne statt, per Videokonferenz, mit der freien Software Jitsi, die schon für die gegenseitige Hilfe genutzt wird — ohne Konto, ohne Installation, ohne Aufzeichnung. Sie wird von einem befreundeten militanten Kollektiv gehostet, Autistici (vc.autistici.org), nicht von einem kommerziellen Dienst. Der Zugangslink wird mit der Einberufung mitgeteilt.",
  ca: "L’assemblea es durà a terme a distància, per videoconferència, amb l’eina lliure Jitsi ja emprada per al suport mutu — sense crear cap compte, sense instal·lar res, sense enregistrament. L’allotja un col·lectiu militant amic, Autistici (vc.autistici.org), no pas un servei comercial. L’enllaç d’accés es comunicarà amb la convocatòria.",
  eo: "La asembleo okazos malproksime, per videokonferenco, kun la libera ilo Jitsi jam uzata por reciproka helpo — sen krei konton, sen instali ion, sen registrado. Ĝin gastigas amika aktivula kolektivo, Autistici (vc.autistici.org), ne komerca servo. La aliro-ligilo estos komunikita kun la kunvoko.",
  nl: "De vergadering wordt op afstand gehouden, via videogesprek, met het vrije gereedschap Jitsi dat al voor onderlinge hulp wordt gebruikt — zonder account, zonder installatie, zonder opname. Ze wordt gehost door een bevriend militant collectief, Autistici (vc.autistici.org), niet door een commerciële dienst. De toegangslink wordt met de bijeenroeping meegedeeld.",
  el: "Η συνέλευση θα διεξαχθεί εξ αποστάσεως, με βιντεοκλήση, με το ελεύθερο εργαλείο Jitsi που χρησιμοποιείται ήδη για την αλληλοβοήθεια — χωρίς λογαριασμό, χωρίς εγκατάσταση, χωρίς καταγραφή. Φιλοξενείται από μια φιλική μαχητική συλλογικότητα, την Autistici (vc.autistici.org), και όχι από εμπορική υπηρεσία. Ο σύνδεσμος πρόσβασης θα κοινοποιηθεί μαζί με τη σύγκληση."
};

function setKey(content, key, value) {
  const re = new RegExp('("' + key.replace(/\./g, '\\.') + '":\\s*)"[^"]*"');
  if (!re.test(content)) throw new Error('clé introuvable pour update: ' + key);
  return content.replace(re, '$1' + JSON.stringify(value));
}

for (const loc of LOCALES) {
  const file = path.join(DIR, loc + '.json');
  let content = fs.readFileSync(file, 'utf8');
  content = setKey(content, KEY, VAL[loc]);
  fs.writeFileSync(file, content, 'utf8');
  JSON.parse(fs.readFileSync(file, 'utf8'));
  console.log(loc + ': how.body actualisé (Autistici confirmé), JSON valide.');
}
console.log('\nTerminé.');
