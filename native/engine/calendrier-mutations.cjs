'use strict';
// Calendrier du recrutement (docs/gdd/calendrier-mutations.md, décisions de Léo du 19/11/2026), fidèle au régime des
// mutations LNR 2023-24 :
//  - v2 (décision de Léo du 19/11/2026, soir) : transferts entre clubs conclus toute l'année, effet au 1er juillet
//    (bascule de saison) pour tous les clubs, clubs gérés compris (§ 3 bis du GDD) ; le texte v1 ci-dessous reste vrai
//    pour le réglage clubsGeres.calendrier = « semaines » ;
//  - achats de joueurs sous contrat à un autre club : immédiats du 1er mai au 30 juin (période des mutations, réglée
//    dans vente-joueurs.json pour les deux sens) ; hors période, accord conclu et exécuté à l'ouverture (même liste
//    d'accords que les ventes, vente-joueurs.cjs) ;
//  - joueurs sans club (commande recruit) : jusqu'au 31 décembre ; en janvier, au plus deux « joueurs supplémentaires »
//    par saison ; fermé ensuite jusqu'à la période des mutations ;
//  - jokers (renforts pris parmi les joueurs sans club, jokers médicaux des clubs gérés) : jusqu'au 31 mars ;
//  - pré-contrats, dans les deux sens, pour un joueur dont le contrat s'achève dans moins de six mois : arrivée au
//    1er juillet (bascule de saison), sans indemnité, seulement une prime à la signature (budget de transferts) ;
//    les autres clubs approchent les joueurs du club joué (courrier, délai pour proposer une prolongation).
// v2 (décision de Léo du 19/11/2026, GDD § 3 bis – 3 quater) : tout transfert entre clubs (club joué compris : achats,
// ventes, ventes imposées) se conclut toute l'année et prend effet au changement de saison ; les clubs gérés tiennent
// leurs tours de marché selon le calendrier (calClubsGeresTours), signent des pré-contrats entre eux, la presse en parle
// (actualités sans courrier) ; indemnité plafonnée aux salaires repris. Réglage clubsGeres.calendrier « semaines » (ou
// CD_CLUBS_GERES_CALENDRIER=semaines, mesure) : ancien comportement ci-dessus.
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

// Transferts entre clubs (v2, décision de Léo du 19/11/2026) : « mutations » = accords toute l'année, arrivée à la bascule ;
// « semaines » = ancien comportement (mesure). Surcharge de mesure : CD_CLUBS_GERES_CALENDRIER.
function calendrierClubs(R = REGLAGES) {
  const env = typeof process !== 'undefined' ? process.env.CD_CLUBS_GERES_CALENDRIER : undefined;
  if (env === 'semaines' || env === 'mutations') return env;
  return R.clubsGeres && R.clubsGeres.calendrier === 'semaines' ? 'semaines' : 'mutations';
}
// Indemnité plafonnée aux salaires que l'acheteur reprend (GDD § 3 quater) : salaire hebdomadaire × 52 × saisons de
// contrat restantes après l'arrivée ; plancher plancherIndemnite. ex. 5 000 €/sem., contrat jusqu'à saison + 1 → ≤ 260 000 €.
const plafondIndemnite = (salaire, contractEnd, saison) => Math.max(0, Math.round(salaire * 52 * Math.max(0, contractEnd - saison)));
function indemnite(fee, salaire, contractEnd, saison, R = REGLAGES) {
  const plancher = R.clubsGeres ? R.clubsGeres.plancherIndemnite : 10000;
  return Math.max(plancher, Math.min(Math.round(fee), plafondIndemnite(salaire, contractEnd, saison)));
}
// Tours de marché des clubs gérés à cette clôture de semaine (calendrier « mutations ») : semaines fixes (0 et 13), hiver
// (un tour toutes les n semaines comptées depuis le début de la période), période des mutations (un tour, deux la dernière
// semaine). Rend {tours, motif:'semaine'|'hiver'|'mutations'|'derniere'|null, fin (fin de la période des mutations)}.
function toursClubs(jour, semaine, saison, R = REGLAGES, RV = VENTE.REGLAGES) {
  const G = R.clubsGeres, rien = { tours: 0, motif: null, fin: null };
  if (!G || !isoValide(jour)) return rien;
  const f = VENTE.fenetre(jour, RV);
  if (f.mode === 'fenetres' && f.ouverte) {
    const fin = periode(jour, RV.fenetres.periodes).fin, derniere = decaler(jour, 7) > fin;
    return { tours: derniere ? G.toursDerniereSemaine : G.toursParSemaine, motif: derniere ? 'derniere' : 'mutations', fin };
  }
  if ((G.semainesFixes || []).includes(semaine) && !(saison === 1 && semaine === 0)) return { tours: 1, motif: 'semaine', fin: null };
  const h = periode(jour, (G.hiver || {}).periodes);
  if (h.ouverte && (G.hiver.periodes || []).length) {
    const p = G.hiver.periodes.find(x => dans(jour.slice(5), x)), an = Number(jour.slice(0, 4));
    const debut = (p.debut <= p.fin || jour.slice(5) >= p.debut ? an : an - 1) + '-' + p.debut;
    const n = Math.floor((Date.parse(jour) - Date.parse(debut)) / 86400000 / 7);
    if (n % Math.max(1, G.hiver.toutesLesSemaines) === 0) return { tours: 1, motif: 'hiver', fin: null };
  }
  return rien;
}

