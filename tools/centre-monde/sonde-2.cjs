'use strict';
// Sonde : que se passe-t-il si on retire seulement le verrou « carrière mondiale » des parcours du Centre ?
const path=require('node:path');
const {ouvrir,creer}=require(path.join(__dirname,'../../tests/helpers/carriere-monde.cjs'));
const academy=require(path.join(__dirname,'../../native/engine/academy.cjs'));
const club=Number(process.argv[2]||102);
const jeu=ouvrir({hebdomadaire:true,simulation:true,testVm:true});
creer(jeu,club);
const run=s=>jeu.bridge.vm.run(s);
const lire=s=>JSON.parse(run('JSON.stringify('+s+')'));
run(`globalThis.__acadSansVerrou=(()=>{const CDWorldCareer={active:()=>false};return (${academy.factory.toString()})()})();`);
const essai=(label,src)=>{try{const r=lire(src);console.log(label,'OK',JSON.stringify(r).slice(0,400));}catch(e){console.log(label,'ERREUR',e.message);}};
console.log(lire(`({season:S.season,round:S.round,week:S.franceMode?.week??S.round,phase:S.phase,clubs:S.clubs.length,policy:S.academyGroupPolicy})`));
// Étape 1 : activation telle quelle (sur une copie de S, pour enchaîner d'autres essais)
run(`globalThis.__S0=JSON.parse(JSON.stringify(S));`);
essai('activation', `(()=>{const p={season:S.season,week:S.franceMode?.week??S.round,club:S.club,confirmed:true};return __acadSansVerrou.execute('academy_activate',p)})()`);
essai('apres', `({active:S.nativeAcademy?.version,centres:S.nativeAcademy?.centers?.length,elite:S.v75Movement?.elite?.length,accession:S.v75Movement?.accession?.length,invites:S.nativeAcademy?.centers?.filter(c=>c.clubId===null).length})`);
jeu.fermer();
