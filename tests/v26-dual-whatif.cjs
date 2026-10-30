const assert=require('node:assert/strict');
const {context}=require('./harness.cjs');

function fixture(){
 const t=context();
 t.run('start(0);beginMatch();pauseMatch();var l=S.live;l.minute=10;l.weather="Sec";l.territory=15;l.tactics[0]="equilibre";l.defences[0]="equilibre";syncMatchPresentation(l)');
 return t;
}
const t=fixture(),run=t.run;
assert.equal(run('l.playbookVersion'),1);
assert.equal(run('fourZoneDoubleWhatIf(l)'),null);
assert.equal(run('fourZoneSecondChoice.zone'),'construction');
assert.equal(run('fourZoneSecondChoice.kind'),'defence');
assert.equal(run('fourZoneSecondChoice.plan'),'');
const initialPanel=run('fourZoneDoubleWhatIfPanel(l)');
for(const term of ['Deux ajustements, deux zones','Deuxième zone','Deuxième type de consigne','Deuxième consigne alternative','Choisissez d’abord']){
 assert.ok(initialPanel.includes(term),term);
}
assert.ok(run('fourZoneTacticalPanel(l).includes("Deux ajustements, deux zones")'));
assert.ok(run('playbookPanel(l).includes("Deux ajustements, deux zones")'));

const baseline=run('JSON.stringify(S)'),store=t.store['bdt-v1'],savedState=run('JSON.stringify(createSaveDocument().state)');
assert.equal(run('setFourZonePreviewChoice("plan","large")'),true);
assert.equal(run('setFourZoneSecondChoice("plan","pression")'),true);
let both=run('fourZoneDoubleWhatIf(l)');
assert.ok(both,'Le double scénario est calculé une fois les deux choix renseignés');
assert.equal(both.changes.length,2);
assert.equal(both.changes.map(x=>x.zone).join(','),'sortie,construction');
assert.equal(both.changes.map(x=>x.kind).join(','),'attack,defence');
assert.equal(both.unchangedZones.join(','),'pression,marque');
assert.equal(both.changes[0].before.actual,'equilibre');
assert.equal(both.changes[0].after.actual,'large');
assert.equal(both.changes[1].before.actual,'equilibre');
assert.equal(both.changes[1].after.actual,'pression');
assert.ok(both.changes[0].after.maximum>both.changes[0].before.maximum);
assert.ok(both.changes[1].after.penalty>both.changes[1].before.penalty);
assert.ok(both.changes[1].after.fatigue>both.changes[1].before.fatigue);
assert.equal(run('fourZoneTacticalPreview(l).find(z=>z.zone==="sortie").attack.actual'),'equilibre');
assert.equal(run('fourZoneTacticalPreview(l).find(z=>z.zone==="construction").defence.actual'),'equilibre');
let html=run('fourZoneDoubleWhatIfPanel(l)');
for(const phrase of ['1. Vos 22 mètres','2. Vos 22 → milieu','Gain par progression réussie','Faute de main','Indice de fatigue offensive','Pénalité : ajustement du modèle','Couverture défensive','Indice de fatigue défensive','Compromis dans les deux secteurs','ne sont pas additionnés']){
 assert.ok(html.includes(phrase),phrase);
}
assert.ok(html.includes("setFourZoneSecondChoice('kind',this.value)"));
assert.equal(run('JSON.stringify(S)'),baseline,'Ni le match ni les consignes ne changent lors du double aperçu');
assert.equal(t.store['bdt-v1'],store,'Les scénarios ne déclenchent pas de stockage');
assert.equal(run('JSON.stringify(createSaveDocument().state)'),savedState,'Les hypothèses ne sont pas persistées');

// Le modèle reçoit bien LES DEUX choix dans une copie commune, et non deux mutateurs.
run('var shadow=Object.create(l);shadow.playbooks=[...l.playbooks];shadow.playbooks[0]={...l.playbooks[0],zones:{...l.playbooks[0].zones,sortie:{...l.playbooks[0].zones.sortie,attack:"large"},construction:{...l.playbooks[0].zones.construction,defence:"pression"}}}');
for(const [i,territory] of [[0,12],[1,36]]){
 run('var scoped=Object.create(shadow);scoped.territory='+territory);
 const kind=i===0?'attack':'defence';
 const expected=run('numericalAdviceModel(scoped,'+JSON.stringify(kind)+',l.'+(i===0?'tactics':'defences')+'[0])');
 for(const field of i===0?['actual','minimum','maximum','handling','kicking','fatigue']:['actual','penalty','cover','fatigue']){
  assert.equal(both.changes[i].after[field],expected[field],i+' '+field);
 }
}
assert.equal(run('JSON.stringify(S)'),baseline);
assert.equal(run('l.playbooks[0].zones.sortie.attack'),'inherit');
assert.equal(run('l.playbooks[0].zones.construction.defence'),'inherit');

// Deux choix offensifs dans des zones distinctes sont aussi supportés.
assert.equal(run('setFourZoneSecondChoice("kind","attack")'),true);
assert.equal(run('fourZoneSecondChoice.plan'),'');
assert.equal(run('fourZoneDoubleWhatIf(l)'),null);
assert.equal(run('setFourZoneSecondChoice("plan","occupation")'),true);
both=run('fourZoneDoubleWhatIf(l)');
assert.equal(both.changes[1].after.actual,'occupation');
assert.equal(both.changes[1].kind,'attack');
assert.equal(both.unchangedZones.join(','),'pression,marque');

