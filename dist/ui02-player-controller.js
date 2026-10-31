'use strict';
// UI-02C — interface de lecture : aucun changement au moteur ni au format de carrière.
const UI02_KEY='cd-ui02-columns-v1',UI02_PRESETS=['overview','contracts','fitness','development'];
function ui02LoadPreferences(){
 try{
  const raw=typeof localStorage!=='undefined'?localStorage.getItem(UI02_KEY):null;
  if(!raw)return {preset:'overview',columns:null};
  const p=JSON.parse(raw),preset=UI02_PRESETS.includes(p?.preset)?p.preset:'overview';
  return {preset,columns:p?.columns==null?null:CDUI02Data.chooseColumns(p.columns,preset)};
 }catch(_){return {preset:'overview',columns:null}}
}
const ui02Initial=ui02LoadPreferences();
let ui02Preset=ui02Initial.preset,ui02Columns=ui02Initial.columns,ui02Custom=!!ui02Columns,ui02StorageError=false;
let ui02ProfileId=null,ui02Tab='profil',ui02Query='',ui02Slot='all',ui02SortKey='note',ui02SortDirection='desc';
let ui02Compare=[null,null],ui02Club=null,ui02BoundRoot=null,ui02Release=null;
function ui02Esc(value){return CDUI02Components.escapeHTML(value)}
function ui02StorePreferences(){
 try{
  if(typeof localStorage==='undefined')throw Error('Storage denied');
  localStorage.setItem(UI02_KEY,JSON.stringify({preset:ui02Preset,columns:ui02Columns}));ui02StorageError=false;
 }catch(_){ui02StorageError=true}
}
function ui02Reconcile(){
 if(!S)return;
 if(ui02Club!==S.club){
  ui02Club=S.club;ui02ProfileId=null;ui02Tab='profil';ui02Compare=[null,null];ui02Slot='all';ui02Query='';
 }
 if(ui02ProfileId&&!club().players.some(p=>p.id===ui02ProfileId)){
  ui02ProfileId=null;if(squadTab==='profile')squadTab='table';
 }
 ui02Compare=ui02Compare.map(id=>id&&club().players.some(p=>p.id===id)?id:null);
}
function ui02Deps(){return {roleNote,potentialAtRole,skill,physicalLoadValue,attributes:ATTR}}
function ui02Ctx(){return {season:S.season,lineup:S.lineup,reserves:S.reserves}}
function ui02Focus(selector){
 try{
  const el=document.querySelector(selector);
  if(el&&typeof el.focus==='function'){
   if(el.tagName==='H2')el.setAttribute('tabindex','-1');
   el.focus();
  }
 }catch(_){}
}
function ui02ShowPlayer(id){
 if(!S||!club().players.some(p=>p.id===id))return false;
 ui02ProfileId=id;ui02Tab='profil';squadTab='profile';view='team';render();
 ui02Focus('.cd02-player-header h2');return true;
}
function ui02Back(){
 ui02ProfileId=null;squadTab='table';view='team';render();
 ui02Focus('.cd02-roster h2');
}
function ui02SetTab(tab){
 if(!Object.prototype.hasOwnProperty.call(CDUI02Components.TABS,tab))return false;
 ui02Tab=tab;render();ui02Focus('[data-cd02-tab="'+tab+'"]');return true;
}
function ui02SetPreset(preset){
 if(!UI02_PRESETS.includes(preset))return false;
 ui02Preset=preset;ui02Columns=null;ui02Custom=false;ui02StorePreferences();render();return true;
}
function ui02SetColumns(cols){
 try{ui02Columns=CDUI02Data.chooseColumns(cols,ui02Preset)}catch(_){return false}
 ui02Custom=true;ui02StorePreferences();render();return true;
}
function ui02Sort(key){
 if(!Object.prototype.hasOwnProperty.call(CDUI02Data.LABELS,key))return false;
 if(ui02SortKey===key)ui02SortDirection=ui02SortDirection==='asc'?'desc':'asc';
 else{ui02SortKey=key;ui02SortDirection=key==='name'?'asc':'desc'}
 render();return true;
}
function ui02Search(value){
 ui02Query=String(value??'').slice(0,120);
 let start=null,end=null;
 try{
  const el=document.activeElement;
  if(el?.getAttribute?.('data-cd02-action')==='search'){start=el.selectionStart;end=el.selectionEnd}
 }catch(_){}
 render();ui02Focus('input[data-cd02-action="search"]');
 try{
  const el=document.querySelector('input[data-cd02-action="search"]');
  if(Number.isInteger(start)&&Number.isInteger(end)&&el?.setSelectionRange)el.setSelectionRange(start,end);
 }catch(_){}
}
function ui02SetSlot(value){
 if(value!=='all'&&!/^(?:[0-9]|1[0-4])$/.test(String(value)))return false;
 ui02Slot=String(value);render();return true;
}
function ui02SelectCompare(index,id){
 if(![0,1].includes(index)||id!==''&&!club().players.some(p=>p.id===id))return false;
 ui02Compare[index]=id||null;
 if(id&&ui02Compare[1-index]===id)ui02Compare[1-index]=null;
 render();return true;
}
function ui02Bind(){
 const root=typeof document!=='undefined'?document.querySelector('#app'):null;
 if(!root||typeof root.addEventListener!=='function')return;
 if(ui02BoundRoot===root)return;
 if(ui02Release)ui02Release();
 const releaseComponents=CDUI02Components.bindActions(root,{
  onTab:ui02SetTab,onSort:ui02Sort,onPlayer:ui02ShowPlayer,onPreset:ui02SetPreset,
  onColumns:ui02SetColumns,onSearch:ui02Search
 });
 const change=e=>{
  const el=e.target;
  if(!el||!root.contains(el))return;
  if(el.matches?.('[data-ui02-slot]'))ui02SetSlot(el.value);
  else if(el.matches?.('[data-ui02-compare]'))ui02SelectCompare(Number(el.getAttribute('data-ui02-compare')),el.value);
  else if(el.matches?.('[data-ui02-training]')){
   const id=el.getAttribute('data-ui02-training');
   if(club().players.some(p=>p.id===id))setPhysicalTraining(id,el.value);
  }
 };
 const click=e=>{
  const el=e.target?.closest?.('[data-ui02-back],[data-ui02-native],[data-ui02-clear]');
  if(!el||!root.contains(el))return;
  if(el.hasAttribute('data-ui02-back'))ui02Back();
  if(el.hasAttribute('data-ui02-native')){
   const id=el.getAttribute('data-ui02-native');
   if(club().players.some(p=>p.id===id))inspectCareerPlayer(id);
  }
  if(el.hasAttribute('data-ui02-clear')){ui02Compare=[null,null];render()}
 };
 const keyboard=e=>{
  const el=e.target;
  if(!el?.matches?.('[data-cd02-action="tab"]'))return;
  const tabs=Object.keys(CDUI02Components.TABS),i=tabs.indexOf(el.getAttribute('data-cd02-tab'));
  if(i<0)return;
  const dest=e.key==='ArrowRight'?(i+1)%tabs.length:e.key==='ArrowLeft'?(i+tabs.length-1)%tabs.length:e.key==='Home'?0:e.key==='End'?tabs.length-1:-1;
  if(dest<0)return;
  e.preventDefault();ui02SetTab(tabs[dest]);
 };
 root.addEventListener('change',change);root.addEventListener('click',click);root.addEventListener('keydown',keyboard);
 ui02BoundRoot=root;
 ui02Release=()=>{
  releaseComponents();root.removeEventListener('change',change);root.removeEventListener('click',click);root.removeEventListener('keydown',keyboard)
 };
}
function ui02Options(selected,excluded){
 return '<option value="">Choisir un joueur</option>'+club().players.map(p=>
  '<option value="'+ui02Esc(p.id)+'"'+(p.id===selected?' selected':'')+(p.id===excluded?' disabled':'')+'>'+
  ui02Esc(p.name+' · '+p.pos)+'</option>').join('');
}
function ui02ComparePanel(){
 const choices='<section class="cd02-selectors" aria-label="Comparer deux joueurs"><h3>Comparer deux joueurs</h3>'+
  '<div class="cd02-selectors-grid">'+[0,1].map(i=>
   '<label>Joueur '+(i+1)+'<select data-ui02-compare="'+i+'" aria-label="Joueur '+(i+1)+' à comparer">'+
   ui02Options(ui02Compare[i],ui02Compare[1-i])+'</select></label>').join('')+
  '<button type="button" data-ui02-clear>Effacer la comparaison</button></div></section>';
 if(!ui02Compare[0]||!ui02Compare[1])return choices;
 const ps=ui02Compare.map(id=>player(id));
 return ps.every(Boolean)?choices+CDUI02Components.renderComparison(CDUI02Data.comparePlayers(ps,ui02Deps(),ui02Ctx())):choices;
}
function ui02TrainingPanel(){
 const locked=!!(S.live||S.trained||S.phase==='ended');
 const names=Object.entries(PHYSICAL_PLANS);
 return '<details class="cd02-training"><summary>Gestion des charges individuelles et entraînement</summary>'+
  '<p class="cd02-help">Les plans utilisent les commandes et calculs natifs du jeu.</p>'+
  '<div class="cd02-table-scroll"><table class="cd02-table"><thead><tr>'+
  '<th scope="col">Joueur</th><th scope="col">Condition</th><th scope="col">Charge</th><th scope="col">Plan</th><th scope="col">Prochaine séance</th>'+
  '</tr></thead><tbody>'+club().players.map(p=>'<tr><th scope="row">'+ui02Esc(p.name)+'</th>'+
   '<td>'+Math.round(p.condition)+' %</td><td>'+physicalLoadValue(p)+'/100</td><td>'+
   '<select data-ui02-training="'+ui02Esc(p.id)+'" aria-label="Charge de '+ui02Esc(p.name)+'"'+(locked?' disabled':'')+'>'+
   names.map(([k,label])=>'<option value="'+k+'"'+(physicalPlan(p)===k?' selected':'')+'>'+ui02Esc(label)+'</option>').join('')+
   '</select></td><td>'+ui02Esc(physicalLoadPreviewText(p))+'</td></tr>').join('')+
  '</tbody></table></div></details>';
}
function ui02TeamView(){
 if(!S)return '';
 ui02Reconcile();ui02Bind();
 if(squadTab==='profile'){
  const p=ui02ProfileId?player(ui02ProfileId):null;
  if(!p)return '<div class="cd02-return"><button type="button" data-ui02-back>← Retour à l’effectif</button></div>';
  return '<div class="cd02-return"><button type="button" data-ui02-back>← Retour à l’effectif</button>'+
   '<button type="button" data-ui02-native="'+ui02Esc(p.id)+'">Développement et gestion détaillée ↗</button></div>'+
   CDUI02Components.renderPlayer(CDUI02Data.playerView(p,ui02Deps(),ui02Ctx()),{tab:ui02Tab});
 }
 const filtered=ui02Slot==='all'?club().players:club().players.filter(p=>slotEligible(p,Number(ui02Slot)));
 const table=CDUI02Data.tableView(filtered,ui02Deps(),ui02Ctx(),{
  preset:ui02Preset,columns:ui02Columns??undefined,
  search:ui02Query,sortBy:ui02SortKey,direction:ui02SortDirection
 });
 const filter='<div class="cd02-filters"><label>Poste<select data-ui02-slot aria-label="Filtrer par poste">'+
  '<option value="all">Tous les postes</option>'+POS.map((pos,i)=>
   '<option value="'+i+'"'+(ui02Slot===String(i)?' selected':'')+'>'+(i+1)+' · '+ui02Esc(pos)+'</option>').join('')+
  '</select></label><span class="cd02-help">Choisissez un joueur pour ouvrir sa fiche.</span></div>';
 return '<div class="cd02-roster-stack">'+filter+
  CDUI02Components.renderTable(table,{preset:ui02Preset,search:ui02Query})+
  (ui02Custom?'<p class="cd02-help">Colonnes personnalisées</p>':'')+
  (ui02StorageError?'<p class="cd02-prefs-error" role="status">Préférences de colonnes non enregistrées sur cet appareil.</p>':'')+
  ui02ComparePanel()+ui02TrainingPanel()+'</div>';
}
