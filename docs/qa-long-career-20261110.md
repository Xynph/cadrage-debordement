# Réception longue durée avec points de reprise

Le pilote `scripts/qa-long-career.cjs` exécute le code de production et produit
un rapport HTML autonome et un JSON exploitable. Il n'injecte ni score, ni
trésorerie, ni joueur dans les carrières. La graine, le commit source, l'empreinte
des fichiers moteur et les durées réelles sont consignés dans le rapport.

## Deux campagnes distinctes

**Club.** Création d'une carrière Base commune avec le club 29, conférences de
presse obligatoires, composition native et renfort de couverture uniquement si
le moteur le propose, matchs délégués et transitions de saison confirmées. Les
points de contrôle d'ouverture, mi-saison et clôture passent par le vrai export,
l'import, la fermeture puis la réouverture du worker depuis le profil disque.
L'état sportif et le curseur aléatoire doivent être conservés exactement. Les
identifiants des joueurs et rencontres doivent être uniques ; les soldes et
salaires doivent rester finis. Une trésorerie fictive négative est permise et
n'est pas transformée en échec comptable artificiel.

**International.** Module de carrière international de production et registre
mondial livré (3 208 joueurs), de 2026 à 2031. La France est gérée avec la
composition automatique native. Un match national en attente est joué avant de
changer de date ; les autres résultats sont ceux du module natif. Chaque fin
d'année est restaurée en JSON puis validée. Le pilote contrôle les courriers,
convocations et participations uniques, les dates monotones, l'idempotence à
date égale et la clôture du Mondial 2031. Ce scénario ne constitue pas une
carrière complète de club : il ne simule ni le vieillissement du catalogue
mondial ni les finances des clubs, et sa reprise n'est pas un import du worker.

## Utilisation

Avec Node 22, depuis la racine du dépôt :

```sh
node scripts/qa-long-career.cjs --output /tmp/oval-reception
node scripts/qa-long-career.cjs --campaign club --seasons 3 --seed 713492 --output /tmp/oval-club
node scripts/qa-long-career.cjs --campaign international --through-year 2031 --seed 713492 --output /tmp/oval-international
node --test tests/qa-long-career.cjs
```

Pour recevoir un autre checkout sans y écrire ni y copier le pilote, définir
`OVAL_QA_SOURCE_ROOT` vers sa racine absolue. Le moteur, ses données, son commit
et son état propre/modifié sont alors lus dans cette racine ; le pilote conserve
ses scripts dans son propre checkout et enregistre aussi sa propre empreinte.
Les profils restent créés sous le répertoire temporaire système. Cette option
sert à distinguer une réception de cumul de celle de la branche de départ.

Le dossier de rapport est libre. Les profils de carrière sont toujours créés
dans un dossier temporaire séparé hors de l'application ; aucun profil personnel
n'est lu. Ils sont conservés après la recette pour permettre l'inspection, et
leur chemin figure dans le JSON et le HTML. Les bornes acceptées sont 1 à 5
saisons club, 2027 à 2031 pour l'année terminale internationale, et une graine
entière non signée sur 32 bits. Les campagnes sont séquentielles.

Ouvrir `index.html` pour lire les cartes de campagne, le temps réel, les points
de reprise et leurs empreintes. Les résultats sont publiés après chaque point
reçu, puis à la fin de chaque campagne. Un échec stoppe la campagne concernée,
reste rouge et donne une action de reprise ; l'autre campagne peut continuer.
Le code de sortie global vaut 1 si l'une des campagnes demandées échoue.

Le JSON n'embarque pas de carrière complète. Un checkpoint du rapport désigne
un export/import/redémarrage vérifié et son empreinte, et ne fournit pas une
commande de reprise automatique d'une campagne interrompue. Pour reproduire,
relancer la même commande, même graine et mêmes sources depuis l'état initial.

Le parcours de trois saisons effectue neuf imports. Avec la protection des
copies de sécurité activée, le pilote respecte les quotas projetés par le
moteur : avant un import, il peut supprimer explicitement la plus ancienne
copie de **son propre profil QA**, via `remove_checkpoint` avec confirmation.
Il contrôle que le profil est bien sous la racine temporaire créée par cette
exécution et consigne chaque suppression dans `campaign.maintenance` du JSON.
Aucun fichier de sécurité n'est supprimé directement et aucun quota n'est
désactivé. Une projection illisible interrompt la campagne.

## Garanties et limites

Les tests ciblés du pilote vérifient que les doublons, retours de journée et
valeurs financières non finies sont détectés, qu'un résultat rouge reste rouge
dans le rapport, et que les diagnostics sont échappés dans le HTML. Ils ne
remplacent pas l'exécution des campagnes.

