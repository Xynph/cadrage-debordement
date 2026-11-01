"""V4.9 — véritables sous-pages PC finance / formation, rendu et sauvegarde."""
import functools
import http.server
import json
import os
import threading
from pathlib import Path

from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parents[1]
OUT = Path(os.environ.get('V49_REPORT_DIR', str(ROOT / 'ui01-browser-report' / 'premium-v49')))
OUT.mkdir(parents=True, exist_ok=True)
server = http.server.ThreadingHTTPServer(
    ('127.0.0.1', 0),
    functools.partial(http.server.SimpleHTTPRequestHandler, directory=str(ROOT / 'dist'))
)
threading.Thread(target=server.serve_forever, daemon=True).start()
checks, errors, http_errors = [], [], []
passed = False

def check(name, value):
    if not value:
        raise AssertionError(name)
    checks.append(name)

SCREENS = {
    'finance': ('tresorerie', 'flux', 'salaires', 'dossiers'),
    'formation': ('passerelle', 'potentiel', 'dossiers'),
}
try:
    with sync_playwright() as pw:
        browser = pw.chromium.launch(headless=True)
        page = browser.new_page(viewport={'width': 1440, 'height': 900},
                                reduced_motion='reduce', color_scheme='dark')
        page.set_default_timeout(15000)
        page.add_init_script(
            'let seed=93217;Math.random=()=>{seed=(Math.imul(seed,1664525)+1013904223)>>>0;return seed/4294967296;}'
        )
        page.on('pageerror', lambda e: errors.append(str(e)))
        page.on('response', lambda r: http_errors.append(str(r.status) + ' ' + r.url) if r.status >= 400 else None)
        page.goto('http://127.0.0.1:%s/' % server.server_address[1])
        check('V4.9 stylesheet loaded', page.locator('link[href="premium-v49.css"]').count() == 1)
        page.locator('.cd3-nav').get_by_role('button', name='Nouvelle carrière').click()
        page.get_by_role('button', name='Univers fictif').click()
        page.locator('.clubchoice').first.click()
        initial_state = page.evaluate('JSON.stringify(S)')
        initial_disk = page.evaluate('localStorage.getItem("bdt-v1")')
        # Réception du toast natif : captures et interaction sans mutation métier.
        # Chaque combinaison réarme le message authentique via toast(), sans
        # toucher à la carrière ni au stockage. Les essais de clic restent dry-run.
        toast_metrics = []
        for toast_theme in ('analyste', 'tribune'):
            page.locator('#ui01-theme').select_option(toast_theme)
            for toast_width, toast_height in ((1440, 900), (1920, 1080)):
                page.set_viewport_size({'width': toast_width, 'height': toast_height})
                status = page.locator('#toast')
                check(f'toast status element {toast_theme}/{toast_width}',
                      status.count() == 1 and status.get_attribute('role') == 'status')
                page.evaluate("()=>toast('Bienvenue au club. Votre saison commence maintenant.')")
                check(f'toast accessible when shown {toast_theme}/{toast_width}',
                      page.get_by_role('status').count() == 1)
                check(f'toast initially shown {toast_theme}/{toast_width}',
                      status.is_visible() and
                      'Bienvenue au club.' in status.inner_text())
                page.evaluate("()=>nav('finance')")
                finance_shell = page.locator('.da42-workspace-shell')
                finance_shell.locator('[data-da42-subpage="tresorerie"]').click()
                check(f'finance tab during toast {toast_theme}/{toast_width}',
                      finance_shell.locator('[data-da42-subpage="tresorerie"]').get_attribute('aria-selected') == 'true')
                page.screenshot(path=str(OUT / f'v49-toast-finance-before-{toast_theme}-{toast_width}.png'),
                                full_page=False)
                page.evaluate("()=>nav('formation')")
                formation_shell = page.locator('.da42-workspace-shell')
                formation_shell.locator('[data-da42-subpage="passerelle"]').click()
                action = formation_shell.locator('[data-da42-page="passerelle"]:not([hidden]) .da4-pathway .da4-text-action')
                check(f'formation action during toast {toast_theme}/{toast_width}',
                      action.count() == 1 and action.is_enabled())
                action.scroll_into_view_if_needed()
                before_hit = action.evaluate("""e=>{
                    const r=e.getBoundingClientRect();
                    const hit=document.elementFromPoint(r.left+r.width/2,r.top+r.height/2);
                    return !!hit && (e===hit || e.contains(hit));
                }""")
                page.screenshot(path=str(OUT / f'v49-toast-formation-before-{toast_theme}-{toast_width}.png'),
                                full_page=False)
                elapsed = page.evaluate("()=>performance.now()")
                page.wait_for_function("""() => {
                    const node=document.getElementById('toast');
                    return node && getComputedStyle(node).display==='none';
                }""", timeout=7500)
                elapsed = page.evaluate("start=>performance.now()-start", elapsed)
                check(f'toast timeout within expected window {toast_theme}/{toast_width}',
                      1000 <= elapsed <= 7200)
                check(f'toast auto hidden {toast_theme}/{toast_width}',
                      not status.is_visible())
                action.scroll_into_view_if_needed()
                action.click(trial=True)
                check(f'formation action interactable after toast {toast_theme}/{toast_width}',
                      action.is_visible() and action.is_enabled())
                page.screenshot(path=str(OUT / f'v49-toast-formation-after-{toast_theme}-{toast_width}.png'),
                                full_page=False)
                page.evaluate("()=>nav('finance')")
                finance_shell = page.locator('.da42-workspace-shell')
                finance_shell.locator('[data-da42-subpage="tresorerie"]').click()
                values = finance_shell.locator('[data-da42-page="tresorerie"]:not([hidden]) .da42-static-values tbody tr')
                values.last.scroll_into_view_if_needed()
                check(f'finance bottom value after toast {toast_theme}/{toast_width}',
                      values.count() > 0 and values.last.is_visible())
                page.screenshot(path=str(OUT / f'v49-toast-finance-after-{toast_theme}-{toast_width}.png'),
                                full_page=False)
                check(f'career preserved after toast {toast_theme}/{toast_width}',
                      page.evaluate('JSON.stringify(S)') == initial_state)
                check(f'save preserved after toast {toast_theme}/{toast_width}',
                      page.evaluate('localStorage.getItem("bdt-v1")') == initial_disk)
                toast_metrics.append({'theme': toast_theme, 'width': toast_width,
                                      'visibleInitially': True, 'hiddenAfterTimer': True,
                                      'formationActionCenterHitBefore': before_hit})
        check('16 toast before and after screenshots', len(toast_metrics) == 4)
        metrics = []
        for theme in ('analyste', 'tribune'):
            page.locator('#ui01-theme').select_option(theme)
            for width, height in ((1440, 900), (1920, 1080)):
                page.set_viewport_size({'width': width, 'height': height})
                for route, subpages in SCREENS.items():
                    page.evaluate('(route)=>nav(route)', route)
                    shell = page.locator('.da42-workspace-shell')
                    check(f'workspace {route}/{theme}/{width}', shell.count() == 1)
                    check(f'all native tabs {route}/{theme}/{width}',
                          shell.get_by_role('tab').count() == len(subpages))
                    check(f'V4.9 sheet active {route}/{theme}/{width}',
                          page.evaluate("""()=>[...document.styleSheets].some(s=>
                             s.href?.endsWith('/premium-v49.css') && !s.disabled)"""))
                    for key in subpages:
                        tab = shell.locator(f'[data-da42-subpage="{key}"]')
                        tab.click()
                        active = shell.locator(f'[data-da42-page="{key}"]:not([hidden])')
                        check(f'native page {route}/{key}/{theme}/{width}',
                              tab.get_attribute('aria-selected') == 'true' and active.count() == 1)
                        check(f'no global vertical scroll {route}/{key}/{theme}/{width}',
                              page.evaluate('document.documentElement.scrollHeight <= innerHeight + 2'))
                        check(f'no horizontal overflow {route}/{key}/{theme}/{width}',
                              page.evaluate('document.documentElement.scrollWidth <= innerWidth + 2'))
                        check(f'career preserved {route}/{key}/{theme}/{width}',
                              page.evaluate('JSON.stringify(S)') == initial_state)
                        check(f'save preserved {route}/{key}/{theme}/{width}',
                              page.evaluate('localStorage.getItem("bdt-v1")') == initial_disk)
                        if route == 'finance' and key == 'tresorerie':
                            check(f'native treasury graph {theme}/{width}',
                                  active.locator('.da4-finance-chart').count() > 0)
                            check(f'treasury plot readable {theme}/{width}',
                                  active.locator('.da4-chart-viewport').evaluate(
                                      "e=>e.clientHeight>=180 && e.getBoundingClientRect().bottom<=e.parentElement.querySelector('figcaption').getBoundingClientRect().top+1"))
                            check(f'treasury table below graph {theme}/{width}',
                                  active.locator('.da4-finance-chart').evaluate(
                                      "e=>e.querySelector('.da4-figure').getBoundingClientRect().bottom<=e.querySelector('.da42-static-values').getBoundingClientRect().top+1"))
                            check(f'V4.9 treasury hierarchy {theme}/{width}',
                                  active.locator('.da4-chart-numbers').evaluate(
                                      "e=>getComputedStyle(e).display==='grid'"))
                        if route == 'finance' and key == 'flux':
                            check(f'native weekly cashflow {theme}/{width}',
                                  active.locator('.da42-cash-timeline').count() == 1)
                        if route == 'formation' and key == 'passerelle':
                            check(f'native academy pathway {theme}/{width}',
                                  active.locator('.da4-academy-stage').count() > 0)
                        if route == 'formation' and key == 'potentiel':
                            check(f'V4.9 real player cards {theme}/{width}',
                                  active.locator('.da42-talent').count() > 0)
                        if route == 'formation' and key == 'potentiel':
                            check(f'talent cards do not clip their values {theme}/{width}',
                                  active.locator('.da42-talent').evaluate_all(
                                      "cards=>cards.every(e=>e.scrollHeight<=e.clientHeight+1 && e.querySelector('footer').getBoundingClientRect().bottom<=e.getBoundingClientRect().bottom)"))
                        if route == 'finance' and key == 'tresorerie':
                            values = active.locator('.da42-static-values')
                            values.locator('tbody tr').last.scroll_into_view_if_needed()
                            check(f'treasury last value reachable {theme}/{width}',
                                  values.locator('tbody tr').last.is_visible())
                            active.locator('.da4-finance-chart').evaluate('e=>e.scrollTop=0')
                        if route == 'formation' and key == 'passerelle':
                            action = active.locator('.da4-pathway .da4-text-action')
                            action.scroll_into_view_if_needed()
                            check(f'young pros action reachable {theme}/{width}', action.is_visible())
                            active.locator('.da4-pathway').evaluate('e=>e.scrollTop=0')
                        metrics.append({'route': route, 'subpage': key, 'theme': theme,
                                        'width': width,
                                        'tabCount': shell.get_by_role('tab').count(),
                                        'visiblePanels': shell.locator('.da42-page:not([hidden])').count()})
                        page.screenshot(path=str(OUT / f'v49-{route}-{key}-{theme}-{width}.png'),
                                        full_page=False)
        check('28 real Chromium screenshots', len(metrics) == 28)
        check('no JavaScript exceptions', not errors)
        check('no HTTP asset errors', not http_errors)
        passed = True
        browser.close()
finally:
    server.shutdown()
    (OUT / 'report.json').write_text(json.dumps({
        'passed': passed,
        'checks': checks,
        'errors': errors,
        'httpErrors': http_errors,
        'metrics': metrics if 'metrics' in locals() else [],
        'toastMetrics': toast_metrics if 'toast_metrics' in locals() else [],
        'limits': ['Chromium Linux seulement; pas de Windows natif, Safari ou audit lecteur ecran.']
    }, ensure_ascii=False, indent=2))
print(json.dumps({'passed': passed, 'checks': len(checks), 'errors': errors}))
