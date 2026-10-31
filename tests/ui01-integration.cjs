'use strict';
const assert=require('node:assert/strict');
const fs=require('node:fs'),vm=require('node:vm'),path=require('node:path');
const {context}=require('./harness.cjs');
const root=path.join(__dirname,'..');
const script=fs.readFileSync(path.join(root,'dist/ui-preferences.js'),'utf8');
const css=fs.readFileSync(path.join(root,'dist/style.css'),'utf8')+fs.readFileSync(path.join(root,'dist/ui01-integration.css'),'utf8');
const checks=[];
function check(name,fn){fn();checks.push(name);console.log('PASS '+name);}
function game(saved,options={}){
 const g=context(saved);const attrs={};let dark=true,onChange;
 g.ctx.document.documentElement={setAttribute:(k,v)=>attrs[k]=v};
 g.ctx.window.matchMedia=()=>({get matches(){return dark},addEventListener(type,fn){onChange=fn}});
 if(options.blockRead)g.ctx.localStorage.getItem=()=>{throw Error('Preference blocked')};
 if(options.blockWrite)g.ctx.localStorage.setItem=()=>{throw Error('Quota exceeded')};
 vm.runInContext(script,g.ctx);
 return Object.assign(g,{attrs,os(value){dark=value;onChange();}});
}
const g=game();g.run('start(0)');
check('system theme follows OS and forced choice stays fixed',()=>{
 assert.equal(g.attrs['data-cd-theme'],'analyste');g.os(false);assert.equal(g.attrs['data-cd-theme'],'tribune');
 g.run('ui01SetTheme("analyste")');g.os(false);assert.equal(g.attrs['data-cd-theme'],'analyste');
 assert.equal(g.run('ui01SetTheme("untrusted")'),false);
});
check('new career remains reachable outside hidden sidebar',()=>{
 assert.match(g.run('ui01Navigation("dashboard",S,1)'),/onclick="resetDialog\(\)"/);
});
check('storage location and save action survive the redesign',()=>{
 const h=g.run('ui01SessionTools()');assert.match(h,/storage/);assert.match(h,/nav\('saves'\)/);
 assert.ok(h.includes(g.run('storageLocationText()')));
});
check('offline quit calls the existing bridge only in offline mode',()=>{
 assert.ok(!g.run('ui01SessionTools()').includes('CDOfflineAction'));
 g.run('gameStorage.offline=true');assert.match(g.run('ui01SessionTools()'),/CDOfflineAction\('quit'\)/);
 g.run('delete gameStorage.offline');
});
check('save failure is an alert outside the mobile-hidden season strip',()=>{
 g.run('lastSaveError=true');const h=g.run('ui01Navigation("dashboard",S,1)');
 assert.match(h,/ui01-session-tools[\s\S]*role="alert"/);
 assert.ok(!h.match(/<div class="ui01-season">([\s\S]*?)<\/div>/)[1].includes('role="alert"'));
 g.run('lastSaveError=false');
});
check('theme changes do not write or alter a career',()=>{
 const state=g.run('JSON.stringify(S)'),saved=g.store['bdt-v1'];
 for(const theme of ['tribune','analyste','system'])g.run(`ui01SetTheme(${JSON.stringify(theme)})`);
 assert.equal(g.run('JSON.stringify(S)'),state);assert.equal(g.store['bdt-v1'],saved);
});
check('14 destinations are retained and render without state corruption',()=>{
 const routes=['dashboard','team','tactics','plans','staff','recruitment','match','league','history','market','formation','finance','saves','help'];
 for(const route of routes){
  assert.equal(g.run(`UI01_GROUPS.some(x=>x.routes.includes(${JSON.stringify(route)}))`),true);
  g.run(`nav(${JSON.stringify(route)})`);assert.equal(g.run('view'),route);assert.ok(g.app.innerHTML.includes('ui01-appbar'));
  assert.equal(g.run('!!parseSaveDocument(JSON.stringify(createSaveDocument()))'),true);
 }
});
check('all four squad tabs preserve the 23-player sheet',()=>{
 for(const tab of ['table','sheet','depth','planning'])g.run(`squadTab=${JSON.stringify(tab)};nav('team')`);
 assert.equal(g.run('S.lineup.length'),15);assert.equal(g.run('S.reserves.length'),8);
});
check('current club and malicious labels are escaped',()=>{
 const h=g.run('ui01Navigation("dashboard",{clubs:[{abbr:"<b>bad</b>"}],club:0,season:1},1)');
 assert.ok(h.includes('&lt;b&gt;bad&lt;/b&gt;'));assert.ok(!h.includes('<b>bad</b>'));
});
check('blocked preference reads/writes remain non-blocking',()=>{
 const denied=game(undefined,{blockRead:true,blockWrite:true});
 assert.equal(denied.run('ui01Pref'),'system');assert.equal(denied.run('ui01SetTheme("analyste")'),true);
});
check('confirmation stays a native cancelable dialog',()=>{
 const before=g.run('JSON.stringify(S)');g.run('resetDialog()');assert.match(g.app.innerHTML,/aria-modal="true"/);
 g.run('closeModal()');assert.equal(g.run('JSON.stringify(S)'),before);
});
check('CSS places confirmation above sticky navigation',()=>{
 assert.match(css,/html\[data-cd-theme\] \.modalback\{z-index:200/);
 assert.ok(css.lastIndexOf('html[data-cd-theme] .modalback')>css.indexOf('.ui01-appbar{'));
});
check('dark welcome cards and controls have explicit surfaces',()=>{
 assert.ok(css.includes('.welcome .clubchoice{background:var(--ui01-surface)'));
 assert.ok(css.includes('.modal button:not(.primary)'));
});
check('live cockpit keeps existing controls and save compatibility',()=>{
 g.run('nav("match");beginMatch();pauseMatch();render()');assert.ok(g.app.innerHTML.includes('v40-cockpit'));
 assert.ok(!g.app.innerHTML.includes('ui01-appbar'));assert.equal(g.run('!!parseSaveDocument(JSON.stringify(createSaveDocument()))'),true);
});
check('old career opens without enabling mobility implicitly',()=>{
 const state=JSON.parse(g.run('JSON.stringify(S)'));state.live=null;delete state.managerMobilityVersion;delete state.managerMobility;
 const old=game(state);assert.equal(old.run('managerMobilityActive()'),false);old.run('render()');
 assert.equal(old.run('!!parseSaveDocument(JSON.stringify(createSaveDocument()))'),true);
});
console.log('UI01 INTEGRATION PASS '+JSON.stringify({passed:checks.length,checks,scope:'native harness and source contracts; browser checks are separate'}));
