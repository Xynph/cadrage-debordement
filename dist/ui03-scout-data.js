/* UI-03A — projections strictement publiques du recrutement natif. */
(function(root,build){
  'use strict';
  const api=build();
  if(typeof module==='object'&&module.exports)module.exports=api;
  if(root)root.CDUI03ScoutData=api;
})(typeof globalThis!=='undefined'?globalThis:null,function(){
  'use strict';
  const VIEWS=Object.freeze(['overview','candidates','reports','missions','watch']);
  const SORTS=Object.freeze(['name','position','age','salary','price','noteMin']);
  const MISSION_STATES=Object.freeze(['active','queued','done']);
  function text(v){return typeof v==='string'?v:'';}
  function num(v){return typeof v==='number'&&Number.isFinite(v)?v:null;}
  function integer(v){return Number.isInteger(v)?v:null;}
  function clampRange(v){return num(v)===null?null:Math.max(0,Math.min(100,v));}
  function norm(v){return String(v??'').normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLocaleLowerCase('fr');}
  function publicPlayer(p){
    if(!p||typeof p.id!=='string'||!p.id)throw new TypeError('Identifiant de candidat requis.');
    // Ne JAMAIS transmettre rating/skills/dev/potential à la vue ou au helper.
    return {id:p.id,name:text(p.name),position:text(p.pos),family:integer(p.fam),
      age:num(p.age),salary:num(p.salary),price:num(p.price)};
  }
  function reportRow(r,available,watched){
    if(!r||typeof r.playerId!=='string'||!r.playerId)return null;
    return {id:text(r.id),playerId:r.playerId,name:text(r.name),position:text(r.pos),
      family:integer(r.family),ageAtReport:num(r.age),
      noteAtReport:clampRange(r.note),potentialAtReport:clampRange(r.potential),
      salaryAtReport:num(r.salary),priceAtReport:num(r.price),
      grade:['A','B','C'].includes(r.grade)?r.grade:null,
      week:integer(r.week),season:integer(r.season),
      available:!!available,watched:!!watched};
  }
  function missionRow(m){
    if(!m||typeof m.id!=='string'||!m.id)return null;
    return {id:m.id,family:integer(m.family),maxAge:integer(m.maxAge),
      maxFee:num(m.budget),maxSalary:num(m.maxWage),
      remaining:integer(m.remaining),status:MISSION_STATES.includes(m.status)?m.status:'unknown',
      week:integer(m.week)};
  }
  function needRow(n){
    if(!n||!Number.isInteger(n.slot)||n.slot<0||n.slot>14)return null;
    return {slot:n.slot,family:integer(n.family),position:text(n.pos),
      score:clampRange(n.score),healthy:integer(n.healthy),durable:integer(n.durable),
      youth:integer(n.youth),need:n.need===true,
      reasons:Array.isArray(n.reasons)?n.reasons.filter(x=>typeof x==='string').slice(0,9):[]};
  }
  function buildCenter(source,deps){
    if(!source||!Array.isArray(source.pool)||!Array.isArray(source.reports)||
      !Array.isArray(source.missions)||!Array.isArray(source.watch)||
      !Array.isArray(source.needs)||!deps||typeof deps.evidence!=='function')
      throw new TypeError('Données natives de recrutement et recruitmentEvidence requis.');
    const watch=new Set(source.watch.filter(x=>typeof x==='string'));
    const seenIds=new Set(),candidates=[];
    const reports=source.reports.map(r=>reportRow(r,false,watch.has(r?.playerId))).filter(Boolean);
    const reportsByPlayer=new Map();
    // Le dernier rapport en tête est la convention native (unshift).
    for(const report of reports)if(!reportsByPlayer.has(report.playerId))reportsByPlayer.set(report.playerId,report);
    for(const raw of source.pool){
      const p=publicPlayer(raw);
      if(seenIds.has(p.id))continue;
      seenIds.add(p.id);
      // Uniquement l'enveloppe publique : le moteur détermine les bornes.
      const evidence=deps.evidence({...p,salary:p.salary});
      if(!evidence||typeof evidence!=='object')throw new TypeError('Fourchette native absente.');
      const known=!!evidence.seen&&reportsByPlayer.has(p.id);
      candidates.push({
        ...p,watched:watch.has(p.id),observed:known,
        stale:known&&!!evidence.stale,
        noteMin:clampRange(evidence.noteMin),noteMax:clampRange(evidence.noteMax),
        potentialMin:known?clampRange(evidence.potentialMin):null,
        potentialMax:known?clampRange(evidence.potentialMax):null,
        grade:known?reportsByPlayer.get(p.id).grade:null,
        evidenceLabel:text(evidence.label),
        reportWeek:known?reportsByPlayer.get(p.id).week:null
      });
    }
    const available=new Set(candidates.map(c=>c.id));
    for(const report of reports){report.available=available.has(report.playerId);}
    const watchRows=[...watch].map(id=>{
      const p=candidates.find(c=>c.id===id);
      if(p)return {id,name:p.name,position:p.position,available:true,observed:p.observed,stale:p.stale,
        noteMin:p.noteMin,noteMax:p.noteMax};
      const r=reportsByPlayer.get(id);
      return {id,name:r?.name||'',position:r?.position||'',available:false,
        observed:!!r,stale:!!r,noteMin:null,noteMax:null};
    });
    return {
      version:1,season:integer(source.season),week:integer(source.week),
      candidates,reports,missions:source.missions.map(missionRow).filter(Boolean),
      watch:watchRows,needs:source.needs.map(needRow).filter(Boolean),
      totals:{candidates:candidates.length,reports:reports.length,watch:watchRows.length,
        active:source.missions.filter(m=>m.status==='active').length,
        queued:source.missions.filter(m=>m.status==='queued').length}
    };
  }
  function compare(a,b){
    if(a==null)return b==null?0:1;
    if(b==null)return -1;
    if(typeof a==='number'&&typeof b==='number')return a-b;
    return String(a).localeCompare(String(b),'fr',{sensitivity:'base',numeric:true});
  }
  function candidateTable(model,opts={}){
    if(!model||!Array.isArray(model.candidates))throw new TypeError('Modèle de scouting requis.');
    const sort=opts.sortBy||'name',direction=opts.direction||'asc';
    if(!SORTS.includes(sort)||!['asc','desc'].includes(direction))throw new RangeError('Tri invalide.');
    const q=norm(opts.search).trim(),family=opts.family===undefined||opts.family==='all'?'all':Number(opts.family);
    if(family!=='all'&&(!Number.isInteger(family)||family<0||family>8))throw new RangeError('Poste invalide.');
    let rows=model.candidates.filter(p=>
      (!q||norm(p.name+' '+p.position).includes(q))&&
      (family==='all'||p.family===family)&&
      (!opts.observedOnly||p.observed)&&
      (!opts.watchedOnly||p.watched)&&
      (opts.maxSalary==null||p.salary!==null&&p.salary<=opts.maxSalary)&&
      (opts.maxFee==null||p.price!==null&&p.price<=opts.maxFee)
    );
    for(const name of ['maxSalary','maxFee']){
      if(opts[name]!=null&&(!Number.isFinite(opts[name])||opts[name]<0))throw new RangeError('Plafond financier invalide.');
    }
    rows=rows.map((row,index)=>({row,index})).sort((a,b)=>{
      const field=sort==='position'?'position':sort;
      const d=compare(a.row[field],b.row[field]);
      return d?(direction==='desc'?-d:d):a.index-b.index;
    }).map(x=>x.row);
    return {sortBy:sort,direction,total:rows.length,rows};
  }
  return Object.freeze({VIEWS,SORTS,publicPlayer,buildCenter,candidateTable});
});