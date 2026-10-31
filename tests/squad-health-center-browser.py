"""Réception Chromium du centre de disponibilité sur une vraie carrière fictive."""
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
report={'passed':False,'checks':checks,'errors':errors,'limits':['Chromium Linux uniquement']}
try:
    with sync_playwright() as pw:
        b=pw.chromium.launch(headless=True)
        page=b.new_page(viewport={'width':1280,'height':900},color_scheme='dark')
        page.set_default_timeout(10000)
        page.on('pageerror',lambda e:errors.append(str(e)))
        page.goto('http://127.0.0.1:%s/'%server.server_address[1])
        page.locator('.clubchoice').first.click()
        page.evaluate("squadTab='health';nav('team')")
        panel=page.locator('.cd-health')
        check('centre visible',panel.is_visible())
        check('quinze postes',panel.locator('.cd-health-slot').count()==15)
        check('trente joueurs visibles',panel.locator('[data-health-row]').count()==page.evaluate('club().players.length'))
        snapshot=page.evaluate('JSON.stringify(S)')
        saved=page.evaluate('localStorage.getItem("bdt-v1")')
        page.evaluate('render()')
        check('consultation sans mutation',page.evaluate('JSON.stringify(S)')==snapshot)
        check('consultation sans réécriture sauvegarde',page.evaluate('localStorage.getItem("bdt-v1")')==saved)
        for width in (1280,768,390,320):
            page.set_viewport_size({'width':width,'height':860})
            page.evaluate("squadTab='health';nav('team')")
            check('largeur %d sans débordement'%width,page.evaluate('document.documentElement.scrollWidth<=innerWidth+2'))
            check('largeur %d panneau visible'%width,page.locator('.cd-health').is_visible())
        page.set_viewport_size({'width':1280,'height':900})
        player_id=page.evaluate('club().players[0].id')
        page.locator('[data-health-search]').fill('aucun-xyz-123')
        check('recherche masque les lignes',page.locator('[data-health-row]:visible').count()==0)
        page.locator('[data-health-search]').fill('')
        page.locator('[data-health-risk]').select_option('fit')
        check('filtre disponibilité',page.locator('[data-health-row]:visible').count()==page.evaluate("squadHealthSnapshot().scores.fit"))
        page.locator('[data-health-risk]').select_option('all')
        page.locator('[data-health-plan="%s"]'%player_id).select_option('repos')
        check('plan natif appliqué',page.evaluate('(id)=>physicalPlan(player(id))',player_id)=='repos')
        check('sauvegarde compatible',page.evaluate('!!parseSaveDocument(JSON.stringify(createSaveDocument()))'))
        page.locator('.cd-health button').filter(has_text='Composer les 23').click()
        check('navigation feuille à 23',page.evaluate("view==='team' && squadTab==='sheet'"))
        page.evaluate("squadTab='health';nav('team')")
        page.locator('.cd-health button').filter(has_text='Voir tous les remplaçants').click()
        check('navigation profondeur',page.evaluate("view==='team' && squadTab==='depth'"))
        check('aucune erreur navigateur',not errors)
        b.close()
    report['passed']=True
finally:
    server.shutdown()
    print(json.dumps(report,ensure_ascii=False))
