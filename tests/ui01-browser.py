"""Actual browser acceptance for UI-01, isolated fictitious careers only."""
import functools
import http.server
import json
import os
from pathlib import Path
import threading
from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parents[1]
OUT = Path(os.environ.get('UI01_REPORT_DIR', str(ROOT / 'ui01-browser-report')))
OUT.mkdir(parents=True, exist_ok=True)
checks = []
errors = []
report = {'passed': False, 'checks': checks, 'pageErrors': errors,
          'limits': ['Chromium Linux only; no native Windows or touch-device certification',
                     'Offline bridge is a test double; no production save is loaded']}
class Handler(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *args):
        pass

def check(name, condition):
    if not condition:
        raise AssertionError(name)
    checks.append(name)

def visible(page, selector):
    return page.locator(selector).first.is_visible()

server = http.server.ThreadingHTTPServer(('127.0.0.1', 0),
    functools.partial(Handler, directory=str(ROOT / 'dist')))
threading.Thread(target=server.serve_forever, daemon=True).start()
url = 'http://127.0.0.1:%s/' % server.server_address[1]
try:
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        context = browser.new_context(viewport={'width': 1440, 'height': 1000}, color_scheme='dark')
        page = context.new_page()
        page.set_default_timeout(10000)
        page.on('pageerror', lambda e: errors.append(str(e)))
        page.goto(url)
        page.get_by_role('button',name='Nouvelle carrière').click();page.get_by_role('button',name='Univers fictif').click()
        check('default system theme resolved dark', page.locator('html').get_attribute('data-cd-theme') == 'analyste')
        check('welcome dark cards have dark surface', page.locator('.clubchoice').first.evaluate('(e)=>getComputedStyle(e).backgroundColor') == 'rgb(20, 31, 48)')
        page.locator('.clubchoice').first.click()
        snapshot = page.evaluate('JSON.stringify(S)')
        saved = page.evaluate('localStorage.getItem("bdt-v1")')
        page.emulate_media(color_scheme='light')
        page.wait_for_function('document.documentElement.dataset.cdTheme === "tribune"')
        check('system theme follows OS while running', True)
        page.locator('#ui01-theme').select_option('analyste')
        page.emulate_media(color_scheme='light')
        check('manual theme ignores OS', page.locator('html').get_attribute('data-cd-theme') == 'analyste')
        check('theme leaves native save unchanged', page.evaluate('localStorage.getItem("bdt-v1")') == saved)
        routes = ['dashboard','team','tactics','plans','staff','recruitment','match','league','history','market','formation','finance','saves','help']
        for width in (1440, 1024, 768, 390, 320):
            page.set_viewport_size({'width': width, 'height': 1000 if width > 800 else 844})
            for theme in ('tribune', 'analyste'):
                page.locator('#ui01-theme').select_option(theme)
                for route in routes:
                    group = page.evaluate('(route)=>UI01_GROUPS.find(g=>g.routes.includes(route)).id', route)
                    page.locator('.ui01-primary-nav button[onclick="nav(\'%s\')"]' % group).click()
                    if route == 'team':
                        page.locator('.ui01-secondary-nav button').first.click()
                    else:
                        page.locator('.ui01-secondary-nav button[onclick="nav(\'%s\')"]' % route).click()
                    check('%s/%s/%s navigation' % (width, theme, route), page.evaluate('view') == route)
                    check('%s/%s/%s valid career' % (width, theme, route), page.evaluate('!!parseSaveDocument(JSON.stringify(createSaveDocument()))'))
                    dims = page.evaluate('({width:innerWidth,scroll:document.documentElement.scrollWidth})')
                    check('%s/%s/%s no page overflow' % (width, theme, route), dims['scroll'] <= dims['width'] + 2)
                page.evaluate('nav("dashboard")')
                if width in (1440, 390):
                    page.screenshot(path=str(OUT / ('bureau-%s-%s.png' % (width, theme))))
                check('%s/%s session actions visible' % (width, theme), visible(page, '.ui01-session-tools button[onclick="resetDialog()"]'))
                page.evaluate('lastSaveError=true;render()')
                check('%s/%s save failure visible' % (width, theme), visible(page, '.ui01-session-tools [role="alert"]'))
                page.evaluate('lastSaveError=false;render()')
                page.locator('.ui01-session-tools button[onclick="resetDialog()"]').click()
                check('%s/%s dialog covers appbar' % (width, theme), page.evaluate('document.elementFromPoint(15,15).closest(".modalback") !== null'))
                page.locator('.modal button[onclick="closeModal()"]').click()
        check('navigation and themes do not mutate career', page.evaluate('JSON.stringify(S)') == snapshot)
        page.set_viewport_size({'width': 390, 'height': 844})
        page.evaluate('nav("team")')
        page.locator('.ui01-secondary-nav button').nth(1).click()
        check('sheet tab uses real 23 players', page.evaluate('squadTab === "sheet" && S.lineup.length === 15 && S.reserves.length === 8'))
        page.screenshot(path=str(OUT / 'feuille-390.png'))
        page.evaluate('nav("match");beginMatch();pauseMatch();render()')
        check('V40 cockpit is visible', visible(page, '.v40-cockpit'))
        check('new bar does not cover live cockpit', page.locator('.ui01-appbar').count() == 0)
        check('paused native match exports', page.evaluate('!!parseSaveDocument(JSON.stringify(createSaveDocument()))'))
        page.set_viewport_size({'width': 1440, 'height': 1000})
        page.screenshot(path=str(OUT / 'match-1440.png'))
        # A bridge double verifies wiring, not the operating-system launcher.
        offline = browser.new_context(viewport={'width': 390, 'height': 844})
        offline.add_init_script("""window.CDOfflineStorage={offline:true,directory:'test-only',getItem:k=>localStorage.getItem(k),setItem:(k,v)=>localStorage.setItem(k,v),removeItem:k=>localStorage.removeItem(k)};window.CDOfflineAction=(a)=>{window.lastOfflineAction=a};""")
        q=offline.new_page();q.on('pageerror',lambda e:errors.append(str(e)));q.goto(url);q.get_by_role('button',name='Nouvelle carrière').click();q.get_by_role('button',name='Univers fictif').click();q.locator('.clubchoice').first.click()
        q.locator('.ui01-session-tools button[onclick="window.CDOfflineAction(\'quit\')"]').click()
        check('offline quit routes to existing bridge', q.evaluate('window.lastOfflineAction') == 'quit')
        check('no page JavaScript exception', not errors)
        report['passed']=True
        browser.close()
except Exception as e:
    report['failure'] = repr(e)
    try:
        page.screenshot(path=str(OUT / 'failure.png'))
    except Exception:
        pass
    raise
finally:
    report['passedChecks']=len(checks)
    (OUT / 'report.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
    server.shutdown()
    print(json.dumps({'passed':report['passed'],'checks':len(checks),'failure':report.get('failure')}))
