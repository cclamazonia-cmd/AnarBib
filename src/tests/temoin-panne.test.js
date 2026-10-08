// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/temoin-panne.test.js
//
// CE QUE CE TEST PROTÈGE (backlog I31, 08/10/2026). Le 07/10, la base de
// production s'est arrêtée 21 minutes et personne n'a été prévenu : la sonde
// `health-probe` vit dans la base et tombe avec elle. deploy/ops/anarbib-temoin.sh
// regarde depuis le poste, toutes les cinq minutes, et écrit par le transport de
// courriel — sans la base — après deux échecs de suite, puis au retour.
//
// On exécute le VRAI script sous bash contre deux petits serveurs HTTP de ce
// test : « l'API » (dont on commande la réponse : 200, 522, connexion coupée) et
// « le contrôle » (codeberg.org dans la vie). Le transport est le mode fichier :
// on observe la DÉCISION d'écrire, à qui, avec quel sujet — tout le sujet.
//   * un seul échec : rien ; deux : un courriel « ne répond plus » ; un
//     troisième : pas de second courriel ; le retour : un courriel « répond de
//     nouveau » avec la durée ;
//   * l'API muette ET le contrôle muet : aveugle — ni échec compté ni courriel ;
//   * sans configuration : le témoin refuse (sortie 2) au lieu de veiller en
//     silence ;
//   * les unités systemd pointent le script, toutes les cinq minutes.

