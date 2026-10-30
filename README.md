# Cadrage Débordement

Browser-local rugby management game. Buildless: `dist/index.html`, `dist/rugby.js` (attributes and simulation), `dist/economy.js` (contracts and transfers), `dist/game.js` (career and UI), `dist/style.css`.

## Validate

`node --check dist/game.js`

`node --check dist/rugby.js`

`node tests/rugby.cjs`

`node tests/economy.cjs`

`node tests/development.cjs`

`node tests/saves.cjs`

`node tests/opposition.cjs`

`node tests/manager.cjs`

`node tests/playbook.cjs`

The deterministic suite covers 23-player selection, specialist front-row cover, substitutions and no re-entry, yellow-card expiry, live save restoration, version-one migration, recruitment cover, attribute effects, 250 independent simulated matches and two complete seasons.

## Version 2

- Eleven role-specific attributes; role ratings and fitness shown independently.
- Fifteen starters and eight nominated replacements. Specialist hooker and both props required on the bench. Remaining coverage is chosen before the match.
- One minute per simulated phase, automatic halftime pause, optional tactical pauses and individual substitutions. Only nominated replacements can enter; no tactical re-entry.
- Same possession, territory, set-piece, penalty, weather, kicking and fatigue engine for interactive and AI fixtures. Yellow cards last ten simulated minutes. Two yellows produce a permanent dismissal as an explicit game simplification.
- Match report, statistics and post-match diagnostic notes; players' actual minutes affect injury risk.
- Normal weekly recovery balances an 80-minute fixture and rotation. AI clubs follow normal training.
- Saves still use `bdt-v1` on the same origin. Version-one data is copied once to `bdt-backup-v1` before adding attributes and bench selection. Score, minute and events of an ongoing match are preserved; new detailed statistics begin at the migration point.

## Version 3 — contracts and transfers

- Current careers keep their finances and wages. Existing players receive deterministic contract ends spread across the current and next two seasons; a one-time `bdt-backup-economy` copy precedes migration. Match state is untouched.
- Recruit or renew through salary and one-to-three-season offers. Three proposals per player per game week; low offers receive counteroffers, a third failed proposal ends talks for the week. Agreement always requires a separate confirmation before payment.
- Renewal extends the existing expiry and immediately changes the wage. Prime paid once; future salary estimates use the existing 29 paid rounds per season, not real-world annual budgets.
- List players, wait a round, review and accept or refuse an interested club's bid. Bids last through the next game week. A transfer moves the actual player and conserves the cash paid by buyer to seller. Live fixtures lock all squad transactions.
- Review unrenewed expiries before starting another season. Expired players leave free and reappear among free agents; academy players cover missing matchday positions. AI clubs renew automatically; they do not negotiate autonomously.
- Youth cannot be sold before age 20; new signings cannot be resold within three league rounds. No real-world transfer windows, agents, player release clauses or full AI-club financial simulation.
- Economy tests cover signatures, counteroffers, persistence, invalid numbers, spending guards, expiry, sales, payroll, and migration. Rugby tests retain the season and match regression checks.

## Version 4 — formation and player careers

- Deterministic potential ceilings preserve saved ratings and attributes. New metadata records training XP, actual minutes, appearances, career minutes and the last twelve season summaries. A one-time `bdt-backup-development` precedes migration. Existing live minutes are baselined, without inventing historical appearances.
- Youth improves faster. Normal/intense training gives fractional XP; minutes actually played add experience. Recovery training and injured players receive no development XP. Gains stop at the ceiling. AI clubs use the same development model.
- Four named prospects arrive each season; cohorts remain through age 21, with a maximum of twelve. Promotion adds a 2,000-euro weekly professional wage and a contract, without a signing fee. Youth fixtures are not simulated. Emergency cover remains available separately.
- A fictional age curve applies gradual decline (earlier for backs) and an announced retirement age. Skills, age and contracts are not modified merely by migration. Retirement and expiry are reviewed together before advancing seasons; retirements remove the player and their wage, without compensation in this simplified model.
- New negotiated contracts cannot run past the announced retirement. Existing contracts are preserved; retired players never become free agents. AI clubs replenish positional cover and introduce new young players each season.
- The Formation screen shows prospects, potential, current-season changes, minutes and retirements. Player cards expose career history and the distinction between overall development and the weighted position rating.
- Tests cover growth ceilings, playing-time effects, migration baselines, cohort and promotion uniqueness, wage effects, injury/recovery training, age decline, retirement, contract limits and ten successive offseasons. Existing rugby and economy regressions remain enabled.

