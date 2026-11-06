from pathlib import Path
from functools import partial
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
from threading import Thread
from playwright.sync_api import sync_playwright
import json

dist=Path(__file__).resolve().parents[1] / 'dist'
server=ThreadingHTTPServer(('127.0.0.1',0),partial(SimpleHTTPRequestHandler,directory=str(dist)))
Thread(target=server.serve_forever,daemon=True).start()
try:
    with sync_playwright() as pw:
        browser=pw.chromium.launch(headless=True)
        page=browser.new_page(viewport={'width':1440,'height':900})
        errors=[]
        page.on('pageerror',lambda error:errors.append(str(error)))
        page.goto(f'http://127.0.0.1:{server.server_port}/index.html',wait_until='domcontentloaded',timeout=60000)
        result=page.evaluate("""() => {
          start(0);
          if(S.interclubWorld)throw Error('new career must be legacy-compatible and lazily initialized');
          finishRound(); // Native real simulated game round, no mocked score.
          if(!S.interclubWorld||S.interclubWorld.events.length<5)throw Error('Interclub matches not recorded');
          const pair=S.interclubWorld.events[0];
          const original=S.history.find(x=>x.pair[0]===pair.a&&x.pair[1]===pair.b);
          if(!original||original.score[0]!==pair.home||original.score[1]!==pair.away)
            throw Error('Narrative differs from native result');
          const saved=JSON.stringify(createSaveDocument());
          const imported=parseSaveDocument(saved);
          if(imported.state.interclubWorld.events.length!==S.interclubWorld.events.length)
            throw Error('Export/import lost rivals');
          pendingSave=imported;
          if(!confirmSaveImport())throw Error('Native JSON import failed');
          nav('dashboard');
          return {round:S.round,events:S.interclubWorld.events.length,pair:pair.id};
        }""")
        native='section[aria-label="Monde vivant interclubs V124"]'
        dossiers=page.locator('[data-da43-section="dashboard"] [data-da42-subpage="dossiers"]')
        dossiers.click(timeout=15000)
        card=page.locator('[data-da43-section="dashboard"] [data-da42-page="dossiers"] '+native)
        assert card.count()==1,'Native Dossiers world panel missing'
        assert card.is_visible(),'The panel exists but cannot be seen'
        assert 'Échos du championnat' in card.inner_text()
        page.evaluate("nav('league')")
        league=page.locator(native)
        assert league.count()==1 and league.is_visible(),'Native league page world panel missing'
        assert 'Réaction simulée' in league.inner_text()
        legacy=page.evaluate("""() => {
          start(1);
          const old=createSaveDocument();
          if(old.state.interclubWorld)throw Error('Old career mutated on read');
          pendingSave=parseSaveDocument(JSON.stringify(old));
          if(!confirmSaveImport())throw Error('Legacy JSON import failed');
          return {season:S.season,players:club().players.length,
            noForcedField:!Object.hasOwn(S,'interclubWorld')};
        }""")
        assert legacy['noForcedField'] and legacy['players']>=23,legacy
        assert not errors,errors
        page.screenshot(path='/tmp/v124-v130-interclub-chromium.png',full_page=True)
        print('V124-V130 CHROMIUM PASS',json.dumps({'round':result,'legacy':legacy},ensure_ascii=False))
        browser.close()
finally:
    server.shutdown()
