"""Targeted contrast regression following a visual review, not a full WCAG audit."""
from pathlib import Path
from functools import partial
import http.server
import threading
import json
from playwright.sync_api import sync_playwright
root=Path(__file__).resolve().parents[1]
out=root/'ui01-browser-report';out.mkdir(exist_ok=True)
class Handler(http.server.SimpleHTTPRequestHandler):
    def log_message(self,*args): pass
server=http.server.ThreadingHTTPServer(('127.0.0.1',0),partial(Handler,directory=str(root/'dist')))
threading.Thread(target=server.serve_forever,daemon=True).start()
rows=[];result={'passed':False,'checks':rows,'scope':'four dashboard text samples; Chromium Linux'}
try:
    with sync_playwright() as p:
        b=p.chromium.launch(headless=True)
        page=b.new_page(viewport={'width':1440,'height':1000})
        page.goto('http://127.0.0.1:%s/'%server.server_address[1]);page.get_by_role('button',name='Nouvelle carrière').click();page.locator('.clubchoice').first.click()
        for width in (1440,390):
            page.set_viewport_size({'width':width,'height':1000})
            for theme in ('tribune','analyste'):
                page.locator('#ui01-theme').select_option(theme)
                for selector in ('.office-message.unread h3','.office-message p','.office-summary small','.office-decision span'):
                    ratio=page.locator(selector).first.evaluate('''el=>{
                        const rgb=s=>(s.match(/[0-9.]+/g)||[]).map(Number);
                        const fg=rgb(getComputedStyle(el).color);let n=el,bg;
                        while(n){bg=rgb(getComputedStyle(n).backgroundColor);if(bg.length===3||bg[3]>0.99)break;n=n.parentElement;}
                        const l=a=>a.slice(0,3).map(x=>x/255).map(x=>x<=0.04045?x/12.92:((x+0.055)/1.055)**2.4).reduce((s,x,i)=>s+x*[0.2126,0.7152,0.0722][i],0);
                        const a=l(fg),b=l(bg||[255,255,255]);return (Math.max(a,b)+0.05)/(Math.min(a,b)+0.05);
                    }''')
                    rows.append({'width':width,'theme':theme,'selector':selector,'ratio':ratio})
                    if ratio<4.5:
                        page.screenshot(path=str(out/'contrast-failure.png'))
                        raise AssertionError(rows[-1])
                page.screenshot(path=str(out/('contrast-%s-%s.png'%(width,theme))))
        result['passed']=True;b.close()
finally:
    (out/'contrast.json').write_text(json.dumps(result,indent=2));server.shutdown()
    print(json.dumps({'contrastPassed':result['passed'],'sampleCount':len(rows)}))
