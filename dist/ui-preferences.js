'use strict';
// UI-01 — couche de présentation uniquement. Aucune modification de carrière ni RNG.
const UI01_THEME_KEY='cd-ui-theme-v1';
const UI01_ALLOWED_THEMES=['system','tribune','analyste'];
function ui01Storage(){
 try{return typeof localStorage!=='undefined'?localStorage:null}catch(_){return null}
}
function ui01ReadTheme(){
 try{
  const value=ui01Storage()?.getItem(UI01_THEME_KEY);
  return UI01_ALLOWED_THEMES.includes(value)?value:'system';
 }catch(_){return 'system'}
}
let ui01Pref=ui01ReadTheme();
let ui01Media=null;
try{if(typeof window!=='undefined'&&typeof window.matchMedia==='function')ui01Media=window.matchMedia('(prefers-color-scheme: dark)')}catch(_){}
function ui01ResolvedTheme(){
 return ui01Pref==='system'?(ui01Media?.matches?'analyste':'tribune'):ui01Pref;
}
function ui01ApplyTheme(){
 const el=typeof document!=='undefined'?document.documentElement:null;
 if(!el||typeof el.setAttribute!=='function')return;
 el.setAttribute('data-cd-theme',ui01ResolvedTheme());
 el.setAttribute('data-cd-theme-preference',ui01Pref);
}
function ui01SetTheme(value){
 if(!UI01_ALLOWED_THEMES.includes(value))return false;
 ui01Pref=value;
 try{ui01Storage()?.setItem(UI01_THEME_KEY,value)}catch(_){}
 ui01ApplyTheme();
 return true;
}
ui01ApplyTheme();
if(ui01Media){
 const onChange=()=>{if(ui01Pref==='system')ui01ApplyTheme()};
 if(typeof ui01Media.addEventListener==='function')ui01Media.addEventListener('change',onChange);
 else if(typeof ui01Media.addListener==='function')ui01Media.addListener(onChange);
}
function ui01Escape(value){
 return String(value).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;').replace(/'/g,'&#39;');
}
// Chaque route de l'ancienne navigation reste disponible dans les deux niveaux.
const UI01_GROUPS=[
 {id:'dashboard',label:'BUREAU',routes:['dashboard','help'],tabs:[['dashboard','Vue générale'],['help','Comment jouer']]},
 {id:'team',label:'EFFECTIF',routes:['team'],tabs:[['team','Joueurs','table'],['team','Feuille à 23','sheet'],['team','Couverture des postes','depth'],['team','Plan sur 3 saisons','planning']]},
 {id:'tactics',label:'TACTIQUES',routes:['tactics','plans','match'],tabs:[['tactics','Préparation'],['plans','Plan de jeu'],['match','Centre de match']]},
 {id:'recruitment',label:'RECRUTEMENT',routes:['recruitment','market','formation'],tabs:[['recruitment','Rapports'],['market','Mercato'],['formation','Formation']]},
 {id:'finance',label:'CLUB',routes:['finance','staff','saves'],tabs:[['finance','Finances'],['staff','Staff'],['saves','Sauvegardes']]},
 {id:'league',label:'COMPÉTITIONS',routes:['league','history'],tabs:[['league','Championnat'],['history','Palmarès & parcours']]}
];
function ui01Navigation(view,state,rank){
 const group=UI01_GROUPS.find(g=>g.routes.includes(view))||UI01_GROUPS[0];
 const club=state.clubs[state.club];
 const mainNav=UI01_GROUPS.map(g=>
  "<button type=\"button\" class=\"ui01-primary "+(g===group?'is-current':'')+
  "\" aria-current=\""+(g===group?'page':'false')+"\" onclick=\"nav('"+g.id+"')\">"+g.label+"</button>"
 ).join('');
 const subNav=group.tabs.map(([route,label,tab])=>{
  const active=route===view&&(!tab||(typeof squadTab!=='undefined'&&squadTab===tab));
  const action=tab?"squadTab='"+tab+"';nav('team')":"nav('"+route+"')";
  return "<button type=\"button\" class=\"ui01-secondary "+(active?'is-current':'')+
   "\" aria-current=\""+(active?'page':'false')+"\" onclick=\""+action+"\">"+label+"</button>";
 }).join('');
 const preferences=UI01_ALLOWED_THEMES.map((t,i)=>
  '<option value="'+t+'"'+(t===ui01Pref?' selected':'')+'>'+['Système','Tribune · Clair','Analyste · Sombre'][i]+'</option>'
 ).join('');
 return '<header class="ui01-appbar" aria-label="Navigation du jeu">'+
  '<div class="ui01-appbar-top"><div class="ui01-brand" aria-label="Cadrage Débordement">CD <span>CADRAGE<br>DÉBORDEMENT</span></div>'+
  '<nav class="ui01-primary-nav" aria-label="Rubriques principales">'+mainNav+'</nav>'+
  '<div class="ui01-utilities"><label for="ui01-theme">Thème</label><select id="ui01-theme" aria-label="Apparence du jeu" onchange="ui01SetTheme(this.value)">'+preferences+'</select>'+
  '<button type="button" class="ui01-help" onclick="nav(\'help\')" title="Comment jouer" aria-label="Comment jouer">?</button></div></div>'+
  '<div class="ui01-appbar-bottom"><nav class="ui01-secondary-nav" aria-label="Sous-rubriques">'+subNav+'</nav>'+
  '<div class="ui01-season"><strong>'+ui01Escape(club?.abbr||'CLUB')+'</strong><span>TOP 14 · Saison '+ui01Escape(state.season)+' · '+ui01Escape(rank)+'e</span>'+
  '<span class="ui01-save-state">'+(typeof lastSaveError!=='undefined'&&lastSaveError?'Sauvegarde en échec':'Sauvegarde auto')+'</span></div></div>'+
  '</header>';
}
