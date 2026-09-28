#!/usr/bin/env node
// Résume un journal de catalogue-mesure.sql : par cas, la moyenne des trois
// derniers appels (le premier chauffe), la valeur rendue, les erreurs.
// usage : node catalogue-mesure-resume.cjs <étape> <journal> [<journal>…]
const fs = require('fs');
const [etape, ...journaux] = process.argv.slice(2);
if (!etape || journaux.length === 0) { console.error('usage : catalogue-mesure-resume.cjs <étape> <journal>…'); process.exit(1); }
for (const chemin of journaux) {
  const lignes = [];
  let cas = null, temps = [], valeur = null, erreur = null;
  const clore = () => {
    if (cas === null) return;
    if (erreur) lignes.push([cas, null, null, erreur]);
    else if (temps.length >= 2) lignes.push([cas, temps.slice(1).reduce((a, b) => a + b, 0) / (temps.length - 1), valeur, null]);
    else lignes.push([cas, null, valeur, `incomplet (${temps.length} temps)`]);
  };
  for (const l of fs.readFileSync(chemin, 'utf8').split('\n')) {
    if (l.startsWith('CAS ')) { clore(); cas = l.slice(4); temps = []; valeur = null; erreur = null; continue; }
    if (cas === null) continue;
    const t = /^Time: ([0-9.]+) ms/.exec(l);
    if (t) temps.push(parseFloat(t[1]));
    else if (l.includes('ERROR') && !erreur) erreur = l.split('ERROR:').pop().trim().slice(0, 90);
    else { const v = /^\s*(-?\d+)\s*$/.exec(l); if (v && valeur === null) valeur = parseInt(v[1], 10); }
  }
  clore();
  for (const [c, moy, v, e] of lignes) {
    console.log(e ? ` ${etape} | ${c.padEnd(48)} | ${'ERREUR'.padStart(9)} | ${e}`
                  : ` ${etape} | ${c.padEnd(48)} | ${moy.toFixed(1).padStart(9)} | ${v === null ? '' : String(v).padStart(6)}`);
  }
}
