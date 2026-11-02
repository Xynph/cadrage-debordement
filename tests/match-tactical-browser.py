import json
import os
from pathlib import Path
from playwright.sync_api import sync_playwright

out=Path(os.environ.get("TACTICAL_QA_DIR","tactical-browser-report"))
out.mkdir(parents=True,exist_ok=True)
checks=[]
with sync_playwright() as p:
 browser=p.chromium.launch(headless=True)
 page=browser.new_page(viewport={"width":1440,"height":900})
 errors=[]
 page.on("pageerror",lambda error:errors.append(str(error)))
 page.goto("http://127.0.0.1:8765/index.html",wait_until="load")
 page.wait_for_function("typeof tacticalVisualHtml === 'function' && typeof matchCockpitView === 'function'")
 checks.append("real dist/index.html loads native game and tactical module")
 result=page.evaluate("""() => {
 const scene={possession:0,ball:{x:50,y:35},kind:'carry',event:{scene:{kind:'carry'}},
 players:[{id:'one',side:0,x:49,y:35},{id:'two',side:0,x:55,y:36},{id:'three',side:1,x:51,y:34}]};
 const original=JSON.stringify(scene),before=localStorage.length;
 const element=document.createElement('div');element.innerHTML=tacticalVisualHtml(scene);
 document.body.append(element);
 return {unchanged:JSON.stringify(scene)===original,storage:before===localStorage.length,
 rows:element.querySelectorAll('tbody tr').length,heading:element.querySelector('h2')?.textContent,
 pressure:element.textContent.includes('Soutien offensif'),
 integrated:matchCockpitView.toString().includes('tacticalVisualHtml')};
 }""")
 assert result["unchanged"] and result["storage"],result
 checks.append("spatial render never mutates input scene or localStorage")
 assert result["rows"]==3 and result["heading"]=="Espaces et soutiens" and result["integrated"],result
 checks.append("three native pitch lanes render and cockpit integration is wired")
 # Live native match: create an actual playable club and let its real engine create the scene.
 page.evaluate("start(0, 'fiction')")
 page.evaluate("beginMatch()")
 native=page.evaluate("""() => {
   if(!S.live) return {started:false};
   clearInterval(timer);
   if(typeof pauseMatch==='function' && !S.live.paused) pauseMatch();
   const before=JSON.stringify(S),storage=JSON.stringify(Object.fromEntries(Object.keys(localStorage).sort().map(k=>[k,localStorage.getItem(k)])));
   const scene=matchScene(S.live),data=tacticalVisualSummary(scene);
   const html=tacticalVisualHtml(scene);
   const host=document.createElement('div');host.innerHTML=html;document.body.appendChild(host);
   return {started:true,playerCount:scene.players.length,lanes:host.querySelectorAll('tbody tr').length,nonmutation:before===JSON.stringify(S),storage:storage===JSON.stringify(Object.fromEntries(Object.keys(localStorage).sort().map(k=>[k,localStorage.getItem(k)]))),real:!!S.live.sheets,kind:data.eventKind};
 }""")
 assert native["started"] and native["real"] and native["playerCount"]>=20 and native["lanes"]==3 and native["nonmutation"] and native["storage"],native
 checks.append("native live match positions render without career or storage mutation")
 page.screenshot(path=str(out/"native-match-1440.png"),full_page=True)
 checks.append("native live match screenshot")
 # Historical export from the original V16 code (not a handcrafted fixture).
 import subprocess,tempfile,tarfile,io,functools,http.server,threading,hashlib
 class Quiet(http.server.SimpleHTTPRequestHandler):
  def log_message(self,*args): pass
 with tempfile.TemporaryDirectory(prefix='tactical-v16-') as tmp:
  archive=subprocess.check_output(['git','archive','dbcb0f3','dist'])
  with tarfile.open(fileobj=io.BytesIO(archive)) as tar:tar.extractall(tmp,filter='data')
  server=http.server.ThreadingHTTPServer(('127.0.0.1',0),functools.partial(Quiet,directory=str(Path(tmp)/'dist')))
  thread=threading.Thread(target=server.serve_forever,daemon=True);thread.start()
  historic=browser.new_context().new_page()
  try:
   historic.goto('http://127.0.0.1:%s/'%server.server_port)
   historic.locator('.clubchoice').first.click()
   historic.evaluate('finishRound()')
   legacy=historic.evaluate('JSON.stringify(createSaveDocument())')
   historical=historic.evaluate('({round:S.round,season:S.season,club:S.club,cash:S.clubs[S.club].cash})')
   assert historical["round"]==1
  finally:
   historic.context.close();server.shutdown()
  export=out/'historical-v16-export.json';export.write_text(legacy)
  saved_state=page.evaluate('JSON.stringify(S)')
  saved_storage=page.evaluate('JSON.stringify(Object.fromEntries(Object.keys(localStorage).sort().map(k=>[k,localStorage.getItem(k)])))')
  page.locator('#save-import').set_input_files(str(export))
  page.get_by_role('dialog',name='Vérifier la sauvegarde').wait_for()
  assert page.evaluate('JSON.stringify(S)')==saved_state
  assert page.evaluate('JSON.stringify(Object.fromEntries(Object.keys(localStorage).sort().map(k=>[k,localStorage.getItem(k)])))')==saved_storage
  checks.append("historical V16 preview preserves original career and all localStorage")
  page.get_by_role('button',name='Remplacer et reprendre la carrière').click()
  restored=page.evaluate('({round:S.round,season:S.season,club:S.club,cash:S.clubs[S.club].cash})')
  assert restored==historical,(restored,historical)
  checks.append("authentic V16 export restores sporting and financial values")
  current=page.evaluate('JSON.stringify(S)')
  disk=page.evaluate('JSON.stringify(Object.fromEntries(Object.keys(localStorage).sort().map(k=>[k,localStorage.getItem(k)])))')
  view=page.evaluate("""() => {
    const before=JSON.stringify(S);
    const legacyScene={possession:0,players:[],ball:{},kind:'message'};
    const html=tacticalVisualHtml(legacyScene);
    return {legacy:html.includes('Aucune géométrie historique'),same:JSON.stringify(S)===before};
  }""")
  assert view["legacy"] and view["same"] and page.evaluate('JSON.stringify(S)')==current and page.evaluate('JSON.stringify(Object.fromEntries(Object.keys(localStorage).sort().map(k=>[k,localStorage.getItem(k)])))')==disk
  checks.append("legacy tactical reading is read-only after authentic import")
  page.reload()
  assert page.evaluate('S.round')==historical["round"]
  checks.append("historical career survives browser reload")

 page.screenshot(path=str(out/"tactical-spatial-1440.png"),full_page=True)
 checks.append("Chromium screenshot 1440")
 assert not errors,errors
 browser.close()
(out/"report.json").write_text(json.dumps({"passed":True,"checks":checks,"pageErrors":errors},ensure_ascii=False,indent=2))
print(json.dumps({"passed":True,"checks":checks,"pageErrors":errors},ensure_ascii=False))
