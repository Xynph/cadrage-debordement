'use strict';

// Article 7 of the 2026-27 League One manual. The existing match clock,
// teams and action recorder stay responsible for the played rugby.
module.exports = function japanMatchFactory(rules) {
  const editions = {3:'rugby-world-2026-11-09-japan-v3',4:'rugby-world-2026-11-09-nationale-v4',5:'rugby-world-2026-11-09-champ-v5'};
  const cause = 'jlo-golden';
  const sportKeys = ['score','tries','goals','goalAttempts','conversions','conversionAttempts'];
  const check = (ok,reason) => { if (!ok) throw Error('League One — ' + reason); };
  const integer = (v,min,max) => Number.isSafeInteger(v) && v>=min && v<=max;
  const pair = (v,max) => Array.isArray(v) && v.length===2 && v.every(n=>integer(n,0,max));
  const equal = (a,b) => JSON.stringify(a)===JSON.stringify(b);
  const keys = (v,allowed) => v!==null && typeof v==='object' && !Array.isArray(v)
    && Object.keys(v).length===allowed.length && allowed.every(k=>Object.hasOwn(v,k));
  const tied = score => score[0]===score[1];
  const playerId = id => typeof id==='string' && /^[A-Za-z0-9:_-]{1,180}$/.test(id);
  const isFixture = f => f?.competitionId===rules.competitionId && rules.phases.includes(f.phase);

  function applies(l,s=S) {
    return isFixture(l?.worldContext) && editions[s?.worldMode?.version] && s.commonDatabase?.id===editions[s.worldMode.version]
      && typeof CDWorldCareer!=='undefined' && CDWorldCareer.active(s)===true;
  }

  function sport(r) {
    check(pair(r.score,250) && pair(r.tries,50) && Array.isArray(r.stats) && r.stats.length===2 && r.stats.every(s=>s && typeof s==='object'),
      'statistiques de match invalides.');
    return {score:r.score.slice(),tries:r.tries.slice(),...Object.fromEntries(sportKeys.slice(2).map(k=>[k,r.stats.map(s=>s[k])]))};
  }

  function sportValid(values,skipConversion=null) {
    check(keys(values,sportKeys) && pair(values.score,250) && pair(values.tries,50) && sportKeys.slice(2).every(k=>pair(values[k],1000)),
      'preuve de score invalide.');
    for (const side of [0,1]) {
      check(values.goals[side]<=values.goalAttempts[side] && values.conversions[side]<=values.conversionAttempts[side]
        && values.conversionAttempts[side]===values.tries[side]-(skipConversion===side?1:0)
        && values.score[side]===values.tries[side]*5+values.conversions[side]*2+values.goals[side]*3,'score incompatible avec les actions.');
    }
  }

  function eligiblePlayers(l,i) {
    return activePlayers(l,i).filter(p=>!l.sheets[i].sentOff.includes(p.id));
  }

  function playShootout(l) {
    const eligible=[0,1].map(i=>eligiblePlayers(l,i));
    const players=eligible.map(list=>list.slice().sort((a,b)=>skill(b,'goal')-skill(a,'goal') || a.id.localeCompare(b.id)).slice(0,5));
    check(players.every(team=>team.length===5),'cinq buteurs éligibles requis par équipe.');
    const q={first:rand(0,1),end:0,rest:5,eligible:eligible.map(list=>list.map(p=>p.id)),
      kickers:players.map(list=>list.map(p=>p.id)),score:[0,0],attempts:[]};
    const taken=[0,0];
    let winner=null;
    for (let round=0;round<1000 && winner===null;round++) {
      const location=rules.shootoutLocation(round), y=location===1?35:location===2?15:55;
      const {distance,angle}=goalKickGeometry(true,y);
      for (const side of [q.first,1-q.first]) {
        const p=players[side][round%5];
        const chance=clamp(.23+skill(p,'goal',true)*.006-Math.max(0,distance-25)*.005-angle*.13
          +(unit(l,side,'mental')-70)*.001-(l.weather==='Vent'?.16:l.weather==='Pluie'?.06:0),.22,.93);
        const made=Math.random()<chance;
        q.attempts.push({side,playerId:p.id,location,made});taken[side]++;
        if (made) q.score[side]++;
        if (round<5) {
          if (q.score[0]>q.score[1]+5-taken[1]) winner=0;
          if (q.score[1]>q.score[0]+5-taken[0]) winner=1;
        }
        if (winner!==null) break;
      }
      if (round>=5 && !tied(q.score)) winner=q.score[0]>q.score[1]?0:1;
    }
    check(winner!==null && rules.shootoutWinner(q,q.eligible)===winner,'séance de tirs sans vainqueur valide.');
    return {winner,record:q};
  }

  function decide(l,side,method,shootout) {
    l.winner=l.pair[side];
    l.decision={method,extraTime:Boolean(l.japanExtra),redCards:l.sheets.map(sh=>sh.redCards.length),...(shootout?{shootout}:{})};
    if (shootout) addEvent(l,`${S.clubs[l.winner].abbr} remporte la séance de tirs au but.`,'end');
  }

  function finish(l) {
    check(applies(l),'contexte de play-off D1 Japon v3 requis.');
    const p=l.japanExtra;
    const step=rules.nextMatchPeriod({period:p?'golden':'regulation',score:l.score});
    if (p) {check(p.end===null,'prolongation déjà close.');p.end=l.minute;}
    if (step.period==='finished') {
      decide(l,step.winnerSide,p?'golden-score':'score');
      return false;
    }
    if (step.period==='shootout') {
      const {winner,record}=playShootout(l);
      decide(l,winner,'shootout',record);
      return false;
    }
    const kickoff=rand(0,1);
    l.japanExtra={version:1,rules:rules.rulesId,start:l.minute,limit:l.minute+step.minutes,rest:step.rest,kickoff,
      regulation:sport(l),firstScore:null,end:null};
    l.flow.fullEnd=l.japanExtra.limit;
    l.flow.ballDead=false;
    addEvent(l,'Prolongation de dix minutes. La première marque décide du match.','break');
    check(performKickRestart(l,'kickoff',kickoff,cause,1-kickoff),'reprise de prolongation refusée.');
    return true;
  }

  function golden(l) { return applies(l) && !l.finished && l.japanExtra?.end===null ? l.japanExtra : null; }

  let installed=false;
  function installHooks() {
    if (installed) return;
    installed=true;
    const oldCapture=captureMatchAction,oldRegister=registerRestart,oldScored=flowScored,oldTry=scoreTry;
    captureMatchAction=function(l,type,meta) {
      if (l.userSide<0 && (type==='try'||type==='goal') && golden(l) && integer(meta?.team,0,1)) {
        return oldCapture({...l,userSide:meta.team},type,meta);
      }
      return oldCapture.apply(this,arguments);
    };
    registerRestart=function(l,kind,team,at,reason,by,origin) {
      if (!applies(l) || reason!==cause) return oldRegister.apply(this,arguments);
      const p=golden(l);
      check(p && kind==='kickoff' && team===p.kickoff && l.minute===p.start,'reprise japonaise hors prolongation.');
      const action=oldRegister(l,kind,team,at,'extra-first',by,origin);
      if (action) action.cause=cause;
      return action;
    };
    flowScored=function(l,side) {
      const p=golden(l);
      if (!p) return oldScored.apply(this,arguments);
      const event=l.events.at(-1);
      check(!p.firstScore && (event?.type==='try'||event?.type==='goal') && event.min===l.minute && event.scene?.team===side,
        'première marque sans action causale.');
      p.firstScore={kind:event.type,side,minute:l.minute};
      endFlowPeriod(l);
      return true;
    };
    scoreTry=function(l,side,origin,startAt=l.territory) {
      if (!golden(l)) return oldTry.apply(this,arguments);
      if (!beforeTryUnderAdvantage(l,side)) return;
      l.tries[side]++;l.score[side]+=5;
      const scorer=actionPlayer(l,side);
      addEvent(l,`${S.clubs[l.pair[side]].abbr} · Essai décisif${scorer?' de '+scorer.name:''}. ${l.score.join(' – ')}.`,'try',
        {kind:'try',team:side,actor:scorer?.id||null,from:{x:startAt,y:35},to:{x:attackingGoal(side),y:35},possession:side});
      flowScored(l,side);
    };
  }

  function historyFields(l) { return applies(l) && l.japanExtra ? {japanExtra:JSON.parse(JSON.stringify(l.japanExtra))} : {}; }
  function restartAllowed(r,l) { return r?.kind==='kickoff' && r.cause===cause && r.minute===l.japanExtra?.start && r.team===l.japanExtra?.kickoff; }
  function flowBoundary(l) { return l.japanExtra?.limit; }
  function earlyFinish(l) { return Boolean(l.japanExtra?.firstScore && l.japanExtra.end===l.minute); }

  function validateExtra(p,now,minute,finished) {
    check(keys(p,['version','rules','start','limit','rest','kickoff','regulation','firstScore','end']) && p.version===1 && p.rules===rules.rulesId
      && integer(p.start,80,230) && p.start<=minute && p.limit===p.start+10 && p.rest===5 && integer(p.kickoff,0,1),'chronologie de prolongation invalide.');
    sportValid(p.regulation);
    check(tied(p.regulation.score),'prolongation après un score décisif.');
    const mark=p.firstScore;
    if (finished) check(p.end===minute && p.end>p.start && (mark!==null || p.end>=p.limit),'durée effective de prolongation invalide.');
    else check(p.end===null && mark===null,'prolongation close avant la fin.');
    if (mark!==null) check(keys(mark,['kind','side','minute']) && (mark.kind==='try'||mark.kind==='goal')
      && integer(mark.side,0,1) && mark.minute===p.end,'première marque incohérente.');
    sportValid(now,mark?.kind==='try'?mark.side:null);
    const before=p.regulation;
    check(sportKeys.every(k=>now[k].every((n,i)=>n>=before[k][i])),'compteurs sportifs rétroactifs.');
    if (!mark) check(equal(now.score,before.score),'score modifié sans première marque.');
    else {
      const side=mark.side,other=1-side,isTry=mark.kind==='try';
      check(now.score[side]===before.score[side]+(isTry?5:3) && now.score[other]===before.score[other]
        && now.tries[side]===before.tries[side]+(isTry?1:0) && now.goals[side]===before.goals[side]+(isTry?0:1)
        && equal(now.conversions,before.conversions) && equal(now.conversionAttempts,before.conversionAttempts),
      'première marque incompatible avec le score et les actions.');
    }
  }

  function validateDecision(r,f,live) {
    const p=r.japanExtra,d=r.decision,isShootout=tied(r.score);
    check(keys(d,isShootout?['method','extraTime','redCards','shootout']:['method','extraTime','redCards']) && d.extraTime===Boolean(p)
      && pair(d.redCards,23) && r.pair.includes(r.winner),'décision éliminatoire incomplète.');
    if (live) check(equal(d.redCards,live.sheets.map(sh=>sh.redCards.length)),'exclusions différentes de la feuille.');
    const q=d.shootout;
    if (isShootout) {
      check(keys(q,['first','end','rest','eligible','kickers','score','attempts']) && integer(q.end,0,1) && q.rest===5
        && Array.isArray(q.eligible) && q.eligible.length===2 && q.eligible.every(list=>Array.isArray(list) && list.length>=5
          && list.length<=15 && new Set(list).size===list.length && list.every(playerId))
        && new Set(q.eligible.flat()).size===q.eligible[0].length+q.eligible[1].length
        && Array.isArray(q.attempts) && q.attempts.every(a=>keys(a,['side','playerId','location','made'])),'preuve de tirs invalide.');
      if (live) check(equal(q.eligible,[0,1].map(i=>eligiblePlayers(live,i).map(p=>p.id))),'tireurs incompatibles avec la feuille.');
    }
    const overtime=p?{start:p.start,end:p.end,regulationScore:p.regulation.score,firstScore:p.firstScore}:undefined;
    const official=rules.knockoutWinner({fixtureId:f.id,competitionId:f.competitionId,phase:f.phase,season:f.season,
      pair:r.pair,score:r.score,tries:r.tries,stats:r.stats,winner:r.winner,overtime,shootout:q},f);
    check(d.method===official.method,'critère de victoire différent de la preuve.');
  }

  function validateResult(r,f,live=null) {
    check(isFixture(f) && equal(r.pair,[f.homeId,f.awayId]) && ['Sec','Vent','Pluie'].includes(r.weather)
      && r.srpExtra===undefined && (r.status===undefined||r.status==='played'),'résultat japonais hors calendrier.');
    if (!live) check(r.fixtureId===f.id && r.competitionId===f.competitionId && r.phase===f.phase && r.season===f.season,
      'identifiant du résultat incohérent.');
    const minute=live?live.minute:r.duration;
    check(integer(minute,80,240),'durée de match invalide.');
    if (r.japanExtra!==undefined) validateExtra(r.japanExtra,sport(r),minute,true);
    else sportValid(sport(r));
    validateDecision(r,f,live);
  }

  function validateLive(l,f) {
    check(isFixture(f) && l.knockout===undefined && l.srpExtra===undefined && l.flowVersion===1 && l.restartVersion===1
      && Array.isArray(l.restartLog) && Array.isArray(l.events) && ['Sec','Vent','Pluie'].includes(l.weather),'contexte de play-off incompatible.');
    if (l.japanExtra===undefined) {
      if (l.finished) validateResult(l,f,l);
      else {
        sportValid(sport(l));
        check(l.winner===undefined && l.decision===undefined,'décision avant la fin.');
      }
      return;
    }
    const p=l.japanExtra;
    validateExtra(p,sport(l),l.minute,l.finished);
    check(l.flow?.period===2 && l.flow.fullEnd===p.limit && p.start>=l.flow.firstEnd+40,'horloge de prolongation incompatible.');
    const restarts=l.restartLog.filter(r=>r.cause===cause);
    check(restarts.length===1 && restartAllowed(restarts[0],l),'reprise de prolongation absente ou incohérente.');
    const scores=l.events.filter(e=>(e.type==='try'||e.type==='goal') && e.min>p.start);
    if (p.firstScore) {
      const [event]=scores,mark=p.firstScore;
      check(scores.length===1 && event.type===mark.kind && event.min===mark.minute && event.scene?.team===mark.side
        && equal(event.scene.score,l.score) && equal(event.scene.tries,l.tries),'première marque absente du journal causal.');
    } else check(scores.length===0,'action de score sans preuve de marque.');
    if (l.finished) validateDecision(l,f,l);
    else check(l.winner===undefined && l.decision===undefined,'décision avant la fin.');
  }

  return Object.freeze({isFixture,applies,finish,installHooks,historyFields,restartAllowed,flowBoundary,earlyFinish,validateResult,validateLive});
};
