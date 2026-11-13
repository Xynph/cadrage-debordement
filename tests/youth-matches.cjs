'use strict';
// Matchs des centres de formation : vraies compétitions par pays, résultats rapides,
// temps de jeu, plafond de 30, blessures et reprise progressive, progression, purge.
const assert=require('node:assert/strict');
const {test}=require('node:test');
const {worldYouth}=require('./helpers/youth-world-harness.cjs');

const END=`Math.floor(Date.UTC(2027,5,30)/86400000)`;
const json=(h,src)=>JSON.parse(h.run(`JSON.stringify(${src})`));

test('Une saison mondiale : 116 centres, vraies compétitions, ~20 matchs par équipe, plafond respecté',()=>{
 const h=worldYouth();
 h.run(`var youthBefore=Object.fromEntries([S.development.academy,...S.aiRoster.academies.map(a=>a.players)].flat().map(p=>[p.id,[p.dev.appearances,p.dev.minutes]]));`);
 h.run(`CDYouthMatches.process(S,${END})`);
 const st=json(h,'S.youthMatches');
 const size=id=>st.comps[id].m.length;
 // France : formats FFR (42 Crabos Élite, 24 Espoirs Élite, 20 Accession) ; étranger : vraies compétitions.
 assert.equal(size('fr-crabos'),42);assert.equal(size('fr-espoirs'),24);assert.equal(size('fr-espoirs-acc'),20);
 assert.equal(size('eng-nextgen'),10);assert.equal(size('eng-premcup'),10);assert.equal(size('irl-u18'),4);assert.equal(size('wal-u18'),4);
 assert.equal(size('rsa-u21'),5);assert.equal(size('aus-nextgen'),4);assert.equal(size('nz-su20'),6);assert.equal(size('jpn-centres'),20);
 assert.equal(size('amical-c'),116);
 for(const id of ['fr-crabos','fr-espoirs','fr-espoirs-acc','eng-nextgen','eng-premcup','irl-u18','wal-u18','rsa-u21','aus-nextgen'])assert.notEqual(st.comps[id].champ,null,id+' sacré');
 assert.equal(st.comps['fr-crabos'].pools.p.length,7,'7 poules de 6');assert.equal(st.comps['fr-crabos'].pools.u.length,6,'6 poules de 4 en championnat');
 assert.ok(st.history.length>=9&&st.history.every(r=>r[0]===1));
 const teams=json(h,`[{clubId:S.club,players:S.development.academy},...S.aiRoster.academies].flatMap(a=>['C','E'].map(cat=>{const ps=a.players.filter(p=>cat==='C'?p.age<=17:p.age>=18);return {apps:ps.map(p=>p.youthLoad?.[1]||0)};}))`);
 assert.equal(teams.length,232);
 for(const t of teams){const games=t.apps.reduce((a,b)=>a+b,0)/23;assert.ok(games>=12&&games<=28,'≈20 matchs par équipe : '+games.toFixed(1));assert.ok(Math.max(...t.apps)<=30);}
 const apps=teams.flatMap(t=>t.apps).filter(n=>n>0).sort((a,b)=>a-b);
 assert.ok(apps[Math.floor(apps.length*.1)]<=10,'des remplaçants autour de 5-10 matchs');
 assert.ok(apps[Math.floor(apps.length*.5)]>=14&&apps[Math.floor(apps.length*.5)]<=21,'titulaires autour de 15-20 matchs');
 // Progression branchée : apparitions, minutes, suivi du potentiel évolutif.
 assert.ok(h.run(`[S.development.academy,...S.aiRoster.academies.map(a=>a.players)].flat().filter(p=>p.dev.appearances>youthBefore[p.id][0]&&p.dev.minutes>youthBefore[p.id][1]).length`)>5000);
 assert.ok(h.run(`S.potentialEvolution.records.flat().filter(r=>r[0].startsWith('youth-')&&r[7]>=8).length`)>3000,'matchs pris en compte pour le potentiel évolutif');
 assert.ok(h.run(`[S.development.academy,...S.aiRoster.academies.map(a=>a.players)].flat().some(p=>p.injury>0)`),'des blessés');
 assert.ok(st.own.C.length>0&&st.own.C.length<=12&&st.own.E.length<=12,'résultats du club purgés');
 h.run(`nativeSystems.domain('youthMatches').validate(S)`);
 // Déterminisme : même carrière, même saison des jeunes.
 const result=h.run('JSON.stringify(S.youthMatches)');h.close();
 const again=worldYouth();again.run(`CDYouthMatches.process(S,${END})`);
 assert.equal(again.run('JSON.stringify(S.youthMatches)'),result);
 // Projection lisible du club joué (Toulouse) sans écriture.
 const before=again.run('JSON.stringify(S)'),view=json(again,`nativeSystems.domain('youthMatches').project()`);
 assert.equal(again.run('JSON.stringify(S)'),before);
 assert.equal(view.available,true);assert.ok(view.competitions.some(c=>c.name==='Élite Crabos'&&c.tables.length));
 assert.ok(view.results.crabos.length&&view.players.length===json(again,'S.development.academy.length'));
 again.close();
});