## Version 5 — portable saves

- Export schema: `format: cadrage-debordement-save`, `exportVersion: 1`, ISO export date, FNV-1a checksum and a complete version-two career snapshot. The checksum detects accidental modification, not authenticity. Exported live games are paused in the file without changing the running game.
- JSON imports are read locally, capped at 5 MiB and previewed before replacement. Shape, bounded numbers, calendar, identifiers, cross-club player uniqueness, squad references, match state and all current feature modules are checked. Unknown formats, future versions, dangerous object keys and markup/attribute text are rejected. Imports support this export format; old browser-local saves still migrate through normal startup.
- Before replacing an open career, `bdt-before-import` stores a complete export of it. If either the backup write or main save write fails, the open in-memory career stays unchanged. The backup can be reviewed, restored or downloaded; restoring it creates a new backup of the career it replaces.
- There is no cloud sync. Export/import buttons are available under Sauvegardes, and import is also available from the initial club-selection screen. Save storage failures are shown persistently; invalid local startup data is retained in `bdt-recovery-invalid` while the welcome/import screen remains reachable.
- Tests cover round trips, cancellation, rollback, quota failures, paused live restoration, halftime, playoffs, completed seasons, ten offseason snapshots, hostile text and identifiers, corrupted/oversized files and missing references. Browser QA downloads and reimports an actual JSON file and checks backup availability.

## Version 6 — opposition and difficulty

- Discovery, Classic and Expert alter coach choices only. No difficulty-dependent attribute, budget, kicking probability or result multiplier. The level is snapshotted at kick-off and cannot be changed during a match. Classic is the migration default.
- Managers select position-eligible, unique matchday squads using fitness, role qualities, style and recent starting workload. Higher levels cover fly-half explicitly and pace replacements, with key-kicker and depth considerations. Tactical reviews depend on weather, score and available qualities; all changes are visible in the match journal.
- Both user and AI clubs have morale updated by the same win/draw/loss increments and the same bounds. Opponent morale is visible in the pre-match report. Legacy morale defaults are identical after import or reload; fatigue workload resets at the offseason.
- Penalty policies are available to the user during tactical pauses: context, points or touch. Expert managers and the user's contextual policy consider a late try requirement or an attainable attacking bonus. All actual kicks still use the same kicker, weather and distance rules.
- New matches use balanceVersion 2: attribute gaps still matter, with reduced compounded attack, set-piece and maul advantages. Existing in-progress matches retain their old physical coefficients when the version is absent. No forced win rates or score-based comeback bonuses.
- Seeded internal calibration: 400 identical-team neutral games produce 49.25% first-team wins and 42.75 combined points on average; 400 strong-versus-weak games, alternating home advantage, produce 91% favorite wins, nine draws and 46.47 combined points. These are fictional engine measurements, not estimates of real rugby probabilities or proof of ideal balance across every matchup.
- Regression checks cover squads, legal paced changes, weather and score decisions, attribute immutability, locked live levels, save compatibility, careers, finances, complete seasons and long-run offseason snapshots. UI checks cover persistent difficulty and penalty policy.
- AI transfer negotiations remain simple; this update focuses on sporting decisions.

## Version 7 — substitutions and second yellow cards

