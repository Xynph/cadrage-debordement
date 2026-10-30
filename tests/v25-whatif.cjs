const assert=require('node:assert/strict');
const {context}=require('./harness.cjs');

function fixture(){
 const t=context();
 t.run('start(0);beginMatch();pauseMatch();var l=S.live;l.minute=10;l.weather="Sec";l.territory=15;l.tactics[0]="equilibre";l.defences[0]="equilibre";syncMatchPresentation(l)');
 return t;
}
const t=fixture(),run=t.run;
assert.equal(run('l.playbookVersion'),1);
assert.equal(run('fourZoneWhatIf(l)'),null);
assert.equal(run('fourZonePreviewChoice.plan'),'');
const empty=run('fourZoneWhatIfPanel(l)');
for(const label of ['Et si vous changiez une seule zone','Zone à comparer','Type de consigne','Consigne alternative','Choisir un scénario','Comparaison avant après']){
 assert.ok(empty.includes(label),label);
}
assert.ok(run('fourZoneTacticalPanel(l).includes("Et si vous changiez une seule zone")'));
assert.ok(run('playbookPanel(l).includes("Et si vous changiez une seule zone")'));
assert.equal(run('fourZoneTacticalPreview(l).length'),4);

const before=run('JSON.stringify(S)'),disk=t.store['bdt-v1'];
const exportedBefore=run('JSON.stringify(createSaveDocument())');
assert.equal(run('setFourZonePreviewChoice("plan","occupation")'),true);
let preview=run('fourZoneWhatIf(l)');
assert.equal(preview.zone,'sortie');
assert.equal(preview.kind,'attack');
assert.equal(preview.plan,'occupation');
assert.equal(preview.previous.actual,'equilibre');
assert.equal(preview.alternate.actual,'occupation');
assert.equal(preview.previousSource,'Plan général');
assert.equal(preview.alternateSource,'Consigne locale');
assert.equal(preview.unchangedZones.join(','),'construction,pression,marque');
assert.ok(preview.previous.minimum>preview.alternate.minimum,'Gain territorial calculé du moteur');
const rendered=run('fourZoneWhatIfPanel(l)');
for(const label of ['Avant','Après (aperçu)','Faute de main','Jeu au pied','Indice de fatigue offensive','Mètres par progression réussie','Occupation']){
 assert.ok(rendered.includes(label),label);
}
assert.ok(rendered.includes("setFourZonePreviewChoice('plan',this.value)"));
assert.equal(run('JSON.stringify(S)'),before,'La sélection n’altère pas les consignes ni les joueurs');
assert.equal(t.store['bdt-v1'],disk,'La sélection ne déclenche aucune sauvegarde');
assert.equal(run('JSON.stringify(createSaveDocument())'),exportedBefore,'Le scénario est exclu de la sauvegarde');

// Vérifier le calcul sur la même zone avec le même code que le moteur.
run('var shadow=Object.create(l);shadow.territory=12;shadow.playbooks=[...l.playbooks];shadow.playbooks[0]={...l.playbooks[0],zones:{...l.playbooks[0].zones,sortie:{...l.playbooks[0].zones.sortie,attack:"occupation"}}}');
const fromEngine=run('numericalAdviceModel(shadow,"attack",l.tactics[0])');
for(const key of ['actual','minimum','maximum','handling','kicking','fatigue']){
 assert.equal(preview.alternate[key],fromEngine[key],key);
}
assert.equal(run('fourZoneTacticalPreview(l).find(z=>z.zone==="sortie").attack.actual'),'equilibre');

// Zone et type réinitialisent l’alternative, et les entrées invalides sont refusées.
assert.equal(run('setFourZonePreviewChoice("zone","construction")'),true);
assert.equal(run('fourZonePreviewChoice.plan'),'');
assert.equal(run('setFourZonePreviewChoice("plan","inherit")'),true);
run('l.playbooks[0].zones.construction.attack="occupation"');
preview=run('fourZoneWhatIf(l)');
assert.equal(preview.previous.actual,'occupation');
assert.equal(preview.alternate.actual,'equilibre');
assert.equal(preview.previousSource,'Consigne locale');
assert.equal(preview.alternateSource,'Plan général');
assert.equal(run('l.playbooks[0].zones.construction.attack'),'occupation');
assert.equal(run('setFourZonePreviewChoice("kind","defence")'),true);
assert.equal(run('fourZonePreviewChoice.plan'),'');
assert.equal(run('setFourZonePreviewChoice("plan","prudente")'),true);
preview=run('fourZoneWhatIf(l)');
assert.equal(preview.kind,'defence');
assert.equal(preview.previous.actual,'equilibre');
assert.equal(preview.alternate.actual,'prudente');
assert.ok(preview.previous.penalty>preview.alternate.penalty,'Ajustement réel de pénalité');
assert.ok(preview.previous.fatigue>preview.alternate.fatigue,'Charge défensive réellement différente');
assert.ok(run('fourZoneWhatIfPanel(l).includes("Couverture de profondeur")'));
assert.ok(run('fourZoneWhatIfPanel(l).includes("Indice de fatigue défensive")'));
assert.equal(run('l.defences[0]'),'equilibre');

