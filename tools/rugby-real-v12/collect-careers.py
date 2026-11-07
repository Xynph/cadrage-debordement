"""Central public season history collection, with explicit unknowns and no dossiers.
Usage: python3 collect-careers.py output.json [limit=1592] [workers=6]
No account, no gated API, no reattempt on blocked access or rate limits.
"""
import concurrent.futures,datetime,hashlib,html,json,re,sys,time,urllib.request,urllib.error,unicodedata
master=json.load(open('modding/data06/rugby-master-2026-2027.json'))
limit=int(sys.argv[2]) if len(sys.argv)>2 else 1592
norm=lambda s:re.sub('[^a-z0-9]','',unicodedata.normalize('NFD',s).encode('ascii','ignore').decode().lower())
started=time.monotonic()
def fetch(p):
 slug=re.sub('[^a-z0-9]+','-',unicodedata.normalize('NFD',p['realName']).encode('ascii','ignore').decode().lower()).strip('-')
 url=f"https://{p['league']}.lnr.fr/joueur/{p['id'].split(':')[-1]}-{slug}"
 base={'playerId':p['id'],'name':p['realName'],'sourceUrl':url,'seasons':[]}
 try:
  req=urllib.request.Request(url,headers={'User-Agent':'CadrageDebordement-public-season-research/1.0'})
  with urllib.request.urlopen(req,timeout=25) as f:body=f.read()
  doc=body.decode();title=re.search(r'<h1[^>]*>(.*?)</h1>',doc,re.S)
  if not title or norm(re.sub('<[^>]+>','',html.unescape(title[1])))!=norm(p['realName']):return {**base,'status':'unknown','reason':'Displayed identity mismatch or absent'}
  m=re.search(r':rows="([^"]+)"',doc)
  if not m:return {**base,'status':'unknown','reason':'No public career table'}
  rows=json.loads(html.unescape(m[1]));stats=[]
  fields=['matchesPlayed','minutesPlayed','points','tries','penalties','drops','yellowCards','orangeCards','redCards']
  for row in rows:
   if row['season'] not in ['2023-2024','2024-2025','2025-2026'] or row['competition'] not in ['TOP 14','PRO D2']:continue
   values={k:row[k] for k in fields if isinstance(row.get(k),(int,float)) and not isinstance(row[k],bool)}
   if any(v<0 for v in values.values()):raise ValueError('Negative statistic')
   stats.append({'season':row['season'],'competition':row['competition'],'historicalClub':row['club']['name'],'stats':values})
  return {**base,'status':'observed' if stats else 'unknown','reason':None if stats else 'No public row in completed three-season window','seasons':stats,'sourceSha256':hashlib.sha256(body).hexdigest()}
 except urllib.error.HTTPError as e:return {**base,'status':'unknown','reason':f'HTTP {e.code}; no bypass/retry'}
 except Exception as e:return {**base,'status':'unknown','reason':str(e)}
rows=[]
def save():
 result={'schema':'rugby-real-v12-public-careers','performanceCutoff':'2026-07-01','knowledgeDate':'2026-11-07','attempted':len(rows),'expected':limit,'completed':len(rows)==limit,'retrievedAt':datetime.datetime.now(datetime.timezone.utc).isoformat(),'records':rows}
 open(sys.argv[1],'w').write(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
with concurrent.futures.ThreadPoolExecutor(max_workers=int(sys.argv[3]) if len(sys.argv)>3 else 6) as pool:
 for r in pool.map(fetch,master['players'][:limit]):
  rows.append(r)
  if len(rows)%50==0:
   save();print(json.dumps({'attempted':len(rows),'observed':sum(bool(x['seasons']) for x in rows),'observed2526':sum(any(s['season']=='2025-2026' for s in x['seasons']) for x in rows),'seconds':round(time.monotonic()-started)}),flush=True)
save();print('COMPLETE',len(rows),round(time.monotonic()-started),flush=True)
