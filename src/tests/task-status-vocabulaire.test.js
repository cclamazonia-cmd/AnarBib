// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/task-status-vocabulaire.test.js
//
// CE QUE CE TEST PROTÈGE. Du 31/08 au 29/09/2026, aucune tâche interne n'a pu
// être créée : la base tenait sept états par une CHECK, les écrans et cinq
// fonctions SQL parlaient encore l'ancien vocabulaire (`pendente`), et la
// priorité « normal » de l'écran n'existait pas en base (`media`). Le
// vocabulaire vit désormais dans `src/lib/taskStatus.js` ; ce banc garde :
//   1. la liste de l'écran = la liste de la contrainte, lue dans les migrations ;
//   2. les quatre écrans de tâches passent par la liste, aucun n'écrit l'ancien
//      état ni la priorité fantôme ;
//   3. chaque état a son libellé dans les dix locales ;
//   4. la migration de correction ne retape aucune fonction.

import { describe, it, expect } from 'vitest';
import { readFileSync, readdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import { TASK_STATES, TASK_LIVE, TASK_CLOSED, TASK_ADVANCE, TASK_PRIORITIES, isTaskClosed, taskStatusLabel } from '../lib/taskStatus.js';

const here = path.dirname(fileURLToPath(import.meta.url));
const racine = path.resolve(here, '..', '..');
const src = (rel) => readFileSync(path.resolve(here, '..', rel), 'utf8');
const migrations = path.join(racine, 'supabase', 'migrations');

function derniereCheck(nom) {
  const fichiers = readdirSync(migrations).filter(f => /^\d{14}_.*\.sql$/.test(f)).sort();
  let trouve = null;
  for (const f of fichiers) {
    const sql = readFileSync(path.join(migrations, f), 'utf8');
    const m = sql.match(new RegExp(`ADD CONSTRAINT ${nom}\\s+CHECK \\(([^;]+?)\\);`, 's'));
    if (m) trouve = { fichier: f, valeurs: [...m[1].matchAll(/'([a-z_]+)'/g)].map(x => x[1]) };
  }
  return trouve;
}

describe('vocabulaire des tâches internes', () => {
  it('la liste de l’écran est celle de la contrainte de la base', () => {
    const check = derniereCheck('painel_internal_tasks_status_check');
    expect(check, 'contrainte introuvable dans les migrations').toBeTruthy();
    expect([...TASK_STATES].sort()).toEqual([...check.valeurs].sort());
    expect(TASK_STATES).not.toContain('pendente');
    // vivants + sortis = tout le cycle, sans recouvrement
    expect([...TASK_LIVE, ...TASK_CLOSED].sort()).toEqual([...TASK_STATES].sort());
    expect(TASK_LIVE.filter(s => TASK_CLOSED.includes(s))).toEqual([]);
    for (const s of TASK_ADVANCE) expect(TASK_STATES).toContain(s);
    expect(isTaskClosed('arquivada')).toBe(true);
    expect(isTaskClosed('bloqueada')).toBe(false);
  });

  it('les priorités sont celles de la base', () => {
    const check = derniereCheck('painel_recurring_task_rules_template_priority_chk');
    if (check) expect([...TASK_PRIORITIES].sort()).toEqual([...check.valeurs].sort());
    expect(TASK_PRIORITIES).toEqual(['baixa', 'media', 'alta']);
  });

  it('un libellé par état, un code brut jamais perdu', () => {
    const t = ({ id }) => `«${id}»`;
    for (const s of TASK_STATES) expect(taskStatusLabel(t, s)).toBe(`«task.status.${s}»`);
    expect(taskStatusLabel(t, 'pendente')).toBe('«task.status.pendente»');
    expect(taskStatusLabel(t, 'inconnu')).toBe('inconnu');
    expect(taskStatusLabel(t, null)).toBe('—');
  });

  it('chaque état a son libellé dans les dix locales', () => {
    const dossier = path.resolve(here, '..', 'i18n', 'locales');
    const locales = readdirSync(dossier).filter(f => f.endsWith('.json'));
    expect(locales.length).toBe(10);
    for (const f of locales) {
      const j = JSON.parse(readFileSync(path.join(dossier, f), 'utf8'));
      for (const s of TASK_STATES) {
        expect(typeof j[`task.status.${s}`], `${f} : task.status.${s}`).toBe('string');
        expect(j[`task.status.${s}`].trim().length, `${f} : task.status.${s} vide`).toBeGreaterThan(0);
      }
    }
  });
});

describe('les écrans de tâches passent par le vocabulaire', () => {
  const section = src('pages/biblioteca/TasksSection.jsx');
  const jour = src('pages/painel/tabs/TabTrabalhoDoDia.jsx');
  const partage = src('pages/painel/_shared.jsx');
  const painel = src('pages/painel/PanelPage.jsx');
  const page = src('pages/biblioteca/BibliotecaPage.jsx');

  it('aucun écran n’écrit l’ancien état', () => {
    for (const [nom, s] of [['TasksSection', section], ['TabTrabalhoDoDia', jour], ['_shared', partage]]) {
      expect(s.includes('value="pendente"'), `${nom} propose encore pendente`).toBe(false);
      expect(s).toMatch(/from '@\/lib\/taskStatus';/);
    }
    expect(section).toMatch(/\{TASK_STATES\.map\(s => <option key=\{s\} value=\{s\}>\{taskStatusLabel\(t, s\)\}<\/option>\)\}/);
    expect(jour).toMatch(/\{TASK_STATES\.map\(s => <option key=\{s\} value=\{s\}>\{taskStatusLabel\(t, s\)\}<\/option>\)\}/);
    expect(partage).toMatch(/\{TASK_ADVANCE\.map\(s => <option key=\{s\} value=\{s\}>\{taskStatusLabel\(t, s\)\}<\/option>\)\}/);
    expect(painel).toMatch(/const statusLabel = taskStatusLabel\(t, tk\.status\);/);
  });

  it('la nouvelle tâche part avec une priorité que la base connaît', () => {
    expect(section).toMatch(/useState\(\{ title: '', description: '', priority: 'media', owner: '' \}\)/);
    expect(section.includes('option value="normal"')).toBe(false);
    // les deux sélecteurs de priorité (tâche, modèle) proposent les trois valeurs de la base
    for (const v of TASK_PRIORITIES) {
      expect((section.match(new RegExp(`<option value="${v}">`, 'g')) || []).length, `priorité ${v}`).toBe(2);
    }
    // et l'écran sait nommer « media », qu'il affichait en code brut
    expect(page).toMatch(/media:\s+t\(\{ id: 'biblioteca\.tasks\.priority\.normal' \}\)/);
  });

  it('une tâche archivée est une tâche close', () => {
    expect(section).toMatch(/if \(isTaskClosed\(tk\.status\)\) continue;/);
    expect(section).toMatch(/tasks\.filter\(tk => isTaskClosed\(tk\.status\)\)/);
  });

  it('le rapport sait nommer les sept états', () => {
    expect(page).toMatch(/Object\.fromEntries\(\[\.\.\.TASK_STATES, 'pendente'\]\.map\(s => \[s, taskStatusLabel\(t, s\)\]\)\)/);
  });
});

describe('la migration de correction', () => {
  const f = readdirSync(migrations).find(n => n.endsWith('_les_fonctions_des_taches_parlent_les_sept_etats.sql'));
  const sql = f ? readFileSync(path.join(migrations, f), 'utf8') : '';

  it('repart de la définition réelle et compte ses remplacements', () => {
    expect(f, 'migration introuvable').toBeTruthy();
    expect(sql).toMatch(/pg_get_functiondef\(r\.oid\)/);
    expect(sql).toMatch(/IF v_n <> v_attendu THEN/);
    expect(sql).toMatch(/EXECUTE v_def;/);
    // aucune fonction retapée à la main
    expect(sql.includes('CREATE OR REPLACE FUNCTION')).toBe(false);
    for (const nom of ['fn_task_create', 'fn_task_instantiate_template', 'fn_task_update_status', 'fn_notify_fonds_deposit_received', 'fn_cron_tasks_detect_stale_recurrence']) {
      expect(sql.includes(`'${nom}'`), nom).toBe(true);
    }
  });

  it('la sonde des récurrences regarde les états vivants', () => {
    const m = sql.match(/v_neuf\s+:= \$v\$\(([^)]*)\)\$v\$;/);
    expect(m).toBeTruthy();
    expect([...m[1].matchAll(/'([a-z_]+)'/g)].map(x => x[1])).toEqual(TASK_LIVE);
  });
});
