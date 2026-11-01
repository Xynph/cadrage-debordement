"""PC / V4.2 — véritables sous-pages de gestion, régressions Chromium et sauvegardes."""
import functools
import http.server
import json
import os
import threading
from pathlib import Path

from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parents[1]
OUT = Path(os.environ.get('DA4_REPORT_DIR', str(ROOT / 'ui01-browser-report' / 'art-direction-v4')))
OUT.mkdir(parents=True, exist_ok=True)
Handler = functools.partial(http.server.SimpleHTTPRequestHandler, directory=str(ROOT / 'dist'))
server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), Handler)
threading.Thread(target=server.serve_forever, daemon=True).start()
checks = []
errors = []
success = False


def check(label, condition):
    assert condition, label
    checks.append(label)


PAGES = {
    'dashboard': ('pilotage', 'calendrier', 'dossiers'),
    'tactics': ('xv', 'condition', 'analyse', 'dossiers'),
    'finance': ('tresorerie', 'flux', 'salaires', 'dossiers'),
    'recruitment': ('besoins', 'marche', 'dossiers'),
    'formation': ('passerelle', 'potentiel', 'dossiers'),
}
DOM = {
    'dashboard': { 'pilotage': '.da42-command', 'calendrier': '.da4-calendar' },
    'tactics': { 'condition': '.da42-fitness', 'analyse': '.da4-tactics-stage' },
    'finance': { 'tresorerie': '.da4-finance-chart', 'flux': '.da42-cash-stage' },
    'recruitment': { 'besoins': '.da4-recruit-stage', 'marche': '.da42-market' },
    'formation': { 'passerelle': '.da4-academy-stage', 'potentiel': '.da42-academy' },
}


