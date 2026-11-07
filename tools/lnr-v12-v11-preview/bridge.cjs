'use strict';
// Isolated preview. No production global mutation and no master write.
const C=require('../rugby-real-v12/review.cjs');
const D=require('../rugby-real-v12/depth.cjs');
const N=require('../rugby-real-v12/native.cjs');
const POS=['Pilier gauche','Talonneur','Pilier droit','Deuxième ligne','Deuxième ligne','Troisième ligne','Troisième ligne','Numéro 8','Demi de mêlée','Demi d’ouverture','Ailier','Centre','Centre','Ailier','Arrière'];
const bound=(x,a,b)=>Math.max(a,Math.min(b,x));
function candidate(master,report){
 const base=C.apply(master,report);
 return D.build(base,'mild');
}
function playerForNative(basePlayer,realPlayer){
 if(!basePlayer||!realPlayer||basePlayer.id!==realPlayer.id)throw Error('Player identity mismatch');
 if(!N.SLOTS[realPlayer.gameplayPosition])throw Error('Unknown specialist role');
 const [slot,fam]=N.SLOTS[realPlayer.gameplayPosition];
 const p=C.clone(basePlayer);
 // This is an explicitly estimated gameplay position, not a newly verified LNR role.
 p.pos=POS[slot];p.fam=fam;
 p.skills=C.project(realPlayer);
 p.rating=realPlayer.ratingV12;
 p.skillBase=p.rating; // skill() must start at exact projected skills, never add an initial bonus
 p.attributesV2=C.clone(realPlayer.attributesV2);
 p.gameplayPosition=realPlayer.gameplayPosition;
 p.ageApprox=p.age;
 p.hiddenTraitsV2=C.clone(realPlayer.hiddenTraitsV2);
 p.potential=realPlayer.potential; // original historical scale remains untouched
 const historicalRoom=bound(realPlayer.potential-realPlayer.rating,0,99);
 p.previewDevCeiling=bound(p.rating+historicalRoom,p.rating,99);
 p.lnrRatingsPreview='v12-depth-mild';
 if(!Object.values(p.skills).every(v=>Number.isFinite(v)&&v>=20&&v<=97))throw Error('Invalid projected skill');
 return p;
}
function alignRoster(original,selected){
 if(!Array.isArray(original)||!Array.isArray(selected))throw Error('Invalid roster');
 const map=new Map(selected.map(p=>[p.id,p]));
 const seen=new Set();
 const roster=original.map(p=>{const q=map.get(p.id);if(!q)return C.clone(p);seen.add(p.id);return playerForNative(p,q);});
 if(map.size!==seen.size)throw Error('Missing selected LNR identities');
 return roster;
}
function initDevelopment(p,nativeEnsureDevelopment){
 if(p.lnrRatingsPreview!=='v12-depth-mild')return p;
 if(typeof nativeEnsureDevelopment!=='function')throw Error('Native development initialization required');
 nativeEnsureDevelopment(p);
 if(!p.dev||!Number.isFinite(p.dev.potential))throw Error('Native development contract mismatch');
 // Headroom relative to the historical rating is preserved, not the raw absolute potential.
 p.dev.potential=p.previewDevCeiling;
 delete p.previewDevCeiling;
 return p;
}
function evolveOnce(p,state,inputs,agingStep){
 if(p.lnrRatingsPreview!=='v12-depth-mild')throw Error('Not a V12 preview player');
 if(typeof agingStep!=='function')throw Error('V11 aging engine required');
 if(!Number.isInteger(state?.season)||state.season<1)throw Error('Invalid season');
 if(state.lastSeason===state.season)return {player:C.clone(p),state:C.clone(state),changes:[]};
 if(p.age!==state.age)throw Error('Age state mismatch');
 // Exactly one annual system: NEVER also call native ageDevelopmentPlayer for this player.
 const r=agingStep(p,state,inputs);
 const out=C.clone(r.player);out.skills=C.project(out);
 // Keep skill() delta zero at the season boundary; cumulative growth will be managed
 // only by the compatible development adapter, not the fictional growPlayer path.
 out.rating=p.rating;out.skillBase=p.rating;
 out.potential=p.potential;
 out.age=r.state.age;
 if(out.dev){out.dev.lastYear=r.state.season;out.dev.seasonStart=out.rating;}
 return {...r,player:out};
}
module.exports={candidate,playerForNative,alignRoster,initDevelopment,evolveOnce,POS};
