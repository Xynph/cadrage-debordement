const assert=require('node:assert/strict');
const {context}=require('./harness.cjs');

function fixture(){
 const t=context();
 t.run('start(0);beginMatch();pauseMatch();var l=S.live;l.minute=10;l.weather="Sec";l.territory=15;l.tactics[0]="equilibre";l.defences[0]="equilibre";syncMatchPresentation(l)');
 return t;
}
const t=fixture(),run=t.run;
assert.equal(run('l.playbookVersion'),1);
const zones=run('fourZoneTacticalPreview(l)');
assert.equal(zones.length,4);
assert.equal(zones.map(z=>z.zone).join(','),'sortie,construction,pression,marque');
assert.equal(zones.map(z=>z.own).join(','),'12,36,64,90');
assert.equal(zones.filter(z=>z.current).length,1);
assert.equal(zones.find(z=>z.current).zone,'sortie');

// Chaque profil utilise les calculs existants, à la possession adaptée.
for(const [key,metre] of [['sortie',12],['construction',36],['pression',64],['marque',90]]){
 assert.equal(run('fieldZone(0,'+metre+')'),key);
 const a=run('fourZoneTacticalPreview(l).find(z=>z.zone==='+JSON.stringify(key)+').attack');
 const d=run('fourZoneTacticalPreview(l).find(z=>z.zone==='+JSON.stringify(key)+').defence');
 run('var shadow=Object.create(l);shadow.territory='+metre);
 const expectedAttack=run('numericalAdviceModel(shadow,"attack",l.tactics[0])');
 const expectedDefence=run('numericalAdviceModel(shadow,"defence",l.defences[0])');
 for(const field of ['actual','minimum','maximum','handling','kicking','fatigue'])
  assert.equal(a[field],expectedAttack[field],key+' : attaque '+field);
 for(const field of ['actual','penalty','fatigue','cover'])
  assert.equal(d[field],expectedDefence[field],key+' : défense '+field);
 assert.ok(a.minimum<=a.maximum,'Fourchette cohérente');
 assert.ok(a.handling>=0&&a.handling<=1,'Probabilité de main');
 assert.ok(a.kicking>=0&&a.kicking<=1,'Propension coup de pied');
}
const initial=run('JSON.stringify(S)'),disk=t.store['bdt-v1'];
let html=run('fourZoneTacticalPanel(l)');
for(const phrase of ['Comparaison tactique des quatre zones','Vos 22 mètres','Vos 22 → milieu','Milieu → leurs 22','Leurs 22 mètres','Gain si progression réussie','Faute de main','Jeu au pied','Risque de pénalité','Couverture','fatigue offensive','fatigue défensive','moteur fictif'])
 assert.ok(html.includes(phrase),phrase);
assert.equal((html.match(/<tr class="/g)||[]).length,4);
assert.ok(run('playbookPanel(l).includes("Comparaison tactique des quatre zones")'));
assert.ok(!run('playbookPanel(null).includes("Comparaison tactique des quatre zones")'));
assert.equal(run('JSON.stringify(S)'),initial,'Le calcul et le rendu ne modifient pas le match');
assert.equal(t.store['bdt-v1'],disk,'Le calcul ne sauvegarde rien');

// Les directives locales écrasent la tactique générale, pour une seule zone.
run('l.playbooks[0].zones.construction.attack="occupation";l.playbooks[0].zones.pression.defence="pression"');
const local=run('fourZoneTacticalPreview(l)');
assert.equal(local.find(z=>z.zone==='construction').attack.actual,'occupation');
assert.equal(local.find(z=>z.zone==='construction').attackLocal,true);
assert.equal(local.find(z=>z.zone==='sortie').attack.actual,'equilibre');
assert.equal(local.find(z=>z.zone==='sortie').attackLocal,false);
assert.equal(local.find(z=>z.zone==='pression').defence.actual,'pression');
assert.equal(local.find(z=>z.zone==='pression').defenceLocal,true);
assert.equal(local.find(z=>z.zone==='marque').defence.actual,'equilibre');
html=run('fourZoneTacticalPanel(l)');
assert.ok(html.includes('Consigne locale'));
assert.ok(html.includes('Plan général'));
assert.equal(run('l.tactics[0]'),'equilibre');
assert.equal(run('l.defences[0]'),'equilibre');

// Changer la météo affecte les risques du modèle, sans changer les consignes.
const dry=run('fourZoneTacticalPreview(l).find(z=>z.zone==="construction").attack.handling');
run('l.weather="Pluie"');
const rain=run('fourZoneTacticalPreview(l).find(z=>z.zone==="construction").attack.handling');
assert.ok(rain>=dry,'Pluie ne réduit pas le risque de faute de main du modèle');
assert.equal(run('l.playbooks[0].zones.construction.attack'),'occupation');

// Comparaison entièrement consultative aussi lorsque la simulation est active.
run('l.paused=false');
const live=run('JSON.stringify(S)');
assert.ok(run('fourZoneTacticalPanel(l).includes("Comparaison tactique")'));
assert.equal(run('JSON.stringify(S)'),live);
run('l.paused=true');

// Pour une équipe orientée dans l'autre sens, les repères sont inversés.
run('l.userSide=1');
const reverse=run('fourZoneTacticalPreview(l)');
assert.equal(reverse.map(z=>z.territory).join(','),'88,64,36,10');
for(const item of reverse)assert.equal(run('fieldZone(1,'+item.territory+')'),item.zone);
run('l.userSide=0');

// Export portable avec directives locales : aucun nouveau champ V24.
const json=run('JSON.stringify(createSaveDocument())');
const loaded=context();
loaded.run('pendingSave=parseSaveDocument('+JSON.stringify(json)+');confirmSaveImport();var l=S.live');
assert.equal(loaded.run('l.playbooks[0].zones.construction.attack'),'occupation');
assert.equal(loaded.run('l.playbooks[0].zones.pression.defence'),'pression');
assert.equal(loaded.run('fourZoneTacticalPreview(l).length'),4);
assert.equal(loaded.run('!!createSaveDocument()'),true);

// Ancienne sauvegarde avant la fonctionnalité de carnet : ne pas ajouter de champs.
const previous=run('JSON.parse(JSON.stringify(S))');
delete previous.live.playbookVersion;
delete previous.live.playbooks;
const old=context(previous);
assert.equal(old.run('fourZoneTacticalPreview(S.live).length'),0);
assert.equal(old.run('fourZoneTacticalPanel(S.live)'),'');
assert.equal(old.run('!!createSaveDocument()'),true);

// Les anciennes rencontres V19/V20 restent contrôlées par leurs suites dédiées.
console.log('V24 : quatre zones, coefficients du moteur, priorités locales, lecture seule et sauvegardes validés');
