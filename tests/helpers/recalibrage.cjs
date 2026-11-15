'use strict';
// Simulation de recalibrage et d'injection de bug pour la preuve de docs/tests-robustes-20261114.md.
// Sans variable d'environnement, ce module ne fait rien : les harnais l'appellent à chaque création
// de contexte, au coût d'un test de variable.
//   CD_RECALIBRAGE='{"ESSAIS.porte":1.1,"PENALITES.jeu":1.1}'  : multiplie les taux du moteur (course, finition,
//                                                                 pénalités, réussite au but…) dans la VM.
//   CD_BUG=essai-sans-points                                     : injecte un vrai défaut de règle (l'essai ne
//                                                                 rapporte plus ses 5 points).
// Une règle du jeu ou une statistique bien posée doit survivre au premier, et le second doit la faire échouer.
const COEFFICIENTS = (() => {
  try { return process.env.CD_RECALIBRAGE ? JSON.parse(process.env.CD_RECALIBRAGE) : null; } catch { throw Error('CD_RECALIBRAGE : JSON invalide'); }
})();
const BUG = process.env.CD_BUG || '';
// Patchs de source : [fonction du moteur, texte remplacé, texte de remplacement].
const BUGS = {
  'essai-sans-points': ['scoreTry', 'l.score[side]+=5', 'l.score[side]+=0'],
  'transformation-sans-points': ['scoreTry', 'l.score[side]+=2', 'l.score[side]+=0'],
};
function appliquer(run) {
  if (COEFFICIENTS) for (const [chemin, facteur] of Object.entries(COEFFICIENTS)) {
    if (!/^[A-Za-z_.]+$/.test(chemin) || typeof facteur !== 'number') throw Error('CD_RECALIBRAGE : ' + chemin);
    run(`if(typeof ${chemin.split('.')[0]}==='undefined'||typeof ${chemin}!=='number')throw Error('Taux inconnu : ${chemin}');${chemin}*=${facteur}`);
  }
  if (BUG) {
    const patch = BUGS[BUG];
    if (!patch) throw Error('CD_BUG inconnu : ' + BUG);
    run(`(()=>{const source=${patch[0]}.toString();if(!source.includes(${JSON.stringify(patch[1])}))throw Error('Bug non applicable : ${BUG}');globalThis.${patch[0]}=(0,eval)('('+source.replace(${JSON.stringify(patch[1])},${JSON.stringify(patch[2])})+')')})()`);
  }
}
module.exports = { appliquer, actif: Boolean(COEFFICIENTS || BUG), COEFFICIENTS, BUG };
