"""Réception Chromium du tableau de pilotage, sur une vraie carrière fictive."""
import functools
import http.server
import json
import platform
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
report={'passed':False,'checks':checks,'errors':errors,'limits':['Chromium headless sur '+platform.system()+' uniquement']}
try:
    with sync_playwright() as pw:
        browser=pw.chromium.launch(headless=True)
        page=browser.new_page(viewport={'width':1280,'height':900},color_scheme='dark')
        page.set_default_timeout(10000)
        page.set_default_navigation_timeout(60000)
        # Compter les tirages sans remplacer le générateur réel du jeu.
        page.add_init_script('''(()=>{const random=Math.random;window.pilotageRandomCalls=0;
            Math.random=()=>{window.pilotageRandomCalls++;return random();};})();''')
        page.on('pageerror',lambda e: errors.append(str(e)))
        page.goto('http://127.0.0.1:%d/'%server.server_address[1])
        page.get_by_role('button',name='Nouvelle carrière').click()
        page.get_by_role('button',name='Univers fictif').click()
        page.locator('.clubchoice').first.click()
        page.get_by_role('button',name='Bureau du manager',exact=True).click()
        # Le pilotage natif est une page du Bureau, accessible par son vrai onglet.
        page.get_by_role('tab',name='Dossiers du club').click()
        panel=page.locator('[aria-label="Pilotage de saison"]')
        check('panneau jouable affiché',panel.is_visible())
        indicators=panel.locator('.office-summary strong')
        check('4 indicateurs métier',indicators.count()==4)
        check('4 indicateurs métier visibles',all(indicators.nth(i).is_visible() for i in range(4)))
        check('indicateurs contrats, espoirs, places et salaires',
              panel.locator('.office-summary small').all_text_contents()==[
                  'CONTRATS EN FIN DE SAISON','ESPOIRS AU CENTRE',
                  'PLACES CHEZ LES PROS','MASSE SALARIALE / SEMAINE'])
        expected=page.evaluate('''()=>{
            const players=S.clubs[S.club].players;
            return [String(players.filter(p=>p.contractEnd===S.season).length),
                String(S.development.academy.length),String(42-players.length),
                new Intl.NumberFormat('fr-FR',{style:'currency',currency:'EUR',maximumFractionDigits:0})
                    .format(players.reduce((sum,p)=>sum+p.salary,0))];
        }''')
        check('valeurs issues de la carrière',indicators.all_text_contents()==expected)
        snapshot=page.evaluate('JSON.stringify(S)')
        stored=page.evaluate('localStorage.getItem("bdt-v1")')
        storage=page.evaluate('JSON.stringify({...localStorage})')
        random_calls=page.evaluate('window.pilotageRandomCalls')
        page.evaluate('render()')
        check('aucune mutation sur rendu',page.evaluate('JSON.stringify(S)')==snapshot)
        check('aucune écriture de sauvegarde sur rendu',page.evaluate('localStorage.getItem("bdt-v1")')==stored)
        check('aucune autre écriture de stockage sur rendu',page.evaluate('JSON.stringify({...localStorage})')==storage)
        check('aucun tirage aléatoire sur rendu',page.evaluate('window.pilotageRandomCalls')==random_calls)
        for width in (1280,768,390,320):
            page.set_viewport_size({'width':width,'height':860})
            page.get_by_role('tab',name='Dossiers du club').click()
            check('%d pixels sans débordement'%width,page.evaluate('document.documentElement.scrollWidth<=innerWidth+2'))
            check('%d pixels panneau visible'%width,panel.is_visible())
            for action in ('Contrats →','Suivre la relève →','Explorer le recrutement →'):
                panel.get_by_role('button',name=action,exact=True).click(trial=True)
                checks.append('%d pixels commande utilisable : %s'%(width,action))
        page.set_viewport_size({'width':1280,'height':900})
        page.locator('[aria-label="Pilotage de saison"] button').filter(has_text='Contrats →').first.click()
        check('contrats liés au module natif',page.evaluate("view==='market' && marketTab==='contracts'"))
        page.get_by_role('button',name='Bureau du manager',exact=True).click()
        page.get_by_role('tab',name='Dossiers du club').click()
        page.locator('[aria-label="Pilotage de saison"] button').filter(has_text='Suivre la relève').first.click()
        check('formation reliée au centre jouable',page.evaluate("view==='formation'"))
        page.get_by_role('button',name='Bureau du manager',exact=True).click()
        page.get_by_role('tab',name='Dossiers du club').click()
        page.locator('[aria-label="Pilotage de saison"] button').filter(has_text='Explorer le recrutement').first.click()
        check('recrutement relié au centre jouable',page.evaluate("view==='recruitment'"))
        check('sauvegarde toujours valide',page.evaluate('!!parseSaveDocument(JSON.stringify(createSaveDocument()))'))
        check('aucune erreur JavaScript navigateur',not errors)
        browser.close()
    report['passed']=True
finally:
    server.shutdown()
    print(json.dumps(report,ensure_ascii=False))
