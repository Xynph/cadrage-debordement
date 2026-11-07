"""Parcours Chromium natif des décisions de rotation sans changement de sélection."""
import functools,http.server,json,threading
from pathlib import Path
from playwright.sync_api import sync_playwright
ROOT=Path(__file__).resolve().parents[1]
checks=[];errors=[]
class Handler(http.server.SimpleHTTPRequestHandler):
    def log_message(self,*args):pass
def check(name,condition):
    if not condition:raise AssertionError(name)
    checks.append(name)
server=http.server.ThreadingHTTPServer(('127.0.0.1',0),functools.partial(Handler,directory=str(ROOT/'dist')))
threading.Thread(target=server.serve_forever,daemon=True).start()
try:
    with sync_playwright() as pw:
        browser=pw.chromium.launch(headless=True)
        page=browser.new_page(viewport={'width':1440,'height':900})
        page.on('pageerror',lambda e:errors.append(str(e)))
        page.goto('http://127.0.0.1:%s/'%server.server_address[1])
        page.get_by_role('button',name='Nouvelle carrière').click()
        page.get_by_role('button',name='Univers fictif').click()
        page.locator('.clubchoice').first.click()
        page.evaluate("squadTab='depth';nav('team')")
        panel=page.locator('.depth-grid')
        check('quinze postes visibles',panel.locator('[data-rotation-slot]').count()==15)
        before=page.evaluate('JSON.stringify(S)')
        page.evaluate('render()')
        check('rendu non mutateur',page.evaluate('JSON.stringify(S)')==before)
        check('alternative cohérente',page.evaluate("""() => squadDepthSnapshot().cards.every(c=>c.alternatives.every(p=>!S.lineup.includes(p.id)&&!S.reserves.includes(p.id)&&squadDepthReadiness(p).ready))"""))
        check('sauvegarde native parseable',page.evaluate('!!parseSaveDocument(JSON.stringify(createSaveDocument()))'))
        for width in (1440,900,390):
            page.set_viewport_size({'width':width,'height':900})
            check('panneau visible '+str(width),page.locator('.depth-grid').is_visible())
        page.get_by_role('button',name='Voir uniquement les postes à risque').click()
        check('filtre risques actif',page.evaluate('squadDepthAlertsOnly===true'))
        page.get_by_role('button',name='Afficher tous les postes').click()
        check('filtre réversible',panel.locator('[data-rotation-slot]').count()==15)
        page.locator('[data-rotation-slot="0"]').get_by_role('button',name='Modifier les 23').click()
        check('feuille native accessible',page.evaluate("view==='team' && squadTab==='sheet'"))
        check('aucune erreur Javascript',not errors)
        browser.close()
    print(json.dumps({'passed':True,'checks':checks,'errors':errors},ensure_ascii=False))
finally:server.shutdown()
