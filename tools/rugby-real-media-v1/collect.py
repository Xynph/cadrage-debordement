#!/usr/bin/env python3
"""Collect original public rugby media to a private working pack; never alters game data.
Uses official roster IDs, bounded concurrency, cache and resumable downloads.
"""
import argparse,collections,concurrent.futures,hashlib,html,json,os,pathlib,re,subprocess,time,urllib.request,urllib.error
from html.parser import HTMLParser
from PIL import Image

ROOT=pathlib.Path(__file__).resolve().parents[2]
try:
 import httpx
 CLIENT=httpx.Client(proxy=os.environ.get('HTTPS_PROXY'),follow_redirects=True,timeout=httpx.Timeout(35,connect=15),limits=httpx.Limits(max_connections=12,max_keepalive_connections=12))
except ImportError:CLIENT=None

UA='Cadrage-Debordement-RugbyReal-Media-Collection/1.0'
class Images(HTMLParser):
 def __init__(self):super().__init__();self.images=[]
 def handle_starttag(self,tag,attrs):
  if tag.lower()=='img':self.images.append(dict(attrs))
def get(url,timeout=35):
 if CLIENT is not None:
  with CLIENT.stream('GET',url,headers={'User-Agent':UA,'Accept':'*/*'},timeout=timeout) as r:
   r.raise_for_status();parts=[];length=0
   for b in r.iter_bytes():
    length+=len(b)
    if length>24*1024*1024:raise ValueError('Media exceeds24MiB')
    parts.append(b)
   return b''.join(parts),r.headers.get('Content-Type',''),str(r.url)
 req=urllib.request.Request(url,headers={'User-Agent':UA,'Accept':'*/*'})
 with urllib.request.urlopen(req,timeout=timeout) as r:
  b=r.read(24*1024*1024+1)
  if len(b)>24*1024*1024:raise ValueError('Media exceeds24MiB')
  return b,r.headers.get('Content-Type',''),r.geturl()
def catalogue():
 js="const vm=require('vm'),fs=require('fs');const s=fs.readFileSync('dist/lnr-rosters-data.js','utf8');console.log(JSON.stringify(vm.runInNewContext(s+';LNR_CATALOGUE')));"
 return json.loads(subprocess.check_output(['node','-e',js],cwd=ROOT,text=True))
def source(club,pack):
 slug,league,url,roster=club
 cache=pack/'sources'/(slug+'.html');cache.parent.mkdir(parents=True,exist_ok=True)
 if cache.exists():raw=cache.read_bytes()
 else:
  raw,ct,final=get(url);cache.write_bytes(raw)
 doc=Images();doc.feed(raw.decode('utf-8'))
 found={};logos=[]
 for img in doc.images:
  src=html.unescape(img.get('src') or img.get('data-src') or '')
  if src.startswith('//'):src='https:'+src
  if not src.startswith('https://cdn.lnr.fr/'):continue
  m=re.search(r'/joueur/(\d+)-[^/]+/photo/photoFull\.[^/?]+',src)
  if m:found['lnr:'+m.group(1)]={'url':src,'alt':img.get('alt','')}
  if f'/club/{slug}/photo/logo.' in src:logos.append(src)
 return {'slug':slug,'league':league,'page':url,'logoUrl':next(iter(dict.fromkeys(logos)),None),'images':found,'roster':roster,'sourceSha256':hashlib.sha256(raw).hexdigest()}
def download(item,pack):
 key=item['kind']+'-'+item['id'].replace(':','-')
 meta=pack/'cache'/(key+'.json');meta.parent.mkdir(parents=True,exist_ok=True)
 if meta.exists():
  try:old=json.loads(meta.read_text())
  except (ValueError,OSError):old={}
  if old.get('url')==item['url'] and old.get('path') and (pack/old['path']).is_file():return old
 out=dict(item)
 try:
  raw,ct,final=get(item['url']);sha=hashlib.sha256(raw).hexdigest()
  if item.get('sha256') and sha!=item['sha256']:
   return {**item,'status':'download_error','error':'Source bytes changed; existing files and cache preserved'}
  from io import BytesIO
  im=Image.open(BytesIO(raw));im.load()
  ext={'JPEG':'jpg','PNG':'png','WEBP':'webp','GIF':'gif','AVIF':'avif'}.get(im.format)
  if not ext:raise ValueError('Unsupported image format '+str(im.format))
  file=pathlib.Path('logos' if item['kind']=='logo' else 'players')/item['league']/item['club']/(item['id'].replace(':','-')+'.'+ext)
  target=pack/file;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(raw)
  out.update(status='downloaded',path=file.as_posix(),bytes=len(raw),sha256=sha,width=im.width,height=im.height,format=im.format,hasAlpha='A' in im.getbands(),contentType=ct,finalUrl=final)
 except Exception as e:out.update(status='download_error',error=type(e).__name__+': '+str(e)[:250])
 meta.write_text(json.dumps(out,ensure_ascii=False));return out

