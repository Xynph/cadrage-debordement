"""Real Chromium snapshots for the isolated E3.3 investment evidence cockpit."""
import json
from pathlib import Path
from playwright.sync_api import sync_playwright
root=Path('economy-v2-e33-reports')
file=root/'e33-reference-827381.html'
assert file.is_file()
out=[]
with sync_playwright() as p:
    browser=p.chromium.launch(headless=True,args=['--no-sandbox'])
    for w,h in ((1920,1080),(1440,900)):
        page=browser.new_page(viewport={'width':w,'height':h},device_scale_factor=1)
        errors=[]
        page.on('pageerror',lambda e:errors.append(str(e)))
        page.goto(file.resolve().as_uri())
        page.wait_for_selector('#e33-facility')
        assert page.locator('#e33-investment').count()==1
        assert page.locator('#e33-facility').inner_text().strip()
        assert page.locator('#e33-academy').inner_text().strip()
        assert page.locator('#e33-events').inner_text().strip()
        assert page.locator('#nativeClub option').count()==14
        assert page.locator('#nativeRows tr').count()==15
        page.locator('#nativeClub').select_option(index=1)
        assert page.locator('#nativeRows tr').count()==15
        assert page.locator('#choices button').count()==3
        page.locator('#case').select_option(label='Surinvestissement facultatif')
        page.locator('#choices button').nth(2).click()
        assert page.locator('#after').inner_text().strip()=='100'
        assert page.evaluate('document.documentElement.scrollWidth <= innerWidth'), 'horizontal overflow'
        assert not errors,errors
        shot=root/f'e33-{w}x{h}.png'
        page.screenshot(path=str(shot),full_page=True)
        assert shot.stat().st_size>5000
        out.append({'viewport':[w,h],'png':str(shot),'bytes':shot.stat().st_size,
                    'nativeClubs':14,'nativeSeasons':15,'choices':3,'errors':errors,'noOverflow':True})
        page.close()
    browser.close()
(root/'e33-viewports.json').write_text(json.dumps(out,indent=2),encoding='utf8')
print('E33 CHROMIUM PASS '+json.dumps(out))
