#!/usr/bin/env node
'use strict';
const fs=require('node:fs'),path=require('node:path'),{execFileSync}=require('node:child_process');
const {outside}=require('./install.cjs');
const source=path.resolve(__dirname,'../..');
function preview(destination){
 const dir=path.resolve(destination);outside(dir);
 const marker=path.join(dir,'rugby-preview.json');
 if(fs.existsSync(dir)&&!fs.existsSync(marker)&&fs.readdirSync(dir).length)throw Error('Le dossier existe sans marqueur Rugby Legacy : aucune modification.');
 if(fs.existsSync(marker)&&JSON.parse(fs.readFileSync(marker,'utf8')).source!==source)throw Error('Cette copie appartient à un autre checkout : choisir un autre dossier.');
 fs.mkdirSync(path.join(dir,'native'),{recursive:true});
 const project=path.join(dir,'native/godot');
 fs.writeFileSync(marker,JSON.stringify({source,project,profiles:path.join(dir,'donnees'),createdAt:new Date().toISOString()},null,2)+'\n');
 fs.cpSync(path.join(source,'native/godot'),project,{recursive:true,preserveTimestamps:true,filter:file=>!file.split(path.sep).includes('.godot')});
 // Même préparation que la CI, dirigée vers la copie : modèle CC0, atlas et portraits de base.
 // Les vérifications des registres et licences du constructeur officiel sont conservées.
 const stage='import importlib.util,sys\nfrom pathlib import Path\ns=importlib.util.spec_from_file_location("rugby_stage",sys.argv[1])\nm=importlib.util.module_from_spec(s)\ns.loader.exec_module(m)\nm.PROJECT=Path(sys.argv[2])\nm.stage(Path(sys.argv[3]))\n';
 execFileSync(process.env.CD_PYTHON|| (process.platform==='win32'?'python':'python3'),['-B','-c',stage,path.join(source,'scripts/build-godot-prototype.py'),project,process.execPath],{cwd:source,stdio:['ignore',2,2]});
 // Le pont et son autoload sont installés uniquement dans cette copie par godot_run.
 const engine=path.join(dir,'native/engine');
 if(!fs.existsSync(engine))fs.symlinkSync(path.join(source,'native/engine'),engine,process.platform==='win32'?'junction':'dir');
 else if(fs.realpathSync(engine)!==fs.realpathSync(path.join(source,'native/engine')))throw Error('La copie pointe vers un autre moteur.');
 console.log(JSON.stringify({project,profiles:path.join(dir,'donnees')}));
 return project;
}
if(require.main===module){try{if(!process.argv[2])throw Error('Usage : node tools/godot-agent/preview.cjs <dossier externe vide ou copie existante>');preview(process.argv[2]);}catch(e){console.error(e.message);process.exitCode=1;}}
module.exports={preview};
