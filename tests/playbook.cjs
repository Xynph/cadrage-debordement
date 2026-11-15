const assert=require('node:assert/strict'),{engineContext:context,matchContext}=require('./harness.cjs'),T=require('./helpers/tirages.cjs');
const t=matchContext(),run=t.run;run('playbookZone="sortie";setPlaybookChoice("attack","occupation");beginMatch();pauseMatch();var l=S.live');
for(const [side,at,zone] of [[0,22,'sortie'],[0,23,'construction'],[0,50,'pression'],[0,78,'marque'],[1,78,'sortie'],[1,77,'construction'],[1,50,'pression'],[1,22,'marque']])assert.equal(run(`fieldZone(${side},${at})`),zone);
assert.equal(run('effectiveAttack(l,0,10)'),'occupation');assert.equal(run('effectiveAttack(l,0,60)'),run('l.tactics[0]'));
run('l.paused=false;setPlaybookChoice("scrum","pousser")');assert.equal(run('l.playbooks[0].scrum'),'equilibre');run('pauseMatch();setPlaybookChoice("scrum","pousser")');assert.equal(run('l.playbooks[0].scrum'),'pousser');assert.ok(run('!!createSaveDocument()'));{const restored=context(run('JSON.parse(JSON.stringify(S))'));assert.equal(restored.run('S.live.playbooks[0].scrum'),'pousser');restored.close();}
run('ballPossession(l,0,10);addEvent(l,"Témoin","play",{kind:"carry",team:0});var idx=l.events.length-1;l.playbooks[0].zones.sortie.attack="large";addEvent(l,"Après","tactic");playback(l).cursor=idx');assert.equal(run('matchViewState(l).tactics[0]'),'occupation');
// The active zone changes actual kicking decisions, not only the UI label.
// Règle lue sur le moteur (probabilité de coup de pied dégagé, aucun tirage) puis retrouvée dans la fréquence observée sur 3 000
// phases de jeu : plus de tirage .2 « sous le seuil d'un taux », qui cessait de dégager dès que ce taux était recalé.
function carryFixture(attack){const t=matchContext();t.run(`var l=createRugbyMatch(nextMatch(),null,true);l.tactics=['equilibre','equilibre'];l.playbooks[0].zones.construction.attack='${attack}';delete l.penalitesVersion;ballPossession(l,0,40)`);return t}
{const occ=carryFixture('occupation'),inh=carryFixture('inherit');
 assert.ok(occ.run('openKickProbability(l,0)')>inh.run('openKickProbability(l,0)'),'la zone occupation augmente la probabilité de dégager');
 const kicks=t=>{t.run('var __ph=JSON.stringify(l),__k=0;for(let i=0;i<3000;i++){var __s=(i*2654435761+7)>>>0;Math.random=()=>{__s=(Math.imul(__s,1664525)+1013904223)>>>0;return __s/4294967296};l=JSON.parse(__ph);l.possession=0;l.territory=40;advanceCausalPlay(l);if(l.tacticalStats[0].kicks>0)__k++}');const count=t.run('__k');t.close();return count};
 T.plusGrand('occupation : plus de coups de pied que le plan hérité',T.zProportions(kicks(occ),3000,kicks(inh),3000))}
// Les pénalités de mêlée et de touche (penalitesVersion) sont coupées : l'issue de la conquête elle-même est ce qu'on observe.
// Règle : « sécuriser » / « courte » conservent plus souvent, « pousser » / « fond » gagnent plus de terrain quand ils réussissent.
// Les effets sont ceux du moteur (setPieceEffects, sans tirage) ; la conquête est ensuite rejouée sur un échantillon seedé.
function piece(kind,move,side=0,n=3000){const t=matchContext();t.run(`var l=createRugbyMatch(nextMatch(),null,false);delete l.penalitesVersion;S.clubs.forEach(c=>c.players.forEach(p=>{p.condition=100;Object.keys(ATTR).forEach(k=>p.skills[k]=75)}));l.playbooks[${side}].${kind}='${move}'`);
 const effets=t.run(`setPieceEffects(l,${side},'${kind}')`);
 t.run(`var __ph=JSON.stringify(l),__w=0,__g=0;for(let i=0;i<${n};i++){var __s=(i*2654435761+${kind==='scrum'?3:5})>>>0;Math.random=()=>{__s=(Math.imul(__s,1664525)+1013904223)>>>0;return __s/4294967296};l=JSON.parse(__ph);l.territory=50;l.possession=${side};grantSetPiece(l,'${kind}',${side},50,'${kind==='scrum'?'knock-on':'indirect-touch'}',${1-side});if(l.stats[${side}].${kind==='scrum'?'scrumsWon':'lineoutsWon'}>0){__w++;__g+=Math.abs(l.territory-50)}}`);
 const result={effets,gagnees:t.run('__w'),n,terrain:t.run('__g')/Math.max(1,t.run('__w'))};t.close();return result}
