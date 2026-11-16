'use strict';
// Pénalité jouée vite à la main : vrai choix du moteur (décision, effets, faits, fréquence).
// Conception : docs/match-choregraphe-20261112.md, § 13 (quatrième tranche).
const {test}=require('node:test');
const assert=require('node:assert/strict');
const {context}=require('./harness.cjs');
const T=require('./helpers/tirages.cjs');

// Match en cours, en pause, avec un compteur de tirages.
function fixture(){
 const t=context();
 t.run('start(0);beginMatch();pauseMatch();var l=S.live;var tirages=0;var aleaBase=Math.random;Math.random=function(){tirages++;return aleaBase()};');
 return t;
}
const valid=run=>assert.equal(run('!!createSaveDocument()'),true,'sauvegarde valide');

test('Les nouvelles rencontres connaissent la pénalité jouée à la main ; les anciennes non', () => {
 const {run}=fixture();
 assert.equal(run('l.quickTapVersion'),1);
 assert.equal(run('quickTapRules(l)'),true);
 assert.equal(run('PENALTY_POLICIES.main'),'Jouer vite à la main');
 run('delete l.quickTapVersion;l.penaltyPolicies[0]="main";ballPossession(l,0,92);l.minute=20');
 assert.equal(run('quickTapRules(l)'),false,'match commencé avant : règles d’origine');
 run('executePenaltyChoice(l,0)');
 assert.ok(!run('l.events.some(e=>e.scene?.kind==="quick-tap")'),'aucune pénalité jouée à la main');
 const t=context();t.run('QUICK_TAP_RULES=0;start(0);beginMatch();pauseMatch()');
 assert.equal(t.run('S.live.quickTapVersion'),undefined,'option coupée : la rencontre garde les règles d’avant');
});

test('Décision : consigne du manager, contexte, aucun tirage sans pénalité jouée', () => {
 const {run}=fixture();
 // Consigne « jouer vite à la main » : toujours ; « points » et « pénaltouche » : jamais.
 run('l.minute=20;ballPossession(l,0,60);l.penaltyPolicies=["main","auto"]');
 assert.equal(run('wantsQuickTap(l,0,40)'),true);
 for(const p of ['points','touch']){run(`l.penaltyPolicies[0]="${p}"`);assert.equal(run('wantsQuickTap(l,0,40)'),false,p)}
 // Un carton arrête le jeu.
 run('l.penaltyPolicies[0]="main";addEvent(l,"Carton jaune.","card",{team:1,incident:true,card:"yellow"})');
 assert.equal(run('wantsQuickTap(l,0,40)'),false,'pas de pénalité jouée vite après un carton');
 // Selon le contexte : plus souvent près de la ligne, et encore plus mené en fin de match.
 run('l.penaltyPolicies[0]="auto";l.events.push({min:l.minute,text:"",type:"play"});l.score=[10,10];l.minute=20');
 const loin=run('quickTapWeight(l,0,60)'),pres=run('quickTapWeight(l,0,5)');
 assert.ok(pres>loin,`près de la ligne (${pres}) plus que loin (${loin})`);
 run('l.minute=72;l.score=[10,20]');const mene=run('quickTapWeight(l,0,5)');
 run('l.score=[20,10]');const devant=run('quickTapWeight(l,0,5)');
 assert.ok(mene>pres&&devant<pres,`mené en fin de match (${mene}) > début (${pres}) > devant en fin de match (${devant})`);
 // Consigne tactique : le jeu au large joue plus vite que le jeu au près.
 run('l.score=[10,10];l.minute=20;l.tactics[0]="large";if(l.playbooks)for(const z of Object.values(l.playbooks[0].zones))z.attack="inherit"');const large=run('quickTapWeight(l,0,40)');
 run('l.tactics[0]="conquete"');const pres2=run('quickTapWeight(l,0,40)');
 assert.ok(large>pres2,`large (${large}) > au près (${pres2})`);
 // La décision elle-même ne consomme aucun tirage.
 run('tirages=0;for(let d=1;d<99;d++)wantsQuickTap(l,0,d)');
 assert.equal(run('tirages'),0);
});

