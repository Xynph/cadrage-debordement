'use strict';
// L'argent du propriétaire (demande de Léo du 18/11/2026, inspirée de Football Manager). Deux mécaniques, rares et
// lisibles, calculées en coulisses pour les clubs gérés ; le club joué les vit par un courrier avec une décision.
//
// 1. Actionnaire qui prête au lieu de donner. Certains propriétaires comblent la perte de la saison par un prêt
//    (compte courant d'associé) : le club touche le même montant, mais le rembourse en trois saisons, ce qui lui
//    laisse moins de marge pour les salaires. Surtout les groupes actionnaires (un sur deux), rarement un mécène
//    (un sur sept), jamais une association (personne ne comble). Trait stable du propriétaire : le même club
//    prête toujours ou jamais, jusqu'à un changement de propriétaire. Le prêt réutilise la dette des clubs
//    (worldClub(id).debt) : il pèse sur la caisse nette, la marge salariale des clubs gérés et l'interdiction
//    d'acheter au-delà de 2 M€ ; mais ce n'est pas une crise (pas de stratégie de vente forcée, pas de reprise du
//    club pour cause de dette) : voir detteDeCrise.
//    Plafond : l'encours ne dépasse pas l'enveloppe annuelle du propriétaire (ni 1,5 M€) ; au-delà, il comble.
//    Sans plafond, un club qui perd un peu chaque saison accumulait trois ans de pertes en dette.
// 2. Mécènes qui arrivent et qui partent. Une ou deux fois par saison dans toute la base : un investisseur reprend
//    un club ambitieux de Pro D2 (club devenu mécène), ou un mécène s'en va après une descente, une saison au fond
//    du classement ou trois saisons de pertes. Actualité dans la presse ; pour le club joué, un courrier et un
//    effet sur la confiance du président.
const unite = texte => {
  let h = 2166136261;
  for (let i = 0; i < texte.length; i++) { h ^= texte.charCodeAt(i); h = Math.imul(h, 16777619); }
  h ^= h >>> 15; h = Math.imul(h, 2246822507); h ^= h >>> 13;
  return (h >>> 0) / 4294967296;
};
const rond = x => Math.round(x / 1000) * 1000;
const fini = x => typeof x === 'number' && Number.isFinite(x);

const PRET = Object.freeze({ parts: Object.freeze({ entreprise: 0.5, mecene: 0.15, association: 0 }), saisons: 3, plafond: 1.5e6, annuiteMin: 50000, minimum: 50000 });

const preteur = (clubId, type) => unite('preteur|' + clubId + '|' + type) < (PRET.parts[type] ?? 0);

// Prêt accordé à la clôture : ce que le propriétaire comble (apport) devient un prêt, dans la limite de son enveloppe.
//   pret : prêt en cours ({restant, annuite, saison, dernier}) ou null ; renvoie {pret, prete} (prete = 0 : il donne).
function accorder(pret, apport, saison, enveloppe) {
  const restant = fini(pret?.restant) && pret.restant > 0 ? pret.restant : 0;
  const plafond = Math.min(fini(enveloppe) ? enveloppe : 0, PRET.plafond);
  const prete = rond(Math.max(0, Math.min(fini(apport) ? apport : 0, plafond - restant)));
  if (prete < PRET.minimum) return { pret: restant > 0 ? { ...pret } : null, prete: 0 };
  const total = restant + prete;
  return { pret: { restant: total, annuite: Math.max(PRET.annuiteMin, Math.ceil(total / PRET.saisons / 1000) * 1000), saison, dernier: prete }, prete };
}
// Remboursement prévu d'une saison (0 la saison même du prêt : il commence la saison suivante).
const remboursementSaison = (pret, saison) => pret && fini(pret.restant) && pret.restant > 0 && pret.saison < saison ? Math.min(pret.restant, pret.annuite) : 0;

