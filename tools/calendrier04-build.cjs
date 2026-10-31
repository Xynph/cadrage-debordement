'use strict';
const fs=require('node:fs'),path=require('node:path'),zlib=require('node:zlib');
const src=path.join(__dirname,'../world-data/calendrier04/fixtures-packed-2026-2027.txt');
const raw=JSON.parse(zlib.inflateSync(Buffer.from(fs.readFileSync(src,'utf8').trim(),'base64')).toString('utf8'));
const slots={
 top14:[[0,'14:30'],[0,'16:35'],[0,'16:35'],[0,'16:35'],[0,'21:05'],[1,'16:05'],[1,'21:05']],
 prod2:[[0,'21:00'],[1,'19:00'],[1,'19:30'],[1,'19:30'],[1,'19:30'],[1,'19:30'],[1,'21:00'],[1,'21:00']]
};
function datePlus(iso,delta){const d=new Date(iso+'T12:00:00Z');d.setUTCDate(d.getUTCDate()+delta);return d.toISOString().slice(0,10)}
function offset(date){const d=new Date(date+'T12:00:00Z');const year=d.getUTCFullYear();const sunday=(year,month)=>{const last=new Date(Date.UTC(year,month,0));return last.getUTCDate()-last.getUTCDay()};const summer=date>=year+'-03-'+String(sunday(year,3)).padStart(2,'0')&&date<year+'-10-'+String(sunday(year,10)).padStart(2,'0');return summer?'+02:00':'+01:00'}
function build(){
 const fixtures=[],coverage={};
 for(const league of ['top14','prod2']){
  const o=raw[league],expected=league==='top14'?14:16,rounds=league==='top14'?26:30;
  if(o.teams.length!==expected||o.dates.length!==rounds||o.pairs.length!==rounds)throw Error('League shape invalid '+league);
  const ordered=new Set();
  for(let r=0;r<rounds;r++){
   const txt=o.pairs[r],per=expected/2;
   if(txt.length!==expected)throw Error('Round size invalid '+league+':'+(r+1));
   const seen=new Set();
   for(let i=0;i<per;i++){
    const home=o.teams[txt.charCodeAt(2*i)-65],away=o.teams[txt.charCodeAt(2*i+1)-65];
    if(!home||!away||home===away||seen.has(home)||seen.has(away))throw Error('Teams invalid J'+(r+1));
    seen.add(home);seen.add(away);
    const pair=home+'|'+away;if(ordered.has(pair))throw Error('Duplicate pairing '+pair);ordered.add(pair);
    const [day,time]=slots[league][(i+(r+1)*3)%per],matchDate=datePlus(o.dates[r],day);
    fixtures.push({id:league+'-j'+String(r+1).padStart(2,'0')+'-m'+String(i+1).padStart(2,'0'),competition:league,round:r+1,home,away,
     windowStart:o.dates[r],windowEnd:datePlus(o.dates[r],1),
     officialKickoff:null,simulatedKickoff:matchDate+'T'+time+':00'+offset(matchDate),
     kickoffStatus:'simulated-not-official',score:null,
     sourceFile:league==='top14'?'TOP14_Calendrier_26-27_52f176c3bd1630dc2d08bce2b2edfa7b.pdf':'PROD2-Calendrier_26-27-1_e05e7a437154a5d2f0f49cb1bde6e3d5.pdf',sourcePage:r<(league==='top14'?13:15)?1:2});
   }
  }
  if(ordered.size!==expected*(expected-1))throw Error('Incomplete '+league);
  for(const k of ordered){const [a,b]=k.split('|');if(!ordered.has(b+'|'+a))throw Error('No return match '+k)}
  coverage[league]=ordered.size;
 }
 return {schemaVersion:1,season:'2026-2027',careerStart:'2026-07-01',status:'all-422-official-pairings; kickoffs-simulated',timeZone:'Europe/Paris',coverage,fixtures};
}
if(require.main===module){const result=build(),dest=process.argv[2];if(dest){fs.mkdirSync(path.dirname(dest),{recursive:true});fs.writeFileSync(dest,JSON.stringify(result,null,2)+'\n')}console.log(JSON.stringify({coverage:result.coverage,total:result.fixtures.length,output:dest||null}))}
module.exports={build};