try:
    with sync_playwright() as pw:
        browser = pw.chromium.launch(headless=True)
        page = browser.new_page(viewport={'width': 1440, 'height': 900}, color_scheme='dark',
                                reduced_motion='reduce')
        page.set_default_timeout(12000)
        page.on('pageerror', lambda error: errors.append(str(error)))
        page.add_init_script(
            'let seed=82321;Math.random=()=>{seed=(Math.imul(seed,1664525)+1013904223)>>>0;return seed/4294967296;}'
        )
        page.goto('http://127.0.0.1:%s/' % server.server_address[1])
        page.locator('.cd3-nav').get_by_role('button', name='Nouvelle carrière').click()
        page.get_by_role('button', name='Univers fictif').click()
        page.locator('.clubchoice').first.click()
        original = page.evaluate('JSON.stringify(S)')
        stored = page.evaluate('localStorage.getItem("bdt-v1")')
        page.locator('#ui01-theme').select_option('analyste')
        for width, height in ((1920, 1080), (1440, 900)):
            page.set_viewport_size({'width': width, 'height': height})
            for route, subpages in PAGES.items():
                page.evaluate('(r)=>nav(r)', route)
                shell = page.locator('.da42-workspace-shell')
                check(f'workspace on {route} {width}', shell.count() == 1)
                tabs = shell.get_by_role('tab')
                check(f'full subnavigation {route} {width}', tabs.count() == len(subpages))
                check(f'page count {route} {width}', shell.get_by_role('tabpanel', include_hidden=True).count() == len(subpages))
                # V4.3: every workspace has a fixed context strip and two real
                # previous/next controls inside the navigation band, never an accordion.
                check(f'V4.3 context dock exists {route} {width}',
                      shell.locator('.da43-page-switch').count() == 1)
                check(f'V4.3 navigation commands {route} {width}',
                      shell.locator('[data-da43-prev],[data-da43-next]').count() == 2)
                check(f'V4.3 intact ARIA panel links {route} {width}',
                      page.evaluate("""()=>[...document.querySelectorAll('.da43-workspace [role=tab]')].every(t=>{
                         const panel=document.getElementById(t.getAttribute('aria-controls'));
                         return !!panel && panel.getAttribute('aria-labelledby')===t.id;
                      })"""))
                # Each button swaps the whole page; no accordion is used for navigation.
                for i, key in enumerate(subpages):
                    tab = shell.locator(f'[data-da42-subpage="{key}"]')
                    tab.click()
                    check(f'active tab {route}/{key} {width}', tab.get_attribute('aria-selected') == 'true')
                    check(f'V4.3 accurate page index {route}/{key} {width}',
                          shell.locator('.da43-page-count').inner_text().strip() ==
                          f'{i+1:02d} / {len(subpages):02d}')
                    check(f'V4.3 native contextual signal {route}/{key} {width}',
                          page.evaluate("""()=>{
                            const a=document.querySelector('.da43-context-key')?.textContent.trim();
                            const b=document.querySelector('.da43-context-value')?.textContent.trim();
                            return !!a && !!b && !/undefined|NaN/.test(a+' '+b);
                          }"""))
                    check(f'one visible page {route}/{key} {width}',
                          shell.locator('.da42-page:not([hidden])').count() == 1)
                    check(f'panel id {route}/{key} {width}',
                          shell.locator(f'[data-da42-page="{key}"]:not([hidden])').count() == 1)
                    check(f'no global page scroll {route}/{key} {width}',
                          page.evaluate('document.documentElement.scrollHeight<=innerHeight+2'))
                    check(f'no horizontal page scroll {route}/{key} {width}',
                          page.evaluate('document.documentElement.scrollWidth<=innerWidth+2'))
                    check(f'career unchanged {route}/{key} {width}',
                          page.evaluate('JSON.stringify(S)') == original)
                    check(f'saved career unchanged {route}/{key} {width}',
                          page.evaluate('localStorage.getItem("bdt-v1")') == stored)
                    target = DOM.get(route, {}).get(key)
                    if target:
                        check(f'real content on {route}/{key} {width}',
                              shell.locator(f'[data-da42-page="{key}"] {target}').is_visible())
                    if key != 'dossiers':
                        check(f'no disclosure for navigation {route}/{key} {width}',
                              shell.locator(f'[data-da42-page="{key}"] > details.da4-dossier').count() == 0)
                    if route in ('formation', 'recruitment') and key == 'dossiers':
                        metric = '.cd04-kpis' if route == 'formation' else '.cd03-kpis'
                        check(f'native KPIs moved to dossiers {route} {width}',
                              shell.locator(f'[data-da42-page="dossiers"] {metric}').count() == 1)
                    if route == 'formation' and key == 'potentiel':
                        check(f'visible complete talent cards {width}', page.evaluate("""()=>{
                          const cards=[...document.querySelectorAll('.da42-page:not([hidden]) .da42-talent')];
                          const bounds=document.querySelector('.da42-page:not([hidden])').getBoundingClientRect();
                          return !!cards.length && cards.every(c=>{
                            const b=c.getBoundingClientRect();
                            return b.top>=bounds.top-2 && b.bottom<=bounds.bottom+2 && b.height>=100;
                          });
                        }"""))
                    if route == 'finance' and key == 'tresorerie':
                        check(f'V4.3 full-width treasury curve {width}', page.evaluate("""()=>{
                          const poly=document.querySelector('.da42-page:not([hidden]) .da4-finance-chart .da4-line');
                          if(!poly)return false;
                          const b=poly.getBoundingClientRect();
                          return b.width>=Math.min(innerWidth*.42,780) && b.height>18;
                        }"""))
                    if route == 'finance' and key == 'salaires':
                        check(f'V4.3 readable nine wage rows {width}', page.evaluate("""()=>{
                          const rows=[...document.querySelectorAll('.da42-page:not([hidden]) .da4-bar-row')];
                          return rows.length===9&&rows.every(row=>row.getBoundingClientRect().height>=24);
                        }"""))
                    if route == 'dashboard' and key == 'calendrier':
                        check(f'V4.3 full-height fixture cards {width}', page.evaluate("""()=>{
                          const rows=[...document.querySelectorAll('.da42-page:not([hidden]) .da4-fixture-stop')];
                          return rows.length>0&&rows.every(row=>row.getBoundingClientRect().height>=130);
                        }"""))
                    if route == 'dashboard' and key == 'calendrier':
                        check(f'V4.3.1 fixture composition balances 5 cards {width}', page.evaluate("""()=>{
                          const rows=[...document.querySelectorAll('.da42-page:not([hidden]) .da4-fixture-stop')];
                          return rows.length===5&&rows.every((row,i)=>{
                            const card=row.getBoundingClientRect();
                            const name=row.querySelector('.da4-stop-name')?.getBoundingClientRect();
                            const css=getComputedStyle(row), mark=getComputedStyle(row,'::after').content;
                            return !!name && name.bottom<=card.bottom+1 && name.top>card.top+card.height*.50
                              && css.counterIncrement.includes('da43-fixture')
                              && mark.includes('counter(da43-fixture');
                          });
                        }"""))
                    if route == 'recruitment' and key == 'marche':
                        geometry = page.evaluate("""()=>{
                          const e=document.querySelector('.da42-page:not([hidden]) .da42-market-composition');
                          const p=document.querySelector('.da42-page:not([hidden])');
                          const a=e.getBoundingClientRect(),b=p.getBoundingClientRect();
                          return {height:a.height,top:a.top,bottom:a.bottom,viewportBottom:b.bottom,
                                  pageHeight:b.height,fullyVisible:a.top>=b.top&&a.bottom<=b.bottom+2};
                        }""")
                        print('V4.2 PC market geometry',width,geometry)
                        check(f'market observatory fits the page {width}', page.evaluate("""()=>{
                          const el=document.querySelector('.da42-page:not([hidden]) .da42-market-composition');
                          const outer=document.querySelector('.da42-page:not([hidden])');
                          if(!el||!outer)return false;
                          const a=el.getBoundingClientRect(),b=outer.getBoundingClientRect();
                          return a.top>=b.top && a.bottom<=b.bottom+2 && a.height>=150;
                        }"""))
                    if route == 'dashboard' and key == 'pilotage':
                        check(f'desktop command fills panel {width}', page.evaluate("""()=>{
                          let a=document.querySelector('.da42-command-lead').getBoundingClientRect();
                          let b=document.querySelector('.da42-command-rail').getBoundingClientRect();
                          return a.width>300 && b.width>190 && a.right<=b.left+2;
                        }"""))
                    page.locator('#toast').evaluate('e=>e.style.display="none"')
                    page.mouse.move(0, 0)
                    page.screenshot(path=str(OUT / f'pc-{route}-{key}-analyste-{width}x{height}.png'),
                                    full_page=False)
                # V4.3 cross-page controls swap panels and wrap, without changing career.
                shell.locator('[data-da43-next]').click()
                check(f'V4.3 next wraps to first {route} {width}',
                      tabs.first.get_attribute('aria-selected') == 'true')
                shell.locator('[data-da43-prev]').click()
                check(f'V4.3 previous wraps to last {route} {width}',
                      tabs.last.get_attribute('aria-selected') == 'true')
                # V4.4: auxiliary buttons are not roving-tab focus owners.
                # Their ARIA destinations follow the actual active page.
                check(f'V4.4 next destination {route} {width}',
                      shell.locator('[data-da43-next]').get_attribute('aria-controls') ==
                      tabs.first.get_attribute('aria-controls'))
                check(f'V4.4 previous destination {route} {width}',
                      shell.locator('[data-da43-prev]').get_attribute('aria-controls') ==
                      tabs.nth(-2).get_attribute('aria-controls'))
                check(f'V4.4 accessible pager labels {route} {width}',
                      shell.locator('[data-da43-next]').get_attribute('aria-label').startswith('Sous-page suivante : ') and
                      shell.locator('[data-da43-prev]').get_attribute('aria-label').startswith('Sous-page précédente : '))
                shell.locator('[data-da43-next]').focus()
                page.keyboard.press('ArrowRight')
                check(f'V4.4 auxiliary arrow leaves tab unchanged {route} {width}',
                      tabs.last.get_attribute('aria-selected') == 'true')
                check(f'V4.4 auxiliary button retains focus {route} {width}',
                      shell.locator('[data-da43-next]').evaluate('(el)=>document.activeElement===el'))
                check(f'V4.4 pager has accessible grouping {route} {width}',
                      shell.locator('.da43-page-switch').get_attribute('role') == 'group')
                check(f'V4.4 desktop hit target {route} {width}',
                      shell.locator('[data-da43-next]').evaluate("""(el)=>{
                        const r=el.getBoundingClientRect();return r.width>=44&&r.height>=44;
                      }"""))
                check(f'V4.3 arrows keep save unchanged {route} {width}',
                      page.evaluate('JSON.stringify(S)') == original and
                      page.evaluate('localStorage.getItem("bdt-v1")') == stored)
                # Keyboard navigation changes active panel without appending content.
                tabs.first.focus()
                page.keyboard.press('End')
                check(f'keyboard End {route} {width}', tabs.last.get_attribute('aria-selected') == 'true')
                page.keyboard.press('Home')
                check(f'keyboard Home {route} {width}', tabs.first.get_attribute('aria-selected') == 'true')
                check(f'no browser JS errors {route} {width}', not errors)

        # V4.3: entire suite in both themes is a desktop product requirement.
        page.set_viewport_size({'width': 1440, 'height': 900})
        page.locator('#ui01-theme').select_option('tribune')
        for route, subpages in PAGES.items():
            page.evaluate('(r)=>nav(r)', route)
            for key in subpages:
                page.locator(f'[data-da42-subpage="{key}"]').click()
                check(f'V4.3 Tribune PC no global scroll {route}/{key}',
                      page.evaluate('document.documentElement.scrollHeight<=innerHeight+2'))
                check(f'V4.3 Tribune PC native state intact {route}/{key}',
                      page.evaluate('JSON.stringify(S)') == original)
                page.screenshot(path=str(OUT / f'pc-v43-{route}-{key}-tribune-1440x900.png'),
                                full_page=False)
        page.locator('#ui01-theme').select_option('analyste')

        page.set_viewport_size({'width': 1440, 'height': 900})
        page.evaluate("nav('finance')")
        page.locator('[data-da42-subpage="tresorerie"]').click()
        expected = page.evaluate('CDArtDirection.snapshot().finance.series.length')
        check('forecast has one native point per week',
              page.locator('.da4-finance-chart circle.da4-dot').count() == expected)
        page.locator('[data-da42-subpage="flux"]').click()
        check('weekly cash variations from native model',
              page.locator('.da42-cash-week').count() == expected - 1)
        page.evaluate("nav('recruitment')")
        page.locator('[data-da42-subpage="besoins"]').click()
        check('real native position needs', page.locator('.da4-position').count() == 15)
        page.locator('.da4-recruit-stage button[data-ui03-tab="candidates"]').click()
        check('native candidate page still opens', page.locator('.cd03-candidates').is_visible())
        page.evaluate("nav('formation')")
        page.locator('[data-da42-subpage="passerelle"]').click()
        check('actual espoirs represented',
              page.locator('.da4-potential-line').count() ==
              page.evaluate('S.development.academy.length'))
        page.locator('.da4-academy-stage button[data-ui04-tab="academy"]').click()
        check('native academy tab still opens', page.locator('.cd04-player-link').count() > 0)
        page.evaluate("nav('dashboard')")
        page.locator('[data-da42-subpage="pilotage"]').click()
        page.locator('.da42-command-cta').click()
        check('command opens native tactics', page.evaluate("view==='tactics'"))
        page.evaluate("nav('dashboard')")
        page.locator('[data-da42-subpage="calendrier"]').click()
        page.locator('.da4-fixture .da4-cta').click()
        check('fixture opens native match view', page.evaluate("view==='match'"))
        check('native save export compatible',
              page.evaluate('!!parseSaveDocument(JSON.stringify(createSaveDocument()))'))
        check('no JS errors', not errors)

        # V4.5: 16 new real Chromium captures beyond the 17 workspaces.
        for width, height in ((1440, 900), (1920, 1080)):
            page.set_viewport_size({'width': width, 'height': height})
            for theme in ('analyste', 'tribune'):
                page.locator('#ui01-theme').select_option(theme)
                page.evaluate("squadTab='table';nav('team')")
                check(f'V4.5 roster panorama {width} {theme}',
                      page.locator('.da4-squad-stage').count() == 1)
                check(f'V4.5 native player list {width} {theme}',
                      page.locator('#da45-roster-table .cd02-player-link').count() ==
                      page.evaluate('club().players.length'))
                check(f'V4.5 jump targets native roster {width} {theme}',
                      page.locator('.da45-roster-jump').get_attribute('href') == '#da45-roster-table')
                check(f'V4.5 roster width {width} {theme}',
                      page.evaluate('document.documentElement.scrollWidth<=innerWidth+2'))
                page.screenshot(path=str(OUT / f'pc-v45-effectif-{theme}-{width}x{height}.png'),
                                full_page=False)
                page.locator('.cd02-player-link').first.click()
                check(f'V4.5 player native tabs {width} {theme}',
                      page.locator('.cd02-player [role=tab]').count() == 4)
                page.locator('[data-cd02-tab="profil"]').click()
                check(f'V4.5 profile native strengths {width} {theme}',
                      page.locator('.da4-profile-stage .da4-strength').count() == 3)
                page.screenshot(path=str(OUT / f'pc-v45-profil-{theme}-{width}x{height}.png'),
                                full_page=False)
                page.locator('[data-cd02-tab="contrat"]').click()
                check(f'V4.5 contract composition {width} {theme}',
                      page.locator('.da45-contract-studio .da45-contract-metric').count() == 3)
                check(f'V4.5 contract native controls {width} {theme}',
                      page.locator('.cd02-player-content .cd02-panels').count() == 1)
                check(f'V4.5 condition uses native player {width} {theme}',
                      page.evaluate("""()=>{
                        const id=document.querySelector('.cd02-player')?.dataset.cd02Player;
                        const p=CDArtDirection.snapshot().squad.find(x=>x.id===id);
                        const meter=document.querySelector('.da45-contract-track');
                        return !!p&&!!meter&&Number(meter.getAttribute('aria-valuenow'))===p.condition;
                      }"""))
                check(f'V4.5 contract width {width} {theme}',
                      page.evaluate('document.documentElement.scrollWidth<=innerWidth+2'))
                page.screenshot(path=str(OUT / f'pc-v45-contrat-{theme}-{width}x{height}.png'),
                                full_page=False)
                page.evaluate("nav('league')")
                check(f'V4.5 league composition {width} {theme}',
                      page.locator('.da45-league-summary').count() == 1)
                check(f'V4.5 league native points {width} {theme}',
                      page.evaluate("""()=>{
                        const m=CDArtDirection.snapshot();
                        const el=document.querySelector('.da45-league-summary');
                        return !!el&&m.standings.length>0&&
                          el.textContent.includes(m.standings[0].name)&&
                          el.textContent.includes(m.club.abbr);
                      }"""))
                check(f'V4.5 league width {width} {theme}',
                      page.evaluate('document.documentElement.scrollWidth<=innerWidth+2'))
                page.screenshot(path=str(OUT / f'pc-v45-classement-{theme}-{width}x{height}.png'),
                                full_page=False)
                check(f'V4.5 career unchanged {width} {theme}',
                      page.evaluate('JSON.stringify(S)') == original)
                check(f'V4.5 save unchanged {width} {theme}',
                      page.evaluate('localStorage.getItem("bdt-v1")') == stored)
        page.locator('#ui01-theme').select_option('analyste')
        success = True
        browser.close()
finally:
    server.shutdown()
    (OUT / 'report.json').write_text(json.dumps(
        {'passed': success, 'checks': checks, 'errors': errors,
         'limits': ['PC Chromium Linux; vrais écrans du jeu; pas de certification Windows ou lecteur écran.']},
        ensure_ascii=False, indent=2
    ))
print(json.dumps({'passed': success, 'checks': len(checks), 'errors': errors}))
