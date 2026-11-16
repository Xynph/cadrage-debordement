#!/usr/bin/env node
'use strict';
const fs=require('node:fs'),path=require('node:path'),{execFileSync}=require('node:child_process');
const pin=require('./pin.json');
const repo=path.resolve(__dirname,'../..');
function outside(dir){const rel=path.relative(repo,dir);if(!rel||(!rel.startsWith('..'+path.sep)&&rel!=='..'&&!path.isAbsolute(rel)))throw Error('Choisir un dossier de travail hors du dépôt public.');}
function install(destination){
 const dir=path.resolve(destination);outside(dir);
 fs.mkdirSync(path.dirname(dir),{recursive:true});
 const git=(...args)=>execFileSync('git',args,{cwd:dir,encoding:'utf8'}).trim();
 const fresh=!fs.existsSync(dir)||fs.readdirSync(dir).length===0;
 if(fresh)execFileSync('git',['clone','--no-checkout',pin.repository,dir],{stdio:'inherit'});
 if(git('remote','get-url','origin')!==pin.repository)throw Error('Le dossier contient un autre dépôt : aucune modification.');
 if(!fresh&&git('status','--porcelain'))throw Error('Le pont contient des modifications locales : aucune modification.');
 execFileSync('git',['fetch','origin',pin.commit],{cwd:dir,stdio:'inherit'});
 execFileSync('git',['checkout','--detach',pin.commit],{cwd:dir,stdio:'inherit'});
 if(git('rev-parse','HEAD')!==pin.commit)throw Error('Révision du pont incorrecte.');
 const manifest=JSON.parse(fs.readFileSync(path.join(dir,'package.json'),'utf8'));
 if(manifest.license!==pin.license||manifest.version!==pin.version||!fs.existsSync(path.join(dir,'LICENSE')))throw Error('Version ou licence du pont différente du pin.');
 const npm=process.platform==='win32'?'npm.cmd':'npm';
 execFileSync(npm,['ci','--ignore-scripts','--no-audit','--no-fund'],{cwd:dir,stdio:'inherit'});
 execFileSync(npm,['run','build'],{cwd:dir,stdio:'inherit'});
 console.log(JSON.stringify({bridge:dir,commit:pin.commit,license:pin.license,version:pin.version}));
}
if(require.main===module){try{if(!process.argv[2])throw Error('Usage : node tools/godot-agent/install.cjs <dossier externe>');install(process.argv[2]);}catch(e){console.error(e.message);process.exitCode=1;}}
module.exports={install,outside};
