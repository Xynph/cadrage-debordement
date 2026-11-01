import datetime as dt
import unittest
from importlib.machinery import SourceFileLoader
from pathlib import Path
mod=SourceFileLoader("lnr",str(Path(__file__).resolve().parents[1]/"tools/calendrier03-lnr.py")).load_module()
class ImportChecks(unittest.TestCase):
 def page(self,teams,round_no,with_time=False):
  a="<h1>Journée "+str(round_no)+"</h1><p>samedi 05 septembre</p>"
  for i,t in enumerate(teams):
   a+='<a href="/club/'+str(i)+'">'+t+'</a>'
   if with_time and i==0:a+="<span>19h00</span>"
  return a
 def test_valid_top14(self):
  matches,date=mod.parse(self.page(mod.TEAMS["top14"],1,True),"top14",1)
  self.assertEqual(len(matches),7)
  self.assertEqual(matches[0][2],"19:00")
  self.assertEqual(date,dt.date(2026,9,5))
 def test_valid_prod2(self):
  matches,date=mod.parse(self.page(mod.TEAMS["prod2"],1),"prod2",1)
  self.assertEqual(len(matches),8)
  self.assertIsNone(matches[0][2])
 def test_reject_ambiguous(self):
  with self.assertRaises(ValueError):
   mod.parse(self.page(mod.TEAMS["top14"][:10],1),"top14",1)
 def test_simulated_slots(self):
  self.assertNotEqual(mod.slot("top14",2,0,dt.date(2026,9,12)),mod.slot("top14",2,6,dt.date(2026,9,12)))
  self.assertTrue(mod.slot("prod2",1,0,dt.date(2026,8,27)).endswith("+02:00"))
if __name__=="__main__":unittest.main()
