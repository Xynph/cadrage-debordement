'use strict';
// LNR-01 : mode de nouvelle carrière facultatif. Aucun état fictif préexistant modifié.
let lnrWelcomeMode='fiction',lnrBrowseIndex=0;
const LNR_NAMES={
 'clermont':['ASM Clermont Auvergne','ASM'],'bayonne':['Aviron Bayonnais','AB'],
 'castres':['Castres Olympique','CO'],'lyon':['LOU Rugby','LOU'],
 'montpellier':['Montpellier Hérault Rugby','MHR'],'toulon':['RC Toulon','RCT'],
 'vannes':['RC Vannes','RCV'],'racing-92':['Racing 92','R92'],
 'pau':['Section Paloise','SP'],'paris':['Stade Français Paris','SFP'],
 'la-rochelle':['Stade Rochelais','SR'],'toulouse':['Stade Toulousain','ST'],
 'perpignan':['USA Perpignan','USAP'],'bordeaux-begles':['Union Bordeaux-Bègles','UBB']
};
const LNR_TOP14=LNR_CATALOGUE.clubs.filter(c=>c[1]==='top14');
const LNR_PROD2=LNR_CATALOGUE.clubs.filter(c=>c[1]==='prod2');
function lnrGameClub(i){
 const source=LNR_TOP14[i];if(!source)return null;
 const title=LNR_NAMES[source[0]]||[source[0].replaceAll('-',' '),source[0].slice(0,3).toUpperCase()];
 return {name:title[0],abbr:title[1],slug:source[0],source:source[2],players:source[3]};
}
function lnrCareerMode(s){return !!s&&s.lnrMode?.version===1&&s.lnrMode.snapshot==='2026-10-31'&&s.lnrMode.scope==='top14'&&s.lnrMode.simulated===true;}
function lnrAssignment(group,index){
 // Une famille précise est NÉCESSAIRE au moteur mais non attestée par les groupes LNR.
 // Attribution de rôle déterministe, explicitement simulée, sans affirmation de poste exact.
 if(group==='1ère ligne')return [0,1,2][index%3];
 if(group==='2ème ligne')return 3;
 if(group==='3ème ligne')return 5;
 if(group==='Demi de mêlée')return 8;
 if(group==="Demi d'ouverture")return 9;
 if(group==='Ailier')return 10;
 if(group==='Centre')return 11;
 if(group==='Arrière')return 14;
 return 13;
}
function lnrBirthAge(lnrId){
 const birth=typeof LNR_BIRTHYEARS_DATA!=='undefined'&&LNR_BIRTHYEARS_DATA.byId[lnrId];
 if(typeof birth==='number'&&Number.isInteger(birth))return {age:2026-birth-1,birthYear:birth,ageEstimated:true};
 if(typeof birth==='string'&&/^\d{4}-\d{2}-\d{2}$/.test(birth)){
  const [year,month,day]=birth.split('-').map(Number);
  return {age:2026-year-(month>7||month===7&&day>1?1:0),birthYear:year,birthDate:birth,ageEstimated:false};
 }
 throw Error('Année LNR introuvable pour '+lnrId);
}
function lnrGamePlayers(i,base){
 const origin=lnrGameClub(i);if(!origin)throw Error('Club LNR inconnu');
 const groups=Object.create(null);
 return origin.players.map(([id,name,group,nationality],index)=>{
  const order=groups[group]||0;groups[group]=order+1;
  const position=lnrAssignment(group,order),family=FAMILIES[position];
  // Évaluation, âge, salaire et condition = PARAMÈTRES DE JEU SIMULÉS.
  const birthday=typeof LNR_BIRTHYEARS_DATA==='undefined'?{age:21+(seedHash(id)%14),ageEstimated:true}:lnrBirthAge(id);
  const seed=seedHash(id);const rating=clamp(base+(seed%15)-8,48,92);
  return ensureSkills({id,name,pos:POS[position],fam:family,
   ...birthday,rating,condition:90+(seed%11),injury:0,
   salary:3500+(seed%18)*330,lnrGroup:group,lnrNationality:nationality||null});
 });
}
function lnrChooseMode(mode){
 if(S||!['fiction','lnr'].includes(mode))return false;
 lnrWelcomeMode=mode;render();return true;
}
function lnrWelcomeToggle(){
 return '<section class="lnr-choice" aria-label="Type de nouvelle carrière">'+
  '<h2>Choisir votre univers</h2><div class="lnr-mode-buttons" role="group" aria-label="Mode de carrière">'+
  '<button type="button" aria-pressed="'+(lnrWelcomeMode==='fiction')+'" onclick="lnrChooseMode(\'fiction\')">Univers fictif classique</button>'+
  '<button type="button" aria-pressed="'+(lnrWelcomeMode==='lnr')+'" onclick="lnrChooseMode(\'lnr\')">Effectifs LNR · 31/10/2026</button></div>'+
  '<p class="help">'+(lnrWelcomeMode==='lnr'?
  'Mode optionnel : 14 clubs du catalogue TOP 14, joueurs et groupes de postes issus des pages LNR au 31/10/2026. Postes précis, notes, contrats, salaires, trésoreries, calendrier et résultats sont SIMULÉS. Âges calculés à partir des années de naissance disponibles : lorsque seul le millésime est connu, l’âge retenu au 01/07/2026 est conservateur et estimé. Pas de reconstitution des effectifs au 01/07/2026. Les 16 clubs PRO D2 restent consultables, non jouables dans cette ligue à 14.':
  'Carrière fictive historique inchangée : clubs, joueurs, contrats et résultats inventés pour le jeu.')+
  '</p></section>';
}
function lnrWelcomeClubs(){
 return lnrWelcomeMode==='lnr'?LNR_TOP14.map((_,i)=>{
  const d=lnrGameClub(i),c=CLUBS[i];return [d.name,d.abbr,c[2],c[3],c[4],c[5]];
 }):CLUBS;
}
function lnrBrowseClub(value){
 const idx=Number(value);if(!Number.isInteger(idx)||idx<0||idx>=LNR_CATALOGUE.clubs.length)return;
 lnrBrowseIndex=idx;render();
}
function lnrEscape(value){
 return String(value).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
}
function lnrCatalogueView(){
 if(!S||!lnrCareerMode(S))return '';
 const opts=LNR_CATALOGUE.clubs.map((c,i)=>'<option value="'+i+'"'+(i===lnrBrowseIndex?' selected':'')+'>'+
  lnrEscape((c[1]==='top14'?'TOP 14':'PRO D2')+' · '+(LNR_NAMES[c[0]]?.[0]||c[0]))+'</option>').join('');
 const c=LNR_CATALOGUE.clubs[lnrBrowseIndex];
 const rows=c[3].map(p=>{const born=typeof LNR_BIRTHYEARS_DATA==='undefined'?null:lnrBirthAge(p[0]);return '<tr><td>'+lnrEscape(p[1])+'</td><td>'+lnrEscape(p[2])+
  '</td><td>'+lnrEscape(p[3]||'Non renseignée')+'</td><td>'+(born?born.age+(born.ageEstimated?' (estimé)':''):'Non disponible')+'</td></tr>';}).join('');
 return '<section class="card lnr-catalogue" aria-label="Catalogue officiel LNR">'+
  '<div class="cardtitle"><h2>Catalogue LNR · 30 clubs</h2><span class="tag">SNAPSHOT 31/10/2026</span></div>'+
  '<p class="help">1 592 joueurs recensés au 31 octobre 2026 ; 14 clubs TOP 14 dans cette carrière, 16 clubs PRO D2 en lecture seule. Les postes précis, capacités, contrats et finances de la simulation ne sont pas des données officielles. Aucune certitude sur le 01/07/2026.</p>'+
  '<label for="lnr-club">Consulter un club</label><select id="lnr-club" onchange="lnrBrowseClub(this.value)">'+opts+'</select>'+
  '<p><a href="'+lnrEscape(c[2])+'" target="_blank" rel="noopener noreferrer">Source officielle : effectif et staff LNR</a></p>'+
  '<p class="help">Âges au 01/07/2026 ; les âges déduits de la seule année de naissance sont conservateurs et estimés.</p>'+ 
  '<div class="lnr-scroll"><table><thead><tr><th>Joueur</th><th>Groupe de poste LNR</th><th>Nationalité LNR</th><th>Âge au 01/07/2026</th></tr></thead>'+
  '<tbody>'+rows+'</tbody></table></div></section>';
}
