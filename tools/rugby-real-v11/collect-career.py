"""Append public career-season rows for young/forward players absent from rankings.
No login. No assumption that a missing row means zero games. Central output only.
"""
import concurrent.futures,datetime,hashlib,html,json,re,sys,urllib.request,unicodedata
norm=lambda s: re.sub(r'[^a-z0-9]','',unicodedata.normalize('NFD',s).encode('ascii','ignore').decode().lower())
data=json.load(open(sys.argv[1]));master=json.load(open('modding/data06/rugby-master-2026-2027.json'))
seen={norm(p['name']) for l in data['lists'] for p in l['ranking']}
targets=[]
for league in ['top14','prod2']:
    group=[p for p in master['players'] if p['league']==league and norm(p['realName']) not in seen]
    # Prioritize rotation and youth with no 2025-26 individual evidence in master.
    group.sort(key=lambda p:(p.get('performance2025_2026') is not None,p['ageApprox']>23,p['gameplayPosition'] not in ['Talonneur','Pilier gauche','Pilier droit','Deuxième ligne','Troisième ligne','Numéro 8'],p['ageApprox'],p['id']))
    targets+=group[:30]
def fetch(p):
    slug=re.sub(r'[^a-z0-9]+','-',unicodedata.normalize('NFD',p['realName']).encode('ascii','ignore').decode().lower()).strip('-')
    url=f"https://{p['league']}.lnr.fr/joueur/{p['id'].split(':')[-1]}-{slug}"
    try:
        with urllib.request.urlopen(urllib.request.Request(url,headers={'User-Agent':'CD-research-public-statistics/1.0'}),timeout=22) as r: body=r.read()
        s=body.decode();title=re.search(r'<h1[^>]*>(.*?)</h1>',s,re.S)
        # URL IDs only accepted when displayed name agrees with master identity.
        if not title or norm(re.sub('<[^>]+>','',html.unescape(title[1])))!=norm(p['realName']): return {'url':url,'reason':'Displayed identity mismatch or absent'}
        match=re.search(r':rows="([^"]+)"',s)
        if not match:return {'url':url,'reason':'No public career table'}
        rows=json.loads(html.unescape(match[1]));out=[]
        for row in rows:
            if row['season']!='2025-2026' or row['competition'] not in ['TOP 14','PRO D2']:continue
            fields={'matchesPlayed':'matches','minutesPlayed':'minutes','points':'points','tries':'tries','penalties':'penalties','drops':'drops','yellowCards':'yellowCards','orangeCards':'orangeCards','redCards':'redCards'}
            stats={v:row[k] for k,v in fields.items() if isinstance(row.get(k),(int,float))}
            out.append({'name':p['realName'],'lnrId':p['id'].split(':')[-1],'historicalClub':row['club']['name'],'historicalPosition':None,'stats':stats,'sourceUrl':url,'sourceSha256':hashlib.sha256(body).hexdigest(),'retrievedAt':datetime.datetime.now(datetime.timezone.utc).isoformat(),'season':row['season'],'competition':row['competition'],'historicalLeague':'top14' if row['competition']=='TOP 14' else 'prod2'})
        return {'rows':out,'url':url,'reason':None if out else 'No public 2025-26 row; unknown not zero'}
    except Exception as e:return {'url':url,'reason':str(e)}
rows=[];miss=[]
with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
    for result in pool.map(fetch,targets):
        if result.get('rows'):rows+=result['rows']
        else:miss.append({'url':result['url'],'reason':result['reason']})
data['careerSeasonRows']=rows;data['unavailable']+=miss;data['careerAttempted']=len(targets)
open(sys.argv[1],'w').write(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
print('career requests',len(targets),'rows',len(rows),'missing',len(miss),flush=True)