import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import { spawn } from 'node:child_process';
import { createServer } from 'node:http';
import { mkdtempSync, rmSync, readFileSync, existsSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const RACINE = fileURLToPath(new URL('../..', import.meta.url));
const SCRIPT = path.join(RACINE, 'deploy/ops/anarbib-temoin.sh');
const BASH = process.platform === 'win32'
  ? ['C:\\Program Files\\Git\\bin\\bash.exe', 'C:\\Program Files\\Git\\usr\\bin\\bash.exe'].find((p) => existsSync(p)) ?? null
  : 'bash';
const posix = (p) => p.replace(/\\/g, '/');

let ops; let api; let controle; let portApi; let portControle;
let modeApi = 200;   // 200 | 522 | 'coupe'

function ecouter(serveur) {
  return new Promise((ok) => serveur.listen(0, '127.0.0.1', () => ok(serveur.address().port)));
}

beforeAll(async () => {
  ops = mkdtempSync(path.join(tmpdir(), 'anarbib-temoin-'));
  api = createServer((req, res) => {
    if (modeApi === 'coupe') { req.socket.destroy(); return; }
    res.statusCode = modeApi; res.end(modeApi === 200 ? '[{"slug":"btl"}]' : 'origin unreachable');
  });
  controle = createServer((req, res) => { res.statusCode = 200; res.end('ok'); });
  portApi = await ecouter(api);
  portControle = await ecouter(controle);
});
afterAll(() => { api?.close(); controle?.close(); rmSync(ops, { recursive: true, force: true }); });

// `spawn`, jamais `spawnSync` : les deux serveurs HTTP vivent dans CE processus,
// et un appel bloquant les empêcherait de répondre au script (sondes à 000).
function passage(env = {}) {
  return new Promise((resoudre) => {
    let sortie = '';
    const p = spawn(BASH, [posix(SCRIPT)], {
      env: {
        PATH: process.env.PATH, HOME: posix(ops), OPS_DIR: posix(ops), TEMOIN_CONF: posix(path.join(ops, 'absent.env')),
        TEMOIN_TRANSPORT: 'fichier',
        TEMOIN_DESTINATAIRES: 'a@anarbib.test, b@anarbib.test',
        TEMOIN_EXPEDITEUR: 'AnarBib <temoin@anarbib.test>',
        TEMOIN_URL_REST: `http://127.0.0.1:${portApi}/rest`,
        TEMOIN_URL_AUTH: `http://127.0.0.1:${portApi}/auth`,
        TEMOIN_URL_CONTROLE: `http://127.0.0.1:${portControle}/`,
        TEMOIN_DELAI_S: '5',
        ...env,
      },
    });
    p.stdout.on('data', (d) => { sortie += d; });
    p.stderr.on('data', (d) => { sortie += d; });
    p.on('close', (rc) => resoudre({ rc, sortie }));
  });
}
const etat = () => Object.fromEntries(readFileSync(path.join(ops, 'temoin/etat'), 'utf8').trim().split('\n').map((l) => l.split('=')));
const courriels = () => (existsSync(path.join(ops, 'temoin/courriels.log')) ? readFileSync(path.join(ops, 'temoin/courriels.log'), 'utf8').trim().split('\n').filter(Boolean) : []);
const dernier = () => JSON.parse(readFileSync(path.join(ops, 'temoin/dernier-courriel.json'), 'utf8'));

describe.skipIf(!BASH)('le témoin de panne hors de la base (I31)', () => {
  it('l’API répond : état ok, aucun courriel, sortie 0', async () => {
    modeApi = 200;
    const r = await passage();
    expect(r.rc, r.sortie).toBe(0);
    expect(etat().etat).toBe('ok');
    expect(courriels()).toHaveLength(0);
  });

  it('un premier échec (522) : compté, pas encore écrit', async () => {
    modeApi = 522;
    const r = await passage();
    expect(r.rc, r.sortie).toBe(1);
    expect(etat()).toMatchObject({ echecs: '1', etat: 'ok' });
    expect(courriels()).toHaveLength(0);
  });

  it('le second échec (connexion coupée) : panne déclarée, un courriel aux deux adresses', async () => {
    modeApi = 'coupe';
    const r = await passage();
    expect(r.rc, r.sortie).toBe(1);
    expect(etat()).toMatchObject({ echecs: '2', etat: 'panne' });
    expect(courriels()).toHaveLength(1);
    const c = dernier();
    expect(c.to).toEqual(['a@anarbib.test', 'b@anarbib.test']);
    expect(c.from).toBe('AnarBib <temoin@anarbib.test>');
    expect(c.subject).toContain('ne répond plus');
    expect(c.text).toContain('REST → 000');
    expect(c.text).toContain('tableau de bord');
  });

  it('un troisième échec : la panne continue, pas de second courriel', async () => {
    modeApi = 522;
    const r = await passage();
    expect(r.rc, r.sortie).toBe(1);
    expect(etat()).toMatchObject({ echecs: '3', etat: 'panne' });
    expect(courriels()).toHaveLength(1);
  });

  it('le retour : un second courriel qui dit la durée, état ok, sortie 0', async () => {
    modeApi = 200;
    const r = await passage();
    expect(r.rc, r.sortie).toBe(0);
    expect(etat()).toMatchObject({ echecs: '0', etat: 'ok' });
    expect(courriels()).toHaveLength(2);
    const c = dernier();
    expect(c.subject).toMatch(/répond de nouveau \(panne de \d+ min/);
    expect(c.text).toContain('I32');
  });

  it('API muette et contrôle muet : aveugle — rien compté, rien écrit, sortie 3', async () => {
    modeApi = 'coupe';
    const r = await passage({ TEMOIN_URL_CONTROLE: 'http://127.0.0.1:9/' });
    expect(r.rc, r.sortie).toBe(3);
    expect(r.sortie).toContain('AVEUGLE');
    expect(etat()).toMatchObject({ echecs: '0', etat: 'ok' });
    expect(courriels()).toHaveLength(2);
  });

  it('sans configuration, le témoin refuse de veiller en silence (sortie 2)', async () => {
    modeApi = 200;
    const r = await passage({ TEMOIN_TRANSPORT: 'resend', TEMOIN_DESTINATAIRES: 'a@anarbib.test', RESEND_API_KEY: '' });
    expect(r.rc, r.sortie).toBe(2);
    expect(r.sortie).toContain('non configure');
  });

  it('les unités systemd lancent le script toutes les cinq minutes, sans OnFailure', () => {
    const service = readFileSync(path.join(RACINE, 'deploy/ops/systemd/anarbib-temoin.service'), 'utf8');
    const timer = readFileSync(path.join(RACINE, 'deploy/ops/systemd/anarbib-temoin.timer'), 'utf8');
    expect(service).toContain('ExecStart=%h/anarbib-ops/anarbib-temoin.sh');
    expect(service).toContain('SuccessExitStatus=1 3');
    expect(service).not.toMatch(/^OnFailure=/m);
    expect(timer).toContain('OnCalendar=*:0/5');
    expect(timer).toContain('Persistent=false');
    // l'exemple de configuration ne porte que des noms
    const exemple = readFileSync(path.join(RACINE, 'deploy/ops/temoin.env.example'), 'utf8');
    for (const l of exemple.split('\n')) if (/^[A-Z_]+=/.test(l)) expect(l, l).toMatch(/^[A-Z_]+=$/);
  });
});
