"""PC cockpit evidence-quality Chromium screenshots on actual six-campaign artifact."""
import argparse
import pathlib
from playwright.sync_api import sync_playwright

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument('--html',default='economy-v2-e24-cockpit.html')
    ap.add_argument('--out',default='economy-v2-e24-screenshots')
    args=ap.parse_args()
    out=pathlib.Path(args.out)
    out.mkdir(parents=True,exist_ok=True)
    url=pathlib.Path(args.html).resolve().as_uri()
    with sync_playwright() as p:
        browser=p.chromium.launch(headless=True)
        for width,height in ((1920,1080),(1440,900)):
            page=browser.new_page(viewport={'width':width,'height':height},device_scale_factor=1)
            errors=[]
            page.on('pageerror',lambda error:errors.append(str(error)))
            page.goto(url)
            assert page.locator('#club option').count()==14
            assert page.locator('#rows tr').count()==15
            assert page.locator('#obligationRows tr').count()==15
            assert page.locator('#history polyline').count()==2
            assert page.locator('#payables').inner_text()=='Non disponible'
            assert page.locator('#budgetEstimate').inner_text().endswith('€')
            assert 'pas une obligation certaine' in page.locator('#provenance').inner_text()
            a=page.locator('#knownTerms').inner_text()
            cash0=page.locator('#cashKpi').inner_text()
            page.locator('#club').select_option('13')
            b=page.locator('#knownTerms').inner_text()
            cash1=page.locator('#cashKpi').inner_text()
            assert a!=b or cash0!=cash1, 'Club selector must refresh real career observations'
            assert page.locator('#payables').inner_text()=='Non disponible'
            assert not errors, errors
            assert page.evaluate('document.documentElement.scrollWidth <= window.innerWidth'), 'Horizontal overflow'
            assert page.locator('#commitments').is_visible()
            path=out/f'cockpit-e24-{width}x{height}.png'
            page.screenshot(path=str(path),full_page=True)
            print(f'E24 CHROMIUM PASS {width}x{height} : 14 clubs, 15 seasons, observed vs forecast vs unknown, {path}')
            page.close()
        browser.close()

if __name__=='__main__':
    main()
