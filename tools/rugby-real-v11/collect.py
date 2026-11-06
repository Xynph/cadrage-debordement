"""Public HTML payload collector. No auth, no images, no individual dossiers.
Usage: python3 tools/rugby-real-v11/collect.py output.json
"""
import html,json,re,sys,urllib.request,datetime,hashlib

def ranking(document):
    match=re.search(r':ranking="([^"]+)"',document)
    if not match: return []
    return json.loads(html.unescape(match[1]))

def collect():
    lists=[];errors=[]
    for league in ['top14','prod2']:
        for metric in ['temps-de-jeu','meilleurs-realisateurs','meilleurs-marqueurs-dessais','nombre-de-cartons']:
            url=f'https://{league}.lnr.fr/classement/joueurs/{metric}/2025-2026'
            try:
                req=urllib.request.Request(url,headers={'User-Agent':'CD-research-public-statistics/1.0'})
                with urllib.request.urlopen(req,timeout=35) as f: body=f.read()
                doc=body.decode('utf8')
                if '2025-2026' not in doc or f'/classement/joueurs/{metric}/2025-2026' not in doc: raise ValueError('season/page unconfirmed')
                rows=ranking(doc)
                if not rows: errors.append({'url':url,'reason':'No public ranking payload; not accessed via authenticated endpoint'});continue
                clean=[]
                fields={'nbMinutesPlayed':'minutes','nbMatchesPlayed':'matches','nbPoints':'points','nbTries':'tries','nbYellowCards':'yellowCards','nbRedCards':'redCards','nbOrangeCards':'orangeCards'}
                for r in rows:
                    p=r['player']; stats={}
                    for k,v in r.items():
                        if k in fields: stats[fields[k]]=int(str(v).replace(' ','').replace('\u00a0','').replace('\u202f',''))
                    if not stats: raise ValueError('No recognized numeric fields '+str(list(r)))
                    clean.append({'name':p['name'],'lnrId':re.search(r'/joueur/(\d+)',p['url'])[1],'historicalClub':r['club']['name'],'historicalPosition':r.get('position'),'rank':r['rank'],'stats':stats})
                lists.append({'league':league,'season':'2025-2026','scope':'season-ranking-as-published; may include finals, not same denominator as match sheet career', 'metric':metric,'sourceUrl':url,'retrievedAt':datetime.datetime.now(datetime.timezone.utc).isoformat(),'sourceSha256':hashlib.sha256(body).hexdigest(),'ranking':clean})
                print(league,metric,len(clean),list(rows[0]),flush=True)
            except Exception as e: errors.append({'url':url,'reason':str(e)})
    return {'schema':'rugby-real-public-2025-26-v11','cutoff':'2026-07-01','lists':lists,'unavailable':errors,'observations':[]}
if __name__=='__main__':
    data=collect();open(sys.argv[1],'w').write(json.dumps(data,ensure_ascii=False,indent=2)+'\n');print('rows',sum(len(x['ranking']) for x in data['lists']),'errors',data['unavailable'])
