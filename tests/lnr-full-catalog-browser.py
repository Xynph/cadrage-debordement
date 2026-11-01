"""Chromium: reception du catalogue LNR complet et reprise de carrieres."""
import functools,http.server,json,threading
from pathlib import Path
from playwright.sync_api import sync_playwright
ROOT=Path(__file__).resolve().parents[1]
checks=[];errors=[]
class Handler(http.server.SimpleHTTPRequestHandler):
 def log_message(self,*args):pass
def check(label,ok):
 if not ok:raise AssertionError(label)
 checks.append(label)
server=http.server.ThreadingHTTPServer(('127.0.0.1',0),functools.partial(Handler,directory=str(ROOT/'dist')))
threading.Thread(target=server.serve_forever,daemon=True).start()
out={'passed':False,'checks':checks,'errors':errors,'limitations':['Chromium Linux','Naissances par année parfois estimées','Snapshot LNR 31/10/2026']}
try:
 with sync_playwright() as pw:
  browser=pw.chromium.launch(headless=True)
  page=browser.new_page(viewport={'width':1280,'height':900})
  page.set_default_timeout(20000)
  page.on('pageerror',lambda e:errors.append(str(e)))
  page.goto('http://127.0.0.1:%d/'%server.server_address[1])
  page.get_by_role('button',name='Nouvelle carrière').click()
  page.get_by_role('button',name='Univers fictif').click()
  page.get_by_role('button',name='Effectifs LNR · 31/10/2026').click()
  page.locator('.clubchoice').first.click()
  check('mode LNR facultatif',page.evaluate('lnrCareerMode(S)'))
  check('14 clubs jouables',page.evaluate('S.clubs.length===14'))
  check('1592 annees chargees',page.evaluate('Object.keys(LNR_BIRTHYEARS_DATA.byId).length===1592'))
  page.evaluate("nav('team')")
  catalog=page.locator('[aria-label="Catalogue officiel LNR"]')
  check('catalogue affiche',catalog.is_visible())
  check('30 clubs disponibles',catalog.locator('option').count()==30)
  total=0
  before=page.evaluate('JSON.stringify(S)')
  saved=page.evaluate("localStorage.getItem('bdt-v1')")
  for i in range(30):
   catalog.locator('select').select_option(str(i))
   rows=catalog.locator('tbody tr')
   count=rows.count()
   check('club %d lignes'%i,count>0)
   total+=count
   check('club %d age rempli'%i,rows.locator('td:last-child').count()==count and
      page.evaluate("""i=>LNR_CATALOGUE.clubs[i][3].every(p=>Boolean(LNR_BIRTHYEARS_DATA.byId[p[0]]))""",i))
  check('1592 joueurs affiches',total==1592)
  check('trois dates exactes',page.evaluate("""['lnr:13725','lnr:13497','lnr:11779'].every(id=>typeof LNR_BIRTHYEARS_DATA.byId[id]==='string'&&!lnrBirthAge(id).ageEstimated)"""))
  check('recherche sans mutation',page.evaluate('JSON.stringify(S)')==before)
  check('recherche sans sauvegarde',page.evaluate("localStorage.getItem('bdt-v1')")==saved)
  check('export LNR valide',page.evaluate('!!parseSaveDocument(JSON.stringify(createSaveDocument()))'))
  page.reload()
  check('reprise carriere LNR',page.evaluate('lnrCareerMode(S)'))
  check('reprise export valide',page.evaluate('!!parseSaveDocument(JSON.stringify(createSaveDocument()))'))
  fiction=browser.new_context()
  old=fiction.new_page()
  old.on('pageerror',lambda e:errors.append(str(e)))
  old.goto('http://127.0.0.1:%d/'%server.server_address[1])
  old.get_by_role('button',name='Nouvelle carrière').click()
  old.get_by_role('button',name='Univers fictif').click()
  old.locator('.clubchoice').first.click()
  check('fiction par defaut intacte',old.evaluate('S.lnrMode===undefined'))
  check('fiction export valide',old.evaluate('!!parseSaveDocument(JSON.stringify(createSaveDocument()))'))
  old.reload()
  check('fiction reprise intacte',old.evaluate('S.lnrMode===undefined&&!!parseSaveDocument(JSON.stringify(createSaveDocument()))'))
  check('zero erreur JavaScript',not errors)
  fiction.close();browser.close()
 out['passed']=True
finally:
 server.shutdown()
 print(json.dumps(out,ensure_ascii=False))
