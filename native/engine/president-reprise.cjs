'use strict';
// Le président reprend la main quand le club dépense trop (demande de Léo du 18/11/2026, suite de l'économie façon FM).
//
// Si, après un achat (recrue signée, indemnité versée à un autre club), la trésorerie passe sous la réserve que le club
// se fixe (club-budget.cjs, reserveCible), le président désigne deux ou trois joueurs à vendre avant une date (trois
// semaines). Un seul courrier, avec des réponses : les mettre sur la liste des transferts, le laisser vendre tout de
// suite, ou plaider pour un délai de deux semaines (sa confiance en prend un coup). À l'échéance, si la caisse n'est
// pas repassée au-dessus de la réserve, il vend lui-même les joueurs désignés encore au club, avec une décote, jusqu'à
// retrouver la réserve. Si la caisse est revenue au-dessus de la réserve entre-temps, il renonce.
//
// Rare par construction : seulement après un achat qui fait franchir la réserve (ou la creuse nettement), au plus une
// fois tous les quatre mois par club. Les clubs gérés suivent la même règle en coulisses (club-directions.cjs : la
// direction passe en « vente » tant que le président attend, puis vente forcée à l'échéance).
// Désignés : les mieux payés hors des douze meilleurs joueurs, sans les recrues trop récentes, les espoirs ni les prêtés.
// Mode Monde uniquement ; aucun tirage au hasard.
//
// Allègement chez les clubs gérés (suite de #899, mesure : 3 à 6 interventions et 9 à 16 ventes par saison) :
//   - le président d'un club géré n'intervient que si le club est « Fragile » après l'achat (club-finance-health.cjs :
//     moins de la moitié de sa réserve, ou endetté) ; un club seulement un peu sous sa réserve se débrouille seul ;
//   - chaque président a son tempérament : entre deux interventions, 4 à 8 mois selon le club (déterministe) ;
//   - il désigne au plus deux joueurs.
// Le club joué garde la règle d'origine (un courrier rare mais lisible, au plus tous les quatre mois).

const DELAI = 21, RALLONGE = 14, ESPACEMENT = 120;   // jours
const DECOTE = 0.8;                                   // vente pressée : 80 % de la valeur du joueur
const NOYAU = 12;                                     // les douze meilleurs ne sont jamais désignés
const CREUSE = 0.1;                                   // déjà sous la réserve : un achat qui la creuse de 10 % de plus
const ESPACEMENT_MAX = 240;                           // clubs gérés : 4 à 8 mois entre deux interventions
const DESIGNES_IA = 2;                                // clubs gérés : au plus deux joueurs désignés

// Tempérament du président d'un club géré : délai entre deux interventions, de 120 à 240 jours, fixe pour un club.
function espacement(id) {
  const n = Math.abs(Math.trunc(Number(id) || 0));
  return ESPACEMENT + ((n * 37 + 11) % (ESPACEMENT_MAX - ESPACEMENT + 1));
}

const DAY = 86400000;
const decaler = (iso, n) => new Date(Date.parse(iso + 'T00:00:00Z') + n * DAY).toISOString().slice(0, 10);
const euros = n => new Intl.NumberFormat('fr-FR', { maximumFractionDigits: 0 }).format(Math.round(n)).replace(/[\u202f\u00a0]/g, ' ') + ' €';
const dateCourte = iso => Number(iso.slice(8, 10)) + ' ' + ['janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'][Number(iso.slice(5, 7)) - 1];

// Le président intervient-il après cet achat ? avant/apres : caisse avant et après ; derniere : date de sa dernière intervention.
function declenche({ avant, apres, reserve, date, derniere = null, delai = ESPACEMENT }) {
  if (![avant, apres, reserve].every(Number.isFinite) || !(reserve > 0) || !(apres < reserve) || !(apres < avant)) return false;
  if (derniere && date < decaler(derniere, delai)) return false;
  return avant >= reserve || avant - apres >= CREUSE * reserve;
}

