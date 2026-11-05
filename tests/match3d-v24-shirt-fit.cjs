'use strict';
const assert=require('node:assert/strict');
const {fitShirt}=require('../tools/match3d-v24-shirt-fit.cjs');
// A garment vertex inside the torso must move outside and follow the same joint.
const result=fitShirt({positions:[.2,.2,-.01],joints:[7,0,0,0],weights:[1,0,0,0]},
 {positions:[0,0,0,1,0,0,0,1,0],indices:[0,1,2],joints:[2,0,0,0,2,0,0,0,2,0,0,0],weights:[1,0,0,0,1,0,0,0,1,0,0,0]},.012);
assert.ok(Math.abs(result.positions[2]-.012)<1e-6,'cloth must clear the real skin surface');
assert.equal(result.joints[0],2,'cloth follows underlying torso rather than unrelated arm');
assert.equal(result.weights[0],1);assert.equal(result.positions.length,3);
assert.throws(()=>fitShirt({positions:[NaN,0,0]},{}),/finite|invalid/i);
console.log('PASS shirt clearance and anatomical skin-weight transfer');
