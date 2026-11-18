'use strict';
// Aléa des championnats dominés (18/11/2026, docs/top14-dispute-20261117.md §14), carrière Monde :
// styles d'attaque rééquilibrés, complaisance du favori (jour sans, causerie, Gabi), rotation autour de la Coupe d'Europe.
// Vérifications déterministes, sans mesure statistique (les mesures sont dans la doc).
const assert = require('node:assert/strict');
const { test } = require('node:test');
const { context } = require('./monde-harness.cjs');

test('Aléa des favoris : styles, complaisance, causerie, rotation européenne', { timeout: 600000 }, () => {
  const h = context(4242, { club: 102, console: false });
  try {
    // Styles : occupation au pied long et disputé, fautes de main du large réduites.
    const effets = JSON.parse(h.run('JSON.stringify(ATTACK_EFFECTS)'));
    assert.equal(effets.large.error, 0.03);
    assert.equal(effets.conquete.error, -0.035);
    assert.deepEqual([effets.occupation.kickBonus, effets.occupation.kickMax, effets.occupation.recup], [12, 55, 0.25]);

    // Complaisance : rien sous le seuil, probabilité croissante au-delà, plafonnée, modulée par le professionnalisme.
    assert.equal(h.run('Object.isFrozen(RELACHEMENT)&&RELACHEMENT.seuil'), 3);
    const risque = (ecart, pro) => h.run(`(()=>{const R=RELACHEMENT;return Math.min(R.max,R.parPoint*(${ecart}-R.seuil))*clamp(1.4-${pro}/100,.4,1.4)})()`);
    assert.ok(risque(3, 60) <= 0 && risque(2, 60) < 0, 'aucun jour sans sous le seuil');
    assert.ok(risque(6, 60) > risque(4, 60), 'plus probable quand l’écart grandit');
    assert.ok(risque(6, 85) < risque(6, 40), 'un effectif professionnel se relâche moins');
    assert.ok(risque(20, 0) <= 0.35 * 1.4 + 1e-9, 'plafond');

    // Match réel : tirage déterministe (même rencontre, même résultat), aucun tirage aléatoire consommé.
    const essai = h.run(`(()=>{const pair=[0,13],date=(S.worldMode.fixtures.find(f=>f.week===S.round)||S.worldMode.fixtures[0]).date;
      const f={id:'test-relachement',week:S.round,date,homeId:pair[0],awayId:pair[1],competitionId:'elite',phase:'league',round:1};S.worldMode.fixtures.push(f);
      try{const m1=createRugbyMatch(pair,null,true),m2=createRugbyMatch(pair,null,true);
        return JSON.stringify({v:m1.relachementVersion,r1:m1.relachement,r2:m2.relachement,risque:m1.relachementRisque||null});
      }finally{S.worldMode.fixtures.splice(S.worldMode.fixtures.indexOf(f),1)}})()`);
    const r = JSON.parse(essai);
    assert.equal(r.v, 1);
    assert.deepEqual(r.r1, r.r2, 'même rencontre, même tirage');
    assert.ok(r.risque && r.risque.favori === 0 && r.risque.probabilite > 0, 'Toulouse favori de Vannes : jour sans possible');

    // Causerie exigeante : le jour sans est annulé pour le camp du manager.
    assert.ok(h.run("RELACHEMENT.intentions.includes('respect_opposition')&&!RELACHEMENT.intentions.includes('release_pressure')"));
    const annule = h.run(`(()=>{const l={relachementVersion:1,relachement:[0.01,0],relachementAnnule:[true,false]};return relachementEdge(l,0)===0&&relachementEdge({...l,relachementAnnule:null},0)===-0.01})()`);
    assert.equal(annule, true);

    // Rotation européenne : un club qui joue en Champions Cup la semaine d'après ménage ses titulaires en championnat.
    const europe = JSON.parse(h.run(`(()=>{const W=S.worldMode,eu=W.fixtures.find(f=>f.competitionId==='champions');
      const ci=eu.homeId,lg=W.fixtures.find(f=>f.competitionId!=='champions'&&f.competitionId!=='challenge'&&(f.homeId===ci||f.awayId===ci)&&Math.abs(f.week-eu.week)<=1);
      const loin=W.fixtures.find(f=>!ROTATION_EUROPE.competitions.includes(f.competitionId)&&(f.homeId===ci||f.awayId===ci)&&!W.fixtures.some(x=>ROTATION_EUROPE.competitions.includes(x.competitionId)&&(x.homeId===ci||x.awayId===ci)&&Math.abs(x.week-f.week)<=1));
      const at=(f)=>{const r=S.round;S.round=f.week;try{return semaineEuropeenne({pair:[f.homeId,f.awayId]},ci)}finally{S.round=r}};
      return JSON.stringify({proche:lg?at(lg):null,loin:loin?at(loin):null,europe:at(eu)});})()`));
    assert.equal(europe.proche, true, 'semaine voisine d’un match européen');
    assert.equal(europe.loin, false, 'semaine sans Europe');
    assert.equal(europe.europe, false, 'pas de rotation pour le match européen lui-même');
  } finally {
    h.close();
  }
});