// Une consigne locale et « suivre le plan général » sont pris en compte correctement.
run('l.playbooks[0].zones.construction.attack="conquete"');
assert.equal(run('setFourZoneSecondChoice("plan","inherit")'),true);
both=run('fourZoneDoubleWhatIf(l)');
assert.equal(both.changes[1].before.actual,'conquete');
assert.equal(both.changes[1].after.actual,'equilibre');
assert.equal(both.changes[1].beforeSource,'Consigne locale');
assert.equal(both.changes[1].afterSource,'Plan général');
assert.equal(run('l.playbooks[0].zones.construction.attack'),'conquete');

// Le deuxième choix ne peut pas cibler la même zone et refuse les valeurs inconnues.
const prev=run('JSON.stringify(fourZoneSecondChoice)');
for(const [field,value] of [['zone','sortie'],['zone','unknown'],['kind','maul'],['plan','mauvais'],['autre','large']]){
 assert.equal(run('setFourZoneSecondChoice('+JSON.stringify(field)+','+JSON.stringify(value)+')'),false);
 assert.equal(run('JSON.stringify(fourZoneSecondChoice)'),prev);
}
const repeated=run('fourZoneDoubleWhatIf(l,{zone:"sortie",kind:"attack",plan:"large"},{zone:"sortie",kind:"defence",plan:"prudente"})');
assert.equal(repeated,null,'Impossible de combiner deux choix sur la même zone');
assert.equal(run('fourZoneDoubleWhatIf(l,{zone:"sortie",kind:"attack",plan:"invalid"},{zone:"construction",kind:"defence",plan:"pression"})'),null);

// Changer la première zone qui recoupe la seconde réattribue une autre zone et invalide le second plan.
assert.equal(run('setFourZonePreviewChoice("zone","construction")'),true);
assert.notEqual(run('fourZoneSecondChoice.zone'),'construction');
assert.equal(run('fourZoneSecondChoice.plan'),'');
assert.equal(run('fourZonePreviewChoice.plan'),'');
assert.equal(run('fourZoneDoubleWhatIf(l)'),null);
assert.equal(run('setFourZonePreviewChoice("plan","occupation")'),true);
assert.equal(run('setFourZoneSecondChoice("zone","marque")'),true);
assert.equal(run('setFourZoneSecondChoice("kind","defence")'),true);
assert.equal(run('setFourZoneSecondChoice("plan","prudente")'),true);
both=run('fourZoneDoubleWhatIf(l)');
assert.equal(both.changes.map(c=>c.zone).join(','),'construction,marque');
assert.equal(both.changes[1].after.actual,'prudente');

// Les scénarios restent sans effet même si le match est en cours.
run('l.paused=false');
const playing=run('JSON.stringify(S)');
assert.ok(run('fourZoneDoubleWhatIfPanel(l).includes("Deux ajustements, deux zones")'));
assert.equal(run('setFourZoneSecondChoice("plan","pression")'),true);
assert.equal(run('JSON.stringify(S)'),playing);
run('l.paused=true');

// Des points de territoire symétriques sont utilisés lorsque l'équipe est inversée.
run('l.userSide=1;fourZonePreviewChoice={zone:"sortie",kind:"attack",plan:"large"};fourZoneSecondChoice={zone:"construction",kind:"defence",plan:"prudente"}');
both=run('fourZoneDoubleWhatIf(l)');
assert.equal(both.changes.length,2);
assert.equal(run('fourZoneTacticalPreview(l).find(z=>z.zone==="sortie").territory'),88);
assert.equal(run('fourZoneTacticalPreview(l).find(z=>z.zone==="construction").territory'),64);
run('l.userSide=0');

// L'export conserve les consignes réelles, et un nouveau contexte oublie les hypothèses.
const exported=run('JSON.stringify(createSaveDocument())');
const restored=context();
restored.run('pendingSave=parseSaveDocument('+JSON.stringify(exported)+');confirmSaveImport();var l=S.live');
assert.equal(restored.run('fourZonePreviewChoice.plan'),'');
assert.equal(restored.run('fourZoneSecondChoice.plan'),'');
assert.equal(restored.run('fourZoneDoubleWhatIf(l)'),null);
assert.equal(restored.run('l.playbooks[0].zones.construction.attack'),'conquete');
assert.equal(restored.run('!!createSaveDocument()'),true);

// Match ancien sans carnet : l'aperçu reste absent, la sauvegarde reste valide.
const legacy=run('JSON.parse(JSON.stringify(S))');
delete legacy.live.playbookVersion;delete legacy.live.playbooks;
const old=context(legacy);
assert.equal(old.run('fourZoneDoubleWhatIf(S.live)'),null);
assert.equal(old.run('fourZoneDoubleWhatIfPanel(S.live)'),'');
assert.equal(old.run('setFourZoneSecondChoice("plan","pression")'),false);
assert.equal(old.run('!!createSaveDocument()'),true);

console.log('V26 : deux zones distinctes, attaque/défense, coefficients du moteur, lecture seule et sauvegardes validés');
