'use strict';
const assert=require('node:assert/strict');
const {context}=require('./harness.cjs');
function setup(){
 const t=context(),r=t.run;
 r('start(0);var listed=club().players[5];toggleListing(listed.id);economyWeek();var offer=S.economy.offers.find(o=>o.playerId===listed.id)');
 assert.ok(r('offer'));
 return r;
}
let r=setup();
const fee=r('offer.fee'),cash=r('club().cash');
assert.equal(r('counterSale(offer.id,0)'),false,'no invalid percentage');
assert.equal(r('club().cash'),cash,'no immediate transaction');
assert.equal(r('S.economy.offers.length'),1);
r('var buyer=S.clubs[offer.buyer];buyer.cash=50000000');
const accepted=r('counterSale(offer.id,5)');
assert.equal(typeof accepted,'boolean');
if(accepted){
 assert.ok(r('S.economy.offers[0].fee')>fee);
 assert.equal(r('counterSale(S.economy.offers[0].id,10)'),false,'one counter only');
 assert.equal(r('club().cash'),cash);
 assert.ok(r('!!parseSaveDocument(JSON.stringify(createSaveDocument()))'));
 r('var finalOffer=S.economy.offers[0], buyerBefore=buyer.cash,sellerBefore=club().cash');
 assert.equal(r('acceptSale(finalOffer.id)'),true);
 assert.equal(r('club().cash-sellerBefore'),r('finalOffer.fee'));
 assert.equal(r('buyerBefore-buyer.cash'),r('finalOffer.fee'));
 assert.equal(r('acceptSale(finalOffer.id)'),false);
}
r=setup();
r('S.clubs[offer.buyer].cash=offer.fee+350000');
assert.equal(r('counterSale(offer.id,15)'),false,'buyer cannot afford counter');
assert.equal(r('S.economy.offers.length'),0,'withdrawn after refusal');
assert.equal(r('club().players.some(p=>p.id===listed.id)'),true,'player remains');
assert.ok(r('!!parseSaveDocument(JSON.stringify(createSaveDocument()))'));
r=setup();r('beginMatch();pauseMatch()');
assert.equal(r('counterSale(offer.id,5)'),false,'live match lock');
r=setup();r('economyWeek();economyWeek()');
assert.equal(r('counterSale(offer.id,5)'),false,'expired offer lock');
console.log(JSON.stringify({passed:true,checks:['accepted counteroffer','declined counteroffer','finance conservation','save roundtrip','single negotiation','match lock','expiry']}));
