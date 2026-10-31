'use strict';
const {setTimeout: pause} = require('node:timers/promises');
const LNR = /^https:\/\/(?:top14|prod2)\.lnr\.fr\/joueur\/\d+-[\w-]+$/;
function validUrl(url) { if (!LNR.test(url)) throw Error('Non-LNR profile URL'); return url; }
function kind(error) {
  const status = error?.status;
  if ([401,402,403,429].includes(status)) return 'stop';
  if (status >= 500 && status < 600 || error?.name === 'AbortError' || ['ETIMEDOUT','ECONNRESET','EAI_AGAIN'].includes(error?.code)) return 'retry';
  return 'fail';
}
function createTransport({fetcher=fetch, firecrawlKey=null, firecrawlBudget=0, timeoutMs=18000, retries=1, pauseFn=pause}={}) {
  if (!Number.isInteger(firecrawlBudget) || firecrawlBudget < 0 || !Number.isInteger(retries) || retries < 0 || retries > 3) throw Error('Invalid limits');
  let spent=0, stopped=false, reason=null;
  async function call(url,options) {
    const ctl = new AbortController();
    const timer = setTimeout(()=>ctl.abort(),timeoutMs);
    try {
      const res = await fetcher(url,{...options,signal:ctl.signal});
      if (!res.ok) {const error=Error('HTTP '+res.status); error.status=res.status; throw error;}
      return res;
    } finally {clearTimeout(timer);}
  }
  async function retry(fn) {
    for (let i=0;;i++) try {return await fn();} catch(error) {
      const type=kind(error);
      if (type==='stop') {stopped=true;reason='HTTP '+error.status;throw error;}
      if (type!=='retry'||i>=retries) throw error;
      await pauseFn(Math.min(8000,250*(2**i)));
    }
  }
  async function direct(url) {
    validUrl(url);
    if(stopped) throw Error('Transport stopped: '+reason);
    const res=await retry(()=>call(url,{headers:{Accept:'text/html','User-Agent':'CadrageDebordementDataResearch/1.0'}}));
    return await res.text();
  }
  async function scrape(url) {
    validUrl(url);
    if(stopped) throw Error('Transport stopped: '+reason);
    if(!firecrawlKey) throw Error('FIRECRAWL_API_KEY required');
    if(spent>=firecrawlBudget) throw Error('Firecrawl budget exhausted');
    spent++; // reserve before making the paid request; never retry a paid call
    const res=await call('https://api.firecrawl.dev/v2/scrape',{method:'POST',headers:{Authorization:'Bearer '+firecrawlKey,'Content-Type':'application/json'},body:JSON.stringify({url,formats:['markdown']})});
    const json=await res.json();
    if(!json.success||typeof json.data?.markdown!=='string'||!json.data.markdown.trim()) throw Error('Empty Firecrawl result');
    return json.data.markdown;
  }
  return {direct,scrape,stats:()=>({firecrawlCalls:spent,stopped,reason})};
}
module.exports={createTransport,validUrl,kind};
