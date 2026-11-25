'use strict';
// Vente de joueurs (docs/gdd/vente-joueurs.md, décisions de Léo du 19/11/2026). Le manager propose un joueur aux autres
// clubs (liste existante de dist/economy.js), reçoit leurs offres à la clôture de la semaine, et les clubs font aussi
// quelques offres spontanées pour ses meilleurs joueurs non proposés. Réponses : accepter (confirmation), demander plus
// (une fois, montant au millier), refuser. Garde d'effectif (même seuil que le marché entre clubs), mention JIFF non
// bloquante, fenêtre des transferts réglable (réglage en attente de décision), courrier « offre_transfert ».
// Correction de coût : pendant economyWeek, les besoins de recrutement sont calculés une fois par club (même résultat).
// Réglages : vente-joueurs.json (lu à chaque calcul). Mode Monde.
const REGLAGES = require('./vente-joueurs.json');

const fini = x => typeof x === 'number' && Number.isFinite(x);
// Montants du club : espace des milliers, « € » (« 1 160 000 € »).
const euros = n => String(Math.round(Math.abs(n))).replace(/\B(?=(\d{3})+(?!\d))/g, ' ') + ' €';
// Même hachage que seedHash (dist/rugby.js) : FNV-1a 32 bits.
function hash(text) { let h = 2166136261; for (const ch of String(text)) { h ^= ch.charCodeAt(0); h = Math.imul(h, 16777619); } return h >>> 0; }

// « Demander plus » : nouveau montant, arrondi au millier supérieur (réglage relances.arrondi).
function relance(fee, pourcent, R = REGLAGES) {
  const pas = R.relances.arrondi > 0 ? R.relances.arrondi : 1;
  return Math.ceil(fee * (1 + pourcent / 100) / pas) * pas;
}
// Plafond de l'acheteur : au-delà, il retire son offre.
function plafond(fee, caisse, besoin, R = REGLAGES) {
  const r = R.relances, pas = r.arrondi > 0 ? r.arrondi : 1;
  return Math.floor(Math.min(caisse - r.reserveAcheteur, fee * (r.margeBase + Math.max(0, besoin) / r.margeBesoin)) / pas) * pas;
}

// Offres spontanées : la semaine `semaine` de la saison est-elle tirée ? Déterministe (graine, saison, semaine) et sans
// état : on recompte les semaines tirées depuis semaineMin pour respecter maxParSaison.
const tirage = (graine, saison, semaine, s) => hash(graine + ':' + saison + ':' + semaine + ':spontanee') % 1000 < Math.round(s.chanceSemaine * 1000);
function semaineTiree(graine, saison, semaine, R = REGLAGES) {
  const s = R.spontanees;
  if (!s.actives || !Number.isInteger(semaine) || semaine < s.semaineMin || !tirage(graine, saison, semaine, s)) return false;
  let avant = 0;
  for (let w = s.semaineMin; w < semaine; w++) if (tirage(graine, saison, w, s)) avant++;
  return avant < s.maxParSaison;
}

// Fenêtre des transferts (réglage en attente de décision). `jour` : AAAA-MM-JJ. Rend {ouverte, reouverture, raison}.
const MOIS = ['janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'];
const dateFr = iso => { const [a, m, j] = iso.split('-').map(Number); return (j === 1 ? '1er' : String(j)) + ' ' + MOIS[m - 1] + ' ' + a; };
const dans = (md, p) => p.debut <= p.fin ? md >= p.debut && md <= p.fin : md >= p.debut || md <= p.fin;
function fenetre(jour, R = REGLAGES) {
  const f = R.fenetres || {};
  if (f.mode !== 'fenetres' || typeof jour !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(jour)) return { mode: f.mode === 'fenetres' ? 'fenetres' : 'saison', ouverte: true, reouverture: null, raison: '' };
  const md = jour.slice(5), periodes = Array.isArray(f.periodes) ? f.periodes : [];
  if (periodes.some(p => dans(md, p))) return { mode: 'fenetres', ouverte: true, reouverture: null, raison: '' };
  const an = Number(jour.slice(0, 4));
  const prochaines = periodes.map(p => { const d = an + '-' + p.debut; return d > jour ? d : (an + 1) + '-' + p.debut; }).sort();
  const reouverture = prochaines[0] || null;
  return { mode: 'fenetres', ouverte: false, reouverture, raison: reouverture ? 'Hors période des mutations : une vente acceptée sera effective le ' + dateFr(reouverture) + '.' : 'Hors période des mutations.' };
}

