"""Réception Chromium du briefing avant-match dans le vrai jeu."""
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
srv=http.server.ThreadingHTTPServer(('127.0.0.1',0),functools.partial(Handler,directory=str(ROOT/'dist')))
threading.Thread(target=srv.serve_forever,daemon=True).start()
out={'passed':False,'checks':checks,'errors':errors,'limitations':['Chromium Linux uniquement']}
try:
    with sync_playwright() as pw:
        browser=pw.chromium.launch(headless=True)
        p=browser.new_page(viewport={'width':1280,'height':900},color_scheme='dark')
        p.set_default_timeout(15000)
        p.on('pageerror',lambda e:errors.append(str(e)))
        p.goto('http://127.0.0.1:%d/'%srv.server_address[1])
        p.get_by_role('button',name='Nouvelle carrière').click()
        p.locator('.clubchoice').first.click()
        p.evaluate("nav('tactics')")
        panel=p.locator('[aria-label="Préparation du prochain match"]')
        check('briefing dans Préparation',panel.is_visible())
        check('quatre KPI',panel.locator('.cd-matchday-kpi').count()==4)
        prior=p.evaluate('JSON.stringify(S)')
        local=p.evaluate("localStorage.getItem('bdt-v1')")
        p.evaluate('render()')
        check('aucune mutation par consultation',p.evaluate('JSON.stringify(S)')==prior)
        check('aucune sauvegarde réécrite par consultation',p.evaluate("localStorage.getItem('bdt-v1')")==local)
        for width in (1280,768,390,320):
            p.set_viewport_size({'width':width,'height':850})
            p.evaluate("nav('tactics')")
            check('panneau visible %d'%width,p.locator('[aria-label="Préparation du prochain match"]').is_visible())
            check('pas de débordement %d'%width,p.evaluate('document.documentElement.scrollWidth<=innerWidth+2'))
        p.set_viewport_size({'width':1280,'height':900})
        p.locator('.cd-matchday button').filter(has_text='Disponibilité & rotation').click()
        check('navigation rotation',p.evaluate("view==='team'&&squadTab==='health'"))
        p.evaluate("nav('tactics')")
        p.locator('.cd-matchday button').filter(has_text='Couverture des postes').click()
        check('navigation profondeur',p.evaluate("view==='team'&&squadTab==='depth'"))
        p.evaluate("nav('tactics')")
        p.locator('.cd-matchday button').filter(has_text='Vérifier les 23').click()
        check('navigation feuille à 23',p.evaluate("view==='team'&&squadTab==='sheet'"))
        p.evaluate("nav('tactics')")
        check('dossier adversaire connu',p.evaluate('!!matchdayReadiness().opponent'))
        p.evaluate("S.tactic='equilibre';S.defence='equilibre';render()")
        button=p.locator('.cd-matchday button').filter(has_text='Appliquer la recommandation du staff')
        if button.count():
            button.click()
            check('recommandation appliquée par moteur',p.evaluate('S.tactic===matchDossier().advice.attack&&S.defence===matchDossier().advice.defence'))
        check('sauvegarde compatible',p.evaluate('!!parseSaveDocument(JSON.stringify(createSaveDocument()))'))
        check('aucune erreur navigateur',not errors)
        browser.close()
    out['passed']=True
finally:
    srv.shutdown()
    print(json.dumps(out,ensure_ascii=False))
