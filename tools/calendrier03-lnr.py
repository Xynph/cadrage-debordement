#!/usr/bin/env python3
"""Conservative LNR public-calendar importer. No third-party dependencies."""
import argparse, datetime as dt, html, json, re, sys, unicodedata, urllib.request
from html.parser import HTMLParser
from pathlib import Path

TEAMS = {
 "top14": ["Aviron Bayonnais","Castres Olympique","LOU Rugby","Montpellier Hérault Rugby","RC Toulon","RC Vannes","Racing 92","Section Paloise","Stade Français Paris","Stade Rochelais","Stade Toulousain","USA Perpignan","Union Bordeaux-Bègles","ASM Clermont"],
 "prod2": ["AS Béziers Hérault","Biarritz Olympique PB","CA Brive","Colomiers Rugby","FC Grenoble Rugby","Nissa Rugby","Oyonnax Rugby","Provence Rugby","RC Narbonnais","SU Agen","Soyaux-Angoulême XV","Stade Aurillacois","US Dax","US Montauban","USON Nevers","Valence Romans"]
}
ALIASES = {"valence romans dr": "Valence Romans", "narbonne": "RC Narbonnais",
 "stade nicois rugby": "Nissa Rugby", "montpellier hr": "Montpellier Hérault Rugby",
 "biarritz olympique pays basque": "Biarritz Olympique PB"}
MONTHS = {"janvier":1,"fevrier":2,"mars":3,"avril":4,"mai":5,"juin":6,"juillet":7,
 "aout":8,"septembre":9,"octobre":10,"novembre":11,"decembre":12}
def norm(v):
 v=unicodedata.normalize("NFKD",v)
 return re.sub(r"\s+"," ",''.join(c for c in v if not unicodedata.combining(c)).lower()).strip()

CANON = {k: {norm(t):t for t in vals} for k,vals in TEAMS.items()}
class ReadPage(HTMLParser):
 def __init__(self):
  super().__init__();self.anchors=[];self.depth=0;self.bits=[];self.visible=[];self.skip=0
 def handle_starttag(self,tag,attrs):
  if tag in ("script","style"):self.skip+=1
  if tag=="a":self.depth+=1;self.bits.append([])
 def handle_data(self,data):
  if self.skip:return
  x=data.strip()
  if not x:return
  self.visible.append(x)
  if self.depth:self.bits[-1].append(x)
 def handle_endtag(self,tag):
  if tag in ("script","style") and self.skip:self.skip-=1
  if tag=="a" and self.depth:
   parts=self.bits.pop();self.anchors.append(" ".join(parts).strip());self.depth-=1
def parse(html_source,league,round_no):
 parser=ReadPage();parser.feed(html_source)
 text=" ".join(parser.visible)
 if not re.search(r"Journée\s+"+str(round_no)+r"\b",text,re.I):
  raise ValueError("Page does not confirm round "+str(round_no))
 names=[]
 for raw in parser.anchors:
  k=norm(raw)
  team=CANON[league].get(k) or ALIASES.get(k)
  if team and team in TEAMS[league]:
   if not names or names[-1]!=team:names.append(team)
 expected=7 if league=="top14" else 8
 if len(names)!=expected*2 or len(set(names))!=expected*2:
  raise ValueError("Ambiguous match pairing: "+league+" J"+str(round_no)+", anchors="+repr(names))
 dates=re.findall(r"(?:lundi|mardi|mercredi|jeudi|vendredi|samedi|dimanche)\\s+(\\d{1,2})\\s+(janvier|février|fevrier|mars|avril|mai|juin|juillet|août|aout|septembre|octobre|novembre|décembre|decembre)", text, re.I)
 if not dates:raise ValueError("Official round day missing")
 day,month=dates[0];year=2026 if MONTHS[norm(month)]>=7 else 2027
 begin=dt.date(year,MONTHS[norm(month)],int(day))
 return [(names[i],names[i+1]) for i in range(0,len(names),2)],begin
