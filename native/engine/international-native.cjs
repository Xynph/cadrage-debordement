'use strict';

const competitions = require('./international-competitions.cjs');
const callups = require('./international-callups.cjs');
const manager = require('./international-manager.cjs');
const { createInternationalCareer } = require('./international-career.cjs');
const { projectAvailability } = require('./international-availability.cjs');

const dateAfter = date => new Date(Date.parse(date) + 86400000).toISOString().slice(0, 10);
const referenceEditions = competitions.COMPETITION_IDS.map(id => competitions.createEdition(id));
const teamIds = [...new Set(referenceEditions.flatMap(edition => edition.teams.map(team => team.id)))];
const editionsByFamily = new Map(referenceEditions.map(edition => [edition.id.replace(/-\d{4}$/, ''), edition]));
const dateFormatter = new Intl.DateTimeFormat('fr-FR', { day: 'numeric', month: 'long', year: 'numeric', timeZone: 'UTC' });
const readableDate = date => dateFormatter.format(new Date(date));
const campKey = camp => [camp.competitionId, camp.nation, camp.from].join('/');
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
    ...nativePositionAptitudes.project(p),injury:p.injury,suspension:p.suspension,nationaleQualifications:p.nationaleQualifications,clubId:club.id,
    formeMatch:typeof CDMatchNotes!=='undefined'?CDMatchNotes.effets.selection(p.id):0
  }))))`));

  function write(profile) {
    ctx.nativeNationalWrite = profile;
    try { run('S.national=JSON.parse(JSON.stringify(nativeNationalWrite))'); }
    finally { delete ctx.nativeNationalWrite; }
    noterSelections(profile);
  }

  // Notes des matchs internationaux joués (match-notes.cjs, même calcul que les clubs) : les deux
  // feuilles d'une rencontre et son score, transmis au moteur qui ignore les rencontres déjà notées.
  // Lecture seule de la carrière internationale : aucun tirage, aucun résultat changé.
  function noterSelections(profile) {
    const state = profile?.career;
    if (!state || !Array.isArray(state.appearances) || !run("typeof CDMatchNotes!=='undefined'&&!!S")) return;
    const results = {};
    for (const year of Object.values(state.results || {})) if (year && typeof year === 'object') Object.assign(results, year);
    // Seules les rencontres depuis la dernière notée sont transmises (le moteur ignore les doublons).
    const depuis = JSON.parse(run("JSON.stringify(Object.values(S.matchNotes?.selection?.vus||{}).sort().at(-1)||'')"));
    const parFixture = new Map();
    for (const row of state.appearances) (parFixture.get(row.fixtureId) || parFixture.set(row.fixtureId, []).get(row.fixtureId)).push(row);
    const matchs = [];
    for (const [fixtureId, rows] of parFixture) {
      const result = results[fixtureId];
      if (rows.length !== 2 || !result || rows[0].date < depuis) continue;
      // Côté vainqueur : le score le plus haut (égalité : ordre indifférent).
      const haut = result.home >= result.away ? ['home', 'away'] : ['away', 'home'];
      const gagnant = result.winnerId ?? null;
      const ordre = gagnant && rows[1].nation === gagnant ? [rows[1], rows[0]] : rows;
      const cote = k => (gagnant ? haut[k] : (k === 0 ? 'home' : 'away'));
      const edition = /^(.*?-\d{4})(?:-|$)/.exec(fixtureId)?.[1] || fixtureId;
      const nomCompetition = competitionName(edition);
      matchs.push({ cle: fixtureId, date: rows[0].date, competition: nomCompetition === 'la fenêtre internationale' ? 'Test-match' : nomCompetition,
        equipes: ordre.map((row, k) => ({ nation: row.nation, nom: teamNames[row.nation] || row.nation, ids: row.playedIds,
          points: result[cote(k)], essais: result[cote(k) + 'Tries'] })) });
    }
    if (!matchs.length) return;
    ctx.nativeNotesSelection = matchs;
    try { run('CDMatchNotes.enregistrerSelection(nativeNotesSelection)'); }
    finally { delete ctx.nativeNotesSelection; }
  }

  function append(profile, messages) {
    const combined = new Map(profile.mail.map(mail => [mail.id, mail]));
    for (const mail of messages) combined.set(mail.id, mail);
    return [...combined.values()].slice(-limit);
  }

  function competitionName(id) {
    const family = editionsByFamily.get(id.replace(/-\d{4}$/, ''));
    if (!family) return 'la fenêtre internationale';
    const year = /-(\d{4})$/.exec(id)?.[1];
    return year ? family.name.replace(/\d{4}$/, year) : family.name;
  }

  function dutyMail(before, after, source, clubPlayerIds) {
    const camps = new Map(after.callups.map(camp => [campKey(camp), camp]));
    const club = new Set(clubPlayerIds);
    const messages = source.map(mail => {
      if (!['international_callup','international_release'].includes(mail.kind)) return mail;
      const camp = camps.get(mail.id.slice(mail.id.indexOf('/')+1));
      if (!camp) return mail;
      const clubRelease = mail.kind === 'international_release';
      const count = clubRelease ? camp.playerIds.filter(id => club.has(id)).length : camp.playerIds.length;
      const start = clubRelease
        ? `${count} ${count === 1 ? 'joueur de votre club rejoint' : 'joueurs de votre club rejoignent'} la sélection de ${teamNames[camp.nation]}`
        : `${count} joueurs sont convoqués avec la sélection de ${teamNames[camp.nation]}`;
      const through = camp.competitionId.startsWith('rugby-world-cup-')
        ? ' La date de retour dépend du parcours dans la compétition.'
        : ` La mise à disposition court jusqu’au ${readableDate(camp.through)} inclus.`;
      return {...mail,body:`${start} pour ${competitionName(camp.competitionId)} à partir du ${readableDate(camp.from)}.${through}`};
    });
    if (!club.size) return messages;

    const returning = new Set();
    for (const prior of before.callups) {
      const key = campKey(prior);
      const camp = camps.get(key);
      if (!camp || prior.from > before.date || before.date > prior.through || camp.through >= after.date) continue;
      const players = camp.playerIds.filter(id => club.has(id) && !returning.has(id) &&
        !callups.clubReleaseOn(after.callups, id, after.date));
      if (!players.length) continue;
      for (const id of players) returning.add(id);
      const count = players.length;
      messages.push({
        id:'club-return/'+key,kind:'international_return',title:'Retour de sélection',
        body:`${count} ${count === 1 ? 'joueur revient' : 'joueurs reviennent'} du rassemblement de ${teamNames[camp.nation]} pour ${competitionName(camp.competitionId)}. La mise à disposition prend fin le ${readableDate(after.date)}.`,
        date:after.date,action:'international',nation:camp.nation,
      });
    }
    return messages;
  }

  function matchMail(state, players, nation) {
    if (!nation) return [];
    const fixture = career.currentFixture ? career.currentFixture(state,nation) : career.project(state, {players,managedNation:nation}).currentFixture;
    if (!fixture || fixture.result) return [];
    return [{
      id:'match-day/'+fixture.id,kind:'international_match',title:'Jour de match avec votre sélection',
      body:teamNames[fixture.homeId]+' – '+teamNames[fixture.awayId]+'. Votre feuille de match est prête à vérifier.',
      date:state.date,action:'international',nation,
    }];
  }

  function advanceProfile(profile, to, notifyActive = false) {
    const players = roster();
    const managed = role(profile);
    const clubId = run('S.club');
    const clubPlayerIds = managed.club ? players.filter(p => p.clubId === clubId).map(p => p.id) : [];
    const moved = career.advance(profile.career, {from:profile.career.date,to,players,managedNation:managed.nation,
      clubPlayerIds,notifyActive});
    const messages = dutyMail(profile.career,moved.state,moved.mail,clubPlayerIds);
    messages.push(...matchMail(moved.state,players,managed.nation));
    return {...profile,career:moved.state,mail:append(profile,messages)};
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
      const upgraded = career.upgrade?.(previous.career) ?? previous.career;
      if (upgraded !== previous.career) {
        const profile = advanceProfile({...previous,career:upgraded},upgraded.date,true);
        validate(profile);
        write(profile);
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
    write(advanceProfile(newProfile,date,true));
  }

  function advance(from) {
    const profile = read();
    if (!profile) return false;
    const offSeason = ended();
    const date = profile.career.date;
    if (from !== date) throw Error('La date de carrière a changé.');
    if (offSeason && date >= nextOpening()) throw Error('Commencez la saison suivante.');
    write(advanceProfile(profile,dateAfter(date)));
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
    let detail = 'Vous poursuivez votre travail en club.';
    if (nation && mode === 'dual') detail = 'Vous gardez votre club et prenez en charge la sélection de '+teamNames[nation]+'.';
    if (nation && mode === 'nation') detail = before.club
      ? 'Vous quittez votre poste en club pour vous consacrer à la sélection de '+teamNames[nation]+'.'
      : 'Vous prenez en charge la sélection de '+teamNames[nation]+'.';
    const mail = {id:`national-job/${date}/${profile.role.history.length}/${nation??'club'}`,kind:'international_job',date,
      title:nation?'Mandat international confirmé':'Fin de votre mandat international',
      body:detail,action:'international',...(nation?{nation}:{})};
    write({...profile,role:next,mail:append(profile,[mail,...(nation ? matchMail(profile.career,roster(),nation) : [])])});
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
      choicesBySlot:overview.choicesBySlot,
      availability:projectAvailability({date,clubManaged:managed.club,clubId,players,callups:overview.callups,
        releaseWindows:overview.releaseWindows,editions:overview.competitions,teams}),
    };
    if (ended()) {
      const waiting = date < nextOpening();
      if (waiting) model.meta.canAdvanceSeason=false;
      model.meta.calendarToday=date;
      model.meta.calendarCadence={day:(new Date(date+'T00:00:00Z').getUTCDay()+6)%7,matchReady:false,canAdvance:waiting&&!current};
    }
    if (current && !model.live) model.meta.nationalMatchToday=true;
    if (!managed.club) { model.next=null; model.calendar=[]; }
  }

  return { initialize, validate, advance, checkSeason, command, project, isNationalOnly, read };
};
