import crypto from 'node:crypto';
export function adapt(raw) {
  if (raw?.schema !== 'rugbydata-raw-v1') throw Error('Wrong capture format');
  if (raw.seasonRequested !== '2025-2026' || !/2025[\/-]2026/.test(String(raw.seasonSelected?.text || ''))) throw Error('Unverified season');
  const league = /\/competition\/1\/?$/.test(raw.source) ? 'TOP14' : /\/competition\/4\/?$/.test(raw.source) ? 'PROD2' : null;
  if (!league) throw Error('Unknown competition');
  const rows=[], rejected=[], seen=new Set();
  for(const response of raw.json || []) {
    if(!/^https:\/\/(www\.)?rugbydata\.fr\//.test(response.url || '')) {rejected.push({reason:'source'});continue;}
    if (response.sha256 && crypto.createHash('sha256').update(JSON.stringify(response.data)).digest('hex') !== response.sha256) {rejected.push({reason:'digest-mismatch'});continue;}
    const arrays = Array.isArray(response.data) ? [response.data] : Object.values(response.data || {}).filter(Array.isArray);
    for (const arr of arrays) for(const item of arr) {
      if (!item || typeof item !== 'object') continue;
      const name=item.name ?? item.playerName; const club=item.club ?? item.teamName;
      const season=item.season ?? '2025-2026';
      if(item.league && ![league,league==='TOP14'?'Top 14':'Pro D2'].includes(item.league)){rejected.push({reason:'league'});continue;}
      if (!name || !club || season !== '2025-2026') {rejected.push({reason:'identity-or-season'});continue;}
      const stats={};let invalid=false;
      for(const [key,aliases] of Object.entries({matches:['matches','matchs'],minutes:['minutes','minutesPlayed'],tries:['tries','essais'],points:['points']})) {
        const v=aliases.map(a=>item[a]).find(v=>v!==undefined);
        if(v===undefined || v===null || v==='') stats[key]=null;
        else if(typeof v==='number' && Number.isSafeInteger(v) && v>=0) stats[key]=v;
        else invalid=true;
      }
      if(invalid || Object.values(stats).every(v=>v===null)){rejected.push({reason:'stats'});continue;}
      const k=[name,club,item.id ?? ''].join('|').normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase();
      if(seen.has(k)) continue;
      seen.add(k);rows.push({name,club,league,season,...stats,sourceUrl:response.url,sourceId:item.id == null ? null : String(item.id)});
    }
  }
  return {rows,rejected,summary:{accepted:rows.length,rejected:rejected.length}};
}