// ---- Changements de propriétaire ----------------------------------------------------------------------------
// clubs : [{id, type, avant, apres, rang, taille, base, pertes}] (avant/apres : division de la saison passée et de la
// nouvelle ; rang/taille : classement final ; pertes : nombre de saisons closes consécutives sous -0,25 M€).
// reputation : {division: réputation}. Renvoie au plus `max` changements, les plus probables d'abord.
const CHANGEMENTS = Object.freeze({
  max: 2,
  arrivee: Object.freeze({ division: 'accession', rangMax: 6, chance: 0.08 }),
  depart: Object.freeze({ descente: 0.3, fondDuClassement: 0.05, pertes: 0.06 }),
});
function changements(clubs, saison, reputation) {
  const out = [];
  for (const c of clubs) {
    const tirage = unite('proprietaire-change|' + c.id + '|' + saison);
    if (c.type === 'mecene') {
      const descente = c.avant !== c.apres && fini(reputation[c.avant]) && fini(reputation[c.apres]) && reputation[c.apres] < reputation[c.avant];
      const fond = !descente && fini(c.rang) && fini(c.taille) && c.rang > c.taille - 2;
      const chance = descente ? CHANGEMENTS.depart.descente : fond ? CHANGEMENTS.depart.fondDuClassement : (c.pertes ?? 0) >= 3 ? CHANGEMENTS.depart.pertes : 0;
      if (tirage < chance) out.push({ id: c.id, de: 'mecene', vers: (c.base ?? 0) >= 72 ? 'entreprise' : 'association', raison: descente ? 'descente' : fond ? 'resultats' : 'pertes', tirage: tirage / chance });
    } else if (c.apres === CHANGEMENTS.arrivee.division && c.avant === c.apres && fini(c.rang) && c.rang <= CHANGEMENTS.arrivee.rangMax && tirage < CHANGEMENTS.arrivee.chance) {
      out.push({ id: c.id, de: c.type, vers: 'mecene', raison: 'ambition', tirage: tirage / CHANGEMENTS.arrivee.chance });
    }
  }
  return out.sort((a, b) => a.tirage - b.tirage || a.id - b.id).slice(0, CHANGEMENTS.max).map(({ tirage, ...x }) => x);
}
const LIBELLES = Object.freeze({ association: 'association', entreprise: 'groupe actionnaire', mecene: 'mécène' });
function annonce(nom, x) {
  if (x.vers === 'mecene') return `${nom} change de mains : un investisseur reprend le club et promet de l’amener en Top 14. Le club passe d’un ${LIBELLES[x.de] ?? 'propriétaire'} à un mécène.`;
  const pourquoi = { descente: 'après la descente', resultats: 'après une saison au fond du classement', pertes: 'après trois saisons de pertes' }[x.raison] ?? '';
  return `${nom} : le mécène se retire ${pourquoi}. Le club ${x.vers === 'association' ? 'revient à ses adhérents, sans personne pour combler un déficit' : 'est repris par un groupe actionnaire, plus regardant sur les comptes'}.`;
}