- New fixtures snapshot `rulesProfile: fr-pro-2025`, limited to the professional French 2025/26 substitution/card-replacement framework documented in `docs/rugby-rules-reference.md`. This is a fixed rules edition in a fictional career, not a claim of 2026/27 compliance or complete law coverage.
- The nominated 23 are immutable. Tactical departures remain on the bench; four tactical re-entries are allowed, regardless of unused reserves. First appearances from the eight reserves do not use that return quota. Both sides use the same eligibility checks.
- A second yellow permanently excludes the individual. Another available nominated player can fill the vacancy after twenty playing minutes, outside the tactical-return quota. The AI restores eligible vacancies independently of its tactical replacement schedule; the user chooses in the bench panel. A separate no-replacement red state is supported and tested, but direct foul-play reds are not generated yet.
- Yellow expiry and replacement eligibility use playing time; half-time and manager pauses consume no exclusion time. Minutes/fatigue for the just-completed interval are charged to the players present at its start, fixing the nine-minute yellow absence in new fixtures.
- Live snapshots without the profile remain unchanged under their original rules until the fixture ends. New fixtures use the revised rules. Portable imports validate nominated players, bench/field/excluded partitions, red vacancies, substitution logs and return counters. The save/export versions stay compatible.
- Focused law scenarios cover four returns with unused reserves, twelve tactical changes, disallowed fifth returns, yellow timing across half-time, the twenty-minute boundary, used-player replacement after a red, permanent-red refusal, AI restoration, reload/import, hostile rule data and legacy live fixtures. Existing season, opposition, economy, development and save suites also pass.
- Still pending: first-row exclusions, nominated replacement/temporary sacrifice and uncontested scrum procedures. The existing first-row card suppression remains explicit technical debt. Medical substitutions/HIA and direct red-card incident generation are not implemented. Manager changes still use the engine's abstract paused phases rather than a full ball-dead/referee authorization model. No full regulatory conformity is claimed.

## Version 8 — first-row exclusions and uncontested scrums

- New fixtures add `frontRowVersion: 1`. Existing version-seven and older fixtures keep their original behavior until completion; their scores, minutes, fatigue and logs are not migrated mid-game. The 2025/26 substitution/card framework remains fixed.
- All three specialist roles may now receive yellow cards, including the replacement specialist. At the next scrum, the staff selects a qualified nominated specialist and nominates an active non-front-row player to leave. Coverage and regulatory restoration do not consume tactical returns. During a temporary exclusion the nominated player cannot return early; after a permanent exclusion they may return through an ordinary legal replacement.
- No specialist available: uncontested scrums and the additional one-player reduction are applied. Eight players from each side are required. The introducing team retains the ball, with no shove, gain, random scrum turnover or scrum-derived try. Two unavailable specialists at the same post leave twelve players; with two twenty-minute reds this becomes thirteen after the first period and fourteen after both when the shortage persists, matching the World Rugby August 2025 matrix.
- A qualified returning player permits contested scrums again. Yellow expiry restores the specialist and eligible nominated players without tactical quota use. Expired front-row reds restore an actual vacant position even if the initially nominated player has already returned elsewhere. The sent-off individuals never re-enter.
- The bench shows active headcount, uncontested status and nominated absences. The report distinguishes uncontested scrums. Both sides use the same automatic staff procedures. Save validation covers first-row exclusions, held players, slot eligibility, red references and authorized headcount; reload/import retains these states.
- Focused tests cover all three positions, next-scrum entry, actual playing minutes, exhausted return quotas, overlapping yellows, the 12/13/14 matrix, permanent reds, nominated players reused elsewhere, two affected teams, malicious imported states and legacy fixtures. All existing career, opposition, save, economy and development suites pass.
- Still simplified: staff chooses the nominated player automatically; no manual nomination prompt. Injuries, blood/HIA procedures and direct-red incident generation remain absent. The general cause/restart engine and referee ball-dead authorization remain pending. This change does not claim complete law compliance.

## Version 9 — causes of set pieces and restarts

