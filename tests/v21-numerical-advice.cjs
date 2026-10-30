const assert=require('node:assert/strict');
const {context}=require('./harness.cjs');

function fixture(){
 const t=context(),run=t.run;
 run('start(0);beginMatch();pauseMatch();var l=S.live;l.minute=10;l.weather="Sec";l.score=[0,0];l.tactics[0]="equilibre";l.defences[0]="equilibre";syncMatchPresentation(l)');
 return {t,run};
}
function card(run,side=0,kind='yellow'){
 run(`giveMatchCard(l,${side},activePlayers(l,${side})[4].id,${JSON.stringify(kind)});syncMatchPresentation(l)`);
}
let {t,run}=fixture();
assert.equal(run('l.numericalAiVersion'),1);
assert.equal(run('numericalStaffAdvice(l)'),null,'15 contre 15 : aucun conseil numérique');
assert.equal(run('numericalAdvicePanel(l)'),'');
const initial=run('JSON.stringify(S)');
assert.equal(run('rugbyMatchView().includes("Conseils tactiques en déséquilibre numérique")'),false);
assert.equal(run('JSON.stringify(S)'),initial);

// Jaune à l'équipe humaine : les recommandations sont calculées sans changer les consignes.
card(run);
assert.equal(run('activePlayers(l,0).length'),14);
assert.equal(run('activePlayers(l,1).length'),15);
assert.equal(run('numericalStaffAdvice(l).difference'),-1);
assert.equal(run('numericalStaffAdvice(l).suggestions.map(s=>s.kind+":"+s.value).join(",")'),'attack:conquete,defence:prudente');
assert.equal(run('numericalStaffAdvice(l).clockNote.includes("10 minute(s)")'),true);
const beforeAdvice=run('JSON.stringify(S)'),disk=t.store['bdt-v1'];
const panel=run('numericalAdvicePanel(l)');
assert.ok(panel.includes('14 contre 15'));
assert.ok(panel.includes('le score est à égalité'));
assert.ok(panel.includes('10 min restantes')===false);
assert.ok(panel.includes("applyNumericalAdvice('attack','conquete')"));
assert.ok(panel.includes("applyNumericalAdvice('defence','prudente')"));
assert.ok(run('rugbyMatchView().includes("Conseils tactiques en déséquilibre numérique")'));
assert.equal(run('JSON.stringify(S)'),beforeAdvice,'Aucun effet secondaire du conseil');
assert.equal(t.store['bdt-v1'],disk,'Pas de sauvegarde induite par affichage');

// Le bouton est une vraie action explicite, interdite en direct et durant une relecture.
run('l.paused=false');
assert.equal(run('applyNumericalAdvice("attack","conquete")'),false);
assert.ok(run('numericalAdvicePanel(l).includes("disabled")'));
assert.equal(run('l.tactics[0]'),'equilibre');
run('l.paused=true;addEvent(l,"Nouvelle action","play",{kind:"carry",team:0})');
assert.equal(run('presentationPending(l)'),true);
assert.equal(run('applyNumericalAdvice("attack","conquete")'),false);
run('syncMatchPresentation(l)');
assert.equal(run('applyNumericalAdvice("attack","invalid")'),false);
assert.equal(run('applyNumericalAdvice("attack","conquete")'),true);
assert.equal(run('l.tactics[0]'),'conquete');
assert.equal(run('S.tactic'),'conquete');
assert.equal(run('l.defences[0]'),'equilibre','Un conseil offensif ne touche pas à la défense');
assert.equal(run('applyNumericalAdvice("defence","prudente")'),true);
assert.equal(run('l.defences[0]'),'prudente');
assert.equal(run('S.defence'),'prudente');
assert.equal(run('numericalStaffAdvice(l).suggestions.length'),0);
assert.ok(run('numericalAdvicePanel(l).includes("déjà aux recommandations")'));
assert.equal(run('applyNumericalAdvice("defence","prudente")'),false,'Pas de réapplication inutile');

// Une sauvegarde portable conserve les décisions explicites et le jaune, sans champ V21.
const exported=run('JSON.stringify(createSaveDocument())');
const imported=context();
imported.run(`pendingSave=parseSaveDocument(${JSON.stringify(exported)});confirmSaveImport();var l=S.live`);
assert.equal(imported.run('l.paused'),true);
assert.equal(imported.run('l.tactics[0]'),'conquete');
assert.equal(imported.run('l.defences[0]'),'prudente');
assert.equal(imported.run('numericalStaffAdvice(l).suggestions.length'),0);
imported.run('l.minute=20');
assert.equal(imported.run('numericalStaffAdvice(l)'),null,'Fin réelle du jaune : retour à égalité');

