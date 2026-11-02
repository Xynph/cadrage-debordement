import json
import os
from pathlib import Path
from playwright.sync_api import sync_playwright

out=Path("opponent-native-audit")
out.mkdir(exist_ok=True)
with sync_playwright() as p:
 browser=p.chromium.launch(headless=True)
 page=browser.new_page()
 page.goto('http://127.0.0.1:8765/index.html')
 results=[]
 for seed in range(24):
  for enabled in (False,True):
   result=page.evaluate("""({seed,enabled})=>{
     let state=(seed+1)*2654435761>>>0;
     const original=Math.random,oldAdapt=adaptOpponentAttack;
    if(!enabled)adaptOpponentAttack=()=>false;
     Math.random=()=>{state=(1664525*state+1013904223)>>>0;return state/4294967296};
     try{
       if(typeof start!=='function'||typeof beginMatch!=='function')throw Error('native game missing');
       start(0,'fiction');
       beginMatch();
       clearInterval(timer);
       if(!S.live)throw Error('native match did not start');
       const l=S.live, initial=JSON.stringify({season:S.season,round:S.round,club:S.club}),score0=[...l.score],counts={};
       let iterations=0;
       while(!l.finished&&iterations++<250){
         if(l.paused){l.paused=false;if(l.flow?.atBreak&&typeof resumeFlowHalf==='function')resumeFlowHalf(l);}
         advanceRugby(l);
         if(l.minute>=80&&!l.finished&&iterations>160)break;
       }
       const events=l.events.filter(e=>e.type==='tactic'),labels=events.map(e=>e.text||'');
       const changed=events.filter(e=>/ajuste son attaque/.test(e.text||''));
       for(const v of changed){const key=Object.keys(TACTICS).find(k=>(v.text||'').toLowerCase().includes(TACTICS[k][0].toLowerCase()));counts[key||'other']=(counts[key||'other']||0)+1}
       const disciplinary=(l.stats||[]).map(s=>({penalties:s.penalties,yellows:s.yellows}));
       const condition=(l.sheets||[]).map((sh,side)=>activePlayers(l,side).reduce((sum,p)=>sum+p.condition,0)/(activePlayers(l,side).length||1));
       if(JSON.stringify({season:S.season,round:S.round,club:S.club})!==initial)throw Error('career metadata mutated');
       return {seed,enabled,minute:l.minute,finished:l.finished,score:l.score,changes:changed.length,plans:counts,disciplinary,condition,events:events.length};
     }finally{clearInterval(timer);Math.random=original;adaptOpponentAttack=oldAdapt;}
   }""",{'seed':seed,'enabled':enabled})
   results.append(result)
 # Import an actual export produced by the historical V16 native game.
 import subprocess,tempfile,tarfile,io,functools,http.server,threading,hashlib
 class Quiet(http.server.SimpleHTTPRequestHandler):
  def log_message(self,*args): pass
 with tempfile.TemporaryDirectory(prefix='opponent-v16-') as tmp:
  archive=subprocess.check_output(['git','archive','dbcb0f3','dist'])
  with tarfile.open(fileobj=io.BytesIO(archive)) as tar:tar.extractall(tmp,filter='data')
  srv=http.server.ThreadingHTTPServer(('127.0.0.1',0),functools.partial(Quiet,directory=str(Path(tmp)/'dist')))
  threading.Thread(target=srv.serve_forever,daemon=True).start()
  old=browser.new_context().new_page()
  try:
   old.goto('http://127.0.0.1:%d/'%srv.server_port)
   old.locator('.clubchoice').first.click()
   old.evaluate('finishRound()')
   old_core=old.evaluate('({round:S.round,season:S.season,club:S.club,cash:S.clubs[S.club].cash})')
   assert old_core['round']==1
   legacy=old.evaluate('JSON.stringify(createSaveDocument())')
  finally:
   old.context.close();srv.shutdown()
  export=out/'historical-v16-export.json';export.write_text(legacy)
  page.reload()
  page.evaluate("start(0,'fiction')")
  before=page.evaluate('JSON.stringify(S)')
  store=page.evaluate('JSON.stringify(Object.fromEntries(Object.keys(localStorage).sort().map(k=>[k,localStorage.getItem(k)])))')
  page.locator('#save-import').set_input_files(str(export))
  page.get_by_role('dialog',name='Vérifier la sauvegarde').wait_for()
  assert page.evaluate('JSON.stringify(S)')==before
  assert page.evaluate('JSON.stringify(Object.fromEntries(Object.keys(localStorage).sort().map(k=>[k,localStorage.getItem(k)])))')==store
  page.get_by_role('button',name='Remplacer et reprendre la carrière').click()
  restored=page.evaluate('({round:S.round,season:S.season,club:S.club,cash:S.clubs[S.club].cash})')
  assert restored==old_core,(restored,old_core)
  state=page.evaluate('JSON.stringify(S)')
  page.evaluate("opponentAttackDecision({tacticalVersion:0},1)")
  assert page.evaluate('JSON.stringify(S)')==state
  page.reload()
  assert page.evaluate('S.round')==old_core['round']
  historical={"passed":True,"round":old_core['round'],"sha256":hashlib.sha256(legacy.encode()).hexdigest()}
 browser.close()
summary={"historicalV16":historical,"runs":len(results),"completed":sum(bool(x["finished"]) for x in results),
 "changes":sum(x["changes"] for x in results),"results":results,
 "paired": [{"seed":i,"control":results[2*i],"adapted":results[2*i+1]} for i in range(24)],
 "limits":["24 paired seeds, 48 genuine engine matches; seed reinitializes Math.random in browser scope","Adaptation disabled only in control; other engine AI remains active","Descriptive pairing, not proof of statistical balance"]}
(out/"report.json").write_text(json.dumps(summary,ensure_ascii=False,indent=2))
print(json.dumps({k:v for k,v in summary.items() if k!="results"},ensure_ascii=False))
assert summary["runs"]==48 and summary["completed"]==48