// Code exécuté dans le moteur (après budget-transferts.cjs). Attend : nativeVenteJoueurs (ce module), les fonctions
// de dist/economy.js (economyWeek, acceptSale, saleBlocked, transferValue…), recruitmentNeeds, nativeSystems.
const BRANCHEMENT = `
const venteReglages=()=>nativeVenteJoueurs.REGLAGES;
const venteGraine=()=>Number.isInteger(S?.careerVariation?.seed)?S.careerVariation.seed:0;
const venteSemaine=()=>S.worldMode?.week??S.round;
const venteJour=()=>typeof CDWorldCareer!=='undefined'&&typeof CDWorldCareer.calendarToday==='function'&&CDWorldCareer.active(S)?CDWorldCareer.calendarToday(S):null;
// v2 (calendrier-mutations.cjs, calFenetreAccords) : accords toujours différés jusqu'au changement de saison.
const venteFenetre=()=>(typeof calFenetreAccords==='function'?calFenetreAccords():null)||nativeVenteJoueurs.fenetre(venteJour(),venteReglages());
const venteMinimum=()=>{const d=typeof nativeSystems!=='undefined'?nativeSystems.domain('interclubMarket'):null;return d&&typeof d.releasePolicy==='function'?d.releasePolicy(S).minimum:37;};
const venteEuros=n=>nativeVenteJoueurs.euros(n);
// Joueurs prêtés cette saison (mêmes listes que le marché entre clubs).
const venteLoans=()=>new Set([S.v78to81,...Object.values(S.nativeAcademy?.offices||{}).map(o=>o.v78to81)].flatMap(o=>o?.loans||[]).filter(l=>l.season===S.season).map(l=>l.id));
// Accords conclus hors période (S.venteJoueurs) : exécutés à l'ouverture suivante. Lecture tolérante (état illisible :
// aucun accord), écriture seulement à la conclusion ou à l'exécution.
const venteEtatValide=v=>!!v&&typeof v==='object'&&v.version===1&&Array.isArray(v.accords)&&Array.isArray(v.evenements)&&Number.isInteger(v.seq);
function venteEtat(ecrire=false){
 if(venteEtatValide(S.venteJoueurs))return S.venteJoueurs;
 const neuf={version:1,seq:0,accords:[],evenements:[]};if(ecrire)S.venteJoueurs=neuf;return neuf;
}
// Accords de vente d'un joueur du club joué (sens « vente », par défaut). Les accords d'achat (sens « achat »,
// calendrier-mutations.cjs) partagent la même liste et la même exécution à l'ouverture.
const venteAccord=id=>venteEtat().accords.find(a=>a.playerId===id&&a.clubId===S.club&&a.sens!=='achat')||null;
// Nouvel accord différé (vente choisie, vente imposée, achat) : exécuté à la première clôture de semaine à partir de a.date.
// bascule : exécuté au changement de saison (settleContracts, calendrier-mutations.cjs), plus à une clôture de semaine.
const venteBasculeChamp=()=>typeof calFenetreAccords==='function'&&calFenetreAccords()?{bascule:true}:{};
// Vente « bascule » (choisie ou imposée) : encaissée à la conclusion (venteEncaisser, décision de Léo du 20/11/2026).
function venteNouvelAccord(champs){const st=venteEtat(true);st.seq++;const a={id:'accord-'+st.seq,clubId:S.club,conclu:venteJour()||'',...venteBasculeChamp(),...champs};st.accords.push(a);if(a.bascule&&a.sens!=='achat')venteEncaisser(a);return a;}
// Encaissement d'une vente du club joué à l'accord (le joueur part au 1er juillet) : caisse de l'acheteur débitée, ligne de
// caisse, part rendue au budget de transferts de la saison en cours (vente choisie, a.rendu), prêt de l'actionnaire
// remboursé (vente pour le prêt) ; le joueur ne prend pas sa retraite avant la fin de son nouveau contrat. a.paye = vrai.
function venteEncaisser(a){
 const buyer=S.clubs[a.buyer],p=player(a.playerId),quand=typeof calJourMois==='function'?calJourMois(a.date):nativeVenteJoueurs.dateFr(a.date);
 buyer.cash-=a.fee;
 ledgerEntry((a.imposee&&!a.pret?'Vente décidée par le président : ':'Vente : ')+a.joueur+' (départ le '+quand+')',a.fee);
 if(!a.imposee&&typeof budgetTransfertsRecette==='function')a.rendu=budgetTransfertsRecette(a.fee,true)||0;
 if(a.pret&&typeof pretRembourser==='function'){const reste=S.pretsActionnaires?.[S.club]?.restant||0,r=Math.min(reste,a.fee);if(r>0){a.pretRendu=r;a.pretAvant={...S.pretsActionnaires[S.club]};(typeof ledgerEntryV1==='function'?ledgerEntryV1:ledgerEntry)('Remboursement anticipé du prêt de l’actionnaire',-r);pretRembourser(S.club,r,true);}}
 if(p&&typeof calProlongerCarriere==='function')calProlongerCarriere(p,Math.max(p.contractEnd??S.season,S.season+1));
 a.paye=true;
}
// Raison pour laquelle un joueur ne peut pas être proposé ('' : possible).
function venteRaisonListe(p,loans=venteLoans()){
 const a=venteAccord(p.id);if(a)return 'Vente conclue avec '+(S.clubs[a.buyer]?.name||'un club')+' : départ le '+nativeVenteJoueurs.dateFr(a.date)+'.';
 const pre=typeof preContratSigne==='function'?preContratSigne(p.id):null;if(pre&&pre.sens==='depart')return 'A signé un pré-contrat avec '+pre.autre+' : il part libre le '+nativeVenteJoueurs.dateFr(pre.arrivee)+'.';
 const rt=typeof calRaisonRetraite==='function'?calRaisonRetraite(p):'';if(rt)return rt;
 const fin=typeof calRaisonVenteFin==='function'?calRaisonVenteFin(p):'';if(fin)return fin;
 if(S.live)return 'Match en cours : attends la fin de la journée.';
 if(p.espoirLoan)return 'Appelé du centre de formation : il n’a pas de contrat professionnel.';
 if(loans.has(p.id))return 'Joueur concerné par un prêt cette saison.';
 return saleBlocked(p)||'';
}
// Garde d'effectif du club joué (décision de Léo du 19/11/2026, fin du plancher de 40) : après le départ, les seuls
// professionnels (espoirs appelés exclus, blessures et suspensions ignorées) doivent encore tenir une feuille de 23
// (premières lignes comprises, même composition que buildSheet) ; garde par famille inchangée. Raison du refus, ou ''.
const VENTE_BANC=[1,0,2,3,5,8,9,10];
function venteFeuilleManque(p,c=club()){
 const pros=c.players.filter(q=>q.id!==p.id&&!q.espoirLoan).map(q=>({...q,injury:0,suspension:0,condition:100}));
 const sh=buildSheet({...c,players:pros});
 return [...new Set(sh.lineup.concat(sh.bench).flatMap((x,i)=>x?[]:[POS[i<15?i:VENTE_BANC[i-15]].toLowerCase()]))];
}
function venteGarde(p,c=club()){
 if(c.id===S.club&&typeof buildSheet==='function'){const manque=venteFeuilleManque(p,c);if(manque.length)return 'Après ce départ, tu ne pourrais plus aligner une feuille de 23 complète (manque : '+manque.join(', ')+').';}
 else{const min=venteMinimum();if(c.players.length<=min)return 'Tu dois garder au moins '+min+' joueurs professionnels.';}
 if(p.fam===0&&c.players.filter(q=>q.id!==p.id&&q.pos===p.pos).length<2)return 'Tu dois garder au moins deux piliers de chaque côté.';
 if(c.players.filter(q=>q.id!==p.id&&q.fam===p.fam).length<2)return 'Tu dois garder au moins deux joueurs de cette famille de poste.';
 return '';
}
// Mention JIFF (non bloquante) : « Tu garderas n JIFF. » si le joueur compte pour le quota.
function venteJiff(p){
 if(typeof CDJiff==='undefined'||!CDJiff||typeof CDJiff.quota!=='function'||S.jiff?.version!==1)return '';
 const q=CDJiff.quota(S,S.club);if(!q||!CDJiff.qualifies(S,S.club,p))return '';
 const n=club().players.filter(x=>x.id!==p.id&&CDJiff.qualifies(S,S.club,x)).length;
 return 'Tu garderas '+n+' '+q.label+(n>1?' dans l’effectif.':' dans l’effectif.');
}
const venteBesoin=(c,p)=>Math.max(0,...recruitmentNeeds(c).filter(n=>slotEligible(p,n.slot)).map(n=>n.score));
// Offre spontanée de la semaine (au plus une), pour un des meilleurs joueurs non proposés : null si rien.
function venteSpontanee(){
 const R=venteReglages().spontanees;if(!R.actives||!S.worldMode)return null;
 const e=S.economy,semaine=venteSemaine(),graine=venteGraine();
 if(!nativeVenteJoueurs.semaineTiree(graine,S.season,semaine,venteReglages()))return null;
 const pris=new Set(e.offers.map(o=>o.playerId)),loans=venteLoans();
 const cands=club().players.filter(p=>!e.listings[p.id]&&!pris.has(p.id)&&!venteRaisonListe(p,loans)&&!venteGarde(p))
  .sort((a,b)=>roleNote(b)-roleNote(a)||(a.id<b.id?-1:a.id>b.id?1:0)).slice(0,R.candidats);
 const h=seedHash(graine+':'+S.season+':'+semaine+':joueur'),pas=R.arrondi>0?R.arrondi:1,ecart=Math.max(0,Math.round((R.fourchette[1]-R.fourchette[0])*100));
 for(let k=0;k<cands.length;k++){
  const p=cands[(h+k)%cands.length];
  const fee=Math.round(transferValue(p)*(R.fourchette[0]+(h%(ecart+1))/100)/pas)*pas;
  const buyers=S.clubs.filter(c=>c.id!==S.club&&c.cash>=fee+R.reserveAcheteur&&professionalPlaces(c)>0).map(c=>({c,b:venteBesoin(c,p)})).filter(x=>x.b>=R.besoinMin)
   .sort((x,y)=>y.b-x.b||Math.abs(x.c.base-(typeof niveauMatch==='function'?niveauMatch(p):p.rating))-Math.abs(y.c.base-(typeof niveauMatch==='function'?niveauMatch(p):p.rating))||x.c.id-y.c.id);
  if(!buyers.length)continue;
  const o={id:'offre-spontanee-'+e.week+'-'+p.id,playerId:p.id,buyer:buyers[h%Math.min(3,buyers.length)].c.id,fee,expires:e.week+1,spontaneous:true};
  e.offers.push(o);return o;
 }
 return null;
}
// Correction de coût : pendant economyWeek, recruitmentNeeds(club) est calculé une fois par club (mêmes valeurs,
// mêmes graines ; la liste rendue n'est jamais modifiée par ses lecteurs). nativeVenteMemo=false la coupe (test d'égalité).
let nativeVenteMemo=true;
const economyWeekVenteV1=economyWeek;
economyWeek=function(){
 const base=recruitmentNeeds,memo=new Map();
 if(nativeVenteMemo)recruitmentNeeds=function(c){if(arguments.length!==1||!c||typeof c!=='object')return base.apply(this,arguments);let r=memo.get(c);if(!r){r=base.call(this,c);memo.set(c,r);}return r;};
 // Pré-contrats (calendrier-mutations.cjs) : approches des autres clubs, sous la même mémoire des besoins.
 try{venteExecuterAccords();const r=economyWeekVenteV1.apply(this,arguments);venteSpontanee();if(typeof calOffresBascule==='function')calOffresBascule();if(typeof calSemaine==='function')calSemaine();return r;}finally{recruitmentNeeds=base;}
};
function venteEvenement(ev){
 const st=venteEtat(true);st.seq++;st.evenements.push({id:'vente-'+st.seq,date:venteJour()||'',...ev});
 st.evenements=st.evenements.slice(-Math.max(1,venteReglages().accords.evenementsGardes));
}
// Exécution des accords arrivés à échéance (clôture de semaine, hors match) : garde d'effectif et moyens de l'acheteur
// revérifiés ; sinon l'accord tombe, avec la raison. Un accord d'un autre club (manager parti) disparaît sans effet.
// quand : absent = clôture de semaine (accords datés d'avant la v2) ; 'achats' / 'ventes' = changement de saison (accords
// « bascule » ; la garde d'effectif n'est plus revérifiée : l'été sert à compléter l'effectif). Rend le nombre exécuté.
function venteExecuterAccords(quand){
 if(!venteEtatValide(S.venteJoueurs)||!S.venteJoueurs.accords.length||S.live)return 0;
 const jour=venteJour();if(!jour)return 0;
 const st=S.venteJoueurs,dus=st.accords.filter(a=>quand?a.bascule&&(quand==='achats')===(a.sens==='achat'):!a.bascule&&a.date<=jour);if(!dus.length)return 0;
 st.accords=st.accords.filter(a=>!dus.includes(a));let n=0;
 for(const a of dus){
  // Accord payé à la conclusion (paye) : honoré même si le manager a changé de club (transfert entre ces deux clubs).
  if(a.clubId!==S.club&&!a.paye)continue;
  // Achat d'un joueur sous contrat (calendrier-mutations.cjs) : revérifié et exécuté par le marché entre clubs.
  if(a.sens==='achat'){if(typeof calExecuterAchat==='function'&&calExecuterAchat(a))n++;continue;}
  if(a.paye){if(venteExecuterPaye(a))n++;continue;}
  const p=player(a.playerId),buyer=S.clubs[a.buyer];
  const base={joueur:a.joueur,acheteur:buyer?.name||a.acheteur,montant:a.fee,playerId:a.playerId,buyerId:a.buyer};
  const raison=!p?'Le joueur ne fait plus partie de l’effectif.':!buyer?'Le club acheteur n’existe plus.':(quand?'':venteGarde(p))||(buyer.cash<a.fee||professionalPlaces(buyer)<=0?buyer.name+' n’a plus les moyens ou plus de place dans son effectif.':'');
  if(raison){venteEvenement({type:'annulee',raison,...base});transferEvent('L’accord avec '+base.acheteur+' pour '+a.joueur+' tombe : '+raison.replace(/\\.$/,'')+'.');continue;}
  setupEconomy();const e=S.economy,id='accord-'+a.id;
  e.offers=e.offers.filter(o=>o.playerId!==p.id);e.offers.push({id,playerId:p.id,buyer:buyer.id,fee:a.fee,expires:e.week});
  // Vente imposée (président, prêt de l'actionnaire) : rien au budget de transferts, pas de conséquences de vestiaire ;
  // le prix d'une vente pour le prêt rembourse l'actionnaire à l'exécution.
  const cons=a.imposee?null:venteConsequences(p),vendre=()=>acceptSale(id);
  if((a.imposee&&typeof budgetTransfertsImposee==='function'?budgetTransfertsImposee(vendre):vendre())===true){
   if(cons)venteAppliquerConsequences(cons);
   if(a.pret&&typeof pretRembourser==='function'){const reste=S.pretsActionnaires?.[S.club]?.restant||0,r=Math.min(reste,a.fee);if(r>0){(typeof ledgerEntryV1==='function'?ledgerEntryV1:ledgerEntry)('Remboursement anticipé du prêt de l’actionnaire',-r);pretRembourser(S.club,r,true);}}
   venteEvenement({type:'executee',raison:'',...base});n++;}
  else{e.offers=e.offers.filter(o=>o.id!==id);venteEvenement({type:'annulee',raison:'La vente n’a pas pu être enregistrée.',...base});}
 }
 return n;
}
// Vente payée à l'accord (décision de Léo du 20/11/2026) : le joueur part au changement de saison, sans revérifier ni
// l'acheteur ni la garde d'effectif ; conséquences de vestiaire au départ (vente choisie du club joué). Seul cas de chute :
// le joueur n'est plus au club vendeur ; l'argent est alors rendu (caisses, ligne de caisse, part du budget retirée).
function venteExecuterPaye(a){
 const vendeur=S.clubs[a.clubId],buyer=S.clubs[a.buyer],joue=a.clubId===S.club,p=vendeur&&buyer?vendeur.players.find(q=>q.id===a.playerId):null;
 const base={joueur:a.joueur,acheteur:buyer?.name||a.acheteur,montant:a.fee,playerId:a.playerId,buyerId:a.buyer};
 if(!p){
  if(buyer)buyer.cash+=a.fee;
  if(joue){
   ledgerEntry('Vente annulée : '+a.joueur,-a.fee);
   // Vente pour le prêt de l'actionnaire : le remboursement fait à l'accord est annulé, la dette revient (ligne de caisse inverse).
   if(a.pretRendu>0&&typeof pretRestituer==='function'&&pretRestituer(S.club,a.pretRendu,a.pretAvant))(typeof ledgerEntryV1==='function'?ledgerEntryV1:ledgerEntry)('Remboursement du prêt de l’actionnaire annulé',a.pretRendu);
   const e=S.budgetTransferts;if(a.rendu>0&&e&&e.clubId===S.club&&e.saison===S.season)e.reconstitue=Math.max(0,Math.round(e.reconstitue-a.rendu));
   const raison='Le joueur ne fait plus partie de l’effectif.';
   venteEvenement({type:'annulee',raison,...base});transferEvent('L’accord avec '+base.acheteur+' pour '+a.joueur+' tombe : '+raison.replace(/\\.$/,'')+'. L’indemnité est rendue.');
  }else if(vendeur)vendeur.cash-=a.fee;
  return false;
 }
 const cons=joue&&!a.imposee?venteConsequences(p):null;
 vendeur.players=vendeur.players.filter(q=>q.id!==p.id);buyer.players.push(p);
 p.contractEnd=Math.max(p.contractEnd??S.season+1,S.season+1);p.formerClub=vendeur.name;p.joinedSeason=S.season+1;p.joinedRound=0;
 if(S.economy){delete S.economy.listings[p.id];S.economy.offers=S.economy.offers.filter(o=>o.playerId!==p.id);}
 if(vendeur.id===S.club||buyer.id===S.club){S.lineup=S.lineup.map(x=>x===p.id?null:x);S.reserves=S.reserves.map(x=>x===p.id?null:x);}
 if(vendeur.id===S.club&&typeof repairSheet==='function')repairSheet();
 if(typeof aiRosterEvent==='function'&&buyer.id!==S.club)aiRosterEvent(buyer.id,'recruit',p,a.fee);
 if(cons)venteAppliquerConsequences(cons);
 transferEvent(p.name+' rejoint '+buyer.name+' : vente de '+venteEuros(a.fee)+' effective au changement de saison.');
 if(joue)venteEvenement({type:'executee',raison:'',...base});
 return true;
}
const venteOffre=id=>S.economy?.offers?.find(o=>o.id===id)||null;
// Raison pour laquelle une offre ne peut pas être acceptée ('' : possible).
function venteRaisonAccepter(o){
 const e=S.economy,p=o&&player(o.playerId),buyer=o&&S.clubs[o.buyer];
 if(S.live)return 'Match en cours : attends la fin de la journée.';
 if(!p||!buyer||o.expires<e.week)return 'Cette offre n’est plus disponible.';
 if(venteAccord(p.id))return 'Un accord est déjà conclu pour ce joueur.';
 const rt=typeof calRaisonRetraite==='function'?calRaisonRetraite(p):'';if(rt)return rt;
 const g=venteGarde(p);if(g)return g;
 // v2 (accord encaissé tout de suite, joueur au 1er juillet) : réserve de l'acheteur après l'indemnité et place de sa saison
 // suivante (arrivées et départs conclus compris), vérifiées à l'accord.
 const f=typeof calFenetreAccords==='function'?calFenetreAccords():null;
 if(f&&typeof calIASuivante==='function'){if(buyer.cash-o.fee<venteReglages().relances.reserveAcheteur||calIASuivante(buyer).places<=0)return 'Plus disponible : '+buyer.name+' n’a plus les moyens ou plus de place dans son effectif.';}
 else if(buyer.cash<o.fee||professionalPlaces(buyer)<=0)return 'Plus disponible : '+buyer.name+' n’a plus les moyens ou plus de place dans son effectif.';
 return '';
}
function venteRaisonRelance(o){
 const p=o&&player(o.playerId);
 if(S.live)return 'Match en cours : attends la fin de la journée.';
 if(!p||o.expires<S.economy.week)return 'Cette offre n’est plus disponible.';
 if(o.countered)return 'Tu as déjà demandé plus : accepte ou refuse cette offre.';
 return '';
}
// Joueurs de complément après la vente : aucun pour le club joué (fin du plancher de 40, décision de Léo du 19/11/2026).
const venteComplements=n=>0;
// Conséquences légères d'une vente choisie (réglages « consequences ») : calculées avant le départ, sur les jauges
// existantes ; textes annoncés dans la confirmation. Le moteur n'a ni capitaine ni statut « emblématique » : le leader du
// vestiaire (CDRelationsV70.leader) et les meilleurs joueurs par note au poste en tiennent lieu.
const venteBorne=(x,a,b)=>Math.max(a,Math.min(b,Math.round(x)));
function venteConsequences(p,cashAvant=club().cash){
 const R=venteReglages().consequences,vide={leader:false,cadre:false,proches:[],renfloue:false,textes:[]};
 if(!R||!R.actives||!p)return vide;
 const own=club(),leaderId=typeof CDRelationsV70!=='undefined'&&typeof CDRelationsV70.leader==='function'?CDRelationsV70.leader(S)?.id??null:null;
 const meilleurs=own.players.slice().sort((a,b)=>roleNote(b)-roleNote(a)||(a.id<b.id?-1:a.id>b.id?1:0)).slice(0,Math.max(0,R.meilleurs)).map(x=>x.id);
 const leader=leaderId===p.id,cadre=leader||meilleurs.includes(p.id);
 const proches=(Array.isArray(S.v70Relations?.pairs)?S.v70Relations.pairs:[]).filter(x=>x.score>0&&(x.a===p.id||x.b===p.id)).map(x=>own.players.find(q=>q.id===(x.a===p.id?x.b:x.a)))
  .filter(q=>q&&q.satisfaction&&Number.isFinite(q.satisfaction.score)).sort((a,b)=>a.id<b.id?-1:a.id>b.id?1:0);
 const reserve=S.clubBudget?.clubs?.[S.club]?.reserve,renfloue=Number.isFinite(reserve)&&reserve>0&&cashAvant<reserve&&R.confiancePresident>0;
 const textes=[];
 if(proches.length&&R.satisfactionProches)textes.push('Ce départ touchera le vestiaire : '+proches.map(q=>q.name).join(', ')+(proches.length>1?' perdront':' perdra')+' un peu de moral.');
 if(leader&&R.moralGroupeLeader)textes.push('C’est le leader du vestiaire : le moral du groupe baissera légèrement.');
 if(cadre&&R.supportersCadre&&Number.isFinite(S.pressRelations?.fanTrust))textes.push('C’est un cadre de l’équipe : les supporters le regretteront.');
 if(renfloue)textes.push('Le président apprécie : la vente renfloue une caisse passée sous la réserve du club.');
 return {leader,cadre,proches:proches.map(q=>q.id),renfloue,textes};
}
function venteAppliquerConsequences(c){
 const R=venteReglages().consequences;if(!R||!R.actives||!c)return;
 for(const id of c.proches){const q=player(id);if(q?.satisfaction&&Number.isFinite(q.satisfaction.score))q.satisfaction.score=venteBorne(q.satisfaction.score+R.satisfactionProches,20,95);}
 if(c.leader&&R.moralGroupeLeader)S.morale=venteBorne((S.morale??70)+R.moralGroupeLeader,25,98);
 if(c.cadre&&R.supportersCadre&&Number.isFinite(S.pressRelations?.fanTrust))S.pressRelations.fanTrust=venteBorne(S.pressRelations.fanTrust+R.supportersCadre,0,100);
 if(c.renfloue)S.trust=venteBorne((S.trust??50)+R.confiancePresident,0,100);
}
const venteNoteAccord=f=>f.bascule?'Accord conclu maintenant, effectif le '+nativeVenteJoueurs.dateFr(f.reouverture)+' (changement de saison). L’argent est encaissé tout de suite ; le joueur reste au club et joue jusque-là.':'Hors période des mutations : accord conclu, effectif le '+nativeVenteJoueurs.dateFr(f.reouverture)+'. Le joueur reste au club et joue jusque-là ; l’argent arrive à son départ.';
function venteRetourBudget(fee){
 const ctx=typeof budgetTransfertsContexte==='function'?budgetTransfertsContexte():null;
 return ctx?nativeBudgetTransferts.rendu(ctx.e,fee,ctx.recettes,nativeBudgetTransferts.REGLAGES):0;
}
// Vue d'un joueur de l'effectif : squad[].sale.
function venteVueJoueur(p,loans=venteLoans()){
 const o=(S.economy?.offers||[]).find(x=>x.playerId===p.id&&x.expires>=S.economy.week),a=venteAccord(p.id);
 return {listed:!!S.economy?.listings?.[p.id],value:Math.round(transferValue(p)),blocked:venteRaisonListe(p,loans),offerId:o?o.id:null,pending:a?venteVueAccord(a):null};
}
const venteVueAccord=a=>({id:a.id,playerId:a.playerId,name:a.joueur,buyerId:a.buyer,buyer:S.clubs[a.buyer]?.name||a.acheteur,fee:a.fee,date:a.date,dateLabel:nativeVenteJoueurs.dateFr(a.date),concluded:a.conclu,
 ...(a.imposee?{imposed:true}:{}),label:(a.imposee?'Vente décidée par le président : départ pour ':'Vente en attente : départ pour ')+(S.clubs[a.buyer]?.name||a.acheteur)+' le '+nativeVenteJoueurs.dateFr(a.date)+' ('+venteEuros(a.fee)+').'});
// Vue des ventes (model.sales) : joueurs proposés, offres reçues avec ce que chaque réponse permet.
function venteVue(){
 if(!S?.economy)return {available:false,listed:[],offers:[],window:null,minimum:37,squadSize:0};
 const e=S.economy,loans=venteLoans(),own=club(),sheet=new Set([...S.lineup,...S.reserves]),f=venteFenetre();
 const listed=Object.keys(e.listings).map(id=>player(id)).filter(Boolean).map(p=>({playerId:p.id,name:p.name,pos:p.pos,age:p.age,value:Math.round(transferValue(p)),blocked:venteRaisonListe(p,loans),offerId:e.offers.find(o=>o.playerId===p.id&&o.expires>=e.week)?.id??null}));
 const offers=e.offers.filter(o=>o.expires>=e.week).map(o=>{
  const p=player(o.playerId),buyer=S.clubs[o.buyer];if(!p||!buyer)return null;
  const raison=venteRaisonAccepter(o),relance=venteRaisonRelance(o);
  return {id:o.id,playerId:p.id,name:p.name,pos:p.pos,age:p.age,salary:p.salary,buyerId:buyer.id,buyer:buyer.name,fee:o.fee,value:Math.round(transferValue(p)),
   lastWeek:o.expires,weeksLeft:o.expires-e.week,spontaneous:!!o.spontaneous,listed:!!e.listings[p.id],countered:o.countered??null,onSheet:sheet.has(p.id),
   accept:{available:!raison,reason:raison},counter:{available:!relance,reason:relance,percents:venteReglages().relances.pourcents.slice()},
   budgetReturn:venteRetourBudget(o.fee),cashAfter:own.cash+o.fee,squadAfter:own.players.length-1,fillers:venteComplements(own.players.length-1),jiff:venteJiff(p),consequences:venteConsequences(p).textes,
   deferred:f.ouverte?null:{date:f.reouverture,dateLabel:f.reouverture?nativeVenteJoueurs.dateFr(f.reouverture):'',note:venteNoteAccord(f)}};
 }).filter(Boolean);
 const pending=venteEtat().accords.filter(a=>a.clubId===S.club&&a.sens!=='achat').map(venteVueAccord);
 return {available:true,listed,offers,pending,window:{mode:f.mode,open:f.ouverte,reopens:f.reouverture,reopensLabel:f.reouverture?nativeVenteJoueurs.dateFr(f.reouverture):'',reason:f.raison,
  periods:(venteReglages().fenetres.periodes||[]).map(x=>({start:x.debut,end:x.fin}))},minimum:venteMinimum(),squadSize:own.players.length};
}
// Commande sale_list {playerId, listed}.
function venteListe(p){
 const keys=Object.keys(p);
 if(keys.length!==2||!keys.every(k=>k==='playerId'||k==='listed')||typeof p.playerId!=='string'||typeof p.listed!=='boolean')throw Error('Paramètres de mise en vente invalides.');
 setupEconomy();const j=player(p.playerId);if(!j)throw Error('Ce joueur ne fait pas partie de ton effectif.');
 const e=S.economy;
 if(p.listed){
  if(e.listings[j.id])return {saleList:{playerId:j.id,listed:true,message:j.name+' est déjà proposé aux autres clubs.'}};
  const r=venteRaisonListe(j);if(r)throw Error(r);
  e.listings[j.id]=true;
  return {saleList:{playerId:j.id,listed:true,message:j.name+' est proposé aux autres clubs. Les offres arrivent à la fin de la semaine.'}};
 }
 if(S.live)throw Error('Match en cours : attends la fin de la journée.');
 delete e.listings[j.id];e.offers=e.offers.filter(o=>o.playerId!==j.id||o.spontaneous);
 return {saleList:{playerId:j.id,listed:false,message:j.name+' n’est plus proposé aux autres clubs.'}};
}
// Commande sale_answer {offerId, action:'accept'|'counter'|'decline', percent?, confirmed?}.
function venteRepondre(p){
 const keys=Object.keys(p),R=venteReglages().relances;
 if(!keys.every(k=>['offerId','action','percent','confirmed'].includes(k))||typeof p.offerId!=='string'||!['accept','counter','decline'].includes(p.action))throw Error('Réponse à l’offre invalide.');
 if(p.action==='counter'&&!R.pourcents.includes(p.percent))throw Error('Hausse demandée invalide : '+R.pourcents.map(x=>'+'+x+' %').join(', ')+'.');
 if(p.action!=='counter'&&p.percent!==undefined)throw Error('Réponse à l’offre invalide.');
 if(p.action==='accept'&&p.confirmed!==true)throw Error('Confirme la vente avant de l’accepter.');
 const o=venteOffre(p.offerId);if(!o||!player(o.playerId))throw Error('Cette offre n’est plus disponible.');
 const j=player(o.playerId),buyer=S.clubs[o.buyer];
 if(p.action==='decline'){
  if(S.live)throw Error('Match en cours : attends la fin de la journée.');
  S.economy.offers=S.economy.offers.filter(x=>x.id!==o.id);
  return {saleAnswer:{offerId:o.id,action:'decline',playerId:j.id,message:'Offre de '+buyer.name+' pour '+j.name+' refusée.'}};
 }
 if(p.action==='counter'){
  const r=venteRaisonRelance(o);if(r)throw Error(r);
  const fee=nativeVenteJoueurs.relance(o.fee,p.percent,venteReglages()),max=nativeVenteJoueurs.plafond(o.fee,buyer.cash,venteBesoin(buyer,j),venteReglages());
  if(fee>max||fee>buyer.cash||professionalPlaces(buyer)<=0){
   S.economy.offers=S.economy.offers.filter(x=>x.id!==o.id);
   const message=buyer.name+' retire son offre pour '+j.name+' après ta demande de '+venteEuros(fee)+'.';
   transferEvent(message);
   return {saleAnswer:{offerId:o.id,action:'counter',playerId:j.id,raised:false,fee,message}};
  }
  o.fee=fee;o.countered=p.percent;
  const message=buyer.name+' relève son offre pour '+j.name+' à '+venteEuros(fee)+'. La vente reste à confirmer.';
  transferEvent(message);
  return {saleAnswer:{offerId:o.id,action:'counter',playerId:j.id,raised:true,fee,message}};
 }
 const raison=venteRaisonAccepter(o);if(raison)throw Error(raison);
 const f=venteFenetre();
 if(!f.ouverte&&f.reouverture){
  // Hors période des mutations : accord conclu, exécuté à l'ouverture ; le joueur reste et joue jusque-là.
  // v2 (bascule) : vente encaissée tout de suite, part du budget de transferts rendue tout de suite (venteEncaisser).
  const a=venteNouvelAccord({playerId:j.id,joueur:j.name,buyer:buyer.id,acheteur:buyer.name,fee:o.fee,date:f.reouverture,spontaneous:!!o.spontaneous,...(f.bascule?{bascule:true}:{})});
  delete S.economy.listings[j.id];S.economy.offers=S.economy.offers.filter(x=>x.playerId!==j.id);
  const rendu=a.rendu||0;
  transferEvent('Accord conclu : '+j.name+' rejoindra '+buyer.name+' le '+nativeVenteJoueurs.dateFr(a.date)+' pour '+venteEuros(a.fee)+(a.paye?', encaissés dès maintenant.':'.'));
  return {saleAnswer:{offerId:o.id,action:'accept',playerId:j.id,fee:o.fee,deferred:true,date:a.date,budgetReturn:rendu,squadSize:club().players.length,
   message:'Accord conclu avec '+buyer.name+' : '+j.name+' partira le '+nativeVenteJoueurs.dateFr(a.date)+' contre '+venteEuros(a.fee)+(a.paye?', encaissés dès maintenant'+(rendu>0?' ('+venteEuros(rendu)+' reviennent au budget de transferts)':''):'')+'. Il reste au club et joue jusque-là.'}};
 }
 const avant=S.budgetTransferts?.reconstitue??0,fee=o.fee,name=j.name,buyerName=buyer.name,cons=venteConsequences(j);
 if(acceptSale(o.id)!==true)throw Error('Cette offre n’est plus disponible.');
 venteAppliquerConsequences(cons);
 const rendu=Math.max(0,(S.budgetTransferts?.reconstitue??0)-avant);
 return {saleAnswer:{offerId:o.id,action:'accept',playerId:j.id,fee,budgetReturn:rendu,squadSize:club().players.length,consequences:cons.textes,
  message:name+' rejoint '+buyerName+' pour '+venteEuros(fee)+'.'+(rendu>0?' '+venteEuros(rendu)+' reviennent au budget de transferts.':'')+' Vérifie ta feuille à 23.'}};
}
// Courrier « offre_transfert » (club-mail.cjs) : une offre en cours = un courrier (clé = id de l'offre). Lecture seule.
function venteCourriers(s){
 if(!s?.worldMode||!s.economy)return [];
 const own=s.clubs[s.club],out=[];
 for(const o of s.economy.offers||[]){
  if(o.expires<s.economy.week)continue;
  const p=own.players.find(x=>x.id===o.playerId),buyer=s.clubs[o.buyer];if(!p||!buyer||!p.dev)continue;
  out.push({key:o.id,player:p.id,club:buyer.id,vars:{joueur:p.name,acheteur:buyer.name,montant:venteEuros(o.fee),valeur:venteEuros(transferValue(p)),
   delai:o.expires>s.economy.week?'jusqu’à la fin de la semaine prochaine':'jusqu’à la fin de la semaine',
   origine:o.spontaneous?'Nous ne l’avions pas proposé : ils sont venus le chercher.':'Il fait partie des joueurs que tu as proposés aux autres clubs.'}});
 }
 return out;
}
// Courriers « vente_executee » / « vente_annulee » : accords exécutés ou tombés ces derniers jours (clé = événement).
function venteCourriersAccords(s,type,jour){
 if(!s?.worldMode||!venteEtatValide(s.venteJoueurs))return [];
 const jours=venteReglages().accords.courrierJours,limite=typeof jour==='string'?new Date(Date.parse(jour+'T00:00:00Z')-jours*86400000).toISOString().slice(0,10):'';
 return s.venteJoueurs.evenements.filter(e=>e.type===type&&(!limite||!e.date||e.date>=limite)).map(e=>({key:e.id,club:e.buyerId,
  vars:{joueur:e.joueur,acheteur:e.acheteur,montant:venteEuros(e.montant),raison:e.raison||''}}));
}
`;

module.exports = Object.freeze({ REGLAGES, euros, hash, relance, plafond, semaineTiree, fenetre, dateFr, BRANCHEMENT });
