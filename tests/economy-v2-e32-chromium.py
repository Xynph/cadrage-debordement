"""E3.2 Chromium evidence: native 14 clubs/15 seasons, segregated synthetic advisor."""
import json
from pathlib import Path
from playwright.sync_api import sync_playwright

root=Path('economy-v2-e32-reports')
target=root/'e32-reference-827381.html'
assert target.is_file()
results=[]
with sync_playwright() as p:
    browser=p.chromium.launch(headless=True,args=['--no-sandbox'])
    for w,h in ((1920,1080),(1440,900)):
        page=browser.new_page(viewport={'width':w,'height':h},device_scale_factor=1)
        failures=[]
        page.on('pageerror',lambda e:failures.append(str(e)))
        page.goto(target.resolve().as_uri())
        page.wait_for_selector('#nativeRows tr')
        assert page.locator('#nativeClub option').count()==14
        assert page.locator('#nativeRows tr').count()==15
        assert page.locator('#choices button').count()==3
        assert page.locator('#case option').count()==4
        original=page.locator('#nativeCash').inner_text()
        page.locator('#nativeClub').select_option(index=1)
        second=page.locator('#nativeCash').inner_text()
        assert original and second and original!=second
        page.locator('#case').select_option(label='Surinvestissement facultatif')
        page.locator('#choices button').nth(2).click()
        assert page.locator('#after').inner_text()=='100'
        assert page.locator('#deferred').inner_text()=='115'
        assert page.locator('#nativeRows tr').count()==15
        assert page.evaluate('document.documentElement.scrollWidth<=innerWidth'), 'horizontal overflow'
        assert not failures,failures
        image=root/f'e32-{w}x{h}.png'
        page.screenshot(path=str(image),full_page=True)
        assert image.stat().st_size>5000
        results.append({'viewport':[w,h],'file':str(image),'bytes':image.stat().st_size,
                        'nativeClubCount':14,'nativeSeasons':15,'choices':3,
                        'noHorizontalOverflow':True,'jsErrors':failures})
        page.close()
    browser.close()
(root/'e32-viewports.json').write_text(json.dumps(results,indent=2),encoding='utf8')
print('E32 CHROMIUM PASS '+json.dumps(results))
