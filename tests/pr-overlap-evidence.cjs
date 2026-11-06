'use strict';
const assert=require('node:assert/strict');
const {assessAdditiveIndex,resolve}=require('../ci/pr-overlap-evidence.cjs');
const M='b'.repeat(40),H='a'.repeat(40),OLD='c'.repeat(40);
const path='dist/index.html';
const main='<html><body><script src="game.js"></script><script src="match3d/match3d.js"></script></body></html>';
const tag='<script src="interclub-v1.js"></script>';
const target=main.replace('<script src="match3d/',tag+'<script src="match3d/');
const common={pr:{number:336},expected:H,main:M,files:[path,'dist/interclub-v1.js'],
 mainHtml:main,candidateHtml:target,overlaps:[209,224,234].map(pr=>({pr,path,head:OLD}))};
const release=pr=>({id:pr,user:{id:350229047,login:'Xynph'},body:`CD-RELEASE-OVERLAP v1 PR=${pr} HEAD=${OLD} CANDIDATE=336 CANDIDATE_HEAD=${H} MAIN=${M} PATH=dist/index.html`});
const allowed={...common,comments:[209,224,234].map(release)};
let tested=0;
function accept(o){assert.equal(resolve(o).accepted,true);tested++;}
function deny(o){assert.equal(resolve(o).accepted,false);tested++;}
assert.deepEqual(assessAdditiveIndex(main,target,common.files),{path:'dist/interclub-v1.js',tag});tested++;
accept(allowed);
deny({...allowed,comments:allowed.comments.slice(1)});
deny({...allowed,comments:[...allowed.comments,{...release(209),id:909}]});
deny({...allowed,comments:allowed.comments.map((x,i)=>i?x:{...x,user:{id:123,login:'Xynph'}})});
deny({...allowed,comments:allowed.comments.map((x,i)=>i?x:{...x,body:x.body.replace(OLD,'d'.repeat(40))})});
deny({...allowed,comments:allowed.comments.map((x,i)=>i?x:{...x,body:x.body.replace('MAIN='+M,'MAIN='+'d'.repeat(40))})});
deny({...allowed,comments:allowed.comments.map((x,i)=>i?x:{...x,body:x.body.replace('CANDIDATE_HEAD='+H,'CANDIDATE_HEAD='+'d'.repeat(40))})});
deny({...allowed,comments:allowed.comments.map((x,i)=>i?x:{...x,body:x.body+'\nextra'})});
deny({...allowed,overlaps:[...allowed.overlaps,{pr:300,path:'dist/match3d/match3d.js',head:OLD}]});
deny({...allowed,overlaps:allowed.overlaps.map((x,i)=>i?x:{...x,head:'d'.repeat(40)})});
deny({...allowed,candidateHtml:target.replace('game.js','removed.js')});
deny({...allowed,candidateHtml:target+tag});
deny({...allowed,candidateHtml:main});
deny({...allowed,candidateHtml:main+tag});
deny({...allowed,candidateHtml:main.replace('<script src="game.js"></script>','')+tag});
deny({...allowed,candidateHtml:main.replace('<script src="match3d/',tag+'<script src="match3d/') .replace(tag,'<script src="match3d/hack.js"></script>')});
deny({...allowed,files:[path]});
deny({...allowed,expected:'short'});
deny({...allowed,comments:allowed.comments.map((x,i)=>i?x:{...x,body:x.body.replace('PR=209','PR=999')})});
assert.equal(resolve({...allowed,overlaps:[]}).accepted,true);tested++;
console.log('pr-overlap-evidence: '+tested+' cas PASS, sans droit de fusion');
