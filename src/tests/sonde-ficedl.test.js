// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/sonde-ficedl.test.js
//
// CE QUE CE TEST PROTÈGE (backlog H2, 12/10/2026). Le thésaurus de la FICEDL
// s'est dégradé sur un mois sans que personne le surveille ; l'export (H3) et
// le courriel à la FICEDL (H2) attendaient un site qu'on croyait mort.
// deploy/ops/anarbib-sonde-ficedl.sh demande une fiche par jour depuis le poste
// et écrit, par le transport de courriel du témoin de panne, après deux échecs
// de suite — puis le jour où le site revient, avec la durée en jours.
//
// Même banc que le témoin : le VRAI script sous bash contre deux petits serveurs
// HTTP de ce test (« la fiche » et « le contrôle »), transport fichier. On
// observe la DÉCISION d'écrire, à qui, avec quel sujet.

import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import { spawn } from 'node:child_process';
import { createServer } from 'node:http';
import { mkdtempSync, rmSync, readFileSync, existsSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const RACINE = fileURLToPath(new URL('../..', import.meta.url));
const SCRIPT = path.join(RACINE, 'deploy/ops/anarbib-sonde-ficedl.sh');
const BASH = process.platform === 'win32'
  ? ['C:\\Program Files\\Git\\bin\\bash.exe', 'C:\\Program Files\\Git\\usr\\bin\\bash.exe'].find((p) => existsSync(p)) ?? null
  : 'bash';
const posix = (p) => p.replace(/\\/g, '/');

let ops; let fiche; let controle; let portFiche; let portControle;
let modeFiche = 200;   // 200 | 503 | 'coupe'

function ecouter(serveur) {
  return new Promise((ok) => serveur.listen(0, '127.0.0.1', () => ok(serveur.address().port)));
}

beforeAll(async () => {
  ops = mkdtempSync(path.join(tmpdir(), 'anarbib-sonde-ficedl-'));
  fiche = createServer((req, res) => {
    if (modeFiche === 'coupe') { req.socket.destroy(); return; }
    res.statusCode = modeFiche; res.end(modeFiche === 200 ? '<html>anarchisme</html>' : 'Service Unavailable');
  });
  controle = createServer((req, res) => { res.statusCode = 200; res.end('ok'); });
  portFiche = await ecouter(fiche);
  portControle = await ecouter(controle);
});
afterAll(() => { fiche?.close(); controle?.close(); rmSync(ops, { recursive: true, force: true }); });

function passage(env = {}) {
  return new Promise((resoudre) => {
    let sortie = '';
    const p = spawn(BASH, [posix(SCRIPT)], {
      env: {
        PATH: process.env.PATH, HOME: posix(ops), OPS_DIR: posix(ops), TEMOIN_CONF: posix(path.join(ops, 'absent.env')),
        TEMOIN_TRANSPORT: 'fichier',
        TEMOIN_DESTINATAIRES: 'a@anarbib.test, b@anarbib.test',
        TEMOIN_EXPEDITEUR: 'AnarBib <temoin@anarbib.test>',
        SONDE_FICEDL_URL: `http://127.0.0.1:${portFiche}/spip.php?mot8`,
        SONDE_FICEDL_URL_CONTROLE: `http://127.0.0.1:${portControle}/`,
        SONDE_FICEDL_DELAI_S: '5',
        ...env,
      },
    });
    p.stdout.on('data', (d) => { sortie += d; });
    p.stderr.on('data', (d) => { sortie += d; });
    p.on('close', (rc) => resoudre({ rc, sortie }));
  });
}
const etat = () => Object.fromEntries(readFileSync(path.join(ops, 'sonde-ficedl/etat'), 'utf8').trim().split('\n').map((l) => l.split('=')));
const courriels = () => (existsSync(path.join(ops, 'sonde-ficedl/courriels.log')) ? readFileSync(path.join(ops, 'sonde-ficedl/courriels.log'), 'utf8').trim().split('\n').filter(Boolean) : []);
const dernier = () => JSON.parse(readFileSync(path.join(ops, 'sonde-ficedl/dernier-courriel.json'), 'utf8'));

describe.skipIf(!BASH)('la sonde du thésaurus FICEDL (H2)', () => {
  it('la fiche répond : état ok, aucun courriel, sortie 0', async () => {
    modeFiche = 200;
    const r = await passage();
    expect(r.rc, r.sortie).toBe(0);
    expect(etat().etat).toBe('ok');
    expect(courriels()).toHaveLength(0);
  });

  it('un premier échec (503) : compté, pas encore écrit', async () => {
    modeFiche = 503;
    const r = await passage();
    expect(r.rc, r.sortie).toBe(1);
    expect(etat()).toMatchObject({ echecs: '1', etat: 'ok' });
    expect(courriels()).toHaveLength(0);
  });

  it('le second échec (connexion coupée) : absence déclarée, un courriel aux deux adresses, qui dit d’écrire à la FICEDL', async () => {
    modeFiche = 'coupe';
    const r = await passage();
    expect(r.rc, r.sortie).toBe(1);
    expect(etat()).toMatchObject({ echecs: '2', etat: 'absent' });
    expect(courriels()).toHaveLength(1);
    const c = dernier();
    expect(c.to).toEqual(['a@anarbib.test', 'b@anarbib.test']);
    expect(c.from).toBe('AnarBib <temoin@anarbib.test>');
    expect(c.subject).toContain('ne répond plus');
    expect(c.text).toContain('→ 000');
    expect(c.text).toContain('H2');
    expect(c.text).toContain('H13');
  });

  it('un troisième échec : l’absence continue, pas de second courriel', async () => {
    modeFiche = 503;
    const r = await passage();
    expect(r.rc, r.sortie).toBe(1);
    expect(etat()).toMatchObject({ echecs: '3', etat: 'absent' });
    expect(courriels()).toHaveLength(1);
  });

  it('le retour : un second courriel qui dit la durée en jours, état ok, sortie 0', async () => {
    modeFiche = 200;
    const r = await passage();
    expect(r.rc, r.sortie).toBe(0);
    expect(etat()).toMatchObject({ echecs: '0', etat: 'ok' });
    expect(courriels()).toHaveLength(2);
    const c = dernier();
    expect(c.subject).toMatch(/répond de nouveau \(absent \d+ jour/);
    expect(c.text).toContain('le raclage (H13)');
    expect(c.text).toContain('le courriel à la FICEDL (H2)');
  });

  it('fiche muette et contrôle muet : aveugle — rien compté, rien écrit, sortie 3', async () => {
    modeFiche = 'coupe';
    const r = await passage({ SONDE_FICEDL_URL_CONTROLE: 'http://127.0.0.1:9/' });
    expect(r.rc, r.sortie).toBe(3);
    expect(r.sortie).toContain('AVEUGLE');
    expect(etat()).toMatchObject({ echecs: '0', etat: 'ok' });
    expect(courriels()).toHaveLength(2);
  });

  it('sans configuration, la sonde refuse de veiller en silence (sortie 2)', async () => {
    modeFiche = 200;
    const r = await passage({ TEMOIN_TRANSPORT: 'resend', TEMOIN_DESTINATAIRES: 'a@anarbib.test', RESEND_API_KEY: '' });
    expect(r.rc, r.sortie).toBe(2);
    expect(r.sortie).toContain('non configuree');
  });

  it('les unités systemd lancent le script une fois par jour, rattrapent un poste éteint, sans OnFailure', () => {
    const service = readFileSync(path.join(RACINE, 'deploy/ops/systemd/anarbib-sonde-ficedl.service'), 'utf8');
    const timer = readFileSync(path.join(RACINE, 'deploy/ops/systemd/anarbib-sonde-ficedl.timer'), 'utf8');
    expect(service).toContain('ExecStart=%h/anarbib-ops/anarbib-sonde-ficedl.sh');
    expect(service).toContain('SuccessExitStatus=1 3');
    expect(service).not.toMatch(/^OnFailure=/m);
    expect(timer).toContain('OnCalendar=*-*-* 10:30:00');
    expect(timer).toContain('Persistent=true');
    // la sonde lit une fiche de descripteur, jamais la une du site
    const script = readFileSync(SCRIPT, 'utf8');
    expect(script).toContain('https://thesaurus.ficedl.info/spip.php?mot8');
    expect(script).toContain("-A 'AnarBib-sonde (une requete par jour)'");
  });
});
