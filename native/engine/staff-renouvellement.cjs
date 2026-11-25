'use strict';
// Staff du club joué renouvelé par le directeur sportif (décision de Léo, 17/11/2026, suite de #874 et #875).
//
// Mesure de #875 : avec un manager passif, le club joué n'a plus personne aux postes entraîneur, adjoint, formation,
// recrutement et analyse dès la saison 3. Les contrats du staff (staff-career.cjs) expirent ; les clubs IA les
// renouvellent d'office et complètent leur staff, le club joué jamais.
//
// Quand le manager a confié les prolongations au staff (case de #874, S.manager.delegation.contracts) :
//  - de mars à juin, le directeur sportif tranche les fins de contrat du staff : il prolonge les membres utiles, laisse
//    partir ceux qui sont en surnombre, proches de la retraite ou nettement moins bons que ce que propose le marché ;
//  - à tout moment (en pratique au début de la saison suivante), il remplace les postes vides sur le marché du staff ;
//  - budget : staff gratuit (cas par défaut, couvert par la ligne « Staff et fonctionnement ») → il ne vise que les
//    profils à la portée du club (niveau ≤ base + 8, − 5 en consigne économe) ; staff rémunéré (staff-employment.cjs
//    activé) → il signe au barème et respecte la réserve de trésorerie, sinon il renonce ;
//  - jugement imparfait (trait « évaluation » du directeur sportif), décision déterministe ;
//  - un courrier résume chaque série de décisions (club-mail.cjs, type ds_staff) ; mode Monde uniquement.

const FENETRE = Object.freeze({ debut: 3, fin: 6 });
const ROLES = Object.freeze(['coach', 'assistant', 'formation', 'scout', 'analyst', 'medical', 'fitness', 'support']);
const RAISONS = Object.freeze({
  solide: 'il tient son poste',
  continuite: 'pas mieux à notre portée sur le marché',
  retraite: 'il arrive au bout de sa carrière',
  surnombre: 'nous sommes déjà assez nombreux à ce poste',
  mieux: 'le marché offre nettement mieux',
  budget: 'la trésorerie ne permet pas de le payer',
});

// Plafond de niveau à la portée du club quand le staff n'est pas rémunéré individuellement.
function plafondNiveau(base, consigne) {
  const b = Number.isFinite(base) ? base : 70;
  return Math.max(55, Math.min(85, Math.round(b + 8 - (consigne === 'econome' ? 5 : 0))));
}

// Plan pur des fins de contrat. membres : {id, role, estime, age, ansMax} (ansMax : saisons avant la retraite) ;
// x : {base, besoin{role:n}, restants{role:n} (membres encore sous contrat la saison prochaine),
//      marche{role: notes estimées des candidats libres à la portée du club (liste, ou une seule note)}}.
// Un même candidat libre ne justifie qu'un seul départ (gros staffs japonais, 25/11/2026 : le meilleur libre du poste
// justifiait des dizaines de départs « le marché offre mieux », réembauchés à l'été) : chaque départ « mieux » réserve
// le meilleur candidat encore libre du poste, le membre suivant se compare au suivant.
function planifier(membres, x) {
  const gardes = {}, out = [], marche = {};
  for (const [role, v] of Object.entries(x.marche || {})) marche[role] = [].concat(v).filter(Number.isFinite).sort((a, b) => b - a);
  const tries = membres.slice().sort((a, b) => b.estime - a.estime || (a.id < b.id ? -1 : a.id > b.id ? 1 : 0));
  for (const m of tries) {
    const besoin = x.besoin[m.role] ?? 0, deja = (x.restants[m.role] ?? 0) + (gardes[m.role] ?? 0);
    const libre = marche[m.role]?.[0];
    let d;
    if (m.ansMax < 2) d = { decision: 'libere', raison: 'retraite' };
    else if (deja >= besoin) d = { decision: 'libere', raison: 'surnombre' };
    // Stabilité : seul un membre faible pour le club est remplacé, et seulement si le marché offre nettement mieux.
    else if (m.estime < x.base - 5 && libre !== undefined && libre >= m.estime + 8) { d = { decision: 'libere', raison: 'mieux' }; marche[m.role].shift(); }
    else {
      const ans = Math.min(m.age <= 58 ? 3 : 2, m.ansMax);
      d = { decision: 'prolonge', raison: m.estime >= x.base - 5 ? 'solide' : 'continuite', ans };
      gardes[m.role] = (gardes[m.role] ?? 0) + 1;
    }
    out.push({ id: m.id, ...d });
  }
  return out;
}