// Joueurs sous contrat entre clubs (période des mutations de vente-joueurs.json, même source que la vente).
// arrivee (v2, calendrier « mutations ») : date de la bascule ; les accords sont toujours différés jusque-là.
function interclub(jour, RV = VENTE.REGLAGES, arrivee = null) {
  const f = VENTE.fenetre(jour, RV);
  if (arrivee && isoValide(jour)) {
    const a = dateFr(arrivee);
    if (f.mode !== 'fenetres' || f.ouverte) {
      const p = f.mode === 'fenetres' ? periode(jour, RV.fenetres.periodes) : null;
      return { ouverte: true, reouverture: null, raison: '', arrivee, note: (p ? 'Période des mutations jusqu’au ' + dateFr(p.fin) + ' : les autres clubs enchérissent aussi. ' : '') + 'Un transfert conclu maintenant prendra effet le ' + a + '.' };
    }
    const raison = 'Hors période des mutations : un accord conclu maintenant prendra effet le ' + a + ' ; les autres clubs n’enchérissent qu’à partir du ' + dateFr(f.reouverture) + '.';
    return { ouverte: false, reouverture: f.reouverture, raison, note: raison, arrivee };
  }
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
function calInterclub(){return nativeCalendrierMutations.interclub(calJour(),nativeVenteJoueurs.REGLAGES,calBascule()?calArrivee():null);}
// v2 (décision de Léo du 19/11/2026) : transferts entre clubs conclus toute l'année, effectifs à la bascule de saison
// (« 1er juillet »), pour tous les clubs. Faux avec le réglage « semaines » (ancien comportement, mesure).
const calBascule=()=>calActif()&&nativeCalendrierMutations.calendrierClubs(calR())==='mutations';
const calArrivee=()=>nativeCalendrierMutations.preContratDates(calAnneeFin(S.season),calR()).arrivee;
// Fenêtre des accords du club joué (vente-joueurs.cjs venteFenetre) : toujours différés jusqu'à la bascule.
function calFenetreAccords(){
 if(!calBascule())return null;const a=calArrivee();
 return {mode:'fenetres',ouverte:false,reouverture:a,bascule:true,raison:'Un transfert conclu maintenant prendra effet le '+calDateFr(a)+' (changement de saison).'};
}
// Indemnité plafonnée aux salaires que l'acheteur reprend (tous les clubs ; réglage « semaines » : inchangée).
function calIndemnite(p,fee){return calBascule()?nativeCalendrierMutations.indemnite(fee,p.salary,p.contractEnd??S.season,S.season,calR()):fee;}
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

// ---- Retraite annoncée à l'avance (décision de Léo du 20/11/2026, GDD § 3 quater) ----
// À la première clôture de semaine de la période retraites (1er janvier), les joueurs dont la retraite tombe à la fin de la
// saison (rollDevelopmentYear : âge + 1 ≥ retireAge à la bascule) l'annoncent : p.dev.annonceRetraite = saison. Ils ne
// peuvent plus être achetés, vendus, mis en vente ni recevoir de pré-contrat.
const CAL_RETRAITE='A annoncé qu’il arrêtera sa carrière à la fin de la saison.';
const calRetraite=p=>!!p&&!!p.dev&&p.dev.annonceRetraite===S.season&&p.dev.retireAge-p.age<=1;
const calRaisonRetraite=p=>calActif()&&calRetraite(p)?CAL_RETRAITE:'';
function calAnnoncesRetraite(j){
 const P=calR().retraites;if(!P||!nativeCalendrierMutations.periode(j,P.periodes).ouverte)return;
 const st=calEtat(true);if(st.retraites===S.season)return;st.retraites=S.season;
 for(const c of S.clubs)for(const p of c.players){
  if(!p.dev||p.dev.retireAge-p.age>1)continue;
  p.dev.annonceRetraite=S.season;
  if(c.id===S.club){const t=p.name+' annonce qu’il arrêtera sa carrière à la fin de la saison.';if(typeof news==='function')news(t);else calActu(t);}
 }
}
// Joueur engagé (accord de transfert, pré-contrat) : il ne prend pas sa retraite avant la fin de son nouveau contrat (dernière
// saison fin) ; la bascule le vieillit d'un an, la retraite tombe quand âge ≥ retireAge.
function calProlongerCarriere(p,fin){
 if(!p||!Number.isInteger(fin))return;if(!p.dev&&typeof ensureDevelopment==='function')ensureDevelopment(p);if(!p.dev)return;
 const min=p.age+Math.max(0,fin-S.season)+1;if(p.dev.retireAge<min)p.dev.retireAge=min;
}
// Mouvements de la saison suivante conclus par le club joué (accords « bascule » de vente-joueurs.cjs, pré-contrats signés).
function calJoueMouvements(){
 const r=[];
 if(typeof venteEtat==='function')for(const a of venteEtat().accords){
  if(!a.bascule||a.clubId!==S.club)continue;
  if(a.sens==='achat'){const p=S.clubs[a.seller]?.players.find(q=>q.id===a.playerId);r.push({playerId:a.playerId,pos:p?.pos,salaire:a.salary||0,de:a.seller,vers:S.club});}
  else{const p=player(a.playerId);r.push({playerId:a.playerId,pos:p?.pos,salaire:p?.salary||0,de:S.club,vers:a.buyer});}
 }
 if(calEtatValide(S.calendrierMutations))for(const x of S.calendrierMutations.preContrats){
  if(x.etat!=='signe'||x.saison!==S.season||x.clubId!==S.club)continue;
  r.push(x.sens==='arrivee'?{playerId:x.playerId,pos:x.pos,salaire:x.salaire,de:x.autreId,vers:S.club}:{playerId:x.playerId,pos:x.pos,salaire:x.salaire,de:S.club,vers:x.autreId});
 }
 return r;
}
// Place de la saison suivante du club joué (GDD § 3 règle 6) : '' si un achat est possible, sinon la raison.
function calRaisonPlaceSuivante(c=club()){
 const s=calIASuivante(c);return s.places>0?'':'Ton effectif de la saison prochaine est déjà complet ('+s.n+'/'+s.capacite+' avec les arrivées prévues).';
}

// ---- Pré-contrats ----
const calPreDates=p=>nativeCalendrierMutations.preContratDates(calAnneeFin(p.contractEnd),calR());
const calPre=id=>calEtat().preContrats.find(x=>x.playerId===id&&(x.etat==='approche'||x.etat==='signe'))||null;
function preContratSigne(id){const x=calPre(id);return x&&x.etat==='signe'?x:null;}
// Prolongation refusée pour un joueur qui a signé ailleurs ('' sinon).
function preContratRefusProlongation(id){const x=preContratSigne(id);return x&&x.sens==='depart'&&x.clubId===S.club?'A signé un pré-contrat avec '+x.autre+' : il part libre le '+calDateFr(x.arrivee)+'.':'';}
// Joueur d'un autre club : un pré-contrat est-il possible ? '' si oui.
// Pré-contrats signés par le club joué cette saison (un pré-contrat tombé, annulé ou exécuté ne compte plus).
function calPreSignesSaison(){return calEtat().preContrats.filter(x=>x.sens==='arrivee'&&x.etat==='signe'&&x.clubId===S.club&&x.saison===S.season).length;}
function calRaisonPreContrat(c,p){
 const P=calR().preContrats;if(!P.actifs||!calActif())return 'Pré-contrats indisponibles dans cette carrière.';
 const ia=calIAReserve(p.id);if(ia)return ia;
 const x=calPre(p.id);
 if(x)return x.sens==='arrivee'&&x.clubId===S.club?'Pré-contrat signé : il rejoindra ton club le '+calDateFr(x.arrivee)+'.':'Il a déjà signé un pré-contrat avec un autre club.';
 if(S.live)return 'Match en cours : attends la fin de la journée.';
 const rt=calRaisonRetraite(p);if(rt)return rt;
 const j=calJour();if(!j)return 'Pré-contrats indisponibles dans cette carrière.';
 if(p.contractEnd!==S.season)return 'Son contrat ne s’achève pas cette saison.';
 const d=calPreDates(p);
 if(j<d.debut)return 'Pré-contrat possible à partir du '+calDateFr(d.debut)+', à moins de '+P.moisAvantFin+' mois de la fin de son contrat.';
 if(j>d.fin)return 'Son contrat est arrivé à échéance.';
 if(typeof careerContractYears==='function'&&careerContractYears(p)<2)return 'Il arrêtera sa carrière à la fin de son contrat.';
 const max=P.maxParSaison;if(Number.isInteger(max)&&max>=0&&calPreSignesSaison()>=max)return 'Tu as déjà signé '+max+' pré-contrat'+(max>1?'s':'')+' cette saison ('+max+' au plus) : les suivants attendront la saison prochaine.';
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
  note:'Pré-contrat : il rejoindra ton club le '+calDateFr(d.arrivee)+', sans indemnité pour '+c.name+'. Seule la prime à la signature ('+nativeVenteJoueurs.euros(premium)+') est payée maintenant, sur le budget de transferts. Pré-contrats : encore '+Math.max(0,calR().preContrats.maxParSaison-calPreSignesSaison())+' sur '+calR().preContrats.maxParSaison+' cette saison.'};
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
 st.preContrats.push(x);calProlongerCarriere(p,S.season+q.years);
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
 const j0=calJour();if(j0)calAnnoncesRetraite(j0);
 calIAPreContrats();
 const P=calR().preContrats,A=P.approches,j=calJour();if(!P.actifs||!j)return;
 if(calEtatValide(S.calendrierMutations))for(const x of S.calendrierMutations.preContrats){
  if(x.sens!=='depart'||x.etat!=='approche')continue;
  const p=x.clubId===S.club?player(x.playerId):null;
  if(!p){x.etat='tombe';continue;}
  if(p.contractEnd>x.saison){x.etat='annule';x.fin=j;transferEvent(p.name+' prolonge : '+x.autre+' renonce à le recruter.');continue;}
  if(j>=x.echeance){
   x.etat='signe';x.fin=j;calProlongerCarriere(p,S.season+x.annees);
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
// Bascule (v2) : pré-contrats du club joué, ses achats conclus, accords et pré-contrats des clubs gérés, puis le cycle des
// contrats (départ des joueurs libres, prolongations et libérations des clubs gérés), enfin ses ventes conclues. L'argent
// est passé à l'accord (décision de Léo du 20/11/2026) : un accord ne tombe plus pour manque de place ni de moyens ; un
// acheteur au-dessus de sa capacité s'ajuste ensuite (calCapaciteBascule).
// Après les arrivées : un club géré au-dessus de sa capacité libère ses joueurs les moins utiles (jamais une recrue du jour,
// sans découvrir de poste) ; le club joué est prévenu (le recrutement reste bloqué tant qu'il n'est pas revenu dessous).
function calCapaciteBascule(){
 const prets=new Set((S.clubDirections?.loans||[]).map(l=>l.playerId)),recrue=p=>p.joinedSeason===S.season+1&&(p.joinedRound||0)===0;
 for(const c of S.clubs){
  const cap=professionalCapacity(c),n=c.players.length;if(n<=cap)continue;
  if(c.id===S.club){const t='Effectif au-dessus du maximum ('+n+'/'+cap+') : aucune nouvelle recrue tant que tu n’es pas revenu sous ce nombre.';if(typeof news==='function')news(t);else calActu(t);continue;}
  const prio=p=>typeof aiRosterPriority==='function'?aiRosterPriority(c,p):roleNote(p);
  const pool=c.players.filter(p=>!recrue(p)&&!prets.has(p.id)).sort((a,b)=>prio(a)-prio(b)||b.salary-a.salary||(a.id<b.id?-1:1));
  const gone=new Set();
  for(const p of pool){if(n-gone.size<=cap)break;if(typeof aiRosterReleasable==='function'&&!aiRosterReleasable(c,p,gone))continue;gone.add(p.id);}
  if(!gone.size)continue;
  const partis=c.players.filter(p=>gone.has(p.id));c.players=c.players.filter(p=>!gone.has(p.id));
  for(const p of partis){
   p.formerClub=c.name;p.price=Math.round(p.salary*2/1000)*1000;p.contractEnd=null;p.condition=100;p.injury=0;
   if(p.population)p.population.availableSince=S.season;
   if(S.economy)S.economy.freeAgents.push(p);if(typeof aiRosterEvent==='function')aiRosterEvent(c.id,'release',p);
  }
  calFil(c.name+' libère '+partis.map(p=>p.name).join(', ')+' pour revenir à '+cap+' joueurs après ses arrivées.');
 }
}
const settleContractsCalV1=settleContracts;
settleContracts=function(){
 const du=!!S.economy&&S.economy.settled!==S.season&&calActif(),v2=du&&calBascule();let n=0;
 // L'argent rendu au budget de transferts pendant la bascule (part des ventes, achats tombés) va à la saison qui commence.
 const bascule=fn=>typeof budgetTransfertsPendantBascule==='function'?budgetTransfertsPendantBascule(fn):fn();
 if(du&&calEtatValide(S.calendrierMutations))calExecuterPreContrats();
 if(v2){n+=bascule(()=>venteExecuterAccords('achats'))||0;n+=calIAExecuter();}
 const r=settleContractsCalV1.apply(this,arguments);
 if(v2)calIAMasseBascule();else calIAArrivees=null;
 if(v2){n+=bascule(()=>venteExecuterAccords('ventes'))||0;calCapaciteBascule();if(n){const t=n>1?n+' transferts entre clubs prennent effet en ce changement de saison.':'Un transfert entre clubs prend effet en ce changement de saison.';calActu(t);calMercatoLigne(calMercatoEtat(),'temps-fort',t,0);}}
 return r;
};

// ---- Clubs gérés (v2) : accords différés, pré-contrats entre eux, rumeurs, temps forts du mercato ----
// État (champs facultatifs de S.calendrierMutations, bornés, purgés à la bascule) :
//  accordsIA : [{id,playerId,nom,pos,vendeurId,vendeur,acheteurId,acheteur,montant,salaire,annees,date,saison}] accords
//    d'achat conclus par un club géré (entre clubs gérés, ou enchère gagnée sur le marché du club joué), en attente de la
//    bascule ; paye : indemnité passée à l'accord (décision de Léo du 20/11/2026), accord toujours honoré ; sans paye
//    (sauvegarde antérieure) : payée à l'exécution, revérifiée ;
//  ia : [{id,playerId,nom,pos,vendeurId,vendeur,acheteurId,acheteur,salaire,annees,date,saison,etat:'signe'|'execute'|'tombe'}]
//    pré-contrats entre clubs gérés ;
//  rumeurs : [{id,playerId,nom,pos,clubId,club,interesseId,interesse,date,saison,suite:null|'signe'|'dementi'|'sans-suite',
//    piste:'vraie'|'fausse' (absente : vraie), dementi:AAAA-MM-JJ (piste fausse)}] ;
//  mercato : {saison,debut,fin,ouverture,derniere,bilan,n,top:[{texte,montant}],semaines:{[semaine]:[{type,texte,montant}]}}
//    résumé lisible (courriers « Échos du mercato » / « Point mercato ») ; type 'accord' (transfert conclu, montant),
//    'precontrat', 'rumeur', 'temps-fort' (ouverture, dernière semaine, bilan, bascule) ; dates AAAA-MM-JJ ou null ;
//    n et top : transferts conclus pendant la période des mutations (bilan) ;
//  clubsGeres : {cle:'saison:semaine',motif} dernière clôture où les clubs gérés ont tenu leurs tours ; iaSemaine : idem pour
//    les pré-contrats ; actus : {cle, n} actualités d'accords de la semaine.
const calG=()=>calR().clubsGeres;
function calIAEtat(){const st=calEtat(true);st.accordsIA??=[];st.ia??=[];st.rumeurs??=[];return st;}
const calIAListe=k=>calEtatValide(S.calendrierMutations)&&Array.isArray(S.calendrierMutations[k])?S.calendrierMutations[k]:[];
// Borne de la liste des accords : seuls les plus anciens accords déjà réglés (saison passée, tombés ou exécutés) sont écartés.
// Un accord en attente (déjà payé à l'accord, exécuté à la bascule) n'est JAMAIS supprimé, même au-delà de la borne : sa
// disparition ferait perdre l'argent de l'acheteur et le transfert. enAttente(x) : vrai pour un accord à garder.
function calGarder(liste,borne,enAttente){
 let exces=liste.length-Math.max(1,borne|0);if(exces<=0)return liste;
 return liste.filter(x=>{if(exces>0&&!enAttente(x)){exces--;return false;}return true;});
}
const calIAAccord=id=>calIAListe('accordsIA').find(a=>a.playerId===id&&a.saison===S.season)||null;
const calIAPre=id=>calIAListe('ia').find(x=>x.playerId===id&&x.etat==='signe'&&x.saison===S.season)||null;
const calPoste=p=>String(p.pos||'').toLowerCase();
const calJourMois=iso=>nativeCalendrierMutations.jourMois(iso.slice(5));
// Joueur engagé par un club géré : raison, '' sinon.
function calIAReserve(id){
 const a=calIAAccord(id);if(a)return 'Transfert conclu avec '+a.acheteur+' : il le rejoindra le '+calDateFr(calArrivee())+'.';
 const x=calIAPre(id);if(x)return 'A signé un pré-contrat avec '+x.acheteur+' pour la saison prochaine.';
 return '';
}
// Plus achetable par un club géré : engagé ailleurs (clubs gérés, accord ou pré-contrat du club joué).
// p (facultatif) : joueur qui a annoncé sa retraite, plus achetable non plus.
const calIAIndisponible=(id,p)=>!!(p&&calRetraite(p))||!!calIAReserve(id)||(typeof calAccordAchat==='function'&&!!calAccordAchat(id))||!!(calEtatValide(S.calendrierMutations)&&calPre(id));
// Fil des transferts (sans courrier) et actualités (S.news, sans la boîte du manager).
function calFil(text){if(!S.economy)return;S.economy.transfers.unshift({season:S.season,round:S.round,text});S.economy.transfers=S.economy.transfers.slice(0,80);}
function calActu(text){if(!Array.isArray(S.news))S.news=[];S.news.unshift(text);S.news=S.news.slice(0,20);}
// Effectif et masse de la saison suivante d'un club géré : contrats qui s'achèvent et départs conclus retirés,
// arrivées conclues ajoutées. engage : indemnités déjà promises. Masse : seule la part partFinsDeContratLiberee des
// salaires qui s'achèvent est retirée (la bascule prolonge la plupart de ces contrats, aiRosterContracts) ; 1 = tous.
// Mouvements du club joué compris (ses achats, ventes et pré-contrats conclus, décision de Léo du 20/11/2026) ; même calcul
// pour le club joué (place de la saison suivante à la conclusion d'un achat). engage : indemnités promises et pas encore
// payées (accords antérieurs à l'encaissement à l'accord).
function calIASuivante(c){
 const acc=calIAListe('accordsIA').filter(a=>a.saison===S.season),pre=calIAListe('ia').filter(x=>x.etat==='signe'&&x.saison===S.season);
 const tous=[...acc,...pre].map(x=>({playerId:x.playerId,pos:x.pos,salaire:x.salaire,de:x.vendeurId,vers:x.acheteurId})).concat(calJoueMouvements());
 const out=new Set(tous.filter(x=>x.de===c.id).map(x=>x.playerId)),inc=tous.filter(x=>x.vers===c.id);
 const part=Math.max(0,Math.min(1,calG()?.masse?.partFinsDeContratLiberee??1));
 let masse=0,n=0,effectif=0;for(const p of c.players){if(out.has(p.id))continue;effectif++;if(p.contractEnd!=null&&p.contractEnd<=S.season){masse+=p.salary*(1-part);continue;}masse+=p.salary;n++;}
 for(const x of inc){masse+=x.salaire;n++;effectif++;}
 const capacite=professionalCapacity(c);
 return {masse,places:capacite-n,n,capacite,effectif,engage:acc.filter(a=>a.acheteurId===c.id&&!a.paye).reduce((s,a)=>s+a.montant,0),postes:new Set(inc.map(x=>x.pos))};
}
const calIAPeutAcheter=(c,salaire,s=calIASuivante(c))=>s.places>0&&s.masse+salaire<=aiRosterWageLimit(c);
// Club géré qui cherche à recruter (GDD § 3 bis) : même seuil qu'avant la v2 (aiRosterMayRecruit : sous max(40, cible) ;
// plans offensifs : jusqu'à cible + 2), lu sur l'effectif projeté (effectif actuel − départs conclus + arrivées conclues),
// pas sur les seuls contrats qui continuent : un tiers des contrats s'achève chaque saison et la plupart sont prolongés à
// la bascule, si bien que la seule « place de la saison suivante » rendait presque tous les clubs acheteurs à chaque tour
// (≈ 80 accords par saison au lieu de 15 à 40). Place et masse de la saison suivante restent exigées.
const calIACherche=(c,large,s=calIASuivante(c))=>calIAPeutAcheter(c,0,s)&&(s.effectif<Math.max(40,aiRosterTarget(c))||!!large&&s.effectif<aiRosterTarget(c)+2);
// Hors période des mutations, seule une part des clubs gérés (participationHorsPeriode, tirage déterministe graine + saison +
// semaine + club) tient le tour : le gros des accords se conclut en mai-juin. 1 = tous les clubs à chaque tour.
function calIAActif(c){
 const G=calG(),motif=calEtatValide(S.calendrierMutations)?S.calendrierMutations.clubsGeres?.motif:null;
 if(!G||motif==='mutations'||motif==='derniere')return true;
 const part=G.participationHorsPeriode??1;if(part>=1)return true;
 return seedHash(venteGraine()+':'+S.season+':'+S.round+':ia-tour:'+c.id)%1000<Math.round(part*1000);
}
// Actualité d'un accord : au plus actusParSemaine par semaine (le fil des transferts et le résumé gardent tout).
function calActuAccord(text){
 const st=calIAEtat(),cle=S.season+':'+S.round;if(st.actus?.cle!==cle)st.actus={cle,n:0};
 if(st.actus.n<(calG().actusParSemaine??4)){st.actus.n++;calActu(text);}
}
// Transferts entre clubs adverses gardés pour la page « Dans le monde » (idée FM27 n° 30, choix de Léo du 23/11/2026) :
// S.mondeTransferts, les 60 plus récents d'abord, jamais purgés à la bascule (le fil S.economy.transfers ne garde que du
// texte). type : 'accord' (indemnité, arrivée à la bascule), 'precontrat' (libre), 'achat' (exécuté tout de suite, ancien
// marché). Club du manager exclu. Apparence copiée pour le portrait de l'article.
function calMondeTransfert(b,s,p,montant,type){
 if(!b||!s||!p||b.id===S.club||s.id===S.club)return;
 const x={date:calJour()||'',saison:S.season,semaine:S.round,type,playerId:p.id,nom:p.name,pos:p.pos,age:p.age,note:Math.round(Number(p.rating)||0),vendeurId:s.id,acheteurId:b.id,montant:Math.max(0,Math.round(Number(montant)||0))};
 for(const k of ['sourcePlayerId','appearanceId','appearanceAge','appearanceBankVersion','appearanceBuild'])if(p[k]!==undefined)x[k]=p[k];
 S.mondeTransferts=[x,...(Array.isArray(S.mondeTransferts)?S.mondeTransferts:[])].slice(0,60);
}
// Accord d'achat d'un club géré (b achète p à s) : le joueur reste à son club jusqu'à la bascule ; l'indemnité passe tout de
// suite d'une caisse à l'autre (paye, décision de Léo du 20/11/2026) et le président de l'acheteur tranche s'il passe sous sa
// réserve (president-reprise.cjs), comme avant la v2.
function calIANouvelAccord(b,s,p,montant,salaire,annees){
 const st=calIAEtat();st.seq++;
 const a={id:'ia-'+st.seq,playerId:p.id,nom:p.name,pos:p.pos,vendeurId:s.id,vendeur:s.name,acheteurId:b.id,acheteur:b.name,montant,salaire,annees,date:calJour()||'',saison:S.season,paye:true};
 st.accordsIA.push(a);st.accordsIA=calGarder(st.accordsIA,calG().accordsGardes,x=>x.saison>=S.season);
 const avant=b.cash;b.cash-=montant;s.cash+=montant;calProlongerCarriere(p,S.season+annees);
 if(typeof repriseApresAchat==='function'&&b.id!==S.club)repriseApresAchat(b,avant);
 const texte=b.name+' s’est mis d’accord avec '+s.name+' pour '+p.name+' ('+calPoste(p)+') : il arrivera le '+calJourMois(calArrivee())+'.';
 calFil(texte.slice(0,-1)+' ('+money(montant)+').');calActuAccord(texte);calMercato('accord',texte,montant);calMondeTransfert(b,s,p,montant,'accord');
 return a;
}
// ---- Résumé du mercato (temps forts, lignes de la semaine) ----
// Ligne d'un gros transfert dans une liste : sans « il arrivera le 1er juillet » (dit une fois) ni point final.
const calTopCourt=s=>{s=String(s).split(' : il arrivera')[0];return s.endsWith('.')?s.slice(0,-1):s;};
function calMercatoEtat(){
 const st=calIAEtat(),j=calJour()||'';let m=st.mercato;
 if(m&&m.ouverture&&!m.bilan&&m.fin&&j>m.fin){
  m.bilan=j;
  const texte='Bilan du mercato : '+(m.n>1?m.n+' transferts entre clubs conclus':m.n===1?'un transfert entre clubs conclu':'aucun transfert entre clubs conclu')+' pendant la période des mutations.'+(m.top.length?' Les plus gros : '+m.top.map(t=>calTopCourt(t.texte)).join(' ; ')+'.':'');
  calActu(texte);calMercatoLigne(m,'temps-fort',texte,0);
 }
 if(!m||m.saison!==S.season)m=st.mercato={saison:S.season,debut:null,fin:null,ouverture:null,derniere:null,bilan:null,n:0,top:[],semaines:{}};
 // Période des mutations de cette saison (juillet à juin) : relue tant qu'elle n'est pas ouverte.
 if(!m.ouverture){
  const f=nativeVenteJoueurs.REGLAGES.fenetres||{},p=f.mode==='fenetres'&&Array.isArray(f.periodes)?f.periodes[0]:null,an=calAnneeFin(S.season),y=p&&p.debut>='07-01'?an-1:an;
  m.debut=p?y+'-'+p.debut:null;m.fin=p?(p.fin<p.debut?y+1:y)+'-'+p.fin:null;
 }
 return m;
}
function calMercatoLigne(m,type,texte,montant){
 const G=calG().mercato,w=String(S.round);(m.semaines[w]??=[]).push({type,texte,montant});m.semaines[w]=m.semaines[w].slice(-G.lignesParSemaine);
 const ks=Object.keys(m.semaines).sort((a,b)=>Number(a)-Number(b));while(ks.length>G.semainesGardees)delete m.semaines[ks.shift()];
}
// Ligne de la semaine ; un accord conclu pendant la période compte pour le bilan (trois plus gros montants).
function calMercato(type,texte,montant=0){
 const m=calMercatoEtat(),j=calJour()||'';calMercatoLigne(m,type,texte,montant);
 if(type==='accord'&&m.debut&&j>=m.debut&&j<=m.fin){m.n++;m.top.push({texte:texte.replace(/ : il arrivera.*$/,'')+', '+money(montant),montant});m.top.sort((a,b)=>b.montant-a.montant);m.top=m.top.slice(0,3);}
}
// Temps forts (après les tours de marché de la semaine) : ouverture, dernière semaine ; le bilan passe par calMercatoEtat.
function calMercatoTempsForts(motif){
 if(!calBascule())return;
 const m=calMercatoEtat(),j=calJour();if(!j||!m.debut||j<m.debut||j>m.fin)return;
 if(!m.ouverture){m.ouverture=j;const t='Ouverture de la période des mutations : les clubs ont jusqu’au '+calDateFr(m.fin)+' pour boucler leurs transferts, qui prendront effet le '+calDateFr(calArrivee())+'.';calActu(t);calMercatoLigne(m,'temps-fort',t,0);}
 if(motif==='derniere'&&!m.derniere){m.derniere=j;const t='Dernière semaine du mercato : les clubs bouclent leurs derniers accords avant le '+calDateFr(m.fin)+'.'+(m.top.length?' Plus gros transferts conclus : '+m.top.map(x=>calTopCourt(x.texte)).join(' ; ')+'.':'');calActu(t);calMercatoLigne(m,'temps-fort',t,0);}
}
// Tours de marché des clubs gérés à cette clôture (club-transfers.cjs). ancien : fenêtre des semaines 0 et 13 ouverte.
function calClubsGeresTours(ancien){
 if(!calBascule())return {tours:ancien?3:0,differe:false,motif:null};
 const j=calJour(),w=S.round;if(!j||S.live||S.phase!=='league')return {tours:0,differe:true,motif:null};
 const st=calIAEtat(),cle=S.season+':'+w;if(st.clubsGeres?.cle===cle)return {tours:0,differe:true,motif:null};
 const t=nativeCalendrierMutations.toursClubs(j,w,S.season,calR(),nativeVenteJoueurs.REGLAGES);
 st.clubsGeres={cle,motif:t.motif};
 return {tours:t.tours,differe:true,motif:t.motif};
}
// ---- Pré-contrats entre clubs gérés, rumeurs (clôture de semaine, calSemaine) ----
// Démentis (chaque clôture, avant le retour hors période des pré-contrats) : une rumeur « fausse » de la saison reçoit son
// démenti à la première clôture à partir de sa date + dementiSemaines (tiré à la création) ; joueur parti de son club :
// sans suite, sans actualité. Les rumeurs sont purgées à la bascule : aucun démenti après.
function calIARumeursDementis(j){
 if(!calEtatValide(S.calendrierMutations)||!Array.isArray(S.calendrierMutations.rumeurs))return;
 for(const r of S.calendrierMutations.rumeurs){
  if(r.saison!==S.season||r.suite!==null||r.piste!=='fausse'||!r.dementi||j<r.dementi)continue;
  const c=S.clubs[r.clubId];if(!c||!c.players.some(p=>p.id===r.playerId)){r.suite='sans-suite';continue;}
  r.suite='dementi';
  const texte=r.interesse+' dément tout intérêt pour '+r.nom+' ('+String(r.pos||'').toLowerCase()+' de '+r.club+').';
  calActu(texte);calMercato('rumeur',texte,0);
 }
}
function calIAPreContrats(){
 const G=calG();if(!G||!calBascule())return;
 const P=G.preContrats,Rm=G.rumeurs,j=calJour();if(!P.actifs||!j)return;
 calIARumeursDementis(j);
 if(S.phase!=='league')return;
 const d=nativeCalendrierMutations.preContratDates(calAnneeFin(S.season),calR());if(j<d.debut||j>d.fin)return;
 const st=calIAEtat(),w=S.round,cle=S.season+':'+w;if(st.iaSemaine===cle)return;st.iaSemaine=cle;
 const graine=venteGraine(),h=k=>seedHash(graine+':'+S.season+':'+w+':ia:'+k);
 const achats=new Map(),departs=new Map();
 for(const x of st.ia)if(x.saison===S.season){achats.set(x.acheteurId,(achats.get(x.acheteurId)||0)+1);departs.set(x.vendeurId,(departs.get(x.vendeurId)||0)+1);}
 const prets=new Set((S.clubDirections?.loans||[]).map(l=>l.playerId)),ligue=new Map(),jlo=id=>{if(!ligue.has(id))ligue.set(id,['jlo-d1','jlo-d2'].includes(CDWorldCareer.leagueId(S,id)));return ligue.get(id);};
 const clubs=S.clubs.filter(c=>c.id!==S.club),suivis=new Map(),enCours=new Set(),fausses=new Set();
 // Rumeur vraie (ou sans piste : sauvegardes antérieures) : prioritaire. Rumeur fausse : pas prioritaire, et le club
 // annoncé ne signe pas ce joueur en pré-contrat cette saison.
 for(const r of st.rumeurs)if(r.saison===S.season){
  if(r.piste==='fausse')fausses.add(r.playerId+':'+r.interesseId);
  if(r.suite===null){enCours.add(r.playerId);if(r.piste!=='fausse')suivis.set(r.playerId,r);}
 }
 let cands=[];
 for(const c of clubs){
  if((departs.get(c.id)||0)>=P.parVendeur)continue;
  const top=new Set(c.players.slice().sort((a,b)=>roleNote(b)-roleNote(a)||(a.id<b.id?-1:1)).slice(0,P.meilleursProteges).map(p=>p.id));
  for(const p of c.players)if(p.contractEnd===S.season&&!top.has(p.id)&&!prets.has(p.id)&&!p.espoirLoan&&(typeof careerContractYears!=='function'||careerContractYears(p)>=2)&&!calIAIndisponible(p.id))cands.push({p,c,k:h(p.id)});
 }
 cands=cands.sort((a,b)=>(suivis.has(b.p.id)?1:0)-(suivis.has(a.p.id)?1:0)||a.k-b.k||(a.p.id<b.p.id?-1:1)).slice(0,P.candidats);
 const n=1+h('n')%Math.max(1,P.parSemaine),nr=Rm&&Rm.actives&&j.slice(5)<=Rm.fin?1+h('r')%Math.max(1,Rm.parSemaine):0;
 let signes=0,rumeurs=0;
 for(const {p,c,k} of cands){
  if(signes>=n&&rumeurs>=nr)break;
  if((departs.get(c.id)||0)>=P.parVendeur)continue;
  const buyers=clubs.filter(b=>b.id!==c.id&&!fausses.has(p.id+':'+b.id)&&(achats.get(b.id)||0)<P.parAcheteur&&jlo(b.id)===jlo(c.id)).map(b=>({b,n:venteBesoin(b,p)})).filter(x=>x.n>=P.besoinMin)
   .sort((x,y)=>y.n-x.n||Math.abs(x.b.base-p.rating)-Math.abs(y.b.base-p.rating)||x.b.id-y.b.id).slice(0,3);
  const salaire=b=>Math.max(270,Math.min(100000,Math.round(Math.max(p.salary,nativeClubTransfers.demand(p,c,b))*P.majorationSalaire/100)*100));
  const rumeur=suivis.get(p.id),ordre=rumeur?[...buyers.filter(x=>x.b.id===rumeur.interesseId),...buyers.filter(x=>x.b.id!==rumeur.interesseId)]:buyers.slice(k%Math.max(1,buyers.length)).concat(buyers.slice(0,k%Math.max(1,buyers.length)));
  const pick=ordre.find(x=>calIAPeutAcheter(x.b,salaire(x.b)));if(!pick)continue;
  const b=pick.b;
  if(signes<n){
   const sal=salaire(b),annees=Math.max(1,Math.min(p.age<=27?3:p.age<=30?2:1,typeof careerContractYears==='function'?careerContractYears(p)-1:3));st.seq++;
   st.ia.push({id:'iapre-'+st.seq,playerId:p.id,nom:p.name,pos:p.pos,vendeurId:c.id,vendeur:c.name,acheteurId:b.id,acheteur:b.name,salaire:sal,annees,date:j,saison:S.season,etat:'signe'});
   st.ia=calGarder(st.ia,P.gardes,x=>x.saison>=S.season&&x.etat==='signe');calProlongerCarriere(p,S.season+annees);
   achats.set(b.id,(achats.get(b.id)||0)+1);departs.set(c.id,(departs.get(c.id)||0)+1);signes++;
   if(rumeur)rumeur.suite='signe';
   const texte=b.name+' a signé '+p.name+' ('+calPoste(p)+' de '+c.name+') pour la saison prochaine.';
   calFil(texte);calActu(texte);calMercato('precontrat',texte,0);calMondeTransfert(b,c,p,0,'precontrat');continue;
  }
  if(rumeurs<nr&&!enCours.has(p.id)){
   // Piste vraie (tauxRealisation) ou fausse : une fausse est démentie dementiSemaines plus tard.
   const hr=k=>seedHash(graine+':'+S.season+':'+w+':'+k+':'+p.id),vraie=hr('rumeur')%1000<Math.round((Rm.tauxRealisation??1)*1000);
   const ds=Array.isArray(Rm.dementiSemaines)?Rm.dementiSemaines:[2,4],sem=ds[0]+hr('dementi')%Math.max(1,ds[1]-ds[0]+1);
   st.seq++;st.rumeurs.push({id:'rumeur-'+st.seq,playerId:p.id,nom:p.name,pos:p.pos,clubId:c.id,club:c.name,interesseId:b.id,interesse:b.name,date:j,saison:S.season,suite:null,piste:vraie?'vraie':'fausse',...(vraie?{}:{dementi:nativeCalendrierMutations.decaler(j,7*sem)})});
   st.rumeurs=st.rumeurs.slice(-Rm.gardees);rumeurs++;
   const texte='Selon la presse, '+b.name+' suit '+p.name+', '+calPoste(p)+' de '+c.name+' en fin de contrat.';
   calActu(texte);calMercato('rumeur',texte,0);
  }
 }
}
// ---- Exécution à la bascule : accords et pré-contrats des clubs gérés (avant leurs prolongations et libérations) ----
// calIAArrivees : arrivées de cette bascule par acheteur ({salaires, ids}), relues par calIAMasseBascule.
let calIAArrivees=null;
// Après les prolongations (aiRosterContracts) : un acheteur que ses arrivées font passer au-dessus de sa limite de masse
// libère, comme pour faire de la place sous un plafond (aiRosterMakeRoom : au plus deux joueurs parmi les moins utiles,
// jamais une arrivée, sans découvrir de poste), de quoi couvrir au plus le salaire de ses arrivées. Réglage
// clubsGeres.masse.libererALaBascule.
function calIAMasseBascule(){
 const arr=calIAArrivees;calIAArrivees=null;
 if(!arr||!calG()?.masse?.libererALaBascule||typeof aiRosterMakeRoom!=='function')return 0;
 let n=0;
 for(const [id,x] of arr){
  const c=S.clubs[id];if(!c||c.id===S.club)continue;
  const dessus=aiRosterPayroll(c)-aiRosterWageLimit(c);if(dessus<=0)continue;
  if(aiRosterMakeRoom(c,Math.min(dessus,x.salaires),x.ids))n++;
 }
 return n;
}
function calIAExecuter(){
 if(!calEtatValide(S.calendrierMutations))return 0;
 const st=calIAEtat();let n=0;
 const arr=calIAArrivees=new Map();
 const placeSuivante=b=>professionalCapacity(b)-b.players.filter(q=>!(q.contractEnd!=null&&q.contractEnd<=S.season)).length;
 // paye : indemnité déjà passée à l'accord (décision de Léo du 20/11/2026) ; sinon (accord d'une sauvegarde antérieure) payée ici.
 const arriver=(p,s,b,salaire,annees,montant,paye)=>{
  s.players=s.players.filter(q=>q.id!==p.id);b.players.push(p);
  if(s.id===S.club){S.lineup=S.lineup.map(x=>x===p.id?null:x);S.reserves=S.reserves.map(x=>x===p.id?null:x);}
  if(montant>0&&!paye){b.cash-=montant;s.cash+=montant;}
  p.formerClub=s.name;p.salary=salaire;p.contractEnd=S.season+annees;p.joinedSeason=S.season+1;p.joinedRound=0;if(montant>0)p.price=montant;
  if(typeof aiRosterEvent==='function'){aiRosterEvent(s.id,montant>0?'sell':'release',p,montant);aiRosterEvent(b.id,'recruit',p,montant);}
  const x=arr.get(b.id)||{salaires:0,ids:new Set()};x.salaires+=salaire;x.ids.add(p.id);arr.set(b.id,x);
 };
 for(const a of st.accordsIA){
  if(a.saison!==S.season)continue;
  const s=S.clubs[a.vendeurId],b=S.clubs[a.acheteurId];
  // Accord payé : toujours honoré (ni place ni moyens revérifiés), même si le manager a rejoint l'un des deux clubs ; seul cas
  // de chute : le joueur n'est plus au vendeur (il ne devrait plus arriver), l'indemnité est alors rendue.
  if(a.paye){
   const p=s&&b?s.players.find(q=>q.id===a.playerId):null;
   if(!p){
    if(s&&b&&a.montant>0){b.cash+=a.montant;s.cash-=a.montant;}
    const t='Le transfert de '+a.nom+' à '+a.acheteur+' tombe : '+a.nom+' ne fait plus partie de '+a.vendeur+'. L’indemnité est rendue.';calFil(t);calActu(t);continue;
   }
   arriver(p,s,b,a.salaire,a.annees,a.montant,true);n++;
   calFil(p.name+' rejoint '+b.name+' ('+money(a.montant)+' à '+s.name+') : transfert effectif au changement de saison.');
   continue;
  }
  const p=s&&s.id!==S.club?s.players.find(q=>q.id===a.playerId):null;
  const raison=!p?a.nom+' ne fait plus partie de '+a.vendeur:!b||b.id===S.club?a.acheteur+' ne gère plus son recrutement':b.cash<a.montant?a.acheteur+' n’a plus les moyens de payer l’indemnité':placeSuivante(b)<=0?a.acheteur+' n’a plus de place dans son effectif':'';
  if(raison){const t='Le transfert de '+a.nom+' à '+a.acheteur+' tombe : '+raison+'.';calFil(t);calActu(t);continue;}
  arriver(p,s,b,a.salaire,a.annees,a.montant,false);n++;
  calFil(p.name+' rejoint '+b.name+' ('+money(a.montant)+' à '+s.name+') : transfert effectif au changement de saison.');
 }
 st.accordsIA=st.accordsIA.filter(a=>a.saison>S.season);
 for(const x of st.ia){
  if(x.saison!==S.season||x.etat!=='signe')continue;
  const s=S.clubs[x.vendeurId],b=S.clubs[x.acheteurId],p=s&&s.id!==S.club?s.players.find(q=>q.id===x.playerId):null;
  // Pré-contrat honoré même si l'acheteur manque de place (il s'ajuste ensuite, calCapaciteBascule).
  if(!p||p.contractEnd>S.season||!b||b.id===S.club){x.etat='tombe';continue;}
  arriver(p,s,b,x.salaire,x.annees,0,true);x.etat='execute';n++;
  calFil(p.name+' rejoint '+b.name+' libre, comme prévu par son pré-contrat.');
 }
 // Le président d'un club géré tranche désormais à la conclusion de ses accords (calIANouvelAccord), plus à la bascule.
 st.ia=st.ia.filter(x=>x.saison>=S.season);st.rumeurs=st.rumeurs.filter(r=>r.saison>S.season);
 return n;
}
// Offres reçues par le club joué (vente-joueurs.cjs, clôture de semaine) : indemnité plafonnée ; aucun club n'achète un
// joueur dont le contrat s'achève cette saison (offres retirées, hors accords exécutés).
function calOffresBascule(){
 if(!calBascule()||!S.economy)return;
 S.economy.offers=S.economy.offers.filter(o=>{
  if(String(o.id).startsWith('accord-'))return true;
  const p=player(o.playerId);if(!p)return true;
  if(p.contractEnd!=null&&p.contractEnd<=S.season)return false;
  if(!o.countered)o.fee=calIndemnite(p,o.fee);return true;
 });
}
// Joueur du club joué en fin de contrat : plus de vente possible (v2).
const calRaisonVenteFin=p=>calBascule()&&p.contractEnd!=null&&p.contractEnd<=S.season?'Son contrat s’achève cette saison : aucun club ne l’achètera, il partira libre s’il n’est pas prolongé.':'';
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

module.exports = Object.freeze({ REGLAGES, periode, libres, interclub, jokers, preContratDates, prime, approcheTiree, decaler, jourMois, calendrierClubs, plafondIndemnite, indemnite, toursClubs, BRANCHEMENT });
