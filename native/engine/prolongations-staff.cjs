'use strict';
// Prolongations confiées au directeur sportif (décision de Léo, 17/11/2026, suite de #870).
//
// Mesure de #870 : un manager qui ne prolonge personne voit sa masse salariale et son effectif fondre (les contrats
// échus ne sont remplacés que pour compléter la feuille). Case « Confier aussi les prolongations au staff »
// (S.manager.delegation.contracts, absente = cochée, comme « Confier aussi la composition au staff ») : de mars à
// juin, le directeur sportif du club joué tranche lui-même les fins de contrat que le manager n'a pas réglées.
//
// Règles :
//  - Jugement imparfait : il voit chaque joueur à travers sa compétence (note estimée de club-directions.cjs,
//    bruit selon son trait « évaluation » ; potentiel estimé de même). Il peut garder un joueur moyen ou laisser
//    partir un bon : comme les choix de joueurs façon FM.
//  - Il prolonge les joueurs utiles au salaire qu'ils demandent (askingWage), dans la limite de la masse que le club
//    s'autorise (budgetLimites) et jamais au-dessus du plafond de la ligue ; les autres partent à l'échéance.
//  - Il n'empiète pas sur le manager : un joueur en discussion avec lui, ou qui a rompu les discussions, est laissé.
//  - Chaque décision part en courrier (club-mail.cjs, types ds_prolongation et ds_depart) avec des réponses :
//    annuler une prolongation, prolonger quand même, ou lui donner une consigne (économe, jeunes, équilibre).
//  - Filet : si la saison se termine avant qu'il ait tranché (case cochée tard), il tranche à la bascule de saison.
//  - Mode Monde uniquement ; décision déterministe (empreinte par joueur et saison, jamais le flux de hasard).

const FENETRE = Object.freeze({ debut: 3, fin: 6 }); // mois du calendrier : mars à juin
const CONSIGNES = Object.freeze({
  equilibre: { part: 1, label: 'équilibre' },
  econome: { part: 0.92, label: 'économe' },
  jeunes: { part: 1, label: 'miser sur les jeunes' },
});
const RAISONS = Object.freeze({
  cadre: 'Il compte à son poste, je préfère ne pas prendre le risque de le perdre.',
  jeune: 'Il a encore de la marge et il ne coûte pas cher : je le garde.',
  profondeur: 'On manque de monde à son poste pour la saison prochaine.',
  effectif: 'Il nous faut du nombre pour la saison prochaine, il fera l’affaire.',
  niveau: 'À mon avis, il n’a plus le niveau pour nous.',
  budget: 'Le garder nous ferait dépasser la masse salariale que le club s’autorise.',
  plafond: 'Le plafond salarial de la ligue ne le permet pas.',
  tresorerie: 'La trésorerie ne permet pas de payer la prime de signature.',
});

// Valeur perçue d'un joueur pour le club, selon la consigne du manager.
function valeur(c, consigne) {
  const marge = Math.max(0, c.potentiel - c.estime);
  let v = c.estime;
  if (consigne === 'jeunes') v += c.age <= 24 ? 2 + Math.min(6, marge * 0.5) : c.age >= 31 ? -3 : 0;
  else if (c.age <= 23) v += Math.min(3, marge * 0.3);
  if (c.age >= 33) v -= 3;
  return v;
}

// Plan pur (testé à part) : candidats {id, estime, potentiel, age, demande (hebdo), ancien (salaire actuel), prime,
// profondeur}, contexte {base, engage (masse hebdo déjà engagée la saison prochaine), limite, plafond, tresorerie,
// restants (joueurs sous contrat la saison prochaine), cible (effectif visé), consigne}.
function planifier(candidats, x) {
  const consigne = CONSIGNES[x.consigne] ? x.consigne : 'equilibre';
  const limite = x.limite * CONSIGNES[consigne].part, plafond = Number.isFinite(x.plafond) ? x.plafond : Infinity;
  const tries = candidats.map(c => ({ ...c, valeur: valeur(c, consigne) }))
    .sort((a, b) => b.valeur - a.valeur || (a.id < b.id ? -1 : a.id > b.id ? 1 : 0));
  let engage = x.engage, gardes = 0, caisse = Number.isFinite(x.tresorerie) ? x.tresorerie : Infinity;
  const out = [];
  for (const c of tries) {
    const effectif = x.restants + gardes;
    let motif = null;
    if (c.valeur >= x.base - 6) motif = c.age <= 23 && c.potentiel - c.estime >= 4 ? 'jeune' : 'cadre';
    else if (c.profondeur < 2 && c.valeur >= x.base - 12) motif = 'profondeur';
    else if (effectif < x.cible && c.valeur >= x.base - 10) motif = 'effectif';
    else if (consigne === 'jeunes' && c.age <= 22 && c.potentiel >= x.base - 4) motif = 'jeune';
    if (!motif) { out.push({ id: c.id, decision: 'libere', raison: 'niveau' }); continue; }
    if (engage + c.demande > plafond) { out.push({ id: c.id, decision: 'libere', raison: 'plafond' }); continue; }
    if (engage + c.demande > limite) { out.push({ id: c.id, decision: 'libere', raison: 'budget' }); continue; }
    if (c.prime > caisse) { out.push({ id: c.id, decision: 'libere', raison: 'tresorerie' }); continue; }
    engage += c.demande; caisse -= c.prime; gardes++;
    out.push({ id: c.id, decision: 'prolonge', raison: motif });
  }
  return out;
}