for(const [kind,sur,risque] of [['scrum','securiser','pousser'],['lineout','courte','fond']]){const a=piece(kind,sur),b=piece(kind,risque);
 assert.ok(a.effets.win>b.effets.win&&b.effets.gain>a.effets.gain,`${kind} : le choix sûr conserve plus, le choix risqué avance plus (effets du moteur)`);
 T.plusGrand(`${kind} : ${sur} conserve plus souvent que ${risque}`,T.zProportions(a.gagnees,a.n,b.gagnees,b.n));
 assert.ok(b.terrain>a.terrain,`${kind} : ${risque} gagne plus de terrain quand il conserve (${b.terrain.toFixed(1)} > ${a.terrain.toFixed(1)})`)}
// Renvois : distance dans la fenêtre annoncée quel que soit le tirage ; le renvoi court reprend plus souvent le ballon que le long.
function renvoi(side,move,tirage){const t=matchContext();t.run(`var l=createRugbyMatch(nextMatch(),null,false);S.clubs.forEach(c=>c.players.forEach(p=>{p.condition=100;Object.keys(ATTR).forEach(k=>p.skills[k]=75)}));l.playbooks[${side}].kickoff='${move}'`);T.constant(t.run,tirage);t.run(`performKickRestart(l,'kickoff',${side},'score',${1-side})`);const result={distance:Math.abs(t.run('l.territory')-50),possession:t.run('l.possession')};t.close();return result}
for(const side of [0,1]){
 // BAS / HAUT : les deux bouts de la fenêtre de distance, et la reprise du ballon forcée dans un sens puis dans l'autre.
 for(const tirage of [T.BAS,T.HAUT]){const short=renvoi(side,'court',tirage),long=renvoi(side,'long',tirage);assert.ok(short.distance>=10&&short.distance<=14,'renvoi court : '+short.distance);assert.ok(long.distance>=25&&long.distance<=35,'renvoi long : '+long.distance)}
 assert.equal(renvoi(side,'court',T.BAS).possession,side,'tirage favorable : le camp du coup de pied reprend le ballon');assert.equal(renvoi(side,'long',T.HAUT).possession,1-side,'tirage défavorable : l’adversaire le garde');
 const reprises=(move)=>{const t=matchContext();t.run(`var l=createRugbyMatch(nextMatch(),null,false);S.clubs.forEach(c=>c.players.forEach(p=>{p.condition=100;Object.keys(ATTR).forEach(k=>p.skills[k]=75)}));l.playbooks[${side}].kickoff='${move}';var __ph=JSON.stringify(l),__r=0;for(let i=0;i<1500;i++){var __s=(i*2654435761+9)>>>0;Math.random=()=>{__s=(Math.imul(__s,1664525)+1013904223)>>>0;return __s/4294967296};l=JSON.parse(__ph);performKickRestart(l,'kickoff',${side},'score',${1-side});if(l.possession===${side})__r++}`);const result=t.run('__r');t.close();return result};
 T.plusGrand('renvoi court : plus de ballons repris que le long',T.zProportions(reprises('court'),1500,reprises('long'),1500))}
// Even a push instruction cannot alter an uncontested scrum.
const u=matchContext();u.run('beginMatch();pauseMatch();var l=S.live,side=l.userSide,sh=l.sheets[side];l.playbooks[side].scrum="pousser";l.minute=10;giveMatchCard(l,side,sh.on[0]);prepareFrontRows(l);l.minute=12;giveMatchCard(l,side,sh.on[0]);prepareFrontRows(l);l.territory=90;var before=l.score.join();grantSetPiece(l,"scrum",side,90,"knock-on",1-side)');assert.equal(u.run('sh.front.uncontested'),true);assert.equal(u.run('l.territory'),90);assert.equal(u.run('l.score.join()'),u.run('before'));
for(const change of ['bad.live.playbooks[0].scrum="invalid"','bad.live.playbookVersion=5','bad.manager.playbook.zones.marque.defence="unknown"']){run('var bad=JSON.parse(JSON.stringify(S))');assert.throws(()=>run(change+';validateCareer(bad)'))}
run('syncMatchPresentation(l);delete l.playbookVersion;delete l.playbooks');assert.equal(run('effectiveAttack(l,0,10)'),run('l.tactics[0]'));assert.ok(run('!!createSaveDocument()'));
t.close();u.close();
console.log(JSON.stringify({passed:true,checks:['zone boundaries both directions','inheritance and paused editing','persistence','frozen scene plans','actual zone-dependent kicking','scrum possession/gain tradeoffs','lineout possession/gain tradeoffs','short/long restart distance and retention both directions','older fixture preserved']}));
