"""One-shot preparation on a fixed audit base; never updates any Git reference."""
import hashlib, json, os, subprocess, sys
from pathlib import Path
BASE='6dfa6cf94efbc7f65e9c9f6a1521f497a1d338a7'
TREE='ec0620beb0fa86d5bfe0a1d826242655d7dfa621'
REPO='Xynph/cadrage-debordement'
FILES=['dist/game.js','dist/career-integration.js','tests/economy-audit.cjs','tests/champion-budget-regression.cjs','.github/workflows/economy-audit.yml','docs/correctifs-prime-entretien.md','DEVELOPPEMENT.md']
def blobhash(b): return hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()
def replace(path,old,new,count=1):
 p=Path(path);s=p.read_text();assert s.count(old)==count,(path,old,s.count(old));p.write_text(s.replace(old,new))
if '--publish-tree' in sys.argv:
 assert os.environ.get('GITHUB_REPOSITORY')==REPO
 assert os.environ.get('GITHUB_REF')=='refs/heads/prepare/champion-budget-native'
 def api(endpoint,payload):
  raw=subprocess.run(['gh','api','--method','POST','repos/'+REPO+'/git/'+endpoint,'--input','-'],input=json.dumps(payload),text=True,capture_output=True,check=True)
  return json.loads(raw.stdout)
 entries=[]
 for name in FILES:
  b=Path(name).read_bytes();obj=api('blobs',{'content':b.decode(),'encoding':'utf-8'});assert obj['sha']==blobhash(b)
  entries.append({'path':name,'mode':'100644','type':'blob','sha':obj['sha']})
 tree=api('trees',{'base_tree':TREE,'tree':entries})
 manifest={'base':BASE,'baseTree':TREE,'tree':tree['sha'],'files':entries,'writes':'unreferenced Git blobs/tree only; no refs or PR mutations'}
 Path('candidate-proof/tree.json').write_text(json.dumps(manifest,indent=2))
 print(json.dumps(manifest));sys.exit(0)
