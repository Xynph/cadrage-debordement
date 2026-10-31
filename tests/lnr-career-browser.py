"""Réception Chromium du mode LNR facultatif et des anciennes carrières."""
import functools,http.server,json,threading
from pathlib import Path
from playwright.sync_api import sync_playwright
ROOT=Path(__file__).resolve().parents[1];checks=[];errors=[]
class Handler(http.server.SimpleHTTPRequestHandler):
 def log_message(self,*args):pass
def check(label,condition):
 if not condition:raise AssertionError(label)
 checks.append(label)
server=http.server.ThreadingHTTPServer(('127.0.0.1',0),functools.partial(Handler,directory=str(ROOT/'dist')))
threading.Thread(target=server.serve_forever,daemon=True).start()
out={'passed':False,'checks':checks,'errors':errors,'limitations':['Chromium Linux uniquement','Finances et capacités simulées, snapshot 31/10/2026']}
try:
 with sync_playwright() as pw:
  browser=pw.chromium.launch(headless=True)
  page=browser.new_page(viewport={'width':1280,'height':900})
  page.set_default_timeout(20000)
  page.on('pageerror',lambda e:errors.append(str(e)))
  page.goto('http://127.0.0.1:%d/'%server.server_address[1])
  page.get_by_role('button',name='Nouvelle carrière').click()
  check('univers fictif par défaut',page.evaluate("lnrWelcomeMode==='fiction'"))
  page.get_by_role('button',name='Effectifs LNR · 31/10/2026').click()
  check('14 équipes LNR proposées',page.locator('.clubchoice').count()==14)
  check('avertissement mode simulé',page.locator('.lnr-choice').inner_text().find('SIMULÉS')>=0)
  page.locator('.clubchoice').first.click()
  check('carrière LNR initialisée',page.evaluate('lnrCareerMode(S)'))
  check('14 clubs officiels',page.evaluate('S.clubs.length===14&&S.clubs[0].name===lnrGameClub(0).name'))
  check('XV et banc natifs',page.evaluate('sheetErrors().length===0'))
  check('sauvegarde export valide',page.evaluate('!!parseSaveDocument(JSON.stringify(createSaveDocument()))'))
  page.evaluate("nav('team')")
  catalog=page.locator('[aria-label="Catalogue officiel LNR"]')
  check('catalogue disponible',catalog.is_visible())
  check('30 clubs consultables',catalog.locator('select option').count()==30)
  before=page.evaluate('JSON.stringify(S)')
  stored=page.evaluate("localStorage.getItem('bdt-v1')")
  catalog.locator('select').select_option('16')
  check('navigation sans mutation',page.evaluate('JSON.stringify(S)')==before)
  check('navigation sans sauvegarde',page.evaluate("localStorage.getItem('bdt-v1')")==stored)
  for width in (1280,768,390,320):
   page.set_viewport_size({'width':width,'height':850})
   page.evaluate("nav('team')")
   check('catalogue visible %d'%width,page.locator('.lnr-catalogue').is_visible())
   check('aucun débordement %d'%width,page.evaluate('document.documentElement.scrollWidth<=innerWidth+2'))
  page.reload()
  check('reprise de carrière LNR',page.evaluate('lnrCareerMode(S)'))
  check('reprise et export cohérents',page.evaluate('!!parseSaveDocument(JSON.stringify(createSaveDocument()))'))
  old=browser.new_page(viewport={'width':1280,'height':900})
  old.goto('http://127.0.0.1:%d/'%server.server_address[1])
  old.get_by_role('button',name='Nouvelle carrière').click()
  old.locator('.clubchoice').first.click()
  check('carrière fictive historique préservée',old.evaluate("S.lnrMode===undefined"))
  check('sauvegarde fictive valide',old.evaluate('!!parseSaveDocument(JSON.stringify(createSaveDocument()))'))
  check('aucune erreur navigateur',not errors)
  browser.close()
 out['passed']=True
finally:
 server.shutdown()
 print(json.dumps(out,ensure_ascii=False))
