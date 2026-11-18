'use strict';
// Jugement du staff, sang-froid et confiance du buteur (docs/jugement-staff-20261116.md), carrière Monde
// (world-champ, club 102) : erreur d'estimation fixe par couple (staff, joueur) et décroissante avec le
// niveau, choix du staff imparfaits mais crédibles, sang-froid caché révélé par fourchettes, confiance qui
// suit la surprise et revient vers 0, sauvegarde, rencontres commencées avant gardant leurs règles, mesures
// IA contre IA (CD_JUGEMENT_MESURES=n pour des mesures plus longues).
const test = require('node:test');
const assert = require('node:assert/strict');
const {context} = require('./monde-harness.cjs');

const shared = context(827381, {club: 102}).toMatch(), base = shared.checkpoint();
test.after(() => shared.close());
const setup = () => shared.restore(base);
// 72 affiches par cas (au lieu de 24) depuis #906 : à 24, un simple changement de l'ordre des tirages (style d'attaque de
// l'IA) faisait passer la réussite au but de 0,80 à 0,857, alors que 10 saisons Monde complètes donnent 74,4 % avant comme
// après ; à 72, main 0,795 et #906 0,801 (≈ +12 s).
const N = Math.max(12, Number(process.env.CD_JUGEMENT_MESURES) || 72);

// Choix du staff contre meilleur choix réel, pour chaque club du Monde, XV proposé par l'IA ; niveau du staff
// imposé (null : staff réel du club).
const CHOIX = `var choix=(niveau,key)=>{let total=0,contredits=0,ecart=0;
 for(const c of S.clubs){const xv=buildSheet(c).lineup.map(id=>c.players.find(p=>p.id===id)).filter(Boolean),pool=key==='kick'?xv.filter(p=>p.fam>=4):xv;if(pool.length<2)continue;
  const judges=staffJudges(c.id);if(niveau!==null)for(const k of Object.keys(judges))judges[k]={...judges[k],level:niveau};
  const staff=judgedOrder(c.id,judges,pool,key)[0],reel=[...pool].sort((a,b)=>trueRoleValue(b,key)-trueRoleValue(a,key))[0];
  total++;if(staff.id!==reel.id){contredits++;ecart+=trueRoleValue(reel,key)-trueRoleValue(staff,key)}}
 return {total,contredits,part:contredits/total,ecartMoyen:contredits?ecart/contredits:0}}`;

// Affiches IA contre IA (hors club du manager) à graine fixe, conditions rétablies ; niveau du staff du côté 0
// imposé (null : réel). Rend la réussite au but, la réussite dans les moments décisifs par tiers de
// sang-froid et les points.
const SIMULER = `var simuler=(n,niveau,seedBase=1)=>{const fx=CDWorldCareer.fixtures(S).filter(f=>f.homeId!==S.club&&f.awayId!==S.club),rng=Math.random,saved=JSON.stringify(S.staffJudgement||null);
 const acc={tentatives:0,reussis:0,points:0,encaisses:0,victoires:0,matchs:0,decisifs:{bas:[0,0],milieu:[0,0],haut:[0,0]},signature:[]};
 const tiers=p=>{const v=sangFroid(p);return v<57?'bas':v<=65?'milieu':'haut'};
 try{for(let k=0;k<n;k++){const f=fx[k%fx.length];let x=(k*2654435761+seedBase)>>>0;Math.random=()=>{x=(Math.imul(x,1664525)+1013904223)>>>0;return x/4294967296};
  for(const id of [f.homeId,f.awayId])CDFranceCareer.ensureAISheet(S.clubs[id]);
  const snap=[f.homeId,f.awayId].flatMap(id=>S.clubs[id].players.map(p=>[p,p.condition,p.injury]));
  const l=createRugbyMatch([f.homeId,f.awayId],null,true);if(niveau!==null&&l.staffJudges)for(const k2 of Object.keys(l.staffJudges[0]))l.staffJudges[0][k2]={...l.staffJudges[0][k2],level:niveau};
  const orig=noteGoalKick;noteGoalKick=function(l2,side,ok){const kk=l2.sjLastKick;if(kk&&kk.decisive){const p=S.clubs[l2.pair[side]].players.find(q=>q.id===kk.id);if(p){const t=acc.decisifs[tiers(p)];t[0]++;if(ok)t[1]++}}return orig.apply(this,arguments)};
  try{for(let g=0;!l.finished&&g<600;g++){l.paused=false;advanceRugby(l)}}finally{noteGoalKick=orig}
  for(const [p,c,i] of snap){p.condition=c;p.injury=i}
  const st=l.stats[0];acc.tentatives+=st.goalAttempts+st.conversionAttempts;acc.reussis+=st.goals+st.conversions;acc.points+=l.score[0];acc.encaisses+=l.score[1];acc.victoires+=l.score[0]>l.score[1]?1:0;acc.matchs++;
  acc.signature.push(l.score.join('-')+':'+l.events.length)}}finally{Math.random=rng;S.staffJudgement=JSON.parse(saved)||undefined;if(!S.staffJudgement)delete S.staffJudgement}
 return acc}`;

