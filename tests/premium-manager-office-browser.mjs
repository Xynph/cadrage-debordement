/** Parcours du vrai jeu dans dist/, sans serveur ou moteur de substitution. */
import assert from 'node:assert/strict';
import fs from 'node:fs';
import http from 'node:http';
import path from 'node:path';
import {createRequire} from 'node:module';
import {fileURLToPath} from 'node:url';
const require=createRequire(import.meta.url),{chromium}=require(process.env.CD_PLAYWRIGHT_MODULE||'playwright');
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..'),out=path.resolve(process.env.OFFICE_REPORT_DIR||path.join(root,'premium-manager-office-report'));
fs.mkdirSync(out,{recursive:true});
const report={passed:false,checks:[],screens:[],errors:[],responses:[]};
const server=http.createServer((req,res)=>{
 let url;try{url=decodeURIComponent(req.url.split('?')[0]);}catch{res.writeHead(400);res.end();return;}
 const file=path.resolve(root,'dist','.'+(url==='/'?'/index.html':url));
 if(!file.startsWith(path.join(root,'dist')+path.sep)||!fs.existsSync(file)||!fs.statSync(file).isFile()){res.writeHead(404);res.end();return;}
 res.setHeader('Content-Type',({'.html':'text/html','.js':'application/javascript','.css':'text/css','.json':'application/json','.webp':'image/webp','.svg':'image/svg+xml','.woff2':'font/woff2'})[path.extname(file)]||'application/octet-stream');res.end(fs.readFileSync(file));
});
await new Promise(r=>server.listen(0,'127.0.0.1',r));
let browser,page;
const check=(name,value)=>{assert.ok(value,name);report.checks.push(name);};
async function capture(name){await page.evaluate(()=>document.fonts.ready);await page.locator('#toast').evaluate(e=>e.style.display='none');await page.screenshot({path:path.join(out,name+'.png')});report.screens.push(name+'.png');}
async function geometry(label){
 const g=await page.evaluate(()=>({w:innerWidth,h:innerHeight,sw:document.documentElement.scrollWidth,sh:document.documentElement.scrollHeight,panels:[...document.querySelectorAll('.ed-office>section')].map(e=>e.getBoundingClientRect().toJSON())}));
 check(label+' sans défilement global',g.sw<=g.w+1&&g.sh<=g.h+1);
 check(label+' cinq panneaux entièrement visibles',g.panels.length===5&&g.panels.every(b=>b.x>=0&&b.y>=0&&b.x+b.width<=g.w+1&&b.y+b.height<=g.h+1));
 for(const selector of ['.ed-office-position','.ed-office-watch button','.ed-office-match-actions','.ed-office-result-strip button small','.ed-office-results output']){
  const item=page.locator(selector).first();if(!await item.count()||!await item.isVisible())continue;
  check(label+' contenu lisible '+selector,await item.evaluate(e=>{const b=e.getBoundingClientRect(),p=e.closest('section').getBoundingClientRect(),local=e.closest('.ed-office-local')?.getBoundingClientRect();return b.y>=p.y&&b.bottom<=p.bottom&&(!local||b.y>=local.y&&b.bottom<=local.bottom);}));
 }
}
try{
 browser=await chromium.launch({headless:true,...(process.env.CD_BROWSER_EXECUTABLE?{executablePath:process.env.CD_BROWSER_EXECUTABLE}:{})});
 page=await browser.newPage({viewport:{width:1440,height:900},reducedMotion:'reduce',colorScheme:'dark'});
 // Même générateur déterministe que les tests natifs ; aucun score injecté.
 await page.addInitScript(()=>{let seed=827381;Date.now=()=>1700000000000;Math.random=()=>{seed=(Math.imul(seed,1664525)+1013904223)>>>0;return seed/4294967296;};});
 page.on('pageerror',e=>report.errors.push(e.message));page.on('response',r=>{if(r.status()>=400)report.responses.push([r.status(),r.url()]);});
 await page.goto('http://127.0.0.1:'+server.address().port);await page.evaluate(()=>start(0));await page.selectOption('#ui01-theme','analyste');
 check('Bureau connecté aux contrats natifs',await page.locator('.ed-office-decision[data-ed-office-tab="contracts"]').count()===1);
 await page.locator('.ed-office-decision[data-ed-office-tab="contracts"]').click();
 check('contrats : bon écran et bon onglet',await page.evaluate(()=>view==='market'&&marketTab==='contracts'));
 await page.evaluate(()=>nav('dashboard'));await page.locator('[data-ed-office-route="team"][data-ed-office-tab="sheet"]').click();
 check('feuille : destination native exacte',await page.evaluate(()=>view==='team'&&squadTab==='sheet'));
 await page.evaluate(()=>nav('dashboard'));const pid=await page.locator('.ed-office-watch [data-ed-player]').first().getAttribute('data-ed-player');await page.locator('.ed-office-watch [data-ed-player]').first().click();
 check('portrait : vrai dossier joueur',await page.locator('[data-cd02-player]').getAttribute('data-cd02-player')===pid);
 await page.evaluate(()=>nav('dashboard'));await page.locator('.ed-office-group [data-ed-office-tab="table"]').click();
 check('groupe : quitte le dossier pour le tableau',await page.evaluate(()=>squadTab==='table'&&!ui02ProfileId));
 await page.evaluate(()=>nav('dashboard'));
 const before=await page.evaluate(()=>JSON.stringify(S)),disk=await page.evaluate(()=>localStorage.getItem('bdt-v1'));
 await page.evaluate(()=>{const random=Math.random;window.__officeRng=0;Math.random=()=>{window.__officeRng++;return random();};});
 await page.locator('.ed-office-message').first().click();
 check('message : fenêtre native de lecture',await page.locator('.ed-office-message-dialog').isVisible());
 check('message : vrai corps',await page.locator('.ed-office-message-dialog').innerText().then(s=>s.includes('Retrouvez ici les échéances')));
 await capture('message-1440');await page.keyboard.press('Escape');
 await page.locator('.ed-office-message-dialog').waitFor({state:'detached'});
 check('message : Échap ferme',await page.locator('.ed-office-message-dialog').count()===0);
 check('message : focus rendu',await page.locator('.ed-office-message').first().evaluate(e=>e===document.activeElement));
 check('lecture : carrière et disque invariants',await page.evaluate(()=>JSON.stringify(S))===before&&await page.evaluate(()=>localStorage.getItem('bdt-v1'))===disk);
 await page.locator('.ed-bar-item').last().hover();check('survol : valeur réelle',await page.locator('.ed-office-group output').innerText().then(s=>s.includes('30 joueur')));
 await page.locator('.ed-bar-item').last().focus();await page.keyboard.press('Enter');check('clavier : valeur sélectionnée',await page.locator('.ed-bar-item').last().getAttribute('aria-pressed')==='true');
 for(const theme of ['analyste','tribune']){
  await page.selectOption('#ui01-theme',theme);
  const contrast=await page.evaluate(()=>{
   const selectors=['.ed-office-group .ed-office-kicker','.ed-office-decision b','.ed-office-decision small','.ed-office-message-body','.ed-office-position strong','.ed-office-sport header button','.ed-office-primary'];
   const rgb=c=>c.match(/[\d.]+/g).map(Number),blend=(a,b)=>{const k=a.length<4?1:a[3];return [0,1,2].map(i=>a[i]*k+b[i]*(1-k));};
   const lum=v=>{const c=v.slice(0,3).map(x=>{x/=255;return x<=.04045?x/12.92:((x+.055)/1.055)**2.4;});return .2126*c[0]+.7152*c[1]+.0722*c[2];};
   return selectors.map(selector=>{const el=document.querySelector(selector),layers=[];let ancestor=el;while(ancestor){layers.push(rgb(getComputedStyle(ancestor).backgroundColor));ancestor=ancestor.parentElement;}let bg=[7,25,16];for(const c of layers.reverse())bg=blend(c,bg);const a=lum(rgb(getComputedStyle(el).color)),b=lum(bg);return {selector,ratio:(Math.max(a,b)+.05)/(Math.min(a,b)+.05)};});
  });report.contrast??={};report.contrast[theme]=contrast;
  check(theme+' contraste des sept textes et commandes',contrast.every(x=>x.ratio>=4.5));
  for(const [width,height] of [[1440,900],[1920,1080]]){await page.setViewportSize({width,height});await geometry(theme+' '+width);await capture('new-'+theme+'-'+width);}
 }
 check('consultation : aucun appel RNG',await page.evaluate(()=>window.__officeRng)===0);
 await page.selectOption('#ui01-theme','analyste');await page.setViewportSize({width:1440,height:900});
 await page.locator('[data-ed-office-page="dossiers"]').first().click();check('Dossiers : modules précédents conservés',await page.locator('[data-da42-page="dossiers"]').isVisible());
 await page.locator('[data-da42-subpage="calendrier"]').click();check('Calendrier : sous-page conservée',await page.locator('[data-da42-page="calendrier"]').isVisible());
 await page.locator('[data-da42-subpage="pilotage"]').click();
 await page.locator('.ed-office-message').first().click();await page.locator('[data-office-dialog-read]').click();
 check('lecture : marquage métier persisté',await page.evaluate(()=>S.manager.inbox[0].read)&&await page.evaluate(()=>JSON.parse(localStorage.getItem('bdt-v1')).manager.inbox[0].read));
 // Quatre journées par entraînement, composition et délégation natifs, sans scores fabriqués.
 await page.evaluate(()=>{for(let i=0;i<4;i++){trainWeek();autoLineup();nav('match');beginMatch();clearInterval(timer);if(!S.live)throw Error('Feuille native non éligible à J'+(S.round+1)+' : '+sheetErrors().join(' '));CDMatchday.open('instant');if(!CDMatchday.instant())throw Error('Délégation non terminée');finishRound();}});
 check('carrière avancée : quatre matchs vraiment enregistrés',await page.evaluate(()=>S.history.filter(r=>r.pair.includes(S.club)).length)===4);
 const advanced=await page.evaluate(()=>JSON.stringify(S));
 await page.locator('[data-da42-subpage="pilotage"]').click();
 const last=await page.evaluate(()=>{const r=CDArtDirection.snapshot().results.at(-1);return r.own+'–'+r.against;});
 check('scores : dernier vrai résultat',await page.locator('.ed-office-result-strip').innerText().then(s=>s.includes(last)));
 await page.locator('.ed-office-result-strip button').last().click();check('résultat : détail au clic',await page.locator('.ed-office-sport output').innerText().then(s=>s.includes(last)));
 for(const [width,height] of [[1440,900],[1920,1080]]){await page.setViewportSize({width,height});await geometry('avancée '+width);await capture('advanced-'+width);}
 check('consultation avancée : invariante',await page.evaluate(()=>JSON.stringify(S))===advanced);
 check('export et parseur natifs',await page.evaluate(()=>!!parseSaveDocument(JSON.stringify(createSaveDocument()))));
 // Stress de texte uniquement : aucune donnée sportive inventée pour les captures.
 await page.setViewportSize({width:1440,height:900});
 await page.evaluate(()=>{S.clubs[nextMatch().find(id=>id!==S.club)].name='Un nom de club particulièrement long '.repeat(8);S.manager.inbox[0].body='Un compte rendu détaillé et lisible.\n'.repeat(200);render();});
 check('nom long : ne recouvre pas les commandes',await page.locator('.ed-office-match h2').evaluate(e=>e.getBoundingClientRect().bottom<=document.querySelector('.ed-office-match-actions').getBoundingClientRect().top));
 check('nom long : enjeux sportifs avant les commandes',await page.locator('.ed-office-stakes').evaluate(e=>e.getBoundingClientRect().bottom<=document.querySelector('.ed-office-match-actions').getBoundingClientRect().top));
 await page.locator('.ed-office-message').first().click();
 check('message long : fenêtre et boutons dans l’écran',await page.locator('.ed-office-message-dialog footer').evaluate(e=>{const b=e.getBoundingClientRect();return b.top>=0&&b.bottom<=innerHeight;}));
 await page.keyboard.press('Escape');
 await page.evaluate(text=>{S=JSON.parse(text);render();},advanced);
 await page.evaluate(()=>start(0,'lnr'));check('LNR : aucun faux portrait',await page.locator('.ed-office .ed-portrait').count()===0);
 for(const [width,height] of [[1440,900],[1920,1080]]){
  await page.setViewportSize({width,height});await geometry('LNR '+width);
  check('LNR '+width+' lettres descendantes du titre entières',await page.locator('.ed-office-match h2').evaluate(e=>{
   const style=getComputedStyle(e),canvas=document.createElement('canvas'),ctx=canvas.getContext('2d');ctx.font=style.fontStyle+' '+style.fontWeight+' '+style.fontSize+' '+style.fontFamily;
   const descent=ctx.measureText(e.textContent).actualBoundingBoxDescent,probe=document.createElement('span');probe.style.cssText='display:inline-block;width:0;height:0;vertical-align:baseline';e.append(probe);
   const visible=e.getBoundingClientRect().bottom-probe.getBoundingClientRect().top>=descent;probe.remove();return visible;
  }));await capture('lnr-'+width);
 }
 check('aucune erreur JavaScript',report.errors.length===0);check('aucune ressource manquante',report.responses.length===0);report.passed=true;
}catch(error){report.errors.push(error.stack||String(error));if(page)await capture('failure').catch(()=>{});throw error;}
finally{fs.writeFileSync(path.join(out,'report.json'),JSON.stringify(report,null,2));console.log(JSON.stringify({passed:report.passed,checks:report.checks.length,screens:report.screens.length,errors:report.errors}));await browser?.close();await new Promise(r=>server.close(r));}