// Recrues pures : postes manquants {role:n}, candidats {id, role, level, estime, ansMax}, plafond de niveau.
// Il prend le meilleur à sa portée (selon son estimation) ; si personne n'est à sa portée, le moins exigeant.
function recruter(manques, candidats, plafond) {
  const pris = new Set(), out = [];
  for (const role of ROLES) {
    for (let n = 0; n < (manques[role] ?? 0); n++) {
      const libres = candidats.filter(c => c.role === role && !pris.has(c.id) && c.ansMax >= 1);
      if (!libres.length) break;
      const aPortee = libres.filter(c => c.level <= plafond)
        .sort((a, b) => b.estime - a.estime || (a.id < b.id ? -1 : 1));
      const c = aPortee[0] ?? libres.slice().sort((a, b) => a.level - b.level || (a.id < b.id ? -1 : 1))[0];
      pris.add(c.id);
      out.push({ id: c.id, role, ans: Math.min(2, c.ansMax) });
    }
  }
  return out;
}

const BRANCHEMENT = `
const dsStaffActif=()=>typeof dsContratsActif==='function'&&dsContratsActif()&&S.staffCareer?.version===1&&typeof CDStaffCareer!=='undefined';
const dsStaffBureau=()=>{const m=S.manager;if(!m.staffDesk||m.staffDesk.season!==S.season)m.staffDesk={season:S.season,decisions:[],lots:m.staffDesk?.lots||[]};return m.staffDesk;};
const dsStaffPeople=()=>S.staffCareer.people.flat();
function dsStaffEstime(p,ev){return Math.round((p.level+(dsContratsHash('ds-staff|'+S.club+'|'+p.id+'|'+S.season)-.5)*2*(2+(100-ev)*.08))*10)/10;}
function dsStaffEmploi(){try{const d=nativeSystems.domain('staffEmployment');const pr=d&&S.staffEmployment?d.project():null;return pr&&pr.enabled?{d,pr}:null;}catch(e){return null;}}
function dsStaffContexte(){return {season:S.season,week:S.franceMode?.week??S.round,club:S.club};}
// Signature (prolongation ou embauche) par la voie normale du jeu : commandes du staff, ou contrat rémunéré si activé.
function dsStaffSigner(kind,p,ans){
 const emploi=dsStaffEmploi();
 try{
  if(emploi){const tarif=(emploi.pr.own.concat(emploi.pr.candidates).find(q=>q.id===p.id)||{}).salary;
   emploi.d.execute('staff_employment_'+kind,{context:emploi.pr.context,confirmed:true,[kind==='hire'?'candidateId':'staffId']:p.id,years:ans,salary:tarif});}
  else CDStaffCareer.execute('staff_'+kind,{context:dsStaffContexte(),confirmed:true,[kind==='hire'?'candidateId':'staffId']:p.id,years:ans});
  return true;
 }catch(e){return false;}
}
function dsStaffObserver(forcee){
 if(!dsStaffActif()||S.live||S.phase==='ended')return false;
 // Pendant la préparation aussi (juillet-août) : c'est là que les postes laissés vides se remplacent.
 const pre=typeof CDPreseason!=='undefined'?CDPreseason.pending(S):null;
 const date=forcee||(pre&&typeof pre.today==='string'?pre.today:dsContratsAujourdhui());if(typeof date!=='string')return false;
 const mois=Number(date.slice(5,7)),bureau=dsStaffBureau(),ds=dsContratsDirecteur(),ev=ds.evaluation,c=club();
 const cible=S.staffCareer.targets.find(t=>t.clubId===S.club);if(!cible)return false;
 const besoin={...cible.roles};for(const r of nativeStaffRenouvellement.ROLES)if(['coach','assistant','formation','scout','analyst'].includes(r))besoin[r]=Math.max(1,besoin[r]||0);
 const plafond=nativeStaffRenouvellement.plafondNiveau(c.base,dsContratsConsigne());
 const lot={id:S.season+':'+date+':'+(bureau.lots.length+1),date,prolonges:[],departs:[],recrues:[],refus:0};
 const libres=()=>dsStaffPeople().filter(p=>p.clubId===null&&p.age<p.retireAge);
 // 1. Fins de contrat (mars à juin).
 if(mois>=nativeStaffRenouvellement.FENETRE.debut&&mois<=nativeStaffRenouvellement.FENETRE.fin){
  const decides=new Set(bureau.decisions.map(x=>x.id)),miens=dsStaffPeople().filter(p=>p.clubId===S.club);
  const echeance=miens.filter(p=>p.contractEnd===S.season&&!decides.has(p.id));
  if(echeance.length){
   const restants={};for(const p of miens)if(p.contractEnd>S.season)restants[p.role]=(restants[p.role]||0)+1;
   // Candidats libres à sa portée, du meilleur au moins bon ; ceux déjà promis à un départ « mieux » cette saison restent réservés.
   const marche={},promis={};for(const x of bureau.decisions)if(x.raison==='mieux')promis[x.role]=(promis[x.role]||0)+1;
   for(const p of libres())if(p.level<=plafond)(marche[p.role]||(marche[p.role]=[])).push(dsStaffEstime(p,ev));
   for(const r in marche)marche[r]=marche[r].sort((a,b)=>b-a).slice(promis[r]||0);
   const plan=nativeStaffRenouvellement.planifier(echeance.map(p=>({id:p.id,role:p.role,estime:dsStaffEstime(p,ev),age:p.age,ansMax:p.retireAge-p.age})),{base:c.base,besoin,restants,marche});
   for(const d of plan){
    const p=echeance.find(x=>x.id===d.id);let decision=d.decision,raison=d.raison;
    if(decision==='prolonge'&&!dsStaffSigner('renew',p,d.ans)){decision='libere';raison='budget';lot.refus++;}
    bureau.decisions.push({id:p.id,name:p.name,role:p.role,d:decision,raison,date,end:p.contractEnd});
    if(decision==='prolonge')lot.prolonges.push({name:p.name,role:p.roleLabel,fin:p.contractEnd});else lot.departs.push({name:p.name,role:p.roleLabel,raison});
   }
   bureau.decisions=bureau.decisions.slice(-80);
  }
 }
 // 2. Postes vides : remplacement sur le marché du staff.
 const presents={};for(const p of dsStaffPeople())if(p.clubId===S.club)presents[p.role]=(presents[p.role]||0)+1;
 const manques={};let total=0;for(const r of nativeStaffRenouvellement.ROLES){const n=Math.max(0,(besoin[r]||0)-(presents[r]||0));if(n){manques[r]=n;total+=n;}}
 if(total){
  const cand=libres().map(p=>({id:p.id,role:p.role,level:p.level,estime:dsStaffEstime(p,ev),ansMax:p.retireAge-p.age}));
  for(const r of nativeStaffRenouvellement.recruter(manques,cand,plafond)){
   const p=dsStaffPeople().find(x=>x.id===r.id);
   if(p&&dsStaffSigner('hire',p,r.ans))lot.recrues.push({name:p.name,role:p.roleLabel,level:p.level});else lot.refus++;
  }
 }
 if(!lot.prolonges.length&&!lot.departs.length&&!lot.recrues.length)return false;
 // Gros staffs (clubs japonais : jusqu'à 70 membres) : un lot dépasse vite 40 noms ; découpé en séries de 40 pour rester
 // dans la forme de sauvegarde (sinon la carrière refuse sa propre sauvegarde).
 bureau.lots=bureau.lots.concat(nativeStaffRenouvellement.decouperLot(lot)).slice(-12);
 const n=lot.prolonges.length+lot.recrues.length;
 if(n)news('Staff : le directeur sportif a '+[lot.prolonges.length?lot.prolonges.length+' prolongation'+(lot.prolonges.length>1?'s':''):'',lot.recrues.length?lot.recrues.length+' arrivée'+(lot.recrues.length>1?'s':''):''].filter(Boolean).join(' et ')+' à son actif.');
 return true;
}
`;