test('Erreur d’estimation : fixe par couple, décroissante avec le niveau, staff réel des clubs', () => {
  const h = setup();
  const r = JSON.parse(h.run(`JSON.stringify((()=>{const p=club().players[0],j=id=>({id,level:45}),fort=id=>({id,level:85});
   const e1=judgementError(j('a'),p.id,'goal'),e2=judgementError(j('a'),p.id,'goal'),e3=judgementError(j('b'),p.id,'goal');
   let max45=0,max85=0;for(const q of S.clubs.flatMap(c=>c.players).slice(0,800)){max45=Math.max(max45,Math.abs(judgementError(j('x'),q.id,'goal')));max85=Math.max(max85,Math.abs(judgementError(fort('x'),q.id,'goal')))}
   const judges=S.clubs.map(c=>staffJudges(c.id));
   return {e1,e2,e3,max45,max85,a45:judgementAmplitude(45),a85:judgementAmplitude(85),a65:judgementAmplitude(65),
    reels:judges.filter(x=>!String(x.arrieres.id).startsWith('club:')).length,clubs:judges.length}})())`));
  assert.equal(r.e1, r.e2, 'même couple, même erreur');
  assert.notEqual(r.e1, r.e3, 'autre membre du staff, autre erreur');
  assert.ok(r.a45 > r.a65 && r.a65 > r.a85, 'amplitude décroissante avec le niveau');
  assert.ok(r.max45 <= 10 && r.max45 > 7, `staff faible : erreurs jusqu'à ±10 (${r.max45.toFixed(2)})`);
  assert.ok(r.max85 <= 1.5, 'staff excellent : erreurs d’au plus un point et demi');
  assert.equal(r.reels, r.clubs, 'chaque club du Monde juge avec un membre réel de son staff');
});

test('Choix du staff : imparfaits, plus souvent contredits avec un staff faible', () => {
  const h = setup();
  const r = JSON.parse(h.run(`${CHOIX};JSON.stringify({faible:choix(45,'goal'),reel:choix(null,'goal'),fort:choix(85,'goal'),piedFaible:choix(45,'kick'),piedFort:choix(85,'kick')})`));
  console.log('Choix du buteur contredits par le meilleur réel :', JSON.stringify(r));
  assert.ok(r.faible.part > r.fort.part, 'un staff faible se trompe plus souvent');
  assert.ok(r.faible.part >= 0.05 && r.faible.part <= 0.4, `staff faible : erreurs fréquentes mais pas systématiques (${r.faible.part})`);
  assert.ok(r.fort.part <= 0.05, `bon staff : rarement contredit (${r.fort.part})`);
  assert.ok(r.reel.part > r.fort.part && r.reel.part < r.faible.part, 'staff réel entre les deux');
  assert.ok(r.faible.ecartMoyen < 10, `erreurs crédibles : quelques points de « But » (${r.faible.ecartMoyen})`);
  assert.ok(r.piedFaible.part >= r.piedFort.part, 'jeu au pied : même règle');
});

