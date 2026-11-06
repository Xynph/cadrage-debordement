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
        page.on("pageerror",lambda error:errors.append(str(error)))
        page.goto(f"http://127.0.0.1:{server.server_port}/index.html",wait_until="domcontentloaded",timeout=60000)
        # Genuine career, genuine dashboard, genuine DOM events (no synthetic panel).
        init=page.evaluate("""() => {
          start(0);
          nav('dashboard');
          if(typeof CDLivingLockerRoom!=='object'||typeof CDVestiaireV64!=='object'||typeof CDRelationsV70!=='object')
            throw Error('V117/V64/V70 not loaded');
          const p=club().players[0];
          if(!p||!p.satisfaction)throw Error('satisfaction V36/V64 absent');
          return {season:S.season,week:S.economy.week,trait:CDLivingLockerRoom.personality(p).trait};
        }""")
        selector='section[aria-label="Monde vivant et vestiaire V117"]'
        panel=page.locator(selector)
        assert panel.count()==1, f"Real dashboard panel must appear once, got {panel.count()}"
        panel.locator('button[onclick="livingLockerDecision(\'responsabiliser\')"]').click(timeout=15000)
        first=page.evaluate("""() => {
          if(!S.livingLockerRoom||S.livingLockerRoom.history.length!==1)
            throw Error('Native click did not create history');
          const history=S.livingLockerRoom.history[0],p=club().players.find(x=>x.id===history.playerId);
          if(!p||!p.satisfaction)throw Error('Player missing after action');
          const json=JSON.stringify(createSaveDocument());
          const parsed=parseSaveDocument(json);
          if(parsed.state.livingLockerRoom.history.length!==1)throw Error('Export lost the choice');
          const prior=JSON.stringify(S.livingLockerRoom);
          pendingSave=parsed;
          if(!confirmSaveImport())throw Error('Native save import failed');
          if(JSON.stringify(S.livingLockerRoom)!==prior)throw Error('Import changed V117 data');
          if(CDVestiaireV64.status(p)==='Non suivi')throw Error('V64 relationship lost');
          const roster=club().players;
          if(!CDRelationsV70.personality&&!CDRelationsV70.relation(S,roster[0].id,roster[1].id))
            throw Error('V70 relationship not available');
          return {history:S.livingLockerRoom.history.length,pending:S.livingLockerRoom.commitments.length,
            season:S.season,week:S.economy.week};
        }""")
        assert first['history']==1 and first['pending']==1,first
        # Reopening dashboard after import must not create another choice.
        assert page.locator(selector).count()==1
        assert page.locator(selector+' button[onclick^="livingLockerDecision"]').count()==0
        # Existing legacy export without V117 is accepted without forced mutation.
        legacy=page.evaluate("""() => {
          start(1);
          const legacy=createSaveDocument();
          if(legacy.state.livingLockerRoom)throw Error('Legacy career unexpectedly migrated');
          pendingSave=parseSaveDocument(JSON.stringify(legacy));
          if(!confirmSaveImport())throw Error('Legacy import failed');
          if(S.livingLockerRoom)throw Error('Read-only view mutated old save');
          return {season:S.season,players:club().players.length};
        }""")
        assert legacy['players']>=23,legacy
        # The other two choices must also be clickable and persisted in a genuine career.
        variants={}
        for choice in ['ecouter','cadrer']:
            page.evaluate("() => {start(0);nav('dashboard');}")
            page.locator(selector+f' button[onclick="livingLockerDecision(\'{choice}\')"]').click(timeout=15000)
            outcome=page.evaluate("""() => ({
              choice:S.livingLockerRoom.history[0].choice,
              morale:S.morale,trust:S.trust,
              inbox:S.manager.inbox.filter(x=>x.title.startsWith('Vestiaire :')).length
            })""")
            assert outcome['choice']==choice and outcome['inbox']==1,outcome
            variants[choice]=outcome
        career=page.evaluate("""() => {
          start(0);
          const checks=[];
          for(let y=0;y<15;y++){
            const before=S.season;
            S.phase='ended';S.round=26;S.live=null;
            advanceSeason();
            if(S.season!==before+1)throw Error('Real rollover failure year '+before);
            const doc=createSaveDocument();
            const restored=parseSaveDocument(JSON.stringify(doc));
            if(restored.state.season!==S.season)throw Error('JSON roundtrip failed year '+before);
            checks.push(S.season);
          }
          return {rollovers:checks.length,season:S.season,history:S.livingLockerRoom?.history?.length??0};
        }""")
        assert career['rollovers']==15 and career['season']==16,career
        assert not errors,errors
        page.screenshot(path="/tmp/v117-v123-chromium.png",full_page=True)
        print("V117-V123 CHROMIUM PASS",json.dumps({"initial":init,"responsabiliser":first,"legacy":legacy,"variants":variants,"career":career},ensure_ascii=False))
        browser.close()
finally:
    server.shutdown()