- New fixtures add `restartVersion: 1`. The 2025 World Rugby laws are the edition anchor; existing fixtures without the flag retain their previous phase model. There is no in-progress score, clock, fatigue or event migration.
- Set pieces are authorized by an explicit event: knock-on/forward pass, ball carrier or kick going into touch, penalty touch, eligible 50:22, defender taking the ball into their own in-goal, or the defending team's choice after a kick through in-goal. A bare `contestSetPiece` call cannot create a scrum/lineout in the new model. The event records beneficiary, actor, mark, origin, cause and match minute; records are capped at 300.
- Direct touch loses territorial gain outside the 22 or if the ball has been brought back without a qualifying phase. Penalty touch and eligible indirect 50:22 retain the throw. Receiving possession and completed tackle/ruck sequences update kick eligibility. The current engine does not yet generate backward carries; the carried-back contexts are represented and tested.
- The conceding team kicks off after scores; the second-half kicker is opposite to the first. Kick-off and drop-out reception is simulated separately from who kicks. Missed penalties may remain live, go into touch for the defenders, or become dead for a 22-metre drop-out. Held-up attackers, attacking in-goal knock-ons and attacking kicks grounded by defenders cause a try-line drop-out. Ordinary kicks through in-goal allow the defensive staff to choose a legal return scrum or 22-metre drop-out. Defender-taken-in-goal grounding is supported by the event resolver, but not naturally generated by the present forward-carry model.
- Failed attacks distinguish hand errors from legal defensive turnovers. Scrum-derived tries are labelled as scrum tries rather than mauls. First-row and uncontested-scrum procedures remain on the same causal path.
- Restart facts and kick eligibility are validated during import/reload; unknown versions, invented causes, wrong beneficiaries, invalid marks and inconsistent timestamps are rejected. Save/export formats remain compatible. Eight suites include both directions, penalty and ordinary touch, carried-back conditions, 50:22 exclusions, in-goal outcomes, missed kicks, score/half-time kickers, preservation of old fixtures and full career regression checks.
- Deliberate scope limit: restarts resolve atomically within a simulated minute. The game still needs a finer clock, advantage, ball-dead substitution authorization, end-of-period exceptions, full lineout/ruck/maul infringement choices and genuine extra-time procedures. Reception/territory probabilities are fictional; no full law compliance is claimed.

## Version 10 — 2D match view, advantage and period endings

- The match centre has an SVG pitch with the actual active player identities and ball. Animated transitions illustrate simulated sequences; formations and trajectories are indicative, not a physical movement simulation. Excluded and nominated-off-field players are absent, replacements appear, and teams change ends at half-time. Wide/close cameras and three playback speeds only change presentation. Pause and reduced-motion preferences disable animation; no rendering consumes match randomness or alters career state.
- New fixtures add `flowVersion: 1`. Advantage retains the beneficiary, sanction and mark, returns to the original award without counting the offence twice, and preserves the more favorable penalty on repeated faults. Clear-benefit thresholds and a three-sequence review are fictional referee policy, not law-mandated distances or durations. Unsafe/card situations stop play.
- At 40/80 displayed minutes, live play can continue. Ordinary dead-ball restarts end the period; protected penalty touches, a scrum returned under advantage, and try conversions can complete. Each half has forty playing minutes independently of first-half overrun. A manager may kick out to end a period; this is an explicit tactical action rather than a live-ball whistle. Extra time in tied knockout games remains the previous simplified deciding penalty.
- Overrun minutes count toward player workload and exclusion clocks. Period, advantage, source marks and timestamps survive reload/export/import with bounded validation. Existing ongoing fixtures without the flow flag preserve their previous rules and can still use the 2D view.
- Ten suites cover rugby (250 games and two seasons), economy, development (ten offseasons), saves, opposition (800 calibration games), match rules, front row, restarts, match flow and 2D rendering. Browser checks cover field presentation, camera selection, tempo and play/pause. This remains an atomic minute-scale engine: fine seconds, full infringement choices, ball-dead substitution authorization, medical procedures and genuine extra time are pending.

## Version 11 — follow the pitch and commentary together

- The live score and match controls form a compact sticky bar. The pitch and commentary share the first viewing row on desktop; below 900px the journal follows the pitch. Statistics, staff instructions and the bench follow below.
- Commentary scrolls independently within the pitch-height panel. Newest actions appear first with a highlighted latest entry, event labels and restrained color accents. A presentation-only Highlights filter keeps scoring, penalties, advantage, discipline, substitutions, tactical instructions and period endings. It stays selected during live updates; it resets on page reload.
- No match rules, event generation, results, random choices or save schema changed. Existing 2D checks pass; browser QA verifies alignment, bounded journal height, filtering, live updates, pause and sticky score without horizontal overflow at the desktop test viewport.

