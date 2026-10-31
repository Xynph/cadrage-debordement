"""Réception Chromium du tableau de pilotage, sur une vraie carrière fictive."""
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
server=http.server.ThreadingHTTPServer(('127.0.0.1',0),functools.partial(Handler,directory=str(ROOT/'dist')))
threading.Thread(target=server.serve_forever,daemon=True).start()
report={'passed':False,'checks':checks,'errors':errors,'limits':['Chromium Linux uniquement']}
try:
    with sync_playwright() as pw:
        browser=pw.chromium.launch(headless=True)
        page=browser.new_page(viewport={'width':1280,'height':900},color_scheme='dark')
        page.set_default_timeout(10000)
        page.on('pageerror',lambda e: errors.append(str(e)))
        page.goto('http://127.0.0.1:%d/'%server.server_address[1])
        page.locator('.clubchoice').first.click()
        page.evaluate("nav('dashboard')")
        panel=page.locator('[aria-label="Pilotage de saison"]')
        check('panneau jouable affiché',panel.is_visible())
        check('4 indicateurs métier',panel.locator('.office-summary strong').count()==4)
        snapshot=page.evaluate('JSON.stringify(S)')
        stored=page.evaluate('localStorage.getItem("bdt-v1")')
        page.evaluate('render()')
        check('aucune mutation sur rendu',page.evaluate('JSON.stringify(S)')==snapshot)
        check('aucune écriture de sauvegarde sur rendu',page.evaluate('localStorage.getItem("bdt-v1")')==stored)
        for width in (1280,768,390,320):
            page.set_viewport_size({'width':width,'height':860})
            page.evaluate("nav('dashboard')")
            check('%d pixels sans débordement'%width,page.evaluate('document.documentElement.scrollWidth<=innerWidth+2'))
            check('%d pixels panneau visible'%width,page.locator('[aria-label="Pilotage de saison"]').is_visible())
        page.set_viewport_size({'width':1280,'height':900})
        page.locator('[aria-label="Pilotage de saison"] button').filter(has_text='Contrats →').first.click()
        check('contrats liés au module natif',page.evaluate("view==='market' && marketTab==='contracts'"))
        page.evaluate("nav('dashboard')")
        page.locator('[aria-label="Pilotage de saison"] button').filter(has_text='Suivre la relève').first.click()
        check('formation reliée au centre jouable',page.evaluate("view==='formation'"))
        page.evaluate("nav('dashboard')")
        page.locator('[aria-label="Pilotage de saison"] button').filter(has_text='Explorer le recrutement').first.click()
        check('recrutement relié au centre jouable',page.evaluate("view==='recruitment'"))
        check('sauvegarde toujours valide',page.evaluate('!!parseSaveDocument(JSON.stringify(createSaveDocument()))'))
        check('aucune erreur JavaScript navigateur',not errors)
        browser.close()
    report['passed']=True
finally:
    server.shutdown()
    print(json.dumps(report,ensure_ascii=False))
