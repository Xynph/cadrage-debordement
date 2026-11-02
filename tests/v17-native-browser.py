"""Réception PC V17 et import réel d'un export produit par le code V16 historique.
V17_CHROMIUM peut désigner un exécutable Chromium/Chrome local.
Aucun profil personnel ni sauvegarde utilisateur n'est utilisé.
"""
import functools, hashlib, http.server, io, json, os, subprocess, tarfile, tempfile, threading
from pathlib import Path
from playwright.sync_api import sync_playwright
ROOT = Path(__file__).resolve().parents[1]
HISTORICAL = 'dbcb0f3'
PANELS = ['overview', 'season', 'squad', 'staff', 'tactics', 'training', 'youth', 'history']
OUT = Path(os.environ.get('V17_REPORT_DIR', '/tmp/v17-native-report'))
OUT.mkdir(parents=True, exist_ok=True)
checks, failures, errors = [], [], []
report = {'passed': False, 'checks': checks, 'failures': failures, 'pageErrors': errors,
          'head': subprocess.check_output(['git','rev-parse','HEAD'], cwd=ROOT, text=True).strip(),
          'historicalCommit': subprocess.check_output(['git','rev-parse',HISTORICAL], cwd=ROOT, text=True).strip(),
          'limitations': ['Chromium Linux PC uniquement, aucun test Windows natif',
                          'Export historique généré pendant cette réception par le vrai code V16 ; pas un fichier personnel préexistant']}
class Handler(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *args): pass
def serve(directory):
    server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), functools.partial(Handler, directory=str(directory)))
    threading.Thread(target=server.serve_forever, daemon=True).start()
    return server, 'http://127.0.0.1:%d/' % server.server_port
def check(label, condition):
    (checks if condition else failures).append(label)
def state(page): return page.evaluate('JSON.stringify(S)')
def storage(page): return page.evaluate('JSON.stringify(Object.fromEntries(Object.keys(localStorage).sort().map(k=>[k,localStorage.getItem(k)])))')
def core(page):
    return page.evaluate('''()=>({club:S.club,season:S.season,round:S.round,history:S.history,lineup:S.lineup,reserves:S.reserves,
    players:S.clubs.map(c=>c.players.map(p=>({id:p.id,name:p.name,condition:p.condition,injury:p.injury,minutes:p.dev?.minutes}))),
    cash:S.clubs.map(c=>c.cash),schedule:S.schedule})''')
def office(page):
    page.evaluate("nav('dashboard')")
    page.locator('[data-da42-subpage="dossiers"]').click()
    page.locator('#v17-manager-office').scroll_into_view_if_needed()
def inspect(page, label):
    office(page)
    before, disk = state(page), storage(page)
    host = page.locator('#v17-manager-office')
    check(label+' single native mount', host.count()==1 and page.locator('.v17-office-integration').count()==1)
    check(label+' eight native sections', host.locator('[data-v17-section]').count()==8)
    check(label+' integration card does not clip office', page.locator('.v17-office-integration').evaluate('e=>e.clientHeight>=e.scrollHeight-2'))
    check(label+' real squad names', page.evaluate('''()=>[...document.querySelectorAll('[data-v17-section="squad"] tbody tr')].map(r=>r.cells[0].textContent).join('|')===club().players.map(p=>p.name).join('|')'''))
    check(label+' eight scheduled opponents', host.locator('[data-v17-section="season"] tbody tr').count()==8)
    check(label+' no invented dates', page.evaluate('CDV17Native.snapshot().fixtures.every(f=>f.date===null)'))
    # A valid native starting sheet must not be rejected by the advisory adapter.
    if label.startswith('new-'):
        check(label+' native lineup valid', page.evaluate('sheetErrors().length===0'))
    lab=host.locator('[data-v17-section="tactics"]').inner_text()
    check(label+' advisory accepts native positions', ('Poste non eligible' in lab)==page.evaluate('starters().some((p,i)=>!slotEligible(p,i))'))
    check(label+' advisory accepts native tactic', 'Tactique non reconnue' not in lab)
    for panel in PANELS:
        host.locator('[data-v17-panel="'+panel+'"]').uncheck()
        check(label+' hides '+panel,host.locator('[data-v17-section="'+panel+'"]').count()==0)
        host.locator('[data-v17-panel="'+panel+'"]').check()
        check(label+' shows '+panel,host.locator('[data-v17-section="'+panel+'"]').is_visible())
    host.locator('[data-v17-density]').click()
    check(label+' comfortable density',host.locator('.v17u.comfortable').count()==1)
    host.locator('[data-v17-density]').click()
    check(label+' compact density',host.locator('.v17u.compact').count()==1)
    check(label+' interactions preserve state',state(page)==before)
    check(label+' interactions preserve all storage',storage(page)==disk)
    page.evaluate('CDV17Native.snapshot(); CDV17Native.section()')
    check(label+' snapshot/render preserve state',state(page)==before and storage(page)==disk)
    page.locator('#toast').evaluate("e=>e.style.display='none'")
    for panel in PANELS:
        heading=host.locator('[data-v17-section="'+panel+'"] h2')
        heading.scroll_into_view_if_needed()
        check(label+' heading actually reachable '+panel, heading.evaluate('''e=>{const r=e.getBoundingClientRect();const hit=document.elementFromPoint(r.x+r.width/2,r.y+r.height/2);return !!hit&&(e===hit||e.contains(hit));}'''))
    host.locator('[data-v17-section="tactics"]').scroll_into_view_if_needed()
    page.screenshot(path=str(OUT/(label+'-tactics.png')))
    host.locator('[data-v17-panel="overview"]').scroll_into_view_if_needed()
    page.screenshot(path=str(OUT/(label+'-office.png')))
    check(label+' no document overflow',page.evaluate('document.documentElement.scrollWidth<=innerWidth+1'))
