"""Issue #365: real Chromium exercise of native finance screen and persisted decisions."""
import functools, http.server, json, threading
from pathlib import Path
from playwright.sync_api import sync_playwright

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'finance-v2-browser-report'
OUT.mkdir(exist_ok=True)
class Handler(http.server.SimpleHTTPRequestHandler):
    def log_message(self,*args): pass
server=http.server.ThreadingHTTPServer(('127.0.0.1',0),
    functools.partial(Handler,directory=str(ROOT/'dist')))
threading.Thread(target=server.serve_forever,daemon=True).start()
checks=[]
errors=[]
report={'passed':False,'checks':checks,'errors':errors}
def check(label,value):
    if not value: raise AssertionError(label)
    checks.append(label)
try:
    with sync_playwright() as pw:
        browser=pw.chromium.launch(headless=True)
        page=browser.new_page(viewport={'width':1920,'height':1080},color_scheme='dark')
        page.on('pageerror',lambda err:errors.append(str(err)))
        page.goto('http://127.0.0.1:%s/'%server.server_address[1])
        page.evaluate('start(0)')
        page.evaluate("nav('finance')")
        # V4.9's genuine native navigation partitions Finance into subpages.
        # New financial decisions belong to the existing "Journal et décisions"
        # subpage, which is hidden until selected (not a standalone HTML view).
        check('Finance subpage navigation present',page.locator('[data-da42-subpage="dossiers"]').count()==1)
        page.locator('[data-da42-subpage="dossiers"]').click()
        check('V2 inside real Finances tab / Journal et décisions',page.locator('.finance-v2-native').is_visible())
        check('real cash shown',page.locator('.finance-v2-native .stat').first.text_content().casefold().find('trésorerie actuelle')>=0)
        check('interactive cash chart visible',page.locator('.finv2-curve').is_visible())
        check('native transaction table visible',page.locator('.finv2-table').is_visible())
        check('accessible cash curve point hover data',page.locator('.finv2-point title').count()>0)
        page.locator('.finv2-filters').get_by_role('button',name='Recettes').click()
        check('income filter applied',page.locator('.finv2-filter[aria-pressed="true"]').inner_text()=='Recettes')
        page.locator('.finv2-filters').get_by_role('button',name='Toutes').click()
        check('all transactions restored',page.locator('.finv2-filter[aria-pressed="true"]').inner_text()=='Toutes')
        original=page.evaluate('JSON.stringify(S)')
        page.screenshot(path=str(OUT/'finance-v2-1920x1080.png'),full_page=True)
        check('dashboard read-only',page.evaluate('JSON.stringify(S)')==original)
        before=page.evaluate('club().cash')
        quote=page.evaluate('worldFacilityQuote(S.club).cost')
        page.locator('.finance-v2-native button[onclick="worldUpgradeFacility()"]').click()
        check('native facility purchase charged once',page.evaluate('club().cash')==before-quote)
        check('native facility level increased',page.evaluate('worldClub(S.club).facilities')==3)
        page.locator('.finance-v2-native button[onclick="careerSetAcademyInvestment(4000)"]').click()
        check('formation selection no premature debit',page.evaluate('club().cash')==before-quote)
        page.evaluate('trainWeek()')
        check('native academy week charged',page.evaluate('club().cash')==before-quote-4000)
        check('single paid academy week',page.evaluate('S.careerManagement.academyWeeks')==1)
        document=page.evaluate('JSON.stringify(createSaveDocument())')
        page.evaluate('start(1)')
        page.evaluate('payload=>{pendingSave=parseSaveDocument(payload);confirmSaveImport()}',document)
        check('reloaded native cash',page.evaluate('club().cash')==before-quote-4000)
        check('reloaded facility level',page.evaluate('worldClub(S.club).facilities')==3)
        check('reloaded academy plan',page.evaluate('S.careerManagement.academyInvestment')==4000)
        page.evaluate("nav('finance')")
        page.locator('[data-da42-subpage="dossiers"]').click()
        check('screen persists after load',page.locator('.finance-v2-native').is_visible())
        page.set_viewport_size({'width':1440,'height':900})
        page.screenshot(path=str(OUT/'finance-v2-1440x900.png'),full_page=True)
        check('1440 screen remains visible',page.locator('.finance-v2-native').is_visible())
        check('no Chromium JS errors',not errors)
        browser.close()
    report['passed']=True
finally:
    server.shutdown()
    (OUT/'report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf8')
    print(json.dumps(report,ensure_ascii=False))