// Résultat rapide (championnats suivis de loin, native/engine/league-detail.cjs) : mêmes règles que le moteur complet.
test('Résultat rapide : complaisance du favori et rotation européenne', { timeout: 600000 }, () => {
  const h = context(4242, { club: 102, console: false });
  try {
    const cp = h.checkpoint();
    // Complaisance : avec le jour sans forcé, le gros favori (+12) gagne de moins loin qu'avec le jour sans écarté.
    const marge = (force) => {
      h.restore(cp);
      return h.run(`(()=>{const a=0,b=13,date=(S.worldMode.fixtures.find(f=>f.week===S.round)||S.worldMode.fixtures[0]).date;
        S.clubs[a].players.forEach(p=>{p.rating+=12;p.condition=100;p.injury=0});S.clubs[b].players.forEach(p=>{p.condition=100;p.injury=0});
        const prior=relachementTire,rand=Math.random;let x=987654321;Math.random=()=>{x=(Math.imul(x,1664525)+1013904223)>>>0;return x/4294967296};
        relachementTire=()=>${force};let total=0;
        try{for(let i=0;i<300;i++){const r=CDLeagueDetail.simulate(S,{id:'t-rapide-'+i,week:S.round,date,homeId:a,awayId:b,competitionId:'elite',phase:'league',round:1,neutral:true});total+=r.score[0]-r.score[1];S.clubs[a].players.forEach(p=>{p.condition=100;p.injury=0});S.clubs[b].players.forEach(p=>{p.condition=100;p.injury=0})}}
        finally{relachementTire=prior;Math.random=rand}return total/300})()`);
    };
    const sans = marge(false), avec = marge(true);
    assert.ok(avec < sans - 2, `jour sans du favori au résultat rapide : ${avec.toFixed(1)} contre ${sans.toFixed(1)} points d’écart`);

    // Rotation : un titulaire très utilisé (série ≥ 2, 60 min) est ménagé la semaine d'un match européen, pas autrement.
    const joue = (europe) => {
      h.restore(cp);
      return h.run(`(()=>{const a=0,date=(S.worldMode.fixtures.find(f=>f.week===S.round)||S.worldMode.fixtures[0]).date,b=13;
        S.clubs[a].players.forEach(p=>{p.rating=70;p.condition=100;p.injury=0;p.suspension=0;p.managerLoad={minutes:0,streak:0}});S.clubs[b].players.forEach(p=>{p.condition=100;p.injury=0});
        const star=S.clubs[a].players[0];star.rating=71;star.managerLoad={minutes:80,streak:3};
        const prior=europeAutour;europeAutour=()=>${europe};
        try{CDLeagueDetail.simulate(S,{id:'t-rotation',week:S.round,date,homeId:a,awayId:b,competitionId:'elite',phase:'league',round:1,neutral:true})}finally{europeAutour=prior}
        return star.managerLoad.minutes})()`);
    };
    assert.ok(joue(false) > 0, 'sans match européen proche, le meilleur joueur joue');
    assert.equal(joue(true), 0, 'la semaine d’un match européen, le joueur très utilisé est ménagé');
  } finally {
    h.close();
  }
});
