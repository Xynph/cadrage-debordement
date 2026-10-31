"""UI-05 — réception dans le jeu jouable via navigateur Chromium Linux."""
import functools
import http.server
import json
import os
import threading
from pathlib import Path

from playwright.sync_api import sync_playwright

BASE=Path(__file__).resolve().parents[1]
OUT=Path(os.environ.get("UI05_REPORT_DIR",str(BASE/"ui05-browser-report")))
OUT.mkdir(parents=True,exist_ok=True)
checks=[]
errors=[]
class Quiet(http.server.SimpleHTTPRequestHandler):
    def log_message(self,*_args):
        pass
def test(label,condition):
    if not condition:
        raise AssertionError(label)
    checks.append(label)

server=http.server.ThreadingHTTPServer(("127.0.0.1",0),
    functools.partial(Quiet,directory=str(BASE/"dist")))
threading.Thread(target=server.serve_forever,daemon=True).start()
url="http://127.0.0.1:%d/"%server.server_address[1]
report={"passed":False,"checks":checks,"errors":errors,
        "limitations":["Chromium Linux; pas de validation native Windows ou appareil tactile physique"]}
try:
    with sync_playwright() as browser_tool:
        browser=browser_tool.chromium.launch(headless=True)
        context=browser.new_context(viewport={"width":1440,"height":900},color_scheme="dark")
        page=context.new_page()
        page.set_default_timeout(12000)
        page.on("pageerror",lambda error:errors.append(str(error)))
        page.goto(url)
        page.get_by_role('button',name='Nouvelle carrière').click()
        page.get_by_role('button',name='Univers fictif').click()
        page.locator(".clubchoice").first.click()
        page.evaluate("nav('tactics')")
        test("panneau UI-05 dans le jeu",page.locator(".ui05-collective").is_visible())
        test("quatre préparations natives",page.locator(".ui05-collective .ui05-option").count()==4)
        test("recommandation et charge visibles",page.locator(".ui05-summary .ui05-metric").count()==3)
        test("commandes UI-01 conservées",page.locator(".ui01-session-tools").is_visible())
        first_state=page.evaluate("JSON.stringify(S)")
        first_save=page.evaluate('localStorage.getItem("bdt-v1")')
        page.evaluate("collectivePreparationCard();collectivePreparationCard();render()")
        test("lecture sans mutation carrière",page.evaluate("JSON.stringify(S)")==first_state)
        test("lecture sans sauvegarde",page.evaluate('localStorage.getItem("bdt-v1")')==first_save)
        test("aucun verrou avant entraînement",page.locator(".ui05-option:disabled").count()==0)
        test("option unique sélectionnée",page.locator('.ui05-option[aria-pressed="true"]').count()==1)
        for width in (1440,1024,768,390,320):
            page.set_viewport_size({"width":width,"height":940 if width>800 else 844})
            for theme in ("analyste","tribune"):
                page.locator("#ui01-theme").select_option(theme)
                page.evaluate("nav('tactics')")
                test("panneau %d %s visible"%(width,theme),page.locator(".ui05-collective").is_visible())
                test("panneau %d %s sans débordement global"%(width,theme),
                     page.evaluate("document.documentElement.scrollWidth<=innerWidth+2"))
                if width in (1440,390,320):
                    page.screenshot(path=str(OUT/("preparation-%d-%s.png"%(width,theme))),full_page=True)
        page.set_viewport_size({"width":1440,"height":900})
        page.locator("#ui01-theme").select_option("analyste")
        page.locator(".ui05-option").nth(1).click()
        test("choix conquête par vraie interaction",page.evaluate("S.collectiveFocus==='conquete'"))
        test("bouton conquête sélectionné",page.locator('.ui05-option[aria-pressed="true"]').count()==1)
        test("choix enregistré en carrière",page.evaluate('JSON.parse(localStorage.getItem("bdt-v1")).collectiveFocus==="conquete"'))
        test("carrière valide après choix",page.evaluate("!!parseSaveDocument(JSON.stringify(createSaveDocument()))"))
        page.evaluate("trainWeek();render()")
        test("verrou après entraînement",page.locator(".ui05-option:disabled").count()==4)
        test("charge du moteur appliquée",page.evaluate(
            "starters().filter(p=>p.fam<=3&&!p.injury).some(p=>physicalLoadValue(p)>=4)"))
        test("choix V28 conservé",page.evaluate("S.collectiveFocus==='conquete'"))
        page.evaluate("beginMatch();render()")
        test("verrou natif pendant match",page.evaluate(
            "(collectivePreparationCard().match(/ui05-option[^>]* disabled/g)||[]).length===4"))
        test("navigation vers le club protégée pendant match",page.evaluate(
            "(function(){const old=view;nav('tactics');return view===old})()"))
        test("préparation intégrée au match",page.evaluate(
            "S.live&&S.live.collectivePreparation&&S.live.collectivePreparation.focus[S.live.userSide]==='conquete'"))
        test("sauvegarde exportable avec match",page.evaluate("!!createSaveDocument()"))
        test("aucune erreur JavaScript",not errors)
        report["passed"]=True
        browser.close()
finally:
    report["passedChecks"]=len(checks)
    (OUT/"report.json").write_text(json.dumps(report,indent=2,ensure_ascii=False),encoding="utf-8")
    server.shutdown()
    print(json.dumps({"passed":report["passed"],"checks":len(checks),"errors":errors},ensure_ascii=False))
