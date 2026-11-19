'use strict';
// Mesure du dilemme du bonus en fin de match (native/engine/match-bonus.cjs), carrière world-champ, Top 14.
//
// Le premier match du club 0 est joué par le moteur jusqu'à la 60e minute (tirages fixés), les deux XV rendus
// identiques (mêmes compétences poste par poste : seule la consigne départage), puis le score est posé sur trois
// situations de manager et chaque consigne est rejouée N fois jusqu'au coup de sifflet final, flux de hasard
// différent à chaque rejeu (le même pour toutes les consignes) :
//   offensif : +3, deux essais d'écart (un essai pour le bonus offensif) ;
//   defensif : −8 (trois points à refaire pour le bonus défensif : une pénalité suffit) ;
//   tenu     : −4 (bonus défensif en poche) ;
//   six      : −6 (un essai transformé gagne, trois points suffisent pour le bonus défensif ; consignes de « defensif »).
// Sortie : victoires, nuls, défaites, bonus offensif et défensif obtenus, points de classement, essais marqués et
// encaissés, ballons perdus (fautes de main) et actions de jeu (chrono des arrêts) sur les vingt dernières minutes.
//
// Usage : node scripts/mesure-bonus-fin-de-match.cjs [N=60] [--minute=60] [--contre=0] [--sans-miroir] [--situations=offensif,tenu]
//         [--essai=securiser:conquete/prudente/points] (variantes de consignes séparées par « ; », pour l'étalonnage)
// `--contre=0` : sans le ballon de contre (dist/tactical-plans.js, CONTRE), pour comparer.
const { ouvrir, jusquAuMatch } = require('../tests/helpers/carriere-monde.cjs');
const { skipMatchTalk } = require('../tests/helpers/scene-match-talks.cjs');
const B = require('../native/engine/match-bonus.cjs');

const args = process.argv.slice(2);
const N = Number(args.find(a => /^\d+$/.test(a)) || 60);
const contre = !args.includes('--contre=0'), miroir = !args.includes('--sans-miroir');
// --minute=72 : situation posée à la 72e au lieu de la 60e (fin de match serrée, docs/chrono-arrets-de-jeu-20261118.md).
const MINUTE = Number((args.find(a => a.startsWith('--minute=')) || '--minute=60').slice(9));
const choisies = (args.find(a => a.startsWith('--situations=')) || '').slice(13).split(',').filter(Boolean);
// Variante de consigne à l'essai : --essai=securiser:conquete/prudente/points
const essai = (args.find(a => a.startsWith('--essai=')) || '').slice(8);
const SITUATIONS = { offensif: { score: [24, 21], essais: [4, 2] }, defensif: { score: [21, 29], essais: [2, 3] }, tenu: { score: [22, 26], essais: [2, 3] }, six: { score: [23, 29], essais: [2, 3], options: 'defensif' } };

