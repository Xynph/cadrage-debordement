'use strict';
const commands=['playbook_set','playbook_staff_zone'];
function factory(){
 const copy=value=>JSON.parse(JSON.stringify(value));
 const check=(ok,message)=>{if(!ok)throw Error(message);};
 const object=value=>value!==null&&typeof value==='object'&&!Array.isArray(value);
 const context=()=>({season:S.season,week:S.franceMode?.week??S.round,club:S.club,live:!!S.live});
 const available=()=>!!S?.manager?.playbook&&S.phase!=='ended'&&(!S.live||playbookRules(S.live)&&S.live.paused&&!S.live.finished&&!presentationPending(S.live));
 const options=table=>Object.entries(table).map(([id,[label,description]])=>({id,label,description}));
 function project(){
  if(!S)return null;
  const live=S.live,plan=live&&playbookRules(live)?live.playbooks[live.userSide]:S.manager?.playbook;
  if(!plan)return {context:context(),available:false,zones:[],setPieces:[],reason:'Ce format de carrière ne possède pas de carnet de jeu.'};
  const attack=live?live.tactics[live.userSide]:S.tactic,defence=live?live.defences?.[live.userSide]||'equilibre':S.defence||'equilibre';
  return {context:context(),available:available(),inMatch:!!live,currentZone:live?fieldZone(live.userSide,live.territory):null,general:{attack,defence,attackLabel:TACTICS[attack][0],defenceLabel:DEFENCES[defence][0]},
   zones:Object.entries(FIELD_ZONES).map(([id,label])=>({id,label,attack:plan.zones[id].attack,defence:plan.zones[id].defence,effectiveAttack:plan.zones[id].attack==='inherit'?attack:plan.zones[id].attack,effectiveDefence:plan.zones[id].defence==='inherit'?defence:plan.zones[id].defence})),
   attackOptions:[{id:'inherit',label:'Plan principal',description:'Suivre le choix général.'},...options(TACTICS)],defenceOptions:[{id:'inherit',label:'Plan principal',description:'Suivre le choix général.'},...options(DEFENCES)],
   setPieces:[['scrum','Mêlées',SCRUM_MOVES],['lineout','Touches',LINEOUT_MOVES],['kickoff','Renvois',KICKOFF_MOVES]].map(([key,label,table])=>({key,label,selected:plan[key],options:options(table)})),
   preview:live&&playbookRules(live)?copy(fourZoneTacticalPreview(live)):[],staffAdvice:live?copy(numericalStaffAdvice(live)):null,
   notice:'Une consigne locale remplace le plan principal dans sa zone. Les phases arrêtées suivent leur propre choix. Ces compromis de simulation ne garantissent aucun résultat.',reason:available()?'':live?'Mettez le match en pause pour décider, en dehors des transitions et après le coup de sifflet.':'Décision indisponible en fin de saison.'};
 }
 function execute(command,p){
  check(object(p)&&Object.keys(p).every(key=>['context','key','value','zone'].includes(key)),'Champs du carnet inconnus.');
  const current=context();
  check(object(p.context)&&Object.keys(p.context).length===4&&Object.keys(current).every(key=>p.context[key]===current[key]),'Ce carnet est périmé : actualisez le plan de jeu.');
  check(available(),'Plan indisponible : mettez le match en pause et terminez sa transition.');
  check(['attack','defence','scrum','lineout','kickoff'].includes(p.key),'Rubrique du carnet inconnue.');
  const local=['attack','defence'].includes(p.key),table=p.key==='attack'?TACTICS:p.key==='defence'?DEFENCES:{scrum:SCRUM_MOVES,lineout:LINEOUT_MOVES,kickoff:KICKOFF_MOVES}[p.key];
  check(table&&typeof p.value==='string'&&(local&&p.value==='inherit'||Object.hasOwn(table,p.value)),'Choix tactique inconnu.');
  check(local?Object.hasOwn(FIELD_ZONES,p.zone):p.zone===undefined,'Zone du carnet inconnue.');
  if(command==='playbook_staff_zone'){
   check(local&&applyNumericalZoneAdvice(p.key,p.zone,p.value),'Ce conseil local ne correspond plus à la situation actuelle.');
  }else{
   const previous=playbookZone;
   try{if(local)playbookZone=p.zone;setPlaybookChoice(p.key,p.value);}finally{playbookZone=previous;}
  }
  const stored=local?S.manager.playbook.zones[p.zone][p.key]:S.manager.playbook[p.key];
  check(stored===p.value,'La consigne n’a pas pu être appliquée.');
  return {playbookDecision:{key:p.key,zone:p.zone??null,value:p.value}};
 }
 // The existing strict save validator owns manager.playbook/live.playbooks.
 return {project,execute,validate(){return true;},installHooks(){}};
}
module.exports={files:[],commands,factory};