// Saisons ajoutées selon l'âge, bornées par la retraite prévue (années de contrat restantes, saison en cours comprise).
function saisonsAjoutees(age, anneesCarriere) {
  const voulu = age <= 26 ? 3 : age <= 30 ? 2 : 1;
  return Math.max(0, Math.min(voulu, anneesCarriere - 1));
}

// Code exécuté dans le moteur (après le BRANCHEMENT de club-budget.cjs) : attend nativeProlongations (ce module).
const BRANCHEMENT = `
const dsContratsMonde=()=>!!S&&!S.franceMode&&typeof CDWorldCareer!=='undefined'&&CDWorldCareer.active(S)&&!!S.manager?.delegation;
const dsContratsActif=()=>dsContratsMonde()&&S.manager.delegation.contracts!==false;
const dsContratsConsigne=()=>{const c=S.manager?.delegation?.contractsPolicy;return nativeProlongations.CONSIGNES[c]?c:'equilibre';};
const dsContratsBureau=()=>{const m=S.manager;if(!m.contractDesk||m.contractDesk.season!==S.season)m.contractDesk={season:S.season,decisions:[]};return m.contractDesk;};
const dsContratsSaison=x=>typeof libelleSaison==='function'?libelleSaison(x):String(x);
const dsContratsAujourdhui=()=>{try{return CDWorldCareer.calendarToday(S);}catch(e){return null;}};
const dsContratsHash=t=>{let h=2166136261;for(let i=0;i<t.length;i++){h^=t.charCodeAt(i);h=Math.imul(h,16777619)>>>0;}return (h>>>0)/4294967296;};
// Prolongation signée par le directeur sportif, salaire pas encore appliqué (il l'est à la bascule de saison).
function dsContratsEnAttente(e){if(e.d!=='prolonge'&&e.etat!=='force')return null;if(e.etat==='annule')return null;const p=club().players.find(x=>x.id===e.id);return p&&p.contractEnd===e.end&&p.contractEnd>S.season?p:null;}
function dsContratsSalaireSuivant(p){const b=S.manager?.contractDesk;const e=b&&b.season===S.season?b.decisions.find(x=>x.id===p.id&&dsContratsEnAttente(x)===p):null;return e?e.salary:(p.salary||0);}
function dsContratsDirecteur(){const d=S.clubDirections?.clubs?.[S.club]?.director;return {nom:typeof d?.name==='string'?d.name:'',evaluation:Number.isFinite(d?.traits?.evaluation)?d.traits.evaluation:50};}
// Note et potentiel vus par le directeur sportif : même bruit que ses estimations de recrutement (club-directions).
function dsContratsVue(p,ev){
 let estime;
 try{estime=S.clubDirections&&typeof nativeClubDirections!=='undefined'?nativeClubDirections.estimate(club(),p,null):null;}catch(e){estime=null;}
 if(!Number.isFinite(estime))estime=roleNote(p)+(dsContratsHash('ds-eval|'+S.club+'|'+p.id+'|'+S.season)-.5)*2*(2+(100-ev)*.08);
 const amp=3+(100-ev)*.1,pot=(Number.isFinite(p.dev?.potential)?p.dev.potential:p.rating)+(dsContratsHash('ds-pot|'+S.club+'|'+p.id+'|'+S.season)-.5)*2*amp;
 return {estime:Math.round(estime*10)/10,potentiel:Math.round(pot*10)/10};
}
function dsContratsLimites(){
 const c=club();let limite=Infinity,plafond=Infinity;
 if(typeof budgetActif==='function'&&budgetActif()){const l=budgetLimites(false).get(c.id);if(l)limite=l.limite/52;const p=budgetPlafondAnnuel(c);if(p)plafond=p/52;}
 if(!Number.isFinite(limite)&&typeof aiRosterWageLimit==='function')limite=aiRosterWageLimit(c);
 return {limite,plafond};
}
// Joueurs dont le contrat s'achève cette saison et que le directeur sportif peut trancher.
function dsContratsCandidats(bureau){
 const c=club(),decides=new Set(bureau.decisions.map(x=>x.id)),talks=S.economy?.talks||{};
 const enMain=new Set(Object.values(talks).filter(t=>t&&t.kind==='renew'&&['ready','counter','withdrawn'].includes(t.status)).map(t=>t.id));
 return c.players.filter(p=>p.contractEnd===S.season&&!decides.has(p.id)&&!enMain.has(p.id)&&!p.espoirLoan&&!(typeof onLoan==='function'&&onLoan(p.id))&&nativeProlongations.saisonsAjoutees(p.age,careerContractYears(p))>=1);
}
// Tranche toutes les fins de contrat encore ouvertes. final : bascule de saison (pas de courrier, filet seulement).
function dsContratsTrancher(final){
 if(!dsContratsActif()||S.live)return 0;
 const bureau=dsContratsBureau(),liste=dsContratsCandidats(bureau);
 if(!liste.length)return 0;
 const c=club(),ds=dsContratsDirecteur(),ids=new Set(liste.map(p=>p.id));
 const restants=c.players.filter(p=>!ids.has(p.id)&&Number.isFinite(p.contractEnd)&&p.contractEnd>S.season&&p.age+1<(p.dev?.retireAge??40));
 const engage=restants.reduce((t,p)=>t+dsContratsSalaireSuivant(p),0),{limite,plafond}=dsContratsLimites();
 const cible=typeof aiRosterTarget==='function'?aiRosterTarget(c):32;
 const candidats=liste.map(p=>({id:p.id,age:p.age,...dsContratsVue(p,ds.evaluation),demande:askingWage(p,'renew'),prime:contractFee(p,'renew'),profondeur:restants.filter(q=>q.fam===p.fam).length}));
 const plan=nativeProlongations.planifier(candidats,{base:c.base,engage,limite,plafond,tresorerie:c.cash,restants:restants.length,cible,consigne:dsContratsConsigne()});
 const date=dsContratsAujourdhui()||'';let n=0;
 for(const d of plan){
  const p=c.players.find(x=>x.id===d.id),q=candidats.find(x=>x.id===d.id);
  const entree={id:p.id,name:String(p.name||''),pos:String(p.pos||''),age:p.age,d:d.decision,raison:d.raison,oldSalary:p.salary,oldEnd:p.contractEnd,salary:p.salary,end:p.contractEnd,fee:0,date,etat:'actif',final:!!final};
  if(d.decision==='prolonge'){
   const ajout=nativeProlongations.saisonsAjoutees(p.age,careerContractYears(p));
   entree.salary=q.demande;entree.end=S.season+ajout;entree.fee=q.prime;
   if(entree.fee)ledgerEntry('Prolongation : '+p.name,-entree.fee);
   p.contractEnd=entree.end;
   transferEvent(p.name+' prolonge jusqu’à la fin de la saison '+dsContratsSaison(entree.end)+', à '+money(entree.salary)+' par semaine dès la saison prochaine (décision du directeur sportif).');
  }
  bureau.decisions.push(entree);n++;
 }
 bureau.decisions=bureau.decisions.slice(-80);
 const gardes=plan.filter(x=>x.decision==='prolonge').length;
 if(final&&n)news('Fin de saison : le directeur sportif a prolongé '+gardes+' joueur'+(gardes>1?'s':'')+' et laissé partir '+(n-gardes)+' autre'+(n-gardes>1?'s':'')+' dont le contrat s’achevait.');
 return n;
}
// Après chaque commande (worker.cjs) : de mars à juin, le directeur sportif tranche ce qui reste ouvert.
function dsContratsObserver(){
 if(!dsContratsActif()||S.live||S.phase==='ended')return false;
 if(typeof CDPreseason!=='undefined'&&CDPreseason.pending(S))return false;
 const d=dsContratsAujourdhui();if(typeof d!=='string')return false;
 const mois=Number(d.slice(5,7));
 if(mois<nativeProlongations.FENETRE.debut||mois>nativeProlongations.FENETRE.fin)return false;
 return dsContratsTrancher(false)>0;
}
// Réponses du manager à un courrier du directeur sportif (club-mail.cjs) : '' si possible, sinon la raison.
function dsContratsRefus(kind,playerId){
 const bureau=S.manager?.contractDesk,e=bureau?.season===S.season?bureau.decisions.find(x=>x.id===playerId):null,p=club().players.find(x=>x.id===playerId);
 if(kind==='econome'||kind==='jeunes'||kind==='equilibre')return dsContratsConsigne()===kind?'C’est déjà sa consigne.':'';
 if(!e||!p)return 'Ce joueur ne fait plus partie de l’effectif.';
 if(kind==='annuler'){
  if(e.d!=='prolonge'||e.etat!=='actif'||p.contractEnd!==e.end)return 'Cette prolongation ne peut plus être annulée.';
  return '';
 }
 if(kind==='forcer'){
  if(e.d!=='libere'||e.etat!=='actif'||p.contractEnd!==S.season)return 'Son contrat a déjà été réglé.';
  if(nativeProlongations.saisonsAjoutees(p.age,careerContractYears(p))<1)return 'Il arrive au bout de sa carrière.';
  const {plafond}=dsContratsLimites(),suivante=club().players.filter(x=>x.id!==p.id&&Number.isFinite(x.contractEnd)&&x.contractEnd>S.season).reduce((t,x)=>t+dsContratsSalaireSuivant(x),0);
  if(suivante+askingWage(p,'renew')>plafond)return 'Le plafond salarial de la ligue ne le permet pas.';
  if((club().cash??0)<contractFee(p,'renew'))return 'Trésorerie insuffisante pour la prime de signature.';
  return '';
 }
 return 'Réponse inconnue.';
}
function dsContratsAction(kind,playerId){
 const raison=dsContratsRefus(kind,playerId);if(raison)throw Error('Courrier du club : '+raison.replace(/\\.$/,''));
 if(kind==='econome'||kind==='jeunes'||kind==='equilibre'){S.manager.delegation.contractsPolicy=kind;return true;}
 const e=S.manager.contractDesk.decisions.find(x=>x.id===playerId),p=club().players.find(x=>x.id===playerId);
 if(kind==='annuler'){
  if(e.fee)ledgerEntry('Prolongation annulée : '+p.name,e.fee);
  p.contractEnd=e.oldEnd;e.etat='annule';
  transferEvent('La prolongation de '+p.name+' est annulée : il quittera le club à la fin de son contrat.');
  return true;
 }
 const ajout=nativeProlongations.saisonsAjoutees(p.age,careerContractYears(p)),salaire=askingWage(p,'renew'),prime=contractFee(p,'renew');
 if(prime)ledgerEntry('Prolongation : '+p.name,-prime);
 p.contractEnd=S.season+ajout;e.etat='force';e.salary=salaire;e.end=p.contractEnd;e.fee=prime;
 transferEvent(p.name+' prolonge jusqu’à la fin de la saison '+dsContratsSaison(p.contractEnd)+', à '+money(salaire)+' par semaine dès la saison prochaine.');
 return true;
}
// Filet de la bascule de saison : ce qui n'a pas été tranché l'est avant le départ des joueurs libres.
const dsContratsSettleV1=settleContracts;
settleContracts=function(){
 if(S.economy&&S.economy.settled!==S.season&&dsContratsMonde()){
  dsContratsTrancher(true);
  // Les prolongations du directeur sportif prennent effet avec la nouvelle saison : nouveau salaire à la bascule.
  const b=S.manager.contractDesk;
  if(b&&b.season===S.season)for(const e of b.decisions){const p=dsContratsEnAttente(e);if(p)p.salary=e.salary;}
 }
 return dsContratsSettleV1.apply(this,arguments);
};
`;

