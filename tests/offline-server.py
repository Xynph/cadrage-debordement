#!/usr/bin/env python3
"""Contrôle du binaire natif et de la reprise après changement de port."""
import argparse,pathlib,tempfile,subprocess,json,time,urllib.request,http.cookiejar,urllib.error
p=argparse.ArgumentParser();p.add_argument('--binary',required=True);args=p.parse_args();binary=str(pathlib.Path(args.binary).resolve())
with tempfile.TemporaryDirectory(prefix='cadrage-') as folder:
 root=pathlib.Path(folder);ready=root/'ready.json';data=root/'donnees'
 def start():
  ready.unlink(missing_ok=True);proc=subprocess.Popen([binary,'--headless','--data-dir',str(data),'--ready-file',str(ready)],stdout=subprocess.PIPE,stderr=subprocess.PIPE)
  for _ in range(100):
   if ready.exists():break
   if proc.poll() is not None:raise RuntimeError(proc.stderr.read().decode())
   time.sleep(.05)
  assert ready.exists();info=json.loads(ready.read_text());client=urllib.request.build_opener(urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()));client.open(info['url']+'/?session='+info['token']).read();return proc,info,client
 def request(client,info,path,body=None):
  req=urllib.request.Request(info['url']+'/api/'+path,data=json.dumps(body).encode() if body is not None else None,headers={'X-CD-Local':'1','Content-Type':'application/json','Origin':info['url']});return json.load(client.open(req))
 proc,info,client=start()
 try:
  state=request(client,info,'storage');assert state['revision']==0
  raw='{"carrière":"équipe française","minute":12}'
  result=request(client,info,'storage',{'revision':0,'key':'bdt-v1','value':raw});assert result['revision']==1
  request(client,info,'storage',{'revision':1,'key':'bdt-match-view','value':'{"try":true}'})
  request(client,info,'quit',{});assert proc.wait(timeout=5)==0
  proc,second,client=start();restored=request(client,second,'storage');assert restored['items']['bdt-v1']==raw;assert restored['items']['bdt-match-view']=='{"try":true}'
  try:request(client,second,'storage',{'revision':0,'key':'bdt-v1','value':'obsolète'});raise AssertionError('conflit accepté')
  except urllib.error.HTTPError as e:assert e.code==409
  request(client,second,'quit',{});assert proc.wait(timeout=5)==0
 finally:
  if proc.poll() is None:proc.kill();proc.wait()
print(json.dumps({'passed':True,'checks':['amorçage par cookie','écritures réelles sur disque','préférences conservées','arrêt propre','reprise avec nouvelle origine','conflit refusé']},ensure_ascii=False))
