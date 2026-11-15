'use strict';
// Feuille de statistiques d'un match (demande de Léo, 13 novembre 2026 : « il faut que les stats
// ressemblent plus à des vraies stats »). Références réelles et calibrage :
// docs/stats-match-realistes-20261113.md.
//
// Le journal du moteur (~200 faits par match) ne raconte qu'une trentaine de courses : un ailier y
// faisait 0 ou 1 plaquage. Cette couche produit, à partir du journal, une feuille par joueur et par
// équipe comparable à une feuille Opta :
//  - les faits du journal sont la vérité : essais, transformations, pénalités tentées, courses
//    racontées et leurs mètres, franchissements (course de 22 m ou plus, comme `longGains`), plaqueur
//    nommé (`tackler`), ballons récupérés, touches, en-avant, pénalités concédées, cartons ;
//  - les actions non racontées (plaquages de routine, courses courtes, passes, soutiens au ruck,
//    jeu au pied courant) sont réparties minute par minute selon le poste, les minutes jouées, la
//    possession et l'occupation de la minute, les plans de jeu (attaque/défense) et les attributs
//    des joueurs (plaquage, puissance, vitesse, passe, jeu au pied, discipline, endurance).
//
// Lecture pure, DÉTERMINISTE : le tirage vient d'une graine dérivée de la clé de la rencontre et du
// premier fait du journal, minute par minute (jamais le générateur du moteur de match) ; le match
// simulé ne change pas. Propriété de préfixe : la feuille d'un journal borné (entracte) ne compte que
// les minutes terminées et les faits montrés ; la feuille du journal complet est la feuille finale.
// Une minute n'est comptée qu'une fois close (premier fait d'une minute suivante, ou fin du match).

