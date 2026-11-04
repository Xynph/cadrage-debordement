"""MATCH 3D 00/01 : vraie réception du jeu dans Chromium, sans CDN."""
import functools
import http.server
import json
import threading
from pathlib import Path

from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parents[1]
REPORT = ROOT / "match3d-browser-report"
REPORT.mkdir(exist_ok=True)
checks = []
errors = []
external = []

class Handler(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *_args):
        pass

def check(label, predicate):
    assert predicate, label
    checks.append(label)

def snapshot(page):
    return page.evaluate("""() => ({
        state: JSON.stringify(S),
        storage: JSON.stringify(Object.fromEntries(
          Object.keys(localStorage).sort().map(k => [k, localStorage.getItem(k)])
        )),
        save: JSON.stringify((({exportedAt, ...stable}) => stable)(createSaveDocument()))
    })""")

def enter_live(page):
    page.evaluate("start(0, 'fiction')")
    page.evaluate("beginMatch()")
    page.evaluate("""() => {
      if (typeof timer !== 'undefined') clearInterval(timer);
      if (typeof pauseMatch === 'function' && !S.live.paused) pauseMatch();
      render();
    }""")
    check("match réel démarré", page.evaluate("!!S.live && !!S.live.sheets"))
    page.locator(".cd3d-panel").wait_for()
    check("vue 2D activée par défaut", page.evaluate("CDMatch3D.getMode() === '2d'"))
    check("terrain 2D visible", page.locator(".match-2d .match-field").count() == 1)

server = http.server.ThreadingHTTPServer(
    ("127.0.0.1", 0), functools.partial(Handler, directory=str(ROOT / "dist"))
)
threading.Thread(target=server.serve_forever, daemon=True).start()
url = "http://127.0.0.1:%d/index.html" % server.server_address[1]

