from pathlib import Path
from functools import partial
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
from threading import Thread
from playwright.sync_api import sync_playwright
import json

dist=Path(__file__).resolve().parents[1] / "dist"
server=ThreadingHTTPServer(("127.0.0.1",0),partial(SimpleHTTPRequestHandler,directory=str(dist)))
Thread(target=server.serve_forever,daemon=True).start()
try:
    with sync_playwright() as pw:
        browser=pw.chromium.launch(headless=True)
        page=browser.new_page(viewport={"width":1440,"height":900})
        errors=[]
        page.on("pageerror",lambda exc:errors.append(str(exc)))
        page.goto(f"http://127.0.0.1:{server.server_port}/index.html",wait_until="domcontentloaded",timeout=60000)
        info=page.evaluate("""() => {
          const needed=['CDEspoirsCoachingV101V104','CDSportingDirectorV105V110',
            'CDFanExperienceV111V116','v102Path','v105Priority','v106Delegate',
            'v107Invest','v108Mitigate','v111Record','v112Price','v113Campaign',
            'v114Community','v115Service'];
          for(const key of needed)if(!window[key])throw Error('Missing script/global '+key);
          const player=(id,pos,age,rating)=>({id,name:id,pos,age,rating,
            condition:90,injury:0,dev:{potential:rating+20,xp:0,seasonStart:rating}});
          S={season:1,round:1,club:0,phase:'league',live:false,news:[],ledger:[],
            clubs:[{name:'Maison',cash:300000,stadiumCapacity:11000,
              players:[player('pro','10',27,77),player('pro2','9',25,68)]},
              {name:'Rival',cash:100000,players:[]}],
            development:{academy:[player('espoir','10',18,63),player('espoir2','9',19,64)]},
            v73Espoirs:{minutes:{espoir:420,espoir2:200},results:[]},
            v77Promotions:{promotions:[],history:[]},
            v82to85:{version:1,season:1,focus:'progression',goal:'formation',
              plans:[],mentors:[],reports:[],history:[]},
            v95to100:{version:1,season:1,region:'Atlantique',identity:'polyvalence',
              cohesion:55,reputation:45,scouts:0,meetings:0,candidates:[],recruits:[],
              loads:[],ambitions:[],history:[]}
          };
          // Real source onclick handlers act on the global game's S; avoid unrelated game rendering of test fixtures.
          window.render=()=>true;
          window.save=()=>true;
          const root=document.createElement('main');root.id='v101-v116-reception';
          root.style.cssText='padding:16px;display:grid;gap:16px;background:#f6f8fa;color:#182b26';
          for(const [id,api] of [
            ['formation',window.CDEspoirsCoachingV101V104],
            ['direction',window.CDSportingDirectorV105V110],
            ['supporters',window.CDFanExperienceV111V116]]){
            if(!api.ensure(S))throw Error('Init failed '+id);
            const section=document.createElement('section');section.id='reception-'+id;
            section.innerHTML=api.panel(S);
            root.appendChild(section);
          }
          document.body.replaceChildren(root);
          return {loaded:needed.length,panels:root.querySelectorAll('h2').length,
            buttons:root.querySelectorAll('button').length};
        }""")
        assert info["panels"]==3,info
        assert info["buttons"]>=15,info
        actions=[
            ("#reception-formation button[onclick^='v102Path']", "v101to104"),
            ("#reception-direction button[onclick^='v105Priority']", "v105to110"),
            ("#reception-direction button[onclick^='v106Delegate']", "v105to110"),
            ("#reception-direction button[onclick^='v107Invest']", "v105to110"),
            ("#reception-direction button[onclick^='v108Mitigate']", "v105to110"),
            ("#reception-supporters button[onclick^='v112Price']", "v111to116"),
            ("#reception-supporters button[onclick^='v113Campaign']", "v111to116"),
            ("#reception-supporters button[onclick^='v114Community']", "v111to116"),
            ("#reception-supporters button[onclick^='v115Service']", "v111to116"),
            ("#reception-supporters button[onclick^='v111Record']", "v111to116")
        ]
        for selector,_ in actions:
            button=page.locator(selector).first
            assert button.count()==1,selector
            assert button.is_enabled(),selector
            button.click()
        result=page.evaluate("""() => {
          const keys=['v101to104','v105to110','v111to116'];
          const apis=[CDEspoirsCoachingV101V104,CDSportingDirectorV105V110,
            CDFanExperienceV111V116];
          const clone=JSON.parse(JSON.stringify(S));
          for(let i=0;i<keys.length;i++){
            if(!apis[i].valid(clone[keys[i]]))throw Error('JSON export/import invalid '+keys[i]);
          }
          if(!clone.v101to104.paths.length||!clone.v105to110.missions.length||
            !clone.v111to116.ledger.length)throw Error('At least one click did not persist');
          const before=clone.clubs[0].cash;
          if(!Number.isFinite(before))throw Error('Cash invalid after combined decisions');
          return {season:clone.season,cash:before,path:clone.v101to104.paths.length,
            staff:clone.v105to110.missions.length,sales:clone.v111to116.ledger.length,
            sentiment:clone.v111to116.sentiment};
        }""")
        assert not errors,errors
        page.screenshot(path="/tmp/v101-v116-chromium.png",full_page=True)
        print("V101-V116 CHROMIUM PASS",json.dumps({"page":info,"actions":len(actions),"result":result},ensure_ascii=False))
        browser.close()
finally:
    server.shutdown()
