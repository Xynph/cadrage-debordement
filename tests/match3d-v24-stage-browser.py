"""30 rigs anatomiques offline ; benchmark 30 objets rendu logiciel, PAS une mesure de match réel."""
import json,os,threading,http.server,functools
from pathlib import Path
from playwright.sync_api import sync_playwright
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'match3d-v24-stage-report';OUT.mkdir(exist_ok=True)
class Handler(http.server.SimpleHTTPRequestHandler):
 def log_message(self,*args):pass
server=http.server.ThreadingHTTPServer(('127.0.0.1',0),functools.partial(Handler,directory=str(ROOT/'dist')))
threading.Thread(target=server.serve_forever,daemon=True).start()
errors=[];external=[]
try:
 with sync_playwright() as p:
  browser=p.chromium.launch(executable_path=os.environ.get('CD_CHROMIUM_PATH'),headless=True,args=['--no-sandbox','--disable-gpu-sandbox','--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader'])
  page=browser.new_page(viewport={'width':960,'height':540});page.set_default_timeout(180000)
  page.on('pageerror',lambda e:errors.append(str(e)))
  def intercept(r):
   if r.request.url.startswith('http://127.0.0.1:'):r.continue_()
   else:external.append(r.request.url);r.abort()
  page.route('**/*',intercept)
  page.goto(f'http://127.0.0.1:{server.server_port}/match3d/assets/rugby-v24/stage30.html',wait_until='domcontentloaded')
  page.wait_for_function('window.ready || window.failures.length',timeout=180000)
  assert page.evaluate('window.ready'),page.evaluate('window.failures')
  diag=page.evaluate('window.diagnostics')
  assert diag['players']==30 and diag['independentRoots']==30 and diag['independentMixers']==30,diag
  assert len(diag['lodCounts'])==3 and all(n>0 for n in diag['lodCounts']),diag
  assert diag['clips']==[16,16,16],diag
  metrics={}
  for view in ['tv','zoom']:
   page.evaluate('(v)=>window.setView(v)',view)
   page.screenshot(path=str(OUT/f'{view}.jpg'),type='jpeg',quality=87,timeout=50000)
   metrics[view]=page.evaluate('window.benchmark(18)')
   assert 0<metrics[view]['fps']<10000,metrics
  assert not errors,errors
  assert not external,external
  report={'status':'STAGING_ONLY_NOT_RUNTIME_APPROVED','environment':'Chromium SwiftShader software / synchronous gl.finish','diagnostics':diag,'metrics':metrics,'jsErrors':errors,'externalRequests':external,'limits':['No comparison to v23 within this run','No WebGL GPU VRAM accounting','Not integrated into the game','30 objects only; no crowds/match logic','Visual validation pending']}
  (OUT/'report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
  print(json.dumps(report,ensure_ascii=False))
  browser.close()
finally:server.shutdown()
