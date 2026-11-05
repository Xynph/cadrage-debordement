"""Exercise actual Mesh2Motion importer/exporter through local Vite modules, no desktop UI."""
import json,subprocess,time,shutil,os
from pathlib import Path
from playwright.sync_api import sync_playwright

root=Path.cwd();repo=root/'rd-work/mesh2motion';out=root/'rd-report';external=[];errors=[]
# Temporary harness is written ONLY in the independent third-party working copy.
(repo/'src/rd-probe.html').write_text('<!doctype html><title>Mesh2Motion API roundtrip</title><a id="export-model-hidden-link"></a><div id="status">Local API test</div>')
shutil.copy2(root/'baseline/dist/match3d/assets/rugby-v24/lod/base_body_anim-lod2.glb',repo/'static/rd-body.glb')
log=(out/'mesh2motion-vite.log').open('w')
env={k:v for k,v in os.environ.items() if k in ['PATH','HOME','LANG','TMPDIR','NODE_EXTRA_CA_CERTS']}
server=subprocess.Popen(['npm','run','dev','--','--host','127.0.0.1','--port','5199','--strictPort'],cwd=repo,stdout=log,stderr=subprocess.STDOUT,env=env)
try:
    with sync_playwright() as p:
        browser=p.chromium.launch(args=['--no-sandbox','--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader'])
        page=browser.new_page(accept_downloads=True)
        page.on('pageerror',lambda e:errors.append(str(e)))
        def route(r):
            if r.request.url.startswith(('http://127.0.0.1:5199/','blob:','data:')):r.continue_()
            else:external.append(r.request.url);r.abort()
        page.route('**/*',route)
        for attempt in range(30):
            try:page.goto('http://127.0.0.1:5199/rd-probe.html',wait_until='domcontentloaded');break
            except Exception:
                if attempt==29:raise
                time.sleep(1)
        result=page.evaluate('''async()=>{
          const {StepLoadModel}=await import('/lib/processes/load-model/StepLoadModel.ts');
          const {StepExportToFile}=await import('/lib/processes/export-to-file/StepExportToFile.ts');

          const importer=new StepLoadModel();importer.set_preserve_skinned_mesh(true);
          await new Promise((resolve,reject)=>{
            importer.addEventListener('modelLoadedForRetargeting',resolve,{once:true});
            importer.load_model_file('/rd-body.glb','glb');setTimeout(()=>reject(Error('Import timeout')),90000);
          });
          const model=importer.get_final_retargetable_model_data();
          const rigs=[];model.traverse(n=>{if(n.isSkinnedMesh)rigs.push(n.skeleton.bones.length)});
          if(!rigs.length||rigs.some(n=>n!==53))throw Error('Canonical rig lost on import');
          function snapshot(scene){
            const meshes=[];scene.updateMatrixWorld(true);
            scene.traverse(n=>{if(!n.isSkinnedMesh)return;
              const weights=n.geometry.getAttribute('skinWeight'),joints=n.geometry.getAttribute('skinIndex');
              const values=a=>Array.from({length:a.count},(_,i)=>[a.getX(i),a.getY(i),a.getZ(i),a.getW(i)]).flat();
              meshes.push({name:n.name,vertices:weights.count,weights:values(weights),joints:values(joints),
                bones:n.skeleton.bones.map(b=>[b.name,b.parent?.isBone?b.parent.name:null]),
                inverseBind:n.skeleton.boneInverses.flatMap(m=>m.elements)});
            });return meshes.sort((a,b)=>a.name.localeCompare(b.name));
          }
          const before=snapshot(model);
          const exporter=new StepExportToFile();
          // Intercept the actual exporter's download sink, without substituting exporter logic.
          exporter.save_array_buffer=(buffer,name)=>{window.rdExport=Array.from(new Uint8Array(buffer));};
          await exporter.export_glb(model,[],'rd-roundtrip');
          const copy=new StepLoadModel();copy.set_preserve_skinned_mesh(true);
          const url=URL.createObjectURL(new Blob([new Uint8Array(window.rdExport)]));
          await new Promise((resolve,reject)=>{
            copy.addEventListener('modelLoadedForRetargeting',resolve,{once:true});
            copy.load_model_file(url,'glb');setTimeout(()=>reject(Error('Reimport timeout')),90000);
          });URL.revokeObjectURL(url);
          const after=snapshot(copy.get_final_retargetable_model_data());
          let delta=0;
          if(before.length!==after.length)throw Error('Export lost meshes');
          for(let i=0;i<before.length;i++){
            const a=before[i],b=after[i];
            if(a.name!==b.name||a.vertices!==b.vertices||JSON.stringify(a.bones)!==JSON.stringify(b.bones)||JSON.stringify(a.joints)!==JSON.stringify(b.joints))throw Error('Mesh or skeleton identity changed');
            for(const key of ['weights','inverseBind']){
              if(a[key].length!==b[key].length)throw Error(key+' size changed');
              for(let j=0;j<a[key].length;j++)delta=Math.max(delta,Math.abs(a[key][j]-b[key][j]));
            }
          }
          if(!Number.isFinite(delta)||delta>1e-5)throw Error('Weights or bind matrices changed: '+delta);
          return {rigs,bytes:window.rdExport.length,reimportVerified:true,meshes:after.length,maxWeightOrBindDelta:delta,importer:'StepLoadModel preserve_skinned_mesh',exporter:'StepExportToFile.export_glb',animations:'Not exported in this minimal API probe; retarget/fitting deferred'};
        }''')
        data=bytes(page.evaluate('window.rdExport'));(out/'copies/mesh2motion-roundtrip.glb').write_bytes(data)
        result['externalRequests']=external;result['pageErrors']=errors
        (out/'mesh2motion.json').write_text(json.dumps(result,indent=2)+'\n')
        assert not external and not errors,(external,errors)
        assert data[:4]==b'glTF'
        browser.close()
finally:server.terminate();server.wait(timeout=20);log.close()
