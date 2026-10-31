'use strict';
// V60.2 : enveloppe temporelle pure protegeant des effets repetes.
(function(root,factory){const api=factory(typeof module==='object'&&module.exports?require('./press-events.js'):root.CDPressEvents);if(typeof module==='object'&&module.exports)module.exports=api;if(root)root.CDPressCalendar=api})(typeof globalThis==='object'?globalThis:null,function(events){
const copy=x=>JSON.parse(JSON.stringify(x));const ok=(v,m)=>{if(!v)throw Error(m)};
function create(clubId){return {version:1,media:events.start(clubId),processed:[],timeline:[]};}
function validate(s){ok(s&&s.version===1&&s.media&&Array.isArray(s.processed)&&Array.isArray(s.timeline),'Calendrier invalide');events.validate(s.media);ok(new Set(s.processed).size===s.processed.length,'Double traitement');return true;}
function advance(s,{season,week,metrics={}}){validate(s);ok(Number.isInteger(season)&&season>=1&&Number.isInteger(week)&&week>=0,'Date invalide');const key=season+':'+week;if(s.processed.includes(key))return {state:copy(s),effects:[],skipped:true};const last=s.timeline.at(-1);if(last)ok(season>last.season||(season===last.season&&week>last.week),'Retour dans le temps');const n=copy(s);
// Adaptation du temps : l'API V60.1 attend une semaine croissante. On fournit un index global.
const absoluteWeek=season*1000+week;
const pending=n.media.promises.filter(p=>p.status==='pending'&&p.season===season);
for(const promise of pending){promise.deadline=promise.deadline<1000?season*1000+promise.deadline:promise.deadline;}
for(const crisis of n.media.crises.filter(c=>c.status==='active')){if(crisis.started<1000)crisis.started=season*1000+crisis.started;}
const result=events.tick(n.media,{season,week:absoluteWeek,metrics});n.media=result.state;n.processed.push(key);n.timeline.push({season,week,effects:result.effects.length});validate(n);return {state:n,effects:result.effects,skipped:false};}
return Object.freeze({create,validate,advance});});