test('Fenêtre « Tireurs et lanceur » : avis du staff, estimation, confiance et sang-froid révélé', () => {
  const h = setup();
  let view = h.command('snapshot').tactics.roles;
  const buteur = view.roles[0];
  assert.ok(view.avis && view.avis.arrieres && view.avis.arrieres.name, 'le membre du staff qui juge est nommé');
  for (const p of buteur.candidates) {
    assert.ok(Number.isInteger(p.estimation) && Math.abs(p.estimation - p.value) <= 10, 'estimation du staff proche de la fiche');
    assert.deepEqual(p.confiance, {value: 0, label: 'Normale'});
    assert.equal(p.sangFroid, null, 'sang-froid caché au départ');
  }
  const best = buteur.candidates.reduce((a, b) => (b.estimation > a.estimation ? b : a));
  assert.ok(buteur.staff.id, 'le staff propose un buteur');
  assert.equal(h.command('snapshot').kicker, buteur.staff.id, 'feuille : buteur du staff');
  // Révélation : 2, 5 puis 10 observations donnent des fourchettes de 11, 9 puis 5 points, vraie valeur dedans.
  const id = best.id, vrai = h.run(`Math.round(sangFroid(club().players.find(p=>p.id===${JSON.stringify(id)})))`);
  for (const [n, largeur] of [[2, 11], [5, 9], [10, 5]]) {
    h.run(`staffJudgementEnsure().vu[${JSON.stringify(id)}]=${n}`);
    const r = h.command('snapshot').tactics.roles.roles[0].candidates.find(p => p.id === id).sangFroid;
    assert.equal(r.max - r.min + 1, largeur, `${n} observations : fourchette de ${largeur}`);
    assert.ok(r.min <= vrai && vrai <= r.max, 'vraie valeur dans la fourchette');
    assert.notEqual((r.min + r.max) / 2, vrai, 'fourchette jamais centrée sur la vraie valeur');
  }
  // Confiance visible, vocabulaire du club.
  h.run(`staffJudgementEnsure().confiance[${JSON.stringify(id)}]=9`);
  view = h.command('snapshot').tactics.roles;
  assert.deepEqual(view.roles[0].candidates.find(p => p.id === id).confiance, {value: 9, label: 'En pleine confiance'});
  h.run('validateCareer(S)');
  assert.equal(h.run('!!parseSaveDocument(JSON.stringify(createSaveDocument()))'), true, 'sauvegarde valide');
});

test('Confiance : suit la surprise, bornée, revient vers la normale ; sauvegarde et anciennes rencontres', () => {
  const h = setup();
  const r = JSON.parse(h.run(`JSON.stringify((()=>{const f=CDWorldCareer.fixtures(S).find(f=>f.homeId!==S.club&&f.awayId!==S.club);
   for(const id of [f.homeId,f.awayId])CDFranceCareer.ensureAISheet(S.clubs[id]);
   const l=createRugbyMatch([f.homeId,f.awayId],null,true),k=goalKicker(l,0),out={version:l.staffJudgementVersion};
   l.minute=20;l.sjLastKick={side:0,id:k.id,decisive:false,p:.8};noteGoalKick(l,0,true);out.reussite=l.sjConfiance[k.id];
   l.sjLastKick={side:0,id:k.id,decisive:false,p:.8};noteGoalKick(l,0,false);out.echec=l.sjConfiance[k.id];
   l.sjLastKick={side:0,id:k.id,decisive:true,p:.5};noteGoalKick(l,0,false);out.echecDecisif=l.sjConfiance[k.id];
   for(let i=0;i<40;i++){l.sjLastKick={side:0,id:k.id,decisive:true,p:.3};noteGoalKick(l,0,true)}out.borne=l.sjConfiance[k.id];
   l.sjLastKick={side:0,id:k.id,decisive:false,p:.8};noteGoalKick(l,1,true);out.autreCote=l.sjConfiance[k.id];
   // Pression : confiance et sang-froid pèsent sur la chance du tir, et seulement le sang-froid en moment décisif.
   l.score=[10,10];l.minute=75;const decisif=decisiveMoment(l,0),calme=(l.minute=30,decisiveMoment(l,0));
   l.minute=75;l.score=[30,10];const large=decisiveMoment(l,0);l.score=[10,13];const conversion=decisiveMoment(l,0,5);
   l.score=[10,10];const froid={id:'froid',hiddenTraitsV2:{bigMatches:80}},tendu={id:'tendu',hiddenTraitsV2:{bigMatches:41}};
   out.pressionDecisive=goalKickPressure(l,0,froid,false)-goalKickPressure(l,0,tendu,false);l.minute=30;out.pressionCalme=goalKickPressure(l,0,froid,false)-goalKickPressure(l,0,tendu,false);l.sjLastKick=null;
   commitStaffJudgement(l);out.stocke=S.staffJudgement.confiance[k.id];
   const l2=createRugbyMatch([f.homeId,f.awayId],null,true);l2.sjLastKick={side:0,id:k.id,decisive:false,p:.8};noteGoalKick(l2,0,true);out.retour=l2.sjConfiance[k.id];
   l2.finished=true;commitStaffJudgement(l2);
   const l3=createRugbyMatch([f.homeId,f.awayId],null,true);l3.finished=true;commitStaffJudgement(l3);out.apresMatchSansTir=S.staffJudgement.confiance[k.id];
   // Ancienne rencontre (créée avant ces règles) : aucune version, ancien calcul du buteur, pas d'effet.
   const old=createRugbyMatch([f.homeId,f.awayId],null,true);delete old.staffJudgementVersion;
   out.ancienButeur=goalKicker(old,0)?.id===chooseScorer(S.clubs[f.homeId],activePlayers(old,0).map(p=>p.id))?.id;out.ancienPression=goalKickPressure(old,0,k,false);
   return {...out,decisif,calme,large,conversion}})())`));
  assert.equal(r.version, 1);
  assert.equal(r.reussite, 1.2, 'réussite attendue à 80 % : +1,2');
  assert.equal(r.echec, -3.6, 'échec attendu à 80 % : −4,8');
  assert.equal(r.echecDecisif, -8.6, 'échec décisif à 50 % : −5');
  assert.equal(r.borne, 20, 'confiance bornée');
  assert.equal(r.autreCote, 20, 'un tir de l’autre équipe ne touche pas ce buteur');
  assert.deepEqual([r.decisif, r.calme, r.large, r.conversion], [true, false, false, true], 'moments décisifs : 70e minute, 7 points d’écart, essai compris');
  assert.ok(Math.abs(r.pressionDecisive - 39 * 0.008) < 1e-9, 'moment décisif : 39 points de sang-froid valent +0,31 avant la courbe de réussite');
  assert.equal(r.pressionCalme, 0, 'hors moment décisif : le sang-froid ne joue pas');
  assert.equal(r.stocke, 20, 'fin de match : confiance gardée');
  assert.equal(r.retour, 16.2, 'match suivant : retour d’un cran (×0,75) avant le premier tir');
  assert.ok(r.apresMatchSansTir < 16.2 && r.apresMatchSansTir > 0, 'match sans tir : retour vers la normale');
  assert.equal(r.ancienButeur, true, 'rencontre commencée avant : ancien choix du buteur');
  assert.equal(r.ancienPression, 0, 'rencontre commencée avant : ni confiance ni sang-froid');
  h.run('validateCareer(S)');
  assert.equal(h.run('!!parseSaveDocument(JSON.stringify(createSaveDocument()))'), true, 'sauvegarde valide');
  h.run('S.staffJudgement.confiance.x=99');
  assert.throws(() => h.run('validateCareer(S)'), /Jugement du staff invalide/);
  h.run('delete S.staffJudgement;validateCareer(S)');
});

