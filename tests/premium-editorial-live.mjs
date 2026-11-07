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
function check(label,value){assert.ok(value,label);report.checks.push(label);console.log(label);}
try{
 browser=await chromium.launch(launch);const page=await browser.newPage({viewport:{width:1440,height:900},colorScheme:'dark',reducedMotion:'reduce'});
 page.setDefaultTimeout(10000);page.on('pageerror',e=>report.errors.push(e.message));page.on('response',r=>{if(r.status()>=400)report.badResponses.push(r.url());});
 await page.goto('http://127.0.0.1:'+server.address().port);await page.evaluate(()=>{start(0);nav('match');beginMatch();pauseMatch();});
 check('contrôleur installé',await page.evaluate(()=>!!window.CDMatchday));
 await page.evaluate(()=>{window.__edUiRngCalls=0;const original=Math.random;Math.random=()=>{window.__edUiRngCalls++;return original();};});
 const state=await page.evaluate(()=>JSON.stringify(S)),disk=await page.evaluate(()=>localStorage.getItem('bdt-v1'));
 for(const [width,height] of [[1440,900],[1920,1080]]){
  await page.setViewportSize({width,height});
  for(const theme of ['analyste','tribune']){
   await page.evaluate(t=>{ui01SetTheme(t);render();},theme);await page.evaluate(()=>document.fonts.ready);
   for(const pane of [null,'tactics','subs','stats','settings','instant']){
    await page.evaluate(p=>p?CDMatchday.open(p):CDMatchday.close(),pane);
    check('colonne permanente '+width+theme+pane,await page.locator('.md-statistics').isVisible());
    check('huit portraits '+width+theme+pane,await page.locator('.md-bench-card').count()===8);
    check('carrière invariante '+pane,await page.evaluate(()=>JSON.stringify(S))===state);
    check('disque carrière invariant '+pane,await page.evaluate(()=>localStorage.getItem('bdt-v1'))===disk);
    check('aucun scroll global '+pane,await page.evaluate(()=>document.documentElement.scrollHeight<=innerHeight+1&&document.documentElement.scrollWidth<=innerWidth+1));
    const contrast=await page.locator('.md-stat small').first().evaluate(el=>{const rgb=s=>(s.match(/[0-9.]+/g)||[]).map(Number),lum=c=>c.slice(0,3).map(x=>x/255).map(x=>x<=.04045?x/12.92:((x+.055)/1.055)**2.4).reduce((s,x,i)=>s+x*[.2126,.7152,.0722][i],0);let n=el,b;while(n){const style=getComputedStyle(n),gradient=style.backgroundImage.match(/rgba?\([^)]+\)/);b=rgb(gradient?gradient[0]:style.backgroundColor);if(gradient||b.length===3||b[3]>.99)break;n=n.parentElement;}const a=lum(rgb(getComputedStyle(el).color)),z=lum(b);return(Math.max(a,z)+.05)/(Math.min(a,z)+.05);});check('contraste statistiques '+theme,contrast>=4.5);const stats=await page.locator('.md-statistics').boundingBox();check('stats entières '+pane,stats.y>=0&&stats.y+stats.height<=height);
    const ticker=await page.locator('.md-ticker').boundingBox();check('commentaire discret en bas',ticker.height<=35&&ticker.y+ticker.height<=height+1);
    if(!pane){const field=await page.locator('.match-field').boundingBox();check('terrain entier visible '+width,field&&field.y>=0&&field.y+field.height<=height&&field.height>=300);check('aucun menu club',!await page.locator('.sidebar').isVisible());}
    else{const dlg=await page.locator('.md-dialog').boundingBox();check('fenêtre préserve stats '+pane,dlg.x+dlg.width<=stats.x);check('fenêtre entière '+pane,dlg.y>=0&&dlg.y+dlg.height<=height);}
    await page.locator('#toast').evaluate(e=>e.style.display='none');const file='dedicated-'+(pane||'terrain')+'-'+theme+'-'+width+'.png';await page.screenshot({timeout:60000,path:path.join(out,file)});report.screens.push({file,width,height,pane,theme});
   }
  }
 }
 check('aucun RNG en consultation',await page.evaluate(()=>window.__edUiRngCalls)===0);
 await page.evaluate(()=>CDMatchday.close());await page.locator('[data-md-key="tactics"]').click();check('ouverture au clic',await page.locator('.md-dialog').isVisible());await page.keyboard.press('Escape');check('echap ferme fenêtre',await page.locator('.md-dialog').count()===0);check('focus rendu au bouton',await page.locator('[data-md-key="tactics"]').evaluate(e=>e===document.activeElement));
 // Consultation : aucun saut, pas de pause et restauration des préférences.
 await page.evaluate(()=>{CDMatchday.setPreference('mode','highlights');CDMatchday.setPreference('speed',8);CDMatchday.setPreference('gapSpeed',300);continueMatch();clearInterval(timer);syncMatchPresentation(S.live);window.__beforeMinute=S.live.minute;window.__beforeSecond=CDMatchday.getState().second;CDMatchday.open('subs');CDMatchday.step(1);});
 check('fenêtre ne met pas en pause',await page.evaluate(()=>!S.live.paused));check('une seconde en consultation',await page.evaluate(()=>S.live.minute===__beforeMinute&&CDMatchday.getState().second===__beforeSecond+1));
 await page.evaluate(()=>CDMatchday.close());check('mode et vitesses restaurés',await page.evaluate(()=>JSON.stringify(CDMatchday.getPreferences()))===JSON.stringify({mode:'highlights',speed:8,gapSpeed:300,camera:'tactical',display:'2d'}));await page.evaluate(()=>pauseMatch());
 // Un brouillon reste intact après les rendus périodiques.
 const change=await page.evaluate(()=>{const l=S.live;for(let slot=0;slot<15;slot++){const p=eligibleChanges(l,l.userSide,slot)[0];if(p)return {slot,id:p.id,out:l.sheets[l.userSide].on[slot]};}});check('changement éligible trouvé',!!change);
 await page.locator('.md-bench-card').filter({has:page.locator('b')}).first().click();check('portrait ouvre remplacement',await page.locator('#md-dialog-title').textContent()==='Remplacements directs');await page.evaluate(()=>CDMatchday.close());
 await page.evaluate(()=>CDMatchday.open('tactics'));await page.locator('.md-xv [data-ed-player]').first().click();check('mini terrain reste en match',await page.evaluate(()=>view==='match'));check('mini terrain ouvre changements',await page.locator('#md-dialog-title').textContent()==='Remplacements directs');await page.evaluate(()=>CDMatchday.open('tactics'));await page.locator('[data-md-key="sub-'+change.slot+'"]').selectOption(change.id);await page.locator('[data-md-key="sub-'+change.slot+'"]').focus();await page.evaluate(()=>render());check('brouillon conservé',await page.locator('[data-md-key="sub-'+change.slot+'"]').inputValue()===change.id);check('focus conservé au rafraîchissement',await page.locator('[data-md-key="sub-'+change.slot+'"]').evaluate(e=>e===document.activeElement));
 await page.evaluate(()=>{S.live.minute=10;if(S.live.flow){S.live.flow.ballDead=false;S.live.flow.advantage=null;}});await page.locator('[data-md-key="confirm-changes"]').click();check('remplacement en attente',await page.evaluate(()=>CDMatchday.getState().queue.length)===1);check('pas de remplacement en ballon vivant',await page.evaluate(c=>S.live.sheets[S.live.userSide].on[c.slot]===c.out,change));
 await page.locator('[data-md-key="queue-0"]').click();check('annulation attente',await page.evaluate(()=>CDMatchday.getState().queue.length)===0);
 await page.evaluate(c=>{CDMatchday.open('subs');CDMatchday.selectSub(c.slot,c.id);CDMatchday.confirm();syncMatchPresentation(S.live);grantSetPiece(S.live,'scrum',S.live.userSide,50,'knock-on',1-S.live.userSide,50);render();},change);check('remplacement natif effectué à arrêt',await page.evaluate(c=>S.live.sheets[S.live.userSide].on[c.slot]===c.id,change));check('huit portraits après entrée',await page.locator('.md-bench-card').count()===8);check('statut terrain visible',await page.locator('.md-bench-card.is-playing').count()>=1);
 await page.evaluate(()=>CDMatchday.open('tactics'));await page.locator('[data-md-key="tab-instructions"]').click();const attack=page.locator('[data-md-key="attack"]'),next=await attack.locator('option').evaluateAll(o=>o.find(x=>!x.selected).value);await attack.selectOption(next);await page.locator('[data-md-key="confirm-changes"]').click();check('consigne native appliquée',await page.evaluate(k=>S.live.tactics[S.live.userSide]===k,next));
 await page.evaluate(()=>{S.live.stats[S.live.userSide].territory=1;S.live.stats[1-S.live.userSide].territory=100;render();});const advice=page.locator('[data-md-key="advice-attack"]');check('conseil applicable',await advice.isEnabled());await advice.click();check('conseil réel appliqué',await page.evaluate(()=>S.live.tactics[S.live.userSide]===matchV61Advice(S.live).attack));
 await page.evaluate(()=>{S.live.paused=false;CDMatchday.open('tactics');CDMatchday.tab('advanced');});check('plan détaillé modifiable en temps réel',await page.locator('[data-md-key="plan-scrum"]').isEnabled());await page.locator('[data-md-key="plan-scrum"]').selectOption('securiser');await page.locator('[data-md-key="zone-sortie-attack"]').selectOption('occupation');await page.evaluate(()=>{clearInterval(timer);CDMatchday.step(1);});check('sélecteur conservé pendant tick',await page.locator('[data-md-key="zone-sortie-attack"]').inputValue()==='occupation');await page.locator('[data-md-key="confirm-changes"]').click();check('plan détaillé appliqué ensemble sans pause',await page.evaluate(()=>!S.live.paused&&S.live.playbooks[S.live.userSide].scrum==='securiser'&&S.live.playbooks[S.live.userSide].zones.sortie.attack==='occupation'));await page.evaluate(()=>pauseMatch());
 // Rouge et mi-temps imposent une pause même pendant la consultation.
 await page.evaluate(()=>{S.live.paused=false;CDMatchday.open('stats');S.live.sheets[1-S.live.userSide].sentOff.push('test-red');CDMatchday.step(1);});check('pause rouge impérative',await page.evaluate(()=>S.live.paused&&CDMatchday.getState().pauseReason.includes('rouge')));await page.evaluate(()=>{S.live.sheets[1-S.live.userSide].sentOff.pop();CDMatchday.close();});
 check('export natif après décisions',await page.evaluate(()=>!!parseSaveDocument(JSON.stringify(createSaveDocument()))));
 // Confirmation isolée : annuler ne simule rien.
 await page.evaluate(()=>CDMatchday.close());const beforeInstant=await page.evaluate(()=>JSON.stringify(S));await page.locator('[data-md-key="instant"]').click();check('confirmation avant délégation',await page.locator('[data-md-key="confirm-instant"]').isVisible());await page.locator('[data-md-key="cancel-instant"]').click();check('annuler sans mutation',await page.evaluate(()=>JSON.stringify(S))===beforeInstant);
 // 3D entière et retour 2D sans mutation de carrière.
 const before3d=await page.evaluate(()=>JSON.stringify(S));await page.evaluate(()=>CDMatchday.setPreference('display','3d'));await page.locator('#cd3d-host canvas').waitFor();
 for(const [width,height] of [[1440,900],[1920,1080]]){await page.setViewportSize({width,height});await page.waitForFunction(()=>document.querySelector('#cd3d-host canvas')?.width>0);const b=await page.locator('#cd3d-host canvas').boundingBox(),h=await page.locator('.md-field').boundingBox();check('canvas 3D entier '+width,b&&h&&b.x>=h.x-1&&b.y>=h.y-1&&b.x+b.width<=h.x+h.width+1&&b.y+b.height<=h.y+h.height+1);check('ratio canvas '+width,Math.abs(b.width/b.height-16/9)<.02);const file='dedicated-3d-'+width+'.png';await page.screenshot({timeout:60000,path:path.join(out,file)});report.screens.push({file,width,height,mode:'3d'});}
 await page.evaluate(()=>CDMatchday.setPreference('display','2d'));check('retour 2D',await page.locator('.match-field').isVisible());check('vue sans mutation',await page.evaluate(()=>JSON.stringify(S))===before3d);
 await page.evaluate(()=>{CDMatchday.open('instant');CDMatchday.instant();});check('résultat immédiat atteint fin sans mi-temps bloquante',await page.evaluate(()=>S.live.finished));check('export final valide',await page.evaluate(()=>!!parseSaveDocument(JSON.stringify(createSaveDocument()))));
 await page.locator('[data-md-key="finish"]').click();check('retour club après validation',await page.evaluate(()=>!S.live&&view==='dashboard'));
 await page.evaluate(()=>{start(0);nav('match');beginMatch();clearInterval(timer);const l=S.live;let guard=0;while(matchMinute(l)<62&&!l.finished&&guard++<100){l.paused=false;advanceRugby(l);}pauseMatch();syncMatchPresentation(l);render();});
 for(const [width,height] of [[1440,900],[1920,1080]]){await page.setViewportSize({width,height});await page.locator('#toast').evaluate(e=>e.style.display='none');const file='dedicated-played-'+width+'.png';await page.screenshot({timeout:60000,path:path.join(out,file)});report.screens.push({file,width,height,mode:'played'});}check('mesures après vrai match joué',await page.evaluate(()=>S.live.stats[0].possession+S.live.stats[1].possession>50));
 const preferences=await page.evaluate(()=>CDMatchday.getPreferences());await page.reload();check('préférences mémorisées',await page.evaluate(()=>JSON.stringify(CDMatchday.getPreferences()))===JSON.stringify(preferences));
 await page.evaluate(()=>{start(0,'lnr');nav('match');beginMatch();pauseMatch();});check('aucun faux visage LNR',await page.locator('.md-bench .ed-portrait').count()===0);
 check('aucune erreur JS',report.errors.length===0);check('aucun asset manquant',report.badResponses.length===0);report.passed=true;
}catch(e){report.errors.push(e.stack||String(e));const page=browser?.contexts()[0]?.pages()[0];if(page)await page.screenshot({timeout:60000,path:path.join(out,'failure.png')}).catch(()=>{});throw e;}finally{fs.writeFileSync(path.join(out,'report.json'),JSON.stringify(report,null,2));console.log(JSON.stringify({passed:report.passed,checks:report.checks.length,screens:report.screens.length,errors:report.errors}));if(browser)await browser.close();await new Promise(r=>server.close(r));}
