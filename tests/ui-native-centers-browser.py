"""Réception Chromium des centres de recrutement et formation raccordés au jeu réel."""
import functools
import http.server
import json
from pathlib import Path
import threading
from playwright.sync_api import sync_playwright

ROOT=Path(__file__).resolve().parents[1]
checks=[]
errors=[]
class Handler(http.server.SimpleHTTPRequestHandler):
    def log_message(self,*args): pass
def check(label,condition):
    if not condition: raise AssertionError(label)
    checks.append(label)
server=http.server.ThreadingHTTPServer(('127.0.0.1',0),
    functools.partial(Handler,directory=str(ROOT/'dist')))
threading.Thread(target=server.serve_forever,daemon=True).start()
report={'passed':False,'checks':checks,'errors':errors,
        'limits':['Chromium Linux seulement, pas de certification mobile ou Windows']}
try:
    with sync_playwright() as pw:
        browser=pw.chromium.launch(headless=True)
        page=browser.new_page(viewport={'width':1280,'height':900},color_scheme='dark')
        page.set_default_timeout(15000)
        page.on('pageerror',lambda e:errors.append(str(e)))
        page.goto('http://127.0.0.1:%d/'%server.server_address[1])
        page.get_by_role('button',name='Nouvelle carrière').click();page.get_by_role('button',name='Univers fictif').click()
        page.locator('.clubchoice').first.click()
        page.evaluate("nav('recruitment')")
        check('centre de recrutement visible',page.locator('.cd03').is_visible())
        original=page.evaluate('JSON.stringify(S)')
        saved=page.evaluate('localStorage.getItem("bdt-v1")')
        page.locator('.cd03-tabs [data-ui03-tab="candidates"]').click()
        check('candidats du moteur',page.locator('.cd03-candidates tbody tr').count()>0)
        page.locator('[data-ui03-action="search"]').fill('inexistant-z-987')
        check('recherche sans résultat',page.locator('.cd03-candidates').inner_text().find('Aucun candidat')>=0)
        page.locator('[data-ui03-action="search"]').fill('')
        check('consultation sans mutation',page.evaluate('JSON.stringify(S)')==original)
        check('consultation sans écriture sauvegarde',page.evaluate('localStorage.getItem("bdt-v1")')==saved)
        page.locator('[data-ui03-action="watch"]').first.click()
        check('joueur suivi en carrière',page.evaluate('S.manager.watch.length===1'))
        page.locator('[data-ui03-tab="missions"]').click()
        cash=page.evaluate('club().cash')
        page.locator('[data-ui03-mission] button[type="submit"]').click()
        check('mission native créée',page.evaluate('S.manager.missions.length===1'))
        check('mission débitée 5000 euros',page.evaluate('club().cash')==cash-5000)
        page.evaluate("nav('formation')")
        check('centre de formation visible',page.locator('.cd04').is_visible())
        page.locator('.cd04-tabs [data-ui04-tab="academy"]').click()
        check('espoirs présents',page.locator('.cd04-player-link').count()>0)
        page.locator('.cd04-player-link').first.click()
        check('fiche jeune ouverte',page.locator('.cd04-detail').is_visible())
        youth_id=page.evaluate('S.development.academy[0].id')
        page.once('dialog',lambda dialog:dialog.accept())
        page.locator('[data-ui04-action="promote"][data-ui04-id="%s"]'%youth_id).first.click()
        check('promotion effective',page.evaluate('(id)=>club().players.some(p=>p.id===id)',youth_id))
        check('sortie du centre',page.evaluate('(id)=>!S.development.academy.some(p=>p.id===id)',youth_id))
        check('sauvegarde compatible',page.evaluate('!!parseSaveDocument(JSON.stringify(createSaveDocument()))'))
        check('aucune erreur navigateur',not errors)
        browser.close()
    report['passed']=True
finally:
    server.shutdown()
    print(json.dumps(report,ensure_ascii=False))
