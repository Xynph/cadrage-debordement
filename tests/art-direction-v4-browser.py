"""Direction artistique : graphiques exacts, contrôles natifs et vraies captures."""
import functools,http.server,threading,json,os
from pathlib import Path
from playwright.sync_api import sync_playwright
ROOT=Path(__file__).resolve().parents[1]
OUT=Path(os.environ.get('DA4_REPORT_DIR',str(ROOT/'ui01-browser-report'/'art-direction-v4')))
OUT.mkdir(parents=True,exist_ok=True)
class Handler(http.server.SimpleHTTPRequestHandler):
 def log_message(self,*a):pass
srv=http.server.ThreadingHTTPServer(('127.0.0.1',0),functools.partial(Handler,directory=str(ROOT/'dist')))
threading.Thread(target=srv.serve_forever,daemon=True).start()
checks=[];errors=[];success=False
def check(label,condition):
 assert condition,label
 checks.append(label)
try:
 with sync_playwright() as pw:
  b=pw.chromium.launch(headless=True)
  p=b.new_page(viewport={'width':1440,'height':1000},color_scheme='dark',reduced_motion='reduce')
  p.set_default_timeout(12000);p.on('pageerror',lambda e:errors.append(str(e)))
  p.add_init_script('let daSeed=82321;Math.random=()=>{daSeed=(Math.imul(daSeed,1664525)+1013904223)>>>0;return daSeed/4294967296}')
  p.goto('http://127.0.0.1:%s/'%srv.server_address[1])
  p.locator('.cd3-nav').get_by_role('button',name='Nouvelle carrière').click();p.get_by_role('button',name='Univers fictif').click();p.locator('.clubchoice').first.click()
  original=p.evaluate('JSON.stringify(S)');disk=p.evaluate('localStorage.getItem("bdt-v1")')
  for theme in ('analyste','tribune'):
   p.locator('#ui01-theme').select_option(theme)
   for width in (1920,1440,1024,768,390,320):
    p.set_viewport_size({'width':width,'height':1000 if width>=1024 else 900})
    for route in ('dashboard','team','finance','recruitment','formation','league','tactics'):
     p.evaluate('(r)=>nav(r)',route)
     check('composed view '+route+theme+str(width),p.locator('.da4-workspace').count()==1)
     check('no overflow '+route+theme+str(width),p.evaluate('document.documentElement.scrollWidth<=innerWidth+1'))
     check('SVG graph finite '+route+theme+str(width),p.locator('.da4-chart,.da4-bars').count()>0 and p.locator('.da4-chart').evaluate_all("els=>els.every(e=>!e.outerHTML.includes('NaN')&&!e.outerHTML.includes('Infinity'))"))
     check('read only '+route+theme+str(width),p.evaluate('JSON.stringify(S)')==original and p.evaluate('localStorage.getItem("bdt-v1")')==disk)
     if width in (1440,390):
      p.locator('#toast').evaluate("e=>e.style.display='none'");p.mouse.move(0,0)
      p.screenshot(path=str(OUT/(route+'-'+theme+'-'+str(width)+'.png')),full_page=True)
  p.set_viewport_size({'width':1440,'height':1000});p.locator('#ui01-theme').select_option('analyste')
  p.evaluate("nav('finance')")
  expected=p.evaluate('CDArtDirection.snapshot().finance.series.length')
  check('one real point per forecast week',p.locator('.da4-finance-chart circle.da4-dot').count()==expected)
  p.locator('.da4-finance-chart summary').click()
  check('chart has a readable values table',p.locator('.da4-finance-chart tbody tr').count()==expected)
  check('forecast matches native engine',p.evaluate('CDArtDirection.snapshot().finance.finalBalance===CDFinancePlanning.forecast(careerBudgetModel()).finalBalance'))
  p.evaluate("nav('recruitment')")
  point=p.locator('.da4-scatter-figure .da4-player-point').first
  point.focus();check('scatter focus shows visible profile',p.locator('.da4-point-readout').inner_text()==point.get_attribute('aria-label'))
  check('all fifteen actual positions',p.locator('.da4-position').count()==15)
  check('scores equal native diagnostics',p.evaluate("(()=>{const needs=new Map(CDArtDirection.snapshot().needs.map(n=>[n.slot,n.score]));return [...document.querySelectorAll('.da4-position')].every((e,i)=>Number(e.querySelector('strong').textContent)===needs.get(i))})()"))
  p.locator('.da4-position').first.focus();check('keyboard reads diagnostic',p.locator('.da4-position-tooltip').first.is_visible())
  p.set_viewport_size({'width':320,'height':900})
  for i in range(15):
   p.locator('.da4-position').nth(i).focus();check('tooltip stays within mobile page '+str(i),p.evaluate('document.documentElement.scrollWidth<=innerWidth+1'))
  p.set_viewport_size({'width':1440,'height':1000})
  p.locator('.da4-recruit-stage button[data-ui03-tab="candidates"]').click();check('graph action opens native candidates',p.locator('.cd03-candidates').is_visible())
  p.evaluate("nav('formation')")
  check('each espoir has a potential interval',p.locator('.da4-potential-line').count()==p.evaluate('S.development.academy.length'))
  p.locator('.da4-academy-stage button[data-ui04-tab="academy"]').click();check('academy action opens native table',p.locator('.cd04-player-link').count()>0)
  p.evaluate("nav('team')")
  check('one dot per professional',p.locator('.da4-squad-stage circle.da4-player-point').count()==p.evaluate('club().players.length'))
  p.locator('.cd02-player-link').first.click();check('native player sheet still works',p.evaluate("squadTab==='profile'"))
  check('profile shows attribute radar',p.locator('.da4-profile-stage .da4-radar-shape').count()==1)
  p.mouse.move(0,0);p.screenshot(path=str(OUT/'player-analyste-1440.png'),full_page=True)
  p.evaluate("nav('dashboard')")
  check('no fictional form series',p.locator('.da4-form .da4-result').count()==0)
  p.locator('.da4-fixture .da4-cta').click();check('fixture goes to native match center',p.evaluate("view==='match'"))
  # A real native match advances the same isolated career; never insert fake chart data.
  p.evaluate('beginMatch();pauseMatch();render()')
  check('live not replaced by graphics',p.locator('.v40-cockpit').is_visible())
  check('native export compatible',p.evaluate('!!parseSaveDocument(JSON.stringify(createSaveDocument()))'))
  completed=p.evaluate('''()=>{
   let done=0;for(let i=0;i<5;i++){
    if(!S.live){repairSheet();beginMatch();}if(!S.live)break;
    clearInterval(timer);let guard=0;
    while(!S.live.finished&&guard++<300){if(S.live.paused)continueMatch();advanceRugby(S.live);}
    clearInterval(timer);if(!S.live.finished)throw Error('Match natif non terminé');
    finishRound();done++;
   }return done;
  }''')
  check('real native results created',completed>=1)
  p.evaluate("nav('dashboard')")
  check('results match actual career history',p.locator('.da4-result').count()==p.evaluate('Math.min(5,S.history.filter(h=>h.pair.includes(S.club)).length)'))
  p.mouse.move(0,0);p.screenshot(path=str(OUT/'dashboard-played-1440.png'),full_page=True)
  p.evaluate("nav('league')");p.mouse.move(0,0);p.screenshot(path=str(OUT/'league-played-1440.png'),full_page=True)
  check('nonzero standings after real matches',p.evaluate('CDArtDirection.snapshot().standings.some(t=>t.points>0)'))
  check('no JS error',not errors)
  success=True;b.close()
finally:
 srv.shutdown();(OUT/'report.json').write_text(json.dumps({'passed':success,'checks':checks,'errors':errors,'limits':['Chromium Linux uniquement. Aucun historique de test inventé.']},ensure_ascii=False,indent=2))
print(json.dumps({'passed':success,'checks':len(checks),'errors':errors}))
