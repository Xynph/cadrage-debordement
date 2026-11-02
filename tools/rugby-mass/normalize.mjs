#!/usr/bin/env node
// Offline replay, no network and no mutation of the master.
import fs from 'node:fs/promises';
import {adapt} from './adapter.mjs';
const [out,...inputs]=process.argv.slice(2);
if(!out||inputs.length===0){console.error('Usage: node tools/rugby-mass/normalize.mjs NORMALIZED.json RAW1.json [RAW2.json ...]');process.exitCode=2;}
else {
  try {
    const rows=[],reports=[],seen=new Set();
    for(const input of inputs){
      const capture=JSON.parse(await fs.readFile(input,'utf8'));
      const result=adapt(capture);
      reports.push({file:input,...result.summary});
      for(const row of result.rows){
        const key=[row.sourceId??'',row.name,row.club,row.league,row.season].join('|').normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase();
        if(seen.has(key))continue;
        seen.add(key);rows.push(row);
      }
    }
    if(rows.length===0)throw Error('No verified rows: refusing empty normalized export');
    await fs.writeFile(out,JSON.stringify(rows,null,2)+'\n');
    console.log(JSON.stringify({output:out,rows:rows.length,reports},null,2));
  } catch(e){console.error(e.message);process.exitCode=1;}
}
