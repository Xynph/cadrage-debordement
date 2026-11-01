"""V4 : vrais écrans, données natives, stockage navigateur isolé et captures."""
import functools, http.server, threading, json, os
from pathlib import Path
from playwright.sync_api import sync_playwright
ROOT=Path(__file__).resolve().parents[1]
OUT=Path(os.environ.get('V4_REPORT_DIR',str(ROOT/'ui01-browser-report'/'premium-v4')))
OUT.mkdir(parents=True,exist_ok=True)
class Handler(http.server.SimpleHTTPRequestHandler):
 def log_message(self,*args): pass
server=http.server.ThreadingHTTPServer(('127.0.0.1',0),functools.partial(Handler,directory=str(ROOT/'dist')))
threading.Thread(target=server.serve_forever,daemon=True).start()
checks=[];errors=[];bad=[];requests=[];success=False
def check(name,condition):
 assert condition,name
 checks.append(name)
routes=['dashboard','team','tactics','plans','staff','recruitment','match','league','history','market','formation','finance','saves','help']
try:
 with sync_playwright() as pw:
  browser=pw.chromium.launch(headless=True)
  page=browser.new_page(viewport={'width':1440,'height':1000},color_scheme='dark',reduced_motion='reduce')
  page.on('pageerror',lambda e:errors.append(str(e)))
  page.on('response',lambda r:bad.append(r.url) if r.status>=400 else None)
  page.on('request',lambda r:requests.append(r.url))
  page.goto('http://127.0.0.1:%s/'%server.server_address[1])
  check('V4 stylesheet actually loaded',page.locator('link[href="premium-v4.css"]').count()==1)
  page.locator('.cd3-nav').get_by_role('button',name='Nouvelle carrière').click()
  page.get_by_role('button',name='Univers fictif').click();page.locator('.clubchoice').first.click()
  for theme in ('analyste','tribune'):
   page.locator('#ui01-theme').select_option(theme)
   page.evaluate("nav('dashboard')")
   check('copper action '+theme,page.locator('.heading .primary').evaluate("e=>{let c=getComputedStyle(e).backgroundColor;return c!=='rgb(128, 102, 249)'&&c!=='rgb(112, 84, 232)'}"))
   for width in (1920,1440,1024,768,390,320):
    page.set_viewport_size({'width':width,'height':1000 if width>=1024 else 900})
    for route in routes:
     page.evaluate('(r)=>nav(r)',route)
     before=page.evaluate('JSON.stringify(S)');disk=page.evaluate('localStorage.getItem("bdt-v1")')
     page.evaluate('render()')
     check('read-only '+route+' '+theme+' '+str(width),page.evaluate('JSON.stringify(S)')==before and page.evaluate('localStorage.getItem("bdt-v1")')==disk)
     check('no overflow '+route+' '+theme+' '+str(width),page.evaluate('document.documentElement.scrollWidth<=innerWidth+1'))
     check('screen content '+route+' '+theme+' '+str(width),page.locator('.main').inner_text().strip()!='')
     if (width==1440 and route in ['dashboard','team','tactics','recruitment','formation','finance','match','league']) or (width==390 and route in ['dashboard','team','tactics']):
      page.locator('#toast').evaluate("e=>e.style.display='none'")
      page.screenshot(path=str(OUT/(route+'-'+theme+'-'+str(width)+'.png')),full_page=route!='dashboard')
  page.set_viewport_size({'width':1440,'height':1000});page.evaluate("nav('dashboard')")
  check('panorama actually visible in office',page.locator('.da4-fixture').evaluate("e=>getComputedStyle(e).backgroundImage.includes('premium-v4-matchday.webp')"))
  check('panorama decodes locally',page.evaluate("async()=>{let i=new Image();i.src='assets/premium-v4-matchday.webp';await i.decode();return i.naturalWidth>=1500&&i.naturalHeight>600}"))
  check('office visual columns do not overlap',page.evaluate("(()=>{const a=document.querySelector('.da4-fixture').getBoundingClientRect(),b=document.querySelector('.da4-condition').getBoundingClientRect();return a.right<=b.left&&Math.abs(a.top-b.top)<2})()"))
  # Same career and same viewport, with only the final skin disabled for comparison.
  page.locator('#ui01-theme').select_option('analyste')
  page.screenshot(path=str(OUT/'dashboard-after.png'))
  page.evaluate("document.querySelector('link[href=\"premium-v4.css\"]').disabled=true")
  page.screenshot(path=str(OUT/'dashboard-before.png'))
  page.evaluate("document.querySelector('link[href=\"premium-v4.css\"]').disabled=false")
  # Existing slot and save lifecycle is exercised through the actual menu.
  page.get_by_role('button',name='Menu principal',exact=True).first.click()
  page.locator('.cd3-nav').get_by_role('button',name='Réglages',exact=False).click()
  page.locator('#cd3-text').select_option('large')
  check('large text preference really increases menu copy',page.locator('.cd3-section-head p').evaluate('e=>parseFloat(getComputedStyle(e).fontSize)>=15'))
  page.locator('#cd3-contrast').select_option('high')
  check('high contrast preference makes panels opaque',page.locator('.cd3-feature').first.evaluate("e=>getComputedStyle(e).backgroundColor==='rgb(6, 29, 23)'&&getComputedStyle(e).borderTopColor==='rgb(225, 236, 212)'"))
  page.locator('#cd3-text').select_option('normal');page.locator('#cd3-contrast').select_option('standard')
  page.locator('.cd3-back').click()
  for width in (1440,768,390,320):
   page.set_viewport_size({'width':width,'height':1000 if width>800 else 900})
   check('five slots '+str(width),page.locator('.cd3-career').count()==5)
   check('menu no overflow '+str(width),page.evaluate('document.documentElement.scrollWidth<=innerWidth+1'))
   page.screenshot(path=str(OUT/('home-'+str(width)+'.png')),full_page=True)
   if width==1440:
    page.evaluate("document.querySelector('link[href=\"premium-v4.css\"]').disabled=true")
    page.screenshot(path=str(OUT/'home-before.png'),full_page=True)
    page.evaluate("document.querySelector('link[href=\"premium-v4.css\"]').disabled=false")
  page.get_by_role('button',name='Continuer ma carrière').click()
  disk=page.evaluate('localStorage.getItem("bdt-v1")')
  page.evaluate('beginMatch()');page.keyboard.press('Escape')
  minute=page.evaluate('S.live.minute');page.wait_for_timeout(1100)
  check('match pauses',page.evaluate('S.live.paused&&S.live.minute')==minute)
  page.get_by_role('button',name='Retour au jeu',exact=False).click()
  page.evaluate('S.live.paused=true;render()')
  contrast_js='''e=>{
   const rgb=s=>s.match(/[0-9.]+/g).map(Number),lum=a=>a.slice(0,3).map(x=>x/255).map(x=>x<=.04045?x/12.92:((x+.055)/1.055)**2.4).reduce((s,x,i)=>s+x*[.2126,.7152,.0722][i],0);
   let n=e,b;while(n){b=rgb(getComputedStyle(n).backgroundColor);if(b.length===3||b[3]>.99)break;n=n.parentElement;}
   let a=lum(rgb(getComputedStyle(e).color)),z=lum(b);return(Math.max(a,z)+.05)/(Math.min(a,z)+.05)>=4.5;
  }'''
  for selector in ('.commentary-feed .latest-event p','.auto-pause label','.full-pitch-label'):
   check('live text contrast '+selector,page.locator(selector).first.evaluate(contrast_js))
  for width in (1440,390):
   page.set_viewport_size({'width':width,'height':1000})
   page.screenshot(path=str(OUT/('live-'+str(width)+'.png')),full_page=True)
   check('live no overflow '+str(width),page.evaluate('document.documentElement.scrollWidth<=innerWidth+1'))
  check('no JS errors',not errors)
  check('all runtime resources local',all(r.startswith('http://127.0.0.1:') for r in requests))
  check('no failed HTTP assets',not bad)
  success=True;browser.close()
finally:
 server.shutdown()
 (OUT/'report.json').write_text(json.dumps({'passed':success,'checks':checks,'errors':errors,'httpErrors':bad,'limits':['Chromium Linux ; pas de certification Windows ni appareil tactile réel.']},ensure_ascii=False,indent=2))
print(json.dumps({'passed':success,'checks':len(checks),'errors':errors}))