expected={'dist/game.js':'41f0a877ea3aca1766af9eb52c4859c5e3f9939c','dist/career-integration.js':'20c4fcf609394c8c1b52a4e9a49d6c7632dd2a2d','tests/economy-audit.cjs':'67f6f72064e1714615be2925b2a426037d340cba','.github/workflows/economy-audit.yml':'5115ebac2aac7ca7e36b28edf25b703a8206b79f','DEVELOPPEMENT.md':'f3d05c16981ef9a71a9152d1245e9445c1ab566d'}
for name,sha in expected.items(): assert blobhash(Path(name).read_bytes())==sha,('unexpected source',name)
replace('dist/game.js',"club().cash+=1000000;S.ledger.unshift({title:'Prime de champion',amount:1000000})","ledgerEntry('Prime de champion',1000000)")
replace('dist/career-integration.js','weeklyWages:totalWages(),weeklyOtherCosts:s?.academyInvestment||0,',"weeklyWages:totalWages(),weeklyOtherCosts:(s?.academyInvestment||0)+\n   (typeof worldActive==='function'&&worldActive()?worldUpkeep(worldClub(S.club).facilities):0),")
replace('dist/career-integration.js','salaires actuels et formation.','salaires actuels, formation et entretien des installations actives.')
replace('tests/economy-audit.cjs','16 fixture observation: forecast V41 omits known facilities upkeep','16 regression: forecast V41 includes known facilities upkeep')
replace('tests/economy-audit.cjs',"A.close(predicted-actual,upkeep,'Forecast gap');assert.ok(upkeep>0);","A.close(predicted,actual,'Forecast reconciled');assert.equal(model.weeklyOtherCosts,upkeep);assert.ok(upkeep>0);")
replace('tests/economy-audit.cjs',"status:'confirmed-gap',weeklyEuros:upkeep","status:'fixed-and-reconciled',weeklyEuros:upkeep")
replace('tests/economy-audit.cjs','Confirmed-gap assertions are reproductions, not proof of economic correctness','Boundary fixtures and reconciliation are not proof of economic balance')
replace('.github/workflows/economy-audit.yml',"      - 'tests/economy-audit.cjs'","      - 'tests/economy-audit.cjs'\n      - 'tests/champion-budget-regression.cjs'",2)
replace('.github/workflows/economy-audit.yml','          CD_ECONOMY_TEST_REPORT: economy-transactions.json','          CD_ECONOMY_TEST_REPORT: economy-transactions.json\n          CD_CHAMPION_BUDGET_REPORT: champion-budget-regression.json')
replace('.github/workflows/economy-audit.yml','          node tests/economy-audit.cjs','          node tests/economy-audit.cjs\n          node tests/champion-budget-regression.cjs')
replace('.github/workflows/economy-audit.yml','          path: economy-transactions.json','          path: |\n            economy-transactions.json\n            champion-budget-regression.json')
doc='''# Correctifs natifs : prime de champion et entretien previsionnel

## Origine et perimetre
Audit #85, base main e706d6a, candidat 6dfa6cf : Vannes champion en saison 7 (profil modeste, graine 99173) cree 101 ecritures alors que le validateur en autorise 100. Le previsionnel V41 omet aussi les frais natifs des installations actives. Les preuves historiques de #85 restent intactes.

## Correction livrable
- `finishRound` utilise `ledgerEntry` pour la prime de 1 000 000 : credit unique et bornage centralise. Aucun changement du montant, du vainqueur, des regles sportives ou du format des sauvegardes.
- `careerBudgetModel` additionne formation et `worldUpkeep` du club gere lorsque le monde est actif. Niveau initial 2 : aucun surcout ; niveau 3 : 2 900 par periode. La projection et ses variantes sont en lecture seule et ne prelevent rien.
- La description du previsionnel mentionne les frais d'entretien. Les conventions de periodes, la billetterie, les primes, le calendrier et les coefficients economiques restent inchanges.

## Tests et avant/apres
`tests/champion-budget-regression.cjs` comprend 22 groupes : finale simulee nativement sur une fixture de frontiere avec registre plein, titre/non-titre, reprise automatique et import confirme, idempotence, erreur de stockage/reessai, anciennes carrieres sans monde, intersaison et rejet maintenu d'un registre de 101 lignes. Previsions controlees aux niveaux 2, 3, 7 et 10, trois sponsors, formation et scenarios alternatifs.
Les memes assertions ont ete executees avant/apres en preparation : 14 echecs sur les sources historiques, puis 22 groupes reussis sur le candidat. La CI finale sur SHA exact demeure obligatoire.

Le banc #85 est repris sans enlever de campagne : 3 profils x 2 graines x 15 saisons, dont modeste/99173. La reproduction de l'oubli de frais devient une assertion d'egalite prevision/reglement. Les preuves de depassement artificiel restent negatives. Les runners continuent a refuser les campagnes incompletes et a conserver l'etat fictif en cas d'echec.

## Limites et sauvegardes deja affectees
Ce correctif previent le depassement ; il ne modifie ni n'importe silencieusement les anciennes sauvegardes invalides. La copie de recuperation existante reste preservee et necessite une procedure explicite sur copie si l'utilisateur rencontre deja ce cas. Aucune sauvegarde personnelle utilisee. Pas de test Windows natif ni de reequilibrage global revendique.
La source UI-02C #84 et les modules UI-03 du producteur restent hors perimetre. #75 reste intacte. Livraison uniquement apres PR non brouillon, CI complete verte et CI post-fusion.
'''
Path('docs/correctifs-prime-entretien.md').write_text(doc)
p=Path('DEVELOPPEMENT.md');p.write_text(p.read_text()+'''\n\n## Correctifs prime de champion et prevision V41 (31 octobre 2026)

- Audit #85 conserve : depassement de registre confirme en saison 7, profil modeste, graine 99173 ; oubli de l'entretien dans careerBudgetModel.
- Prime de champion via ledgerEntry : un seul credit de 1 000 000, registre borne a 100, sans modifier saves.js ni les regles du championnat.
- Prevision V41 : formation + entretien natif des installations actives ; aucun surcout pour les anciennes carrieres sans monde ou le niveau initial 2. La projection est sans effet de bord.
- 22 groupes de regression avant/apres, dont reprise automatique, import confirme, titre au registre plein, idempotence et erreur d'ecriture ; les six campagnes natives de 15 saisons de #85 sont conservees. Les rapports CI sur le dernier SHA et apres fusion font autorite, pas cette entree preparatoire.
- Les preuves d'audit historiques demeurent dans #85 ; aucune modification des branches UI-02/UI-03 du producteur, aucune sauvegarde personnelle touchee, #75 intacte. Pas de changement des coefficients economiques ni de test Windows natif revendique.
- Dossier : docs/correctifs-prime-entretien.md. Les sauvegardes deja invalides ne sont pas reparees silencieusement.
''')
Path('candidate-proof').mkdir(exist_ok=True)
Path('candidate-proof/expected-files.json').write_text(json.dumps(FILES))
print('Prepared seven explicit paths on fixed audit tree; no reference modified.')
