"""Menu V3 acceptance on isolated browser storage. No personal career or network data."""
import functools, http.server, threading, json, os
from pathlib import Path
from playwright.sync_api import sync_playwright
ROOT=Path(__file__).resolve().parents[1]
OUT=Path(os.environ.get('MENU_V3_REPORT_DIR',str(ROOT/'ui01-browser-report'/'menu-v3')))
OUT.mkdir(parents=True,exist_ok=True)
class Handler(http.server.SimpleHTTPRequestHandler):
 def log_message(self,*args): pass
server=http.server.ThreadingHTTPServer(('127.0.0.1',0),functools.partial(Handler,directory=str(ROOT/'dist')))
threading.Thread(target=server.serve_forever,daemon=True).start()
checks=[];errors=[];requests=[];success=False
def check(name,condition):
 assert condition,name
 checks.append(name)
try:
 with sync_playwright() as p:
  browser=p.chromium.launch(headless=True)
  ctx=browser.new_context(viewport={'width':1440,'height':1000},reduced_motion='reduce')
  page=ctx.new_page();page.set_default_timeout(10000);page.on('pageerror',lambda e:errors.append(str(e)));page.on('request',lambda r:requests.append(r.url))
  page.goto('http://127.0.0.1:%s/'%server.server_address[1])
  check('five empty slots',page.locator('.cd3-career').count()==5)
  check('desktop has actual three-column composition',page.evaluate("getComputedStyle(document.querySelector('.cd3-layout')).gridTemplateColumns.split(' ').length===3"))
  check('right cinema promo visible',page.locator('.cd3-promo').is_visible())
  check('new photo stadium actually used by backdrop',page.evaluate("getComputedStyle(document.querySelector('.cd3-backdrop')).backgroundImage.includes('menu-stadium-cinematic.png')"))
  check('original photo assets fetch without errors',page.evaluate("async()=>{const paths=['assets/menu-stadium-cinematic.png','assets/menu-rugby-ball-photoreal.png'];const results=await Promise.all(paths.map(p=>fetch(p)));return results.every(r=>r.ok&&r.headers.get('content-type')?.includes('image/png'))}"))
  check('muddy ball on lower-right layer',page.evaluate("(()=>{const e=document.querySelector('.cd3-right-bottom');const s=getComputedStyle(e);return s.backgroundImage.includes('menu-rugby-ball-photoreal.png')&&s.pointerEvents==='none'&&e.getBoundingClientRect().height>=170})()"))
  check('five cards form a vertical column',page.evaluate("(()=>{const c=[...document.querySelectorAll('.cd3-career')].map(x=>x.getBoundingClientRect());return c.every((v,i)=>i===0||(v.y>c[i-1].y&&Math.abs(v.x-c[0].x)<3))})()"))
  check('continue disabled without save',page.get_by_role('button',name='Continuer ma carrière').is_disabled())
  check('reduced motion respected',page.locator('.cd3-content').evaluate('e=>getComputedStyle(e).animationName')=='none')
  page.keyboard.press('Tab');check('skip link focus',page.locator('.cd3-skip').evaluate('e=>e===document.activeElement'))
  page.keyboard.press('Enter');check('skip targets content',page.locator('#cd3-content').evaluate('e=>e===document.activeElement'))
  page.locator('.cd3-nav').get_by_role('button',name='Nouvelle carrière').click();page.get_by_role('button',name='Univers fictif').click()
  page.locator('#menu-difficulty').select_option('expert');page.locator('.clubchoice').first.click()
  check('difficulty saved before initial slot',page.evaluate("S.difficulty==='expert'&&CDMenuSlots.restore(CDMenuSlots.list().active).difficulty==='expert'"))
  page.get_by_role('button',name='Menu principal',exact=True).first.click()
  saved=page.evaluate('localStorage.getItem("bdt-v1")')
  for w in (1440,768,390):
   page.set_viewport_size({'width':w,'height':1000 if w==1440 else 900})
   page.locator('#toast').evaluate("e=>e.style.display='none'");page.screenshot(path=str(OUT/('menu-%s.png'%w)),full_page=True)
   check('no horizontal overflow '+str(w),page.evaluate('document.documentElement.scrollWidth<=innerWidth'))
   check('five cards visible '+str(w),page.locator('.cd3-career').count()==5)
   check('cinematic three-zone responsive composition '+str(w),page.locator('.cd3-sidebar').is_visible() and page.locator('.cd3-right').is_visible() and page.locator('.cd3-cards').is_visible())
   check('rugby ball visible and nonblocking '+str(w),page.evaluate("(()=>{const e=document.querySelector('.cd3-right-bottom');const r=e.getBoundingClientRect();const s=getComputedStyle(e);return r.width>0&&r.height>=90&&s.backgroundImage.includes('menu-rugby-ball-photoreal.png')&&s.pointerEvents==='none'})()"))
  page.get_by_role('button',name='Réglages',exact=False).click();page.locator('#cd3-contrast').select_option('high');page.locator('#cd3-text').focus();page.locator('#cd3-text').select_option('large')
  check('preference retains focus',page.locator('#cd3-text').evaluate('e=>e===document.activeElement'))
  check('settings preserve canonical save',page.evaluate('localStorage.getItem("bdt-v1")')==saved)
  page.locator('#main-menu-theme').select_option('analyste');page.locator('#main-menu-motion').select_option('reduced')
  check('theme applied',page.locator('html').get_attribute('data-cd-theme')=='analyste')
  page.screenshot(path=str(OUT/'settings-390.png'),full_page=True)
  page.keyboard.press('Escape');page.locator('.cd3-resume').first.click()
  check('restore requires review',page.get_by_role('dialog').is_visible())
  page.keyboard.press('Shift+Tab');check('dialog focus trapped',page.get_by_role('dialog').evaluate('e=>e.contains(document.activeElement)'))
  page.keyboard.press('Escape');check('cancel preserves save',page.evaluate('localStorage.getItem("bdt-v1")')==saved);check('cancel restores card focus',page.locator('.cd3-resume').first.evaluate('e=>e===document.activeElement'))
  page.locator('.cd3-delete').first.click();page.get_by_role('button',name='Annuler',exact=True).click();check('delete cancellation restores focus',page.locator('.cd3-delete').first.evaluate('e=>e===document.activeElement'))
  page.locator('.cd3-resume').first.click();page.get_by_role('button',name='Restaurer cette copie',exact=True).click()
  check('career restored',page.evaluate("entryScreen==='game'&&S.club===0"))
  page.get_by_role('button',name='Menu principal',exact=True).first.click()
  export=page.evaluate('JSON.stringify(createSaveDocument())')
  with page.expect_file_chooser() as fc:
   page.get_by_role('button',name='Importer une carrière JSON',exact=False).click()
  fc.value.set_files({'name':'test-career.json','mimeType':'application/json','buffer':export.encode()})
  page.get_by_role('dialog').wait_for();page.get_by_role('button',name='Annuler',exact=True).click();check('JSON picker previews without replacement',page.evaluate('S.club')==0);check('cancel button restores import focus',page.get_by_role('button',name='Importer une carrière JSON',exact=False).evaluate('e=>e===document.activeElement'))
  page.locator('.cd3-nav').get_by_role('button',name='Nouvelle carrière').click();page.get_by_role('button',name='Univers fictif').click();page.get_by_role('button',name='Conserver et continuer').click();page.locator('.clubchoice').nth(1).click()
  check('second career preserves first',page.evaluate('CDMenuSlots.list().items.length===2&&CDMenuSlots.restore(CDMenuSlots.list().items[0].id).club===0'))
  page.evaluate('beginMatch()');page.keyboard.press('Escape');minute=page.evaluate('S.live.minute');page.wait_for_timeout(1100)
  check('pause freezes clock',page.evaluate('S.live.paused&&S.live.minute')==minute)
  page.get_by_role('button',name='Menu principal',exact=True).click();check('match retained paused',page.evaluate('S.live.paused'))
  page.get_by_role('button',name='Continuer ma carrière').click();check('continue preserves paused match',page.evaluate('S.live.paused'))
  page.reload();check('reload opens menu',page.locator('.cd3-menu').is_visible());check('preferences retained',page.locator('html').get_attribute('data-menu-text')=='large')
  check('no external runtime assets',all(r.startswith('http://127.0.0.1:') for r in requests))
  check('no JS errors',not errors)
  success=True
  browser.close()
finally:
 server.shutdown();(OUT/'report.json').write_text(json.dumps({'checks':checks,'pageErrors':errors,'passed':success and not errors},ensure_ascii=False,indent=2))
print(json.dumps({'passed':True,'checks':len(checks),'errors':errors}))
