'use strict';
const assert=require('node:assert/strict');
const {snapshot}=require('../dist/v58-native-bridge.js');
const legacy={club:0,clubs:[{id:0}],season:1};
const old=JSON.stringify(legacy);
assert.deepEqual(snapshot(legacy),{enabled:false,clubId:0,season:1,offers:0,pending:false});
assert.equal(JSON.stringify(legacy),old);
const current={...legacy,managerMobilityVersion:1,managerMobility:{version:1,applications:[
{season:1,status:'offered'},{season:1,status:'rejected'},{season:2,status:'offered'}],pending:{toClub:1}}};
const before=JSON.stringify(current);
assert.deepEqual(snapshot(current),{enabled:true,clubId:0,season:1,offers:1,pending:true});
assert.equal(JSON.stringify(current),before);
assert.equal(Object.isFrozen(snapshot(current)),true);
assert.equal(snapshot(null),null);
console.log('V58 native read-only bridge PASS');