test('Effets : essai, gain, percée, ballon perdu, avec les faits du moteur (tirage balayé, aucun seuil codé en dur)',()=>{
 // La décision est un tirage comparé à des probabilités que le moteur recale (essai, perte, percée : ~.1 à ~.5). Au lieu de choisir
 // un tirage qui tombe entre deux seuils (l'ancien [0.55, 0.5] tombait mal dès qu'un seuil bougeait de 0,05), on balaie le premier tirage de 0 à 1 sur la
 // même situation : l'ordre des issues (essai ou percée, puis ballon perdu, puis gain) est la règle, leurs bornes ne sont pas testées.
 const classe=faits=>{const f=faits[1];if(!f)return 'rien';if(f.kind==='try')return 'essai';if(f.kind==='turnover')return f.team===1?'gratte':'?';if(f.kind==='ingoal'&&f.cause==='held-up')return 'tenu';if(f.kind==='hand-fault'&&f.cause==='knock-on')return 'en-avant';if(f.kind==='carry')return f.to.x-f.from.x>=22?'percee':'gain';return '?'};
 const situation=(at)=>{const {run}=fixture();run(`l.minute=30;l.flow.advantage=null;ballPossession(l,0,${at});l.penaltyPolicies[0]="main"`);return {run,photo:T.photographier(run)}};
 const jouer=(sit,rolls,policy)=>{const {run,photo}=sit;T.rejouer(run,photo);if(policy)run(`l.penaltyPolicies[0]="${policy}"`);run('var debut=l.events.length');T.injecter(run,rolls);run('executePenaltyChoice(l,0)');
  const faits=JSON.parse(run('JSON.stringify(l.events.slice(debut).map(e=>e.scene&&{kind:e.scene.kind,team:e.scene.team,actor:e.scene.actor,from:e.scene.from,to:e.scene.to,cause:e.scene.cause}).filter(Boolean))'));valid(run);return faits};
 const suite=liste=>liste.filter((c,i)=>i===0||c!==liste[i-1]);
 for(const [at,attendu] of [[94,['essai','perte','gain']],[45,['percee','perte','gain']]]){
  const sit=situation(at),tirages=T.balayage(80),classes=tirages.map(r=>classe(jouer(sit,[r])));
  const ordre=suite(classes.map(c=>['gratte','tenu','en-avant'].includes(c)?'perte':c));
  assert.deepEqual(ordre,attendu,`tirage de 0 à 1 à ${at} m : issues dans l'ordre ${attendu.join(' → ')} (lu : ${classes.join(' ')})`);
  // Tout tirage donne des faits cohérents : le demi de mêlée joue la pénalité, au point de la faute, d'abord.
  for(const r of [0.02,0.5,0.98]){const f=jouer(sit,[r]);assert.equal(f[0].kind,'quick-tap');assert.equal(f[0].team,0);assert.equal(f[0].from.x,at,'au point de la faute')}
  const perdu=tirages.filter((r,i)=>['gratte','tenu','en-avant'].includes(classes[i]));
  // Ballon perdu : le deuxième tirage départage tenu dans l'en-but, gratté, en-avant (près de la ligne) ou gratté / en-avant (au milieu).
  const milieu=perdu[Math.floor(perdu.length/2)],sous=suite(T.balayage(60).map(r=>classe(jouer(sit,[milieu,r]))));
  assert.deepEqual(sous,at===94?['tenu','gratte','en-avant']:['gratte','en-avant'],`deuxième tirage à ${at} m : ${sous.join(', ')}`);
  const g=jouer(sit,[T.HAUT]);assert.equal(g[1].kind,'carry');assert.equal(classe(g),'gain');assert.equal(sit.run('l.possession'),0,'le ballon est conservé');
  if(at===94){assert.ok(g[1].to.x>94&&g[1].to.x<100,'gain sans franchir la ligne');const e=jouer(sit,[T.BAS]);assert.equal(e[1].kind,'try');assert.equal(sit.run('l.quickTaps[0]'),1);
   const t=jouer(sit,[milieu,0.05]);assert.equal(t[1].cause,'held-up');const n=jouer(sit,[milieu,T.HAUT]);assert.equal(n[1].cause,'knock-on')}
  else{const p=jouer(sit,[T.BAS]);assert.ok(p[1].to.x-p[1].from.x>=22,'percée');const o=jouer(sit,[T.HAUT]);const gain=o[1].to.x-o[1].from.x;assert.ok(gain>=5&&gain<=14,'gain ordinaire '+gain);assert.equal(jouer(sit,[milieu,T.BAS])[1].kind,'turnover')}
 }
 // Pénaltouche choisie : aucun fait de pénalité jouée à la main.
 const touche=situation(45);assert.ok(!jouer(touche,[T.HAUT],'touch').some(f=>f.kind==='quick-tap'));
});