def slot(league,round_no,i,weekend):
 """Simulation only: plausible TV pattern, varied across rounds and home games."""
 if league=="top14":
  options=[(5,"14:30"),(5,"16:35"),(5,"16:35"),(5,"16:35"),(5,"21:00"),(6,"15:00"),(6,"21:05")]
  if round_no%3==1:options=[(5,"14:30"),(5,"16:35"),(5,"16:35"),(5,"18:00"),(5,"21:00"),(6,"16:00"),(6,"21:05")]
 else:
  options=[(3,"21:00"),(4,"19:00"),(4,"19:30"),(4,"19:30"),(4,"19:30"),(4,"19:30"),(4,"21:00"),(4,"21:00")]
  if round_no%2:options[1]=(4,"19:30")
 weekday,clock=options[i]
 # Weekend is a date inside the round's given period; derive closest requested weekday.
 difference=(weekday-weekend.weekday())%7
 date=weekend+dt.timedelta(days=difference)
 return date.isoformat()+"T"+clock+":00+02:00" if date.month in range(4,11) else date.isoformat()+"T"+clock+":00+01:00"
def main(argv=None):
 ap=argparse.ArgumentParser();ap.add_argument("--input-dir",type=Path,
 help="Cached HTML files top14-j1.html ... prod2-j30.html, useful offline")
 ap.add_argument("--output",type=Path,required=True);ap.add_argument("--allow-partial",action="store_true")
 opts=ap.parse_args(argv)
 all_fixtures=[];missing=[];audits=[]
 for league,total in (("top14",26),("prod2",30)):
  for rnd in range(1,total+1):
   url=f"https://{'top14' if league=='top14' else 'prod2'}.lnr.fr/calendrier-et-resultats/2026-2027/j{rnd}"
   try:
    if opts.input_dir:
     raw=(opts.input_dir/(league+"-j"+str(rnd)+".html")).read_text(encoding="utf-8")
    else:
     req=urllib.request.Request(url,headers={"User-Agent":"CadrageDebordement-CalendarResearch/1.0"})
     with urllib.request.urlopen(req,timeout=18) as response:
      raw=response.read().decode("utf-8")
    matches,round_day=parse(raw,league,rnd)
    # No guessed weekend from source. Scheduler awaits official per-round date/window.
    for i,(home,away) in enumerate(matches):
     all_fixtures.append({"id":f"{league}-r{rnd:02d}-m{i+1:02d}",
      "competition":league,"round":rnd,"home":home,"away":away,
      "officialKickoff":None,"officialKickoffVerified":False,
      "simulatedKickoff":slot(league,rnd,i,round_day),"simulatedKickoffStatus":"invented-gameplay-time",
      "roundReferenceDate":round_day.isoformat(),
      "score":None,"sourceUrl":url})
    audits.append({"league":league,"round":rnd,"matches":len(matches),"source":url})
   except Exception as e:
    missing.append({"league":league,"round":rnd,"reason":str(e)[:220]})
 if missing and not opts.allow_partial:
  raise SystemExit("REJECTED incomplete schedule: "+str(len(missing))+" rounds failed; no output written")
 total=len(all_fixtures)
 if total!=422 and not opts.allow_partial:raise SystemExit("REJECTED: "+str(total)+"/422")
 payload={"season":"2026-2027","careerStart":"2026-07-01","completeness":"complete" if total==422 and not missing else "partial","count":total,
 "officialDataSource":"LNR public pages","fixtures":all_fixtures,"audits":audits,"missing":missing,
 "note":"Simulated kickoffs are not LNR announcements; results never imported."}
 opts.output.parent.mkdir(parents=True,exist_ok=True)
 opts.output.write_text(json.dumps(payload,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
 print(json.dumps({"extracted":total,"missingRounds":len(missing),"complete":not missing and total==422}))
if __name__=="__main__":main()
