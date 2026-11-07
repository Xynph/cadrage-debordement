/** Reception Chromium PC reelle : modules V101-V116 du main natif. */
import assert from 'node:assert/strict';
import fs from 'node:fs';
import http from 'node:http';
import path from 'node:path';
import {createRequire} from 'node:module';
import {fileURLToPath} from 'node:url';
const require=createRequire(import.meta.url);
const {chromium}=require(process.env.CD_PLAYWRIGHT_MODULE||'playwright');
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const out=path.join(root,'v101-v116-reception-report');
fs.mkdirSync(out,{recursive:true});
const report={checks:[],screenshots:[],errors:[],responses:[],passed:false};
const mime={'.html':'text/html','.js':'application/javascript','.css':'text/css','.svg':'image/svg+xml','.png':'image/png','.webp':'image/webp','.woff2':'font/woff2','.json':'application/json'};
const server=http.createServer((req,res)=>{
 let relative;try{relative=decodeURIComponent((req.url||'/').split('?')[0]);}catch{res.writeHead(400);res.end();return;}
 const file=path.resolve(root,'dist','.'+(relative==='/'?'/index.html':relative));
 if(!file.startsWith(path.join(root,'dist')+path.sep)||!fs.existsSync(file)||!fs.statSync(file).isFile()){res.writeHead(404);res.end();return;}
 res.setHeader('Content-Type',mime[path.extname(file)]||'application/octet-stream');
 res.end(fs.readFileSync(file));
});
await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
const check=(name,condition)=>{assert.ok(condition,name);report.checks.push(name);};
let browser;
try{
 const launch={headless:true};
 if(process.env.CD_BROWSER_EXECUTABLE)launch.executablePath=process.env.CD_BROWSER_EXECUTABLE;
 browser=await chromium.launch(launch);
 const page=await browser.newPage({viewport:{width:1440,height:900},reducedMotion:'reduce'});
 page.on('pageerror',e=>report.errors.push(e.message));
 page.on('response',r=>{if(r.status()>=400)report.responses.push([r.status(),r.url()]);});
 const base='http://127.0.0.1:'+server.address().port;
 await page.goto(base);
 await page.evaluate(()=>start(0));
 check('trois APIs chargees',await page.evaluate(()=>['CDEspoirsCoachingV101V104','CDSportingDirectorV105V110','CDFanExperienceV111V116'].every(k=>!!window[k])));
 check('trois commandes effectivement installees',await page.evaluate(()=>['v102Path','v105Priority','v112Price'].every(k=>typeof window[k]==='function')));
 const initial=await page.evaluate(()=>JSON.stringify(S));
 await page.evaluate(()=>nav('formation'));
 const youth=page.locator('.cd04-panel').filter({hasText:'V101–V104'});
 const formationDossiers=page.locator('[data-da43-section="formation"] [data-da42-subpage="dossiers"]');
 check('Formation : onglet Dossiers accessible',await formationDossiers.count()===1);
 await formationDossiers.click();
 check('Formation : panneau visible dans la page native',await youth.count()===1&&await youth.isVisible());
 check('Formation : diagnostic present',await youth.getByText('Diagnostic de coherence').count()===1);
 await page.screenshot({path:path.join(out,'formation-1440.png')});report.screenshots.push('formation-1440.png');
 // A blank academy is valid for some initial clubs; test real click only if eligible button exists.
 const youthButton=youth.getByRole('button',{name:'minutes',exact:true}).first();
 if(await youthButton.count() && await youthButton.isEnabled()){
   const before=await page.evaluate(()=>JSON.stringify(S.v101to104||null));
   await youthButton.click();
   check('Formation : clic parcours modifie un etat natif',await page.evaluate(()=>JSON.stringify(S.v101to104||null))!==before);
 }
 await page.evaluate(()=>nav('dashboard'));
 const dossiers=page.locator('[data-da42-subpage="dossiers"]');
 check('Bureau : onglet Dossiers accessible',await dossiers.count()>0);
 await dossiers.first().click();
 const director=page.locator('.cd04-panel').filter({hasText:'V105–V110'});
 const fans=page.locator('.cd04-panel').filter({hasText:'V111–V116'});
 check('Direction : panneau visible au Bureau Dossiers',await director.count()===1&&await director.isVisible());
 check('Supporters : panneau visible au Bureau Dossiers',await fans.count()===1&&await fans.isVisible());
 await page.screenshot({path:path.join(out,'dossiers-1440.png')});report.screenshots.push('dossiers-1440.png');
 const beforeDirection=await page.evaluate(()=>S.v105to110?.priority);
 await director.getByRole('button',{name:'performance',exact:true}).click();
 check('Direction : bouton cliquable et decision persistee en memoire',await page.evaluate(()=>S.v105to110?.priority)==='performance');
 check('Direction : priorite changee',beforeDirection!=='performance');
 // The manager choice re-renders the native workspace; reselect the Dossiers subpage.
 await page.locator('[data-da43-section="dashboard"] [data-da42-subpage="dossiers"]').first().click();
 const beforeFans=await page.evaluate(()=>S.v111to116?.price);
 await fans.getByRole('button',{name:/premium · 30/}).click();
 check('Supporters : prix mis a jour par clic',await page.evaluate(()=>S.v111to116?.price)==='premium');
 check('Supporters : prix change',beforeFans!=='premium');
 check('Sauvegarde native serialisable et relisible',await page.evaluate(()=>{
   const encoded=JSON.stringify(createSaveDocument());
   return !!parseSaveDocument(encoded);
 }));
 const saved=await page.evaluate(()=>JSON.parse(JSON.stringify(createSaveDocument())));
 check('Sauvegarde contient le choix Direction',await page.evaluate(()=>JSON.stringify(createSaveDocument()).includes('"performance"')));
 check('Sauvegarde contient le prix Supporters',await page.evaluate(()=>JSON.stringify(createSaveDocument()).includes('"premium"')));
 // Test native parser on legacy career lacking optional module fields.
 check('Ancienne sauvegarde sans modules V101-V116 lisible',await page.evaluate(doc=>{
   function omit(root){
     if(!root||typeof root!=='object')return;
     delete root.v101to104;delete root.v105to110;delete root.v111to116;
   }
   const old=JSON.parse(JSON.stringify(doc.state));
   omit(old);
   // Create a freshly checksummed export from the legacy state; never tamper with a signed file.
   const signed=createSaveDocument(old);
   return !!parseSaveDocument(JSON.stringify(signed));
 },saved));
 await page.reload();
 check('Jeu recharge sans erreur JS',await page.evaluate(()=>typeof start==='function'&&typeof parseSaveDocument==='function'));
 for(const [w,h] of [[1440,900],[1920,1080]]){
   await page.setViewportSize({width:w,height:h});
   await page.evaluate(()=>start(0));
   await page.evaluate(()=>nav('dashboard'));
   await page.locator('[data-da42-subpage="dossiers"]').first().click();
   check('Dossiers '+w+' sans debordement horizontal',await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+2));
   check('Dossiers '+w+' deux panneaux presents',await page.locator('.cd04-panel').filter({hasText:'V105–V110'}).count()===1&&await page.locator('.cd04-panel').filter({hasText:'V111–V116'}).count()===1);
   const shot='dossiers-'+w+'-responsive.png';await page.screenshot({path:path.join(out,shot)});report.screenshots.push(shot);
 }
 check('Aucune erreur JavaScript',report.errors.length===0);
 check('Aucun asset HTTP manquant',report.responses.length===0);
 report.passed=true;
}catch(error){
 report.errors.push(error.stack||String(error));
 const p=browser?.contexts()[0]?.pages()[0];
 if(p)await p.screenshot({path:path.join(out,'failure.png')}).catch(()=>{});
 throw error;
}finally{
 fs.writeFileSync(path.join(out,'report.json'),JSON.stringify(report,null,2));
 console.log(JSON.stringify({passed:report.passed,checks:report.checks.length,errors:report.errors,responses:report.responses}));
 if(browser)await browser.close();
 await new Promise(resolve=>server.close(resolve));
}
