/**
 * Merge OAI-PMH i18n keys into all 10 locale files.
 * Run: node scripts/merge-imp-oai-keys.cjs
 * Session : Lot 3a – OAI-PMH infrastructure
 */
const fs = require('fs');
const path = require('path');

const LOCALES_DIR = path.resolve(__dirname, '../src/i18n/locales');

const NEW_KEYS = {
  'pt-BR': {
    'importacoes.oai.title': 'Colheita OAI-PMH',
    'importacoes.oai.desc': 'Moissonnage automatico semanal de catalogos expostos via protocolo OAI-PMH. A configuracao das fontes e reservada a(o/e) administrador(a/e) de rede.',
    'importacoes.oai.noSources': 'Nenhuma fonte OAI-PMH configurada. Contate o(a/e) administrador(a/e) de rede.',
    'importacoes.oai.harvestNow': 'Colher agora',
    'importacoes.oai.harvesting': 'Colheita em andamento…',
    'importacoes.oai.harvestStarted': 'Colheita iniciada (run #{id}).',
    'importacoes.oai.lotsPerCycle': '{n} lotes/ciclo',
    'importacoes.oai.totalHarvested': '{n} registros colhidos',
    'importacoes.oai.lastHarvest': 'Ultima colheita:',
    'importacoes.oai.status.idle': 'Inativo',
    'importacoes.oai.status.in_progress': 'Em andamento',
    'importacoes.oai.status.paused': 'Pausado',
    'importacoes.oai.status.error': 'Erro',
    'importacoes.oai.status.completed': 'Concluido',
  },
  fr: {
    'importacoes.oai.title': 'Moissonnage OAI-PMH',
    'importacoes.oai.desc': 'Moissonnage automatique hebdomadaire de catalogues exposes via le protocole OAI-PMH. La configuration des sources est reservee a l\'admin reseau.',
    'importacoes.oai.noSources': 'Aucune source OAI-PMH configuree. Contactez l\'admin reseau.',
    'importacoes.oai.harvestNow': 'Moissonner maintenant',
    'importacoes.oai.harvesting': 'Moissonnage en cours…',
    'importacoes.oai.harvestStarted': 'Moissonnage lance (run #{id}).',
    'importacoes.oai.lotsPerCycle': '{n} lots/cycle',
    'importacoes.oai.totalHarvested': '{n} notices moissonnees',
    'importacoes.oai.lastHarvest': 'Dernier moissonnage :',
    'importacoes.oai.status.idle': 'Inactif',
    'importacoes.oai.status.in_progress': 'En cours',
    'importacoes.oai.status.paused': 'En pause',
    'importacoes.oai.status.error': 'Erreur',
    'importacoes.oai.status.completed': 'Termine',
  },
  es: {
    'importacoes.oai.title': 'Cosecha OAI-PMH',
    'importacoes.oai.desc': 'Cosecha automatica semanal de catalogos expuestos via protocolo OAI-PMH. La configuracion de fuentes esta reservada a le administradore de red.',
    'importacoes.oai.noSources': 'Ninguna fuente OAI-PMH configurada. Contacte a le administradore de red.',
    'importacoes.oai.harvestNow': 'Cosechar ahora',
    'importacoes.oai.harvesting': 'Cosecha en curso…',
    'importacoes.oai.harvestStarted': 'Cosecha iniciada (run #{id}).',
    'importacoes.oai.lotsPerCycle': '{n} lotes/ciclo',
    'importacoes.oai.totalHarvested': '{n} registros cosechades',
    'importacoes.oai.lastHarvest': 'Ultima cosecha:',
    'importacoes.oai.status.idle': 'Inactive',
    'importacoes.oai.status.in_progress': 'En curso',
    'importacoes.oai.status.paused': 'Pausade',
    'importacoes.oai.status.error': 'Error',
    'importacoes.oai.status.completed': 'Completade',
  },
  en: {
    'importacoes.oai.title': 'OAI-PMH harvesting',
    'importacoes.oai.desc': 'Automatic weekly harvesting of catalogs exposed via OAI-PMH protocol. Source configuration is restricted to network admins.',
    'importacoes.oai.noSources': 'No OAI-PMH sources configured. Contact the network admin.',
    'importacoes.oai.harvestNow': 'Harvest now',
    'importacoes.oai.harvesting': 'Harvesting…',
    'importacoes.oai.harvestStarted': 'Harvest started (run #{id}).',
    'importacoes.oai.lotsPerCycle': '{n} lots/cycle',
    'importacoes.oai.totalHarvested': '{n} records harvested',
    'importacoes.oai.lastHarvest': 'Last harvest:',
    'importacoes.oai.status.idle': 'Idle',
    'importacoes.oai.status.in_progress': 'In progress',
    'importacoes.oai.status.paused': 'Paused',
    'importacoes.oai.status.error': 'Error',
    'importacoes.oai.status.completed': 'Completed',
  },
  it: {
    'importacoes.oai.title': 'Raccolta OAI-PMH',
    'importacoes.oai.desc': 'Raccolta automatica settimanale di cataloghi esposti tramite protocollo OAI-PMH. La configurazione delle fonti e riservata all\'amministratore/trice di rete.',
    'importacoes.oai.noSources': 'Nessuna fonte OAI-PMH configurata. Contattare l\'amministratore/trice di rete.',
    'importacoes.oai.harvestNow': 'Raccogliere ora',
    'importacoes.oai.harvesting': 'Raccolta in corso…',
    'importacoes.oai.harvestStarted': 'Raccolta avviata (run #{id}).',
    'importacoes.oai.lotsPerCycle': '{n} lotti/ciclo',
    'importacoes.oai.totalHarvested': '{n} registri raccolti',
    'importacoes.oai.lastHarvest': 'Ultima raccolta:',
    'importacoes.oai.status.idle': 'Inattiv*',
    'importacoes.oai.status.in_progress': 'In corso',
    'importacoes.oai.status.paused': 'In pausa',
    'importacoes.oai.status.error': 'Errore',
    'importacoes.oai.status.completed': 'Completat*',
  },
  de: {
    'importacoes.oai.title': 'OAI-PMH-Ernte',
    'importacoes.oai.desc': 'Automatische wochentliche Ernte von Katalogen uber das OAI-PMH-Protokoll. Die Quellkonfiguration ist Netzwerkadmin*innen vorbehalten.',
    'importacoes.oai.noSources': 'Keine OAI-PMH-Quellen konfiguriert. Kontaktiere die*den Netzwerkadmin*in.',
    'importacoes.oai.harvestNow': 'Jetzt ernten',
    'importacoes.oai.harvesting': 'Ernte lauft…',
    'importacoes.oai.harvestStarted': 'Ernte gestartet (Run #{id}).',
    'importacoes.oai.lotsPerCycle': '{n} Lose/Zyklus',
    'importacoes.oai.totalHarvested': '{n} Datensatze geerntet',
    'importacoes.oai.lastHarvest': 'Letzte Ernte:',
    'importacoes.oai.status.idle': 'Inaktiv',
    'importacoes.oai.status.in_progress': 'Laufend',
    'importacoes.oai.status.paused': 'Pausiert',
    'importacoes.oai.status.error': 'Fehler',
    'importacoes.oai.status.completed': 'Abgeschlossen',
  },
  ca: {
    'importacoes.oai.title': 'Recol-leccio OAI-PMH',
    'importacoes.oai.desc': 'Recol-leccio automatica setmanal de catalegs exposats via protocol OAI-PMH. La configuracio de fonts es reservada a le administrador-a-e de xarxa.',
    'importacoes.oai.noSources': 'Cap font OAI-PMH configurada. Contacteu le administrador-a-e de xarxa.',
    'importacoes.oai.harvestNow': 'Recollir ara',
    'importacoes.oai.harvesting': 'Recol-leccio en curs…',
    'importacoes.oai.harvestStarted': 'Recol-leccio iniciada (run #{id}).',
    'importacoes.oai.lotsPerCycle': '{n} lots/cicle',
    'importacoes.oai.totalHarvested': '{n} registres recollits',
    'importacoes.oai.lastHarvest': 'Ultima recol-leccio:',
    'importacoes.oai.status.idle': 'Inactiu-va-ve',
    'importacoes.oai.status.in_progress': 'En curs',
    'importacoes.oai.status.paused': 'En pausa',
    'importacoes.oai.status.error': 'Error',
    'importacoes.oai.status.completed': 'Completat-da-de',
  },
  eo: {
    'importacoes.oai.title': 'OAI-PMH-rikolto',
    'importacoes.oai.desc': 'Auxtomata semajna rikolto de katalogoj ekspozitaj per OAI-PMH-protokolo. La fonta agordo estas rezervita al retadministrant-in-o.',
    'importacoes.oai.noSources': 'Neniu OAI-PMH-fonto agordita. Kontaktu la retadministrant-in-on.',
    'importacoes.oai.harvestNow': 'Rikolti nun',
    'importacoes.oai.harvesting': 'Rikolto okazas…',
    'importacoes.oai.harvestStarted': 'Rikolto komencita (rulo #{id}).',
    'importacoes.oai.lotsPerCycle': '{n} lotoj/ciklo',
    'importacoes.oai.totalHarvested': '{n} registroj rikoltitaj',
    'importacoes.oai.lastHarvest': 'Lasta rikolto:',
    'importacoes.oai.status.idle': 'Neaktiva',
    'importacoes.oai.status.in_progress': 'Okazanta',
    'importacoes.oai.status.paused': 'Pauxzita',
    'importacoes.oai.status.error': 'Eraro',
    'importacoes.oai.status.completed': 'Finita',
  },
  nl: {
    'importacoes.oai.title': 'OAI-PMH-oogst',
    'importacoes.oai.desc': 'Automatische wekelijkse oogst van catalogi via het OAI-PMH-protocol. Bronconfiguratie is voorbehouden aan netwerkbeheerders.',
    'importacoes.oai.noSources': 'Geen OAI-PMH-bronnen geconfigureerd. Neem contact op met de netwerkbeheerder.',
    'importacoes.oai.harvestNow': 'Nu oogsten',
    'importacoes.oai.harvesting': 'Oogst bezig…',
    'importacoes.oai.harvestStarted': 'Oogst gestart (run #{id}).',
    'importacoes.oai.lotsPerCycle': '{n} loten/cyclus',
    'importacoes.oai.totalHarvested': '{n} records geoogst',
    'importacoes.oai.lastHarvest': 'Laatste oogst:',
    'importacoes.oai.status.idle': 'Inactief',
    'importacoes.oai.status.in_progress': 'Bezig',
    'importacoes.oai.status.paused': 'Gepauzeerd',
    'importacoes.oai.status.error': 'Fout',
    'importacoes.oai.status.completed': 'Voltooid',
  },
  el: {
    'importacoes.oai.title': 'Συλλογη OAI-PMH',
    'importacoes.oai.desc': 'Αυτοματη εβδομαδιαια συλλογη καταλογων μεσω πρωτοκολλου OAI-PMH. Η διαμορφωση πηγων ειναι μονο για διαχειριστες δικτυου.',
    'importacoes.oai.noSources': 'Δεν εχουν ρυθμιστει πηγες OAI-PMH. Επικοινωνηστε με τον διαχειριστη δικτυου.',
    'importacoes.oai.harvestNow': 'Συλλογη τωρα',
    'importacoes.oai.harvesting': 'Συλλογη σε εξελιξη…',
    'importacoes.oai.harvestStarted': 'Συλλογη ξεκινησε (run #{id}).',
    'importacoes.oai.lotsPerCycle': '{n} παρτιδες/κυκλο',
    'importacoes.oai.totalHarvested': '{n} εγγραφες συλλεχθηκαν',
    'importacoes.oai.lastHarvest': 'Τελευταια συλλογη:',
    'importacoes.oai.status.idle': 'Ανενεργο',
    'importacoes.oai.status.in_progress': 'Σε εξελιξη',
    'importacoes.oai.status.paused': 'Σε παυση',
    'importacoes.oai.status.error': 'Σφαλμα',
    'importacoes.oai.status.completed': 'Ολοκληρωθηκε',
  },
};

const LOCALE_TO_FILE = {
  'pt-BR': 'pt-BR.json', fr: 'fr.json', es: 'es.json', en: 'en.json',
  it: 'it.json', de: 'de.json', ca: 'ca.json', eo: 'eo.json',
  nl: 'nl.json', el: 'el.json',
};

let totalAdded = 0;
for (const [locale, newKeys] of Object.entries(NEW_KEYS)) {
  const filePath = path.join(LOCALES_DIR, LOCALE_TO_FILE[locale]);
  const raw = fs.readFileSync(filePath, 'utf8');
  const existing = JSON.parse(raw);
  let added = 0;
  for (const [k, v] of Object.entries(newKeys)) {
    if (!(k in existing)) { existing[k] = v; added++; }
  }
  const sorted = Object.keys(existing).sort().reduce((o, k) => { o[k] = existing[k]; return o; }, {});
  fs.writeFileSync(filePath, JSON.stringify(sorted, null, 2) + '\n', 'utf8');
  console.log(`${LOCALE_TO_FILE[locale]}: +${added} keys (total ${Object.keys(sorted).length})`);
  totalAdded += added;
}
console.log(`\nDone. Total new keys added: ${totalAdded}`);