// À 13 contre 15, sous la pluie, le jeu d'occupation est recommandé.
({run}=fixture());
card(run);run('l.minute=12');card(run);
assert.equal(run('activePlayers(l,0).length'),13);
assert.equal(run('numericalStaffAdvice(l).difference'),-2);
assert.equal(run('numericalStaffAdvice(l).suggestions[0].value'),'occupation');
run('l.weather="Pluie"');
assert.equal(run('numericalStaffAdvice(l).suggestions[0].value'),'occupation');
assert.ok(run('numericalAdvicePanel(l).includes("13 contre 15")'));
run('l.minute=20');
assert.equal(run('numericalStaffAdvice(l).difference'),-1);
run('l.minute=22');
assert.equal(run('numericalStaffAdvice(l)'),null);

// Décisions adaptées au score, à la météo, aux qualités et au temps restant.
({run}=fixture());card(run);
run('l.weather="Pluie"');
assert.equal(run('numericalStaffAdvice(l).suggestions[0].value'),'occupation');
run('l.weather="Sec";l.score=[0,14];l.flow.period=2;l.flow.firstEnd=40;l.flow.fullEnd=80;l.minute=72');
assert.equal(run('numericalStaffAdvice(l).remaining'),8);
assert.equal(run('numericalStaffAdvice(l).suggestions[0].value'),'large','Retard en fin de match : choix risqué autorisé');
run('l.score=[17,0]');
assert.equal(run('numericalStaffAdvice(l).suggestions[0].value'),'occupation','Protéger un avantage en sous-nombre');

// En supériorité, le jeu au large et, pour deux joueurs supplémentaires, la pression.
// Sous la pluie, la conquête ; les joueurs épuisés demandent de la prudence.
({run}=fixture());card(run,1);
assert.equal(run('numericalStaffAdvice(l).difference'),1);
assert.equal(run('numericalStaffAdvice(l).suggestions.find(s=>s.kind==="attack").value'),'large');
run('l.minute=12');card(run,1);
assert.equal(run('numericalStaffAdvice(l).difference'),2);
assert.equal(run('numericalStaffAdvice(l).suggestions.find(s=>s.kind==="defence").value'),'pression');
run('l.weather="Pluie"');
assert.equal(run('numericalStaffAdvice(l).suggestions.find(s=>s.kind==="attack").value'),'conquete');
run('activePlayers(l,0).forEach(p=>p.condition=50)');
assert.equal(run('numericalStaffAdvice(l).suggestions.find(s=>s.kind==="defence").value'),'prudente');

// Rouge définitif : ne jamais annoncer un retour. Rouge 20 min : le remplacement reste conditionnel.
({run}=fixture());card(run,0,'red');
assert.equal(run('activePlayers(l,0).length'),14);
assert.ok(run('numericalStaffAdvice(l).clockNote.includes("aucun remplacement")'));
run('l.minute=60');
assert.equal(run('numericalStaffAdvice(l).difference'),-1);
({run}=fixture());card(run,0,'red20');
assert.ok(run('numericalStaffAdvice(l).clockNote.includes("remplacement envisageable")'));
run('l.minute=30');
assert.equal(run('numericalStaffAdvice(l).difference'),-1,'Le joueur humain choisit le remplaçant');

// Compatibilité : un ancien match sans marqueur V20 ne reçoit pas de nouvel assistant.
const legacy=run('JSON.parse(JSON.stringify(S))');
delete legacy.live.numericalAiVersion;
legacy.live.managerMemory.forEach(m=>{delete m.lastCardDiff;delete m.cardBase});
const old=context(legacy);
assert.equal(old.run('numericalStaffAdvice(S.live)'),null);
assert.equal(old.run('numericalAdvicePanel(S.live)'),'');
assert.equal(old.run('!!createSaveDocument()'),true);

// Match terminé : aucune action possible.
run('l.finished=true;l.paused=true');
assert.equal(run('numericalStaffAdvice(l)'),null);
assert.equal(run('applyNumericalAdvice("attack","large")'),false);

console.log('V21 : recommandations 15v15, 15v14, 15v13, météo, score, effectifs, cartons, choix explicite et sauvegardes validés');