// Tout le module tient dans `fabrique()` : Node l'appelle une fois (exports ci-dessous) et la VM du
// moteur l'installe telle quelle (`CDMatchStats`, native-systems.cjs) pour enregistrer, à la fin de
// chaque match noté, la même feuille que l'écran de match (match-notes.cjs).
function fabrique(){
 const VERSION=1;
 // Postes 1 à 15 (index 0 à 14 de la feuille `on` du moteur).
 const LIBELLES_POSTES=Object.freeze(['Pilier gauche','Talonneur','Pilier droit','Deuxième ligne','Deuxième ligne','Troisième ligne','Troisième ligne','Numéro 8','Demi de mêlée','Demi d’ouverture','Ailier','Centre','Centre','Ailier','Arrière']);
 // Poids par poste, proportionnels aux références par 80 minutes (tableau de la doc) :
 // plaquages, courses, mètres par course, passes (hors passe du demi de mêlée au ruck), soutiens au
 // ruck, jeu au pied, fautes (pénalités) et en-avant.
 const POIDS=Object.freeze({
  plaquages:[7.5,10,7.5,11,11,15,15,12,6,7,5.2,9,9,5.2,5.5],
  courses:  [7,7,7,8,8,9,9,12,4,6,8,9,9,8,9],
  metres:   [.9,1,.9,1.1,1.1,1.2,1.2,1.5,2.2,2.2,4.6,3,3,4.6,4.4],
  passes:   [2.5,3.5,2.5,3,3,3.5,3.5,4.5,0,30,4,7,7,4,7],
  rucks:    [15,14,15,16,16,13,13,11,1,1.5,2,4,4,2,2],
  pieds:    [0,0,0,0,0,0,0,0,7,10,1,1,0.3,1,4],
  fautes:   [1.6,1.2,1.6,1.3,1.3,1.5,1.5,1.2,.7,.5,.4,.7,.7,.4,.4],
  cassure:  [.3,.3,.3,.4,.4,.7,.7,1,.4,1,1.8,1.6,1.6,1.8,1.8],
  enAvant:  [.6,.6,.6,.7,.7,.8,.8,.9,.6,.8,1.1,1.1,1.1,1.1,1],
  offloads: [.4,.5,.4,.7,.7,.9,.9,1,.2,.6,1.2,1.4,1.4,1.2,1.1]
 });
 // Calibrage (validé sur 120 matchs : tests/match-stats-realistes.cjs, tableau de la doc).
 const REGLAGES=Object.freeze({
  coursesParMinute:2.95,     // courses non racontées des deux équipes par minute pleinement jouée
  piedsParMinute:.62,        // coups de pied courants des deux équipes par minute
  cassure:.036,            // part des courses non racontées qui percent la ligne (franchissement, 22 à 40 m)
  gain:.8,                 // échelle des mètres d'une course ordinaire
  manque:.13,               // part des courses avec un plaquage manqué (défense équilibrée)
  aide:.2,                   // second plaqueur (plaquage à deux)
  passeDuDemi:.58,           // course servie par le demi de mêlée
  passesEnPlus:.8,           // autres passes par course (jeu équilibré)
  offload:.07,
  soutiens:1.9,              // soutiens au ruck par ruck
  ruck:.74,                  // course qui finit en ruck (sinon maul, ballon porté au sol rejoué, jeu au pied)
  arret:.12                  // part de minute perdue par arrêt de jeu (mêlée, touche, pénalité…)
 });
 const STYLES_ATTAQUE=Object.freeze({
  equilibre:{courses:1,passes:1,pieds:1,offload:1,gain:1},
  large:{courses:.97,passes:1.3,pieds:.85,offload:1.4,gain:1.12},
  conquete:{courses:1.1,passes:.8,pieds:.9,offload:.75,gain:.88},
  occupation:{courses:.82,passes:.9,pieds:1.7,offload:.9,gain:1}
 });
 const STYLES_DEFENSE=Object.freeze({equilibre:{manque:1,gain:1},pression:{manque:1.18,gain:.92},prudente:{manque:.85,gain:1.1}});
 const ARRETS=new Set(['scrum','lineout','penalty','kickoff','try','goal','miss','card','sub','break','touch','drop22','goalLine']);
 const NEUTRES=new Set(['message','card','sub','tactic','break','end','advantage']);
 const CHAMPS_JOUEUR=Object.freeze(['minutes','essais','points','transformations','transformationsTentees','penalitesReussies','penalitesTentees',
  'courses','metres','franchissements','defenseursBattus','offloads','passes','plaquages','plaquagesManques','soutiensRuck','recuperations','conquetesVolees',
  'ballonsPerdus','enAvant','penalitesConcedees','touchesGagnees','touchesVolees','lancers','coupsDePied','metresAuPied','cartonsJaunes','cartonsRouges']);

 // --- Tirage déterministe -------------------------------------------------------------------
 function empreinte(texte){let h=0x811c9dc5;for(let i=0;i<texte.length;i++){h^=texte.charCodeAt(i);h=Math.imul(h,0x01000193)>>>0}return h>>>0}
 function tirage(graine){let a=graine>>>0;return ()=>{a=a+0x6D2B79F5>>>0;let t=a;t=Math.imul(t^t>>>15,t|1);t^=t+Math.imul(t^t>>>7,t|61);return ((t^t>>>14)>>>0)/4294967296}}
 const tirageDe=(base,...cles)=>tirage(empreinte(base+'|'+cles.join('|')));
 // Poisson (Knuth) : nombre d'actions d'une minute autour de son espérance.
 function poisson(lambda,r){if(!(lambda>0))return 0;const L=Math.exp(-lambda);let k=0,p=1;do{k++;p*=r()}while(p>L&&k<60);return k-1}
 function gauss(r){const u=Math.max(1e-9,r()),v=r();return Math.sqrt(-2*Math.log(u))*Math.cos(2*Math.PI*v)}
 function choisir(candidats,poids,r){
  let total=0;const w=candidats.map(c=>{const x=Math.max(0,poids(c));total+=x;return x});
  if(!(total>0))return candidats.length?candidats[Math.floor(r()*candidats.length)]:null;
  let cible=r()*total;for(let i=0;i<candidats.length;i++){cible-=w[i];if(cible<=0)return candidats[i]}
  return candidats[candidats.length-1];
 }

 // Attributs : `options.joueurs[id] = {skills:{tackle,power,speed,pass,kick,discipline,stamina}}` (ou
 // les clés directement). Absents : joueur moyen (70).
 function attribut(info,cle){const s=info?.skills||info||{},v=Number(s[cle]);return Number.isFinite(v)?Math.max(20,Math.min(99,v)):70}

 function vide(){const o={};for(const c of CHAMPS_JOUEUR)o[c]=0;return o}

 /**
  * Feuille de statistiques d'un match, par joueur et par équipe.
  * @param {Array} journal  Faits du moteur (`live.events`) : `{min, type, text, scene:{kind, team, actor, tackler, on, from, to, …}}`.
  * @param {Object} [options]
  * @param {string} [options.cle]    Identifiant stable de la rencontre (saison:journée:phase:paire) ; avec le premier fait du
  *                                  journal, il forme la graine. Même clé + même journal = même feuille.
  * @param {number} [options.borne]  Nombre de faits lus (entracte : ce qui a été montré). Par défaut tout le journal.
  * @param {Object} [options.joueurs] Attributs par identifiant (voir `attribut`) ; facultatif.
  * @returns {{version:number,cle:string,minute:number,fini:boolean,faits:number,equipes:Array<Object>,joueurs:Object<string,Object>}}
  *   `joueurs[id]` : camp (0/1), numero (1-15, poste de sa première entrée), poste (libellé), minutes, essais, points,
  *   transformations(Tentees), penalitesReussies/Tentees, courses, metres, franchissements, defenseursBattus, offloads,
  *   passes, plaquages, plaquagesManques, soutiensRuck, recuperations (turnovers), conquetesVolees, ballonsPerdus, enAvant, penalitesConcedees,
  *   touchesGagnees, touchesVolees, lancers, coupsDePied, metresAuPied, cartonsJaunes, cartonsRouges.
  *   `equipes[s]` : la somme de ces champs sur les joueurs du camp, plus rucks (rucks joués), touches {lancers, gagnees},
  *   melees {introductions, gagnees}, reussitePlaquage (%), possession (part des faits joués, %).
  */
 function feuilleStatistiques(journal,options={}){
  const events=Array.isArray(journal)?journal:[];
  const n=Math.max(0,Math.min(events.length,Number.isInteger(options.borne)?options.borne:events.length));
  const premier=events.find(e=>e?.scene)||events[0]||{};
  const base=String(options.cle||'')+'#'+empreinte(String(premier.text||'')+'|'+JSON.stringify(premier.scene?.on||[]));
  const infos=options.joueurs&&typeof options.joueurs==='object'?options.joueurs:{};
  const joueurs={},equipes=[0,1].map(()=>({rucks:0,touches:{lancers:0,gagnees:0},melees:{introductions:0,gagnees:0},faitsPossession:0}));
  let on=[[],[]],possession=0,territoire=50,derniereMinute=null,fini=false;
  const exclus=new Map(); // id → minute de retour (Infinity : rouge)
  const fiche=(id,camp,poste)=>{
   const k=String(id);let j=joueurs[k];
   if(!j){j=joueurs[k]={camp,numero:poste+1,poste:LIBELLES_POSTES[poste]||'',...vide()};
    const r=tirageDe(base,'forme',k);j._forme=Math.exp(.24*gauss(r));}
   return j;
  };
  const presents=(camp,minute)=>{
   const liste=[];
   (on[camp]||[]).forEach((id,poste)=>{if(id==null||poste>14)return;const retour=exclus.get(String(id));if(retour!==undefined&&minute<retour)return;liste.push({id:String(id),poste,j:fiche(id,camp,poste)})});
   return liste;
  };
  // Attributs normalisés (20-99, défaut 70) mémorisés par joueur : les poids de tirage les relisent des centaines de fois par match.
  const cacheAtt={};
  const attr=(id,cle)=>{const o=cacheAtt[id]||(cacheAtt[id]={});const v=o[cle];return v!==undefined?v:(o[cle]=attribut(infos[id],cle))};
  const fatigue=(c,minute)=>minute>50?.78+.22*attr(c.id,'stamina')/100:1;
  const poidsPlaquage=minute=>c=>POIDS.plaquages[c.poste]*c.j._forme*(.55+.8*attr(c.id,'tackle')/100)*fatigue(c,minute);
  const poidsCourse=minute=>c=>POIDS.courses[c.poste]*c.j._forme*(.6+.7*attr(c.id,c.poste<8?'power':'speed')/100)*fatigue(c,minute);
  const camps=(s)=>[s,1-s];
  // Faits de la minute en cours (pour la répartition de la minute quand elle se ferme).
  let minute={faits:0,tenus:[0,0],arrets:0,courses:[0,0],x:[]};
  const nouvelleMinute=()=>({faits:0,tenus:[0,0],arrets:0,courses:[0,0],x:[]});

  // Routine d'une minute close : courses, plaquages, passes, rucks, jeu au pied.
  function routine(m){
   const r=tirageDe(base,'minute',m);
   const totalTenus=minute.tenus[0]+minute.tenus[1];
   const parts=totalTenus?minute.tenus.map(t=>t/totalTenus):[possession===0?1:0,possession===1?1:0];
   const jeu=Math.max(.3,1-REGLAGES.arret*minute.arrets);
   const x=minute.x.length?minute.x.reduce((a,b)=>a+b,0)/minute.x.length:territoire;
   for(const s of [0,1]){
    const att=presents(s,m),def=presents(1-s,m);
    if(!att.length||!def.length||!(parts[s]>0))continue;
    const plans=minute.plans||{},style=STYLES_ATTAQUE[plans.attack?.[s]]||STYLES_ATTAQUE.equilibre,defense=STYLES_DEFENSE[plans.defence?.[1-s]]||STYLES_DEFENSE.equilibre;
    const attendu=Math.max(0,REGLAGES.coursesParMinute*parts[s]*jeu*style.courses-.5*minute.courses[s]);
    const nombre=poisson(attendu,r);
    const plaquageMoyen=def.reduce((a,c)=>a+attr(c.id,'tackle'),0)/def.length;
    const pManque=REGLAGES.manque*defense.manque*(1.25-.35*plaquageMoyen/100);
    const demi=att.find(c=>c.poste===8);
    for(let k=0;k<nombre;k++){
     let porteur=choisir(att,poidsCourse(m),r);
     let gain=REGLAGES.gain*POIDS.metres[porteur.poste]*(.2+1.6*r())*style.gain*defense.gain;
     const cassure=r()<REGLAGES.cassure*POIDS.cassure[porteur.poste]*(.6+.8*attr(porteur.id,'speed')/100)*style.gain*defense.gain;
     if(cassure){gain=22+r()*16;porteur.j.franchissements++}
     if(cassure||r()<pManque){
      const rate=choisir(def,c=>POIDS.plaquages[c.poste]*(1.65-attr(c.id,'tackle')/100)*(c.poste>=10?1.3:1),r);
      rate.j.plaquagesManques++;porteur.j.defenseursBattus++;if(!cassure)gain+=1+r()*5;
     }
     if(demi&&porteur!==demi&&r()<REGLAGES.passeDuDemi)demi.j.passes++;
     const autres=poisson(REGLAGES.passesEnPlus*style.passes,r);
     for(let p=0;p<autres;p++){const passeur=choisir(att,c=>POIDS.passes[c.poste]*(.6+.8*attr(c.id,'pass')/100),r);passeur.j.passes++}
     porteur.j.courses++;porteur.j.metres+=cassure?gain:Math.min(19,gain);
     if(r()<REGLAGES.offload*style.offload*POIDS.offloads[porteur.poste]){
      porteur.j.offloads++;porteur.j.passes++;
      const soutien=choisir(att.filter(c=>c!==porteur),poidsCourse(m),r);
      if(soutien){soutien.j.courses++;soutien.j.metres+=1+r()*4*style.gain;porteur=soutien}
     }
     const plaqueur=choisir(def,poidsPlaquage(m),r);plaqueur.j.plaquages++;
     if(r()<REGLAGES.aide){const second=choisir(def.filter(c=>c!==plaqueur),poidsPlaquage(m),r);if(second)second.j.plaquages++}
     const ruck=r()<REGLAGES.ruck;if(!ruck)continue;
     equipes[s].rucks++;
     const soutiens=Math.max(1,Math.round(REGLAGES.soutiens+(r()-.5)*1.4));
     const libres=att.filter(c=>c!==porteur);
     for(let a=0;a<soutiens&&libres.length;a++){const c=choisir(libres,c=>POIDS.rucks[c.poste]*c.j._forme*fatigue(c,m),r);c.j.soutiensRuck++;libres.splice(libres.indexOf(c),1)}
    }
    // Jeu au pied courant : plus fréquent depuis son propre camp.
    const camp=s===0?x:100-x;
    const pieds=poisson(REGLAGES.piedsParMinute*parts[s]*jeu*style.pieds*(camp<40?1.55:camp<60?.95:.45),r);
    for(let k=0;k<pieds;k++){const buteur=choisir(att,c=>POIDS.pieds[c.poste]*(.5+attr(c.id,'kick')/100),r);if(!buteur)break;buteur.j.coupsDePied++;buteur.j.metresAuPied+=18+r()*30}
   }
   for(const s of [0,1])for(const c of presents(s,m))c.j.minutes++;
  }

  const fermer=jusqua=>{
   // Ferme les minutes [derniereMinute, jusqua) : la première avec ses faits, les suivantes sans fait.
   if(derniereMinute===null)return;
   for(let m=derniereMinute;m<jusqua;m++){routine(m);const plans=minute.plans;minute=nouvelleMinute();minute.plans=plans}
   derniereMinute=jusqua;
  };
  const dernierPorteur=[null,null];let dernierePenalite=null,derniereMiseEnPlace=null,buteur=[null,null];
  for(let i=0;i<n;i++){
   const e=events[i]||{},s=e.scene,min=Number.isFinite(e.min)?e.min:(derniereMinute??0);
   if(derniereMinute===null)derniereMinute=min;
   else if(min>derniereMinute)fermer(min);
   if(!s){continue}
   if(Array.isArray(s.on)&&s.on.length===2)on=s.on.map(x=>Array.isArray(x)?x.slice():[]);
   if(s.plans)minute.plans=s.plans;
   const kind=s.kind,team=s.team===0||s.team===1?s.team:null;
   if(kind==='end'){fini=true;continue}
   if(!NEUTRES.has(kind)){
    minute.faits++;if(s.possession===0||s.possession===1){minute.tenus[s.possession]++;equipes[s.possession].faitsPossession++;possession=s.possession}
    if(Number.isFinite(s.to?.x)){minute.x.push(s.to.x);territoire=s.to.x}
   }
   if(ARRETS.has(kind))minute.arrets++;
   // Acteur du fait : sur le terrain, sinon dans la feuille du moment (exclu temporaire), sinon déjà
   // connu de ce camp (un joueur exclu disparaît de `on` dans le fait de son carton).
   const connu=id=>{const j=joueurs[id];return j&&j.camp===team?{id,poste:j.numero-1,j}:null};
   const acteur=s.actor!=null&&team!==null?presents(team,min).find(c=>c.id===String(s.actor))||((on[team]||[]).map(String).includes(String(s.actor))?{id:String(s.actor),poste:on[team].map(String).indexOf(String(s.actor)),j:fiche(s.actor,team,on[team].map(String).indexOf(String(s.actor)))}:connu(String(s.actor))):null;
   const r=tirageDe(base,'fait',i);
   if(kind==='carry'&&team!==null){
    const gain=Number.isFinite(s.from?.x)&&Number.isFinite(s.to?.x)?Math.abs(s.to.x-s.from.x):0;
    minute.courses[team]++;
    const def=presents(1-team,min);
    if(acteur){acteur.j.courses++;acteur.j.metres+=gain;dernierPorteur[team]=acteur}
    const demi=presents(team,min).find(c=>c.poste===8);if(demi&&acteur&&demi!==acteur&&r()<REGLAGES.passeDuDemi)demi.j.passes++;
    if(gain>=22){
     if(acteur){acteur.j.franchissements++;acteur.j.defenseursBattus++}
     const rate=def.length?choisir(def,c=>POIDS.plaquages[c.poste]*(c.poste>=10?2:1),r):null;if(rate)rate.j.plaquagesManques++;
    }else if(def.length){
     const nomme=s.tackler!=null?def.find(c=>c.id===String(s.tackler)):null;
     (nomme||choisir(def,poidsPlaquage(min),r)).j.plaquages++;
     equipes[team].rucks++;
    }
    continue;
   }
   if(kind==='try'&&team!==null){
    if(acteur){acteur.j.essais++;acteur.j.points+=5;
     // Essai en jeu courant sans franchissement juste avant : le marqueur a battu le dernier défenseur.
     const avant=events[i-1]?.scene;if(s.origin==='open'&&!(avant?.kind==='carry'&&String(avant.actor)===acteur.id)){acteur.j.defenseursBattus++;const def=presents(1-team,min);if(def.length)choisir(def,c=>POIDS.plaquages[c.poste]*(c.poste>=10?2:1),r).j.plaquagesManques++}}
    if(typeof s.conversion==='boolean'){
     const att=presents(team,min),k=(buteur[team]&&att.find(c=>c.id===buteur[team]))||att.find(c=>c.poste===9)||att.find(c=>c.poste===8)||att[0];
     if(k){k.j.transformationsTentees++;if(s.conversion){k.j.transformations++;k.j.points+=2}}
    }
    continue;
   }
   if((kind==='goal'||kind==='miss')&&team!==null&&acteur){
    acteur.j.penalitesTentees++;buteur[team]=acteur.id;
    if(kind==='goal'){acteur.j.penalitesReussies++;acteur.j.points+=3}
    continue;
   }
   if(kind==='turnover'&&team!==null){
    if(acteur)acteur.j.recuperations++;
    const perdant=dernierPorteur[1-team]&&presents(1-team,min).find(c=>c.id===dernierPorteur[1-team].id)||choisir(presents(1-team,min),poidsCourse(min),r);
    if(perdant)perdant.j.ballonsPerdus++;
    continue;
   }
   // Mêlée non disputée : la préparation (« setup ») puis l'introduction non disputée (« play ») du même camp
   // racontent une seule mêlée, que le moteur compte une fois (l.stats.scrums).
   if(kind==='scrum'||kind==='lineout'){const meme=kind==='scrum'&&e.type!=='setup'&&derniereMiseEnPlace?.kind==='scrum'&&derniereMiseEnPlace.team===team&&derniereMiseEnPlace.preparee;derniereMiseEnPlace={kind,team,preparee:e.type==='setup'};if(team!==null&&!meme){if(kind==='lineout'){equipes[team].touches.lancers++;const talon=presents(team,min).find(c=>c.poste===1);if(talon)talon.j.lancers++}else equipes[team].melees.introductions++}continue}
   if((kind==='setpiece-win'||kind==='setpiece-loss')&&team!==null){
    const mp=derniereMiseEnPlace;derniereMiseEnPlace=null;
    if(mp?.kind==='lineout'){if(kind==='setpiece-win'&&mp.team===team)equipes[team].touches.gagnees++;if(acteur){acteur.j.touchesGagnees++;if(kind==='setpiece-loss')acteur.j.touchesVolees++}}
    else if(mp?.kind==='scrum'&&kind==='setpiece-win'&&mp.team===team)equipes[team].melees.gagnees++;
    if(kind==='setpiece-loss'&&acteur)acteur.j.conquetesVolees++;
    continue;
   }
   if(kind==='hand-fault'&&team!==null){
    const c=choisir(presents(team,min),c=>POIDS.enAvant[c.poste]*(1.4-attr(c.id,'pass')/150),r);
    if(c){c.j.enAvant++;c.j.ballonsPerdus++}
    continue;
   }
   if(kind==='penalty'&&team!==null){
    const fautif=1-team,c=choisir(presents(fautif,min),c=>POIDS.fautes[c.poste]*(1.5-attr(c.id,'discipline')/110),r);
    if(c){c.j.penalitesConcedees++;dernierePenalite={camp:fautif,minute:min,j:c.j}}
    continue;
   }
   if(kind==='card'&&s.incident===true&&team!==null&&acteur){
    const rouge=s.card==='red'||s.cause==='red';
    if(rouge)acteur.j.cartonsRouges++;else acteur.j.cartonsJaunes++;
    exclus.set(acteur.id,rouge?Infinity:min+10);
    // Le carton sanctionne la dernière pénalité de son équipe : elle revient au joueur sanctionné.
    if(dernierePenalite&&dernierePenalite.camp===team&&min-dernierePenalite.minute<=1&&dernierePenalite.j!==acteur.j){dernierePenalite.j.penalitesConcedees--;acteur.j.penalitesConcedees++;dernierePenalite.j=acteur.j}
    continue;
   }
   if(kind==='kick'&&team!==null&&acteur){
    acteur.j.coupsDePied++;acteur.j.metresAuPied+=Number.isFinite(s.from?.x)&&Number.isFinite(s.to?.x)?Math.abs(s.to.x-s.from.x):25;
    continue;
   }
   if(kind==='touch'&&s.cause==='penalty-touch'&&team!==null){
    const att=presents(team,min),k=att.find(c=>c.poste===9)||att.find(c=>c.poste===14)||att.find(c=>c.poste===8);
    if(k){k.j.coupsDePied++;k.j.metresAuPied+=22+r()*18}
    continue;
   }
  }
  // Fin du match montrée : la dernière minute est close.
  if(fini&&derniereMinute!==null)fermer(derniereMinute+1);
  return assembler(joueurs,equipes,{cle:String(options.cle||''),minute:derniereMinute??0,fini,faits:n});
 }

 function assembler(joueurs,equipes,meta){
  const sortie={};
  const totaux=[0,1].map(s=>({...vide(),rucks:equipes[s].rucks,touches:{...equipes[s].touches},melees:{...equipes[s].melees}}));
  for(const [id,j] of Object.entries(joueurs)){
   const o={camp:j.camp,numero:j.numero,poste:j.poste};
   for(const c of CHAMPS_JOUEUR)o[c]=c==='metres'||c==='metresAuPied'?Math.round(j[c]):j[c];
   // Joueur resté sur le banc : aucune ligne.
   if(o.minutes===0&&CHAMPS_JOUEUR.every(c=>c==='minutes'||o[c]===0))continue;
   sortie[id]=o;
   for(const c of CHAMPS_JOUEUR)totaux[j.camp][c]+=o[c];
  }
  const faits=equipes[0].faitsPossession+equipes[1].faitsPossession;
  totaux.forEach((t,s)=>{
   const tentes=t.plaquages+t.plaquagesManques;
   t.reussitePlaquage=tentes?Math.round(t.plaquages/tentes*1000)/10:null;
   t.possession=faits?Math.round(equipes[s].faitsPossession/faits*100):null;
  });
  return {version:VERSION,...meta,equipes:totaux,joueurs:sortie};
 }

 // Lignes du tiroir « Stats » et de la fin de match (domicile / extérieur).
 function lignesEquipe(feuille){
  if(!feuille?.equipes)return [];
  const [a,b]=feuille.equipes;
  return [
   ['Plaquages réussis',a.plaquages,b.plaquages],['Plaquages manqués',a.plaquagesManques,b.plaquagesManques],
   ['Réussite au plaquage',a.reussitePlaquage===null?'—':String(a.reussitePlaquage).replace('.',',')+' %',b.reussitePlaquage===null?'—':String(b.reussitePlaquage).replace('.',',')+' %'],
   ['Courses',a.courses,b.courses],['Mètres gagnés',a.metres,b.metres],['Défenseurs battus',a.defenseursBattus,b.defenseursBattus],
   ['Passes',a.passes,b.passes],['Offloads',a.offloads,b.offloads],['Rucks joués',a.rucks,b.rucks],
   ['Ballons récupérés',a.recuperations,b.recuperations],['Ballons perdus',a.ballonsPerdus,b.ballonsPerdus],
   ['Coups de pied',a.coupsDePied,b.coupsDePied],['Mètres au pied',a.metresAuPied,b.metresAuPied]
  ].map(([label,home,away])=>({label,home:String(home),away:String(away)}));
 }

 // Résumé d'un joueur (historique de match, notes) : les chiffres d'une ligne de feuille.
 function resumeJoueur(feuille,id){
  const j=feuille?.joueurs?.[String(id)];if(!j)return null;
  const o={};for(const c of CHAMPS_JOUEUR)o[c]=j[c];return {camp:j.camp,numero:j.numero,poste:j.poste,...o};
 }


 // --- Branchement à l'entracte (match-direct.cjs) --------------------------------------------
 // Attributs des joueurs lus une fois par rencontre (ils ne changent pas pendant le match).
 const ATTRIBUTS=new Map();
 function attributsDe(rencontre,lire){
  if(ATTRIBUTS.has(rencontre))return ATTRIBUTS.get(rencontre);
  let joueurs={};
  if(typeof lire?.attributs==='function'){try{joueurs=lire.attributs()||{}}catch(error){joueurs={}}}
  ATTRIBUTS.set(rencontre,joueurs);while(ATTRIBUTS.size>4)ATTRIBUTS.delete(ATTRIBUTS.keys().next().value);
  return joueurs;
 }
 // Feuille de ce qui a été montré : les `borne` premiers faits du journal (indice de `normaliser`).
 function feuilleMontree(events,borne,rencontre,lire){
  return feuilleStatistiques(events,{cle:rencontre,borne,joueurs:attributsDe(rencontre,lire)});
 }
 // Tableau de bord de l'entracte : les chiffres d'équipe sont ceux de la feuille (somme des joueurs).
 // Les faits du journal (franchissements, en-avant) y sont déjà identiques ; la possession,
 // l'occupation, les mêlées, touches et pénalités restent ceux du moteur.
 function completerTableau(tableau,feuille){
  const [a,b]=feuille.equipes,vide=v=>v[0]+v[1]===0&&feuille.minute<10;
  const poser=(cle,label,champ,extra={})=>{
   const valeurs=[a[champ],b[champ]];let rang=tableau.find(r=>r.cle===cle);
   if(!rang){rang={cle,label};tableau.push(rang)}
   Object.assign(rang,{label,valeurs,vide:vide(valeurs)},extra);
  };
  poser('metres','Mètres gagnés','metres');
  poser('franchissements','Franchissements','franchissements');
  poser('plaquages','Plaquages réussis','plaquages');
  poser('plaquages_manques','Plaquages manqués','plaquagesManques',{inverse:true});
  poser('recuperations','Ballons récupérés','recuperations');
  poser('en_avant','En-avant','enAvant',{inverse:true});
  poser('temps_de_jeu','Courses','courses');
  poser('pieds','Coups de pied','coupsDePied');
  poser('passes','Passes','passes');
  poser('defenseurs_battus','Défenseurs battus','defenseursBattus');
  poser('offloads','Offloads','offloads');
  poser('rucks','Rucks joués','rucks');
  poser('ballons_perdus','Ballons perdus','ballonsPerdus',{inverse:true});
  return tableau;
 }
 // Lignes du XV adverse (`direct.adversaire`) : plaquages, mètres et essais de la feuille.
 function habillerAdversaire(liste,feuille){
  for(const j of Array.isArray(liste)?liste:[]){
   const f=j&&feuille.joueurs[String(j.joueur)];if(!f)continue;
   j.plaquages=f.plaquages;j.metres=f.metres;j.essais=f.essais;j.courses=f.courses;j.minutes=f.minutes;
  }
  return liste;
 }
 // --- Apport de la feuille à la note de match (match-notes.cjs, 14 novembre 2026) ----------------
 // Ce qu'un joueur a fait de plus (ou de moins) que ce que son poste et ses minutes lui donnaient
 // dans CE match : part du total de son équipe selon les poids du poste (POIDS), multipliée par la
 // valeur d'une unité. Somme nulle par équipe et par statistique : la base 6,5 et l'étalonnage des
 // notes par poste ne bougent pas en moyenne ; un ailier à 110 m ou un flanker à 22 plaquages en tire
 // un bonus, un joueur aux nombreux plaquages manqués un malus. Les passes n'y entrent pas (affaire de
 // rôle : le demi de mêlée sert presque chaque ruck). Borné à ±APPORT_MAX (impact brut, avant la
 // compression de la note). Les essais, franchissements, ballons récupérés… comptent déjà dans la
 // note par les faits du journal, dont la feuille reprend exactement les acteurs.
 const APPORT=Object.freeze({plaquages:[.05,'plaquages'],plaquagesManques:[-.16,'plaquages'],metres:[.009,'metresCourse'],defenseursBattus:[.07,'cassure'],offloads:[.06,'offloads'],ballonsPerdus:[-.1,'enAvant']}),APPORT_MAX=.9;
 function apportsNote(feuille){
  const sortie={},liste=Object.entries(feuille?.joueurs||{});
  const poids=(cle,poste)=>cle==='metresCourse'?POIDS.courses[poste]*POIDS.metres[poste]:POIDS[cle][poste];
  for(const camp of [0,1]){
   const eux=liste.filter(([,j])=>j.camp===camp&&j.minutes>0&&j.numero>=1&&j.numero<=15);
   for(const [champ,[valeur,cle]] of Object.entries(APPORT)){
    const part=eux.map(([,j])=>poids(cle,j.numero-1)*j.minutes),somme=part.reduce((a,b)=>a+b,0);
    if(!(somme>0))continue;
    const total=eux.reduce((a,[,j])=>a+j[champ],0);
    eux.forEach(([id,j],k)=>{sortie[id]=(sortie[id]||0)+valeur*(j[champ]-total*part[k]/somme)});
   }
  }
  for(const id of Object.keys(sortie))sortie[id]=Math.round(Math.max(-APPORT_MAX,Math.min(APPORT_MAX,sortie[id]))*1000)/1000;
  return sortie;
 }
 return Object.freeze({VERSION,LIBELLES_POSTES,POIDS,REGLAGES,CHAMPS_JOUEUR,feuilleStatistiques,lignesEquipe,resumeJoueur,empreinte,feuilleMontree,completerTableau,habillerAdversaire,apportsNote});
}

module.exports=Object.freeze({...fabrique(),fabrique});
