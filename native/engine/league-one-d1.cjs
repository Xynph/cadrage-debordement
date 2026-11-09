'use strict';

function factory(raw) {
  const ledger = JSON.parse(JSON.stringify(raw));
  const rulesId = 'japan-rugby-league-one-2026-27-v1';
  const competitionId = 'jlo-d1', secondDivision = 'jlo-d2', promotionId = 'jlo-d1-d2';
  const regularDatePolicy = 'earliest-published-option', playoffDatePolicy = 'simulation-weekends-2026-27';
  const phases = Object.freeze(['quarter','semi','third-place','final']);
  const DAY = 86400000;
  const check = (ok, why) => { if (!ok) throw Error('League One — ' + why); };
  const integer = (n,min,max) => Number.isSafeInteger(n) && n>=min && n<=max;
  const clubId = v => integer(v,0,10000) || typeof v==='string' && /^[A-Za-z0-9:_-]{1,120}$/.test(v);
  const two = (items,valid) => Array.isArray(items) && items.length===2 && items.every(valid);
  const numbers = (items,max=250) => two(items,n=>integer(n,0,max));
  const samePair = (a,b) => Array.isArray(a) && a.length===2 && a[0]===b[0] && a[1]===b[1];
  const distinct = values => new Set(values).size===values.length;
  const idOrder = (a,b) => String(a)<String(b)?-1:String(a)>String(b)?1:0;
  const date = value => typeof value==='string' && /^\d{4}-\d{2}-\d{2}$/.test(value)
    && Number.isFinite(Date.parse(value)) && new Date(value).toISOString().slice(0,10)===value;
  check(ledger?.schema==='jlo-d1-calendar-v1' && ledger.season===2026 && ledger.clubKeys?.length===12
    && distinct(ledger.clubKeys) && ledger.regular?.length===108, 'calendrier de l’édition 2026-27 invalide.');
  const clubKeys = Object.freeze(ledger.clubKeys.slice());
  const week = (day,anchor) => Math.floor((Date.parse(day)-Date.parse(anchor))/(7*DAY));
  const monday = anchor => date(anchor) && new Date(anchor).getUTCDay()===1;

  function calendarFixtures({clubs,season=2026,anchor='2026-08-31',datePolicy}={}) {
    check(season===ledger.season,'saison sans calendrier officiel dans cette édition.');
    check(monday(anchor),'date d’ancrage hebdomadaire invalide.');
    check(datePolicy===undefined || datePolicy===regularDatePolicy,'politique de date inconnue.');
    check(Array.isArray(clubs) && clubs.length===12 && clubs.every(c=>clubId(c?.id) && clubKeys.includes(c.key))
      && distinct(clubs.map(c=>c.id)) && distinct(clubs.map(c=>c.key)), 'les douze clubs D1 doivent correspondre aux clés du calendrier.');
    const byKey = new Map(clubs.map(c=>[c.key,c.id]));
    return ledger.regular.map(m=>{
      const chosen = m.date ?? (datePolicy ? m.dateOptions[0] : null);
      const w = week(m.dateOptions[0],anchor);
      check(w>=0 && m.dateOptions.every(d=>week(d,anchor)===w),'fenêtre publiée sur des semaines distinctes.');
      return {id:m.id,competitionId,season,phase:'league',round:m.roundNumber-1,slot:m.slot,week:w,
        homeId:byKey.get(m.homeKey),awayId:byKey.get(m.awayKey),date:chosen,dateOptions:m.dateOptions.slice(),
        dateSource:m.date?'published':chosen?'simulation-earliest-option':'published-window',kickoffUtc:m.kickoffUtc};
    });
  }

  function scoring(result, requireConversions=false) {
    const {score,tries} = result;
    const conversions = result.conversions ?? (Array.isArray(result.stats) ? result.stats.map(s=>s?.conversions) : undefined);
    check(numbers(score) && numbers(tries,50) && tries.every((n,i)=>n*5<=score[i]), 'score ou essais invalides.');
    if (conversions!==undefined || requireConversions) check(numbers(conversions,50) && conversions.every((n,i)=>n<=tries[i] && tries[i]*5+n*2<=score[i]),'transformations invalides.');
    return {score:score.slice(),tries:tries.slice(),conversions:conversions?.slice() ?? [0,0]};
  }

  function bonuses(score,tries) {
    const attacking = score.map((s,i)=>+(s>score[1-i] && tries[i]-tries[1-i]>=3));
    const defending = score.map((s,i)=>+(s<score[1-i] && score[1-i]-s<=7));
    const points = score.map((s,i)=>(s>score[1-i]?4:s===score[1-i]?2:0)+attacking[i]+defending[i]);
    return {points,attacking,defending};
  }

  function resultPoints(result) {
    const {score,tries}=scoring(result);
    return bonuses(score,tries).points;
  }

  function pairValid(pair) { return two(pair,clubId) && distinct(pair); }

  function fault(result) {
    const ids = result.fault;
    check(pairValid(result.pair) && Array.isArray(ids) && ids.length<=2 && distinct(ids) && ids.every(i=>result.pair.includes(i)), 'responsabilité d’annulation invalide.');
    return ids;
  }

  function leagueResult(result) {
    if (result.status==='cancelled') {
      const causes = fault(result), score = [0,0], tries = [0,0], conversions = [0,0], points = [0,0];
      const outcome = ['no-contest','no-contest'];
      if (causes.length<2) for (const i of [0,1]) {
        const responsible = causes.includes(result.pair[i]);
        score[i] = responsible?0:14;
        tries[i] = conversions[i] = responsible?0:2;
        points[i] = causes.length===0?2:responsible?0:4;
        outcome[i] = causes.length===0?'draw':responsible?'loss':'win';
      }
      return {score,tries,conversions,points,outcome,attacking:[0,0],defending:[0,0]};
    }
    check(result.status===undefined || result.status==='played','état de résultat de championnat invalide.');
    const value = scoring(result);
    const outcome = value.score.map((s,i)=>s>value.score[1-i]?'win':s<value.score[1-i]?'loss':'draw');
    return {...value,...bonuses(value.score,value.tries),outcome};
  }

  function headToHead(group, games, field) {
    const mini = new Map(group.map(id=>[id,{played:0,value:0}]));
    for (const {pair,sport} of games) {
      if (!pair.every(id=>mini.has(id))) continue;
      for (const [i,id] of pair.entries()) {
        const row = mini.get(id);
        row.played++;
        row.value += field==='points'?sport.points[i]:field==='w'?+(sport.outcome[i]==='win'):
          field==='pd'?sport.score[i]-sport.score[1-i]:sport.tries[i];
      }
    }
    const counts = new Set([...mini.values()].map(r=>r.played));
    const average = group.length>=3 && counts.size>1;
    if (average && counts.has(0)) return () => [0,1];
    return id => {const v=mini.get(id);return [v.value,average?v.played:1];};
  }

  function partition(group, values) {
    if (group.length<2) return [group];
    const compare = (a,b) => {
      const [nA,dA]=values(a),[nB,dB]=values(b);
      return nB*dA-nA*dB;
    };
    const result=[];
    for (const id of group.slice().sort(compare)) {
      const last = result.at(-1);
      if (last && compare(last[0],id)===0) last.push(id);
      else result.push([id]);
    }
    return result;
  }

  function table(clubIds, results, id=competitionId, {season=2026,fixtures,drawOrder}={}) {
    const count = id===competitionId?12:id===secondDivision?8:0;
    check(count && Array.isArray(clubIds) && clubIds.length===count && clubIds.every(clubId) && distinct(clubIds), 'clubs du classement invalides.');
    check(Array.isArray(results), 'historique de championnat invalide.');
    const rows = new Map(clubIds.map(id=>[id,{id,played:0,w:0,d:0,l:0,pf:0,pa:0,pd:0,tf:0,ta:0,points:0,bp:0,bpT:0,bpL:0}]));
    const seen = new Set(), games=[];
    const scheduled = fixtures===undefined?null:new Map(fixtures.map(f=>[f.id,f]));
    if (scheduled) check(scheduled.size===fixtures.length,'fixture de championnat dupliquée.');
    for (const result of results) {
      if (result.competitionId!==id || result.phase!=='league' || result.season!==season) continue;
      check(typeof result.fixtureId==='string' && result.fixtureId && !seen.has(result.fixtureId),'résultat de championnat absent ou dupliqué.');
      check(pairValid(result.pair) && result.pair.every(c=>rows.has(c)), 'paire de championnat hors des clubs.');
      if (scheduled) {
        const f=scheduled.get(result.fixtureId);
        check(f?.competitionId===id && f.season===season && f.phase==='league' && samePair(result.pair,[f.homeId,f.awayId]), 'résultat hors fixture de championnat.');
      }
      seen.add(result.fixtureId);
      const sport=leagueResult(result);
      games.push({pair:result.pair,sport});
      for (const [i,team] of result.pair.entries()) {
        const r=rows.get(team), other=1-i;
        r.played++;r.w+=+(sport.outcome[i]==='win');r.d+=+(sport.outcome[i]==='draw');r.l+=+(sport.outcome[i]==='loss');
        r.pf+=sport.score[i];r.pa+=sport.score[other];r.pd=r.pf-r.pa;r.tf+=sport.tries[i];r.ta+=sport.tries[other];
        r.points+=sport.points[i];r.bpT+=sport.attacking[i];r.bpL+=sport.defending[i];r.bp=r.bpT+r.bpL;
        check(r.played<=(id===competitionId?18:14),'nombre de résultats supérieur à la saison.');
      }
    }
    const total = field => () => id=>[rows.get(id)[field],1];
    const versus = field => group => headToHead(group,games,field);
    const rules = [total('points'),total('w'),versus('points'),versus('w'),versus('pd'),total('pd'),versus('tf'),total('tf')];
    if (drawOrder!==undefined) {
      check(Array.isArray(drawOrder) && drawOrder.length===count && distinct(drawOrder) && drawOrder.every(c=>rows.has(c)), 'tirage de classement incomplet.');
      const draw=new Map(drawOrder.map((c,i)=>[c,-i]));
      rules.push(()=>c=>[draw.get(c),1]);
    }
    let groups=[clubIds];
    for (const criterion of rules) groups=groups.flatMap(group=>partition(group,criterion(group)));
    const ranked=[];
    for (const group of groups) {
      const rank=ranked.length+1;
      for (const id of group.slice().sort(idOrder)) ranked.push({...rows.get(id),rank,sportingTie:group.length>1});
    }
    return ranked;
  }

  function fullTable(rows,count,games,label) {
    check(Array.isArray(rows) && rows.length===count && distinct(rows.map(r=>r?.id)) && rows.every(r=>clubId(r?.id)
      && r.played===games && integer(r.rank,1,count) && typeof r.sportingTie==='boolean'), `classement ${label} incomplet.`);
    return rows.slice().sort((a,b)=>a.rank-b.rank);
  }

  function rowsAt(rows,ranks,label) {
    return ranks.map(rank=>{
      const found=rows.filter(r=>r.rank===rank);
      check(found.length===1 && !found[0].sportingTie,`classement ${label} non départagé au rang ${rank}.`);
      return found[0].id;
    });
  }

  function playoffSeeds(rows) {
    return rowsAt(fullTable(rows,12,18,'D1'),[1,2,3,4,5,6],'D1');
  }

  function nextMatchPeriod({period,score}={}) {
    check(numbers(score) && ['regulation','golden'].includes(period),'période de play-off invalide.');
    if (score[0]!==score[1]) return {period:'finished',winnerSide:score[0]>score[1]?0:1};
    return period==='regulation'?{period:'golden',minutes:10,rest:5}:{period:'shootout',kickers:5,rest:5};
  }

  function shootoutLocation(round) {
    check(integer(round,0,999),'tour de tirs invalide.');
    return [1,2,3,1,2][round%5];
  }

  function shootoutWinner(q,eligible) {
    check(q && integer(q.first,0,1) && two(q.kickers,k=>Array.isArray(k) && k.length===5 && k.every(clubId))
      && distinct(q.kickers.flat()) && numbers(q.score,1000) && Array.isArray(q.attempts) && q.attempts.length>0 && q.attempts.length<=2000,
    'preuve de tirs invalide.');
    if (eligible!==undefined) check(two(eligible,Array.isArray) && q.kickers.every((team,i)=>team.every(p=>eligible[i].includes(p))),'tireur non éligible.');
    const tally=[0,0],taken=[0,0];
    let winner=null;
    for (const [i,a] of q.attempts.entries()) {
      const round=Math.floor(i/2),side=i%2===0?q.first:1-q.first;
      check(winner===null && a?.side===side && a.playerId===q.kickers[side][round%5] && a.location===shootoutLocation(round)
        && typeof a.made==='boolean','séquence de tirs incohérente.');
      taken[side]++;
      if (a.made) tally[side]++;
      if (round<5) {
        if (tally[0]>tally[1]+5-taken[1]) winner=0;
        if (tally[1]>tally[0]+5-taken[0]) winner=1;
      } else if (i%2===1 && tally[0]!==tally[1]) winner=tally[0]>tally[1]?0:1;
    }
    check(winner!==null && samePair(tally,q.score),'vainqueur des tirs incohérent.');
    return winner;
  }

  function knockoutWinner(result,fixture) {
    check(fixture?.competitionId===competitionId && phases.includes(fixture.phase) && two(fixture.seeds,n=>integer(n,1,6))
      && distinct(fixture.seeds) && result?.fixtureId===fixture.id && result.competitionId===competitionId && result.phase===fixture.phase
      && result.season===fixture.season && samePair(result.pair,[fixture.homeId,fixture.awayId]), 'résultat hors fixture de play-off.');
    const status=result.status??'played', higher=fixture.seeds[0]<fixture.seeds[1]?0:1;
    let side,method;
    if (status==='cancelled-before-kickoff') { side=higher;method='higher-seed'; }
    else {
      const {score,tries,conversions}=scoring(result,status==='cancelled-after-kickoff');
      if (status==='cancelled-after-kickoff') {
        const rule=[['score',score],['tries',tries],['conversions',conversions]].find(([,v])=>v[0]!==v[1]);
        side=rule?(rule[1][0]>rule[1][1]?0:1):higher;
        method=rule?rule[0]:'higher-seed';
      } else {
        check(status==='played','état de play-off invalide.');
        const o=result.overtime;
        if (o!==undefined) check(o && integer(o.start,80,230) && integer(o.end,o.start+1,240)
          && numbers(o.regulationScore) && o.regulationScore[0]===o.regulationScore[1],'preuve de prolongation invalide.');
        if (score[0]!==score[1]) {
          side=score[0]>score[1]?0:1;
          if (o!==undefined) {
            const mark=o.firstScore, delta=mark?.kind==='try'?5:['goal','drop'].includes(mark?.kind)?3:0;
            check(delta && mark.side===side && mark.minute===o.end && score[side]===o.regulationScore[side]+delta
              && score[1-side]===o.regulationScore[1-side],'première marque incompatible avec le score.');
          }
          check(result.shootout===undefined,'tirs déclarés malgré un score décisif.');
          method=o===undefined?'score':'golden-score';
        } else {
          check(o && o.end>=o.start+10 && o.firstScore===null && samePair(o.regulationScore,score),'tirs sans prolongation achevée.');
          side=shootoutWinner(result.shootout,result.shootout?.eligible);
          method='shootout';
        }
      }
    }
    const winner=result.pair[side];
    check(result.winner===undefined || result.winner===winner,'vainqueur annoncé incohérent.');
    return {winner,loser:result.pair[1-side],method};
  }

  function stageFixture(season,seeds,phase,slot,pair,datePolicy,anchor) {
    const final=phase==='final', rounds={quarter:18,semi:19,'third-place':20,final:20};
    const simulated={quarter:['2027-05-22','2027-05-23'],semi:['2027-05-29','2027-05-30'],'third-place':['2027-06-05']};
    const date=final?ledger.playoffs.final:datePolicy?simulated[phase][slot-1]:null;
    const window=[ledger.playoffs.from,ledger.playoffs.to];
    return {id:`jlo:2026-27:d1:${phase}:m0${slot}`,competitionId,season,phase,round:rounds[phase],slot,week:date?week(date,anchor):null,
      homeId:pair[0],awayId:pair[1],seeds:pair.map(id=>seeds.indexOf(id)+1),date, dateWindow:window,
      dateSource:final?'published':date?'simulation-window':'published-phase-window'};
  }

  function stageDecisions(fixtures,results) {
    const matching=results.filter(r=>r.competitionId===competitionId && r.season===2026 && r.phase===fixtures[0].phase);
    const decisions=new Map();
    for (const r of matching) {
      const fixture=fixtures.find(f=>f.id===r.fixtureId);
      check(fixture && !decisions.has(fixture.id),'résultat de play-off inconnu ou dupliqué.');
      decisions.set(fixture.id,knockoutWinner(r,fixture));
    }
    return fixtures.every(f=>decisions.has(f.id))?fixtures.map(f=>decisions.get(f.id)):null;
  }

  function knockoutFixtures({season=2026,seeds,phase,results=[],datePolicy,anchor='2026-08-31'}={}) {
    check(season===ledger.season && phases.includes(phase),'phase ou saison de play-off invalide.');
    check(datePolicy===undefined || datePolicy===playoffDatePolicy,'politique de phase finale inconnue.');
    check(monday(anchor) && week(ledger.playoffs.from,anchor)>=0,'date d’ancrage hebdomadaire invalide.');
    check(Array.isArray(seeds) && seeds.length===6 && seeds.every(clubId) && distinct(seeds) && Array.isArray(results),'têtes de série ou résultats invalides.');
    const [first,second,third,fourth,fifth,sixth]=seeds;
    const make=(kind,pairs)=>pairs.map((pair,i)=>stageFixture(season,seeds,kind,i+1,pair,datePolicy,anchor));
    const quarters=make('quarter',[[third,sixth],[fourth,fifth]]);
    if (phase==='quarter') return quarters;
    const q=stageDecisions(quarters,results);
    if (!q) return [];
    const semis=make('semi',[[first,q[1].winner],[second,q[0].winner]]);
    if (phase==='semi') return semis;
    const s=stageDecisions(semis,results);
    if (!s) return [];
    return make(phase,[s.map(r=>phase==='final'?r.winner:r.loser)]);
  }

  function finalRanking(regular,results) {
    const rows=fullTable(regular,12,18,'D1'),seeds=playoffSeeds(rows);
    const get=phase=>knockoutFixtures({seeds,phase,results});
    const f=get('final'),b=get('third-place');
    check(f.length===1 && b.length===1,'phase finale incomplète.');
    const final=stageDecisions(f,results),bronze=stageDecisions(b,results);
    check(final && bronze,'finale ou troisième place sans résultat.');
    const q=stageDecisions(get('quarter'),results);
    const eliminated=q.map(r=>r.loser).sort((a,b)=>seeds.indexOf(a)-seeds.indexOf(b));
    const order=[final[0].winner,final[0].loser,bronze[0].winner,bronze[0].loser,...eliminated];
    return [...order.map((id,i)=>{const row=rows.find(r=>r.id===id);return {...row,regularRank:row.rank,rank:i+1};}),...rows.slice(6)];
  }

  function promotionPairs(division1,division2) {
    const d1=fullTable(division1,12,18,'D1'),d2=fullTable(division2,8,14,'D2');
    check(distinct([...d1,...d2].map(r=>r.id)), 'un club est présent dans les deux divisions.');
    const upper=rowsAt(d1,[11,12],'D1'),lower=rowsAt(d2,[2,1],'D2');
    return upper.map((id,i)=>({id:`jlo:2026-27:d1-d2:p0${i+1}`,competitionId:promotionId,season:2026,
      upperId:id,lowerId:lower[i],upperRank:11+i,lowerRank:2-i,dateWindow:[ledger.promotion.from,ledger.promotion.to]}));
  }

  function validatePairing(p) {
    check(p?.competitionId===promotionId && p.season===2026 && pairValid([p.upperId,p.lowerId])
      && [11,12].includes(p.upperRank) && p.lowerRank===13-p.upperRank && p.id===`jlo:2026-27:d1-d2:p0${p.upperRank-10}`
      && samePair(p.dateWindow,[ledger.promotion.from,ledger.promotion.to]),'paire de barrage invalide.');
  }

  function promotionFixtures(pairing,{firstHomeId,dates,anchor='2026-08-31'}={}) {
    validatePairing(pairing);
    const ids=[pairing.upperId,pairing.lowerId];
    check(ids.includes(firstHomeId),'hôte de la première manche requis.');
    check(monday(anchor) && week(pairing.dateWindow[0],anchor)>=0,'date d’ancrage hebdomadaire invalide.');
    check(dates===undefined || two(dates,date) && dates[0]<dates[1] && dates[0]>=pairing.dateWindow[0] && dates[1]<=pairing.dateWindow[1],
      'dates de barrage hors fenêtre.');
    const ordered=[firstHomeId,ids.find(id=>id!==firstHomeId)];
    return [0,1].map(i=>({id:`${pairing.id}:m0${i+1}`,competitionId:promotionId,season:2026,phase:'promotion',leg:i+1,
      homeId:ordered[i],awayId:ordered[1-i],date:dates?.[i]??null,week:dates?week(dates[i],anchor):null,
      dateWindow:pairing.dateWindow.slice(),dateSource:dates?'supplied':'published-window'}));
  }

  function promotionOutcome(pairing,legs) {
    validatePairing(pairing);
    check(Array.isArray(legs) && legs.length<=2, 'deux manches de barrage au maximum.');
    const ids=[pairing.upperId,pairing.lowerId], first=legs[0], second=legs[1];
    if (!first) {check(!second,'seconde manche sans première manche.');return null;}
    check(pairValid(first.pair) && first.pair.every(id=>ids.includes(id)) && (!second || samePair(second.pair,[first.pair[1],first.pair[0]])),
      'paires de barrage incompatibles.');
    const observed=[first,second].map(leg=>{
      if (!leg) return null;
      if (leg.status==='cancelled') return {leg,faults:fault(leg),sport:null};
      check(leg.status===undefined || leg.status==='played','état de manche invalide.');
      return {leg,faults:[],sport:scoring(leg,true)};
    });
    const firstFault=observed[0].faults;
    const decision=(winner,method,metrics=null)=>({winner,upperNext:winner,lowerNext:ids.find(id=>id!==winner),
      promoted:winner===pairing.lowerId,method,metrics});
    if (firstFault.length===1) {
      check(!second,'second match interdit après responsabilité unique en première manche.');
      return decision(ids.find(id=>id!==firstFault[0]),'cancellation-fault');
    }
    if (!second) return null;
    const secondFault=observed[1].faults;
    if (secondFault.length===1) return decision(ids.find(id=>id!==secondFault[0]),'cancellation-fault');
    const stats=new Map(ids.map(id=>[id,{points:0,wins:0,difference:0,tries:0,conversions:0}]));
    for (const {leg,sport} of observed) {
      if (!sport) continue;
      const {score,tries,conversions}=sport,points=bonuses(score,tries).points;
      for (const [i,id] of leg.pair.entries()) {
        const row=stats.get(id);
        row.points+=points[i];row.wins+=+(score[i]>score[1-i]);row.difference+=score[i]-score[1-i];
        row.tries+=tries[i];row.conversions+=conversions[i];
      }
    }
    const [upper,lower]=ids.map(id=>stats.get(id));
    const method=Object.keys(upper).find(k=>upper[k]!==lower[k]);
    return decision(method && lower[method]>upper[method]?pairing.lowerId:pairing.upperId,method??'incumbent',{upper,lower});
  }

  return Object.freeze({rulesId,competitionId,secondDivision,promotionId,regularDatePolicy,playoffDatePolicy,clubKeys,phases,promotionWindow:Object.freeze([ledger.promotion.from,ledger.promotion.to]),
    calendarFixtures,regularFixtures:calendarFixtures,resultPoints,leagueResult,table,playoffSeeds,nextMatchPeriod,
    shootoutLocation,shootoutWinner,knockoutWinner,knockoutFixtures,finalRanking,promotionPairs,promotionFixtures,promotionOutcome});
}

module.exports = {factory,...factory(require('./jlo-d1-calendar-2026-27-public.json'))};
