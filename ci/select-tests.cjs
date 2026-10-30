'use strict';

// Sélection conservatrice pour les commits de développement.
// Les pull requests et main exécutent TOUJOURS toutes les suites.
const fs=require('node:fs');
const path=require('node:path');
const root=path.resolve(__dirname,'..');
const allTests=fs.readdirSync(path.join(root,'tests'))
 .filter(name=>name.endsWith('.cjs')&&name!=='harness.cjs')
 .map(name=>'tests/'+name).sort();

const name=key=>'tests/'+key+'.cjs';
const dependencies={
 'dist/rugby.js':['rugby','discipline','frontrow','match-rules','matchflow','goalkicking','opposition','v19-advantage','v20-numerical-ai','v21-numerical-advice','v22-tactical-comparison','v23-local-zones','v24-four-zones','v25-whatif','v26-dual-whatif','saves','v27-physical-load','v28-collective-preparation','v29-focused-development','v30-recruitment-intelligence','v32-succession-planning'],
 'dist/frontrow.js':['frontrow','discipline','match-rules','rugby','saves'],
 'dist/restarts.js':['restarts','match-rules','rugby','saves','v28-collective-preparation'],
 'dist/matchflow.js':['matchflow','rugby','saves'],
 'dist/tactical-plans.js':['tactical-plans','v20-numerical-ai','v21-numerical-advice','v22-tactical-comparison','v23-local-zones','v24-four-zones','v25-whatif','v26-dual-whatif','saves'],
 'dist/opposition.js':['opposition','v20-numerical-ai','v21-numerical-advice','v22-tactical-comparison','v23-local-zones','v24-four-zones','v25-whatif','v26-dual-whatif','saves','v27-physical-load'],
 'dist/saves.js':['saves','v20-numerical-ai','v21-numerical-advice','v22-tactical-comparison','v23-local-zones','v24-four-zones','v25-whatif','v26-dual-whatif','frontrow','match-rules','v27-physical-load','v28-collective-preparation','v29-focused-development','v30-recruitment-intelligence','v32-succession-planning'],
 'dist/match-actions.js':['match-actions','rugby','v19-advantage'],
 'dist/match2d.js':['match2d','v21-numerical-advice','v22-tactical-comparison','v23-local-zones','v24-four-zones','v25-whatif','v26-dual-whatif'],
 'dist/playbook.js':['playbook','tactical-plans','v22-tactical-comparison','v23-local-zones','v24-four-zones','v25-whatif','v26-dual-whatif','saves'],
 'dist/match-preparation.js':['preparation','saves','v28-collective-preparation'],
 'dist/manager.js':['manager','saves','v30-recruitment-intelligence','v32-succession-planning'],
 'dist/manager-squad.js':['manager','saves','v27-physical-load','v29-focused-development','v32-succession-planning'],
 'dist/development.js':['development','saves','v27-physical-load','v29-focused-development','v30-recruitment-intelligence','v32-succession-planning'],
 'dist/economy.js':['economy','saves','v30-recruitment-intelligence','v31-finance-forecasts','v32-succession-planning'],
 'dist/world-data.js':['rugby','development','economy','saves'],
 'dist/storage.js':['offline','saves'],
 'dist/game.js':['manager','match2d','preparation','v21-numerical-advice','v22-tactical-comparison','v23-local-zones','v24-four-zones','v25-whatif','v26-dual-whatif','saves','v27-physical-load','v28-collective-preparation','v29-focused-development','v30-recruitment-intelligence','v31-finance-forecasts','v32-succession-planning'],
 'dist/style.css':['match2d','v21-numerical-advice','v22-tactical-comparison','v23-local-zones','v24-four-zones','v25-whatif','v26-dual-whatif','v27-physical-load','v29-focused-development','v30-recruitment-intelligence','v31-finance-forecasts','v32-succession-planning'],
 'dist/index.html':['offline','v21-numerical-advice','v23-local-zones','v24-four-zones','v25-whatif','v26-dual-whatif']
};
const helpers=new Set(['ci/select-tests.cjs','.github/workflows/tests.yml']);
function selectTests(files,available=allTests){
 const valid=new Set(available),chosen=new Set();
 const all=()=>[...valid].sort();
 const include=names=>{
  for(const test of names){
   const p=test.startsWith('tests/')?test:name(test);
   if(!valid.has(p))return false;
   chosen.add(p);
  }
  return true;
 };
 if(!Array.isArray(files)||!files.length)return all(); // Diff absent : ne pas sauter les tests
 for(let raw of files){
  if(typeof raw!=='string')return all();
  const file=raw.trim();
  if(!file)continue;
  if(file==='AGENTS.md'||file==='README.md'||file==='DEVELOPPEMENT.md'||file.startsWith('docs/'))continue;
  if(file.startsWith('tests/')){
   if(file==='tests/harness.cjs'||!valid.has(file))return all();
   chosen.add(file);continue;
  }
  if(helpers.has(file)||file.startsWith('.github/workflows/')){
   if(!include(['ci-selection']))return all();
   continue;
  }
  if(file.startsWith('dist/')){
   const deps=dependencies[file];
   if(!deps||!include(deps))return all(); // Nouveau fichier : couverture totale
   continue;
  }
  if(file.startsWith('offline/')){
   if(!include(['offline','saves']))return all();
   continue;
  }
  return all(); // Changement inconnu : prudence
 }
 return [...chosen].sort();
}
module.exports={selectTests,allTests};
if(require.main===module){
 if(process.argv.length!==3){console.error('Usage : node ci/select-tests.cjs <fichier-des-chemins-modifiés>');process.exit(2);}
 const changed=fs.readFileSync(process.argv[2],'utf8').split(/\r?\n/).filter(Boolean);
 for(const test of selectTests(changed))console.log(test);
}
