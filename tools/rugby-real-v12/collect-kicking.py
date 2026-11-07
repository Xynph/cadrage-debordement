"""Public historical transformation leaderboard payload. Reuse prior evidence; no auth."""
import html,json,re,urllib.request,hashlib,datetime,sys
out={'schema':'rugby-real-v12-extra-observations','season':'2025-2026','performanceCutoff':'2026-07-01','lists':[],'unavailable':[],'honours':[]}
for league in ['top14','prod2']:
 url=f'https://{league}.lnr.fr/classement/joueurs/meilleurs-taux-de-transformation/2025-2026'
 try:
  body=urllib.request.urlopen(url,timeout=30).read();doc=body.decode();m=re.search(r':ranking="([^"]+)"',doc)
  if not m:raise ValueError('No public payload')
  if f'/meilleurs-taux-de-transformation/2025-2026' not in doc:raise ValueError('Unconfirmed period')
  data=json.loads(html.unescape(m[1]));rows=[]
  for x in data:
   rows.append({'lnrId':re.search(r'/joueur/(\d+)',x['player']['url'])[1],'name':x['player']['name'],'historicalClub':x['club']['name'],'historicalPosition':x.get('position'),'rank':x['rank'],'observed':{k:v for k,v in x.items() if k not in ['player','club','position','rank']}})
  out['lists'].append({'league':league,'season':'2025-2026','scope':'season-transformation-leaderboard','sourceUrl':url,'retrievedAt':datetime.datetime.now(datetime.timezone.utc).isoformat(),'sourceSha256':hashlib.sha256(body).hexdigest(),'rows':rows})
  print(league,len(rows),rows[0],flush=True)
 except Exception as e:out['unavailable'].append({'sourceUrl':url,'reason':str(e)})
open(sys.argv[1],'w').write(json.dumps(out,ensure_ascii=False,indent=2)+'\n')