test('Mesures IA contre IA : staff faible contre bon staff, sang-froid dans les moments décisifs', () => {
  const h = setup();
  const r = JSON.parse(h.run(`${SIMULER};JSON.stringify({faible:simuler(${N},45),reel:simuler(${N},null),fort:simuler(${N},85),bis:simuler(${N},null)})`, 600000));
  const taux = a => a.reussis / Math.max(1, a.tentatives), dec = t => t[1] / Math.max(1, t[0]);
  const resume = Object.fromEntries(Object.entries(r).filter(([k]) => k !== 'bis').map(([k, a]) => [k, {but: +taux(a).toFixed(3), points: +(a.points / a.matchs).toFixed(1), encaisses: +(a.encaisses / a.matchs).toFixed(1), victoires: a.victoires, decisifs: Object.fromEntries(Object.entries(a.decisifs).map(([t, v]) => [t, `${v[1]}/${v[0]}`]))}]));
  console.log(`Mesures (${N} affiches par cas) :`, JSON.stringify(resume));
  assert.deepEqual(r.reel.signature, r.bis.signature, 'déterministe : mêmes graines, mêmes matchs');
  // Tolérance 0,03 (au lieu de 0,02) depuis #812 : la fatigue réduite sur phases arrêtées décale le tirage
  // aléatoire ; mesuré sur 24 affiches, faible 0,741 contre fort 0,717 (écart 0,024, bruit d'échantillon),
  // alors que sans SET_PIECE_FATIGUE_RULES on obtient faible 0,707 contre fort 0,717.
  assert.ok(taux(r.fort) >= taux(r.faible) - 0.03, 'un bon staff ne choisit pas plus mal qu’un staff faible');
  for (const a of [r.faible, r.reel, r.fort]) {
    assert.ok(taux(a) > 0.6 && taux(a) < 0.85, `réussite au but crédible (${taux(a)})`);
    assert.ok(a.points / a.matchs > 15 && a.points / a.matchs < 40, 'pas de bouleversement des scores');
  }
});
