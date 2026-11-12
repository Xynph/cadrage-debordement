const assert=require('node:assert/strict');const {context}=require('./harness.cjs');
let t=context(),run=t.run;run('start(0);beginMatch();pauseMatch();var l=S.live,sh=l.sheets[l.userSide]');
assert.equal(run('matchScene(l).players.length'),30);assert.ok(run('match2D(l)').includes('role="group"'));assert.ok(run('match2D(l).includes("Terrain entier")'));assert.equal(run('match2D(l).includes("Vue proche")'),false);assert.ok(run('match2D(l).includes("Rythme du match")'));
const before=run('JSON.stringify(S)');for(let i=0;i<10;i++)run('match2D(l);matchScene(l)');assert.equal(run('JSON.stringify(S)'),before);
const a=context(),b=context();a.run('start(0);beginMatch();pauseMatch();for(var i=0;i<5;i++)match2D(S.live)');b.run('start(0);beginMatch();pauseMatch()');assert.equal(a.run('Math.random()'),b.run('Math.random()'));
run('l.minute=10;var excluded=sh.on[0];giveMatchCard(l,l.userSide,excluded)');assert.equal(run('matchScene(l).players.length'),29);assert.equal(run('matchScene(l).players.some(p=>p.id===excluded)'),false);run('prepareFrontRows(l)');assert.equal(run('matchScene(l).players.length'),29);assert.equal(run('matchScene(l).players.some(p=>p.id===sh.front.held[0].id)'),false);
run('l.minute=20;sh.cards=[];resolveFrontExpiries(l,l.userSide)');assert.equal(run('matchScene(l).players.length'),30);
run('match2D(l);l.paused=false;addEvent(l,"Progression", "play",{kind:"carry",team:l.possession,to:{x:60,y:35}})');assert.ok(run('match2D(l).includes("animateTransform")'));run('l.paused=true;addEvent(l,"Pause")');assert.equal(run('match2D(l).includes("animateTransform")'),false);run('l.paused=false;addEvent(l,"Progression", "play",{kind:"carry",team:l.possession,to:{x:65,y:35}});window.matchMedia=()=>({matches:true})');assert.equal(run('match2D(l).includes("animateTransform")'),false);
run('l.paused=true;var state=JSON.stringify(S);setMatchTempo("lent")');assert.equal(run('JSON.stringify(S)'),run('state'));assert.equal(run('matchTempo'),'lent');
run('l.flow.period=2;l.flow.firstEnd=40;l.flow.fullEnd=80;l.minute=50;l.halftime=true;addEvent(l,"Seconde période")');assert.ok(run('match2D(l).includes(CLUBS[0][1]+" ←")'));
for(const stage of ['scrum','lineout','kickoff']){run(`addEvent(l,"Phase", "play",{kind:${JSON.stringify(stage)},team:l.possession})`);assert.equal(run('matchScene(l).players.length'),30)}
assert.equal(run('matchScene(l).players.every(p=>p.x>=0&&p.x<=100&&p.y>=0&&p.y<=70)'),true);
// Formation de renvoi (loi 12), dans les deux sens : botteur au ballon, partenaires derrière lui et alignés sur la largeur,
// receveurs à 10 m au moins, avants devant, arrière au fond ; plus de colonne numérotée.
for(const team of [0,1]){
 const k=run(`(()=>{l.paused=true;const kicker=l.sheets[${team}].on[5];addEvent(l,"Renvoi","restart",{kind:'kickoff',team:${team},actor:kicker,from:{x:50,y:35},to:{x:50,y:35},possession:${team}});const s=matchScene(l);return JSON.stringify({s,kicker})})()`);
 const {s,kicker}=JSON.parse(k),dk=team===0?1:-1,eq=s.players.filter(p=>p.side===team),re=s.players.filter(p=>p.side!==team);
 assert.ok(eq.every(p=>(p.x-50)*dk<0),'partenaires du botteur derrière le ballon');
 const botteur=eq.find(p=>p.id===kicker),dix=eq.find(p=>p.slot===9);
 assert.ok(Math.hypot(botteur.x-50,botteur.y-35)<4,'le botteur nommé par le moteur au ballon');assert.equal(dix.y,40,'le n° 10 prend la place du botteur dans la ligne');
 const ligne=eq.filter(p=>Math.abs(p.x-50)<=2.5);assert.ok(ligne.length>=10&&Math.max(...ligne.map(p=>p.y))-Math.min(...ligne.map(p=>p.y))>=55,'chasseurs alignés sur la largeur');
 assert.ok(re.every(p=>(p.x-50)*dk>=10),'receveurs à 10 m au moins');
 const prof=slot=>(re.find(p=>p.slot===slot).x-50)*dk;
 assert.ok([0,1,2,3,4,5,6,7].every(a=>[10,13,14].every(b=>prof(a)<prof(b))),'avants devant, ailiers et arrière au fond');assert.equal(Math.max(...re.map(p=>(p.x-50)*dk)),prof(14));
 assert.ok(new Set(s.players.map(p=>Math.round(p.y))).size>12,'pas de colonne');
}
console.log(JSON.stringify({passed:true,checks:['kickoff formation','active snapshot roster','excluded and nominated players hidden','specialist substitutions','single whole-pitch view','keyboard-accessible players','model and RNG isolation','action-level animation','pause and reduced motion','tempo controls','second-half direction','set-piece layouts within pitch']}));
