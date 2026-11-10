'use strict';

const competitions = require('./international-competitions.cjs');
const callups = require('./international-callups.cjs');
const manager = require('./international-manager.cjs');
const { createInternationalCareer } = require('./international-career.cjs');

const dateAfter = date => new Date(Date.parse(date) + 86400000).toISOString().slice(0, 10);
const teamIds = [...new Set(competitions.COMPETITION_IDS.flatMap(id => competitions.createEdition(id).teams.map(team => team.id)))];
const mailKeys = ['id','kind','title','body','date','action','nation'];
const limit = 45;

module.exports = function nativeInternational(run, ctx, facts, enabled) {
  const career = createInternationalCareer(competitions, callups, facts);
  const teams = teamIds.map(id => ({ id, name: facts.nations[id]?.[0] ?? id, flagCode: facts.nations[id]?.[1] ?? null }));
  const teamNames = Object.fromEntries(teams.map(team => [team.id, team.name]));
  const read = (source = 'S') => JSON.parse(run(`JSON.stringify(${source}?.national??null)`));
  const supported = () => !!run('CDWorldCareer.active(S)&&S.worldMode.day!==undefined');
  const worldDay = () => run('CDWorldCareer.calendarToday(S)');
  const ended = () => run("S.phase==='ended'");
  const nextOpening = () => run('CDWorldCareer.nextOpening(S)');
  const role = profile => manager.managerRole(profile?.role);
  const isNationalOnly = () => run('S?.national?.role?.club===false');
  const roster = () => JSON.parse(run(`JSON.stringify(S.clubs.flatMap(club=>club.players.map(p=>({
    id:p.id,name:p.name,pos:p.pos,fam:p.fam,age:p.age,rating:p.rating,note:roleNote(p),condition:p.condition,
    injury:p.injury,nationaleQualifications:p.nationaleQualifications,clubId:club.id
  }))))`));

  function write(profile) {
    ctx.nativeNationalWrite = profile;
    try { run('S.national=JSON.parse(JSON.stringify(nativeNationalWrite))'); }
    finally { delete ctx.nativeNationalWrite; }
  }

  function append(profile, messages) {
    const combined = new Map(profile.mail.map(mail => [mail.id, mail]));
    for (const mail of messages) combined.set(mail.id, mail);
    return [...combined.values()].slice(-limit);
  }

  function validate(profile) {
    if (profile === null) return;
    if (!profile || Object.keys(profile).length !== 3 || !profile.career || !Array.isArray(profile.mail) || profile.mail.length > limit ||
      !manager.validateManagerRole(profile.role, { supportedNations: teamIds, date: profile.career.date }) ||
      profile.mail.some(mail => !mail || typeof mail.id !== 'string' || !mail.id.length || mail.id.length > 240 ||
        Object.keys(mail).some(key => !mailKeys.includes(key)) ||
        ['kind','title','body','date'].some(key => typeof mail[key] !== 'string' || !mail[key].length || mail[key].length > 1000) ||
        !['international','national_job'].includes(mail.action) || (mail.nation && !teamIds.includes(mail.nation))) ||
      new Set(profile.mail.map(mail => mail.id)).size !== profile.mail.length) throw Error('Profil international invalide.');
    career.validate(profile.career);
  }

  function initialize(seed, request = null) {
    const previous = read();
    if (previous) {
      validate(previous);
      if (!supported() || (!ended() && previous.career.date !== worldDay()) ||
        (ended() && (previous.career.date < worldDay() || previous.career.date > nextOpening()))) {
        throw Error('Le calendrier du mandat international ne correspond pas à la carrière.');
      }
      return;
    }
    if (!enabled || !supported()) {
      if (request?.nationalRole && request.nationalRole !== 'club') throw Error('Le mandat international est disponible dans les carrières Monde.');
      return;
    }
    const date = worldDay();
    const assigned = manager.createManagerRole({mode:request?.nationalRole, nation:request?.nation, date}, teamIds);
    const newProfile = {career:career.initial(date, seed), role:assigned, mail:[]};
    const nation = assigned.nation;
    newProfile.mail.push(nation ? {
      id:'national-welcome',kind:'international_job',title:'Votre nomination internationale',
      body:'Vous prenez en charge la sélection de ' + teamNames[nation] + '.',date,action:'international',nation,
    } : {
      id:'national-jobs',kind:'international_job',title:'Les postes de sélectionneur',
      body:'Consultez les sélections ouvertes aux candidatures. Vous pouvez garder votre club ou vous consacrer à une sélection.',date,action:'national_job',
    });
    write(newProfile);
  }

  function advance(from) {
    const profile = read();
    if (!profile) return false;
    const offSeason = ended();
    const date = profile.career.date;
    if (from !== date) throw Error('La date de carrière a changé.');
    if (offSeason && date >= nextOpening()) throw Error('Commencez la saison suivante.');
    const players = roster();
    const managed = role(profile);
    const clubId = run('S.club');
    const moved = career.advance(profile.career, {from:date,to:dateAfter(date),players,managedNation:managed.nation,
      clubPlayerIds:managed.club ? players.filter(p => p.clubId === clubId).map(p => p.id) : []});
    if (managed.nation) {
      const fixture = career.project(moved.state, {players,managedNation:managed.nation}).currentFixture;
      if (fixture && !fixture.result) moved.mail.push({
        id:'match-day/'+fixture.id,kind:'international_match',title:'Jour de match avec votre sélection',
        body:teamNames[fixture.homeId]+' – '+teamNames[fixture.awayId]+'. Votre feuille de match est prête à vérifier.',
        date:moved.state.date,action:'international',nation:managed.nation,
      });
    }
    write({...profile,career:moved.state,mail:append(profile,moved.mail)});
    return offSeason;
  }

  function checkSeason() {
    const profile = read();
    if (profile && ended() && profile.career.date !== nextOpening()) throw Error('Terminez les journées de l’intersaison avant de changer de saison.');
  }

  function command(command, payload) {
    const profile = read();
    if (!profile) throw Error('Les sélections sont indisponibles dans cette carrière.');
    const date = profile.career.date;
    const before = role(profile);
    if (run('!!S.live&&!S.worldMode?.resultConfirmed')) throw Error('Terminez et validez le match du club avant cette décision.');
    if (command === 'national_play_match') {
      if (payload.fromDate !== date || typeof payload.fixtureId !== 'string') throw Error('La rencontre internationale a changé.');
      const played = career.play(profile.career,{date,fixtureId:payload.fixtureId,managedNation:before.nation,
        players:roster(),lineup:payload.lineup,reserves:payload.reserves});
      write({...profile,career:played.state,mail:append(profile,played.mail)});
      return;
    }
    if (payload.confirmed !== true) throw Error('Confirmez le changement de mandat.');
    const leaving = command === 'national_leave_job';
    const mode = leaving ? 'club' : payload.role;
    if (!leaving && !['dual','nation'].includes(mode)) throw Error('Mandat de sélectionneur invalide.');
    const nation = leaving ? null : payload.nation;
    const offer = manager.nationalOffers(profile.role,teamIds).includes(nation) ? nation : null;
    const next = manager.applyManagerRole(profile.role,{mode,nation,date,fromMode:before.mode,fromNation:before.nation},
      {supportedNations:teamIds,date,nationalOffer:offer,matchInProgress:false});
    const mail = {id:`national-job/${date}/${profile.role.history.length}/${nation??'club'}`,kind:'international_job',date,
      title:nation?'Mandat international confirmé':'Fin de votre mandat international',
      body:nation?'Vous prenez en charge la sélection de '+teamNames[nation]+'.':'Vous poursuivez votre travail en club.',action:'international',...(nation?{nation}:{})};
    write({...profile,role:next,mail:append(profile,[mail])});
  }

  function project(model) {
    const profile = read();
    if (!profile) {
      if (enabled && !model.club) model.international = {teams,role:'club'};
      return;
    }
    const date = profile.career.date;
    const managed = role(profile);
    const players = roster();
    const overview = career.project(profile.career,{date,players,managedNation:managed.nation});
    const clubId = run('S.club');
    const relevant = new Map(players.filter(p => managed.club && p.clubId === clubId).concat(overview.squad).map(p => [p.id,p]));
    const current = overview.currentFixture?.result === null ? overview.currentFixture : null;
    model.international = {
      role:managed.mode,nation:managed.nation,teams,mail:profile.mail.slice().reverse(),
      jobs:manager.nationalOffers(profile.role,teamIds).map(nation => ({nation,name:teamNames[nation]})),
      editions:overview.competitions.map(item=>({...item,tables:item.standings})),
      callups:overview.callups.filter(camp=>camp.from<=date&&date<=camp.through).map(camp=>({...camp,
        players:camp.playerIds.filter(id=>relevant.has(id)).map(id=>relevant.get(id))
      })).filter(camp=>camp.players.length),
      currentManagedFixture:current,nextManagedFixture:current??overview.nextFixture,squad:overview.squad,sheet:overview.sheet,
    };
    if (ended() && date < nextOpening()) {
      model.meta.canAdvanceSeason=false;
      model.meta.calendarToday=date;
      model.meta.calendarCadence={day:(new Date(date+'T00:00:00Z').getUTCDay()+6)%7,matchReady:false,canAdvance:true};
    }
    if (current && !model.live) model.meta.nationalMatchToday=true;
    if (!managed.club) { model.next=null; model.calendar=[]; }
  }

  return { initialize, validate, advance, checkSeason, command, project, isNationalOnly, read };
};
