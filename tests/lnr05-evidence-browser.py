"""Test Chromium de l'assistant de preuves et composition (sans connexion externe)."""
import functools,http.server,json,threading
from pathlib import Path
from playwright.sync_api import sync_playwright
ROOT=Path(__file__).resolve().parents[1];checks=[];errors=[]
class Handler(http.server.SimpleHTTPRequestHandler):
 def log_message(self,*args):pass
def check(name,condition):
 if not condition:raise AssertionError(name)
 checks.append(name)
server=http.server.ThreadingHTTPServer(('127.0.0.1',0),functools.partial(Handler,directory=str(ROOT/'dist')))
threading.Thread(target=server.serve_forever,daemon=True).start()
out={'passed':False,'checks':checks,'errors':errors,'limitations':['Chromium Linux uniquement','Aucune valeur sportive officielle calculée']}
try:
 with sync_playwright() as pw:
  browser=pw.chromium.launch(headless=True)
  page=browser.new_page(viewport={'width':1280,'height':900})
  page.set_default_timeout(20000)
  page.on('pageerror',lambda e:errors.append(str(e)))
  page.goto('http://127.0.0.1:%d/'%server.server_address[1])
  page.get_by_role('button',name='Nouvelle carrière').click()
  page.locator('.clubchoice').first.click()
  page.evaluate("nav('team')")
  check('aucune cellule LNR en mode fictif',page.locator('.lnr05-center').count()==0)
  page.evaluate("S=null;gameStorage.removeItem('bdt-v1');entryScreen='clubs';render()")
  page.get_by_role('button',name='Effectifs LNR · 31/10/2026').click()
  page.locator('.clubchoice').first.click()
  page.evaluate("nav('team')")
  box=page.locator('[aria-label="Cellule LNR de preuves et rotation"]')
  check('cellule LNR presente',box.is_visible())
  check('240 fiches disponibles',page.evaluate('LNR05_EVIDENCE.players.length===240'))
  state=page.evaluate('JSON.stringify(S)')
  stored=page.evaluate("localStorage.getItem('bdt-v1')")
  box.get_by_role('button',name='Mesures sourcées').click()
  check('filtres sans mutation',page.evaluate('JSON.stringify(S)')==state)
  check('filtres sans sauvegarde',page.evaluate("localStorage.getItem('bdt-v1')")==stored)
  box.locator('tbody tr').first.locator('button').click()
  check('dossier joueur',page.locator('[aria-label="Décision de composition LNR"]').is_visible())
  check('dossier indique simulations',page.locator('.lnr05-detail').inner_text().find('Simulation de carrière')>=0)
  check('choix sans mutation',page.evaluate('JSON.stringify(S)')==state)
  for width in (1280,768,390,320):
   page.set_viewport_size({'width':width,'height':900})
   page.evaluate("nav('team')")
   check('cellule visible '+str(width),page.locator('.lnr05-center').is_visible())
   check('aucun debordement '+str(width),page.evaluate('document.documentElement.scrollWidth<=innerWidth+2'))
  page.set_viewport_size({'width':1280,'height':900})
  player_id=page.evaluate("club().players.find(p=>lnr05Proof(p.id)&&lnr05Proposal(p.id)?.valid)?.id||null")
  check('composition proposee disponible',player_id is not None)
  page.evaluate("lnr05Pick("+json.dumps(player_id)+")")
  box=page.locator('.lnr05-center')
  box.get_by_role('button',name='Confirmer la composition à 23').click()
  check('joueur inclus dans feuille',page.evaluate("S.lineup.includes("+json.dumps(player_id)+")||S.reserves.includes("+json.dumps(player_id)+")"))
  check('feuille native valide',page.evaluate('sheetErrors().length===0'))
  check('sauvegarde native apres choix',page.evaluate('!!parseSaveDocument(JSON.stringify(createSaveDocument()))'))
  page.reload()
  check('reprise apres choix',page.evaluate('lnrCareerMode(S)&&!!parseSaveDocument(JSON.stringify(createSaveDocument()))'))
  check('aucune erreur JS',not errors)
  browser.close()
 out['passed']=True
finally:
 server.shutdown()
 print(json.dumps(out,ensure_ascii=False))
