'use strict';
// Calendrier du recrutement (docs/gdd/calendrier-mutations.md, décisions de Léo du 19/11/2026), fidèle au régime des
// mutations LNR 2023-24 :
//  - achats de joueurs sous contrat à un autre club : immédiats du 1er mai au 30 juin (période des mutations, réglée
//    dans vente-joueurs.json pour les deux sens) ; hors période, accord conclu et exécuté à l'ouverture (même liste
//    d'accords que les ventes, vente-joueurs.cjs) ;
//  - joueurs sans club (commande recruit) : jusqu'au 31 décembre ; en janvier, au plus deux « joueurs supplémentaires »
//    par saison ; fermé ensuite jusqu'à la période des mutations ;
//  - jokers (renforts pris parmi les joueurs sans club, jokers médicaux des clubs gérés) : jusqu'au 31 mars ;
//  - pré-contrats, dans les deux sens, pour un joueur dont le contrat s'achève dans moins de six mois : arrivée au
//    1er juillet (bascule de saison), sans indemnité, seulement une prime à la signature (budget de transferts) ;
//    les autres clubs approchent les joueurs du club joué (courrier, délai pour proposer une prolongation).
// Mode Monde. Réglages : calendrier-mutations.json (lu à chaque calcul). Aucun hasard hors des tirages déterministes.
const REGLAGES = require('./calendrier-mutations.json');
const VENTE = require('./vente-joueurs.cjs');

const isoValide = j => typeof j === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(j);
const MOIS = ['janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'];
// « 31 janvier » à partir de « 01-31 ».
const jourMois = md => { const [m, j] = md.split('-').map(Number); return (j === 1 ? '1er' : String(j)) + ' ' + MOIS[m - 1]; };
const dateFr = VENTE.dateFr;
const dans = (md, p) => p.debut <= p.fin ? md >= p.debut && md <= p.fin : md >= p.debut || md <= p.fin;
const decaler = (iso, n) => new Date(Date.parse(iso + 'T00:00:00Z') + n * 86400000).toISOString().slice(0, 10);

// Une liste de périodes (MM-JJ) : ouverte ce jour-là ? Sinon, prochaine ouverture ; si ouverte, date de fermeture.
function periode(jour, periodes) {
  const liste = Array.isArray(periodes) ? periodes : [];
  if (!isoValide(jour)) return { ouverte: true, reouverture: null, fin: null };
  const md = jour.slice(5), an = Number(jour.slice(0, 4));
  const p = liste.find(x => dans(md, x));
  if (p) {
    const fin = p.debut <= p.fin || md > p.fin ? (p.debut <= p.fin ? an : an + 1) + '-' + p.fin : an + '-' + p.fin;
    return { ouverte: true, reouverture: null, fin };
  }
  const prochaines = liste.map(x => { const d = an + '-' + x.debut; return d > jour ? d : (an + 1) + '-' + x.debut; }).sort();
  return { ouverte: false, reouverture: prochaines[0] || null, fin: null };
}

// Joueurs sans club (commande recruit). dejaSupp : joueurs supplémentaires déjà recrutés cette saison.
function libres(jour, dejaSupp = 0, R = REGLAGES) {
  const ouvert = { ouverte: true, supplementaire: false, restants: null, max: R.supplementaires.maxParSaison, reouverture: null, fin: null, raison: '', note: '' };
  if (R.mode !== 'fenetres' || !isoValide(jour)) return ouvert;
  const L = periode(jour, R.libres.periodes), max = R.supplementaires.maxParSaison;
  if (L.ouverte) return { ...ouvert, fin: L.fin, note: 'Joueurs sans club : recrutement ouvert jusqu’au ' + dateFr(L.fin) + '.', court: 'Joueurs libres : ouvert jusqu’au ' + jourMois(L.fin.slice(5)) };
  const reo = L.reouverture ? dateFr(L.reouverture) : '';
  const Sp = periode(jour, R.supplementaires.periodes), finSupp = (R.supplementaires.periodes[0] || {}).fin;
  if (Sp.ouverte) {
    if (dejaSupp < max) {
      const n = max - dejaSupp;
      return { ...ouvert, supplementaire: true, restants: n, fin: Sp.fin, note: 'Joueurs supplémentaires jusqu’au ' + dateFr(Sp.fin) + ' : encore ' + n + ' sur ' + max + ' cette saison.', court: 'Joueurs supplémentaires : ' + n + ' sur ' + max };
    }
    return { ...ouvert, ouverte: false, supplementaire: true, restants: 0, reouverture: L.reouverture,
      raison: 'Les ' + max + ' joueurs supplémentaires de la saison sont déjà recrutés : recrutement des joueurs sans club rouvert le ' + reo + '.', court: 'Joueurs libres : fermé jusqu’au ' + jourMois(L.reouverture.slice(5)) };
  }
  return { ...ouvert, ouverte: false, reouverture: L.reouverture,
    raison: 'Recrutement des joueurs sans club fermé' + (finSupp ? ' depuis le ' + jourMois(finSupp) : '') + ' : réouverture le ' + reo + '.', court: 'Joueurs libres : fermé jusqu’au ' + jourMois(L.reouverture.slice(5)) };
}

