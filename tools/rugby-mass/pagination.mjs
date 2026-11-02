import fs from 'node:fs/promises';
import crypto from 'node:crypto';

// Browser-only UI pagination: never guess API endpoints or bypass access controls.
export async function expandRankings(page,{rounds=30,delay=750,checkpoint=null}={}) {
  if(!Number.isInteger(rounds)||rounds<1||rounds>100)throw Error('Invalid rounds');
  const history=[];
  for(let n=0;n<rounds;n++) {
    const before=await page.locator('body').innerText();
    const buttons=page.getByText(/voir plus/i);
    const count=await buttons.count();
    if(!count){history.push({round:n,expanded:0,status:'no-more-button'});break;}
    let expanded=0;
    for(let i=count-1;i>=0;i--) {
      try{await buttons.nth(i).click({timeout:1500});expanded++;}catch{}
    }
    await page.waitForTimeout(delay);
    const after=await page.locator('body').innerText();
    const beforeHash=crypto.createHash('sha256').update(before).digest('hex');
    const afterHash=crypto.createHash('sha256').update(after).digest('hex');
    const status=beforeHash===afterHash?'stalled':'advanced';
    history.push({round:n,expanded,beforeHash,afterHash,status});
    if(checkpoint)await fs.writeFile(checkpoint,JSON.stringify({version:1,history,complete:status==='stalled'},null,2)+'\n');
    if(status==='stalled'||!expanded)break;
  }
  const complete=history.length>0 && ['stalled','no-more-button'].includes(history.at(-1).status);
  return {complete,history};
}
