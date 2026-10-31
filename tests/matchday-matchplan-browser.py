"""Réception Chromium du poste de décision rugby MATCHDAY-03."""
import functools,http.server,json,threading
from pathlib import Path
from playwright.sync_api import sync_playwright
ROOT=Path(__file__).resolve().parents[1];checks=[];errors=[]
class Handler(http.server.SimpleHTTPRequestHandler):
    def log_message(self,*args):pass
def check(name,ok):
    if not ok:raise AssertionError(name)
    checks.append(name)
server=http.server.ThreadingHTTPServer(('127.0.0.1',0),functools.partial(Handler,directory=str(ROOT/'dist')))
threading.Thread(target=server.serve_forever,daemon=True).start()
out={'passed':False,'checks':checks,'errors':errors,'limitations':['Chromium Linux uniquement']}
try:
 with sync_playwright() as pw:
  browser=pw.chromium.launch(headless=True)
  page=browser.new_page(viewport={'width':1280,'height':900})
  page.set_default_timeout(15000)
  page.on('pageerror',lambda e:errors.append(str(e)))
  page.goto('http://127.0.0.1:%d/'%server.server_address[1])
  page.locator('.clubchoice').first.click()
  page.evaluate("nav('tactics')")
  root=page.locator('[aria-label="Poste de décision avant-match"]')
  check('poste de décision visible',root.is_visible())
  check('cinq comparaisons sectorielles',root.locator('tbody tr').count()==5)
  old=page.evaluate('JSON.stringify(S)')
  stored=page.evaluate("localStorage.getItem('bdt-v1')")
  root.get_by_role('button',name='Rotation protégée').click()
  check('sélection scénario sans mutation',page.evaluate('JSON.stringify(S)')==old)
  check('aucune sauvegarde sur aperçu',page.evaluate("localStorage.getItem('bdt-v1')")==stored)
  for width in (1280,768,390,320):
   page.set_viewport_size({'width':width,'height':850})
   page.evaluate("nav('tactics')")
   check('scénarios accessibles %d'%width,page.locator('.cd-cmd').is_visible())
   check('aucun débordement %d'%width,page.evaluate('document.documentElement.scrollWidth<=innerWidth+2'))
  page.set_viewport_size({'width':1280,'height':900})
  page.locator('.cd-cmd-actions button').filter(has_text='Appliquer XV, banc et tactique').click()
  check('défense protégée adoptée',page.evaluate("S.defence==='prudente'"))
  check('feuille valide',page.evaluate('sheetErrors().length===0'))
  check('sauvegarde compatible',page.evaluate('!!parseSaveDocument(JSON.stringify(createSaveDocument()))'))
  check('zéro erreur JavaScript',not errors)
  browser.close()
 out['passed']=True
finally:
 server.shutdown()
 print(json.dumps(out,ensure_ascii=False))