// Joueurs sous contrat entre clubs (période des mutations de vente-joueurs.json, même source que la vente).
function interclub(jour, RV = VENTE.REGLAGES) {
  const f = VENTE.fenetre(jour, RV);
  if (f.mode !== 'fenetres' || !isoValide(jour)) return { ouverte: true, reouverture: null, raison: '', note: '' };
  if (f.ouverte) { const p = periode(jour, RV.fenetres.periodes); return { ouverte: true, reouverture: null, raison: '', note: 'Période des mutations ouverte jusqu’au ' + dateFr(p.fin) + ' : les accords entre clubs sont immédiats.' }; }
  const raison = 'Hors période des mutations : un accord conclu maintenant sera effectif le ' + dateFr(f.reouverture) + '.';
  return { ouverte: false, reouverture: f.reouverture, raison, note: raison };
}

function jokers(jour, R = REGLAGES) {
  if (R.mode !== 'fenetres' || !isoValide(jour)) return { ouverte: true, reouverture: null };
  return periode(jour, R.jokers.periodes);
}

// Dates d'un pré-contrat pour un contrat qui s'achève en juin de `anneeFin` : premier jour possible (moins de
// moisAvantFin mois de contrat, le 1er du mois), fin du contrat, arrivée au nouveau club.
function preContratDates(anneeFin, R = REGLAGES) {
  const P = R.preContrats, [m] = P.finContrat.split('-').map(Number);
  return { debut: new Date(Date.UTC(anneeFin, m - P.moisAvantFin, 1)).toISOString().slice(0, 10), fin: anneeFin + '-' + P.finContrat, arrivee: anneeFin + '-' + P.arrivee };
}
const prime = (salaire, R = REGLAGES) => { const P = R.preContrats, pas = P.arrondi > 0 ? P.arrondi : 1; return Math.ceil(salaire * P.primeSemaines / pas) * pas; };
// Approche d'un autre club cette semaine ? Déterministe (graine, saison, semaine).
const approcheTiree = (graine, saison, semaine, R = REGLAGES) => {
  const A = R.preContrats.approches;
  return !!A.actives && Number.isInteger(semaine) && VENTE.hash(graine + ':' + saison + ':' + semaine + ':precontrat') % 1000 < Math.round(A.chanceSemaine * 1000);
};

