"""Paired render-only benchmark, same 30 positions/camera/lights/resolution/software renderer."""
import json,os,threading,http.server,functools,statistics
from pathlib import Path
from playwright.sync_api import sync_playwright
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'match3d-v24-paired-report';OUT.mkdir(exist_ok=True)
class Handler(http.server.SimpleHTTPRequestHandler):
 def log_message(self,*args):pass
s=http.server.ThreadingHTTPServer(('127.0.0.1',0),functools.partial(Handler,directory=str(ROOT/'dist')));threading.Thread(target=s.serve_forever,daemon=True).start()
errors=[];external=[];runs=[]
try:
 with sync_playwright() as p:
  b=p.chromium.launch(executable_path=os.environ.get('CD_CHROMIUM_PATH'),args=['--no-sandbox','--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader'])
  for pair in range(3):
   for view in ['tv','zoom']:
    for version in (['v23','v24'] if pair%2==0 else ['v24','v23']):
     page=b.new_page(viewport={'width':960,'height':540});page.set_default_timeout(180000)
     page.on('pageerror',lambda e:errors.append(str(e)))
     def route(r):
      if r.request.url.startswith('http://127.0.0.1:'):r.continue_()
      else:external.append(r.request.url);r.abort()
     page.route('**/*',route)
     page.goto(f'http://127.0.0.1:{s.server_port}/match3d/assets/rugby-v24/paired-benchmark.html?version={version}&view={view}',wait_until='domcontentloaded')
     assert not errors,errors
     page.wait_for_function('window.ready || window.failures?.length',timeout=180000);assert page.evaluate('window.ready'),page.evaluate('window.failures')
     page.evaluate('window.sample(12)')
     result=page.evaluate('window.sample(24)');assert result['players']==30 and result['fps']>0,result
     result['pair']=pair;runs.append(result)
     if pair==0:page.screenshot(path=str(OUT/f'{version}-{view}.jpg'),type='jpeg',quality=90)
     print(json.dumps({k:result[k] for k in ['pair','version','view','fps','triangles']}),flush=True);page.close()
  assert not errors and not external,(errors,external)
  summary={}
  for view in ['tv','zoom']:
   v23=[r['fps'] for r in runs if r['view']==view and r['version']=='v23'];v24=[r['fps'] for r in runs if r['view']==view and r['version']=='v24']
   summary[view]={'v23MedianFPS':statistics.median(v23),'v24MedianFPS':statistics.median(v24),'pairedRatios':[b/a for a,b in zip(v23,v24)]}
  report={'status':'MEASURED_STAGING_ONLY_NO_RUNTIME_APPROVAL','protocol':{'pairs':3,'warmupFrames':12,'measuredFrames':24,'viewport':[960,540],'renderer':'Chromium SwiftShader gl.finish','animationStep':1/60,'order':'AB/BA/AB','sameScene':True,'frustumCulling':'disabled on both versions; all 30 rigs submitted'},'summary':summary,'runs':runs,'errors':errors,'externalRequests':external,'limits':['Render-only scene, no match/crowds','Not a runtime integration benchmark','Software rendering only; GPU hardware and VRAM not measured','No performance acceptance claimed']}
  (OUT/'report.json').write_text(json.dumps(report,indent=2)+'\n');b.close()
finally:s.shutdown()