try:
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(
            headless=True,
            args=["--enable-webgl", "--use-gl=angle", "--use-angle=swiftshader",
                  "--enable-unsafe-swiftshader"],
        )
        context = browser.new_context(viewport={"width": 1440, "height": 900})
        page = context.new_page()
        page.set_default_timeout(15000)
        page.on("pageerror", lambda error: errors.append(str(error)))
        page.on("request", lambda request: external.append(request.url)
                if not request.url.startswith(url.split("/index.html")[0] + "/") else None)
        page.goto(url, wait_until="load")
        page.wait_for_function("typeof CDMatch3D !== 'undefined' && typeof THREE !== 'undefined'")
        enter_live(page)
        check("module de contact 3D chargé hors ligne", page.evaluate(
            "typeof CDMatch3DContact === 'object'"))
        check("contact, chute et récupération bornés dans Chromium", page.evaluate("""() => {
          const input={kind:'turnover',possession:0,ball:{x:50,y:35},
            players:[{id:'a',side:0,x:50,y:35,featured:true},
                     {id:'b',side:1,x:53,y:36}]};
          const before=JSON.stringify(input),pair=CDMatch3DContact.plan(input);
          if(!pair)return false;
          const impact=CDMatch3DContact.pose(pair,'b',440);
          const recovered=CDMatch3DContact.pose(pair,'b',800);
          return impact.fall>0 && impact.fall<=1.1 &&
            recovered.fall===0 && JSON.stringify(input)===before;
        }"""))
        check("effets physiques visuels 3D chargés localement", page.evaluate(
            "typeof CDMatch3DImpact === 'object' && CDMatch3DImpact.count === 12"))
        check("impact visuel déterministe sans mutation du moteur", page.evaluate("""() => {
          const participants=new Map([
            ['a',{position:{x:4,z:8}}],
            ['b',{position:{x:6,z:10}}]
          ]);
          const source=JSON.stringify([...participants]);
          const fx=CDMatch3DImpact.active({lead:'a',other:'b'},430,participants);
          return fx.x===5 && fx.z===9 && fx.t===.5 &&
            CDMatch3DImpact.active(null,430,participants)===null &&
            JSON.stringify([...participants])===source;
        }"""))
        initial = snapshot(page)

        # Instrumenter le changement de caméra sans modifier le code du jeu.
        page.evaluate("""() => {
          window.__cameraPositions = [];
          const original = THREE.PerspectiveCamera.prototype.lookAt;
          THREE.PerspectiveCamera.prototype.lookAt = function(...args) {
            window.__cameraPositions.push({
              x:this.position.x, y:this.position.y, z:this.position.z,
              up:[this.up.x,this.up.y,this.up.z]
            });
            return original.apply(this,args);
          };
        }""")
        page.locator(".cd3d-panel button").filter(has_text="3D").click()
        page.locator("#cd3d-host canvas").wait_for()
        page.wait_for_function("document.querySelector('#cd3d-host canvas').width > 0")
        check("canvas WebGL effectif", page.evaluate("""() => {
          const c=document.querySelector('#cd3d-host canvas');
          return !!c && c.width>0 && c.height>0 && !!c.getContext('webgl2') || !!c?.getContext('webgl');
        }"""))
        check("vue 3D sélectionnée", page.evaluate("CDMatch3D.getMode() === '3d'"))
        check("caméra TV active", page.evaluate("""() =>
          __cameraPositions.some(p=>p.y===68 && p.z===85)"""))
        page.locator(".cd3d-panel button").filter(has_text="Tactique").click()
        check("caméra tactique active", page.evaluate("""() =>
          __cameraPositions.some(p=>p.y===115 && p.z===0.01 && p.up[2]===-1)"""))
        page.evaluate("render()")
        page.locator("#cd3d-host canvas").wait_for()
        check("canvas toujours présent après nouveau rendu", page.locator("#cd3d-host canvas").count()==1)
        check("30 joueurs issus du vrai moteur", page.evaluate(
            "CDMatch3DAdapter.normalize(matchScene(S.live)).players.length === 30"))
        check("état et sauvegarde inchangés par 3D", snapshot(page) == initial)
        page.screenshot(path=str(REPORT / "match3d-chromium.png"), full_page=True)
        page.locator(".cd3d-panel button").filter(has_text="2D").click()
        check("retour 2D avec terrain", page.locator(".match-2d .match-field").count()==1)
        check("canvas 3D supprimé", page.locator("#cd3d-host canvas").count()==0)
        check("aucune mutation par aller-retour", snapshot(page)==initial)
        check("sauvegarde exportable et lisible", page.evaluate(
            "!!parseSaveDocument(JSON.stringify(createSaveDocument()))"))
        context.close()

        # Bloquer les contextes WebGL *avant* le chargement des scripts du jeu.
        fallback = browser.new_context(viewport={"width":1280,"height":800})
        fallback.add_init_script("""(() => {
          const get = HTMLCanvasElement.prototype.getContext;
          HTMLCanvasElement.prototype.getContext = function(type, ...args) {
            if (/^(webgl|experimental-webgl|webgl2)$/.test(type)) return null;
            return get.call(this, type, ...args);
          };
        })();""")
        other = fallback.new_page()
        other.on("request", lambda request: external.append(request.url)
                 if not request.url.startswith(url.split("/index.html")[0] + "/") else None)
        other.goto(url, wait_until="load")
        enter_live(other)
        before = snapshot(other)
        other.locator(".cd3d-panel button").filter(has_text="3D").click()
        other.get_by_text("WebGL indisponible", exact=False).wait_for()
        check("message WebGL indisponible", "WebGL indisponible" in other.locator("#cd3d-host").inner_text())
        other.locator(".cd3d-panel button").filter(has_text="2D").click()
        check("repli 2D utilisable", other.locator(".match-2d .match-field").count()==1)
        check("repli ne modifie pas le match et la sauvegarde", snapshot(other)==before)
        fallback.close()
        check("aucune requête externe", not external)
        check("aucune exception JavaScript non gérée", not errors)
        browser.close()
finally:
    server.shutdown()

report={"passed":True,"checks":checks,"pageErrors":errors,"externalRequests":external,
        "limitations":["Chromium Linux; pas une validation Windows native",
                       "Le rendu est schématique, aucune animation de rugby réelle attestée"]}
(REPORT / "report.json").write_text(json.dumps(report,ensure_ascii=False,indent=2)+"\n")
print(json.dumps(report,ensure_ascii=False))
