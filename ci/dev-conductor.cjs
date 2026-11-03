'use strict';
// Tableau de bord lecture seule : ni fusion ni mutation de branches.
// Le gate officiel et les protections serveur restent seuls habilités à intégrer.
const {execFileSync} = require('node:child_process');
const REPO='Xynph/cadrage-debordement';
const lanes={
  DATA:/^(modding\/|tools\/rugby-|tests\/rugby-)/,
  V60:/^(dist\/(?:.*v60|.*press|media-|office-career-press|saves\.js)|tests\/v60-)/,
  CI:/^(ci\/|\.github\/workflows\/|tests\/(?:dev-conductor|delivery-readiness|chat-release|release-gate))/,
  GAME:/^(dist\/|src\/|tests\/|offline\/)/
};
function lane(files) {
  const out=new Set();
  for(const file of files){
    const path=typeof file==='string'?file:file.filename;
    if(typeof path!=='string')throw Error('Chemin invalide');
    let found=false;
    for(const [name,re] of Object.entries(lanes))if(re.test(path)){out.add(name);found=true;break;}
    if(!found)out.add('DOCS');
  }
  return [...out].sort();
}
function overlap(a,b){const s=new Set(a);return b.filter(x=>s.has(x));}
function select(prs) {
  if(!Array.isArray(prs))throw Error('PR attendues');
  const sorted=prs.map(p=>{
    if(!Number.isSafeInteger(p.number)||p.number<=0||!Array.isArray(p.files))throw Error('Métadonnées PR invalides');
    const paths=p.files.map(f=>typeof f==='string'?f:f.filename);
    const kinds=lane(paths);
    const sensitive=paths.some(f=>/^(dist\/saves\.js|modding\/data06\/|ci\/release-gate\.cjs|ci\/chat-release\.cjs|\.github\/workflows\/)/.test(f));
    const ready=p.state==='open'&&!p.draft&&p.mergeable===true&&p.mergeable_state==='clean';
    return {number:p.number,title:String(p.title||'').slice(0,120),sha:p.head?.sha||null,base:p.base?.ref||null,
      paths,kinds,sensitive,ready,ci:'À vérifier avec le gate officiel',conflicts:[],next:''};
  }).sort((a,b)=>a.number-b.number);
  for(let i=0;i<sorted.length;i++)for(let j=i+1;j<sorted.length;j++){
    const shared=overlap(sorted[i].paths,sorted[j].paths);
    if(shared.length){sorted[i].conflicts.push({pr:sorted[j].number,files:shared});sorted[j].conflicts.push({pr:sorted[i].number,files:shared});}
  }
  for(const p of sorted){
    p.next=p.base!=='main'?'Vérifier la dépendance et intégrer la PR de base en premier':
      p.conflicts.length?'Coordonner les chemins communs avant toute écriture':
      !p.ready?'Résoudre draft, conflits ou état de fusion incertain':
      p.sensitive?'Contrôles renforcés et gate officiel sur HEAD exact':
      'Contrôler CI 7/7 et gate officiel sur HEAD exact';
  }
  return sorted;
}
function report(prs){
  const rows=select(prs);
  return ['# État des chantiers (lecture seule)','',...rows.map(p=>
    '- PR #'+p.number+' — '+p.kinds.join('/')+' — '+p.next+
    (p.conflicts.length?' ; chemins communs avec #'+p.conflicts.map(c=>c.pr).join(', #'):'')+
    ' ; CI : '+p.ci), '',
    'Aucune fusion, aucun rerun et aucune réservation effectués. Les recouvrements de fichiers sont des alertes, pas des conflits Git prouvés.',
    'Les workflows, protections et le gate officiel doivent être contrôlés indépendamment.'].join('\n');
}
function api(url){
  const raw=execFileSync('gh',['api','--method','GET',url],{encoding:'utf8',timeout:25000,maxBuffer:12*1024*1024});
  return JSON.parse(raw);
}
function pages(endpoint){
  const out=[];
  for(let page=1;page<=10;page++){
    const sep=endpoint.includes('?')?'&':'?';
    const batch=api('repos/'+REPO+'/'+endpoint+sep+'per_page=100&page='+page);
    if(!Array.isArray(batch))throw Error('Pagination invalide');
    out.push(...batch);
    if(batch.length<100)return out;
  }
  throw Error('Liste tronquée : arrêt sûr');
}
function inspect(){
  const prs=pages('pulls?state=open');
  const subset=prs.filter(p=>p.base?.ref==='main'||p.head?.repo?.full_name===REPO);
  if(subset.length>100)throw Error('Trop de PR ouvertes');
  return subset.map(pr=>{
    const files=pages('pulls/'+pr.number+'/files').map(f=>f.filename);
    return {...pr,files};
  });
}
function main(argv=process.argv.slice(2)){
  if(argv.length>1||argv[0]&&!['--json','--text'].includes(argv[0]))throw Error('Usage : node ci/dev-conductor.cjs [--json|--text]');
  const rows=select(inspect());
  if(argv[0]==='--json')console.log(JSON.stringify(rows,null,2));
  else console.log(report(rows));
}
if(require.main===module){try{main();}catch(error){console.error('STOP lecture seule : '+error.message);process.exitCode=1;}}
module.exports={lane,overlap,select,report};
