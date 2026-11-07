/** Vrais parcours natifs, assets locaux et invariants de carrière ; aucun moteur de substitution. */
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
import {fileURLToPath} from 'node:url';
const require=createRequire(import.meta.url),{chromium}=require(process.env.CD_PLAYWRIGHT_MODULE||'playwright');
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..'),out=path.resolve(process.env.EDITORIAL_REPORT_DIR||path.join(root,'premium-editorial-report'));
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
 page.on('pageerror',e=>report.errors.push(e.message));page.on('response',r=>{if(r.status()>=400)report.badResponses.push({url:r.url(),status:r.status()});});
 await page.goto('http://127.0.0.1:'+server.address().port);await page.evaluate(()=>document.fonts.ready);await page.screenshot({path:path.join(out,'menu-1440.png')});
 await page.evaluate(()=>start(0));await page.evaluate(()=>document.fonts.ready);
 const routes=await page.evaluate(()=>Object.keys(CDEditorial.routes));
 // Les normalisations des modules natifs sont terminées avant la mesure UI.
 for(const route of routes)await page.evaluate(r=>nav(r),route);
 const disk=await page.evaluate(()=>localStorage.getItem('bdt-v1'));
 for(const [width,height] of [[1440,900],[1920,1080]]){
  await page.setViewportSize({width,height});
  for(const route of routes){
   const state=await page.evaluate(()=>JSON.stringify(S));
   await page.evaluate(r=>nav(r),route);await page.evaluate(()=>document.fonts.ready);
   await page.locator('[data-ed-route="'+route+'"]').first().waitFor();
   check(route+' '+width+' scène native',await page.locator('.main[data-ed-route="'+route+'"] .heading h1').isVisible());
   const geometry=await page.evaluate(()=>({width:document.documentElement.scrollWidth,height:document.documentElement.scrollHeight,main:document.querySelector('.main').getBoundingClientRect().toJSON(),font:getComputedStyle(document.querySelector('.heading h1')).fontFamily}));
   check(route+' '+width+' aucun débordement horizontal',geometry.width<=width+1);
   check(route+' '+width+' aucun scroll global',geometry.height<=height+1);
   check(route+' '+width+' police locale',geometry.font.includes('CD Cormorant'));
   check(route+' '+width+' carrière invariante',await page.evaluate(()=>JSON.stringify(S))===state);
   check(route+' '+width+' disque invariant',await page.evaluate(()=>localStorage.getItem('bdt-v1'))===disk);
   const name=route+'-'+width+'.png';await page.locator('#toast').evaluate(e=>e.style.display='none');await page.screenshot({path:path.join(out,name)});report.screens.push({route,width,height,file:name});
   const subpages=await page.locator('.main [data-da42-subpage],.main .ed-section-tabs button').all();
   for(let i=0;i<subpages.length;i++){
    const button=subpages[i];if(!await button.isVisible())continue;const label=await button.innerText();await button.click();
    check(route+' '+width+' sous-page '+label,await page.locator('.main :is(.da42-page,.ed-section-panel):visible').count()>0);
    check(route+' '+width+' sous-page sans mutation '+label,await page.evaluate(()=>JSON.stringify(S))===state);
   }
  }
 }
 await page.evaluate(()=>nav('tactics'));await page.locator('[data-da42-subpage="xv"]').click();check('quinze joueurs natifs sur le terrain',await page.locator('.ed-pitch-player[data-ed-player]').count()===15);const pitchState=await page.evaluate(()=>JSON.stringify(S));const pitchId=await page.locator('.ed-pitch-player[data-ed-player]').first().getAttribute('data-ed-player');await page.locator('.ed-pitch-player[data-ed-player]').first().click();check('terrain ouvre le vrai dossier',await page.locator('.cd02-player').getAttribute('data-cd02-player')===pitchId);check('lecture du terrain sans mutation',await page.evaluate(()=>JSON.stringify(S))===pitchState);
 await page.evaluate(()=>nav('market'));await page.locator('.markettabs button').filter({hasText:'Contrats'}).click();check('onglet Contrats affiche ses commandes',await page.getByRole('heading',{name:'Les engagements du club',exact:true}).isVisible());await page.locator('.markettabs button').filter({hasText:'Mouvements'}).click();check('onglet Mouvements réellement actif',await page.evaluate(()=>marketTab)==='history');await page.locator('.markettabs button').filter({hasText:'Recruter'}).click();check('candidats natifs à nouveau accessibles',await page.locator('.marketgrid').isVisible());
 await page.setViewportSize({width:1440,height:900});await page.evaluate(()=>{squadTab='table';nav('team');});
 await page.locator('.ed-section-tabs button').first().click();
 const first=page.locator('.cd02-player-link').first();const name=(await first.innerText()).trim();await first.click();
 check('fiche native ouverte',await page.locator('.cd02-player').isVisible());check('nom de la fiche conservé',(await page.locator('.cd02-player-header h2').innerText()).trim()===name);
 check('portrait fictif présent',await page.locator('.ed-profile-face .ed-portrait').isVisible());
 await page.screenshot({path:path.join(out,'player-profile-1440.png')});
 const profileTabs=await page.locator('[data-cd02-tab]').evaluateAll(els=>els.map(el=>el.dataset.cd02Tab));for(const tab of profileTabs){const b=page.locator('[data-cd02-tab="'+tab+'"]');await b.click();check('fiche onglet '+tab,await b.getAttribute('aria-selected')==='true');}
 await page.evaluate(()=>{squadTab='table';nav('team');});
 const input=page.getByRole('searchbox',{name:'Rechercher un joueur'});await input.fill('ZZZ-inexistant');check('recherche native sans résultat',await page.locator('.cd02-empty').isVisible());await input.fill('');check('groupe restauré',(await page.locator('[data-cd02-row]').count())===await page.evaluate(()=>club().players.length));
 await page.evaluate(()=>nav('dashboard'));await page.locator('[data-da42-subpage="pilotage"]').click();const chart=page.locator('.ed-bar-item').last();await chart.focus();await page.keyboard.press('Enter');check('graphique au clavier',await chart.getAttribute('aria-pressed')==='true');check('données de graphique lisibles',(await page.locator('.ed-chart-readout').first().innerText()).includes('joueur'));
 await page.locator('[data-ed-route="team"]').last().click();check('bouton graphique ouvre le groupe',await page.locator('.main[data-ed-route="team"]').count()===1);
 await page.evaluate(()=>nav('finance'));await page.locator('[data-da42-subpage="dossiers"]').click();const finance=page.locator('.finance-v2-native');check('cockpit financier conservé',await finance.isVisible());await finance.getByRole('button',{name:'Recettes',exact:true}).click();check('filtre financier natif',await finance.locator('.finv2-filter[aria-pressed=true]').innerText()==='Recettes');
 await page.locator('#ui01-theme').selectOption('tribune');check('thème clair conservé',await page.evaluate(()=>document.documentElement.dataset.cdTheme)==='tribune');const lightContrast=await page.evaluate(()=>{
 const probe=document.createElement('span');probe.style.color='var(--ed-gold)';document.body.append(probe);const color=getComputedStyle(probe).color;probe.style.color='var(--ed-panel)';const bg=getComputedStyle(probe).color;probe.remove();
 const lum=c=>{const parts=c.match(/[\d.]+/g).slice(0,3).map(Number).map(v=>{v/=255;return v<=.04045?v/12.92:Math.pow((v+.055)/1.055,2.4)});return parts[0]*.2126+parts[1]*.7152+parts[2]*.0722;};const a=lum(color),b=lum(bg);return (Math.max(a,b)+.05)/(Math.min(a,b)+.05);
 });check('contraste des chiffres et liens du thème clair',lightContrast>=4.5);
 await page.screenshot({path:path.join(out,'finance-light-1440.png')});
 await page.locator('#ui01-theme').selectOption('analyste');
 await page.evaluate(()=>{nav('match');beginMatch();pauseMatch();nav('saves');});
 check('sauvegardes accessibles pendant un match en pause',await page.locator('.main[data-ed-route="saves"] .ed-native-scroll').isVisible());
 check('contenu de sauvegarde défilable en match',await page.locator('.ed-native-scroll').evaluate(el=>getComputedStyle(el).overflowY==='auto'));
 await page.screenshot({path:path.join(out,'saves-paused-match-1440.png')});
 // Nouvelle carrière LNR : les visages fictifs ne sont pas associés aux sportifs réels.
 await page.evaluate(()=>start(0,'lnr'));await page.evaluate(()=>{squadTab='table';nav('team');});check('aucun faux portrait de sportif réel',await page.locator('.ed-team-overview .ed-portrait').count()===0);
 check('aucune erreur JavaScript',report.errors.length===0);check('aucun asset manquant',report.badResponses.length===0);report.passed=true;
}catch(error){report.errors.push(error.stack||String(error));throw error;}
finally{fs.writeFileSync(path.join(out,'report.json'),JSON.stringify(report,null,2));console.log(JSON.stringify({passed:report.passed,checks:report.checks.length,screens:report.screens.length,errors:report.errors.slice(-3)},null,2));if(browser)await browser.close();await new Promise(resolve=>server.close(resolve));}