// Statistiques sur un grand nombre de matchs IA contre IA, avec et sans l'option.
function bilan(sans,n){
 const t=context();t.run('start(0)');if(sans)t.run('QUICK_TAP_RULES=0');
 return JSON.parse(t.run(`(function(){const a={m:0,pen:0,taps:0,tapsTotal:0,penPres:0,tapsPres:0,penMene:0,tapsMene:0,essais:0,points:0,buts:0,issues:{}};
  const base=executePenaltyChoice;
  executePenaltyChoice=function(l,side){const d=side===0?100-l.territory:l.territory,mene=l.score[side]<l.score[1-side],avant=l.quickTaps?.[side]||0;a.pen++;if(d<=12){a.penPres++;if(mene)a.penMene++}const r=base(l,side);if((l.quickTaps?.[side]||0)>avant){a.taps++;if(d<=12){a.tapsPres++;if(mene)a.tapsMene++}}return r};
  try{for(let i=0;i<${n};i++){const C=S.clubs.length,x=i%C,y=(i*5+3+Math.floor(i/C))%C;if(x===y)continue;const l=createRugbyMatch([x,y],null,true);l.quickTapLog=[];
   while(!l.finished){l.paused=false;advanceRugby(l)}a.m++;a.essais+=l.tries[0]+l.tries[1];a.points+=l.score[0]+l.score[1];a.buts+=l.stats[0].goals+l.stats[1].goals;a.tapsTotal+=(l.quickTaps?.[0]||0)+(l.quickTaps?.[1]||0);for(const q of l.quickTapLog)a.issues[q.issue]=(a.issues[q.issue]||0)+1}}
  finally{executePenaltyChoice=base}return JSON.stringify(a)})()`));
}
test('Fréquence réaliste et équilibre du jeu sur 1 500 matchs', () => {
 const avec=bilan(false,1500),sans=bilan(true,1500);
 const part=avec.taps/avec.pen,partPres=avec.tapsPres/avec.penPres,partMene=avec.tapsMene/Math.max(1,avec.penMene);
 console.log(JSON.stringify({matchs:avec.m,penalitesParMatch:+(avec.pen/avec.m).toFixed(2),jouéesALaMainParMatch:+(avec.taps/avec.m).toFixed(2),part:+(100*part).toFixed(1),partPresDeLaLigne:+(100*partPres).toFixed(1),partMenePresDeLaLigne:+(100*partMene).toFixed(1),issues:avec.issues,
  essais:[+(avec.essais/avec.m).toFixed(2),+(sans.essais/sans.m).toFixed(2)],points:[+(avec.points/avec.m).toFixed(2),+(sans.points/sans.m).toFixed(2)]}));
 assert.equal(sans.taps,0,'option coupée : aucune');
 // Minorité des pénalités (intention de conception : une exception qui surprend, jamais la règle), puis deux classements mesurés par un test de différence
 // de proportions (4 écarts types) et non par un facteur arbitraire (« ×1,8 ») ni par un classement de deux taux voisins.
 assert.ok(part>=0.01&&part<=0.15,'minorité des pénalités : '+part);
 T.plusGrand('plus fréquente près de la ligne',T.zProportions(avec.tapsPres,avec.penPres,avec.taps-avec.tapsPres,avec.pen-avec.penPres));
 T.plusGrand('plus fréquente près de la ligne quand on est mené',T.zProportions(avec.tapsMene,avec.penMene,avec.tapsPres-avec.tapsMene,avec.penPres-avec.penMene));
 // Issues : surtout du jeu conservé, parfois l'essai ou la percée, parfois le ballon perdu.
 const total=Object.values(avec.issues).reduce((s,n)=>s+n,0),perdu=(avec.issues.gratte||0)+(avec.issues['en-avant']||0)+(avec.issues.tenu||0);
 // Total des pénalités jouées lu sur le match : une pénalité de mêlée peut suivre une pénalité jouée (en-avant, mêlée) dans le même temps de jeu.
 assert.ok(total===avec.tapsTotal&&perdu/total>0.1&&perdu/total<0.35,'ballon perdu : '+perdu+'/'+total);
 assert.ok((avec.issues.essai||0)>0&&(avec.issues.percee||0)>0,'essais et percées');
 // Équilibre : essais et points par match à moins de 8 % de l'existant.
 for(const k of ['essais','points'])assert.ok(Math.abs(avec[k]/avec.m-sans[k]/sans.m)/(sans[k]/sans.m)<0.08,k);
});