// Code exécuté dans le moteur (après vente-joueurs.cjs) : attend nativeCalendrierMutations (ce module),
// nativeVenteJoueurs, les fonctions de dist/economy.js et des autres branchements (budget, ventes, prolongations).
const BRANCHEMENT = `
const calR=()=>nativeCalendrierMutations.REGLAGES;
const calActif=()=>!!S&&!!S.worldMode&&!S.franceMode&&typeof CDWorldCareer!=='undefined';
const calJour=()=>{if(!calActif())return null;try{return CDWorldCareer.calendarToday(S);}catch(e){return null;}};
const calDateFr=d=>nativeVenteJoueurs.dateFr(d);
// La saison s commence en août 2025+s et s'achève en juin 2026+s (world-career.cjs, referenceStart) : un contrat qui
// s'achève à la saison c prend fin en juin 2026+c.
const calAnneeFin=c=>2026+c;
const calEtatValide=v=>!!v&&typeof v==='object'&&v.version===1&&Number.isInteger(v.seq)&&Array.isArray(v.preContrats)&&!!v.supplementaires&&Array.isArray(v.supplementaires.ids);
function calEtat(ecrire=false){
 if(calEtatValide(S.calendrierMutations))return S.calendrierMutations;
 const neuf={version:1,seq:0,supplementaires:{saison:S.season,ids:[]},preContrats:[]};if(ecrire)S.calendrierMutations=neuf;return neuf;
}
const calSupp=()=>{const s=calEtat().supplementaires;return s.saison===S.season?s.ids.length:0;};
function calLibres(){return nativeCalendrierMutations.libres(calJour(),calSupp(),calR());}
function calInterclub(){return nativeCalendrierMutations.interclub(calJour(),nativeVenteJoueurs.REGLAGES);}
// Recrue libre (commande recruit, model.market) : '' si permise, sinon la raison avec la date de réouverture.
function calendrierRefusRecrue(){const l=calLibres();return l.ouverte?'':l.raison;}
// Après la signature d'une recrue libre : un joueur supplémentaire de plus si on est en janvier.
function calendrierApresRecrue(id){
 const l=calLibres();if(!l.supplementaire)return;
 const e=calEtat(true);if(e.supplementaires.saison!==S.season)e.supplementaires={saison:S.season,ids:[]};
 if(!e.supplementaires.ids.includes(id))e.supplementaires.ids.push(id);
}
// Jokers (renforts pris parmi les joueurs sans club, jokers médicaux des clubs gérés) : jusqu'au 31 mars.
function calendrierJokersOuverts(){const j=calJour();return !j||nativeCalendrierMutations.jokers(j,calR()).ouverte;}
// Accords d'achat différés (vente-joueurs.cjs, sens « achat »).
const calAccordAchat=id=>typeof venteEtat==='function'?venteEtat().accords.find(a=>a.sens==='achat'&&a.playerId===id&&a.clubId===S.club)||null:null;
function calExecuterAchat(a){const d=nativeSystems.domain('interclubMarket');return d&&typeof d.executerAchat==='function'?d.executerAchat(a):false;}

// ---- Pré-contrats ----
const calPreDates=p=>nativeCalendrierMutations.preContratDates(calAnneeFin(p.contractEnd),calR());
const calPre=id=>calEtat().preContrats.find(x=>x.playerId===id&&(x.etat==='approche'||x.etat==='signe'))||null;
function preContratSigne(id){const x=calPre(id);return x&&x.etat==='signe'?x:null;}
// Prolongation refusée pour un joueur qui a signé ailleurs ('' sinon).
function preContratRefusProlongation(id){const x=preContratSigne(id);return x&&x.sens==='depart'&&x.clubId===S.club?'A signé un pré-contrat avec '+x.autre+' : il part libre le '+calDateFr(x.arrivee)+'.':'';}
// Joueur d'un autre club : un pré-contrat est-il possible ? '' si oui.
function calRaisonPreContrat(c,p){
 const P=calR().preContrats;if(!P.actifs||!calActif())return 'Pré-contrats indisponibles dans cette carrière.';
 const x=calPre(p.id);
 if(x)return x.sens==='arrivee'&&x.clubId===S.club?'Pré-contrat signé : il rejoindra ton club le '+calDateFr(x.arrivee)+'.':'Il a déjà signé un pré-contrat avec un autre club.';
 if(S.live)return 'Match en cours : attends la fin de la journée.';
 const j=calJour();if(!j)return 'Pré-contrats indisponibles dans cette carrière.';
 if(p.contractEnd!==S.season)return 'Son contrat ne s’achève pas cette saison.';
 const d=calPreDates(p);
 if(j<d.debut)return 'Pré-contrat possible à partir du '+calDateFr(d.debut)+', à moins de '+P.moisAvantFin+' mois de la fin de son contrat.';
 if(j>d.fin)return 'Son contrat est arrivé à échéance.';
 if(typeof careerContractYears==='function'&&careerContractYears(p)<2)return 'Il arrêtera sa carrière à la fin de son contrat.';
 return '';
}
// Devis d'un pré-contrat (projection du marché entre clubs, commande precontract_offer).
function calPreContratDevis(c,p,budget){
 const raison=calRaisonPreContrat(c,p),x=calPre(p.id);
 const signed=x&&x.sens==='arrivee'&&x.clubId===S.club?{date:x.arrivee,dateLabel:calDateFr(x.arrivee),salary:x.salaire,years:x.annees,premium:x.prime,label:'Rejoindra '+club().name+' le '+calDateFr(x.arrivee)+'.'}:null;
 if(raison)return {available:false,reason:raison,...(signed?{signed}:{})};
 const d=calPreDates(p),salary=Math.max(1000,Math.min(100000,askingWage(p,'recruit'))),premium=nativeCalendrierMutations.prime(salary,calR());
 const maxYears=Math.max(1,Math.min(3,careerContractYears(p)-1));
 const a2r=typeof a2rRefusRecrue==='function'?a2rRefusRecrue(salary):'',horsBudget=typeof budgetTransfertsRefus==='function'?budgetTransfertsRefus(premium,budget||undefined):null;
 const blocage=a2r||horsBudget||(club().cash<premium?'Trésorerie insuffisante pour la prime.':'');
 // premiumWeeks / premiumStep : prime = arrondi supérieur(salaire × premiumWeeks, premiumStep), recalculée par l'écran.
 return {available:!blocage,reason:blocage||'',salary,premium,premiumWeeks:calR().preContrats.primeSemaines,premiumStep:calR().preContrats.arrondi,minYears:1,maxYears,arrival:d.arrivee,arrivalLabel:calDateFr(d.arrivee),
  note:'Pré-contrat : il rejoindra ton club le '+calDateFr(d.arrivee)+', sans indemnité pour '+c.name+'. Seule la prime à la signature ('+nativeVenteJoueurs.euros(premium)+') est payée maintenant, sur le budget de transferts.'};
}
// Commande precontract_offer {playerId, sellerId, salary, years, confirmed:true}.
function preContratProposer(q){
 const keys=Object.keys(q||{});
 if(keys.length!==5||!['playerId','sellerId','salary','years','confirmed'].every(k=>keys.includes(k))||typeof q.playerId!=='string'||!Number.isInteger(q.sellerId)||!Number.isInteger(q.salary)||!Number.isInteger(q.years))throw Error('Pré-contrat : paramètres invalides.');
 if(q.confirmed!==true)throw Error('Confirme le pré-contrat avant de le proposer.');
 const c=S.clubs[q.sellerId],p=c&&c.id!==S.club?c.players.find(x=>x.id===q.playerId):null;if(!p)throw Error('Ce joueur n’est plus disponible.');
 const r=calRaisonPreContrat(c,p);if(r)throw Error(r);
 const d=calPreContratDevis(c,p);if(!d.available)throw Error(d.reason);
 if(q.salary<d.salary)throw Error(p.name+' demande au moins '+nativeVenteJoueurs.euros(d.salary)+' par semaine.');
 if(q.salary>100000)throw Error('La demande salariale dépasse le plafond de 100 000 € par semaine.');
 if(q.years<d.minYears||q.years>d.maxYears)throw Error('Durée possible : '+d.minYears+' à '+d.maxYears+' saison'+(d.maxYears>1?'s':'')+'.');
 const a2r=typeof a2rRefusRecrue==='function'?a2rRefusRecrue(q.salary):'';if(a2r)throw Error(a2r);
 const premium=nativeCalendrierMutations.prime(q.salary,calR());
 const hb=typeof budgetTransfertsRefus==='function'?budgetTransfertsRefus(premium):null;if(hb)throw Error(hb);
 if(club().cash<premium)throw Error('Trésorerie insuffisante pour la prime.');
 const st=calEtat(true);st.seq++;
 const x={id:'pre-'+st.seq,sens:'arrivee',etat:'signe',clubId:S.club,playerId:p.id,nom:p.name,pos:p.pos,autreId:c.id,autre:c.name,salaire:q.salary,annees:q.years,prime:premium,date:calJour(),echeance:calJour(),arrivee:d.arrival,saison:S.season};
 st.preContrats.push(x);
 if(premium>0){ledgerEntry('Prime de pré-contrat : '+p.name,-premium);if(typeof budgetTransfertsDepenser==='function')budgetTransfertsDepenser(premium);}
 transferEvent(p.name+' signe un pré-contrat : il rejoindra '+club().name+' le '+calDateFr(x.arrivee)+', sans indemnité pour '+c.name+'.');
 return {preContract:{playerId:p.id,sellerId:c.id,salary:q.salary,years:q.years,premium,arrival:x.arrivee,arrivalLabel:calDateFr(x.arrivee),
  message:p.name+' a signé : il rejoindra le club le '+calDateFr(x.arrivee)+', sans indemnité. Prime de '+nativeVenteJoueurs.euros(premium)+' payée.'}};
}
// Prolongation signée pendant une approche : l'autre club renonce aussitôt.
function calendrierApresProlongation(id){
 if(!calEtatValide(S.calendrierMutations))return;
 const p=player(id);
 for(const x of S.calendrierMutations.preContrats)if(x.sens==='depart'&&x.etat==='approche'&&x.playerId===id&&p&&p.contractEnd>x.saison){
  x.etat='annule';x.fin=calJour()||'';transferEvent(p.name+' prolonge : '+x.autre+' renonce à le recruter.');
 }
}
// Clôture de semaine (dans economyWeek, vente-joueurs.cjs) : approches arrivées à échéance (il signe, sauf
// prolongation) et, certaines semaines, nouvelle approche d'un autre club pour un joueur en fin de contrat.
function calSemaine(){
 if(!calActif()||S.live)return;
 const P=calR().preContrats,A=P.approches,j=calJour();if(!P.actifs||!j)return;
 if(calEtatValide(S.calendrierMutations))for(const x of S.calendrierMutations.preContrats){
  if(x.sens!=='depart'||x.etat!=='approche')continue;
  const p=x.clubId===S.club?player(x.playerId):null;
  if(!p){x.etat='tombe';continue;}
  if(p.contractEnd>x.saison){x.etat='annule';x.fin=j;transferEvent(p.name+' prolonge : '+x.autre+' renonce à le recruter.');continue;}
  if(j>=x.echeance){
   x.etat='signe';x.fin=j;
   // Seule la presse en parle : le joueur reste pleinement professionnel jusqu'à son départ.
   transferEvent('La presse l’annonce : '+p.name+' s’est engagé avec '+x.autre+' pour la saison prochaine. Il quittera le club libre le '+calDateFr(x.arrivee)+'.');
  }
 }
 if(!A.actives)return;
 const semaine=S.worldMode?.week??S.round,graine=venteGraine();
 if(!nativeCalendrierMutations.approcheTiree(graine,S.season,semaine,calR()))return;
 if(calEtat().preContrats.filter(x=>x.sens==='depart'&&x.saison===S.season&&x.clubId===S.club).length>=A.maxParSaison)return;
 const own=club(),cands=own.players.filter(p=>p.contractEnd===S.season&&!p.espoirLoan&&!calPre(p.id)&&!venteAccord(p.id)&&(typeof careerContractYears!=='function'||careerContractYears(p)>=2)&&(()=>{const d=calPreDates(p);return j>=d.debut&&j<=d.fin;})())
  .sort((a,b)=>roleNote(b)-roleNote(a)||(a.id<b.id?-1:a.id>b.id?1:0)).slice(0,A.candidats);
 if(!cands.length)return;
 const h=seedHash(graine+':'+S.season+':'+semaine+':precontrat-joueur');
 for(let k=0;k<cands.length;k++){
  const p=cands[(h+k)%cands.length];
  const buyers=S.clubs.filter(c=>c.id!==S.club&&c.cash>=A.reserveAcheteur&&professionalPlaces(c)>0).map(c=>({c,b:venteBesoin(c,p)})).filter(x=>x.b>=A.besoinMin)
   .sort((x,y)=>y.b-x.b||Math.abs(x.c.base-p.rating)-Math.abs(y.c.base-p.rating)||x.c.id-y.c.id);
  if(!buyers.length)continue;
  const b=buyers[h%Math.min(3,buyers.length)].c,st=calEtat(true),d=calPreDates(p);st.seq++;
  st.preContrats.push({id:'pre-'+st.seq,sens:'depart',etat:'approche',clubId:S.club,playerId:p.id,nom:p.name,pos:p.pos,autreId:b.id,autre:b.name,
   salaire:Math.min(100000,Math.ceil(p.salary*A.majorationSalaire/100)*100),annees:Math.max(1,Math.min(3,careerContractYears(p)-1)),prime:0,date:j,echeance:nativeCalendrierMutations.decaler(j,A.delaiJours),arrivee:d.arrivee,saison:S.season});
  return;
 }
}
// Bascule de saison (1er juillet) : les pré-contrats s'exécutent avant le départ des joueurs libres.
function calExecuterPreContrats(){
 const st=S.calendrierMutations;
 for(const x of st.preContrats){
  if(x.saison!==S.season||(x.etat!=='signe'&&x.etat!=='approche'))continue;
  if(x.clubId!==S.club){x.etat='tombe';continue;}
  if(x.sens==='depart'){
   const own=club(),p=own.players.find(q=>q.id===x.playerId),b=S.clubs[x.autreId];
   if(!p||!b||p.contractEnd>S.season){x.etat=p&&p.contractEnd>S.season?'annule':'tombe';continue;}
   own.players=own.players.filter(q=>q!==p);S.lineup=S.lineup.map(id=>id===p.id?null:id);S.reserves=S.reserves.map(id=>id===p.id?null:id);
   if(S.economy){delete S.economy.listings[p.id];S.economy.offers=S.economy.offers.filter(o=>o.playerId!==p.id);}
   p.formerClub=own.name;p.salary=x.salaire;p.contractEnd=S.season+x.annees;p.joinedSeason=S.season+1;p.joinedRound=0;b.players.push(p);
   if(typeof aiRosterEvent==='function')aiRosterEvent(b.id,'recruit',p,0);
   x.etat='execute';transferEvent(p.name+' rejoint '+b.name+' libre, comme prévu par son pré-contrat.');
  }else{
   const c=S.clubs[x.autreId],p=c?.players.find(q=>q.id===x.playerId);
   if(!p||p.contractEnd>S.season){
    x.etat='tombe';
    if(x.prime>0)ledgerEntry('Prime de pré-contrat remboursée : '+x.nom,x.prime);
    transferEvent('Le pré-contrat de '+x.nom+' tombe : il ne fait plus partie de '+(c?.name||x.autre)+' en fin de contrat. La prime est remboursée.');continue;
   }
   c.players=c.players.filter(q=>q!==p);
   p.formerClub=c.name;p.salary=x.salaire;p.contractEnd=S.season+x.annees;p.joinedSeason=S.season+1;p.joinedRound=0;p.condition=100;
   club().players.push(p);if(typeof satisfactionActive==='function'&&satisfactionActive()&&typeof ensureSatisfaction==='function')ensureSatisfaction(p);
   if(typeof aiRosterEvent==='function')aiRosterEvent(c.id,'release',p,0);
   x.etat='execute';transferEvent(p.name+' rejoint '+club().name+' : pré-contrat honoré, arrivée sans indemnité.');
  }
 }
 st.preContrats=st.preContrats.filter(x=>x.saison>=S.season-1).slice(-40);
}
const settleContractsCalV1=settleContracts;
settleContracts=function(){
 if(S.economy&&S.economy.settled!==S.season&&calEtatValide(S.calendrierMutations)&&calActif())calExecuterPreContrats();
 return settleContractsCalV1.apply(this,arguments);
};
// Le directeur sportif ne prolonge pas un joueur qui a signé ailleurs (prolongations-staff.cjs).
if(typeof dsContratsCandidats==='function'){const dsCandidatsCalV1=dsContratsCandidats;dsContratsCandidats=function(){return dsCandidatsCalV1.apply(this,arguments).filter(p=>!preContratRefusProlongation(p.id));};}
if(typeof dsContratsRefus==='function'){const dsRefusCalV1=dsContratsRefus;dsContratsRefus=function(kind,id){return kind==='forcer'&&preContratRefusProlongation(id)||dsRefusCalV1.apply(this,arguments);};}
// Renforts pris parmi les joueurs sans club (club-budget.cjs, promote_cover) : jokers jusqu'au 31 mars ; après, les
// espoirs montent.
if(typeof budgetJoker==='function'){const budgetJokerCalV1=budgetJoker;budgetJoker=function(){return calendrierJokersOuverts()||calLibres().ouverte?budgetJokerCalV1.apply(this,arguments):null;};}

// ---- Vues ----
const calVuePre=x=>({id:x.id,state:x.etat,direction:x.sens==='arrivee'?'arrival':'departure',playerId:x.playerId,name:x.nom,pos:x.pos,clubId:x.autreId,club:x.autre,
 salary:x.salaire,years:x.annees,premium:x.prime,date:x.date,deadline:x.echeance,deadlineLabel:x.echeance?calDateFr(x.echeance):'',arrival:x.arrivee,arrivalLabel:calDateFr(x.arrivee),label:calLibellePre(x),
 short:x.sens==='arrivee'?'Rejoindra le club le '+nativeCalendrierMutations.jourMois(x.arrivee.slice(5)):x.etat==='approche'?'Approché par '+x.autre+' : prolonger avant le '+nativeCalendrierMutations.jourMois(x.echeance.slice(5)):'A signé à '+x.autre+' : départ le '+nativeCalendrierMutations.jourMois(x.arrivee.slice(5))});
function calLibellePre(x){
 if(x.sens==='arrivee')return 'Rejoindra '+(S.clubs[x.clubId]?.name||'ton club')+' le '+calDateFr(x.arrivee)+' (pré-contrat signé, sans indemnité).';
 if(x.etat==='approche')return 'Approché par '+x.autre+' : propose-lui une prolongation avant le '+calDateFr(x.echeance)+', sinon il signera là-bas.';
 return 'A signé à '+x.autre+' : il part libre le '+calDateFr(x.arrivee)+'.';
}
// squad[] : {preContract} pour un joueur du club joué approché ou qui a signé ailleurs ; {} sinon.
function preContratVueJoueur(p){const x=calActif()&&calEtatValide(S.calendrierMutations)?calPre(p.id):null;return x&&x.clubId===S.club&&x.sens==='depart'?{preContract:calVuePre(x)}:{};}
// model.mutations : périodes ouvertes ou fermées (raison écrite, date de réouverture), pré-contrats et accords d'achat.
function calendrierVue(){
 if(!calActif()||!S.economy)return {available:false};
 const j=calJour(),l=calLibres(),f=calInterclub(),k=nativeCalendrierMutations.jokers(j,calR()),list=calEtat().preContrats.filter(x=>x.clubId===S.club);
 const vivants=list.filter(x=>x.etat==='approche'||x.etat==='signe');
 const achats=(typeof venteEtat==='function'?venteEtat().accords:[]).filter(a=>a.sens==='achat'&&a.clubId===S.club)
  .map(a=>({id:a.id,playerId:a.playerId,name:a.joueur,sellerId:a.seller,seller:S.clubs[a.seller]?.name||a.vendeur,fee:a.fee,salary:a.salary,date:a.date,dateLabel:calDateFr(a.date),
   label:'Accord conclu : '+a.joueur+' rejoindra le club le '+calDateFr(a.date)+' ('+nativeVenteJoueurs.euros(a.fee)+' à '+(S.clubs[a.seller]?.name||a.vendeur)+').'}));
 const libresVue={open:l.ouverte,supplementary:!!l.supplementaire,remaining:l.restants,max:l.max,until:l.fin,untilLabel:l.fin?calDateFr(l.fin):'',reopens:l.reouverture,reopensLabel:l.reouverture?calDateFr(l.reouverture):'',reason:l.raison,note:l.note||l.raison};
 const inter={open:f.ouverte,reopens:f.reouverture,reopensLabel:f.reouverture?calDateFr(f.reouverture):'',reason:f.raison,note:f.note};
 return {available:true,today:j,summary:l.court||'',detail:[libresVue.note,inter.note].filter(Boolean).join(' '),
  freeAgents:libresVue,interclub:inter,jokers:{open:k.ouverte,reopens:k.reouverture||null},
  preContracts:{arrivals:vivants.filter(x=>x.sens==='arrivee').map(calVuePre),departures:vivants.filter(x=>x.sens==='depart'&&x.etat==='signe').map(calVuePre),approaches:vivants.filter(x=>x.sens==='depart'&&x.etat==='approche').map(calVuePre)},
  purchases:achats};
}
// Courriers (club-mail.cjs) : « precontrat_approche » (approche en cours, lien vers la prolongation) et
// « precontrat_signe » (il a signé ailleurs). Lecture seule.
function calCourriers(s,etat){
 if(!s?.worldMode||!calEtatValide(s.calendrierMutations))return [];
 return s.calendrierMutations.preContrats.filter(x=>x.sens==='depart'&&x.clubId===s.club&&x.etat===etat&&x.saison===s.season)
  .map(x=>({key:x.id+':'+etat,player:x.playerId,club:x.autreId,vars:{joueur:x.nom,acheteur:x.autre,echeance:calDateFr(x.echeance),depart:calDateFr(x.arrivee)}}));
}
`;

module.exports = Object.freeze({ REGLAGES, periode, libres, interclub, jokers, preContratDates, prime, approcheTiree, decaler, jourMois, BRANCHEMENT });
