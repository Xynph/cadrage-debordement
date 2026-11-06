import fs from 'node:fs/promises';
const normalized = value => String(value || '').normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase().replace(/[^a-z0-9]/g,'');
export function reconcile(master, rows, season='2025-2026') {
  if (!Array.isArray(master.players) || !Array.isArray(rows)) throw Error('Invalid input');
  const byName = new Map();
  for (const p of master.players) {
    const key=normalized(p.realName);
    byName.set(key,[...(byName.get(key)||[]),p]);
  }
  const accepted=[],rejected=[],changes=[],seen=new Set();
  for (const row of rows) {
    const match=byName.get(normalized(row.name))||[];
    const p=match.length===1?match[0]:null;
    let issue=!p?'ambiguous-name':null;
    if(!issue&&row.season!==season) issue='season';
    if(!issue&&(!row.sourceUrl||!row.sourceUrl.startsWith('https://')))issue='source';
    if(!issue&&row.club!==p.club)issue='club-or-transfer';
    if(!issue&&row.league!==p.league)issue='league-or-transfer';
    if(!issue&&seen.has(p.id))issue='duplicate';
    const data={competition:row.league,season,matches:null,minutes:null,tries:null,points:null};
    for(const k of ['matches','minutes','tries','points']) {
      const val=row[k];
      if(val!==null&&val!==undefined&&val!=='') {
        if(!Number.isInteger(val)||val<0)issue='invalid-'+k;
        else data[k]=val;
      }
    }
    if(!issue&&Object.values(data).slice(2).every(x=>x===null))issue='no-statistics';
    if(!issue&&data.minutes!==null&&(data.matches===null||data.minutes>data.matches*90))issue='invalid-minutes';
    if(!issue&&data.points!==null&&data.tries!==null&&data.points<5*data.tries)issue='invalid-points';
    if(!issue&&p.performance2025_2026!==null&&JSON.stringify(p.performance2025_2026)!==JSON.stringify(data))issue='existing-observation-conflict';
    if(issue){rejected.push({name:row.name,issue});continue;}
    seen.add(p.id);
    accepted.push({id:p.id,source:row.sourceUrl,performance:data});
    if(p.performance2025_2026===null)changes.push({id:p.id,performance2025_2026:data});
  }
  return {summary:{input:rows.length,accepted:accepted.length,newPlayers:changes.length,rejected:rejected.length},accepted,rejected,proposedChanges:changes};
}
if(process.argv[1]?.endsWith('/reconcile.mjs')) {
 const [a,b,c]=process.argv.slice(2);
 if(!a||!b||!c)throw Error('Usage: node reconcile.mjs MASTER NORMALIZED OUT');
 const master=JSON.parse(await fs.readFile(a,'utf8'));
 const rows=JSON.parse(await fs.readFile(b,'utf8'));
 const report=reconcile(master,rows);
 await fs.writeFile(c,JSON.stringify(report,null,2));
 console.log(report.summary);
}
