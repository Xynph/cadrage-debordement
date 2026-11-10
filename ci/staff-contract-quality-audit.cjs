'use strict';
// Read-only catalogue audit. Reports contain opaque IDs and static messages,
// never member names, raw role text, source URLs or private evidence.
const path=require('node:path');
const object=x=>x!==null&&typeof x==='object'&&!Array.isArray(x);
const opaque=x=>typeof x==='string'&&/^[a-zA-Z0-9:_-]{1,100}$/.test(x)?x:null;
const day=x=>typeof x==='string'&&/^\d{4}-\d{2}-\d{2}$/.test(x)&&Number.isFinite(Date.parse(x+'T00:00:00Z'))&&new Date(x+'T00:00:00Z').toISOString().slice(0,10)===x;
const dated=x=>day(x)||(typeof x==='string'&&/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})$/.test(x)&&day(x.slice(0,10))&&Number.isFinite(Date.parse(x)));
const messages={
 'opening-register-missing':'Registre d’ouverture absent : exclusions d’alias et effectifs actifs prospectifs non vérifiés.',
 'opening-register-unusable':'Registre d’ouverture incomplet ou incohérent : aucun nombre actif n’est certifié.',
 'edition-policy-unknown':'Politique d’édition non déterminable ; applicabilité du registre d’ouverture inconnue.',
 'staff-missing':'Aucune fiche de staff embarquée pour ce club ; couverture documentaire inconnue.',
 'staff-historical':'Fiche historique : aucune fonction actuelle ne peut être déduite.',
 'staff-source-unknown':'Ni date ni saison de source embarquée : fonction actuelle non vérifiable.',
 'staff-history-unknown':'Le caractère historique de cette fiche n’est pas renseigné.',
 'staff-source-after-observation':'La date de source est postérieure au relevé ; contrôler sa signification.',
 'contract-estimated':'Échéance estimée explicitement déclarée ; ce n’est pas une erreur de données.',
 'contract-unknown':'Échéance ou provenance non documentée dans les champs disponibles.',
 'contract-official-reference-missing':'Échéance déclarée officielle sans référence individuelle exploitable embarquée.',
 'opening-evidence-not-embedded':'Registre documentaire d’ouverture sans pièces individuelles embarquées : sources privées non vérifiées par cet audit.',
 'source-conflicts-declared':'Le profil signale des conflits de sources ; aucun arbitrage automatique.'
};
function auditEdition(input={}){
 const {edition,staffRegistry,opening=null}=object(input)?input:{};
 const foundation=object(input?.foundation)?input.foundation:{players:{},sources:{}};
 const errors=[],warnings=new Map();
 const add=(code,clubId=null,entityId=null)=>errors.push({code,clubId:Number.isSafeInteger(clubId)?clubId:null,entityId:opaque(entityId)});
 const warn=(code,clubId=null,entityId=null)=>{
  if(!warnings.has(code))warnings.set(code,{code,message:messages[code],count:0,examples:[]});
  const w=warnings.get(code);w.count++;
  if(w.examples.length<5)w.examples.push({clubId:Number.isSafeInteger(clubId)?clubId:null,entityId:opaque(entityId)});
 };
 const registry=edition?.registry;
 if(!object(edition)||!object(registry)||!Array.isArray(registry.clubs))return {edition:null,valid:false,status:'invalid',opening:{status:'unknown',applies:null},errors:[{code:'invalid-edition',clubId:null,entityId:null}],warnings:[],clubs:[],counts:{}};
 const modes={1:'world',2:'world-pacific',3:'world-japan',4:'world-nationale',5:'world-champ'};
 let linkageInvalid=false;
 const link=(bad,code)=>{if(bad){add(code);linkageInvalid=true;}};
 link(edition.id!==undefined&&registry.id!==undefined&&edition.id!==registry.id,'edition-registry-id-mismatch');
 link(edition.version!==undefined&&registry.version!==undefined&&edition.version!==registry.version,'edition-registry-version-mismatch');
 link(registry.marker?.id!==undefined&&registry.id!==undefined&&registry.marker.id!==registry.id,'registry-marker-id-mismatch');
 link(registry.marker?.version!==undefined&&registry.version!==undefined&&registry.marker.version!==registry.version,'registry-marker-version-mismatch');
 link(registry.marker?.version!==undefined&&edition.version!==undefined&&registry.marker.version!==edition.version,'edition-marker-version-mismatch');
 link(edition.mode!==undefined&&registry.mode!==undefined&&edition.mode!==registry.mode,'edition-registry-mode-mismatch');
 link(modes[edition.version]!==undefined&&edition.mode!==undefined&&edition.mode!==modes[edition.version],'edition-mode-version-mismatch');
 const policyKnown=!linkageInvalid&&Number.isInteger(edition.version)&&Object.hasOwn(modes,edition.version);
 if(!policyKnown)warn('edition-policy-unknown');
 const openingApplies=policyKnown&&edition.version===5;
 const openingHeaderValid=object(opening)&&opening.schema==='world-initial-contracts-v1'&&opening.databaseId===registry.id&&day(opening.asOf)&&object(opening.players)&&object(opening.inactiveAliases);
 let openingStatus=!policyKnown?'unknown':!openingApplies?'not-applicable':opening===null?'missing':openingHeaderValid?'available':'invalid';
 if(openingStatus==='missing')warn('opening-register-missing');
 if(openingStatus==='invalid'){add('invalid-opening-register');warn('opening-register-unusable');}
 const clubs=registry.clubs,byClub=new Map(),players=new Map(),staffIds=new Set();
 const counts={catalogueClubs:clubs.length,playableClubs:0,players:0,legacyAliasPlayers:0,playersIncludingLegacyAliases:0,catalogueInactiveAliases:0,prospectiveActivePlayers:0,staffMembers:0,staffHistorical:0,staffHistoryUnknown:0,staffCurrentDeclared:0,contractOfficialDeclared:0,contractEstimated:0,contractUnknown:0,openingExact:0,openingMinimum:0,inactiveAliases:0,aliasCrossClub:0,openingActiveTerms:0,openingChanges:0};
 const clubReports=[];
 for(const c of clubs){
  if(!object(c)||!Number.isSafeInteger(c.id)||c.id<0){add('invalid-club');continue;}
  if(byClub.has(c.id))add('duplicate-club',c.id);else byClub.set(c.id,c);
  if(!Array.isArray(c.players)){add('invalid-roster',c.id);continue;}
  for(const p of c.players){
   counts.players++;
   if(!object(p)||!opaque(p.id)){add('invalid-player-id',c.id);continue;}
   if(players.has(p.id))add('duplicate-player-id',c.id,p.id);else players.set(p.id,{club:c,player:p});
   if(p.clubId!==undefined&&p.clubId!==c.id)add('player-club-mismatch',c.id,p.id);
  }
 }
 const playable=edition.playable;
 if(!Array.isArray(playable)||new Set(playable).size!==playable.length)add('invalid-playable-clubs');
 else {counts.playableClubs=playable.length;for(const id of playable)if(!byClub.has(id))add('dangling-playable-club',id);}
 const profiles=object(registry.worldProfiles)?registry.worldProfiles:{};
 for(const id of Object.keys(profiles))if(!players.has(id))add('dangling-world-profile',null,id);
 const staffClubs=new Map();
 if(!object(staffRegistry)||!Array.isArray(staffRegistry.clubs))add('invalid-staff-registry');
 else for(const c of staffRegistry.clubs){
  if(!object(c)||!Number.isSafeInteger(c.id)||!byClub.has(c.id)){add('dangling-staff-club',c?.id);continue;}
  if(staffClubs.has(c.id))add('duplicate-staff-club',c.id);else staffClubs.set(c.id,c);
  if(!Array.isArray(c.members)){add('invalid-staff-members',c.id);continue;}
  for(const member of c.members){
   counts.staffMembers++;
   if(!object(member)){add('invalid-staff-member',c.id);continue;}
   if(!opaque(member.id))add('invalid-staff-id',c.id);
   else if(staffIds.has(member.id)||players.has(member.id))add('duplicate-staff-id',c.id,member.id);
   staffIds.add(member.id);
   if(member.clubId!==c.id)add('staff-club-mismatch',c.id,member.id);
   if(typeof member.role!=='string'||!member.role.trim())add('invalid-staff-role',c.id,member.id);
   // Free multilingual descriptions are not a closed taxonomy of licences.
   if(member.historical===true){counts.staffHistorical++;warn('staff-historical',c.id,member.id);}
   else if(member.historical===false)counts.staffCurrentDeclared++;
   else {counts.staffHistoryUnknown++;warn('staff-history-unknown',c.id,member.id);}
   for(const key of ['sourceDate','observedAt'])if(member[key]!==null&&member[key]!==undefined&&!dated(member[key]))add('invalid-staff-'+key,c.id,member.id);
   if(member.sourceSeason!==null&&member.sourceSeason!==undefined&&(typeof member.sourceSeason!=='string'||!member.sourceSeason.trim()))add('invalid-staff-sourceSeason',c.id,member.id);
   if(!member.sourceDate&&!member.sourceSeason)warn('staff-source-unknown',c.id,member.id);
   if(dated(member.sourceDate)&&day(member.observedAt)&&Date.parse(member.sourceDate)>Date.parse(member.observedAt+'T23:59:59Z'))warn('staff-source-after-observation',c.id,member.id);
  }
 }
 const terms=openingApplies&&openingHeaderValid?opening.players:{};
 const aliases=openingApplies&&openingHeaderValid?opening.inactiveAliases:{};
 const openingErrorsBefore=errors.length;
 // Removed catalogue rows remain available only through the explicit production
 // compatibility source. Never invent an owner from the opening mapping alone.
 const legacyOwners=new Map(),legacy=registry.compatibilityAliases;
 const legacyErrorsBefore=errors.length;
 if(Object.hasOwn(registry,'compatibilityAliases')){
  if(!openingApplies||!object(legacy))add('invalid-compatibility-aliases');
  else for(const [id,row] of Object.entries(legacy)){
   if(!opaque(id)||!object(row)||Object.keys(row).length!==4||!['clubId','canonicalId','player','worldProfile'].every(k=>Object.hasOwn(row,k))||!object(row.player)||row.player.id!==id||!object(row.worldProfile))add('invalid-compatibility-alias',row?.clubId,id);
   const ownerClub=byClub.get(row?.clubId),canonical=players.get(row?.canonicalId),mapping=aliases[id];
   if(!ownerClub||ownerClub.leagueId!=='champ'||openingHeaderValid&&(!object(mapping)||mapping.clubId!==row?.clubId))add('compatibility-alias-club-mismatch',row?.clubId,id);
   if(!canonical||id===row?.canonicalId||object(legacy)&&Object.hasOwn(legacy,row?.canonicalId))add('dangling-compatibility-canonical',row?.clubId,id);
   if(openingHeaderValid&&(!object(mapping)||mapping.canonicalId!==row?.canonicalId))add('compatibility-alias-mapping-mismatch',row?.clubId,id);
   if(players.has(id))add('compatibility-alias-still-active',row?.clubId,id);
   if(ownerClub&&object(row?.player))legacyOwners.set(id,{club:ownerClub,player:row.player});
  }
 }
 const legacyValid=errors.length===legacyErrorsBefore;
 counts.legacyAliasPlayers=legacyValid?legacyOwners.size:null;
 counts.playersIncludingLegacyAliases=legacyValid?counts.players+legacyOwners.size:null;
 if(openingApplies&&openingHeaderValid){
  for(const [id,term] of Object.entries(terms)){
   const owner=players.get(id);
   if(!owner)add('dangling-opening-player',term?.clubId,id);
   if(!object(term)||!owner||term.clubId!==owner.club.id||!['prem','urc','champ'].includes(owner.club.leagueId))add('opening-club-mismatch',term?.clubId,id);
   if(!Number.isInteger(term?.endSeason)||term.endSeason<1||term.endSeason>6||!['season-end','minimum-season-end'].includes(term.endType))add('invalid-opening-term',term?.clubId,id);
   if(term?.endType==='season-end')counts.openingExact++;
   if(term?.endType==='minimum-season-end')counts.openingMinimum++;
   if(Object.hasOwn(aliases,id))add('opening-inactive-alias',term?.clubId,id);
   if(owner&&!Object.hasOwn(aliases,id)&&Number.isInteger(term?.endSeason)&&['season-end','minimum-season-end'].includes(term.endType)){
    counts.openingActiveTerms++;
    const baseline=foundation.players?.[id]?.contract?.endSeason??owner.player.contractEnd??profiles[id]?.contract?.endSeason;
    const effective=term.endType==='season-end'?term.endSeason:Math.max(baseline,term.endSeason);
    if(Number.isInteger(baseline)&&effective!==baseline)counts.openingChanges++;
   }
   warn('opening-evidence-not-embedded',term?.clubId,id);
  }
  for(const [id,alias] of Object.entries(aliases)){
   counts.inactiveAliases++;
   const catalogueOwner=players.get(id),owner=catalogueOwner||legacyOwners.get(id),canonical=players.get(alias?.canonicalId);
   if(catalogueOwner)counts.catalogueInactiveAliases++;
   if(!owner||!canonical)add('dangling-inactive-alias',alias?.clubId,id);
   if(!object(alias)||owner?.club.id!==alias.clubId||owner?.club.leagueId!=='champ')add('alias-club-mismatch',alias?.clubId,id);
   if(id===alias?.canonicalId||Object.hasOwn(aliases,alias?.canonicalId))add('inactive-alias-chain',alias?.clubId,id);
   if(owner&&canonical&&owner.club.id!==canonical.club.id)counts.aliasCrossClub++;
  }
 }
 if(openingApplies&&openingHeaderValid&&errors.length>openingErrorsBefore){openingStatus='invalid';warn('opening-register-unusable');}
 for(const c of clubs){
  if(!object(c)||!Number.isSafeInteger(c.id)||c.id<0||!Array.isArray(c.players))continue;
  const members=staffClubs.get(c.id)?.members,active=c.players.filter(p=>!object(aliases[p?.id])||aliases[p.id].clubId!==c.id);
  counts.prospectiveActivePlayers+=active.length;
  if(!Array.isArray(members)||!members.length)warn('staff-missing',c.id);
  clubReports.push({clubId:c.id,playable:Array.isArray(playable)&&playable.includes(c.id),cataloguePlayers:c.players.length,prospectiveActivePlayers:active.length,staffMembers:Array.isArray(members)?members.length:0,staffHistorical:Array.isArray(members)?members.filter(m=>m?.historical===true).length:0,rolesDocumented:Array.isArray(members)?members.filter(m=>typeof m?.role==='string'&&m.role.trim()).length:0,distinctRoleLabels:Array.isArray(members)?new Set(members.filter(m=>typeof m?.role==='string'&&m.role.trim()).map(m=>m.role.trim())).size:0,staffSourceDated:Array.isArray(members)?members.filter(m=>dated(m?.sourceDate)||!!m?.sourceSeason).length:0});
  for(const player of c.players){
   if(!object(player)||!opaque(player.id))continue;
   const french=foundation.players?.[player.id],profile=french||profiles[player.id],contract=profile?.contract;
   if(Array.isArray(profile?.factConflicts)&&profile.factConflicts.length)warn('source-conflicts-declared',c.id,player.id);
   if(!object(contract)){counts.contractUnknown++;warn('contract-unknown',c.id,player.id);continue;}
   if(!Number.isInteger(contract.endSeason)||contract.endSeason<1||contract.endSeason>20)add('invalid-contract-season',c.id,player.id);
   if(contract.endYear!==null&&contract.endYear!==undefined&&contract.endYear!==2026+contract.endSeason)add('contract-year-season-mismatch',c.id,player.id);
   if(contract.endMonth!==null&&contract.endMonth!==undefined&&(!Number.isInteger(contract.endMonth)||contract.endMonth<1||contract.endMonth>12))add('invalid-contract-month',c.id,player.id);
   if(!french&&player.contractEnd!==undefined&&player.contractEnd!==contract.endSeason)add('contract-profile-roster-mismatch',c.id,player.id);
   if(contract.sourceRef!==undefined&&contract.sourceRef!==null&&(typeof contract.sourceRef!=='string'||!contract.sourceRef.trim()))add('invalid-contract-source-reference',c.id,player.id);
   if(contract.sources!==undefined&&(!Array.isArray(contract.sources)||contract.sources.some(ref=>typeof ref!=='string'||!ref.trim())))add('invalid-contract-source-reference',c.id,player.id);
   if(contract.basis==='official'){
    counts.contractOfficialDeclared++;
    if(!contract.sourceRef&&(!Array.isArray(contract.sources)||!contract.sources.length))warn('contract-official-reference-missing',c.id,player.id);
    if(french&&Array.isArray(contract.sources))for(const ref of contract.sources)if(!Object.hasOwn(foundation.sources||{},ref))add('dangling-contract-source',c.id,player.id);
   }else if(contract.basis==='estimated'){counts.contractEstimated++;warn('contract-estimated',c.id,player.id);}
   else {counts.contractUnknown++;warn('contract-unknown',c.id,player.id);}
  }
 }
 const openingUnknown=['unknown','missing','invalid'].includes(openingStatus);
 if(openingUnknown){
  for(const key of ['prospectiveActivePlayers','legacyAliasPlayers','playersIncludingLegacyAliases','catalogueInactiveAliases','openingExact','openingMinimum','inactiveAliases','aliasCrossClub','openingActiveTerms','openingChanges'])counts[key]=null;
  for(const club of clubReports)club.prospectiveActivePlayers=null;
 }
 const status=errors.length?'invalid':openingUnknown?'unknown':'valid';
 return {edition:opaque(edition.id),mode:opaque(edition.mode),valid:status==='valid',status,opening:{status:openingStatus,applies:policyKnown?openingApplies:null},counts,errors,warnings:[...warnings.values()].sort((a,b)=>a.code.localeCompare(b.code)),clubs:clubReports.sort((a,b)=>a.clubId-b.clubId)};
}
function loadProductionInputs(root=path.resolve(__dirname,'..')){
 const read=name=>require(path.join(root,'native/engine',name));
 const compose=read('world-pacific-registry.cjs'),base=read('world-registry.json');
 const pacific=compose.extendWorldRegistry(base,read('world-pacific-extension.json'));
 const japan=compose.extendJapanRegistry(pacific,read('world-japan-extension.json'));
 const nationale=compose.extendNationaleRegistry(japan,read('world-nationale-extension.json'));
 const champ=compose.extendChampRegistry(nationale,read('world-champ-extension.json'));
 const editions=read('world-editions.cjs').createWorldEditions(base,pacific,japan,nationale,champ).entries;
 const staff=read('staff.cjs');
 return {editions,staffByDatabase:Object.fromEntries(editions.map(e=>{const selected=staff.forDatabase(e.id);return [e.id,selected.referenceRegistry||selected.registry];})),foundation:require(path.join(root,'dist/rugby-roster-foundation.js')),opening:read('world-initial-contracts.json')};
}
function auditAll(inputs){
 const editions=inputs.editions.map(edition=>auditEdition({edition,staffRegistry:inputs.staffByDatabase[edition.id],foundation:inputs.foundation,opening:inputs.opening}));
 return {schema:'staff-contract-quality-v1',referenceSeason:'2026/27',scope:'catalogue-anonyme-lecture-seule',privateEvidenceVerified:false,valid:editions.every(e=>e.valid),editions};
}
if(require.main===module){try{const report=auditAll(loadProductionInputs());process.stdout.write(JSON.stringify(report,null,2)+'\n');if(!report.valid)process.exitCode=1;}catch{process.stdout.write(JSON.stringify({schema:'staff-contract-quality-v1',valid:false,errors:[{code:'production-inputs-unavailable'}]})+'\n');process.exitCode=1;}}
module.exports={auditEdition,auditAll,loadProductionInputs};
