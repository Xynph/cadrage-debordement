'use strict';
// Championship (deuxième division anglaise), Super Rugby (championnat du Pacifique) et deuxième division japonaise :
// un club bien géré finit ses deux premières saisons dans le vert ou près de l'équilibre, comme en Top 14 et en Pro D2.
// Cause mesurée le 24/11/2026 (carrière Monde réelle, graines 4242, 7 et 2026) : la trésorerie de départ de ces clubs était
// un paramètre fictif uniforme (3,6 M€, 4 M€, 3,4 M€), soit 100 %, 52 % et 53 % de leurs recettes, quand la réserve d'un
// club en vise 10 à 20 %. À l'ouverture de la deuxième saison, l'excédent au-dessus de la réserve était réinvesti d'un coup
// (club-budget.cjs, ouverture et engagement) : 1,2 à 2,6 M€ de dépenses en plus, et ces championnats finissaient la saison 2
// dans le rouge. Même correction que la Nationale (#896) : une trésorerie de départ à la mesure des recettes de chaque club.
// Deuxième cause, Championship et D2 japonaise (saisons 2 et 3) : la masse autorisée comptait sur 15 % d'économies de
// fonctionnement en plus de l'enveloppe du propriétaire (39 à 47 % des recettes) ; les clubs gérés la remplissaient à
// l'intersaison et toute la division restait dans le rouge (-0,3 à -0,7 M€). Marge de prudence (league-economy.cjs) :
// 15 % en Championship ; D2 japonaise : 10 % à la création, 21 % dès la saison 2 (league-economy.cjs, prudenceDepart, masseDepart,
// soutien ; mesure du 25/11/2026 : plus aucun club de la division dans le rouge hors enveloppe en trois saisons).
// Le Super Rugby garde sa borne : son plafond salarial (2,6 M€) passe avant.
const assert = require('node:assert/strict');
const { test } = require('node:test');
const B = require('../native/engine/club-budget.cjs');
const { ouvrir, creer } = require('./helpers/carriere-monde.cjs');

const LIGUES = ['champ', 'srp', 'jlo-d2'];
// Tolérance du moteur sur un déficit (club-budget.cjs, TOLERANCE_DEFICIT) : 2 % des recettes, « personne ne s'en émeut ».
const TOLERANCE = 0.02;