test('Temps forts : la pénalité jouée à la main est montrée avec son coup de sifflet et sa suite', () => {
 const H=require('../native/engine/match-highlights.cjs');
 const sc=(kind,x,extra={})=>({kind,team:0,possession:0,from:{x,y:30},to:{x,y:30},score:[0,0],tries:[0,0],...extra});
 const events=[
  {min:20,type:'play',scene:sc('carry',60,{to:{x:86,y:30}})},
  {min:21,type:'penalty',scene:sc('penalty',92,{cause:'offside'})},
  {min:21,type:'play',scene:sc('quick-tap',92)},
  {min:21,type:'try',scene:sc('try',92,{to:{x:100,y:30},score:[7,0],tries:[1,0],origin:'open',conversion:true})},
  {min:22,type:'restart',scene:{...sc('kickoff',50),team:1,score:[7,0],tries:[1,0]}}];
 for(const niveau of ['cles','dynamique']){
  const tf=H.en_direct(events,{niveau}).tempsForts.find(t=>t.plans.some(p=>p.kind==='quick-tap'));
  assert.ok(tf,niveau+' : temps fort de la pénalité jouée');
  assert.deepEqual(tf.plans.map(p=>p.kind).filter(k=>k!=='transformation').slice(-3),['penalty','quick-tap','try'],niveau+' : coup de sifflet, pénalité jouée, essai');
 }
 // Seule (sans essai), dans les 22 adverses, elle reste assez intéressante pour le niveau étendu
 // (au milieu du terrain, c'est le moteur qui juge : depuis la sélection de main du 13/11, elle n'y suffit plus seule).
 const seule=[{...events[0],scene:sc('carry',60,{to:{x:75,y:30}})},{...events[1],scene:sc('penalty',80)},{...events[2],scene:sc('quick-tap',80)},{min:21,type:'play',scene:sc('carry',80,{to:{x:92,y:30}})}];
 assert.ok(H.en_direct(seule,{niveau:'etendus'}).tempsForts.some(t=>t.plans.some(p=>p.kind==='quick-tap')),'étendus : montrée');
});
