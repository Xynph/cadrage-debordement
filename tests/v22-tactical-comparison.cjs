const assert=require('node:assert/strict');
const {context}=require('./harness.cjs');

function fixture(){
 const t=context();
 t.run('start(0);beginMatch();pauseMatch();var l=S.live;l.minute=10;l.weather="Sec";l.score=[0,0];l.tactics[0]="equilibre";l.defences[0]="equilibre";syncMatchPresentation(l)');
 return t;
}
const t=fixture(),run=t.run;
assert.equal(run('numericalStaffAdvice(l)'),null);
assert.equal(run('numericalAdvicePanel(l)'),'');
assert.equal(run('numericalAdviceComparison(l,null)'),'');
run('giveMatchCard(l,0,activePlayers(l,0)[4].id,"yellow");syncMatchPresentation(l)');
assert.equal(run('activePlayers(l,0).length'),14);
const preview=run('numericalStaffAdvice(l)');
assert.equal(preview.suggestions.length,2);
assert.equal(preview.suggestions[0].value,'conquete');
assert.equal(preview.suggestions[1].value,'prudente');

const prior=run('JSON.stringify(S)'),disk=t.store['bdt-v1'];
const attackCurrent=run('numericalAdviceModel(l,"attack","equilibre")');
const attackNext=run('numericalAdviceModel(l,"attack","conquete")');
const defenceCurrent=run('numericalAdviceModel(l,"defence","equilibre")');
const defenceNext=run('numericalAdviceModel(l,"defence","prudente")');
assert.equal(attackCurrent.actual,'equilibre');
assert.equal(attackNext.actual,'conquete');
assert.equal(attackCurrent.minimum-attackNext.minimum,4);
assert.equal(attackCurrent.maximum-attackNext.maximum,7);
assert.ok(attackNext.handling<attackCurrent.handling,'Conquête réduit les fautes de main du modèle');
assert.ok(attackNext.fatigue>attackCurrent.fatigue,'Conquête augmente la charge offensive du modèle');
assert.equal(defenceCurrent.penalty,0);
assert.equal(defenceNext.penalty,-.02,'Ajustement exact du risque de pénalité du moteur');
assert.equal(defenceCurrent.fatigue,.37);
assert.equal(defenceNext.fatigue,.31);
assert.equal(defenceNext.cover,'Profondeur mieux protégée');
assert.equal(run('numericalAdviceModel(l,"attack","unknown")'),null);
assert.equal(run('numericalAdviceModel(l,"defence","unknown")'),null);
const rendered=run('numericalAdvicePanel(l)');
for(const label of ['Comparaison tactique','Mètres par progression réussie','Risque de faute de main','Propension au jeu au pied','Indice de dépense offensive','Risque de pénalité','Indice de dépense défensive','Couverture de la profondeur','Appliquer cette consigne','moteur fictif']){
 assert.ok(rendered.includes(label),label);
}
assert.equal(run('JSON.stringify(S)'),prior,'Les comparaisons ne modifient jamais le match');
assert.equal(t.store['bdt-v1'],disk,'Le rendu ne provoque pas de sauvegarde');
// Le comparatif n'est pas un clic; seules les commandes existantes peuvent appliquer la consigne.
assert.equal(run('l.tactics[0]'),'equilibre');
assert.equal(run('l.defences[0]'),'equilibre');
run('l.paused=false');
assert.ok(run('numericalAdvicePanel(l).includes("disabled")'));
assert.equal(run('applyNumericalAdvice("attack","conquete")'),false);
assert.equal(run('l.tactics[0]'),'equilibre');
run('l.paused=true;syncMatchPresentation(l)');
assert.equal(run('applyNumericalAdvice("attack","conquete")'),true);
assert.equal(run('l.tactics[0]'),'conquete');
assert.equal(run('l.defences[0]'),'equilibre');
assert.equal(run('applyNumericalAdvice("defence","prudente")'),true);
assert.equal(run('l.defences[0]'),'prudente');
assert.equal(run('numericalStaffAdvice(l).suggestions.length'),0);

// Réutiliser les modèles réellement appliqués à la zone : pas d'effet inventé
// lorsqu'une priorité locale du carnet de jeu remplace le plan principal.
const z=fixture(),rz=z.run;
rz('giveMatchCard(l,0,activePlayers(l,0)[4].id,"yellow")');
rz('l.playbooks[0].zones[fieldZone(0,l.territory)].attack="large"');
assert.equal(rz('numericalAdviceModel(l,"attack","equilibre").actual'),'large');
assert.equal(rz('numericalAdviceModel(l,"attack","conquete").actual'),'large');
assert.equal(rz('numericalAdviceModel(l,"attack","equilibre").handling'),rz('numericalAdviceModel(l,"attack","conquete").handling'));
assert.ok(rz('numericalAdvicePanel(l).includes("plan local")'));
rz('l.playbooks[0].zones[fieldZone(0,l.territory)].defence="pression"');
assert.equal(rz('numericalAdviceModel(l,"defence","equilibre").penalty'),rz('numericalAdviceModel(l,"defence","prudente").penalty'));
assert.ok(rz('numericalAdvicePanel(l).includes("effets affichés restent identiques")'));

// Le temps humide et le risque de montée défensive se fondent sur le même moteur.
rz('l.playbooks[0].zones[fieldZone(0,l.territory)].attack="inherit";l.playbooks[0].zones[fieldZone(0,l.territory)].defence="inherit";l.weather="Pluie"');
assert.ok(rz('numericalAdviceModel(l,"attack","large").handling>numericalAdviceModel(l,"attack","conquete").handling'));
assert.equal(rz('numericalAdviceModel(l,"defence","pression").penalty'),.045);
assert.equal(rz('numericalAdviceModel(l,"defence","pression").fatigue'),.53);
assert.equal(rz('numericalAdviceModel(l,"defence","prudente").fatigue'),.31);
assert.ok(rz('numericalAdviceComparison(l,{kind:"defence",value:"pression"}).includes("grands gains possibles")'));

// Les exports portables conservent le même modèle sans nouvel attribut V22.
const json=rz('JSON.stringify(createSaveDocument())');
const restored=context();
restored.run('pendingSave=parseSaveDocument('+JSON.stringify(json)+');confirmSaveImport();var l=S.live');
assert.equal(restored.run('l.numericalAiVersion'),1);
assert.equal(restored.run('numericalAdviceModel(l,"attack","large").actual'),'large');
assert.equal(restored.run('!!createSaveDocument()'),true);
const legacy=rz('JSON.parse(JSON.stringify(S))');
delete legacy.live.numericalAiVersion;
legacy.live.managerMemory.forEach(m=>{delete m.lastCardDiff;delete m.cardBase});
const old=context(legacy);
assert.equal(old.run('numericalStaffAdvice(S.live)'),null);
assert.equal(old.run('numericalAdvicePanel(S.live)'),'');
assert.equal(old.run('!!createSaveDocument()'),true);

// Comparer reste possible pour tout différentiel couvert par l'assistant V21.
const double=fixture(),rd=double.run;
rd('giveMatchCard(l,0,activePlayers(l,0)[4].id,"yellow");l.minute=12;giveMatchCard(l,0,activePlayers(l,0)[4].id,"yellow")');
assert.equal(rd('activePlayers(l,0).length'),13);
assert.ok(rd('numericalAdvicePanel(l).includes("Comparaison tactique")'));
rd('l.minute=22');
assert.equal(rd('numericalAdvicePanel(l)'),'');
console.log('V22 : compromis tirés du moteur, rendu sans mutation, zones prioritaires, clic explicite et sauvegardes vérifiés');
