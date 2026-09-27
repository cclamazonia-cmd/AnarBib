/* ===========================================================================
 * i18n-es-ptbr-registre.cjs
 * DOC-ADDR-1 (registre informel de chaque langue, sans exception) — relevé le
 * 27/09/2026 après la passe française : douze valeurs de es.json et deux de
 * pt-BR.json s'adressaient encore à la personne au pluriel de politesse ou au
 * formel, et aucune garde ne les voyait.
 *
 * es : le « vosotros » dans les fenêtres de cooptation et de retrait collectif
 * (« Verificad », « Exponed », « Seleccionad », « Explicad », « Vuestra
 * decisión es decisiva ») — elles s'adressent à UNE personne, celle qui
 * propose ou qui vote, comme en fr (« Vérifie », « Ta décision ») — et le
 * « Usted » dans trois phrases (mode lecture seule, horaire de retrait). La
 * garde es ne cherchait que « usted » en minuscule : « Usted » passait.
 * pt-BR : « Exponei » (vós), dans les deux champs de motivation des mêmes
 * fenêtres ; « Exponha » (você).
 *
 * Réécriture DE → PARA, rejouable ; aucune de ces valeurs n'a de source dans
 * scripts/. La garde : src/tests/i18n-ecriture.test.js, chemin (4),
 * VOUVOIEMENT_ES, et src/tests/helpers/ptbr-tu-europeu.js (« exponei »).
 * Usage : node scripts/i18n-es-ptbr-registre.cjs
 * =========================================================================== */
const fs = require('fs');
const path = require('path');

const DOSSIER = path.join(__dirname, '..', 'src', 'i18n', 'locales');

// locale : { clé : [ancienne valeur, valeur au registre de la langue] }
const DE_PARA = {
  'es': {
    'biblioteca.privacy.readonlyHint': [
      'Usted está en modo de solo lectura. Solamente les coordinadores y administradores pueden modificar la política de retención.',
      'Estás en modo de solo lectura. Solamente les coordinadores y administradores pueden modificar la política de retención.',
    ],
    'rede.collectiveRemoval.propose.modal.motivationPlaceholder': [
      'Exponed en detalle las razones políticas de esta propuesta de retiro…',
      'Expón en detalle las razones políticas de esta propuesta de retiro…',
    ],
    'rede.collectiveRemoval.propose.modal.targetPlaceholder': [
      'Seleccionad une administrade activo…',
      'Selecciona une administrade activo…',
    ],
    'rede.collectiveRemoval.propose.modal.warning': [
      'Atención : decisión política grave. La unanimidad de les administradores activos (excluide le target) es necesaria. Se aplica un período de gracia de 7 días antes de la ejecución. Verificad que esta posición es colectivamente compartida.',
      'Atención : decisión política grave. La unanimidad de les administradores activos (excluide le target) es necesaria. Se aplica un período de gracia de 7 días antes de la ejecución. Verifica que esta posición es colectivamente compartida.',
    ],
    'rede.cooptation.propose.modal.description': [
      'La cooptación es una decisión política colectiva. La unanimidad de les administradores activos de la red es necesaria. Verificad que este camarade tiene la confianza colectiva de la red.',
      'La cooptación es una decisión política colectiva. La unanimidad de les administradores activos de la red es necesaria. Verifica que este camarade tiene la confianza colectiva de la red.',
    ],
    'rede.cooptation.propose.modal.motivationPlaceholder': [
      'Exponed la trayectoria militante de le camarade y la razón de esta propuesta…',
      'Expón la trayectoria militante de le camarade y la razón de esta propuesta…',
    ],
    'rede.cooptation.vote.discloseIdentityHint': [
      'Esta elección es obligatoria y se registra en cada voto. Les demás administradores ven siempre vuestra identidad.',
      'Esta elección es obligatoria y se registra en cada voto. Les demás administradores ven siempre tu identidad.',
    ],
    'rede.cooptation.vote.rationalePlaceholder': [
      'Explicad los motivos políticos de vuestra oposición…',
      'Explica los motivos políticos de tu oposición…',
    ],
    'rede.cooptation.vote.errors.discloseRequired': [
      'Vuestra elección sobre la divulgación de identidad es obligatoria.',
      'Tu elección sobre la divulgación de identidad es obligatoria.',
    ],
    'rede.cooptation.vote.modal.description': [
      'Vuestra decisión es decisiva : la unanimidad es necesaria. Un solo voto en contra cierra el proceso.',
      'Tu decisión es decisiva : la unanimidad es necesaria. Un solo voto en contra cierra el proceso.',
    ],
    'reservation.pickup.confirmed': [
      'Usted confirmó ese horario',
      'Confirmaste ese horario',
    ],
    'reservation.pickup.refused': [
      'Usted informó que no puede en ese horario',
      'Informaste que no puedes en ese horario',
    ],
  },
  'pt-BR': {
    'rede.collectiveRemoval.propose.modal.motivationPlaceholder': [
      'Exponei detalhadamente as razões políticas desta proposta de retirada…',
      'Exponha detalhadamente as razões políticas desta proposta de retirada…',
    ],
    'rede.cooptation.propose.modal.motivationPlaceholder': [
      'Exponei o caminho militante d(o/a/e) camarada e o porquê desta proposta…',
      'Exponha o caminho militante d(o/a/e) camarada e o porquê desta proposta…',
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
