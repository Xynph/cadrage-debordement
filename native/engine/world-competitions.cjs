'use strict';

// Self-contained by design: this function is also injected into the native VM
// through factory.toString(). No runtime state, random generator or I/O lives here.
function factory() {
  const DAY = 86400000;
  const SOURCES = {
    lnr: 'https://assets.lnr.fr/3/0/4/6/9/8/LIVRE-2_Sportif-et-Comp%C3%A9titions_2627_V2_703069b00e686885076f1b627c8c5441.pdf',
    prem: 'https://rfu.widen.net/s/bpmdldld6m/prem-rugby-league-regulations-2026-27',
    premMembership: 'https://www.englandrugby.com/follow/news-and-media/rugby-unites-behind-transformational-new-vision',
    urc: 'https://d19fc3vd0ojo3m.cloudfront.net/irfu/wp-content/uploads/2025/09/26090041/001.-Championship-Rules-25_26__CLEAN.pdf',
    urcFormat: 'https://www.unitedrugby.com/latest/news/get-ready-for-2026-27-fixtures-are-now-live/',
    urcTitleHolder: 'https://www.unitedrugby.com/latest/news/urc-qualification-for-investec-champions-cup-clarified/',
    champions: 'https://www.epcrugby.com/champions-cup/champions-cup-rules',
    challenge: 'https://www.epcrugby.com/challenge-cup/reglement-ecc',
    calendar: 'https://www.epcrugby.com/european-professional-club-rugby/content/epcr-pool-draws-for-202627-season'
  };
  const copy = x => JSON.parse(JSON.stringify(x));
  const assert = (ok, message) => { if (!ok) throw new Error(message); };
  const year = season => {
    const y = Number(String(season).slice(0, 4));
    assert(Number.isInteger(y) && y >= 2000 && y <= 2200, 'invalid season');
    return y;
  };
  const dateMs = date => {
    assert(typeof date === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(date), 'date must be ISO day');
    const ms = Date.parse(date + 'T00:00:00Z');
    assert(Number.isFinite(ms) && new Date(ms).toISOString().slice(0, 10) === date, 'invalid date');
    return ms;
  };
  const iso = ms => new Date(ms).toISOString().slice(0, 10);
  const weekKey = date => {
    const ms = dateMs(date), d = new Date(ms).getUTCDay();
    return iso(ms - ((d + 6) % 7) * DAY);
  };
  const numericId = id => Number.isSafeInteger(id) && id >= 0;
  const seasonKey = value => {
    assert((typeof value==='number' && Number.isSafeInteger(value) && value>=1) || (typeof value==='string' && /^\d{4}(?:[/-]\d{2,4})?$/.test(value)), 'invalid result season');
    return typeof value==='string' && value.length>=4 ? String(Number(value.slice(0,4))) : String(value);
  };
  const ids = list => {
    assert(Array.isArray(list) && list.every(numericId), 'invalid club IDs');
    assert(new Set(list).size === list.length, 'duplicate club ID');
    return list.slice();
  };
  function rules(competitionId) {
    const common = { competitionId, win: 4, draw: 2, loss: 0, roundBase: 0, regularPhase: 'league' };
    const profiles = {
      elite: { clubs: 14, rounds: 26, legs: 2, bonus: { tryMargin: 3, losingMargin: 5 }, playoffs: 6, provenance: { url: SOURCES.lnr, edition: '2026/27', status: 'confirmed', sections: ['2005–2010', '2031', '2034', '2085'] } },
      accession: { clubs: 16, rounds: 30, legs: 2, bonus: { tryMargin: 3, losingMargin: 5 }, playoffs: 6, provenance: { url: SOURCES.lnr, edition: '2026/27', status: 'confirmed', sections: ['2011–2013', '2031', '2034', '2085'] } },
      prem: { clubs: 10, rounds: 18, legs: 2, bonus: { tries: 4, losingMargin: 7 }, playoffs: 4, membership: { automaticPromotionRelegation:false, framework:'criteria-based-expansion-and-demotion', source:SOURCES.premMembership, effective:'2026/27' }, provenance: { url: SOURCES.prem, edition: '2026/27', status: 'confirmed', sections: ['2.2', '3.1', '3.2', '4.3(b)', 'Schedule 2'], sha256:'71c5d6acd535e75b9f72625c4a79c7aea4be18abd704e13f9a4880ac2913a97b' } },
      urc: { clubs: 16, rounds: 18, legs: 1, regionalReturnLegs: 3, bonus: { tries: 4, losingMargin: 7 }, playoffs: 8, provenance: { url: SOURCES.urc, edition: '2025/26', status: 'provisional-current-edition-unavailable', corroboration:{url:SOURCES.urcFormat,edition:'2026/27',scope:'unchanged regular/playoff format and calendar windows'}, caveat: '2026/27 consolidated regulation not located. Public competition-rules page mixes editions.' } },
      champions: { clubs: 24, pools: 4, poolSize: 6, rounds: 4, bonus: { tryMargin: 3, losingMargin: 7 }, playoffs: 16, provenance: { url: SOURCES.champions, edition: '2026/27', status: 'confirmed', sections: ['2.1–2.8', '3–6'] } },
      challenge: { clubs: 18, pools: 3, poolSize: 6, rounds: 4, bonus: { tryMargin: 3, losingMargin: 7 }, playoffs: 16, provenance: { url: SOURCES.challenge, edition: '2026/27', status: 'confirmed', caveat: 'Final-date year typo on rules page resolved by the official 2026/27 calendar.' } },
      access: { clubs: 2, rounds: 1, bonus: null, playoffs: 2, provenance: { url: SOURCES.lnr, edition: '2026/27', status: 'confirmed', sections: ['2008', '2013', '2085'] } }
    };
    assert(Object.hasOwn(profiles,competitionId), 'unknown competition: ' + competitionId);
    return copy({ ...common, ...profiles[competitionId] });
  }
  function europeanWeeks({ season }) {
    const y = year(season);
    return [`${y}-10-17`, `${y}-12-12`, `${y+1}-01-09`, `${y+1}-01-16`, `${y+1}-04-03`, `${y+1}-04-10`, `${y+1}-05-01`, `${y+1}-05-22`].map(day=>iso(dateMs(weekKey(day))+5*DAY));
  }
  function roundDates({ season, competitionId, rounds, startDate, endDate, excludedWeeks = [], dates }) {
    if (dates) {
      assert(Array.isArray(dates) && dates.length === rounds, 'one date per round required');
      dates.forEach(dateMs);
      assert(new Set(dates.map(weekKey)).size === rounds, 'duplicate round week');
      return dates.slice();
    }
    const y = year(season);
    let first = dateMs(startDate || `${y}-09-${competitionId === 'prem' || competitionId === 'urc' ? '26' : '05'}`);
    const end = dateMs(endDate || `${y+1}-05-${competitionId === 'accession' ? '15' : '29'}`);
    const blocked = new Set([...europeanWeeks({season}), ...excludedWeeks].map(weekKey));
    const available = [];
    for (let ms = first; ms <= end; ms += 7 * DAY) if (!blocked.has(weekKey(iso(ms)))) available.push(iso(ms));
    assert(available.length >= rounds, 'not enough free weeks for regular rounds');
    // Spread generated game rounds over the season; dates are never claimed official.
    return Array.from({length: rounds}, (_, i) => available[Math.floor(i * (available.length - 1) / Math.max(1, rounds - 1))]);
  }
  function circle(list) {
    const rotating = list.slice(), rounds = [];
    assert(rotating.length % 2 === 0, 'even club count required');
    for (let r = 0; r < rotating.length - 1; r++) {
      const pairs = [];
      for (let i = 0; i < rotating.length / 2; i++) {
        const a = rotating[i], b = rotating[rotating.length - 1 - i];
        pairs.push((r + i) % 2 ? [b, a] : [a, b]);
      }
      rounds.push(pairs);
      rotating.splice(1, 0, rotating.pop());
    }
    return rounds;
  }
  const edgeKey = (a,b) => a < b ? `${a}:${b}` : `${b}:${a}`;
  // Euler orientation gives equal home/away degree in an even-degree graph.
  function orient(edges) {
    const adj = new Map(), used = new Set(), out = new Map();
    edges.forEach(([a,b], i) => { if (!adj.has(a)) adj.set(a, []); if (!adj.has(b)) adj.set(b, []); adj.get(a).push([b,i]); adj.get(b).push([a,i]); });
    for (const start of adj.keys()) {
      const stack = [start], circuit = [];
      while (stack.length) {
        const a = stack[stack.length - 1], choices = adj.get(a);
        while (choices.length && used.has(choices[choices.length-1][1])) choices.pop();
        if (!choices.length) circuit.push(stack.pop());
        else { const [b,i] = choices.pop(); used.add(i); stack.push(b); }
      }
      for (let i = 1; i < circuit.length; i++) out.set(edgeKey(circuit[i-1],circuit[i]), [circuit[i-1],circuit[i]]);
    }
    return out;
  }
  function validateClubs(clubs) {
    assert(Array.isArray(clubs), 'clubs array required');
    ids(clubs.map(c => c.id));
    return new Map(clubs.map(c => [c.id, c]));
  }
  function regularFixtures(options) {
    const { clubs, competitionId, season, initialFixtures } = options;
    const p = rules(competitionId), byId = validateClubs(clubs);
    assert(['elite','accession','prem','urc'].includes(competitionId), 'regularFixtures requires a domestic league');
    assert(clubs.length === p.clubs, 'incorrect league club count');
    let rounds = circle(clubs.map(c => c.id));
    if (competitionId === 'urc') {
      const groups = new Map();
      for (const c of clubs) { assert(typeof c.shield === 'string' && c.shield, 'URC shield required'); if (!groups.has(c.shield)) groups.set(c.shield, []); groups.get(c.shield).push(c.id); }
      assert(groups.size === 4 && [...groups.values()].every(g => g.length === 4), 'URC requires four geographical groups of four');
      const cross = rounds.flat().filter(([a,b]) => byId.get(a).shield !== byId.get(b).shield), directed = orient(cross);
      rounds = rounds.map(ps => ps.map(([a,b]) => directed.get(edgeKey(a,b)) || [a,b]));
      const first = new Map(rounds.flat().map(pair => [edgeKey(...pair), pair]));
      const extra = Array.from({length:3},()=>[]);
      for (const group of groups.values()) circle(group).forEach((ps,r) => ps.forEach(([a,b]) => { const pair = first.get(edgeKey(a,b)); extra[r].push([pair[1],pair[0]]); }));
      rounds.push(...extra);
    } else rounds.push(...rounds.map(ps => ps.map(([a,b]) => [b,a])));
    const dates = roundDates({...options, rounds:p.rounds});
    const generated = rounds.flatMap((pairs,round) => pairs.map(([homeId,awayId],slot) => ({id:`${competitionId}:${year(season)}:league:${round}:${slot}`,competitionId,season,round,date:dates[round],homeId,awayId,phase:'league',scheduleSource:'generated-game'})));
    if (!initialFixtures) return generated;
    assert(Array.isArray(initialFixtures) && initialFixtures.length === generated.length, 'initial fixture count mismatch');
    const seen = new Set(), pairs = new Map(), perRound = new Map(), home = new Map(), direction=new Map(), weekOccupancy=new Set();
    for (const f of initialFixtures) {
      assert(f.competitionId === competitionId && year(f.season) === year(season) && f.phase === 'league', 'initial fixture namespace mismatch');
      assert(typeof f.id === 'string' && !seen.has(f.id), 'duplicate initial fixture ID'); seen.add(f.id);
      assert(byId.has(f.homeId) && byId.has(f.awayId) && f.homeId !== f.awayId, 'unknown initial fixture club'); dateMs(f.date);
      assert(Number.isInteger(f.round) && f.round >= 0 && f.round < p.rounds, 'invalid initial round');
      const rr = perRound.get(f.round) || new Set(); assert(!rr.has(f.homeId) && !rr.has(f.awayId), 'club twice in initial round'); rr.add(f.homeId); rr.add(f.awayId); perRound.set(f.round,rr);
      const w=weekKey(f.date);for(const clubId of [f.homeId,f.awayId]) {const k=`${w}:${clubId}`;assert(!weekOccupancy.has(k),'club twice in initial week');weekOccupancy.add(k);}
      const k=edgeKey(f.homeId,f.awayId); pairs.set(k,(pairs.get(k)||0)+1);home.set(f.homeId,(home.get(f.homeId)||0)+1);
      const ordered=`${f.homeId}:${f.awayId}`;direction.set(ordered,(direction.get(ordered)||0)+1);
    }
    for (const c of clubs) { assert(home.get(c.id) === p.rounds/2, 'unbalanced initial home fixtures'); for (const o of clubs) if(c.id<o.id) assert(pairs.get(edgeKey(c.id,o.id)) === (competitionId==='urc' && c.shield!==o.shield?1:2), 'incorrect initial opponent count'); }
    assert([...direction.values()].every(n=>n===1),'initial return fixture must reverse home and away');
    assert([...perRound.values()].every(s=>s.size===clubs.length), 'incomplete initial round');
    return copy(initialFixtures);
  }
  const metric = (r, k) => Number.isFinite(r[k]) ? r[k] : 0;
  const descending = (a,b,keys) => { for(const k of keys) { const d=metric(b,k)-metric(a,k);if(d) return d; } return 0; };
  const epcrCompare = (a,b) => descending(a,b,['points','won','diff','tf']);
  function table(clubIds, results, competitionId, options = {}) {
    const list = ids(clubIds), allowed = new Set(list), p=rules(competitionId);
    assert(Array.isArray(results),'results array required');
    const phase = options.phase || 'league';
    let relevant = results.filter(r=>r.competitionId===competitionId && r.phase===phase && (options.poolId===undefined || r.poolId===options.poolId));
    if(options.season!==undefined) relevant=relevant.filter(r=>seasonKey(r.season)===seasonKey(options.season));
    else assert(new Set(relevant.map(r=>seasonKey(r.season))).size<=1,'multiple seasons require explicit season');
    relevant=relevant.slice().sort((a,b)=>(Number(a.round)||0)-(Number(b.round)||0) || String(a.date||'').localeCompare(String(b.date||'')) || String(a.fixtureId).localeCompare(String(b.fixtureId)));
    const byId = new Map(list.map(clubId=>[clubId,{clubId,played:0,won:0,drawn:0,lost:0,pf:0,pa:0,tf:0,ta:0,points:0,bonus:0,offensiveBonus:0,defensiveBonus:0,form:[],diff:0,tryDiff:0}]));
    const seen = new Set(), included=[];
    for(const r of relevant) {
      assert(typeof r.fixtureId==='string' && !seen.has(r.fixtureId),'duplicate or missing fixture ID');seen.add(r.fixtureId);
      assert(Array.isArray(r.pair) && r.pair.length===2 && r.pair.every(numericId) && r.pair[0]!==r.pair[1],'invalid result pair');
      assert(Array.isArray(r.score) && r.score.length===2 && r.score.every(n=>Number.isSafeInteger(n)&&n>=0),'invalid score');
      assert(Array.isArray(r.tries) && r.tries.length===2 && r.tries.every(n=>Number.isSafeInteger(n)&&n>=0),'invalid tries');
      // A pool table may receive all results of the competition, but never a
      // result involving exactly one pool member: that indicates wrong scoping.
      const n=r.pair.filter(id=>allowed.has(id)).length; if(n===0) continue; assert(n===2,'result crosses table membership');
      included.push(r);
      for(let side=0;side<2;side++) {
        const row=byId.get(r.pair[side]), other=1-side, margin=r.score[side]-r.score[other], tries=r.tries[side]-r.tries[other];
        const win=margin>0, draw=margin===0, bo=p.bonus && (p.bonus.tryMargin!==undefined?tries>=p.bonus.tryMargin:r.tries[side]>=p.bonus.tries), bd=p.bonus && margin<0 && -margin<=p.bonus.losingMargin;
        row.played++;row.won+=+win;row.drawn+=+draw;row.lost+=+(!win&&!draw);row.pf+=r.score[side];row.pa+=r.score[other];row.tf+=r.tries[side];row.ta+=r.tries[other];row.offensiveBonus+=+!!bo;row.defensiveBonus+=+!!bd;row.bonus+=+!!bo + +!!bd;row.points+=(win?p.win:draw?p.draw:p.loss)+ +!!bo + +!!bd;row.form.push(win?'W':draw?'D':'L');
      }
    }
    for(const row of byId.values()) { row.diff=row.pf-row.pa;row.tryDiff=row.tf-row.ta;row.form=row.form.slice(-5); const deduction=options.deductions && options.deductions[row.clubId] || 0; assert(Number.isFinite(deduction),'invalid points deduction');row.points-=deduction; }
    const rows=[...byId.values()].sort((a,b)=>b.points-a.points);
    const drawOrder=options.tieBreaks && options.tieBreaks.drawOrder;
    if(drawOrder) {const values=Object.values(drawOrder);assert(values.every(n=>Number.isSafeInteger(n)&&n>=0)&&new Set(values).size===values.length,'draw order requires unique non-negative ranks');}
    function finalTie(items, missing) {
      if(missing)for(const r of items)r.unavailableTieBreak=missing;
      if(drawOrder && items.every(r=>Number.isSafeInteger(drawOrder[r.clubId])))return items.slice().sort((a,b)=>drawOrder[a.clubId]-drawOrder[b.clubId]);
      for(const r of items)r.unresolvedTie=true;
      return items;
    }
    function grouped(items, criteria, index=0) {
      if(items.length<2) return items;
      if(index>=criteria.length)return finalTie(items);
      const criterion=criteria[index], values=criterion(items);
      if(!values)return finalTie(items,criterion.field);
      const sorted=items.slice().sort((a,b)=>values.get(b.clubId)-values.get(a.clubId)), out=[];
      for(let i=0;i<sorted.length;) {let j=i+1;while(j<sorted.length && values.get(sorted[j].clubId)===values.get(sorted[i].clubId)) j++;out.push(...grouped(sorted.slice(i,j),criteria,index+1));i=j;}
      return out;
    }
    const val = k => group=>new Map(group.map(r=>[r.clubId,r[k]]));
    const extra = (key, sign=1, required=false) => Object.assign(group=>{
      const values=options.tieBreaks && options.tieBreaks[key];
      if(required&&group.some(r=>!values||!Number.isSafeInteger(values[r.clubId])))return null;
      return new Map(group.map(r=>[r.clubId,sign * Number(values && values[r.clubId] || 0)]));
    },{field:key});
    const h2h = k => group=>{
      const set=new Set(group.map(r=>r.clubId)), acc=new Map(group.map(r=>[r.clubId,0]));
      for(const r of included) if(r.pair.every(id=>set.has(id))) for(let s=0;s<2;s++) {const o=1-s,margin=r.score[s]-r.score[o];let n=0;if(k==='points') n=(margin>0?4:margin===0?2:0)+(r.tries[s]-r.tries[o]>=3?1:0)+(margin<0&&-margin<=5?1:0);else if(k==='diff')n=margin;else if(k==='tryDiff')n=r.tries[s]-r.tries[o];else n=r.score[s];acc.set(r.pair[s],acc.get(r.pair[s])+n);}
      return acc;
    };
    let criteria;
    if(competitionId==='elite'||competitionId==='accession') criteria=[val('points'),h2h('points'),val('diff'),h2h('diff'),h2h('tryDiff'),val('tryDiff'),val('pf'),val('tf'),extra('forfeits',-1),extra('previousRank',-1,true)];
    else if(competitionId==='prem') {
      criteria=[val('points'),val('won'),val('diff'),val('pf'),h2h('pf')];
      // RFU §3.1(a): wins excluding first match, then first two, etc.
      const max=Math.max(0,...rows.map(r=>r.played));
      for(let skip=1;skip<max;skip++) criteria.push(group=>new Map(group.map(row=>[row.clubId,included.filter(r=>r.pair.includes(row.clubId)).slice(skip).filter(r=>{const s=r.pair.indexOf(row.clubId);return r.score[s]>r.score[1-s];}).length])));
    } else if(competitionId==='urc') criteria=[val('points'),val('won'),val('diff'),val('tf'),val('pf'),val('tryDiff'),extra('suspendedPlayers',-1,true),extra('yellowCards',-1,true)];
    else criteria=[val('points'),val('won'),val('diff'),val('tf')];
    return grouped(rows,criteria).map((r,i)=>({...r,rank:i+1}));
  }
  function matchings(list) {
    if(!list.length) return [[]];
    const first=list[0], all=[];
    for(let i=1;i<list.length;i++) for(const rest of matchings(list.slice(1,i).concat(list.slice(i+1)))) all.push([[first,list[i]],...rest]);
    return all;
  }
  function colorRounds(list, edges) {
    const available=new Set(edges.map(pair=>edgeKey(...pair))), candidates=matchings(list);
    function visit(left, rounds) {
      if(!left.size) return rounds;
      const first=left.values().next().value;
      for(const ps of candidates) if(ps.some(p=>edgeKey(...p)===first) && ps.every(p=>left.has(edgeKey(...p)))) {
        const next=new Set(left);ps.forEach(p=>next.delete(edgeKey(...p)));const found=visit(next,rounds.concat([ps]));if(found)return found;
      }
      return null;
    }
    const result=visit(available,[]);assert(result,'pool graph has no valid four-round calendar');return result;
  }
  function poolStage({clubs,pools,competitionId,season,dates,initialFixtures}) {
    const p=rules(competitionId), byId=validateClubs(clubs);assert(p.pools,'European competition required');
    assert(Array.isArray(pools)&&pools.length===p.pools&&pools.every(pool=>Array.isArray(pool)&&pool.length===6),'invalid pool structure');ids(pools.flat());
    const days=dates || europeanWeeks({season}).slice(0,4);assert(Array.isArray(days)&&days.length===4,'four pool dates required');days.forEach(dateMs);assert(new Set(days.map(weekKey)).size===4,'four distinct pool weeks required');
    const generated=pools.flatMap((pool,poolId)=>{
      assert(pool.every(id=>byId.has(id)),'unknown pool club');let edges=[];
      for(let a=0;a<6;a++) for(let b=a+1;b<6;b++) if(competitionId==='challenge'||byId.get(pool[a]).leagueId!==byId.get(pool[b]).leagueId) edges.push([pool[a],pool[b]]);
      if(competitionId==='champions') {
        assert(['elite','prem','urc'].every(l=>pool.filter(id=>byId.get(id).leagueId===l).length===2),'Champions pool requires two from each league');
        const shields=pool.filter(id=>byId.get(id).leagueId==='urc').map(id=>byId.get(id).shield);assert(shields[0]!==shields[1],'same URC shield in Champions pool');
      } else {
        const omit=matchings(pool).sort((a,b)=>b.filter(([x,y])=>byId.get(x).leagueId===byId.get(y).leagueId).length-a.filter(([x,y])=>byId.get(x).leagueId===byId.get(y).leagueId).length)[0];
        const blocked=new Set(omit.map(pair=>edgeKey(...pair)));edges=edges.filter(pair=>!blocked.has(edgeKey(...pair)));
      }
      const directed=orient(edges), rounds=colorRounds(pool,edges);
      return rounds.flatMap((pairs,round)=>pairs.map((pair,slot)=>{const [homeId,awayId]=directed.get(edgeKey(...pair));return {id:`${competitionId}:${year(season)}:league:${poolId}:${round}:${slot}`,competitionId,season,phase:'league',poolId,round,date:days[round],homeId,awayId,scheduleSource:'generated-game'};}));
    });
    if(initialFixtures===undefined) return generated;
    assert(Array.isArray(initialFixtures)&&initialFixtures.length===generated.length,'initial pool fixture count mismatch');
    const seen=new Set(), slots=new Set(), edges=new Set(), home=new Map(), groupOf=new Map(pools.flatMap((pool,pi)=>pool.map(id=>[id,pi])));
    for(const f of initialFixtures) {
      assert(f.competitionId===competitionId&&year(f.season)===year(season)&&f.phase==='league','initial pool fixture namespace mismatch');
      assert(typeof f.id==='string'&&!seen.has(f.id),'duplicate initial pool fixture ID');seen.add(f.id);
      assert(Number.isInteger(f.round)&&f.round>=0&&f.round<4&&weekKey(f.date)===weekKey(days[f.round]),'initial pool fixture outside round week');
      assert(groupOf.has(f.homeId)&&groupOf.has(f.awayId)&&f.homeId!==f.awayId&&groupOf.get(f.homeId)===f.poolId&&groupOf.get(f.awayId)===f.poolId,'initial pool fixture crosses pools');
      if(competitionId==='champions')assert(byId.get(f.homeId).leagueId!==byId.get(f.awayId).leagueId,'same league in Champions pool fixture');
      const key=edgeKey(f.homeId,f.awayId);assert(!edges.has(key),'repeated initial pool opponent');edges.add(key);
      for(const id of [f.homeId,f.awayId]) {const slot=`${f.round}:${id}`;assert(!slots.has(slot),'club twice in initial pool round');slots.add(slot);}
      home.set(f.homeId,(home.get(f.homeId)||0)+1);
    }
    assert([...groupOf.keys()].every(id=>home.get(id)===2),'unbalanced initial pool home fixtures');
    return copy(initialFixtures);
  }
  function normalizePoolRows(tables, count, compare=epcrCompare) {
    assert(Array.isArray(tables)&&tables.length===count&&tables.every(t=>Array.isArray(t)&&t.length===6),'complete six-club pool tables required');
    ids(tables.flat().map(r=>r.clubId));
    return tables.map((rows,poolId)=>rows.map(r=>({...r,poolId,diff:Number.isFinite(r.diff)?r.diff:metric(r,'pf')-metric(r,'pa')})).sort(compare));
  }
  function poolQualifiers({competitionId,tables,transfers=[],drawOrder}) {
    const p=rules(competitionId), hasDraw=id=>drawOrder && Number.isFinite(drawOrder[id]);
    if(drawOrder) {const values=Object.values(drawOrder);assert(values.every(n=>Number.isSafeInteger(n)&&n>=0)&&new Set(values).size===values.length,'draw order requires unique non-negative ranks');}
    function rank(items) {
      const sorted=items.slice().sort(epcrCompare), out=[];
      for(let i=0;i<sorted.length;) {let j=i+1;while(j<sorted.length&&epcrCompare(sorted[i],sorted[j])===0)j++;const tied=sorted.slice(i,j);if(tied.every(r=>hasDraw(r.clubId)))tied.sort((a,b)=>drawOrder[a.clubId]-drawOrder[b.clubId]);out.push(...tied);i=j;}
      return out;
    }
    const pools=normalizePoolRows(tables,p.pools).map(rank), tiers=[0,1,2].map(i=>rank(pools.map(pool=>({...pool[i],poolRank:i+1}))));
    const remaining=rank(pools.flatMap(pool=>pool.slice(3).map((r,i)=>({...r,poolRank:i+4}))));
    let qualifiers, moved=[];
    if(competitionId==='champions') {qualifiers=[...tiers.flat(),...remaining.slice(0,4)];moved=remaining.slice(4,8).map((r,i)=>({...r,transferSeed:i+1,fromCompetition:'champions'}));}
    else {
      assert(competitionId==='challenge'&&Array.isArray(transfers)&&transfers.length===4,'four Champions transfers required');
      ids([...pools.flat(),...transfers].map(r=>r.clubId));
      qualifiers=[...tiers[0],...tiers[1],...tiers[2].slice(0,2),...transfers.map(r=>({...r,fromCompetition:'champions'})),tiers[2][2],...remaining.slice(0,3)];
    }
    const unresolved=[];
    const allGroups=[...pools,...tiers,remaining], tied=new Set();for(const g of allGroups)for(let i=0;i<g.length;) {let j=i+1;while(j<g.length&&epcrCompare(g[i],g[j])===0)j++;const group=g.slice(i,j);if(group.length>1&&!group.every(r=>hasDraw(r.clubId))){const clubIds=group.map(r=>r.clubId);clubIds.forEach(id=>tied.add(id));unresolved.push({code:'EPCR_DRAW_REQUIRED',clubIds});}i=j;}
    const annotate=r=>({...r,unresolvedTie:tied.has(r.clubId)});
    return {qualifiers:qualifiers.map((r,i)=>({...annotate(r),seed:i+1})),transfers:moved.map(annotate),unresolved,provenance:p.provenance};
  }
  function qualifyEurope({tables,titles={},season,clubs,invitations}) {
    const byId=validateClubs(clubs), selected={}, unresolved=[], ineligibleTitles=[], quotas={elite:8,prem:8,urc:8};
    assert(tables&&typeof tables==='object','domestic tables required');
    const idsOf=value=>ids(value.map(r=>typeof r==='number'?r:r.clubId));
    const lists={};for(const l of Object.keys(quotas)){lists[l]=idsOf(tables[l]||[]);assert(lists[l].length===rules(l).clubs,'complete league table required: '+l);assert(lists[l].every(id=>byId.has(id)&&byId.get(id).leagueId===l),'table league mismatch');}
    const titleIds=['champions','challenge','urc'].map(k=>titles[k]).filter(id=>id!==undefined&&id!==null);ids([...new Set(titleIds)]);
    if(titles.urc!==undefined&&titles.urc!==null)assert(lists.urc.slice(0,8).includes(titles.urc),'URC champion must come from its top-eight playoff field');
    const premFinalists=['prem','premFinalist'].map(k=>titles[k]).filter(id=>id!==undefined&&id!==null);
    ids(premFinalists);assert(premFinalists.every(id=>lists.prem.slice(0,4).includes(id)),'PREM finalists must come from its top-four playoff field');
    for(const id of new Set(titleIds)) {
      const c=byId.get(id);
      if(c&&c.leagueId==='accession')ineligibleTitles.push({code:'LNR_TOP14_REQUIRED',clubId:id,source:SOURCES.lnr,section:'2010'});
      else if(!c||!quotas[c.leagueId])unresolved.push({code:'TITLE_HOLDER_OUTSIDE_DOMESTIC_QUOTAS',clubId:id});
    }
    for(const l of Object.keys(quotas)) {
      const priority=[];
      if(l==='prem')priority.push(...premFinalists);
      // A URC champion seeded seventh/eighth can lose a place when a European
      // holder outside the top eight displaces a regular-season qualifier.
      if(l==='urc'&&titles.urc!==undefined&&titles.urc!==null)priority.push(titles.urc);
      for(const k of ['champions','challenge'])if(titles[k]!==undefined&&byId.has(titles[k])&&byId.get(titles[k]).leagueId===l)priority.push(titles[k]);
      assert(priority.every(id=>lists[l].includes(id)),'title holder absent from domestic table');
      selected[l]=[...new Set([...priority,...lists[l]])].slice(0,8);
    }
    const champions=Object.values(selected).flat(), championSet=new Set(champions);
    const guests=invitations===undefined?[]:invitations;
    ids(guests);assert(guests.length<=2 && guests.every(id=>byId.has(id)&&byId.get(id).leagueId==='guest'),'invalid guest invitation');
    // Invitations are annual inputs, never inferred indefinitely from the
    // immutable first-season participant list.
    if(guests.length<2)unresolved.push({code:'INVITATIONS_REQUIRED',season,missing:2-guests.length});
    const challenge=[...lists.elite.filter(id=>!championSet.has(id)),...lists.prem.filter(id=>!championSet.has(id)),...lists.urc.filter(id=>!championSet.has(id)),...guests];
    return {season,champions,challenge,byLeague:selected,invitations:guests.slice(),unresolved,ineligibleTitles,provenance:{status:'published-quota-with-game-assumptions',quotaSource:SOURCES.calendar,urcTitleHolderAllocation:{url:SOURCES.urcTitleHolder,edition:'qualification-2026/27',status:'confirmed'},premFinalistPriority:{url:SOURCES.prem,section:'3.1(c)',edition:'qualification-2027/28',status:'confirmed'},caveat:'Official URC 2026/27 qualification confirms European title-holder displacement within eight places and protection of the URC champion. Later seasons reuse this model; a complete rule for invited winners or every cross-league exception was not located.'}};
  }
  const CHALLENGE_DRAW_POLICY='balanced-challenge-v1';
  function drawBalancedChallenge(arranged,byId) {
    const from=league=>arranged.filter(id=>byId.get(id).leagueId===league);
    const elite=from('elite'),prem=from('prem'),urc=from('urc'),guests=from('guest');
    assert(elite.length===6&&prem.length===2&&urc.length===8&&guests.length===2,'balanced Challenge requires 6 TOP 14, 2 PREM, 8 URC and 2 guests');

    // Game model. Only the Scottish-Italian shield spans two federations.
    const federation=c=>c.shield==='scotland-italy'?c.country:c.shield;
    const orderIndex=new Map(arranged.map((id,index)=>[id,index]));
    const pools=[[],[],[]];
    const poolOrder=id=>[0,1,2].map(i=>(i+orderIndex.get(id))%3);
    let best=null,bestShields=Infinity,bestCountries=Infinity;
    function placeURC(index,shields,countries) {
      if(shields>bestShields||shields===bestShields&&countries>=bestCountries)return;
      if(index===urc.length){
        best=pools.map(pool=>pool.slice());bestShields=shields;bestCountries=countries;
        return;
      }
      const id=urc[index],c=byId.get(id),country=federation(c);
      for(const p of poolOrder(id)){
        const pool=pools[p];if(pool.length===3)continue;
        const neighbors=pool.map(other=>byId.get(other));
        pool.push(id);
        placeURC(index+1,shields+neighbors.filter(x=>c.shield&&c.shield===x.shield).length,
          countries+neighbors.filter(x=>country&&country===federation(x)).length);
        pool.pop();
      }
    }
    placeURC(0,0,0);
    assert(best,'no balanced Challenge pool allocation');
    elite.forEach((id,i)=>best[(i+orderIndex.get(elite[0]))%3].push(id));

    // The 3/3/2 URC split leaves 1/1/2 places. Each of the other leagues
    // contributes one club to the two-seat pool and one to a distinct pool.
    const others=arranged.filter(id=>['prem','guest'].includes(byId.get(id).leagueId));
    function placeOthers(index){
      if(index===others.length)return true;
      const id=others[index],league=byId.get(id).leagueId;
      for(const p of poolOrder(id)){
        const pool=best[p];
        if(pool.length===6||pool.some(other=>byId.get(other).leagueId===league))continue;
        pool.push(id);if(placeOthers(index+1))return true;pool.pop();
      }
      return false;
    }
    assert(placeOthers(0),'no balanced Challenge pool allocation');
    return best.map(pool=>pool.sort((a,b)=>orderIndex.get(a)-orderIndex.get(b)));
  }


  function drawPools({clubs,competitionId,participants,protectedIds=[],order,challengeDrawPolicy=null}) {
    const p=rules(competitionId), byId=validateClubs(clubs), entrants=ids(participants);
    assert(p.pools && entrants.length===p.clubs && entrants.every(id=>byId.has(id)), 'incorrect European entrants');
    const arranged=ids(order===undefined?entrants:order);
    assert(arranged.length===entrants.length && arranged.every(id=>entrants.includes(id)), 'draw order must be an entrant permutation');
    const protectedSet=new Set(ids(protectedIds));
    assert(protectedSet.size<=p.pools && [...protectedSet].every(id=>entrants.includes(id)), 'invalid protected champions');
    const pools=Array.from({length:p.pools},()=>[]);
    if(competitionId==='challenge') {
      if(challengeDrawPolicy!==null){
        assert(challengeDrawPolicy===CHALLENGE_DRAW_POLICY,'unknown Challenge draw policy');
        return drawBalancedChallenge(arranged,byId);
      }
      // Open game draw: callers supply the persisted shuffled order. No same-
      // league prohibition exists here, unlike the Champions competition.
      arranged.forEach((id,i)=>pools[i%p.pools].push(id));return pools;
    }
    assert(challengeDrawPolicy===null,'Challenge draw policy on another competition');
    assert(competitionId==='champions' && ['elite','prem','urc'].every(l=>entrants.filter(id=>byId.get(id).leagueId===l).length===8), 'Champions requires eight entrants per league');
    assert(entrants.filter(id=>byId.get(id).leagueId==='urc').every(id=>typeof byId.get(id).shield==='string'), 'URC shield required for draw');
    const protectedOrder=arranged.filter(id=>protectedSet.has(id));
    protectedOrder.forEach((id,i)=>pools[i].push(id));
    const todo=arranged.filter(id=>!protectedSet.has(id));
    function visit(index) {
      if(index===todo.length)return true;
      const id=todo[index], c=byId.get(id);
      for(let pi=0;pi<pools.length;pi++) {
        const pool=pools[pi];
        if(pool.length===6 || pool.filter(x=>byId.get(x).leagueId===c.leagueId).length===2)continue;
        if(c.leagueId==='urc' && pool.some(x=>byId.get(x).leagueId==='urc'&&byId.get(x).shield===c.shield))continue;
        pool.push(id);if(visit(index+1))return true;pool.pop();
        // TOP 14 and PREM placements cannot constrain future URC slots.
        if(c.leagueId!=='urc')break;
      }
      return false;
    }
    assert(visit(0), 'no legal Champions pool allocation for supplied entrants');return pools;
  }
  function knockoutWinner(result,competitionId) {
    rules(competitionId);
    const r=result;
    assert(r && Array.isArray(r.pair)&&r.pair.length===2&&r.pair.every(numericId)&&r.pair[0]!==r.pair[1], 'invalid knockout pair');
    assert(Array.isArray(r.score)&&r.score.length===2&&r.score.every(n=>Number.isSafeInteger(n)&&n>=0), 'invalid knockout score');
    const explicit=r.winner!==undefined&&r.winner!==null;
    const recordedMethod=typeof r.decision==='string'?r.decision:r.decision&&r.decision.method;
    if(explicit)assert(r.pair.includes(r.winner),'knockout winner outside pair');
    const scoreSide=r.score[0]===r.score[1]?null:r.score[0]>r.score[1]?0:1;
    if(scoreSide!==null) {assert(!explicit||r.winner===r.pair[scoreSide],'winner contradicts score');return {winner:r.pair[scoreSide],method:'score'};}
    if(r.afterExtraTime!==true && !(Number.isFinite(r.duration)&&r.duration>=100))return {winner:null,requires:'extra-time'};
    assert(Array.isArray(r.tries)&&r.tries.length===2&&r.tries.every(n=>Number.isSafeInteger(n)&&n>=0), 'tries required after extra time');
    if(r.tries[0]!==r.tries[1]) {const winner=r.pair[r.tries[0]>r.tries[1]?0:1];assert(!explicit||winner===r.winner,'winner contradicts tries');return {winner,method:'tries'};}
    if(['elite','accession','access'].includes(competitionId)) {
      for(const [key,method,low] of [['penalties','penalties',false],['drops','drops',false],['redCards','redCards',true]]) {
        const values=r[key];
        if(!Array.isArray(values)||values.length!==2||!values.every(n=>Number.isSafeInteger(n)&&n>=0)) {
          if(explicit&&['penalties','drops','redCards','shootout','place-kicks','kicks'].includes(recordedMethod))return {winner:r.winner,method:recordedMethod,source:'recorded-decision'};
          return {winner:null,requires:'lnr-'+key};
        }
        if(values[0]!==values[1]) {const side=(values[0]>values[1])!==low?0:1,winner=r.pair[side];assert(!explicit||winner===r.winner,'winner contradicts '+key);return {winner,method};}
      }
    }
    if(explicit) {
      assert(['shootout','place-kicks','kicks'].includes(recordedMethod),'tied knockout needs an explicit place-kick decision');
      return {winner:r.winner,method:'shootout'};
    }
    return {winner:null,requires:'place-kicks'};
  }
  function knockoutFixtures({competitionId,season,seeds,phase,results=[],date,dates={}}) {
    assert(Array.isArray(seeds),'knockout seeds array required');
    let ordered=seeds.slice();
    if(ordered.some(s=>s&&typeof s==='object'&&s.seed!==undefined)) {assert(ordered.every(s=>s&&Number.isInteger(s.seed)&&s.seed>=1)&&new Set(ordered.map(s=>s.seed)).size===ordered.length,'invalid explicit knockout seeds');ordered.sort((a,b)=>a.seed-b.seed);}
    const p=rules(competitionId), list=ids(ordered.map(s=>typeof s==='number'?s:s.clubId)), ranking=new Map(list.map((id,i)=>[id,i]));
    const phases=competitionId==='champions'||competitionId==='challenge'?['r16','quarter','semi','final']:competitionId==='urc'?['quarter','semi','final']:competitionId==='prem'?['semi','final']:competitionId==='access'?['access']:['barrage','semi','final'];
    assert(phases.includes(phase),'invalid knockout phase');
    const needed=competitionId==='access'?2:p.playoffs;assert(list.length>=needed,'insufficient knockout seeds');
    assert(Array.isArray(results),'knockout results array required');
    const seen=new Set();for(const r of results)if(r.competitionId===competitionId) {assert(typeof r.fixtureId==='string'&&!seen.has(r.fixtureId),'duplicate knockout result');seen.add(r.fixtureId);}
    const y=year(season), european=competitionId==='champions'||competitionId==='challenge';
    const euro=european?europeanWeeks({season}):null;
    const defaults=european?{r16:euro[4],quarter:euro[5],semi:euro[6],final:competitionId==='challenge'?iso(dateMs(euro[7])-DAY):euro[7]}:{barrage:`${y+1}-06-05`,quarter:`${y+1}-06-05`,semi:`${y+1}-06-12`,final:`${y+1}-06-19`,access:`${y+1}-06-26`};
    function fixturesFor(current) {
      const index=phases.indexOf(current), round=index;
      function winners(previous) {
        const previousFixtures=fixturesFor(previous);if(!previousFixtures.length)return null;
        const winners=[];
        for(const f of previousFixtures) {
          const r=results.find(r=>r.fixtureId===f.id&&r.competitionId===competitionId);
          if(!r)return null;
          assert(r.phase===previous&&r.pair[0]===f.homeId&&r.pair[1]===f.awayId,'knockout result does not match fixture');
          const decision=knockoutWinner(r,competitionId);if(decision.winner===null)return null;winners.push(decision.winner);
        }
        return winners;
      }
      let pairs;
      if(index===0) {
        if(current==='access')pairs=[[list[1],list[0]]];
        else if(current==='barrage')pairs=[[list[2],list[5]],[list[3],list[4]]];
        else if(current==='r16')pairs=Array.from({length:8},(_,i)=>[list[i],list[15-i]]);
        else if(current==='quarter')pairs=Array.from({length:4},(_,i)=>[list[i],list[7-i]]);
        else pairs=[[list[0],list[3]],[list[1],list[2]]];
      } else {
        const previous=phases[index-1], ws=winners(previous);if(!ws)return [];
        if(previous==='barrage')pairs=[[list[0],ws[1]],[list[1],ws[0]]];
        else if(previous==='r16')pairs=[[ws[0],ws[7]],[ws[1],ws[6]],[ws[2],ws[5]],[ws[3],ws[4]]];
        else if(previous==='quarter')pairs=[[ws[0],ws[3]],[ws[1],ws[2]]];
        else pairs=[[ws[0],ws[1]]];
      }
      let venuePolicy='higher-seed-home',neutral=false;
      if(current==='final'||(competitionId==='elite'&&current==='semi')) {venuePolicy=competitionId==='urc'?'urc-designated':european?'epcr-designated':'organiser-designated';neutral=competitionId!=='urc';}
      if(competitionId==='champions'&&current==='semi'){venuePolicy='epcr-designated';neutral=true;}
      if(competitionId==='challenge'&&current==='semi')venuePolicy='higher-seed-home-in-europe';
      if(current==='access')venuePolicy='accession-finalist-home';
      const day=(current===phase&&date)||dates[current]||defaults[current];dateMs(day);
      return pairs.map((pair,slot)=>{
        if(current!=='access'&&ranking.get(pair[0])>ranking.get(pair[1]))pair=[pair[1],pair[0]];
        const designated=venuePolicy.includes('designated')||venuePolicy==='higher-seed-home-in-europe';
        return {id:`${competitionId}:${y}:${current}:${round}:${slot}`,competitionId,season,phase:current,round,date:day,homeId:pair[0],awayId:pair[1],neutral,venuePolicy,venueHostId:neutral?null:pair[0],venueDesignationPending:designated,scheduleSource:'generated-game',...(venuePolicy==='higher-seed-home-in-europe'?{venueRegion:'Europe'}:{})};
      });
    }
    return fixturesFor(phase);
  }
  return {CHALLENGE_DRAW_POLICY,rules,regularFixtures,table,europeanWeeks,weekKey,poolStage,poolQualifiers,qualifyEurope,drawPools,knockoutWinner,knockoutFixtures};
}
module.exports = { factory };