// Joueurs désignés : {id, name, pos, note, salaire (hebdo), valeur, bloque}. manque : ce qui sépare la caisse de la réserve.
function designer(joueurs, { manque, max = 3 }) {
  const coeur = new Set(joueurs.slice().sort((a, b) => b.note - a.note || (a.id < b.id ? -1 : 1)).slice(0, NOYAU).map(p => p.id));
  const candidats = joueurs.filter(p => !coeur.has(p.id) && !p.bloque && p.valeur > 0)
    .sort((a, b) => b.salaire - a.salaire || b.valeur - a.valeur || (a.id < b.id ? -1 : 1));
  const out = []; let total = 0;
  for (const p of candidats) {
    if (out.length >= max || out.length >= 2 && total >= manque) break;
    out.push(p); total += p.valeur * DECOTE;
  }
  return out;
}

const liste = l => l.length > 1 ? l.slice(0, -1).join(', ') + ' et ' + l[l.length - 1] : l.join('');
// Variables du courrier (club-mail.json, type reprise_president).
function courrier(plan, { tresorerie, reserve }) {
  return {
    tresorerie: euros(tresorerie), reserve: euros(reserve), manque: euros(Math.max(0, reserve - tresorerie)), echeance: dateCourte(plan.echeance),
    // Une seule ligne (le courrier refuse les retours à la ligne dans ses variables).
    liste: liste(plan.joueurs.map(j => `${j.name} (${j.pos}, ${euros(j.salaire * 52)} par an, estimé ${euros(j.valeur)})`)),
    n: plan.joueurs.length,
    // Phrase sur la période des mutations, remplie par le branchement (repriseCourrier) hors période.
    mutations: '',
  };
}

function valide(e) {
  return !!e && typeof e === 'object' && e.version === 1 && !!e.clubs && typeof e.clubs === 'object' && !!e.derniere && typeof e.derniere === 'object' &&
    Object.values(e.clubs).every(p => !!p && typeof p.date === 'string' && typeof p.echeance === 'string' && Array.isArray(p.joueurs) && ['en_cours', 'retabli', 'vendu', 'abandon'].includes(p.etat));
}

