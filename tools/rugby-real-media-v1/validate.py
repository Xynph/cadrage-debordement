#!/usr/bin/env python3
"""Verify original image bytes and build a private, offline head/bust gallery."""
import argparse, collections, csv, hashlib, html, json, pathlib, re, unicodedata
from PIL import Image, ImageDraw, ImageFont
PLACEHOLDER_SHA='60a0c0dc2df281db65ad3183dc7aa79ea1ee0d14bb583ff0d0cbc086cf5fd406'
def normalized(s):
 for _ in range(2):s=html.unescape(s)
 return re.sub(r'[^a-z0-9]+','',unicodedata.normalize('NFKD',s).encode('ascii','ignore').decode().lower())
def safe_path(pack,relative):
 p=(pack/relative).resolve()
 if not p.is_relative_to(pack.resolve()):raise ValueError('Path outside pack')
 return p

def inspect(pack):
 m=json.loads((pack/'manifest.json').read_text());groups=collections.defaultdict(list);variants=[];byclub=collections.defaultdict(list);verified=0
 for e in m['entries']:
  byclub[e['club']].append(e)
  if e['status']!='downloaded':
   assert e['kind']=='portrait' and e['path'] is None and not e['available'];continue
  raw=safe_path(pack,e['path']).read_bytes();assert hashlib.sha256(raw).hexdigest()==e['sha256'],e['id']+' bytes changed'
  with Image.open(safe_path(pack,e['path'])) as im:
   im.load();assert im.size==(e['width'],e['height']);assert im.format==e['format']
  verified+=1
  if e['kind']=='portrait':
   assert e['sha256']!=PLACEHOLDER_SHA and 'no-avatar' not in e['url'];groups[e['sha256']].append(e['id'])
   source=e.get('sourceName') or e.get('sourceAlt','')
   if normalized(e['name'])!=normalized(source):variants.append({'id':e['id'],'name':e['name'],'sourceName':source,'identityMatch':e['identityMatch']})
 duplicates=[ids for ids in groups.values() if len(ids)>1];assert not duplicates,duplicates
 report={'filesVerified':verified,'sameImageAssignedToDifferentPlayers':duplicates,'sourceCaptionVariants':variants,'byClub':{c:{'portraits':sum(e['kind']=='portrait' and e['status']=='downloaded' for e in es),'unresolved':sum(e['status']=='unavailable' for e in es)} for c,es in sorted(byclub.items())}}
 (pack/'validation.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
 font=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',13);sheets=pack/'review';sheets.mkdir(exist_ok=True)
 def sheet(es,name,cols=8,cw=150,ch=220):
  canvas=Image.new('RGB',(cols*cw,max(1,(len(es)+cols-1)//cols)*ch),(235,238,240));d=ImageDraw.Draw(canvas)
  for i,e in enumerate(es):
   x=i%cols*cw;y=i//cols*ch
   with Image.open(safe_path(pack,e['path'])) as original:
    im=original.convert('RGBA');im.thumbnail((cw-6,ch-40));canvas.paste(im,(x+(cw-im.width)//2,y),im)
   d.text((x+3,y+ch-37),e['name'][:20],font=font,fill=(16,25,35));d.text((x+3,y+ch-20),e['id'],font=font,fill=(60,70,80))
  canvas.save(sheets/(name+'.jpg'),quality=88)
 sheet([e for e in m['entries'] if e['kind']=='logo'],'logos',6,200,200)
 for club,es in byclub.items():sheet([e for e in es if e['kind']=='portrait' and e['status']=='downloaded'],club)
 sheet([e for e in m['entries'] if e.get('sourceKind')=='official-club' and e['status']=='downloaded'],'fallbacks')
 fields=['kind','id','name','club','league','status','path','width','height','bytes','sourcePage','url','jerseyStatus','portraitStyle','rightsStatus']
 with (pack/'inventory.csv').open('w',encoding='utf-8-sig',newline='') as f:
  w=csv.DictWriter(f,fields,extrasaction='ignore');w.writeheader();w.writerows(m['entries'])
 with (pack/'missing.csv').open('w',encoding='utf-8-sig',newline='') as f:
  w=csv.DictWriter(f,['id','name','club','league','reason','sourcePage'],extrasaction='ignore');w.writeheader();w.writerows(m['missing'])
 # CSS frames originals without changing image files. Each card also links the full source file.
 body=[]
 for c,es in sorted(byclub.items()):
  logo=next(e for e in es if e['kind']=='logo');cards=[]
  for e in es:
   if e['kind']!='portrait':continue
   name=html.escape(e['name']);caption=name+' · '+e['id']
   if e['status']=='downloaded':
    path=html.escape(e['path'],quote=True);cards.append('<article><a href="'+path+'"><div class="frame"><img loading="lazy" src="'+path+'" alt="'+name+'"></div></a><p>'+caption+'</p></article>')
   else:cards.append('<article><div class="frame missing">Portrait indisponible</div><p>'+caption+'</p></article>')
  body.append('<section><h2><img class="logo" src="'+html.escape(logo['path'],quote=True)+'">'+html.escape(c)+'</h2><div class="grid">'+''.join(cards)+'</div></section>')
 summary=m['summary'];page='''<!doctype html><html lang="fr"><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>Rugby Réel — portraits et logos</title><style>body{font:16px system-ui;background:#eef1f5;color:#172133;margin:30px}h1{margin-bottom:8px}.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(160px,1fr));gap:14px}article{background:white;border-radius:10px;overflow:hidden}p{font-size:13px;padding:0 10px}.frame{height:230px;overflow:hidden;background:#dce1e7}.frame img{display:block;width:100%;height:auto;min-height:230px;object-position:center top}.missing{display:grid;place-items:center;color:#536075}.logo{height:65px;width:85px;object-fit:contain;vertical-align:middle;margin-right:15px}section{margin:35px 0}</style><h1>Rugby Réel — 2026-2027</h1>'''+f'<p>{summary["logosDownloaded"]} logos · {summary["realPortraits"]} portraits · {summary["playersUnresolved"]} indisponibles. Cliquer sur une photo ouvre son original. Les cadrages affichés ne modifient pas les fichiers.</p><p>Sources officielles LNR et clubs, collecte du 7 novembre 2026. Certains clichés datent de saisons antérieures. Les droits de diffusion ne sont pas établis.</p>'+''.join(body)+'</html>'
 (pack/'index.html').write_text(page)
 print(json.dumps({'filesVerified':verified,'portraitDuplicates':len(duplicates),'captionVariants':len(variants),'clubs':len(byclub)}));return m,report
if __name__=='__main__':
 a=argparse.ArgumentParser();a.add_argument('--pack',type=pathlib.Path,required=True);inspect(a.parse_args().pack)