La campagne club conserve la cadence hebdomadaire. Elle ne reçoit pas les
parcours au jour le jour des éditions Monde ni les clics Godot. Les calendriers
et règles du jeu ne sont pas changés ; les tests structurels ne certifient pas
les règles du rugby, l'équilibrage ou un rendu Windows. Les montants financiers
sont ceux de la fiction du jeu. Une graine et un club ne démontrent pas la
robustesse de toutes les trajectoires.

Les anciennes recettes `career-resilience` et `rugby-real-long-career-qa` gardent
leur rôle sur les trajectoires multi-clubs et les effectifs V11/V12. Ce pilote
complète leur couverture avec le worker récent, la presse et le calendrier
international ; il ne remplace pas ces suites ni leurs preuves.

## Réception observée le 10 novembre 2026

Source du pilote `6dc85e977a4acffb2cd34c1b46e1965297f008ff`, copie propre au
lancement, Node 22.23.4 sur Linux, graine 713492. Empreinte du périmètre moteur
et données lu par le pilote :
`ba3581f3eb8bf7c72464db538b3ca1731de005b0756b5c20de9ddbc6e48e9a7e`.

| Campagne | Contrôles reçus | Points de reprise | Durée réelle |
| --- | --- | --- | --- |
| Club : trois saisons, 90 matchs du club délégués | 734 | 9 exports/imports/redémarrages | 663,386 s |
| International : 2026–2031, 353 résultats, 168 courriers | 441 | 7 restaurations JSON | 3,642 s |

Les trois saisons club ont chacune clôturé avec 433 résultats natifs. Les 168
courriers internationaux comprennent 28 annonces d'hôtes, 68 notifications de
départ en sélection des joueurs du club, 17 convocations de la France et 55
résultats de la France. Aucun doublon n'a été détecté dans ces campagnes.
Le total est de **1 175 contrôles**, 16 points de reprise et **667,131 secondes**
pour l'exécution complète ; le coût reflète aussi la charge Cloud simultanée.

Preuves : [rapport HTML autonome](qa-long-career-20261110/index.html),
[JSON complet](qa-long-career-20261110/report.json),
[aperçu large](qa-long-career-20261110/apercu-1440.png),
[aperçu mobile](qa-long-career-20261110/apercu-390.png) et
[réception Chromium](qa-long-career-20261110/browser.json).
Le rendu HTML a passé six contrôles : deux campagnes et leurs seize points
présents, deux statuts reçus, téléchargement JSON fonctionnel et absence de
débordement horizontal à 1440 et 390 px. Deux captures complètes ont été
inspectées. Ce sont des captures du **rapport**, pas des écrans Godot du jeu.

La prise en charge du quota des copies de sécurité a été ajoutée ensuite et
reçue par les tests ciblés du pilote (quatre tests réussis). La campagne longue
ci-dessus précède cette protection ; elle ne valide pas le cumul avec ce
nouveau stockage. La réception d'intégration doit donc conserver cette
distinction et vérifier le chemin `remove_checkpoint` avec le moteur protégé.

## Réception distincte du cumul protégé

Une nouvelle exécution du pilote, via `OVAL_QA_SOURCE_ROOT`, a reçu une saison
sur le checkout propre `4a278beaef5773dfdb4df097c695b850961606d9` : **242
contrôles et trois exports/imports/redémarrages**, terminés sans échec en
**114,929 secondes** pour la campagne (115,073 secondes pour l'exécution).
Cette source comprend les copies de sécurité et les raccords du cumul ; elle
est distincte de la campagne longue ci-dessus.

Les empreintes d'état reçues à l'ouverture, mi-saison et clôture restent
identiques à celles de la campagne initiale, dont la saison clôturée compte
433 résultats. La réception ne change ni l'état sportif ni le RNG malgré les
copies de protection créées par les trois imports. Le quota de huit copies
n'est pas atteint dans ce parcours d'une saison.

Preuves du cumul : [rapport HTML](qa-long-career-20261110/cumul-4a278be/index.html)
et [rapport JSON](qa-long-career-20261110/cumul-4a278be/report.json). Le JSON
identifie aussi l'empreinte du pilote et celle du moteur reçu :
`bea6eb777f8ba00913b4fe5751b32b93c5b31da51f670dff08b5b663918ae38c`.

Le [test d'intégration du quota](qa-long-career-20261110/cumul-4a278be/quota.log)
a ensuite passé sur un **autre profil QA neuf**, en 31,015 secondes : neuf
états distincts produits par des notes de carnet natives, neuf imports,
une suppression confirmée via `remove_checkpoint` au neuvième import et
huit copies conservées. L'état sportif et la note importés restent strictement
identiques après chaque import. Ce test ne supprime aucune copie d'un profil
personnel et ne désactive aucune protection. Il est rejouable ainsi :

```sh
OVAL_QA_SOURCE_ROOT=/chemin/du/checkout node --test tests/qa-long-career-protected.cjs
```

Sans moteur contenant `profile-safety.cjs`, ce test est explicitement ignoré ;
les quatre tests courts du pilote restent exécutés indépendamment.