## Version 12 — action-synchronized match viewing

- Removed close camera. Whole-pitch view only. New live events record structured action kind, actor/team, start/end ball coordinates, score/tries, period, tactical style and active slot identities. Scene generation consumes those facts, never regexes over commentary or the last restart of the minute. Old events without facts explicitly show current state; new events in existing matches gain snapshots without changing their rules.
- Playback presents each recorded event before calculating another playing minute. The highlighted comment, ball, featured player, score and clock refer to that same event; future comments are hidden until shown. An action remains visible even under the Highlights filter. A try reaches its actual attacking goal, before the conceding team's centre restart and then reception. Scrums and touches show setup at the legal restart mark before the contest outcome. Formations and lateral positions remain schematic, not a physical rugby simulator.
- The engine records every successful carrying sequence and names a deterministic active participant, with varied descriptions and the current tactical approach. The existing random draw stream and result probabilities remain unchanged; scoring/conversion remain one atomic event. Automated matches retain the same sporting engine without storing visual snapshots.
- Optional pause-after-try and pause-after-card controls stop after the already-calculated sequence is displayed. Card returns do not trigger incident pauses. Preferences are browser-local, outside portable career data. Manual pause/player inspection jumps to the current engine head without advancing the clock, so managerial changes always use the actual legal roster. Fast-forward skips visual playback and respects chosen incident pauses.
- Click or keyboard-activate a player to pause and inspect identity, attributes, condition and played minutes. Only the user's currently eligible replacements are offered; changes go through the existing substitution guard. Opponent cards are read-only. Scene facts survive export/import and are validated for geometry, versions, teams, actor IDs, nominated slot identities, score bounds and periods. Reload resumes at the last calculated event rather than replaying half a sequence.
- Eleven suites pass, including new causal visualization scenarios, pause boundaries, historical rosters, click replacement, hostile snapshots and save restoration, plus the previous full career/season/economy/opposition checks. Browser QA verifies equal current-action text in pitch and journal and a substitution from the SVG through to both displays. No new rugby-law variation or normative compliance claim is introduced.

## Version 13 — attack and defence with sporting effects

- New fixtures snapshot `tacticalVersion: 1`, independent attack styles and defence plans, and measured phase counters. Existing live fixtures without the flag finish under the previous physical coefficients. Browser-local career preference `defence` defaults to balanced and applies at the next kickoff; no ongoing match receives a silent tactical migration. Portable imports validate plans, versions, action snapshots and bounded counters, including fractional carried metres after a kick.
- Attack: balanced, close (`conquete`, preserving the save key), wide and occupation. New-profile attack success weights the actual active players' relevant skills: forwards' power for close play, backs' passing/speed for wide play. Carry distance, hand-error exposure, finishing opportunity and workload vary with the choice. Rain increases wide-play risk. Occupation increases open-play kicking, chiefly in one's own half; it reduces that preference in the attacking 22. Existing kicking distance, weather and reception laws remain causal.
- Defence: balanced, rush and prudent drift. Rush reduces initial attacking success and raises forced-hand-error exposure, with higher defensive workload and penalty risk; a beaten rush allows longer carries and more finishing opportunities. Drift concedes more initial advances while reducing their length, large gains, finishing opportunity, workload and penalty risk. These are explicitly fictional simulation coefficients, not World Rugby regulations or real-world probabilities. No direct difficulty/result/attribute bonus is introduced.
- Both clubs and automated fixtures use the same calculations. AI chooses a defence from available qualities/freshness and, at Expert, score and remaining time, using its normal review cadence. Tactical changes are journaled. The player's two plans can be edited in preparation and during a pause; invalid, finished, unpaused and pending-playback changes are rejected.
- Action snapshots retain both sides' plans. Attack width/support and defensive line depth change in the SVG, and pending playback shows the recorded plans rather than a later AI change. The pitch legend identifies each recorded plan. Positions remain schematic and do not calculate collisions, passes or offside lines.
- Half-time staff observations cite recorded carries, metres, errors, opponent progress and penalties. Recommendations are conditional (for example, wet wide play with handling errors), never auto-applied or presented as guaranteed results. Players below 70% condition can be inspected through the existing pause/substitution controls. Live stats add phase counters and the final report preserves them.
- Twelve suites pass, including 640 controlled comparison games, attribute-dependent carrying opportunities, frozen formations, half-time advice, save/import hostility, fractional territory and preservation of older engines. Browser QA covers preparation, separate live controls, changing defence at half-time and a staff report grounded in the match's actual counters.

