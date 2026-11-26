'use strict';
// Matchs de Top 14 joués par le vrai moteur pour tests/match-lois-completes.cjs : une carrière Monde (116 clubs,
// graine propre à chaque monde) par groupe de 48 matchs. Créer un monde coûte ~5 s (new_career), soit plus de la moitié
// du travail du test ; les mondes sont indépendants (graine du monde, rien d'hérité du précédent) : chacun est joué
// dans son propre processus node, trois à la fois. Mêmes graines, mêmes rencontres, mêmes journaux que le jeu en série
// (vérifié par empreinte : voir la PR) ; seule la durée change.
// Usage en processus enfant : node lois-completes-monde.cjs <monde> <nombre de matchs> <fichier de sortie JSON>
const COMP = 'elite';
const PAR_MONDE = 48;

// Journal et faits d'un match de la journée `i` du monde `monde` (la rencontre est choisie par (i×7 + monde×13) mod total).
function jouerMonde(monde, n) {
  const { worldYouth } = require('./youth-world-harness.cjs');
  const t = worldYouth({ seed: 61126 + monde * 101, club: monde * 7 });
  const total = Number(t.run(`S.worldMode.fixtures.filter(f=>f.competitionId==='${COMP}'&&f.phase==='league').length`));
  const matchs = [];
  for (let i = 0; i < PAR_MONDE && matchs.length < n; i++) {
    matchs.push(JSON.parse(t.run(`(()=>{const f=S.worldMode.fixtures.filter(f=>f.competitionId==='${COMP}'&&f.phase==='league')[(${i}*7+${monde}*13)%${total}];
        S.round=f.week;const pair=[f.homeId,f.awayId];for(const id of pair)CDFranceCareer.ensureAISheet(S.clubs[id]);S.club=pair[0];
        const l=createRugbyMatch(pair,null,false);for(let n=0;!l.finished;n++){if(n>4000)throw Error('boucle');l.paused=false;advanceRugby(l)}
        return JSON.stringify({abbr:pair.map(id=>S.clubs[id].abbr),score:l.score,tries:l.tries,yellows:l.stats[0].yellows+l.stats[1].yellows,
          transfos:l.stats.map(s=>({c:s.conversions,a:s.conversionAttempts,pt:s.penaltyTries||0,panneau:statsPanel(l).includes((s.conversions-(s.penaltyTries||0))+' / '+(s.conversionAttempts-(s.penaltyTries||0)))})),
          tirs:l.stats.map(s=>({g:s.goals,a:s.goalAttempts,d:s.drops||0,da:s.dropAttempts||0})),
          panneauTirs:statsPanel(l).includes('<strong>'+(l.stats[0].goals-(l.stats[0].drops||0))+' / '+(l.stats[0].goalAttempts-(l.stats[0].dropAttempts||0))+'</strong><span>Tirs de pénalité</span><strong>'+(l.stats[1].goals-(l.stats[1].drops||0))+' / '+(l.stats[1].goalAttempts-(l.stats[1].dropAttempts||0))+'</strong>'),
          journal:l.events.map(e=>e.scene?{min:e.min,type:e.type,text:e.text,period:e.period,scene:{kind:e.scene.kind,team:e.scene.team,possession:e.scene.possession,period:e.scene.period,actor:e.scene.actor,cause:e.scene.cause,loi:e.scene.loi,move:e.scene.move,incident:e.scene.incident,origin:e.scene.origin,conversion:e.scene.conversion,from:e.scene.from,to:e.scene.to,score:e.scene.score,tries:e.scene.tries}}:{min:e.min,type:e.type,text:e.text,period:e.period}),
          events:l.events.map(e=>({min:e.min,type:e.type,text:e.text,s:e.scene?{kind:e.scene.kind,team:e.scene.team,cause:e.scene.cause,loi:e.scene.loi,score:e.scene.score}:{}}))});})()`)));
  }
  return matchs;
}

// Les n premiers matchs, dans l'ordre des mondes : `largeur` processus enfants à la fois, chacun joue un monde entier.
async function jouer(n, largeur = 3) {
  const fs = require('node:fs'), os = require('node:os'), path = require('node:path'), { spawn } = require('node:child_process');
  const dossier = fs.mkdtempSync(path.join(os.tmpdir(), 'cd-lois-completes-'));
  const mondes = Array.from({ length: Math.ceil(n / PAR_MONDE) }, (_, monde) => ({ monde, n: Math.min(PAR_MONDE, n - monde * PAR_MONDE), sortie: path.join(dossier, `monde-${monde}.json`) }));
  const enfants = new Set();
  const arreter = () => { for (const e of enfants) e.kill(); };
  process.on('exit', arreter);
  try {
    let suivant = 0;
    const ouvrier = async () => {
      while (suivant < mondes.length) {
        const m = mondes[suivant++];
        await new Promise((resolve, reject) => {
          const e = spawn(process.execPath, [__filename, String(m.monde), String(m.n), m.sortie], { stdio: ['ignore', 'inherit', 'inherit'] });
          enfants.add(e);
          e.on('error', reject);
          e.on('exit', (code, signal) => { enfants.delete(e); code === 0 ? resolve() : reject(Error(`monde ${m.monde} : code ${code} ${signal || ''}`)); });
        });
      }
    };
    await Promise.all(Array.from({ length: Math.min(largeur, mondes.length) }, ouvrier));
    return mondes.flatMap(m => JSON.parse(fs.readFileSync(m.sortie, 'utf8')));
  } finally {
    process.removeListener('exit', arreter);
    arreter();
    fs.rmSync(dossier, { recursive: true, force: true });
  }
}

if (require.main === module) {
  const [monde, n, sortie] = process.argv.slice(2);
  require('node:fs').writeFileSync(sortie, JSON.stringify(jouerMonde(Number(monde), Number(n))));
}
module.exports = { jouer, jouerMonde, PAR_MONDE };
