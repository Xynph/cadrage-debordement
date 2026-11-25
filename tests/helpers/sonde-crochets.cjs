'use strict';
// Instrumente les crochets de fin de semaine des modules du moteur (sonde de mesure, jamais chargée par le jeu).
// À appeler AVANT de charger worker.cjs : la fabrique de chaque module est réécrite avec un compteur
// `__sonde('<module>:<déclencheur>')` en tête de son crochet ; le texte réécrit est celui que le moteur
// injecte dans sa machine virtuelle (factory.toString()).
const path = require('node:path');
const ENGINE = path.join(__dirname, '..', '..', 'native', 'engine');
const S = k => `typeof __sonde==='function'&&__sonde(${k});`;

// [module, [texte exact à trouver, clé]] : le compteur est inséré juste après le texte trouvé.
const POINTS = [
  ['academy', [['g.finishRound=function(){', "'academy:finishRound'"], ['g.trainWeek=function(){', "'academy:trainWeek'"]]],
  ['academy-intake', [['const original=finishRound,wrapped=function(){', "'academy-intake:finishRound'"]]],
  ['academy-follow-up', [['const original=finishRound,wrapped=function(){', "'academy-follow-up:finishRound'"]]],
  ['avant-saison', [["const wrapped=function(){const s=typeof S==='undefined'?null:S;if(s&&s.preseason!==undefined)open(s);", "'avant-saison:'+name"]]],
  ['club-meetings', [['const wrapped=function(){\n     const before=S?context():null', "'club-meetings:'+name", true]]],
  ['club-sheet', [['const original=finishRound,wrapped=function(){', "'club-sheet:finishRound'"]]],
  ['club-strategy', [['const previousFinish=finishRound;finishRound=function(){', "'club-strategy:finishRound'"]]],
  ['espoirs-match', [
    ['if(typeof finishRound===\'function\'&&!finishRound.__espoirsMatch){\n   const original=finishRound,wrapped=function(){', "'espoirs-match:finishRound'"],
    ['if(typeof finishRound===\'function\'&&!finishRound.__espoirsOwn){\n   const original=finishRound,wrapped=function(){', "'espoirs-own:finishRound'"],
    ['const original=repairSheet,wrapped=function(){', "'espoirs-own:repairSheet'"]]],
  ['press-promises', [['const previous=finishRound;finishRound=function(){', "'press-promises:finishRound'"]]],
  ['jiff', [['const original=finishRound,wrapped=function(){', "'jiff:finishRound'"]]],
  ['match-notes', [['const fin=finishRound;finishRound=function(){', "'match-notes:finishRound'"], ['if(st.semaine&&!st.semaine.annoncee){', "'match-notes:nouvelle-journee'"]]],
  ['youth-matches', [['const wrapped=function(){const result=original.apply(this,arguments);tick();', "'youth-matches:'+name", true]]],
  ['youth-national', [['const original=finishRound,wrapped=function(){', "'youth-national:finishRound'"], ['const original=trainWeek,wrapped=function(){', "'youth-national:trainWeek'"]]],
  ['reprise', [["wrap('finishRound',()=>{", "'reprise:finishRound'"], ["if(last!==undefined&&last!==s.round&&s.phase!=='ended'){", "'reprise:changement-de-semaine'"]]],
];

let fait = false;
function instrumenter() {
  if (fait) return; fait = true;
  for (const [nom, points] of POINTS) {
    const fichier = path.join(ENGINE, nom + '.cjs');
    const mod = require(fichier);
    // Copie Windows (core.autocrlf) : le source est en CRLF ; les points de sonde sont écrits en LF.
    let src = mod.factory.toString().replace(/\r\n/g, '\n');
    for (const [texte, cle, avant] of points) {
      const i = src.indexOf(texte);
      if (i < 0) throw Error(`sonde : point introuvable dans ${nom} : ${texte.slice(0, 60)}`);
      src = avant ? src.slice(0, i + texte.indexOf('{') + 1) + S(cle) + src.slice(i + texte.indexOf('{') + 1)
        : src.slice(0, i + texte.length) + S(cle) + src.slice(i + texte.length);
    }
    // eslint-disable-next-line no-eval
    const factory = (0, eval)('(' + src + ')');
    require.cache[require.resolve(fichier)].exports = { ...mod, factory };
  }
}

// Côté machine virtuelle : journal des déclenchements, avec la semaine du monde au moment de l'appel.
const INSTALLER_VM = `globalThis.__sondeLog=[];globalThis.__sonde=k=>{globalThis.__sondeLog.push([k,S?.worldMode?.week??null,S?.worldMode?.day??null]);return true;};`;

module.exports = { instrumenter, INSTALLER_VM, POINTS };