try:
    with tempfile.TemporaryDirectory(prefix='v17-historical-') as directory:
        archive = subprocess.check_output(['git','archive',HISTORICAL,'dist'],cwd=ROOT)
        with tarfile.open(fileobj=io.BytesIO(archive)) as tar: tar.extractall(directory,filter='data')
        historical, old_url = serve(Path(directory)/'dist')
        current, url = serve(ROOT/'dist')
        try:
            with sync_playwright() as pw:
                options={'headless':True}
                if os.environ.get('V17_CHROMIUM'):
                    options.update(executable_path=os.environ['V17_CHROMIUM'], args=['--no-sandbox','--no-zygote','--single-process'])
                browser=pw.chromium.launch(**options)
                report['browser']=browser.version
                # Separate origins and contexts; native V16 start, one played round, native export.
                old_context=browser.new_context(viewport={'width':1440,'height':900})
                old=old_context.new_page(); old.on('pageerror',lambda e:errors.append('V16: '+str(e)))
                old.goto(old_url);old.locator('.clubchoice').first.click()
                old.evaluate('finishRound()')
                historical_core=core(old)
                check('historical career actually progressed',old.evaluate('S.round===1 && S.history.length>0'))
                legacy=old.evaluate('JSON.stringify(createSaveDocument())')
                legacy_path=OUT/'v16-export.json'; legacy_path.write_text(legacy)
                report['historicalExportSha256']=hashlib.sha256(legacy.encode()).hexdigest()
                old_context.close();browser.close()
                browser=pw.chromium.launch(**options)
                context=browser.new_context(viewport={'width':1440,'height':900},reduced_motion='reduce')
                page=context.new_page();page.on('pageerror',lambda e:errors.append('V17: '+str(e)))
                page.goto(url);page.locator('.cd3-nav').get_by_role('button',name='Nouvelle carrière').click()
                page.get_by_role('button',name='Univers fictif').click();page.locator('.clubchoice').first.click()
                for theme in ('analyste','tribune'):
                    page.locator('#ui01-theme').select_option(theme)
                    for width,height in ((1440,900),(1920,1080)):
                        page.set_viewport_size({'width':width,'height':height})
                        inspect(page,'new-'+theme+'-'+str(width))
                original, disk=state(page),storage(page)
                page.locator('#save-import').set_input_files(str(legacy_path))
                page.get_by_role('dialog',name='Vérifier la sauvegarde').wait_for()
                check('legacy import preview preserves state and storage',state(page)==original and storage(page)==disk)
                page.get_by_role('button',name='Annuler',exact=True).click()
                check('legacy import cancellation preserves state and storage',state(page)==original and storage(page)==disk)
                page.locator('#save-import').set_input_files(str(legacy_path))
                page.get_by_role('button',name='Remplacer et reprendre la carrière').click()
                check('legacy import restored original sporting/financial values',core(page)==historical_core)
                check('legacy source file unchanged',legacy_path.read_text()==legacy)
                check('legacy current career backup preserved',page.evaluate('JSON.stringify(backupDocument().state)')==original)
                check('legacy export valid',page.evaluate('!!parseSaveDocument(JSON.stringify(createSaveDocument()))'))
                for width,height in ((1440,900),(1920,1080)):
                    page.set_viewport_size({'width':width,'height':height})
                    inspect(page,'legacy-'+str(width))
                restored_core=core(page)
                page.reload()
                check('legacy reload retains restored sporting/financial values',core(page)==restored_core)
                check('no browser exceptions',not errors)
                context.close();browser.close()
        finally:
            historical.shutdown();current.shutdown()
    report['passed']=not failures and not errors
finally:
    (OUT/'report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2))
    print(json.dumps(report,ensure_ascii=False))
assert report['passed'],failures or errors
