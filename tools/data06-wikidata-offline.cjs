'use strict';
const fs=require('node:fs'),path=require('node:path');
const norm=x=>String(x||'').normalize('NFKD').replace(/[\u0300-\u036f]/g,'').replace(/[^a-z0-9]/gi,'').toLowerCase();
function csv(raw){const rows=[];let row=[],cell='',quoted=false;for(let i=0;i<raw.length;i++){const c=raw[i];if(c==='"'){if(quoted&&raw[i+1]==='"'){cell+='"';i++}else quoted=!quoted}else if(c===','&&!quoted){row.push(cell);cell=''}else if((c==='\n'||c==='\r')&&!quoted){if(c==='\r'&&raw[i+1]==='\n')i++;row.push(cell);if(row.some(Boolean))rows.push(row);row=[];cell=''}else cell+=c}if(quoted)throw Error('Unclosed CSV quote');row.push(cell);if(row.some(Boolean))rows.push(row);const keys=rows.shift()||[];if(!keys.includes('player')||!keys.includes('playerLabel'))throw Error('Missing required Wikidata columns');return rows.map(r=>Object.fromEntries(keys.map((k,i)=>[k,r[i]||''])));}
function records(text,format){if(format==='csv')return csv(text);if(format==='json'){const j=JSON.parse(text);if(!Array.isArray(j.results?.bindings))throw Error('Expected SPARQL JSON bindings');return j.results.bindings.map(r=>Object.fromEntries(Object.entries(r).map(([k,v])=>[k,v.value])))}throw Error('Unsupported format')}
function match(rows,roster){
 const byName=new Map();for(const p of roster){const key=norm(p.name);if(!byName.has(key))byName.set(key,[]);byName.get(key).push(p)}
 const grouped=new Map();for(const r of rows){const qid=/\/((?:Q)\d+)$/.exec(r.player||'')?.[1];if(!qid)continue;const name=r.playerLabel||'';if(!grouped.has(qid))grouped.set(qid,{qid,name,birth:r.birth||null,height:r.height||null,weight:r.weight||null,citizenships:new Set(),clubs:new Set()});const x=grouped.get(qid);if(norm(x.name)!==norm(name))throw Error('QID label conflict '+qid);if(r.citizenship) x.citizenships.add(r.citizenship);if(r.club)x.clubs.add(r.club)}
 const matches=[],ambiguous=[],unmatched=[];const used=new Set();
 for(const x of grouped.values()){
  const candidates=byName.get(norm(x.name))||[];
  const entry={qid:x.qid,name:x.name,source:'https://www.wikidata.org/wiki/'+x.qid,birth:x.birth,height:x.height,weight:x.weight,citizenships:[...x.citizenships],clubs:[...x.clubs]};
  // Name alone is not a sufficient verified identity link: require explicit external ID mapping or human approval.
  if(candidates.length)ambiguous.push({...entry,candidates:candidates.map(p=>({id:p.id,club:p.club})),reason:'identity-not-independently-verified'});
  else unmatched.push(entry);
 }
 return {summary:{rows:rows.length,qids:grouped.size,autoMatched:matches.length,review:ambiguous.length,unmatched:unmatched.length,roster:roster.length},matches,ambiguous,unmatched};
}
function roster(root){return ['top14-a','top14-b','prod2-a','prod2-b'].flatMap(f=>JSON.parse(fs.readFileSync(path.join(root,'modding/data03',f+'.json'),'utf8')).clubs).flatMap(c=>c.players.map(p=>({...p,club:c.club})))}
if(require.main===module){const file=process.argv[2];if(!file)throw Error('Usage: node tools/data06-wikidata-offline.cjs export.csv|export.json');const root=path.resolve(__dirname,'..');const ext=path.extname(file).slice(1);const result=match(records(fs.readFileSync(file,'utf8'),ext),roster(root));console.log(JSON.stringify(result.summary,null,2));}
module.exports={norm,csv,records,match,roster};
