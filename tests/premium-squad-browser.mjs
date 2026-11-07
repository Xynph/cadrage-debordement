/** Réception du vrai dist/, sans application ou moteur de substitution. */
import assert from 'node:assert/strict';
import fs from 'node:fs';
import http from 'node:http';
import path from 'node:path';
import {createRequire} from 'node:module';
import {fileURLToPath} from 'node:url';
const require=createRequire(import.meta.url),{chromium}=require(process.env.CD_PLAYWRIGHT_MODULE||'playwright');
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..'),out=path.resolve(process.env.SQUAD_REPORT_DIR||path.join(root,'premium-squad-report'));
fs.mkdirSync(out,{recursive:true});
const report={passed:false,checks:[],screens:[],errors:[]},baseline=process.argv.includes('--baseline');
const server=http.createServer((req,res)=>{let url;try{url=decodeURIComponent(req.url.split('?')[0]);}catch{res.writeHead(400);res.end();return;}const file=path.resolve(root,'dist','.'+(url==='/'?'/index.html':url));if(!file.startsWith(path.join(root,'dist')+path.sep)||!fs.existsSync(file)||!fs.statSync(file).isFile()){res.writeHead(404);res.end();return;}res.setHeader('Content-Type',({'.html':'text/html','.js':'application/javascript','.css':'text/css','.webp':'image/webp','.svg':'image/svg+xml','.woff2':'font/woff2'})[path.extname(file)]||'application/octet-stream');res.end(fs.readFileSync(file));});
await new Promise(r=>server.listen(0,'127.0.0.1',r));let browser,page;
const check=(name,value)=>{assert.ok(value,name);report.checks.push(name);};
async function capture(name){await page.evaluate(()=>document.fonts.ready);await page.locator('#toast').evaluate(e=>e.style.display='none');await page.screenshot({path:path.join(out,name+'.png')});report.screens.push(name+'.png');}
async function bounds(label){const g=await page.evaluate(()=>({w:innerWidth,h:innerHeight,sw:document.documentElement.scrollWidth,sh:document.documentElement.scrollHeight}));check(label+' sans défilement global',g.sw<=g.w+1&&g.sh<=g.h+1);}
try{
 browser=await chromium.launch({headless:true,...(process.env.CD_BROWSER_EXECUTABLE?{executablePath:process.env.CD_BROWSER_EXECUTABLE}:{})});page=await browser.newPage({viewport:{width:1440,height:900},reducedMotion:'reduce'});
 await page.addInitScript(()=>{let seed=827381;Date.now=()=>1700000000000;Math.random=()=>{seed=(Math.imul(seed,1664525)+1013904223)>>>0;return seed/4294967296;};});
 page.on('pageerror',e=>report.errors.push(e.message));
 await page.goto('http://127.0.0.1:'+server.address().port);await page.evaluate(()=>{start(0);squadTab='table';nav('team');});await page.selectOption('#ui01-theme','analyste');
 for(const [width,height] of [[1440,900],[1920,1080]]){
  await page.setViewportSize({width,height});await page.evaluate(()=>{squadTab='table';nav('team');});await capture('effectif-'+width);
  if(!baseline){
   const visible=await page.locator('[data-cd02-row]').evaluateAll(rows=>rows.filter(e=>{const b=e.getBoundingClientRect(),p=e.closest('.cd02-table-scroll').getBoundingClientRect();return b.top>=p.top&&b.bottom<=p.bottom+1&&b.bottom<=innerHeight;}).length);
   check('dix lignes complètes '+width,visible>=10);report.checks.push('lignes visibles '+width+' : '+visible);await bounds('effectif '+width);
   check('toutes les actions de l’aperçu visibles '+width,await page.locator('.sq-preview button').evaluateAll(els=>els.every(e=>{const b=e.getBoundingClientRect(),p=e.closest('.sq-preview').getBoundingClientRect();return b.top>=p.top&&b.bottom<=p.bottom;})));
  }
  await page.locator('.cd02-player-link').first().click();await capture('fiche-'+width);
  if(!baseline){check('un seul radar '+width,await page.locator('.cd02-player-content svg').count()===1);await bounds('fiche '+width);}
 }
 if(baseline){report.passed=true;}else{
  await page.setViewportSize({width:1440,height:900});await page.evaluate(()=>{ui02Back();});
  const before=await page.evaluate(()=>JSON.stringify(S)),disk=await page.evaluate(()=>localStorage.getItem('bdt-v1'));
  await page.evaluate(()=>{const random=Math.random;window.__squadRng=0;Math.random=()=>{window.__squadRng++;return random();};});
  const preview=page.locator('[data-sq-select]').nth(3),id=await preview.getAttribute('data-sq-select');await preview.click();
  check('aperçu lié au joueur choisi',await page.locator('[data-sq-preview]').getAttribute('data-sq-preview')===id);
  await page.locator('[data-sq-open="comparison"]').first().click();check('comparaison ouverte',await page.locator('.sq-dialog[open]').count()===1);
  await page.locator('[data-ui02-compare="1"]').focus();await page.selectOption('[data-ui02-compare="1"]',await page.evaluate(id=>club().players.find(p=>p.id!==id).id,id));
  check('comparaison maintenue après rendu',await page.locator('.sq-dialog[open] .cd02-comparison').isVisible());
  check('focus conservé après sélection',await page.locator('[data-ui02-compare="1"]').evaluate(e=>e===document.activeElement));
  await capture('comparaison-1440');await page.locator('[data-ui02-clear]').click();check('effacer garde le focus et la fenêtre',await page.locator('.sq-dialog[open] [data-ui02-clear]').evaluate(e=>e===document.activeElement));await page.keyboard.press('Escape');check('Échap ferme la comparaison',await page.locator('.sq-dialog[open]').count()===0);
  check('focus restitué',await page.locator('[data-sq-open="comparison"]').first().evaluate(e=>e===document.activeElement));
  await page.locator('.sq-preview [data-sq-open="comparison"]').click();await page.keyboard.press('Escape');check('focus restitué à l’action d’origine',await page.locator('.sq-preview [data-sq-open="comparison"]').evaluate(e=>e===document.activeElement));
  await page.locator('[data-sq-open="training"]').click();check('charges natives accessibles',await page.locator('.sq-dialog[open] [data-ui02-training]').count()>0);await page.keyboard.press('Escape');
  const input=page.getByRole('searchbox',{name:'Rechercher un joueur'});await input.fill('ZZZ-inexistant');check('filtre vide sans ancien joueur',await page.locator('[data-sq-preview]').count()===0&&await page.locator('.cd02-empty').isVisible());await input.fill('');
  await page.selectOption('[data-cd02-action="preset"]','contracts');check('présentation contrats native',await page.locator('.cd02-table thead').first().innerText().then(t=>t.includes('contrat')));await page.selectOption('[data-cd02-action="preset"]','overview');
  await page.selectOption('[data-ui02-slot]','9');check('filtre de poste natif',await page.locator('[data-cd02-row]').evaluateAll(rows=>rows.every(r=>slotEligible(player(r.dataset.cd02Row),9))));await page.selectOption('[data-ui02-slot]','all');
  const selected=await page.locator('[data-sq-preview]').getAttribute('data-sq-preview');await page.locator('[data-cd02-sort="name"]').click();check('tri conserve l’aperçu par ID',await page.locator('[data-sq-preview]').getAttribute('data-sq-preview')===selected);
  await page.locator('.cd02-columns summary').click();await page.locator('[data-cd02-action="column"][value="name"]').uncheck();check('colonnes sans nom : aperçu toujours accessible',await page.locator('[data-sq-select]').count()>0&&await page.locator('.cd02-player-link').count()===0);await page.selectOption('[data-cd02-action="preset"]','overview');
  await page.locator('.cd02-player-link').first().click();const playerId=await page.locator('[data-cd02-player]').getAttribute('data-cd02-player');
  for(const tab of ['attributs','contrat','progression','profil']){await page.locator('[data-cd02-tab="'+tab+'"]').click();check('onglet natif '+tab,await page.locator('[data-cd02-tab="'+tab+'"]').getAttribute('aria-selected')==='true');}
  await page.locator('[data-sq-route="depth"]').click();check('couverture des postes native',await page.evaluate(()=>squadTab==='depth'));
  await page.evaluate(id=>{ui02ShowPlayer(id);},playerId);await page.locator('[data-sq-route="sheet"]').click();check('feuille à 23 native',await page.evaluate(()=>squadTab==='sheet'));
  await page.evaluate(id=>ui02ShowPlayer(id),playerId);await page.locator('[data-sq-contract]').click();check('contrat du bon joueur',await page.evaluate(id=>ui02ProfileId===id&&ui02Tab==='contrat',playerId));
  check('consultations : carrière et disque invariants',await page.evaluate(()=>JSON.stringify(S))===before&&await page.evaluate(()=>localStorage.getItem('bdt-v1'))===disk);
  check('consultations sans tirage aléatoire',await page.evaluate(()=>window.__squadRng)===0);
  await page.evaluate(()=>{ui02Back();});
  for(const theme of ['tribune','analyste']){await page.selectOption('#ui01-theme',theme);await bounds(theme);await capture('effectif-'+theme+'-1440');
   const contrast=await page.evaluate(()=>{const rgb=c=>c.match(/[\d.]+/g).map(Number),blend=(a,b)=>{const k=a.length<4?1:a[3];return [0,1,2].map(i=>a[i]*k+b[i]*(1-k));},lum=v=>{const c=v.slice(0,3).map(x=>{x/=255;return x<=.04045?x/12.92:((x+.055)/1.055)**2.4;});return .2126*c[0]+.7152*c[1]+.0722*c[2];};return ['.sq-preview .sq-kicker','.sq-grades b','.sq-facts dt','.sq-facts dd','.sq-preview .sq-primary'].map(selector=>{const e=document.querySelector(selector),layers=[];for(let a=e;a;a=a.parentElement)layers.push(rgb(getComputedStyle(a).backgroundColor));let bg=[7,25,16];for(const c of layers.reverse())bg=blend(c,bg);const a=lum(rgb(getComputedStyle(e).color)),b=lum(bg);return {selector,ratio:(Math.max(a,b)+.05)/(Math.min(a,b)+.05)};});});report.contrast??={};report.contrast[theme]=contrast;check('contraste des textes '+theme,contrast.every(x=>x.ratio>=4.5));
  }
  const longId=await page.evaluate(()=>{const p=club().players[0];window.__sqOldName=p.name;p.name='Jean-Baptiste de La Roche-Champfleury '.repeat(3);ui02ShowPlayer(p.id);return p.id;});
  check('nom long sans recouvrement',await page.locator('.cd02-player-header').evaluate(e=>{const name=e.querySelector('h2').getBoundingClientRect(),meta=e.querySelector('.cd02-header-meta').getBoundingClientRect();return name.right<=meta.left&&name.width<=e.clientWidth;}));await capture('fiche-nom-long-1440');await page.evaluate(id=>{player(id).name=window.__sqOldName;ui02Back();},longId);
  // Export/import natif d'une carrière avancée obtenue par les commandes moteur.
  await page.evaluate(()=>{trainWeek();autoLineup();nav('match');beginMatch();clearInterval(timer);CDMatchday.open('instant');CDMatchday.instant();finishRound();});
  const advanced=await page.evaluate(()=>JSON.stringify(createSaveDocument(S)));await page.evaluate(doc=>{pendingSave=parseSaveDocument(doc);confirmSaveImport();squadTab='table';nav('team');},advanced);
  check('carrière avancée native',await page.evaluate(()=>S.history.filter(r=>r.pair.includes(S.club)).length)===1);await capture('effectif-avance-1440');
  await page.locator('.cd02-player-link').first().click();check('fiche avancée',await page.locator('.sq-profile-overview').isVisible());await capture('fiche-avance-1440');
  await page.evaluate(()=>{trainWeek();ui02Back();});await page.locator('[data-sq-open="training"]').click();check('charges verrouillées après séance native',await page.locator('[data-ui02-training]').evaluateAll(els=>els.length>0&&els.every(e=>e.disabled)));await page.keyboard.press('Escape');
  await page.evaluate(()=>{start(0,'lnr');squadTab='table';nav('team');});check('LNR sans faux portraits',await page.locator('.ed-team-overview .ed-portrait').count()===0);await page.locator('.cd02-player-link').first().click();check('fiche LNR sans faux portrait',await page.locator('.ed-profile-face .ed-portrait').count()===0);await capture('fiche-lnr-1440');
  check('aucune erreur navigateur',report.errors.length===0);report.passed=true;
 }
}catch(error){report.errors.push(error.stack||String(error));throw error;}
finally{fs.writeFileSync(path.join(out,'report.json'),JSON.stringify(report,null,2));console.log(JSON.stringify({passed:report.passed,checks:report.checks.length,screens:report.screens.length,errors:report.errors.slice(-2)},null,2));if(browser)await browser.close();await new Promise(r=>server.close(r));}
