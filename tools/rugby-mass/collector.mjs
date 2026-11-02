#!/usr/bin/env node
// RugbyData browser capture: captures real rendered tables + JSON without assuming an undocumented API.
import fs from 'node:fs/promises';
import {pathToFileURL} from 'node:url';
import path from 'node:path';
import crypto from 'node:crypto';
import {expandRankings} from './pagination.mjs';

export function validateURL(raw) {
  const u=new URL(raw);
  if(u.protocol!=='https:'||!['www.rugbydata.fr','rugbydata.fr'].includes(u.hostname)||!/^\/statistics\/competition\/\d+\/?$/.test(u.pathname)) throw Error('Use an HTTPS RugbyData competition statistics URL');
  return u.href;
}
export function optionForSeason(options,season) {
  const variants=[season,season.replace('-','/'),season.slice(0,4)+'/'+season.slice(7)];
  const found=options.filter(x=>variants.some(v=>x.text.includes(v)||x.value.includes(v)));
  if(found.length!==1)throw Error('Season unavailable or ambiguous: '+season);
  return found[0];
}
export function argsOf(argv) {
  const a={};
  for(let i=0;i<argv.length;i+=2){if(!argv[i]?.startsWith('--')||!argv[i+1])throw Error('Bad options');a[argv[i].slice(2)]=argv[i+1];}
  if(!a.url||!a.out||!/^20\d{2}-20\d{2}$/.test(a.season||''))throw Error('Usage: --url URL --season YYYY-YYYY --out DIR');
  a.url=validateURL(a.url);a.limit=Number(a.limit??300);a.delay=Number(a.delay??750);
  if(!Number.isInteger(a.limit)||a.limit<1||a.limit>2000||!Number.isInteger(a.delay)||a.delay<200||a.delay>10000)throw Error('Invalid bounds');
  return a;
}
function redact(url){const u=new URL(url);for(const key of [...u.searchParams.keys()])if(/token|key|auth|session|secret/i.test(key))u.searchParams.set(key,'REDACTED');return u.href;}
export async function capture(a,engine) {
  const {chromium}=engine??await import('playwright');
  const browser=await chromium.launch({headless:true});
  try{
    const page=await browser.newPage({locale:'fr-FR'});
    const json=[],seen=new Set(),failures=[];
    page.on('response',async response=>{
      try{
        if(!response.ok()||!/json/i.test(response.headers()['content-type']||''))return;
        const u=new URL(response.url());
        if(!['www.rugbydata.fr','rugbydata.fr'].includes(u.hostname))return;
        const data=await response.json();
        if(!data||typeof data!=='object')return;
        const digest=crypto.createHash('sha256').update(JSON.stringify(data)).digest('hex');
        if(seen.has(digest)||json.length>=a.limit)return;
        seen.add(digest);json.push({url:redact(response.url()),sha256:digest,data});
      }catch(e){failures.push(String(e));}
    });
    await page.goto(a.url,{waitUntil:'domcontentloaded',timeout:45000});
    await page.waitForTimeout(a.delay);
    const selects=page.locator('select');
    let chosen;
    for(let i=0;i<await selects.count();i++){
      const options=await selects.nth(i).locator('option').evaluateAll(xs=>xs.map(x=>({value:x.value,text:(x.textContent||'').trim()})));
      try{chosen={i,option:optionForSeason(options,a.season)};break;}catch{}
    }
    if(!chosen)throw Error('Selected season not available as native select. Inspect rendered UI before adapting; no output created.');
    await selects.nth(chosen.i).selectOption(chosen.option.value);
    await page.waitForTimeout(a.delay);
    if(await selects.nth(chosen.i).inputValue()!==chosen.option.value)throw Error('Season selection not confirmed');
    const tab=page.getByText(/statistiques individuelles/i).first();
    if(await tab.count())await tab.click({timeout:4000}).catch(()=>{});
    await page.waitForTimeout(a.delay);
    await fs.mkdir(a.out,{recursive:true});
    const checkpoint=path.join(a.out,'rugbydata-'+a.url.match(/\d+\/?$/)[0].replace('/','')+'-'+a.season+'-checkpoint.json');
    const pagination=await expandRankings(page,{rounds:Math.min(a.limit,100),delay:a.delay,checkpoint});
    const tables=await page.locator('table').evaluateAll(xs=>xs.map(t=>({headers:[...t.querySelectorAll('th')].map(x=>x.textContent.trim()),rows:[...t.querySelectorAll('tr')].map(tr=>[...tr.querySelectorAll('td')].map(x=>x.textContent.trim())).filter(xs=>xs.length)})));
    const visible=await page.locator('body').innerText();
    const out={schema:'rugbydata-raw-v1',seasonRequested:a.season,seasonSelected:chosen.option,source:a.url,capturedAt:new Date().toISOString(),pagination,json,tables,text:visible.slice(0,1000000),failures};
    await fs.mkdir(a.out,{recursive:true});
    const file=path.join(a.out,'rugbydata-'+a.url.match(/\d+\/?$/)[0].replace('/','')+'-'+a.season+'.json');
    await fs.writeFile(file,JSON.stringify(out,null,2)+'\n');
    return {file,JSONResponses:json.length,tables:tables.length,paginationComplete:pagination.complete};
  }finally{await browser.close();}
}
if(process.argv[1]&&import.meta.url===pathToFileURL(path.resolve(process.argv[1])).href)capture(argsOf(process.argv.slice(2))).then(console.log).catch(e=>{console.error(e.message);process.exitCode=1;});