test('Moteur Monde : Championship, Super Rugby et D2 japonaise, saisons 1 et 2 d’un club bien géré dans le vert ou à l’équilibre', () => {
  const jeu = ouvrir({ hebdomadaire: true, testVm: true });
  try {
    creer(jeu, 30);
    const run = s => jeu.bridge.vm.run(s), lire = s => JSON.parse(run('JSON.stringify(' + s + ')'));
    const depart = lire(`(()=>{const f=budgetForces(),R=nativeClubBudget.recettes(f);return S.clubs.filter(c=>${JSON.stringify(LIGUES)}.includes(budgetLigue(c.id)))
      .map(c=>({id:c.id,division:budgetLigue(c.id),cash:c.cash,recettes:R.get(c.id),reserve:nativeClubBudget.reserveCible(R.get(c.id),c.id,budgetLigue(c.id))}));})()`);
    assert.equal(depart.length, 14 + 10 + 8, 'les clubs des trois championnats');
    // Deux saisons projetées par le vrai budget du moteur (écritures hebdomadaires, frais de match, clôture, puis ouverture de
    // la saison 2 avec réinvestissement des excédents et dividende), un match sur deux à domicile, forme selon la force du club.
    const saisons = lire(`(()=>{const ligues=${JSON.stringify(LIGUES)},f=budgetForces(),repere=budgetRepere(),n=wageForecastWeeks(),R=nativeClubBudget.recettes(f),types=budgetTypes();
      const clubs=S.clubs.filter(c=>ligues.includes(budgetLigue(c.id))),caisse=new Map(clubs.map(c=>[c.id,c.cash])),out=[];
      for(let saison=1;saison<=2;saison++){
        const o=nativeClubBudget.ouverture({forces:f,saison,clubs:clubs.map(c=>({id:c.id,cash:caisse.get(c.id),masse:budgetMasse(c)*52})),types,excedents:saison>1});
        for(const [i,c] of clubs.entries()){const div=budgetLigue(c.id),pairs=clubs.filter(x=>budgetLigue(x.id)===div).sort((a,b)=>b.base-a.base||a.id-b.id),rang=pairs.indexOf(c)+1,taille=pairs.length;
          const compte=o.clubs[i],forme=rang<=taille/3?'VVVDV':rang<=2*taille/3?'VDVDN':'DDVDD',rec=repere.receptions[c.id]||Math.max(7,taille-1);
          let cash=caisse.get(c.id)-compte.dividende;
          for(let w=0;w<n;w++){const e=nativeClubBudget.semaine({forces:f,clubId:c.id,masseHebdo:budgetMasse(c),semaines:n,receptions:rec,domicile:w%2===0,resultats:forme.split(''),
            repere:'test|'+saison+'|'+w,gere:true,formation:budgetCentre(c),investissement:compte.investissement,staff:budgetStaff(c)});
            const fr=nativeClubBudget.fraisDeMatch(compte,nativeClubBudget.recettesImprevues(e,{forces:f,clubId:c.id,receptions:rec}),nativeClubBudget.deficitPrevu(f,c.id,budgetMasse(c)*52));
            compte.imprevu=fr.imprevu;compte.fraisMatch=fr.fraisMatch;if(fr.montant>0)e.push({title:'frais',amount:-fr.montant});
            nativeClubBudget.compter(compte,e,budgetMasse(c)*52);cash+=e.reduce((s,x)=>s+x.amount,0);}
          const r=nativeClubBudget.cloture({division:div,compte,tresorerie:cash,rang,taille});
          caisse.set(c.id,cash+r.ecritures.reduce((s,x)=>s+x.amount,0));
          out.push({saison,id:c.id,division:div,type:compte.type,resultat:r.resultat,investissement:compte.investissement,recettes:R.get(c.id),part:budgetMasse(c)*52/R.get(c.id)});}
      }
      return out;})()`);
    for (const ligue of LIGUES) for (const saison of [1, 2]) {
      const lot = saisons.filter(c => c.division === ligue && c.saison === saison);
      console.log(ligue + ', saison ' + saison + ' projetée : ' + JSON.stringify(lot.map(c => [c.id, c.type, Math.round(c.resultat / 1e4) / 100, Math.round(c.investissement / 1e4) / 100])));
      const moyenne = lot.reduce((s, c) => s + c.resultat / c.recettes, 0) / lot.length;
      // Résultat moyen de la division au-dessus de -2 % des recettes (tolérance du moteur : « personne ne s'en émeut »).
      assert.ok(moyenne > -TOLERANCE, ligue + ' saison ' + saison + ' : résultat moyen ' + (moyenne * 100).toFixed(1) + ' % des recettes');
      // Un club bien géré (salaires des joueurs sous 30 % des recettes, le point mort de la division) : dans le vert ou à
      // l'équilibre, à 2 % des recettes près.
      const geres = lot.filter(c => c.part < 0.3);
      assert.ok(geres.length > 0, ligue + ' : au moins un club bien géré');
      for (const c of geres) assert.ok(c.resultat > -TOLERANCE * c.recettes, ligue + ' saison ' + saison + ', club ' + c.id + ' bien géré (' + c.part.toFixed(2) + ') : ' + c.resultat);
    }
    // Masse autorisée (Championship, D2 japonaise) : en moyenne au plus 38 % des recettes de la division (Top 14 : 30 %,
    // Premiership : 31 %, Pro D2 : 33 % ; avant la marge de prudence : 43 %, et jusqu'à 47 % pour un club de mécène).
    const limites = lire(`(()=>{const f=budgetForces(),R=nativeClubBudget.recettes(f),L=budgetLimites(false);return S.clubs.filter(c=>['champ','jlo-d2'].includes(budgetLigue(c.id)))
      .map(c=>({id:c.id,division:budgetLigue(c.id),part:L.get(c.id).limite/R.get(c.id)}));})()`);
    assert.equal(limites.length, 14 + 8);
    for (const ligue of ['champ', 'jlo-d2']) {
      const parts = limites.filter(c => c.division === ligue).map(c => c.part), moyenne = parts.reduce((s, x) => s + x, 0) / parts.length;
      assert.ok(moyenne <= 0.38, ligue + ' : masse autorisée moyenne ' + (100 * moyenne).toFixed(1) + ' % des recettes (' + parts.map(x => Math.round(100 * x)).join(', ') + ')');
    }
    // Trésorerie de départ : jamais au-dessus de la réserve que le club se fixe (rien à « réinvestir » d’un coup en saison 2).
    for (const c of depart) assert.ok(c.cash > 0 && c.cash <= c.reserve, c.division + ' ' + c.id + ' : caisse de départ ' + c.cash + ' pour une réserve de ' + c.reserve + ' (recettes ' + Math.round(c.recettes) + ')');
  } finally { jeu.fermer(); }
});