Controlled comparison: 80 games per case, uniform 75-rated skills, alternating tested side, fixed seed schedule, no AI plan/substitution changes. Dry wide play gained **19.47 m per successful carry** versus **12.27 m** close, with **11.99 versus 7.03 hand errors/game**. Under rain, errors were **15.50 versus 10.34**. Occupation used **10.97 open-play kicks/game** versus **1.29** balanced. Against rush, attacks advanced on **46.8%** of carries versus **50.8%** against drift; rush defenders conceded **7.75 penalties/game** versus **4.28** and finished at **63.13% condition** versus **71.87%**, without substitutions. These sample results demonstrate tradeoffs in this engine, not universal rankings or real-life benchmarks.

## Version 14 — manager workspace and rugby playbook

- A manager office replaces the old dashboard: four upcoming league fixtures, unread/filterable in-game messages, contract and transfer decisions, injuries, squad coverage and recent result. Decisions route to the relevant screen; financial and signature guards remain unchanged.
- The squad opens as a sortable table with position/search filters, contract expiry, fitness, salary, minutes and potential. Compare two players attribute by attribute; the fifteen-position depth view respects specialist front-row eligibility. The existing 23-player sheet remains a separate tab.
- Staff responsibilities may delegate training and selection. The preparer chooses recovery below 75% average XV fitness, otherwise normal training. The assistant repairs an incomplete sheet before kickoff and selects again after training. These use actual training and squad eligibility, without attribute bonuses. There is no staff hiring/quality/payroll model yet.
- Recruitment missions search available simulated free agents by position family, maximum age, signing fee and weekly salary. A mission costs 5,000 euros and takes two game weeks; one active mission and three queued missions maximum. Up to three reports compare each candidate to the current first choice; report grades are dated snapshots of known attributes. Watchlists and report candidates are retained among free agents subject to the existing 60-agent cap. No hidden-information accuracy system or scouting of contracted opposition players is claimed. Negotiation uses the existing salary/duration/confirmation flow.
- New fixtures snapshot `playbookVersion: 1`. Four oriented field zones can override the base attack/defence; inheriting preserves the previous coefficients. Scrum security trades gain/finishing opportunity for conservation; pushing does the reverse. Short lineouts, back throws and mauls have explicit conservation/gain tradeoffs. Centre kickoffs may be short (10–14 m) or long (25–35 m), with differing recovery prospects. Goal-line and 22-metre restarts are unaffected; uncontested scrums bypass the new modifiers. These are fictional strategic policies, not new laws.
- Both sides use the same engine. The AI currently inherits its existing general strategy in each zone. Live changes require a pause and no pending playback. Action facts preserve the effective plans and chosen set-piece move for coherent commentary and schematic whole-pitch presentation. Existing live fixtures retain their original engine; career preferences apply to later fixtures.
- Manager state and playbooks survive reload/export/import, with bounded validation and migration from older careers. Fourteen suites cover the new missions, delegation, slot depth, zone orientation, actual kick decisions, set-piece tradeoffs and restart distances/retention, alongside the existing season, finance, development, laws and visual playback regressions. Browser QA covers office navigation, player comparison, plan choices, staff delegation and mission submission.
- Original implementation inspired by publicly documented management-game interaction patterns; no proprietary Football Manager or rugby-game source code was obtained or copied.

## Limits

Fictional players and finances. Simplified tournament tiebreakers and extra time. No in-match injuries, HIA, direct red cards, European fixtures, JIFF rules or promotion/relegation. Squad flexibility beyond a player's position family is not simulated. Saves are local to one browser, without cloud sync.
