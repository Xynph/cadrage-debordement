"""Contrôle Chromium UI-02C du vrai jeu servi en HTTP local."""
import functools
import http.server
import json
import os
from pathlib import Path
import threading
from playwright.sync_api import sync_playwright

ROOT=Path(__file__).resolve().parents[1]
OUT=Path(os.environ.get('UI02_REPORT_DIR',str(ROOT/'ui02-browser-report')))
OUT.mkdir(exist_ok=True)
results=[]
errors=[]
class Handler(http.server.SimpleHTTPRequestHandler):
    def log_message(self,*args):
        pass
def check(label,value):
    if not value:
        raise AssertionError(label)
    results.append(label)

server=http.server.ThreadingHTTPServer(('127.0.0.1',0),functools.partial(Handler,directory=str(ROOT/'dist')))
threading.Thread(target=server.serve_forever,daemon=True).start()
url='http://127.0.0.1:%s/' % server.server_address[1]
report={'passed':False,'checks':results,'errors':errors,'limits':['Chromium Linux, sans validation Windows ou téléphone physique']}
try:
    with sync_playwright() as pw:
        browser=pw.chromium.launch(headless=True)
        context=browser.new_context(viewport={'width':1440,'height':1000},color_scheme='dark')
        page=context.new_page()
        page.set_default_timeout(12000)
        page.on('pageerror',lambda e:errors.append(str(e)))
        page.goto(url)
        check('modules UI02 chargés',page.evaluate('typeof CDUI02Data==="object" && typeof CDUI02Components==="object" && typeof ui02TeamView==="function"'))
        page.locator('.clubchoice').first.click()
        page.evaluate("nav('team')")
        check('effectif visible',page.locator('.cd02-roster').is_visible())
        check('commandes session intactes',page.locator('.ui01-session-tools').is_visible())
        check('volet entraînement présent',page.locator('details.cd02-training').count()==1)
        snapshot=page.evaluate('JSON.stringify(S)')
        saved=page.evaluate('localStorage.getItem("bdt-v1")')
        player_ids=page.evaluate('club().players.slice(0,2).map(p=>p.id)')
        check('joueurs issus du moteur',page.locator('.cd02-player-link').count()>20)
        for width in (1440,1024,768,390,320):
            page.set_viewport_size({'width':width,'height':1000 if width>800 else 844})
            for theme in ('analyste','tribune'):
                page.locator('#ui01-theme').select_option(theme)
                page.evaluate("squadTab='table';nav('team')")
                check('%s %s tableau'%(width,theme),page.locator('.cd02-roster').is_visible())
                check('%s %s sans débordement'% (width,theme),page.evaluate('document.documentElement.scrollWidth<=innerWidth+2'))
                if width in (1440,390,320):
                    page.screenshot(path=str(OUT/('effectif-%s-%s.png'%(width,theme))),full_page=True)
                page.locator('.cd02-player-link').first.click()
                check('%s %s fiche plein écran'%(width,theme),page.locator('.cd02-player').is_visible())
                check('%s %s onglets'%(width,theme),page.locator('.cd02-player [role="tab"]').count()==4)
                page.locator('[data-cd02-tab="attributs"]').click()
                check('%s %s onze qualités'%(width,theme),page.locator('.cd02-attribute').count()==11)
                page.keyboard.press('ArrowRight')
                check('%s %s navigation clavier'%(width,theme),page.locator('[data-cd02-tab="contrat"]').get_attribute('aria-selected')=='true')
                if width in (1440,390):
                    page.screenshot(path=str(OUT/('joueur-%s-%s.png'%(width,theme))),full_page=True)
                page.locator('[data-ui02-back]').click()
                check('%s %s retour effectif'%(width,theme),page.locator('.cd02-roster').is_visible())
        check('lecture sans mutation carrière',page.evaluate('JSON.stringify(S)')==snapshot)
        check('lecture sans sauvegarde carrière',page.evaluate('localStorage.getItem("bdt-v1")')==saved)
        page.set_viewport_size({'width':1440,'height':1000})
        page.locator('#ui01-theme').select_option('analyste')
        page.locator('.cd02-columns summary').click()
        page.locator('.cd02-columns input[value="salary"]').check()
        check('colonne salaire ajoutée',page.locator('th button[data-cd02-sort="salary"]').count()==1)
        check('préférence enregistrée hors carrière',page.evaluate('(JSON.parse(localStorage.getItem("cd-ui02-columns-v1")).columns||[]).includes("salary")'))
        check('sélection sans mutation carrière',page.evaluate('JSON.stringify(S)')==snapshot)
        page.locator('input[data-cd02-action="search"]').fill('ABSENT_TEST_012345')
        check('recherche vide',page.locator('.cd02-roster').get_by_text('Aucun joueur ne correspond aux critères.').count()==1)
        page.locator('input[data-cd02-action="search"]').fill('')
        check('focus conservé recherche',page.evaluate('document.activeElement.getAttribute("data-cd02-action")==="search"'))
        page.locator('[data-ui02-compare="0"]').select_option(player_ids[0])
        page.locator('[data-ui02-compare="1"]').select_option(player_ids[1])
        check('comparaison visible',page.locator('.cd02-comparison').is_visible())
        check('comparaison sans mutation',page.evaluate('JSON.stringify(S)')==snapshot)
        page.reload()
        page.evaluate("nav('team')")
        check('colonnes restaurées',page.locator('th button[data-cd02-sort="salary"]').count()==1)
        check('sauvegarde restaurable',page.evaluate('!!parseSaveDocument(JSON.stringify(createSaveDocument()))'))
        page.locator('details.cd02-training summary').click()
        page.locator('[data-ui02-training]').first.select_option('repos')
        check('entraînement physique natif',page.evaluate('physicalPlan(club().players[0])==="repos"'))
        page.evaluate("squadTab='sheet';nav('team')")
        check('XV et huit remplaçants inchangés',page.evaluate('S.lineup.length===15&&S.reserves.length===8'))
        page.evaluate("nav('match');beginMatch();pauseMatch();render()")
        check('cockpit V40',page.locator('.v40-cockpit').is_visible())
        check('interface joueur masquée pendant match',page.locator('.cd02-player,.cd02-roster').count()==0)
        check('aucune erreur JavaScript de page',not errors)
        report['passed']=True
        browser.close()
finally:
    report['passedChecks']=len(results)
    (OUT/'report.json').write_text(json.dumps(report,indent=2,ensure_ascii=False),encoding='utf-8')
    server.shutdown()
    print(json.dumps({'passed':report['passed'],'checks':len(results),'errors':errors},ensure_ascii=False))
