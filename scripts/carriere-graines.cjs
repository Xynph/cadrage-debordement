'use strict';
// Lance une sonde de carrière sur plusieurs graines, un processus par graine, au plus --max à la fois (défaut 8 ; PC de Léo
// 16 cœurs : jusqu'à 14 simulations en tout ; machine cloud : 3). {graine} dans les arguments est remplacé par la graine ; la sortie de chaque
// graine va dans <journaux>/graine-<g>.log. Code de sortie : 1 si une graine a échoué.
// Usage : node scripts/carriere-graines.cjs --graines 4242,7,99 [--max 3] [--journaux dossier] -- scripts/carriere-chrono.cjs --graine {graine} --saisons 2 --sortie e-{graine}.json
const { spawn } = require('node:child_process');
const fs = require('node:fs');
const path = require('node:path');
const args = process.argv.slice(2), fin = args.indexOf('--');
if (fin < 0 || fin === args.length - 1) { console.error('Usage : --graines a,b,c [--max n] [--journaux d] -- script.cjs args… ({graine} remplacé)'); process.exit(2); }
const avant = args.slice(0, fin), commande = args.slice(fin + 1), opt = (n, d) => { const i = avant.indexOf(n); return i >= 0 ? avant[i + 1] : d; };
const graines = String(opt('--graines', '')).split(',').filter(Boolean), max = Math.max(1, Number(opt('--max', 8)));
const journaux = path.resolve(opt('--journaux', '.'));
fs.mkdirSync(journaux, { recursive: true });
const t0 = Date.now(), file = [...graines], resultats = [];
let actifs = 0;
const suivant = () => {
  while (actifs < max && file.length) {
    const g = file.shift(), log = path.join(journaux, 'graine-' + g + '.log'), out = fs.openSync(log, 'w'), t = Date.now();
    const enfant = spawn(process.execPath, commande.map(a => a.replaceAll('{graine}', g)), { stdio: ['ignore', out, out], windowsHide: true });
    actifs++;
    console.log('graine ' + g + ' lancée → ' + log);
    enfant.on('exit', code => {
      fs.closeSync(out); actifs--;
      resultats.push({ g, code, s: Math.round((Date.now() - t) / 1000) });
      console.log('graine ' + g + (code === 0 ? ' terminée' : ' en ÉCHEC (code ' + code + ')') + ' en ' + Math.round((Date.now() - t) / 1000) + ' s');
      if (file.length) suivant();
      else if (actifs === 0) {
        console.log('total ' + Math.round((Date.now() - t0) / 1000) + ' s');
        process.exitCode = resultats.some(r => r.code !== 0) ? 1 : 0;
      }
    });
  }
};
suivant();
