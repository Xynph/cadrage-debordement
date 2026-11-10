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