// Code branché dans la carrière (après club-budget.cjs et a2r.cjs). Attend : budgetActif, budgetMonde, budgetMasse,
// transferValue, saleBlocked, nativePresidentReprise (ce module).
const BRANCHEMENT = `
const repriseActif=()=>budgetActif()&&budgetMonde()&&typeof worldActive==='function'&&worldActive();
const repriseJour=()=>{try{return CDWorldCareer.calendarToday(S);}catch(e){return null;}};
const repriseEtat=()=>{if(!nativePresidentReprise.valide(S.presidentReprise))S.presidentReprise={version:1,clubs:{},derniere:{}};return S.presidentReprise;};
const repriseReserve=id=>{const r=S.clubBudget?.clubs?.[id]?.reserve;return Number.isFinite(r)?r:null;};
const repriseTally=(k,id)=>{if(typeof nativeClubDirections!=='undefined')nativeClubDirections.tally(k,id);};
const reprisePretes=()=>new Set((S.clubDirections?.loans||[]).map(l=>l.playerId));
function repriseJoueurs(c){
 const pretes=reprisePretes();
 return c.players.map(p=>({id:p.id,name:p.name,pos:p.pos,note:p.rating,salaire:p.salary,valeur:transferValue(p),bloque:!!saleBlocked(p)||pretes.has(p.id)}));
}
// Après un achat d'un club : caisse avant l'achat. Le président désigne les joueurs à vendre s'il le faut.
function repriseApresAchat(c,avant){
 if(!repriseActif()||!c||S.live)return false;
 const e=repriseEtat(),date=repriseJour(),reserve=repriseReserve(c.id);
 if(!date||reserve===null||e.clubs[c.id]?.etat==='en_cours')return false;
 const joue=c.id===S.club;
 if(!nativePresidentReprise.declenche({avant,apres:c.cash,reserve,date,derniere:e.derniere[c.id]||null,
  delai:joue?nativePresidentReprise.ESPACEMENT:nativePresidentReprise.espacement(c.id)}))return false;
 // Club géré : seulement s'il est « Fragile » après l'achat (étiquette de santé, quand elle est branchée).
 if(!joue&&typeof santeFiche==='function'){let f=null;try{f=santeFiche(c.id);}catch(err){}if(f&&f.etiquette&&f.etiquette!=='fragile'){repriseTally('president:epargne',c.id);return false;}}
 const joueurs=nativePresidentReprise.designer(repriseJoueurs(c),{manque:reserve-c.cash,max:joue?3:nativePresidentReprise.DESIGNES_IA});
 if(!joueurs.length)return false;
 e.clubs[c.id]={date,echeance:nativePresidentReprise.decaler(date,nativePresidentReprise.DELAI),joueurs:joueurs.map(j=>({id:j.id,name:j.name,pos:j.pos,salaire:j.salaire,valeur:j.valeur})),
  etat:'en_cours',saison:S.season,tresorerie:c.cash,reserve,delai:false,confie:false};
 e.derniere[c.id]=date;
 repriseTally('president:intervention',c.id);
 return true;
}
// Clubs gérés : la direction passe en « vente » tant que le président attend (club-directions.cjs).
const repriseIAVente=id=>id!==S.club&&S.presidentReprise?.clubs?.[id]?.etat==='en_cours';
// Vente décidée par le président : au club qui a la place, la masse et les moyens (le plus riche d'abord).
// Club joué hors période des mutations (calendrier-mutations, décision de Léo du 19/11/2026) : la vente est conclue
// tout de suite mais exécutée à l'ouverture (accord imposé de vente-joueurs.cjs : rien au budget de transferts).
function repriseFenetre(c){
 if(c.id!==S.club||typeof venteFenetre!=='function'||typeof venteNouvelAccord!=='function')return null;
 const f=venteFenetre();return f.ouverte||!f.reouverture?null:f;
}
function repriseVendre(c,plan,reserve){
 const vendus=[],differe=repriseFenetre(c);let attendu=0;
 for(const j of plan.joueurs){
  if(c.cash+attendu>=reserve)break;
  const p=c.players.find(x=>x.id===j.id);if(!p||saleBlocked(p)||differe&&(venteAccord(p.id)||venteRaisonListe(p)))continue;
  const fee=Math.max(20000,Math.round(transferValue(p)*nativePresidentReprise.DECOTE/10000)*10000);
  const b=S.clubs.filter(x=>x.id!==c.id&&x.id!==S.club&&professionalPlaces(x)>0&&x.cash-fee>=400000&&aiRosterPayroll(x)+p.salary<=aiRosterWageLimit(x))
   .sort((x,y)=>y.cash-x.cash||x.id-y.id)[0];
  if(!b)continue;
  if(differe){
   venteNouvelAccord({playerId:p.id,joueur:p.name,buyer:b.id,acheteur:b.name,fee,date:differe.reouverture,imposee:true});
   delete S.economy.listings[p.id];S.economy.offers=S.economy.offers.filter(o=>o.playerId!==p.id);
   transferEvent('Le président a conclu la vente de '+p.name+' à '+b.name+' pour '+money(fee)+' : départ le '+nativeVenteJoueurs.dateFr(differe.reouverture)+(differe.bascule?', au changement de saison.':', à l’ouverture des mutations.'));
   attendu+=fee;vendus.push({name:p.name,fee,club:b.name,date:differe.reouverture});repriseTally('president:vente',c.id);continue;
  }
  b.cash-=fee;c.players=c.players.filter(x=>x.id!==p.id);b.players.push(p);
  p.formerClub=c.name;p.joinedSeason=S.season;p.joinedRound=S.round;p.contractEnd=Math.max(p.contractEnd,S.season+1);
  if(typeof aiRosterEvent==='function'){aiRosterEvent(c.id,'sell',p,fee);aiRosterEvent(b.id,'recruit',p,fee);}
  if(c.id===S.club){
   ledgerEntry('Vente décidée par le président : '+p.name,fee);
   delete S.economy.listings[p.id];S.economy.offers=S.economy.offers.filter(o=>o.playerId!==p.id);
   S.lineup=S.lineup.map(x=>x===p.id?null:x);S.reserves=S.reserves.map(x=>x===p.id?null:x);
   transferEvent('Le président a vendu '+p.name+' à '+b.name+' pour '+money(fee)+'.');
  }else{c.cash+=fee;S.economy.transfers.unshift({season:S.season,round:S.round,text:c.name+' vend '+p.name+' à '+b.name+' pour '+money(fee)+' (le président veut retrouver sa réserve).'});S.economy.transfers=S.economy.transfers.slice(0,80);}
  vendus.push({name:p.name,fee,club:b.name});
  repriseTally('president:vente',c.id);
 }
 if(c.id===S.club&&vendus.some(v=>!v.date))repairSheet();
 return vendus;
}
// Chaque semaine : caisse revenue au-dessus de la réserve (il renonce), échéance (il vend), sinon on attend.
function repriseSemaine(){
 if(!repriseActif())return;
 const e=repriseEtat(),date=repriseJour();if(!date)return;
 for(const [id,plan] of Object.entries(e.clubs)){
  if(plan.etat!=='en_cours')continue;
  const c=S.clubs[Number(id)],reserve=repriseReserve(c.id)??plan.reserve,joue=c.id===S.club;
  if(c.cash>=reserve){plan.etat='retabli';repriseTally('president:retabli',c.id);if(joue)news('Le président a vu la trésorerie repasser au-dessus de la réserve : il renonce aux ventes qu’il avait demandées.');continue;}
  if(!(plan.confie||date>=plan.echeance))continue;
  const vendus=repriseVendre(c,plan,reserve);
  plan.etat=vendus.length?'vendu':'abandon';
  if(joue)news(vendus.length?'Le président a tranché : '+vendus.map(v=>v.name+' ('+v.club+', '+money(v.fee)+(v.date?', départ le '+nativeVenteJoueurs.dateFr(v.date):'')+')').join(', ')+'.'
   :'Le président n’a trouvé aucun acheteur pour les joueurs désignés : la trésorerie reste sous la réserve.');
 }
 // Mémoire bornée : les interventions closes des saisons passées disparaissent.
 for(const [id,plan] of Object.entries(e.clubs))if(plan.etat!=='en_cours'&&plan.saison<S.season)delete e.clubs[id];
}
const worldWeeklyEconomyRepriseV1=worldWeeklyEconomy;
worldWeeklyEconomy=function(results){const r=worldWeeklyEconomyRepriseV1(results);if(r!==false)repriseSemaine();return r;};
// Courrier du club joué (club-mail.cjs, déclencheur « reprise_president ») : {cle, vars} ou null.
function repriseCourrier(){
 const plan=S.presidentReprise?.clubs?.[S.club];
 if(!repriseActif()||!plan||plan.etat!=='en_cours')return null;
 // Hors période des mutations : le président prévient que ses ventes ne seront effectives qu'à l'ouverture.
 const f=repriseFenetre(club());
 return {cle:plan.date,vars:{...nativePresidentReprise.courrier(plan,{tresorerie:plan.tresorerie,reserve:plan.reserve}),
  mutations:f?(f.bascule?'Les transferts prennent effet au changement de saison : une vente se conclura tout de suite, mais le joueur ne partira et l’argent n’arrivera que le ':'Nous sommes hors période des mutations : une vente se conclura tout de suite, mais le joueur ne partira et l’argent n’arrivera que le ')+nativeVenteJoueurs.dateFr(f.reouverture)+'.':''}};
}
function repriseRefus(action){
 const plan=S.presidentReprise?.clubs?.[S.club];
 if(!plan||plan.etat!=='en_cours')return 'Le président a déjà tranché.';
 if(action==='delai'&&plan.delai)return 'Le président a déjà accordé un délai.';
 if(action==='lister'&&!plan.joueurs.some(j=>club().players.some(p=>p.id===j.id&&!saleBlocked(p))))return 'Aucun des joueurs désignés n’est encore à vendre.';
 return ['lister','confier','delai'].includes(action)?'':'Réponse inconnue.';
}
function repriseAction(action){
 const raison=repriseRefus(action);if(raison)return {ok:false,raison};
 const plan=S.presidentReprise.clubs[S.club];
 if(action==='lister'){for(const j of plan.joueurs){const p=club().players.find(x=>x.id===j.id);if(p&&!saleBlocked(p))S.economy.listings[p.id]=true;}return {ok:true};}
 if(action==='confier'){plan.confie=true;return {ok:true};}
 plan.delai=true;plan.echeance=nativePresidentReprise.decaler(plan.echeance,nativePresidentReprise.RALLONGE);
 return {ok:true,verdict:'Nouvelle échéance : '+nativePresidentReprise.dateCourte(plan.echeance)+'.'};
}
`;

module.exports = Object.freeze({ DELAI, RALLONGE, ESPACEMENT, ESPACEMENT_MAX, DESIGNES_IA, DECOTE, NOYAU, CREUSE, BRANCHEMENT, decaler, dateCourte, euros, espacement, declenche, designer, courrier, valide });
