"""MATCH 3D 00/01 : vraie réception du jeu dans Chromium, sans CDN."""
import functools
import http.server
import json
import os
import platform
import threading
from pathlib import Path
from urllib.parse import urlsplit

from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parents[1]
REPORT = Path(os.environ.get("CD_MATCH3D_REPORT_DIR", ROOT / "match3d-browser-report"))
REPORT.mkdir(exist_ok=True)
checks = []
errors = []
external = []
pending_requests = set()
failure_diagnostics = {}

class Handler(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *_args):
        pass

def check(label, predicate):
    if not predicate:
        try:
            failure_diagnostics.update(page.evaluate("""() => ({
              renderer: CDMatch3D.diagnostics(),
              canvasConnected: !!document.querySelector('#cd3d-host canvas'),
              cameras: (window.__cameraPositions || []).slice(-8),
              rigScenes: [...(window.__rigScenes?.values() || [])]
            })"""))
        except Exception as error:
            failure_diagnostics["captureError"] = str(error)
    assert predicate, label
    checks.append(label)

def snapshot(page):
    return page.evaluate("""() => ({
        state: JSON.stringify(S),
        storage: JSON.stringify(Object.fromEntries(
          Object.keys(localStorage).filter(k => k !== 'bdt-matchday-preferences')
            .sort().map(k => [k, localStorage.getItem(k)])
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

def setting(page, key, value):
    """Cliquer les réglages visibles du match dédié, pas la barre historique masquée."""
    page.locator('[data-md-key="settings"]').click()
    page.locator('[data-md-key="%s"]' % key).select_option(value)
    page.keyboard.press("Escape")

server = http.server.ThreadingHTTPServer(
    ("127.0.0.1", 0), functools.partial(Handler, directory=str(ROOT / "dist"))
)
threading.Thread(target=server.serve_forever, daemon=True).start()
url = os.environ.get("CD_GAME_URL", "http://127.0.0.1:%d/index.html" % server.server_address[1])

try:
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(
            headless=True,
            **({"executable_path": os.environ["CD_BROWSER_EXECUTABLE"]}
               if os.environ.get("CD_BROWSER_EXECUTABLE") else {}),
            args=(json.loads(Path(os.environ["CD_BROWSER_ARGS"]).read_text())
                  if os.environ.get("CD_BROWSER_ARGS") else
                  ["--enable-webgl", "--use-gl=angle", "--use-angle=swiftshader",
                   "--enable-unsafe-swiftshader"]),
        )
        context = browser.new_context(viewport={"width": 1440, "height": 900})
        page = context.new_page()
        page.set_default_timeout(15000)
        page.on("pageerror", lambda error: errors.append(str(error)))
        page.on("request", lambda request: pending_requests.add(request.url))
        page.on("requestfinished", lambda request: pending_requests.discard(request.url))
        page.on("requestfailed", lambda request: pending_requests.discard(request.url))
        page.on("request", lambda request: external.append(request.url)
                if urlsplit(request.url)[:2] != urlsplit(url)[:2] else None)
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
        check("roulade et récupération animées sans décision rugby", page.evaluate("""() => {
          const scene={kind:'turnover',possession:0,ball:{x:50,y:35},players:[
            {id:'a',side:0,x:50,y:35,featured:true},
            {id:'b',side:1,x:53,y:36}]};
          const initial=JSON.stringify(scene),pair=CDMatch3DContact.plan(scene);
          if(!pair)return false;
          const early=CDMatch3DContact.stunt(pair,'b',120);
          const floor=CDMatch3DContact.stunt(pair,'b',430);
          const rise=CDMatch3DContact.stunt(pair,'b',680);
          const done=CDMatch3DContact.stunt(pair,'b',800);
          return floor.tuck>early.tuck && floor.shoulder>0 &&
            floor.lift>0 && rise.recovery>0 &&
            done.tuck===0 && done.lift===0 &&
            CDMatch3DContact.stunt(pair,'outsider',430).tuck===0 &&
            JSON.stringify(scene)===initial;
        }"""))
        check("effets physiques visuels 3D chargés localement", page.evaluate(
            "typeof CDMatch3DImpact === 'object' && CDMatch3DImpact.count === 20"))
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
        check("nouveau ballon de rugby 3D hors ligne", page.evaluate("""() =>
          typeof CDMatch3DBallModel === 'object' &&
          CDMatch3DBallModel.detail.laceCount === 5"""))
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
        page.evaluate("""() => {
          window.__rugbyBallCreated = false;
          window.__rigScenes = new Map();
          const oldAdd = THREE.Scene.prototype.add;
          THREE.Scene.prototype.add = function(...objects) {
            if(objects.some(o => o.userData?.renderOnlyBall))window.__rugbyBallCreated = true;
            for(const o of objects)if(o.userData?.premiumAthleteRig) {
              // Les rendus des réglages peuvent recréer une scène complète.
              const sample = window.__rigScenes.get(this) || {count:0, valid:true};
              window.__rigScenes.set(this, sample);
              sample.count++;
              const rig=o.userData.motionParts;
              if(!rig || rig.elbows?.length!==2 || rig.knees?.length!==2 ||
                 rig.arms?.length!==2 || rig.legs?.length!==2)sample.valid=false;
            }
            return oldAdd.apply(this, objects);
          };
        }""")
        setting(page, "camera", "tv")
        setting(page, "display", "3d")
        page.locator("#cd3d-host canvas").wait_for()
        page.wait_for_function("document.querySelector('#cd3d-host canvas').width > 0")
        check("canvas WebGL effectif", page.evaluate("""() => {
          const c=document.querySelector('#cd3d-host canvas');
          return !!c && c.width>0 && c.height>0 && !!c.getContext('webgl2') || !!c?.getContext('webgl');
        }"""))
        check("vue 3D sélectionnée", page.evaluate("CDMatch3D.getMode() === '3d'"))
        check("ballon procédural ajouté à la scène réelle", page.evaluate("__rugbyBallCreated"))
        check("30 rigs aptes aux transitions de contact", page.evaluate(
            "__rigScenes.size > 0 && [...__rigScenes.values()].every(s => s.count === 30 && s.valid) && typeof CDMatch3DContact.stunt === 'function'"))
        check("30 joueurs en 3D équipés du rig premium", page.evaluate(
            "__rigScenes.size > 0 && [...__rigScenes.values()].every(s => s.count === 30 && s.valid)"))
        check("course et coudes animés hors moteur", page.evaluate("""() => {
          const input=Object.freeze({x:0,y:0});
          const target=Object.freeze({x:9,y:0});
          const active=CDMatch3DMotion.pose(input,target,.5,160,3);
          const still=CDMatch3DMotion.pose(input,input,.5,160,3);
          return active.elbowFlex.length===2 &&
            active.elbowFlex.every(x=>x>=.14&&x<=.6) &&
            still.elbowFlex.every(x=>x===.14) &&
            Number.isFinite(active.hipSway) &&
            input.x===0 && input.y===0 && target.x===9;
        }"""))
        check("caméra TV active", page.evaluate("""() =>
          __cameraPositions.some(p=>p.y===48 && p.z===62)"""))
        setting(page, "camera", "tactical")
        # La fermeture des réglages recrée la scène à la prochaine image.
        page.wait_for_function("""() =>
          __cameraPositions.some(p=>p.y===115 && p.z===0.01 && p.up[2]===-1)""")
        check("caméra tactique active", page.evaluate("""() =>
          __cameraPositions.some(p=>p.y===115 && p.z===0.01 && p.up[2]===-1)"""))
        # Contrat interne historique du renderer, sans exposer cette caméra dans l'UI.
        page.evaluate("CDMatch3D.setCamera('sideline')")
        # L'historique tactique peut précéder le remontage de la scène courante.
        page.wait_for_function("""() =>
          __cameraPositions.some(p=>p.y===24 && p.z===69)""")
        check("caméra latérale activable", page.evaluate("""() =>
          __cameraPositions.some(p=>p.y===24 && p.z===69)"""))
        check("suivi de caméra latérale disponible", page.evaluate("""() => {
          const f=CDMatch3DCamera.target({x:23,z:10});
          const p=CDMatch3DCamera.sidelinePosition(f);
          return p.y===24 && p.z>=60 && p.z<=80 && Number.isFinite(p.x);
        }"""))
        setting(page, "camera", "tv")
        page.wait_for_function("""() =>
          __cameraPositions.filter(p=>p.y===48).length>=2""")
        check("retour caméra TV après latérale", page.evaluate("""() =>
          __cameraPositions.filter(p=>p.y===48).length>=2"""))
        page.evaluate("render()")
        page.locator("#cd3d-host canvas").wait_for()
        check("canvas toujours présent après nouveau rendu", page.locator("#cd3d-host canvas").count()==1)
        check("30 joueurs issus du vrai moteur", page.evaluate(
            "CDMatch3DAdapter.normalize(matchScene(S.live)).players.length === 30"))
        check("état et sauvegarde inchangés par 3D", snapshot(page) == initial)
        # Lot 20: assert the real local skinned glTF is visible before screenshots.
        page.wait_for_function(
            "CDMatch3D.diagnostics().rigged === 30 && CDMatch3D.diagnostics().asset.ready",
            timeout=15000,
        )
        check("30 humanoïdes glTF riggés réellement chargés", page.evaluate(
            "CDMatch3D.diagnostics().rigged === 30"))
        check("30 joueurs présents en 3D", page.evaluate(
            "CDMatch3D.diagnostics().players === 30"))
        # Assert that an actual AnimationMixer advances in Chromium.
        animation_before = page.evaluate("CDMatch3D.diagnostics().animationTime")
        page.wait_for_function(
            "(start) => CDMatch3D.diagnostics().animationTime > start + 0.05",
            arg=animation_before, timeout=15000)
        check("animation squelettique réellement avancée", page.evaluate(
            "(start) => CDMatch3D.diagnostics().animationTime > start + 0.05",
            animation_before))
        page.wait_for_function("CDMatch3D.diagnostics().render.fps > 0", timeout=15000)
        perf = page.evaluate("CDMatch3D.diagnostics()")
        check("v22 nouveau rig GLB actif", perf["asset"].get("realRig") is True)
        check("v23 maillots PBR procéduraux pour les deux équipes", perf["asset"].get("clothTextures") == 4)
        check("v23 matériaux PBR activés", perf["asset"].get("materials") == "MeshStandardMaterial PBR")
        check("v22 course et chute presentes", any("Man_Run" in c for c in perf["asset"].get("clips", [])) and any("Man_Death" in c for c in perf["asset"].get("clips", [])))
        check("deux tenues d'équipe générées hors ligne", perf["asset"]["kits"] == 2)
        check("géométries du kit mutualisées", perf["render"]["geometries"] <= 90)
        check("FPS logiciel Chromium au moins 10", perf["render"]["fps"] >= 10)
        check("FPS mesuré dans Chromium", perf["render"]["fps"] > 0)
        check("mémoire géométrique mesurée", perf["render"]["geometries"] > 0)
        check("textures GPU et os mutualisées sous 90", perf["render"]["textures"] <= 90)
        (REPORT / "match3d-v20-performance.json").write_text(
            json.dumps(perf, ensure_ascii=False, indent=2) + "\n")
        page.screenshot(path=str(REPORT / "match3d-chromium.png"), full_page=True)
        page.locator("#cd3d-host canvas").screenshot(path=str(REPORT / "match3d-v23-tv-players-close.png"))
        page.evaluate("CDMatch3D.setCamera('immersive')")
        check("caméra immersive disponible", page.evaluate("CDMatch3D.getMode() === '3d'"))
        page.wait_for_timeout(200)
        page.screenshot(path=str(REPORT / "match3d-immersive.png"), full_page=True)
        page.locator("#cd3d-host canvas").screenshot(path=str(REPORT / "match3d-v23-immersive-players-close.png"))
        setting(page, "camera", "tv")
        setting(page, "display", "2d")
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
                 if urlsplit(request.url)[:2] != urlsplit(url)[:2] else None)
        other.goto(url, wait_until="load")
        enter_live(other)
        before = snapshot(other)
        setting(other, "display", "3d")
        other.get_by_text("WebGL indisponible", exact=False).wait_for()
        check("message WebGL indisponible", "WebGL indisponible" in other.locator("#cd3d-host").inner_text())
        setting(other, "display", "2d")
        check("repli 2D utilisable", other.locator(".match-2d .match-field").count()==1)
        check("repli ne modifie pas le match et la sauvegarde", snapshot(other)==before)
        fallback.close()
        check("aucune requête externe", not external)
        check("aucune exception JavaScript non gérée", not errors)
        browser.close()
except Exception as error:
    (REPORT / "report.json").write_text(json.dumps({
        "passed": False, "checks": checks, "error": str(error),
        "pageErrors": errors, "pendingRequests": sorted(pending_requests),
        "diagnostics": failure_diagnostics,
    }, ensure_ascii=False, indent=2) + "\n")
    raise
finally:
    server.shutdown()

report={"passed":True,"checks":checks,"pageErrors":errors,"externalRequests":external,
        "limitations":[f"Chromium {platform.system()} ; lanceur portable non certifié",
                       "Le rendu est schématique, aucune animation de rugby réelle attestée"]}
(REPORT / "report.json").write_text(json.dumps(report,ensure_ascii=False,indent=2)+"\n")
print(json.dumps(report,ensure_ascii=False))
