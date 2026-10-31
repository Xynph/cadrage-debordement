"""Réception Chromium de MATCHDAY-02 dans le jeu réel."""
import functools,http.server,json,threading
from pathlib import Path
from playwright.sync_api import sync_playwright
ROOT=Path(__file__).resolve().parents[1]
checks=[];errors=[]
class Handler(http.server.SimpleHTTPRequestHandler):
    def log_message(self,*args):pass
def check(name,passed):
    if not passed:raise AssertionError(name)
    checks.append(name)
server=http.server.ThreadingHTTPServer(('127.0.0.1',0),functools.partial(Handler,directory=str(ROOT/'dist')))
threading.Thread(target=server.serve_forever,daemon=True).start()
result={'passed':False,'checks':checks,'errors':errors,'limitations':['Chromium Linux uniquement']}
try:
    with sync_playwright() as pw:
        browser=pw.chromium.launch(headless=True)
        page=browser.new_page(viewport={'width':1280,'height':900})
        page.set_default_timeout(15000)
        page.on('pageerror',lambda e:errors.append(str(e)))
        page.goto('http://127.0.0.1:%d/'%server.server_address[1])
        page.get_by_role('button',name='Nouvelle carrière').click()
        page.locator('.clubchoice').first.click()
        page.evaluate("nav('tactics')")
        root=page.locator('[aria-label="Assistant de composition"]')
        check('assistant visible dans Préparation',root.is_visible())
        check('23 lignes de composition',root.locator('tbody tr').count()==23)
        prior=page.evaluate('JSON.stringify(S)')
        save=page.evaluate("localStorage.getItem('bdt-v1')")
        root.get_by_role('button',name='Fraîcheur').click()
        check('choix de stratégie sans mutation',page.evaluate('JSON.stringify(S)')==prior)
        check('pas de sauvegarde durant aperçu',page.evaluate("localStorage.getItem('bdt-v1')")==save)
        for width in (1280,768,390,320):
            page.set_viewport_size({'width':width,'height':850})
            page.evaluate("nav('tactics')")
            check('assistant visible %d'%width,page.locator('.cd-lineup').is_visible())
            check('pas de débordement %d'%width,page.evaluate('document.documentElement.scrollWidth<=innerWidth+2'))
        page.set_viewport_size({'width':1280,'height':900})
        page.locator('.cd-lineup-actions button').filter(has_text='Appliquer cette composition').click()
        check('application validée',page.evaluate('sheetErrors().length===0'))
        check('sauvegarde JSON après action',page.evaluate('!!parseSaveDocument(JSON.stringify(createSaveDocument()))'))
        page.evaluate("nav('tactics')")
        page.locator('.cd-lineup-actions button').filter(has_text='Modifier les 23 manuellement').click()
        check('accès à la feuille native',page.evaluate("view==='team'&&squadTab==='sheet'"))
        check('aucune erreur JavaScript',not errors)
        browser.close()
    result['passed']=True
finally:
    server.shutdown()
    print(json.dumps(result,ensure_ascii=False))
