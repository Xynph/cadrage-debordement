const assert=require('node:assert/strict');
const {context}=require('./harness.cjs');

function fixture(){
 const t=context();
 t.run('start(0);beginMatch();pauseMatch();var l=S.live;l.minute=10;l.weather="Sec";l.score=[0,0];l.territory=18;l.tactics[0]="equilibre";l.defences[0]="equilibre";giveMatchCard(l,0,activePlayers(l,0)[4].id,"yellow");syncMatchPresentation(l)');
 return t;
}

const t=fixture(),run=t.run;
assert.equal(run('activePlayers(l,0).length'),14);
assert.equal(run('numericalStaffAdvice(l).suggestions[0].value'),'conquete');
assert.equal(run('numericalAdviceZoneControls(l,{kind:"attack",value:"conquete"})'),'');
run('l.playbooks[0].zones.sortie.attack="large";l.playbooks[0].zones.construction.attack="occupation";l.playbooks[0].zones.pression.defence="pression"');
const advice=run('numericalStaffAdvice(l)');
assert.equal(advice.zoneSuggestions.length,2);
assert.equal(advice.suggestions.length,2);
assert.equal(run('fieldZone(0,l.territory)'),'sortie');

const before=run('JSON.stringify(S)'),disk=t.store['bdt-v1'];
const html=run('numericalAdvicePanel(l)');
assert.ok(html.includes('Priorité du carnet de jeu'));
assert.ok(html.includes('Vos 22 mètres · zone actuelle'));
assert.ok(html.includes('Vos 22 → milieu'));
assert.ok(html.includes('Milieu → leurs 22'));
assert.ok(html.includes('Attaque locale :'));
assert.ok(html.includes('Défense locale :'));
assert.ok(html.includes("applyNumericalZoneAdvice('attack','sortie','conquete')"));
assert.ok(html.includes("applyNumericalZoneAdvice('attack','construction','conquete')"));
assert.ok(html.includes("applyNumericalZoneAdvice('defence','pression','prudente')"));
assert.equal(run('JSON.stringify(S)'),before,'Les conseils locaux restent sans effet de bord');
assert.equal(t.store['bdt-v1'],disk,'Aucun enregistrement sur un simple rendu');

// Les commandes rejetées ne changent ni le plan général ni les consignes locales.
assert.equal(run('applyNumericalZoneAdvice("attack","unknown","conquete")'),false);
assert.equal(run('applyNumericalZoneAdvice("attack","sortie","unknown")'),false);
assert.equal(run('applyNumericalZoneAdvice("attack","sortie","large")'),false);
assert.equal(run('applyNumericalZoneAdvice("scrum","sortie","conquete")'),false);
run('l.paused=false');
assert.equal(run('applyNumericalZoneAdvice("attack","sortie","conquete")'),false);
assert.ok(run('numericalAdvicePanel(l).includes("disabled")'));
run('l.paused=true;addEvent(l,"Action témoin","play",{kind:"carry",team:0});playback(l).cursor=l.events.length-2');
assert.equal(run('presentationPending(l)'),true);
assert.equal(run('applyNumericalZoneAdvice("attack","sortie","conquete")'),false);
run('syncMatchPresentation(l)');

// Appliquer à une seule zone n'altère jamais le plan général ni les autres zones.
assert.equal(run('applyNumericalZoneAdvice("attack","sortie","conquete")'),true);
assert.equal(run('l.playbooks[0].zones.sortie.attack'),'conquete');
assert.equal(run('S.manager.playbook.zones.sortie.attack'),'conquete');
assert.equal(run('l.playbooks[0].zones.construction.attack'),'occupation');
assert.equal(run('l.tactics[0]'),'equilibre');
assert.equal(run('S.tactic'),'equilibre');
assert.equal(run('l.defences[0]'),'equilibre');
assert.equal(run('effectiveAttack(l,0,18)'),'conquete');
assert.equal(run('effectiveAttack(l,0,32)'),'occupation');
assert.equal(run('applyNumericalZoneAdvice("attack","sortie","conquete")'),false,'Pas de double validation');
assert.equal(run('applyNumericalZoneAdvice("defence","pression","prudente")'),true);
assert.equal(run('l.playbooks[0].zones.pression.defence'),'prudente');
assert.equal(run('S.manager.playbook.zones.pression.defence'),'prudente');
assert.equal(run('l.defences[0]'),'equilibre');
assert.equal(run('numericalStaffAdvice(l).zoneSuggestions.length'),1);

// Après un changement de contexte, l'ancien bouton ne peut plus appliquer son conseil.
run('l.weather="Pluie"');
assert.equal(run('numericalStaffAdvice(l).suggestions.find(s=>s.kind==="attack").value'),'occupation');
assert.equal(run('applyNumericalZoneAdvice("attack","construction","conquete")'),false);
assert.equal(run('l.playbooks[0].zones.construction.attack'),'occupation');

// Une consigne principale déjà conforme ne doit pas masquer un conflit local.
const t2=fixture(),r2=t2.run;
r2('l.tactics[0]="conquete";l.playbooks[0].zones.sortie.attack="large"');
assert.equal(r2('numericalStaffAdvice(l).suggestions.some(s=>s.kind==="attack")'),false);
assert.equal(r2('numericalStaffAdvice(l).zoneSuggestions.some(s=>s.kind==="attack")'),true);
assert.ok(r2('numericalAdvicePanel(l).includes("plan principal correspond au conseil du staff")'));
assert.equal(r2('applyNumericalZoneAdvice("attack","sortie","conquete")'),true);
assert.equal(r2('l.tactics[0]'),'conquete');
assert.equal(r2('numericalStaffAdvice(l).zoneSuggestions.some(s=>s.kind==="attack")'),false);

// Sauvegarde portable : seules les valeurs déjà prévues dans le carnet sont modifiées.
const exportDoc=run('JSON.stringify(createSaveDocument())');
const restored=context();
restored.run('pendingSave=parseSaveDocument('+JSON.stringify(exportDoc)+');confirmSaveImport();var l=S.live');
assert.equal(restored.run('l.playbooks[0].zones.sortie.attack'),'conquete');
assert.equal(restored.run('S.manager.playbook.zones.sortie.attack'),'conquete');
assert.equal(restored.run('l.tactics[0]'),'equilibre');
assert.equal(restored.run('!!createSaveDocument()'),true);

// Anciens matchs sans profil V20/V21 : ni recommandations ni mutation.
const legacy=run('JSON.parse(JSON.stringify(S))');
delete legacy.live.numericalAiVersion;
legacy.live.managerMemory.forEach(m=>{delete m.lastCardDiff;delete m.cardBase});
const old=context(legacy);
assert.equal(old.run('numericalStaffAdvice(S.live)'),null);
assert.equal(old.run('numericalAdvicePanel(S.live)'),'');
assert.equal(old.run('applyNumericalZoneAdvice("attack","sortie","conquete")'),false);
assert.equal(old.run('!!createSaveDocument()'),true);

// Sans carton actif, avec un match fini ou une zone sans conflit : aucun clic.
run('l.minute=21');
assert.equal(run('numericalStaffAdvice(l)'),null);
assert.equal(run('applyNumericalZoneAdvice("attack","construction","conquete")'),false);
run('l.finished=true;l.paused=true');
assert.equal(run('applyNumericalZoneAdvice("attack","construction","conquete")'),false);
console.log('V23 : priorités locales, clics par zone, absence de mutation automatique et anciennes sauvegardes validés');
