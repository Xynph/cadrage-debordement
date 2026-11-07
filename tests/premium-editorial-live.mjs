/** Vrais parcours natifs, assets locaux et invariants de carrière ; aucun moteur de substitution. */
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
import {fileURLToPath} from 'node:url';
const require=createRequire(import.meta.url),{chromium}=require(process.env.CD_PLAYWRIGHT_MODULE||'playwright');
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..'),out=path.resolve(process.env.EDITORIAL_REPORT_DIR||path.join(root,'premium-matchroom-report'));
fs.mkdirSync(out,{recursive:true});
const server=http.createServer((req,res)=>{let decoded;try{decoded=decodeURIComponent((req.url||'/').split('?')[0]);}catch{res.writeHead(400);res.end();return;}const file=path.resolve(root,'dist','.'+(decoded==='/'?'/index.html':decoded));if(!file.startsWith(path.join(root,'dist')+path.sep)||!fs.existsSync(file)||!fs.statSync(file).isFile()){res.writeHead(404);res.end();return;}res.setHeader('Content-Type',({'.html':'text/html','.js':'application/javascript','.css':'text/css','.webp':'image/webp','.svg':'image/svg+xml','.woff2':'font/woff2','.json':'application/json'})[path.extname(file)]||'application/octet-stream');res.end(fs.readFileSync(file));});
await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
const report={passed:false,checks:[],screens:[],errors:[],badResponses:[]},launch={headless:true};
if(process.env.CD_BROWSER_EXECUTABLE)launch.executablePath=process.env.CD_BROWSER_EXECUTABLE;
if(process.env.CD_BROWSER_ARGS)launch.args=JSON.parse(fs.readFileSync(process.env.CD_BROWSER_ARGS,'utf8'));
let browser;
function check(label,value){assert.ok(value,label);report.checks.push(label);}
try{
 browser=await chromium.launch(launch);const page=await browser.newPage({viewport:{width:1440,height:900},colorScheme:'dark',reducedMotion:'reduce'});
 page.on('pageerror',e=>report.errors.push(e.message));page.on('response',r=>{if(r.status()>=400)report.badResponses.push(r.url());});
 await page.goto('http://127.0.0.1:'+server.address().port);await page.evaluate(()=>{start(0);nav('match');beginMatch();pauseMatch();});
 await page.evaluate(()=>{window.__edUiRngCalls=0;const original=Math.random;Math.random=()=>{window.__edUiRngCalls++;return original();};});
 const state=await page.evaluate(()=>JSON.stringify(S)),disk=await page.evaluate(()=>localStorage.getItem('bdt-v1'));
 for(const [width,height] of [[1440,900],[1920,1080]]){
  await page.setViewportSize({width,height});
  for(const theme of ['analyste','tribune']){
   await page.evaluate(t=>{ui01SetTheme(t);render();},theme);
   check('thème natif '+theme,await page.evaluate(()=>document.documentElement.dataset.cdTheme)===theme);
   for(const focus of ['terrain','effectif','analyse','tactique']){
    await page.evaluate(f=>chooseMatchCockpitFocus(f),focus);await page.evaluate(()=>document.fonts.ready);
    const active=page.locator('.ed-live-page:not([hidden])');check('une seule page '+width+theme+focus,await active.count()===1);
    check('panneau réel '+focus,await active.getAttribute('data-ed-live-page')===focus);
    check('carrière invariante '+focus,await page.evaluate(()=>JSON.stringify(S))===state);
    check('disque invariant '+focus,await page.evaluate(()=>localStorage.getItem('bdt-v1'))===disk);
    check('aucun scroll global '+focus,await page.evaluate(()=>document.documentElement.scrollHeight<=innerHeight+1&&document.documentElement.scrollWidth<=innerWidth+1));
    if(focus==='terrain'){
     const b=await page.locator('.match-field').boundingBox();check('terrain entier immédiatement visible '+width+theme,!!b&&b.y>=0&&b.y+b.height<=height&&b.height>=300);
     check('commentaire visible',await page.locator('.match-commentary').isVisible());
    }else if(focus==='effectif'){
     check('deux vrais groupes',await page.locator('.ed-live-page:not([hidden]) .v40-roster').count()===2);
     check('trente lignes natives',await page.locator('.v40-roster-row').count()===30);
     check('changement conservé',await page.locator('.ed-live-page:not([hidden]) select[aria-label="Remplaçant poste 1"]').count()===1);
    }else if(focus==='analyse')check('observatoire natif accessible',await page.locator('.match-tactical-observatory').isVisible());
    else check('conseiller natif accessible',await page.locator('.v61-advisor').isVisible());
    const samples=({terrain:['.full-pitch-label','.auto-pause label','.latest-event p'],effectif:['.v40-player-link','.v40-shirt','.v40-condition','.v40-roster header small'],analyse:['.card p','.v40-stats-head','.v40-metric-line span'],tactique:['.card p','.v40-tactics label']})[focus];for(const selector of samples){const paragraph=active.locator(selector).first();check('échantillon présent '+theme+focus+selector,await paragraph.count()===1);if(await paragraph.count()){
     const ratio=await paragraph.evaluate(el=>{const rgb=s=>(s.match(/[0-9.]+/g)||[]).map(Number),lum=c=>c.slice(0,3).map(x=>x/255).map(x=>x<=.04045?x/12.92:((x+.055)/1.055)**2.4).reduce((s,x,i)=>s+x*[.2126,.7152,.0722][i],0);let n=el,b;while(n){b=rgb(getComputedStyle(n).backgroundColor);if(b.length===3||b[3]>.99)break;n=n.parentElement;}const a=lum(rgb(getComputedStyle(el).color)),z=lum(b);return(Math.max(a,z)+.05)/(Math.min(a,z)+.05);});check('contraste du texte '+theme+focus,ratio>=4.5);
    }
    }
    const file='live-'+focus+'-'+theme+'-'+width+'.png';await page.locator('#toast').evaluate(e=>e.style.display='none');await page.screenshot({path:path.join(out,file)});report.screens.push({file,width,height,focus,theme});
   }
  }
 }
 check('aucun tirage aléatoire en consultation',await page.evaluate(()=>window.__edUiRngCalls)===0);
 await page.evaluate(()=>chooseMatchCockpitFocus('terrain'));await page.locator('[data-ed-live-tab="terrain"]').focus();await page.keyboard.press('ArrowRight');
 check('clavier change de page',await page.locator('.ed-live-page:not([hidden])').getAttribute('data-ed-live-page')==='effectif');
 await page.evaluate(()=>render());
 check('focus après nouveau rendu natif',await page.locator('[data-ed-live-tab="effectif"]').evaluate(e=>e===document.activeElement));
 await page.locator('.ed-live-page:not([hidden]) .v40-player-link').first().click();check('fiche native en match',await page.locator('.modalback').isVisible());await page.evaluate(()=>closeModal());
 const sub=page.locator('select[aria-label="Remplaçant poste 1"]');const id=await sub.locator('option').evaluateAll(options=>options.find(o=>o.value)?.value);
 check('remplaçant éligible natif',!!id);await sub.selectOption(id);check('remplacement réellement appliqué',await page.evaluate(id=>S.live.sheets[S.live.userSide].on[0]===id,id));
 await page.evaluate(()=>chooseMatchCockpitFocus('tactique'));await page.locator('.v40-advanced summary').click();check('commandes détaillées natives accessibles',await page.locator('#live-tactic').isVisible());const attack=page.locator('#v40-attack');const next=await attack.locator('option').evaluateAll(options=>options.find(o=>!o.selected)?.value);await attack.selectOption(next);check('consigne réellement appliquée',await page.evaluate(key=>S.live.tactics[S.live.userSide]===key,next));check('export natif valide après décisions',await page.evaluate(()=>!!parseSaveDocument(JSON.stringify(createSaveDocument()))));
 await page.evaluate(()=>chooseMatchCockpitFocus('terrain'));const before3d=await page.evaluate(()=>JSON.stringify(S));await page.locator('.cd3d-toolbar button').filter({hasText:'3D'}).click();await page.locator('#cd3d-host').waitFor();check('3D native conservée',await page.evaluate(()=>CDMatch3D.getMode())==='3d');await page.locator('#cd3d-host canvas').waitFor();
 for(const [width,height] of [[1440,900],[1920,1080]]){await page.setViewportSize({width,height});await page.waitForFunction(()=>{const e=document.querySelector('#cd3d-host canvas');return e&&e.width>0;});const box=await page.locator('#cd3d-host canvas').boundingBox(),host=await page.locator('#cd3d-host').boundingBox();check('canvas 3D entier '+width,!!box&&!!host&&box.y+box.height<=height&&box.x>=host.x-1&&box.y>=host.y-1&&box.x+box.width<=host.x+host.width+1&&box.y+box.height<=host.y+host.height+1);check('ratio 3D conservé '+width,Math.abs(box.width/box.height-16/9)<.02);await page.screenshot({path:path.join(out,'live-3d-'+width+'.png')});report.screens.push({file:'live-3d-'+width+'.png',width,height,mode:'3d'});}
await page.locator('.cd3d-toolbar button').filter({hasText:'2D'}).click();check('retour 2D natif',await page.locator('.match-field').isVisible());check('modes sans mutation',await page.evaluate(()=>JSON.stringify(S))===before3d);
 await page.evaluate(()=>{start(0,'lnr');nav('match');beginMatch();pauseMatch();chooseMatchCockpitFocus('effectif');});check('aucun portrait fictif LNR',await page.locator('.ed-live-pages .ed-portrait').count()===0);
 check('aucune erreur JS',report.errors.length===0);check('aucun asset manquant',report.badResponses.length===0);report.passed=true;
}catch(e){report.errors.push(e.stack||String(e));const page=browser?.contexts()[0]?.pages()[0];if(page)await page.screenshot({path:path.join(out,'failure.png')}).catch(()=>{});throw e;}finally{fs.writeFileSync(path.join(out,'report.json'),JSON.stringify(report,null,2));console.log(JSON.stringify({passed:report.passed,checks:report.checks.length,screens:report.screens.length,errors:report.errors}));if(browser)await browser.close();await new Promise(r=>server.close(r));}