// Validation de sauvegarde (exécutée dans le moteur, S en argument implicite) : réglages et bureau du directeur sportif.
function valider(m, saison) {
  if (!m || typeof m !== 'object') return true;
  const d = m.delegation || {};
  if (d.contracts !== undefined && typeof d.contracts !== 'boolean') throw Error('Sauvegarde invalide : délégation des prolongations.');
  if (d.contractsPolicy !== undefined && !CONSIGNES[d.contractsPolicy]) throw Error('Sauvegarde invalide : consigne du directeur sportif.');
  const b = m.contractDesk;
  if (b === undefined) return true;
  const ok = b && typeof b === 'object' && Number.isSafeInteger(b.season) && b.season >= 1 && b.season <= saison && Array.isArray(b.decisions) && b.decisions.length <= 80
    && b.decisions.every(e => e && typeof e.id === 'string' && e.id.length <= 180 && ['prolonge', 'libere'].includes(e.d) && ['actif', 'annule', 'force'].includes(e.etat) && RAISONS[e.raison] !== undefined
      && Number.isFinite(e.salary) && Number.isFinite(e.oldSalary) && Number.isFinite(e.fee) && typeof e.name === 'string' && e.name.length <= 120 && typeof e.date === 'string' && e.date.length <= 10);
  if (!ok) throw Error('Sauvegarde invalide : décisions du directeur sportif.');
  return true;
}

module.exports = Object.freeze({ FENETRE, CONSIGNES, RAISONS, valeur, planifier, saisonsAjoutees, valider, BRANCHEMENT });
