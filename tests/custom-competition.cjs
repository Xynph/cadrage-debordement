'use strict';
process.env.CD_MODES_HERITES='1'; // Anciens modes de carrière (non-Monde) : test à migrer vers le mode Monde.
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),vm=require('node:vm');
assert.ok(fs.existsSync(path.join(__dirname,'../native/engine/custom-competition.cjs')),'Le domaine de compétition personnalisée existe');
const domain=require('../native/engine/custom-competition.cjs'),editor=require('../native/engine/competition-editor.cjs');
const document=editor.generate({name:'Ligue des vallées',clubs:Array.from({length:14},(_,i)=>'Club fictif '+(i+1)),doubleRound:true});
const ctx=vm.createContext({S:null,start(club,mode){assert.equal(mode,'fiction');ctx.S={club,season:1,round:0,phase:'league',live:null,clubs:Array.from({length:14},(_,id)=>({id,name:'Initial '+id,abbr:'I'+id})),schedule:[]};},worldNewSeason(){ctx.S.schedule=[];return 'preserved';}});
vm.runInContext('const custom=('+domain.factory.toString()+')();custom.installHooks()',ctx);
const call=(name,...args)=>{ctx.args=args;return vm.runInContext('custom.'+name+'(...args)',ctx);};
let checks=0;const yes=(v,m)=>{assert.ok(v,m);checks++;};
const payload={mode:'custom',club:3,confirmed:true,document};
for(const invalid of [{...payload,confirmed:false},{...payload,club:14},{...payload,document:{...document,clubs:document.clubs.slice(1)}},{...payload,extra:1}]){assert.throws(()=>call('create',invalid),/personnalisée/i);checks++;yes(ctx.S===null,'refus avant mutation');}
call('create',payload);yes(ctx.S.club===3&&ctx.S.clubs[3].name===document.clubs[3].name,'identités personnalisées');yes(ctx.S.clubs[3].abbr==='C04','abréviation stable');yes(call('validate',ctx.S),'état valide');
const before=JSON.stringify(ctx.S);call('project');yes(JSON.stringify(ctx.S)===before,'projection pure');
for(const mutate of [s=>s.clubs[0].name='Autre',s=>s.customCompetition.version=2,s=>s.customCompetition.extra=true,s=>s.customCompetition.clubs[0].name='<script>',s=>s.schedule[0][0].reverse(),s=>s.worldMode={},s=>s.customCompetition.schedule[0][0]=[0,0]]){const state=JSON.parse(before);mutate(state);assert.throws(()=>call('validate',state),/personnalisée/i);checks++;}
yes(vm.runInContext('worldNewSeason()',ctx)==='preserved','hook préserve résultat');yes(call('validate',ctx.S),'calendrier restauré au nouveau départ');
ctx.S.live={};const old=JSON.stringify(ctx.S);assert.throws(()=>call('create',payload),/match/i);yes(JSON.stringify(ctx.S)===old,'match interdit sans mutation');
yes(call('validate',{season:1,clubs:[]})===true,'ancienne carrière intacte sans marqueur');
const long=structuredClone(document);long.clubs[0].name='X'.repeat(80);yes(domain.support(long).playable,'nom de 80 caractères accepté');long.clubs[0].name+='X';yes(!domain.support(long).playable,'nom de 81 caractères refusé');
const reserved=structuredClone(document);reserved.name='Club & amis';yes(!domain.support(reserved).playable,'balisage réservé non jouable');
console.log(checks+' contrôles compétition personnalisée réussis');
