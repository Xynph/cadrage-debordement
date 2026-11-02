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
 page.screenshot(path=str(out/"tactical-spatial-1440.png"),full_page=True)
 checks.append("Chromium screenshot 1440")
 assert not errors,errors
 browser.close()
(out/"report.json").write_text(json.dumps({"passed":True,"checks":checks,"pageErrors":errors},ensure_ascii=False,indent=2))
print(json.dumps({"passed":True,"checks":checks,"pageErrors":errors},ensure_ascii=False))
