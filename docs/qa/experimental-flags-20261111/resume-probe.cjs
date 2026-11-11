const fs=require('node:fs'),os=require('node:os'),path=require('node:path');const {createBridge}=require(path.join(process.argv[2], 'native/engine/worker.cjs'));
const dataDir=fs.mkdtempSync(path.join(os.tmpdir(),'flags-resume-'));process.env.CD_SALAIRES_PAR_NIVEAU='1';let b=createBridge({dataDir,seed:27,now:1794178800000}),i=0;
function good(command,payload={}){let r=b.handle({id:++i,command,payload});if(!r.ok)throw Error(command+':'+r.error);return r.model;}
const m=good('new_career',{mode:'common',club:29});b.close();delete process.env.CD_SALAIRES_PAR_NIVEAU;b=createBridge({dataDir,now:1794178800000});const n=good('snapshot');const e=good('export');
console.log(JSON.stringify({created:m.finance,resumed:n.finance,strategyCreated:m.clubLife.clubStrategy.finance,strategyResumed:n.clubLife.clubStrategy.finance,marker:JSON.parse(e.meta.exportText).state.startingSalaries}));b.close();