def collect(pack,workers=6):
 pack.mkdir(parents=True,exist_ok=True);master_path=ROOT/'modding/data06/rugby-master-2026-2027.json';original=master_path.read_bytes();master=json.loads(original)
 cat=catalogue();clubs=cat['clubs'];assert len(clubs)==30 and len(master['players'])==1592
 sources=[]
 with concurrent.futures.ThreadPoolExecutor(max_workers=min(workers,4)) as pool:
  fut={pool.submit(source,c,pack):c for c in clubs}
  for f in concurrent.futures.as_completed(fut):
   c=fut[f]
   try:s=f.result();sources.append(s);print('SOURCE '+json.dumps({'club':s['slug'],'playerURLs':len(s['images']),'logo':bool(s['logoUrl'])}),flush=True)
   except Exception as e:sources.append({'slug':c[0],'league':c[1],'page':c[2],'images':{},'logoUrl':None,'error':str(e)});print('SOURCE_ERROR '+c[0]+' '+str(e),flush=True)
 smap={s['slug']:s for s in sources};items=[];missing=[]
 for c in clubs:
  s=smap[c[0]]
  if s['logoUrl']:items.append({'kind':'logo','id':c[0],'club':c[0],'league':c[1],'name':c[0],'url':s['logoUrl'],'sourcePage':s['page'],'sourceKind':'official-league','rightsStatus':'not-cleared-for-public-distribution'})
  else:missing.append({'kind':'logo','id':c[0],'club':c[0],'reason':'no-official-url'})
 for p in master['players']:
  s=smap[p['club']];image=s['images'].get(p['id'])
  if image:items.append({'kind':'portrait','id':p['id'],'name':p['realName'],'club':p['club'],'league':p['league'],'url':image['url'],'sourceAlt':image['alt'],'sourcePage':s['page'],'sourceKind':'official-league','rightsStatus':'not-cleared-for-public-distribution','identityMatch':'official-source-player-id','jerseyStatus':'needs-visual-review'})
  else:missing.append({'kind':'portrait','id':p['id'],'name':p['realName'],'club':p['club'],'league':p['league'],'reason':'not-found-in-current-official-roster','sourcePage':s['page']})
 entries=[]
 with concurrent.futures.ThreadPoolExecutor(max_workers=workers) as pool:
  fs=[pool.submit(download,i,pack) for i in items]
  for f in concurrent.futures.as_completed(fs):
   entries.append(f.result())
   if len(entries)%100==0:print('DOWNLOAD '+json.dumps({'done':len(entries),'total':len(items),'errors':sum(x['status']!='downloaded' for x in entries)}),flush=True)
 group=collections.defaultdict(list)
 for e in entries:
  if e.get('sha256') and e['kind']=='portrait':group[e['sha256']].append(e['id'])
 for e in entries:
  if e['kind']=='portrait' and e.get('sha256'):
   e['sameContentPlayerIds']=group[e['sha256']]
   e['contentStatus']='shared-image-review' if len(group[e['sha256']])>1 else 'unique-source-image'
 entries.sort(key=lambda e:(e['kind'],e['league'],e['club'],e['id']))
 report={'schema':'rugby-real-media-originals-v1','collectedAt':'2026-11-07','season':'2026-2027','referenceRosterSha256':hashlib.sha256(original).hexdigest(),'productionAssetsChanged':False,'scope':{'clubs':30,'players':1592},'sources':[{k:v for k,v in s.items() if k not in ['images','roster']} for s in sorted(sources,key=lambda s:s['slug'])],'summary':{'logosDownloaded':sum(e['kind']=='logo' and e['status']=='downloaded' for e in entries),'portraitFilesDownloaded':sum(e['kind']=='portrait' and e['status']=='downloaded' for e in entries),'uniquePortraitContents':len(group),'sharedPortraitFiles':sum(e['kind']=='portrait' and len(e.get('sameContentPlayerIds',[]))>1 for e in entries),'missing':len(missing),'downloadErrors':sum(e['status']=='download_error' for e in entries),'bytes':sum(e.get('bytes',0) for e in entries)},'entries':entries,'missing':missing,'limitations':['Original files are preserved, without synthetic faces or jerseys.','Current official source-player ID association does not independently verify facial identity or current jersey.','Shared-content images require review and are not automatically counted as real portraits.','Public reuse is not inferred from public accessibility.']}
 assert master_path.read_bytes()==original
 (pack/'manifest.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
 print('COMPLETE '+json.dumps(report['summary']),flush=True)
 return report
def replay(manifest,pack,workers=6):
 """Replay curated URLs; fail if publisher bytes changed instead of silently accepting them."""
 report=json.loads(manifest.read_text());items=[e for e in report['entries'] if e['status']=='downloaded']
 master=ROOT/'modding/data06/rugby-master-2026-2027.json'
 before=hashlib.sha256(master.read_bytes()).hexdigest()
 if before!=report['referenceRosterSha256']:raise ValueError('Roster version differs from manifest')
 pack.mkdir(parents=True,exist_ok=True)
 def checked(e):
  result=download(e,pack)
  if result['status']!='downloaded':return {'id':e['id'],'error':result.get('error')}
  actual=hashlib.sha256((pack/result['path']).read_bytes()).hexdigest()
  if actual!=e['sha256'] or result['path']!=e['path']:return {'id':e['id'],'error':'Source changed; do not use until reviewed'}
  return None
 with concurrent.futures.ThreadPoolExecutor(max_workers=workers) as pool:errors=[r for r in pool.map(checked,items) if r]
 assert hashlib.sha256(master.read_bytes()).hexdigest()==before
 (pack/'replay-results.json').write_text(json.dumps({'verified':len(items)-len(errors),'errors':errors},indent=2)+'\n')
 if errors:raise ValueError(str(len(errors))+' sources failed verification; see replay-results.json')
 (pack/'manifest.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
 print('REPLAY '+json.dumps({'verified':len(items),'unresolved':report['summary']['playersUnresolved']}))
 return report

if __name__=='__main__':
 parser=argparse.ArgumentParser();parser.add_argument('--pack',type=pathlib.Path,required=True);parser.add_argument('--workers',type=int,default=6);parser.add_argument('--manifest',type=pathlib.Path);a=parser.parse_args();replay(a.manifest,a.pack,a.workers) if a.manifest else collect(a.pack,a.workers)
