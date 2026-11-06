from pathlib import Path
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
from threading import Thread
from functools import partial
from playwright.sync_api import sync_playwright
import json

root = Path(__file__).resolve().parents[1] / "dist"
server = ThreadingHTTPServer(("127.0.0.1", 0), partial(SimpleHTTPRequestHandler, directory=str(root)))
Thread(target=server.serve_forever, daemon=True).start()
url = f"http://127.0.0.1:{server.server_port}/index.html"
with sync_playwright() as pw:
    browser = pw.chromium.launch(headless=True)
    page = browser.new_page(viewport={"width": 1440, "height": 900})
    errors = []
    page.on("pageerror", lambda e: errors.append(str(e)))
    page.goto(url, wait_until="domcontentloaded", timeout=60000)
    result = page.evaluate("""() => {
      const names=['CDEspoirsCareerV82V85','CDEspoirsFollowupV86V89','CDEspoirsDynamicsV90V94','CDEspoirsStrategyV95V100'];
      const player=(id,pos,age,rating)=>({id,name:id,pos,age,rating,condition:90,injury:0,dev:{potential:rating+15,xp:0,seasonStart:rating}});
      const s={season:1,club:0,round:4,phase:'league',live:false,news:[],ledger:[],
        clubs:[{name:'Maison',cash:300000,players:[player('pro','10',27,77)]},{name:'Rival',cash:100000,players:[]}],
        development:{academy:[player('jeune','10',18,63),player('jeune2','9',19,64)]},
        v73Espoirs:{results:[],minutes:{jeune:400,jeune2:350}},v77Promotions:{promotions:[],history:[]},
        v78to81:{version:1,season:1,loans:[],history:[]}};
      const root=document.createElement('main');root.id='v82-v100-reception';root.style.cssText='display:grid;grid-template-columns:1fr 1fr;gap:12px;padding:16px;background:#f1f5f9;color:#15231f';document.body.replaceChildren(root);
      const reports=[];
      for(const name of names){
        const api=window[name];
        if(!api) throw Error('Module absent: '+name);
        const state=api.ensure(s);
        if(!state) throw Error('Etat invalide: '+name);
        const el=document.createElement('section');el.style.cssText='padding:14px;border:1px solid #aaa;background:white;overflow:auto';
        el.innerHTML=api.panel(s);root.appendChild(el);
        if(!el.querySelector('h2'))throw Error('Titre panneau absent: '+name);
        reports.push({name,buttons:el.querySelectorAll('button').length,text:el.innerText.slice(0,80)});
      }
      const imported=JSON.parse(JSON.stringify(s));
      for(const key of ['v82to85','v86to89','v90to94','v95to100'])if(!imported[key])throw Error('JSON absent '+key);
      return reports;
    }""")
    page.screenshot(path="/tmp/v82-v100-chromium.png", full_page=True)
    assert len(result) == 4, result
    assert all(x["buttons"] > 0 for x in result), result
    print("V82-V100 CHROMIUM PASS", json.dumps(result, ensure_ascii=False))
    browser.close()
server.shutdown()
