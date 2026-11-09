'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),vm=require('node:vm');
// Verbatim guards from 66d6225: independent witnesses, not reconstructed expectations.
const witness="function saveObject(v){return v!==null&&typeof v==='object'&&!Array.isArray(v)}\nfunction saveArray(v,max=1000){return Array.isArray(v)&&v.length<=max}\nfunction saveNumber(v,min=-1e12,max=1e12){return typeof v==='number'&&Number.isFinite(v)&&v>=min&&v<=max}\nfunction saveInt(v,min=0,max=1e9){return Number.isInteger(v)&&v>=min&&v<=max}";
const lines=fs.readFileSync(path.join(__dirname,'../dist/saves.js'),'utf8').split(/\r?\n/),current=lines.filter(l=>l.startsWith('const nativeSaveFinite=')||l.startsWith('function saveNumber(')||l.startsWith('function saveInt(')||l.startsWith('function saveObject(')||l.startsWith('function saveArray(')).join('\n');
function contexts(){return [witness,current].map(source=>{const c=vm.createContext({});vm.runInContext(source,c);return c;});}
function result(c,fn,value,bounds){c.value=value;c.bounds=bounds;try{return {value:vm.runInContext(fn+'(value,...bounds)',c)};}catch(e){return {error:e.name,message:e.message};}}
test('Cached numeric predicates preserve finite/integer guards, sensitive numeric values and coercion boundaries',()=>{
 const pair=contexts(),values=[undefined,null,false,true,'0','1','NaN',NaN,Infinity,-Infinity,0,-0,1,-1,.5,-.5,Number.MIN_VALUE,-Number.MIN_VALUE,Number.MAX_VALUE,-Number.MAX_VALUE,Number.MAX_SAFE_INTEGER,Number.MAX_SAFE_INTEGER+1,1e12,-1e12,1e12+1,-1e12-1,1e9+1,1e308,new Number(1),{},[],[1],()=>1,Symbol('number'),1n];
 const bounds=[[],[undefined,undefined],[-Infinity,Infinity],[-1,1],[0,0],[1,-1],[null,null],['0','1'],[NaN,1],[0,NaN],[Number.MIN_VALUE,Number.MAX_VALUE],[Symbol('min'),10]];let checks=0;
 for(const fn of ['saveNumber','saveInt'])for(const v of values)for(const range of bounds){assert.deepEqual(result(pair[1],fn,v,range),result(pair[0],fn,v,range));checks++;}
 assert.equal(checks,840);
 for(const c of pair){assert.equal(result(c,'saveNumber',Infinity,[-Infinity,Infinity]).value,false);assert.equal(result(c,'saveInt',Infinity,[-Infinity,Infinity]).value,false);assert.equal(result(c,'saveNumber','1',[]).value,false);assert.equal(result(c,'saveInt',.5,[]).value,false);}
});
test('Numeric guard short-circuiting preserves bound side effects and rejects coercible values before touching bounds',()=>{
 for(const fn of ['saveNumber','saveInt'])for(const v of [0,2,Infinity,NaN,'1',{},new Number(1),1n]){
  const outputs=contexts().map(c=>{const trace=[],min={valueOf(){trace.push('min');return 1;}},max={valueOf(){trace.push('max');return 3;}};const r=result(c,fn,v,[min,max]);return {r,trace};});assert.deepEqual(outputs[1],outputs[0]);
 }
 const outputs=contexts().map(c=>{const trace=[];const v={valueOf(){trace.push('value');throw Error('must not coerce');}};return {r:result(c,'saveNumber',v,[]),trace};});assert.deepEqual(outputs[1],outputs[0]);assert.deepEqual(outputs[1],{r:{value:false},trace:[]});
});

test('Cached array predicate preserves ordinary objects, proxies, bounds and getter order',()=>{
 const revoked=Proxy.revocable([],{});revoked.revoke();const values=[undefined,null,false,true,0,'array',{},Object.create(null),[],[1],Array(2),new Uint8Array(2),new Number(1),new Date(0),new Proxy([],{}),revoked.proxy];
 const pair=contexts();for(const fn of ['saveObject','saveArray'])for(const value of values)for(const bounds of [[],[0],[1],[2],[-1],[Infinity],[NaN],['1']])assert.deepEqual(result(pair[1],fn,value,bounds),result(pair[0],fn,value,bounds));
 const results=contexts().map(c=>{const trace=[],value=new Proxy([1,2],{get(target,key){trace.push(String(key));return Reflect.get(target,key);}}),max={valueOf(){trace.push('max');return 2;}};return {r:result(c,'saveArray',value,[max]),trace};});assert.deepEqual(results[1],results[0]);assert.deepEqual(results[1],{r:{value:true},trace:['length','max']});
});
