"""Chromium-only evidence for E3.1 isolated advisory HTML. No game integration."""
import json
from pathlib import Path
from playwright.sync_api import sync_playwright

ROOT = Path("economy-v2-e31-reports")
PAGE = ROOT / "e31-reference-827381.html"
assert PAGE.is_file(), "Native report missing"
with sync_playwright() as p:
    browser = p.chromium.launch(headless=True, args=["--no-sandbox"])
    results = []
    for width, height in ((1920, 1080), (1440, 900)):
        page = browser.new_page(viewport={"width": width, "height": height}, device_scale_factor=1)
        errors = []
        page.on("pageerror", lambda e: errors.append(str(e)))
        page.goto(PAGE.resolve().as_uri())
        page.wait_for_selector('#choices button')
        assert page.locator('#choices button').count() == 3
        assert page.locator('#case option').count() == 4
        assert page.locator('#chart .bar').count() == 6
        assert page.locator('#after').inner_text().strip()
        page.locator('#case').select_option(label='Surinvestissement facultatif')
        page.locator('#choices button').nth(2).click()
        assert page.locator('#after').inner_text().strip() == '100'
        assert page.locator('#deferred').inner_text().strip() == '115'
        assert page.locator('#choices button').nth(2).get_attribute('aria-pressed') == 'true'
        assert page.evaluate("document.documentElement.scrollWidth <= innerWidth"), "Horizontal overflow"
        screenshot = ROOT / f"e31-{width}x{height}.png"
        page.screenshot(path=str(screenshot), full_page=True)
        assert screenshot.stat().st_size > 5000
        assert not errors, str(errors)
        results.append({"viewport": [width, height], "screenshot": str(screenshot),
                        "size_bytes": screenshot.stat().st_size, "browser_errors": errors,
                        "options": 3, "cases": 4, "selected_after": 100})
        page.close()
    browser.close()
(ROOT / "e31-viewports.json").write_text(json.dumps(results, indent=2), encoding="utf-8")
print("E31 CHROMIUM PASS", json.dumps(results))
