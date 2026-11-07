const {test}=require('node:test');
const assert=require('node:assert/strict');
const ui=require('../dist/premium-squad.js');
const p={id:'p1',name:'<Nom & "long">',position:'Demi d’ouverture',age:25,note:76,condition:83,potential:87,salary:1200,contract:4,minutes:93,physical:31,status:'Banc',injury:0,attributes:{power:{label:'Puissance',value:70},speed:{label:'Vitesse',value:84},tackle:{label:'Plaquage',value:61},pass:{label:'Passe',value:85},kick:{label:'Jeu au pied',value:79},stamina:{label:'Endurance',value:73}}};
test('sélection reconciliée avec les seuls IDs réellement affichés',()=>{
 assert.equal(ui.selectPlayer(['a','b'],'b'),'b');assert.equal(ui.selectPlayer(['a'],'b'),'a');assert.equal(ui.selectPlayer([],'b'),null);
});
test('dossier échappé et lecture sans mutation',()=>{
 const before=JSON.stringify(p),html=ui.playerCard(p);
 assert.match(html,/&lt;Nom &amp; &quot;long&quot;&gt;/);assert.doesNotMatch(html,/<Nom/);
 for(const value of ['83','31','1 200','S4','93'])assert.ok(html.includes(value),value);
 assert.equal(JSON.stringify(p),before);
});
test('un radar, valeurs natives accessibles et aucune valeur absente inventée',()=>{
 const html=ui.profileOverview(p);assert.equal((html.match(/<svg/g)||[]).length,1);
 for(const [key,a] of Object.entries(p.attributes))assert.ok(html.includes(a.label)&&html.includes(String(a.value)),key);
 const empty=ui.profileOverview({...p,note:null,condition:null,physical:null,minutes:null,salary:null,contract:null,attributes:{}});
 assert.doesNotMatch(empty,/NaN|undefined|null|<svg/);assert.match(empty,/non renseignés/);assert.match(empty,/—/);
});
