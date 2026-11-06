"""Chromium visual acceptance of the static, native-data E2.3 cockpit."""
import argparse
import pathlib
from playwright.sync_api import sync_playwright

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--html", default="economy-v2-e23-cockpit.html")
    p.add_argument("--out", default="economy-v2-e23-screenshots")
    args = p.parse_args()
    output = pathlib.Path(args.out)
    output.mkdir(parents=True, exist_ok=True)
    uri = pathlib.Path(args.html).resolve().as_uri()
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(headless=True)
        for width, height in ((1920, 1080), (1440, 900)):
            page = browser.new_page(viewport={"width": width, "height": height}, device_scale_factor=1)
            errors = []
            page.on("pageerror", lambda exc: errors.append(str(exc)))
            page.goto(uri)
            page.locator("#cashKpi").wait_for()
            assert page.locator("#cashKpi").inner_text().strip().endswith("€")
            assert page.locator("#debtKpi").inner_text().strip().endswith("€")
            assert page.locator("table tbody tr").count() == 15
            assert page.locator("svg polyline").count() == 2
            assert page.locator("#club option").count() == 14
            first = page.locator("#cashKpi").inner_text()
            page.locator("#club").select_option("13")
            second = page.locator("#cashKpi").inner_text()
            assert second.endswith("€") and first != second, "Changing club must refresh native values"
            assert not errors, f"Browser errors: {errors}"
            assert page.evaluate("document.documentElement.scrollWidth <= window.innerWidth"), "Horizontal overflow"
            assert page.locator("#history").is_visible(), "Charts not visible"
            file = output / f"cockpit-{width}x{height}.png"
            page.screenshot(path=str(file), full_page=True)
            print(f"COCKPIT CHROMIUM PASS {width}x{height}: 15 native seasons, 14 clubs, 2 charts, {file}")
            page.close()
        browser.close()

if __name__ == "__main__":
    main()