function mesurer(options = {}) {
  const n = options.n ?? N, minute = options.minute ?? MINUTE, avecContre = options.contre ?? contre, avecMiroir = options.miroir ?? miroir;
  const situations = options.situations ?? (choisies.length ? choisies : Object.keys(SITUATIONS));
  const jeu = ouvrir({ testVm: true, hebdomadaire: true });
  try {
    let model = jeu.regler(jeu.call('new_career', { mode: 'world-champ', club: 0, detailedLeagues: [] }));
    model = jusquAuMatch(jeu, model);
    if (!model.selection.valid) model = jeu.call('auto_lineup');
    if (!model.selection.valid) model = jeu.call('promote_cover', { confirmed: true });
    skipMatchTalk(jeu.call('begin_match'), jeu.call);
    const vm = jeu.bridge.vm;
    // La 60e minute, jouée par le moteur sans présentation, tirages fixés.
    vm.run(`(()=>{const l=S.live,reel=Math.random;let x=20261118;Math.random=()=>{x=(Math.imul(x,1664525)+1013904223)>>>0;return x/4294967296};
      try{let g=0;while(!l.finished&&matchMinute(l)<${minute}&&g++<400){l.paused=false;if(l.flow?.atBreak)resumeFlowHalf(l);advanceRugby(l);}}finally{Math.random=reel}
      if(${avecMiroir})for(let k=0;k<15;k++){const a=matchPlayer(l,0,l.sheets[0].on[k]),b=matchPlayer(l,1,l.sheets[1].on[k]);if(a&&b){b.skills=JSON.parse(JSON.stringify(a.skills));b.condition=a.condition;}}
      globalThis.__mesureBonus=JSON.stringify(S);})()`);
    const consignes = { base: null, ...B.CONSIGNES };
    for (const e of essai.split(';').filter(Boolean)) { const [id, v] = e.split(':'), [attack, defense, penalty] = v.split('/'); consignes[id] = { attack, defense, penalty }; }
    const resultats = {};
    for (const nom of situations) {
      const sit = SITUATIONS[nom], ids = ['base', ...B.OPTIONS[sit.options || nom]];
      resultats[nom] = {};
      for (const id of ids) {
        resultats[nom][id] = JSON.parse(vm.run(`(()=>{
          const sit=${JSON.stringify(sit)},c=${JSON.stringify(consignes[id])},R=CDWorldCompetitions.rules('elite').bonus,reel=Math.random;
          const t={victoire:0,nul:0,defaite:0,bonusOffensif:0,bonusDefensif:0,points:0,essaisMarques:0,essaisEncaisses:0,ballonsPerdus:0,actions:0};
          for(let k=0;k<${n};k++){
            S=JSON.parse(__mesureBonus);const l=S.live,u=l.userSide;l.paused=false;l.contreVersion=${avecContre ? 1 : 0};
            l.score[u]=sit.score[0];l.score[1-u]=sit.score[1];l.tries[u]=sit.essais[0];l.tries[1-u]=sit.essais[1];
            if(c){l.tactics[u]=c.attack;l.defences[u]=c.defense;l.penaltyPolicies[u]=c.penalty;}
            const e0=l.tries.slice(),h0=l.tacticalStats[u].handErrors,a0=l.chrono?l.chrono.actions:l.minute;
            let x=1234+k*7919;Math.random=()=>{x=(Math.imul(x,1664525)+1013904223)>>>0;return x/4294967296};
            try{let g=0;while(!l.finished&&g++<300){l.paused=false;if(l.flow?.atBreak)resumeFlowHalf(l);advanceRugby(l);}}finally{Math.random=reel}
            const m=l.score[u]-l.score[1-u],bo=CDWorldCompetitions.matchBonus('elite',l.score,l.tries)[u];
            t.victoire+=m>0;t.nul+=m===0;t.defaite+=m<0;t.bonusOffensif+=bo.bo;t.bonusDefensif+=bo.bd;t.points+=(m>0?4:m===0?2:0)+bo.bo+bo.bd;
            t.essaisMarques+=l.tries[u]-e0[u];t.essaisEncaisses+=l.tries[1-u]-e0[1-u];t.ballonsPerdus+=l.tacticalStats[u].handErrors-h0;t.actions+=(l.chrono?l.chrono.actions:l.minute)-a0;
          }
          for(const k in t)t[k]=Math.round(t[k]/${n}*100)/100;return JSON.stringify(t)})()`));
      }
    }
    return resultats;
  } finally { jeu.fermer(); }
}

if (require.main === module) {
  const r = mesurer();
  console.log(`# ${N} fins de match par consigne (${MINUTE}e → fin), Top 14, ${miroir ? 'XV identiques' : 'XV réels'}, ballon de contre ${contre ? 'actif' : 'coupé'}`);
  for (const [sit, lignes] of Object.entries(r)) {
    console.log(`\n## ${sit} (${JSON.stringify(SITUATIONS[sit])})`);
    console.log('consigne   | V    | N    | D    | BO   | BD   | pts  | essais + | essais − | ballons perdus');
    for (const [id, t] of Object.entries(lignes)) console.log([id.padEnd(10), t.victoire, t.nul, t.defaite, t.bonusOffensif, t.bonusDefensif, t.points, t.essaisMarques, t.essaisEncaisses, t.ballonsPerdus].map(v => String(v).padEnd(4)).join(' | '));
  }
}
module.exports = { mesurer, SITUATIONS };
