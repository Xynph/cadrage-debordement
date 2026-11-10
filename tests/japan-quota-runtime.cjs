'use strict';
const {test}=require('node:test'),a=require('node:assert/strict');
const {runInNewContext}=require('node:vm');
const Q=require('../native/engine/japan-quota-runtime.cjs');
const eligibility=require('../native/engine/japan-eligibility.cjs');
const rows=(cat,n,basis='estimated')=>Array.from({length:n},(_,i)=>({id:cat+'-'+i,category:cat,basis}));
test('registration keeps all locals, ten B/C and no more than three C; official declarations get priority',()=>{
 const A=rows('A-1',22),A2=rows('A-2',3),B=rows('B',10),C=rows('C',7);
 const declared={id:'confirmed-C',category:'C',basis:'official-2026-27'};
 const chosen=Q.selectRegistration([...B,...C,...A,...A2,declared]);
 a.ok(chosen.some(x=>x.id==='confirmed-C'));
 a.deepEqual(chosen.reduce((m,p)=>(m[p.category]=(m[p.category]||0)+1,m),{}),{'A-1':22,'A-2':3,B:9,C:1});
 a.equal(new Set(chosen.map(x=>x.id)).size,chosen.length);
 const withHighPriorityC=Q.selectRegistration([...B,...C.map(p=>({...p,rank:99})),declared]);
 a.equal(withHighPriorityC.filter(p=>p.category==='C').length,3);
 a.equal(withHighPriorityC.length,10);
});
test('a partial manual sheet cannot grow beyond nomination or on-field maxima',()=>{
 const A=rows('A-1',18),B=rows('B',10),C=rows('C',5);
 a.equal(Q.partialSheet([...A.slice(0,7),...B.slice(0,5),...C.slice(0,2)],[]),false);
 a.equal(Q.partialSheet(A.slice(0,14),B.slice(0,6)),true);
 a.equal(Q.partialSheet(A.slice(0,14),B.slice(0,7)),false);
 a.equal(Q.partialSheet(A.slice(0,14),C.slice(0,4)),false);
 a.equal(Q.partialSheet(A.slice(0,14),[A[2]]),false);
});
test('substitutions and a card-related vacant place cannot exceed field cap',()=>{
 const A=rows('A-1',12),B=rows('B',8),C=rows('C',6);
 const XV=[...A.slice(0,8),...B.slice(0,4),...C.slice(0,3)];
 a.equal(Q.changeAllowed(XV,A[0].id,B[4]),false);
 a.equal(Q.changeAllowed(XV,B[0].id,C[3]),false);
 a.equal(Q.changeAllowed(XV,B[0].id,A[8]),true);
 const withCard=XV.slice(1);
 a.equal(Q.changeAllowed(withCard,null,B[4]),false);
 a.equal(Q.changeAllowed(withCard,null,A[8]),true);
 a.equal(Q.changeAllowed(withCard,A[1].id,B[4]),false);
});

test('the opponent keeps legal tactical picks and repairs only a Japanese nomination outside quotas',()=>{
 const locals=rows('A-1',23), visitors=rows('B',7);
 const club={id:70,players:[...locals,...visitors]};
 const categories=Object.fromEntries(club.players.map(p=>[p.id,p]));
 const standard={lineup:locals.slice(0,15).map(p=>p.id),bench:locals.slice(15).map(p=>p.id)};
 const eligible={...standard,bench:[...standard.bench].reverse()};
 const excessive={lineup:[...standard.lineup.slice(0,8),...visitors.map(p=>p.id)],bench:standard.bench};
 let proposed=eligible, repair=eligible, builds=[];
 const context={
  S:{club:68,worldMode:{leagues:{'jlo-d1':{members:[68,70]},'jlo-d2':{members:[]}}}},
  CDWorldCareer:{edition:()=>({version:3,registry:{japanCategories:categories}}),sourcePlayer:()=>null},
  buildSheet:(team,lineup,bench)=>{builds.push({team,lineup,bench});return lineup.length?repair:standard;},
  managerSheet:()=>proposed,slotEligible:()=>false,benchEligible:()=>false,
  sheetErrors:()=>[],legalChange:()=>true,promoteCover:()=>{},eligibility
 };
 runInNewContext(`(${Q.factory.toString()})(eligibility).installHooks()`,context);
 a.equal(context.managerSheet(club),eligible);
 a.equal(builds.length,0);

 proposed=excessive;
 a.equal(context.managerSheet({...club,id:10}),excessive);
 a.equal(context.managerSheet({...club,id:68}),excessive);
 a.equal(builds.length,0);
 a.equal(context.managerSheet(club),eligible);
 a.deepEqual(builds.map(b=>[b.lineup,b.bench]),[[excessive.lineup,excessive.bench]]);

 builds=[];
 repair=excessive;
 a.equal(context.managerSheet(club),standard);
 a.equal(builds.length,2);
});