const selection=run('JSON.stringify(fourZonePreviewChoice)');
for(const [kind,value] of [['zone','inconnue'],['kind','scrum'],['plan','stratageme'],['autre','pression']]){
 assert.equal(run('setFourZonePreviewChoice('+JSON.stringify(kind)+','+JSON.stringify(value)+')'),false);
 assert.equal(run('JSON.stringify(fourZonePreviewChoice)'),selection);
}
assert.equal(run('setFourZonePreviewChoice("plan","")'),true);
assert.equal(run('fourZoneWhatIf(l)'),null);

// Si l’alternative est déjà appliquée, afficher des effets identiques, pas un bénéfice fictif.
assert.equal(run('setFourZonePreviewChoice("plan","equilibre")'),true);
preview=run('fourZoneWhatIf(l)');
assert.equal(preview.previous.actual,preview.alternate.actual);
assert.ok(run('fourZoneWhatIfPanel(l).includes("Aucun écart")'));

// Une zone locale conserve sa priorité ; l’hypothèse ne modifie pas les trois autres.
assert.equal(run('setFourZonePreviewChoice("kind","attack")'),true);
assert.equal(run('setFourZonePreviewChoice("plan","large")'),true);
const local=run('fourZoneWhatIf(l)');
assert.equal(local.previous.actual,'occupation');
assert.equal(local.alternate.actual,'large');
assert.equal(run('l.playbooks[0].zones.construction.attack'),'occupation');
assert.equal(run('fourZoneTacticalPreview(l).find(z=>z.zone==="marque").attack.actual'),'equilibre');

// Pendant la simulation, les sélecteurs restent de simples choix d’aperçu.
run('l.paused=false');
const live=run('JSON.stringify(S)');
assert.equal(run('setFourZonePreviewChoice("plan","occupation")'),true);
assert.equal(run('JSON.stringify(S)'),live);
run('l.paused=true');

// La même zone est lue dans le bon sens lorsque l’utilisateur joue de l’autre côté.
run('l.userSide=1;fourZonePreviewChoice={zone:"sortie",kind:"attack",plan:"large"}');
const reverse=run('fourZoneWhatIf(l)');
assert.equal(reverse.zone,'sortie');
assert.equal(run('fourZoneTacticalPreview(l).find(z=>z.zone==="sortie").territory'),88);
assert.equal(reverse.alternate.actual,'large');
run('l.userSide=0');

// Export/import : les états transitoires du comparatif ne sont pas persistés.
const exported=run('JSON.stringify(createSaveDocument())');
const loaded=context();
loaded.run('pendingSave=parseSaveDocument('+JSON.stringify(exported)+');confirmSaveImport();var l=S.live');
assert.equal(loaded.run('fourZonePreviewChoice.plan'),'');
assert.equal(loaded.run('l.playbooks[0].zones.construction.attack'),'occupation');
assert.equal(loaded.run('fourZoneWhatIf(l)'),null);
assert.equal(loaded.run('fourZoneTacticalPreview(l).length'),4);
assert.equal(loaded.run('!!createSaveDocument()'),true);

// Ancien match sans carnet : aucun scénario et aucun changement de sauvegarde.
const oldState=run('JSON.parse(JSON.stringify(S))');
delete oldState.live.playbookVersion;
delete oldState.live.playbooks;
const old=context(oldState);
assert.equal(old.run('fourZoneWhatIf(S.live)'),null);
assert.equal(old.run('fourZoneWhatIfPanel(S.live)'),'');
assert.equal(old.run('setFourZonePreviewChoice("plan","large")'),false);
assert.equal(old.run('!!createSaveDocument()'),true);

console.log('V25 : comparaison attaque/défense, quatre zones, calcul moteur, lecture seule, UI, sauvegardes et héritage validés');