test('Plafond de 30 avec les sélections, risque accru, reprise progressive et validation',()=>{
 const h=worldYouth();
 const id=h.run(`S.development.academy.find(p=>p.age>=18).id`);
 for(let i=0;i<30;i++)assert.equal(h.run(`CDYouthMatches.recordSelection(S,${JSON.stringify(id)},80)`),true);
 assert.equal(h.run(`CDYouthMatches.recordSelection(S,${JSON.stringify(id)},80)`),false,'plafond atteint');
 assert.equal(json(h,`CDYouthMatches.matches(S,S.development.academy.find(p=>p.id===${JSON.stringify(id)}))`).available,false);
 // Blessure longue posée à la main : absence, puis trois matchs de retour à 50 minutes au plus.
 const hurt=h.run(`(()=>{const p=S.development.academy.filter(p=>p.age<=17)[0];p.youthLoad=[S.season,0,0,0,0,42,-3,0,0,Math.floor(Date.UTC(2026,7,1)/86400000)];p.injury=6;return p.id;})()`);
 h.run(`CDYouthMatches.process(S,${END})`);
 const p=json(h,`S.development.academy.find(p=>p.id===${JSON.stringify(hurt)})`);
 assert.equal(p.youthLoad[7],0);assert.ok(p.youthLoad[1]>0,'rejoue après sa blessure');
 assert.equal(json(h,`S.development.academy.find(p=>p.id===${JSON.stringify(id)}).youthLoad`)[1],0,'joueur au plafond jamais aligné');
 h.run(`nativeSystems.domain('youthMatches').validate(S)`);
 assert.throws(()=>h.run(`S.development.academy[0].youthLoad=[1,31,0,0,0,0,0,0,0,0];nativeSystems.domain('youthMatches').validate(S)`),/Matchs des jeunes/);
 h.run(`S.development.academy[0].youthLoad=[1,0,0,0,0,0,0,0,0,0]`);
 assert.throws(()=>h.run(`S.youthMatches.comps['fr-crabos'].m.push(9999);nativeSystems.domain('youthMatches').validate(S)`),/Matchs des jeunes/);
});

test('Nouvelle saison : détail purgé, palmarès borné, retour progressif au plus 50 minutes',()=>{
 const h=worldYouth();
 h.run(`CDYouthMatches.process(S,${END})`);
 // Joueur en reprise : chaque match joué en compte au plus 50 minutes.
 h.run(`S.season=2;S.round=0;S.worldMode.week=0;var ramped=S.development.academy.find(p=>p.age<=17);ramped.youthLoad=[2,0,0,0,0,0,3,0,0,Math.floor(Date.UTC(2027,6,1)/86400000)];ramped.injury=0;`);
 h.run(`CDYouthMatches.process(S,Math.floor(Date.UTC(2027,10,30)/86400000))`);
 const st=json(h,'S.youthMatches');
 assert.equal(st.season,2);assert.ok(st.history.some(r=>r[0]===1),'palmarès conservé');
 assert.ok(Object.values(st.comps).every(c=>c.champ===null||st.history.some(r=>r[0]===2)),'compétitions remises à zéro');
 const y=json(h,'ramped.youthLoad');
 assert.ok(y[1]>=1&&y[3]<=50*Math.min(y[1],3)+80*Math.max(0,y[1]-3),'reprise progressive');
 assert.throws(()=>h.run(`S.youthMatches.history=Array(600).fill([1,'fr-crabos',0]);nativeSystems.domain('youthMatches').validate(S)`),/palmarès/);
});

test('Page de suivi du centre branchée (#626) et compteur des sélections jeunes (#636)',()=>{
 const h=worldYouth();
 h.run(`CDYouthMatches.process(S,Math.floor(Date.UTC(2026,11,31)/86400000))`);
 const page=json(h,`nativeSystems.domain('academyFollowUp').project()`);
 assert.equal(page.matchCap.connected,true);
 assert.equal(page.competitions.available,true);
 assert.ok(page.competitions.competitions.some(c=>c.name==='Élite Crabos'&&c.standings.length&&c.results.length));
 const row=page.players.find(p=>p.matchCap&&p.matchCap.count>0);assert.ok(row,'charge affichée');
 const id=JSON.stringify(row.id);
 assert.equal(h.run(`CDYouthCompetitions.appearances(S,${id})`),row.matchCap.count);
 // Compteur des sélections de #636 : pris en compte sans double compte avec recordSelection.
 // Vrai domaine youthNational : trente matchs inscrits dans son état (format documenté), puis validation.
 h.run(`{const yn=nativeSystems.domain('youthNational');if(!S.youthNational)yn.initialize(S);yn.recordAppearances(S,${id},'FRA',Array.from({length:30},(_,i)=>'2026-'+String(9+Math.floor(i/28)).padStart(2,'0')+'-'+String(1+i%28).padStart(2,'0')));yn.validate(S);}`);
 assert.equal(h.run(`nativeSystems.domain('youthNational').matches(S,${id})`),30);
 assert.equal(h.run(`CDYouthCompetitions.appearances(S,${id})`),row.matchCap.count+30);
 assert.equal(json(h,`CDYouthMatches.matches(S,S.development.academy.find(p=>p.id===${id}))`).available,false);
 const alerts=json(h,`nativeSystems.domain('academyFollowUp').alerts(S)`);
 assert.ok(alerts.some(t=>t.includes('plafond de 30')),'alerte du plafond');
 h.run(`delete S.youthNational`);
});