// Code exécuté dans le moteur (après club-budget.cjs) : prêts à la clôture et remboursements hebdomadaires,
// changements de propriétaire à l'intersaison, courriers du club joué. Attend : nativeClubOwner (ce module).
//   S.pretsActionnaires = {"<id>": {restant, annuite, saison, dernier, vente?:{joueur, prix, acheteur}}}
//   S.proprietaires = {version:1, historique:[{saison, id, de, vers, raison}]}
const BRANCHEMENT = `
const pretsEtat=()=>{if(!S.pretsActionnaires||typeof S.pretsActionnaires!=='object'||Array.isArray(S.pretsActionnaires))S.pretsActionnaires={};return S.pretsActionnaires;};
const pretRestant=id=>{const p=S.pretsActionnaires?.[id];return p&&Number.isFinite(p.restant)&&p.restant>0?p.restant:0;};
// Dette de crise : la dette du club hors prêt de l'actionnaire (stratégie de vente, reprise du club, étiquette).
function detteDeCrise(id){const d=(typeof worldClub==='function'?worldClub(id)?.debt:0)||0;return Math.max(0,d-pretRestant(id));}
// Clôture d'un club : le propriétaire prêteur transforme son apport en prêt (dette du club). Renvoie le montant prêté.
function pretAccorder(id,compte,apport,saison){
 if(!(apport>0)||!nativeClubOwner.preteur(id,compte.type))return 0;
 const info=typeof worldClub==='function'?worldClub(id):null;if(!info)return 0;
 const e=pretsEtat(),r=nativeClubOwner.accorder(e[id]??null,apport,saison,compte.enveloppe);
 if(!(r.prete>0))return 0;
 e[id]={...r.pret,...(id===S.club?{vente:pretVenteProposee(r.pret.restant)}:{})};info.debt=(info.debt||0)+r.prete;
 return r.prete;
}
// Remboursement payé cette semaine (écriture du budget) : la dette et l'encours baissent d'autant.
// anticipe : remboursement hors des écritures de la semaine (vente du joueur proposé), à compter à part dans le résultat.
function pretRembourser(id,montant,anticipe=false){
 const e=S.pretsActionnaires,p=e?.[id];if(!p||!(montant>0))return;
 const paye=Math.min(p.restant,montant),info=typeof worldClub==='function'?worldClub(id):null;
 p.restant=Math.round(p.restant-paye);if(info)info.debt=Math.max(0,Math.round((info.debt||0)-paye));if(anticipe){const k=S.clubBudget?.clubs?.[id];if(k)k.rembourse=(k.rembourse||0)+paye;}
 if(p.restant<=0)delete e[id];
}
// Joueur que le président propose de vendre pour rembourser tout de suite : le mieux valorisé hors des cadres.
function pretVenteProposee(restant){
 if(typeof transferValue!=='function')return null;
 const c=club(),cadres=new Set(c.players.slice().sort((a,b)=>b.rating-a.rating||String(a.id).localeCompare(String(b.id))).slice(0,10).map(p=>p.id));
 const libres=c.players.filter(p=>!cadres.has(p.id)&&p.age>=23&&!(typeof saleBlocked==='function'&&saleBlocked(p)));
 const p=libres.map(p=>({p,v:transferValue(p)})).sort((a,b)=>b.v-a.v||String(a.p.id).localeCompare(String(b.p.id)))[0];
 return p?{joueur:p.p.id,prix:p.v}:null;
}
function pretAcheteur(p,prix){
 const lg=typeof budgetLigue==='function'?budgetLigue(S.club):null;
 return S.clubs.filter(c=>c.id!==S.club&&(typeof professionalPlaces!=='function'||professionalPlaces(c)>0)&&c.cash-350000>=prix&&((worldClub(c.id)?.debt)||0)<2000000)
  .sort((a,b)=>(budgetLigue(b.id)===lg)-(budgetLigue(a.id)===lg)||b.cash-a.cash||a.id-b.id)[0]||null;
}
// Courrier du président (club-mail.cjs, déclencheur « pret_actionnaire ») : la saison qui suit le prêt.
function pretCourrier(){
 const p=S.pretsActionnaires?.[S.club];if(!p||p.saison!==S.season-1||p.repondu)return null;
 const j=p.vente?club().players.find(x=>x.id===p.vente.joueur):null;
 const proposition=j?'Si tu préfères solder tout de suite, j’ai un acheteur pour '+j.name+' ('+j.pos+') : '+nativeClubBudget.euros(p.vente.prix)+'. Le prix de la vente irait directement au remboursement, et tu repartirais avec toute ta marge salariale.'
  :'Je ne vois personne à vendre sans affaiblir le groupe : il faudra rembourser sur la durée.';
 return {montant:nativeClubBudget.euros(p.dernier),encours:nativeClubBudget.euros(p.restant),annuite:nativeClubBudget.euros(p.annuite),saisons:Math.max(1,Math.ceil(p.restant/p.annuite)),proposition,joueur:j?j.name:''};
}
function pretVenteRefus(){
 const p=S.pretsActionnaires?.[S.club];if(!p||p.repondu)return 'Le président a déjà tranché.';
 const j=p.vente?club().players.find(x=>x.id===p.vente.joueur):null;if(!j)return 'Le joueur proposé ne fait plus partie de l’effectif.';
 if(typeof saleBlocked==='function'&&saleBlocked(j))return saleBlocked(j);
 if(!pretAcheteur(j,p.vente.prix))return 'Aucun club n’a les moyens de l’acheter aujourd’hui.';
 return '';
}
// Réponse au courrier : 'accepter' (la dette reste) ou 'vendre' (vente immédiate, le prix rembourse le prêt).
function pretRepondre(choix){
 const p=S.pretsActionnaires?.[S.club];if(!p||p.repondu)return false;
 if(choix==='vendre'){
  if(pretVenteRefus())return false;
  const j=club().players.find(x=>x.id===p.vente.joueur),acheteur=pretAcheteur(j,p.vente.prix),id='pret-'+S.season+'-'+j.id;
  S.economy.offers.push({id,playerId:j.id,buyer:acheteur.id,fee:p.vente.prix,expires:S.economy.week});
  if(acceptSale(id)!==true)return false;
  const rembourse=Math.min(p.restant,p.vente.prix);
  ledgerEntryV1('Remboursement anticipé du prêt de l’actionnaire',-rembourse);pretRembourser(S.club,rembourse,true);
 }
 const reste=S.pretsActionnaires?.[S.club];if(reste)reste.repondu=true;
 return true;
}

// ---- Changements de propriétaire (intersaison, avant le recalage des salaires et l'ouverture des comptes) ----
function proprietairesEtat(){const p=S.proprietaires;if(!p||p.version!==1||!Array.isArray(p.historique))S.proprietaires={version:1,historique:[]};return S.proprietaires;}
// forces : liste imposée (tests) à la place du tirage.
function proprietairesChanger(forces=null){
 if(!budgetLisible(S.clubBudget))return [];
 const E=nativeLeagueEconomy.CHAMPIONNATS,reputation=Object.fromEntries(Object.entries(E).map(([k,v])=>[k,v.reputation]));
 const clubs=S.clubs.map(c=>{const k=S.clubBudget.clubs[c.id],h=S.clubFinances?.clubs?.[c.id]||[];let pertes=0;for(let i=h.length-1;i>=0&&h[i][1]<-250;i--)pertes++;
  return {id:c.id,type:k.type,avant:k.division,apres:budgetLigue(c.id),rang:k.rang,taille:k.taille,base:c.base,pertes};});
 const liste=Array.isArray(forces)?forces:nativeClubOwner.changements(clubs,S.season,reputation),etat=proprietairesEtat();
 for(const x of liste){
  const c=S.clubs[x.id];S.clubBudget.clubs[x.id].type=x.vers;
  // Un nouveau propriétaire repart sans prêt de l'ancien : l'encours est soldé (racheté avec le club).
  const p=S.pretsActionnaires?.[x.id];if(p){const info=worldClub(x.id);if(info)info.debt=Math.max(0,(info.debt||0)-p.restant);delete S.pretsActionnaires[x.id];}
  etat.historique.push({saison:S.season,id:x.id,de:x.de,vers:x.vers,raison:x.raison});
  const texte=nativeClubOwner.annonce(c.name,x);
  if(typeof transferEvent==='function')transferEvent(texte);
  if(typeof nativeClubDirections!=='undefined'){try{nativeClubDirections.tally('proprietaire:'+(x.vers==='mecene'?'arrivee':'depart'),x.id);}catch(e){}}
  if(x.id===S.club){S.trust=Math.max(0,Math.min(100,(S.trust??50)+(x.vers==='mecene'?5:-5)));etat.courrier={saison:S.season,...x};}
  else if(budgetLigue(x.id)===budgetLigue(S.club)&&typeof news==='function')news(texte);
 }
 etat.historique=etat.historique.slice(-40);
 return liste;
}
// Courrier du club joué (club-mail.cjs, déclencheur « proprietaire_change ») : la saison du changement.
function proprietaireCourrier(){
 const x=S.proprietaires?.courrier;if(!x||x.saison!==S.season)return null;
 const raison={descente:'la descente',resultats:'une saison au fond du classement',pertes:'trois saisons de pertes',ambition:''}[x.raison]??'';
 return {arrivee:x.vers==='mecene'?'oui':'non',ancien:nativeClubOwner.LIBELLES[x.de]??'',nouveau:nativeClubOwner.LIBELLES[x.vers]??'',raison};
}
`;

module.exports = Object.freeze({ PRET, CHANGEMENTS, LIBELLES, preteur, accorder, remboursementSaison, changements, annonce, unite, BRANCHEMENT });