// Un lot de courrier tient au plus LOT_MAX noms par liste (forme validée) : au-delà, séries successives de même date ;
// les signatures refusées restent sur la première série.
const LOT_MAX = 40;
function decouperLot(lot, max = LOT_MAX) {
  const n = Math.max(1, ...['prolonges', 'departs', 'recrues'].map(k => Math.ceil(lot[k].length / max)));
  if (n === 1) return [lot];
  return Array.from({ length: n }, (_, i) => ({ ...lot, id: i ? lot.id + '.' + (i + 1) : lot.id, refus: i ? 0 : lot.refus,
    prolonges: lot.prolonges.slice(i * max, (i + 1) * max), departs: lot.departs.slice(i * max, (i + 1) * max), recrues: lot.recrues.slice(i * max, (i + 1) * max) }));
}

const short = (x, n) => typeof x === 'string' && x.length <= n;
// Validation de sauvegarde du bureau staff du directeur sportif.
function valider(m, saison) {
  const b = m && typeof m === 'object' ? m.staffDesk : undefined;
  if (b === undefined) return true;
  const entree = e => e && short(e.name, 160) && short(e.role, 160);
  const ok = b && typeof b === 'object' && Number.isSafeInteger(b.season) && b.season >= 1 && b.season <= saison
    && Array.isArray(b.decisions) && b.decisions.length <= 80
    && b.decisions.every(e => e && short(e.id, 240) && short(e.name, 160) && ROLES.includes(e.role) && ['prolonge', 'libere'].includes(e.d) && RAISONS[e.raison] !== undefined && short(e.date, 10))
    && Array.isArray(b.lots) && b.lots.length <= 12
    && b.lots.every(l => l && short(l.id, 60) && short(l.date, 10) && Number.isSafeInteger(l.refus) && l.refus >= 0
      && ['prolonges', 'departs', 'recrues'].every(k => Array.isArray(l[k]) && l[k].length <= LOT_MAX && l[k].every(entree)));
  if (!ok) throw Error('Sauvegarde invalide : décisions du directeur sportif sur le staff.');
  return true;
}

module.exports = Object.freeze({ FENETRE, ROLES, RAISONS, LOT_MAX, plafondNiveau, planifier, recruter, decouperLot, valider, BRANCHEMENT });
