# GitHub privé et travail sans le PC personnel — 15 novembre 2026

## Choix et plan d'exécution
Léo demande de conserver GitHub, de préparer le dépôt privé et de pouvoir travailler
depuis son PC professionnel sans installation locale. Les PR et leurs contrôles
obligatoires restent dans le cloud. Le PC personnel est réservé à la recette GPU :
il n'est jamais une dépendance de Validation CI. Blacksmith est différé : transfert
à une organisation et coût à évaluer, le plan Pro personnel ne suit pas un transfert.

1. Préparer Windows cloud pour le privé avec activation explicite.
2. Préparer le checkout authentifié dans oval-legacy-recette-windows.
3. Valider les workflows et ouvrir des PR brouillons, sans lancer la recette matérielle.
4. Mesurer l'usage et recevoir les tests sur une machine de caractéristiques privées.
5. Fusionner via le gate, configurer les accès puis seulement changer la visibilité.

## État et réglages GitHub restants
La préparation seule ne bascule pas le dépôt et n'ajoute aucun budget payant.
Le connecteur disponible n'expose pas l'administration des secrets, de la
facturation ou de la visibilité ; le jeton gh local est invalide.

- Vérifier GitHub Pro actif pour Xynph, les protections de main et l'accès des apps
  Codex/Claude après bascule. Le ruleset actuel exige PR et Validation CI, sans
  merge queue native.
- Billing : relever le calcul inclus restant sur tout le compte, créer alertes et
  blocage de dépassement avant toute CI privée. Sans crédit ni dépense autorisée,
  les jobs hébergés peuvent s'arrêter : le travail sur les branches reste possible,
  mais aucune fusion sans Validation CI.
- Pro inclut actuellement 18 USD de calcul, équivalant à 3000 minutes Linux à
  0,006 USD/min ; Windows standard coûte 0,010 USD/min. Artefacts : 1 Go partagé
  avec Packages ; cache : allocation distincte 10 Go/dépôt.
- Mesurer les durées effectives par job et tentative, pas le délai mural des runs.
  Le relevé historique de 14900 minutes/12 h précède les optimisations et ne donne
  pas le coût actuel.
- Important : les runners Linux standard privés ont moins de RAM/CPU que les
  runners publics utilisés ici. L'ordonnanceur JS réserve 12 Go de RAM et lance
  jusqu'à trois suites. Ne pas basculer avant recette du profil privé et adaptation
  vérifiée des shards/parallélisme ; ne réduire aucune couverture pour économiser.
- Dans oval-legacy-recette-windows, créer le secret CADRAGE_SOURCE_READ_TOKEN :
  jeton à durée limitée, limité au seul dépôt cadrage-debordement, Contents read.
  Ne jamais coller le jeton dans une issue ou le chat. Le GITHUB_TOKEN du dépôt de
  recette ne suffit pas à lire un autre dépôt privé. Le checkout ne conserve pas
  les identifiants Git et valide que le SHA appartient à main.
- Le secret OVAL_RECETTE_DISPATCH_TOKEN existant concerne le déclenchement,
  pas la lecture des sources. Vérifier séparément sa portée.
- CD_PRIVATE_WINDOWS_CLOUD=true (variable du dépôt principal) autorise les recettes
  Windows hébergées en privé. Par défaut elles restent désactivées en privé afin
  de ne pas introduire des dépenses récurrentes. Son activation nécessite budget
  décidé et vérification des créneaux toutes les 4 h et des artefacts sur 14 jours.
- Auditer les environnements GitHub (dont recette-pc-leo) et leurs restrictions
  disponibles sur Pro privé, les téléchargements anonymes/URLs publiques et les
  outils de livraison avant bascule. Le checkout RTX n'est pas cet audit complet.

## Sans PC personnel
Édition, PR et tests hébergés peuvent fonctionner sans le PC. L'EXE cloud utilise
un environnement distinct de la vraie RTX : aucune preuve matérielle n'est revendiquée.
Les recettes RTX attendent le runner ; elles ne basculent pas automatiquement dans
le cloud et n'empêchent pas Validation CI. Aucun job RTX n'est lancé pour cette préparation.

## Vérifications
Préparation statique uniquement : syntaxe YAML, quatre gardes Windows avec activation
privée explicite, checkout sans persistance, contrôle d'ascendance et runner RTX inchangés.
La recette Windows native, le secret privé, la RAM en CI privée et la facturation ne sont
pas validés. Les PR restent brouillons jusqu'à réception et coordination #591.

Sources officielles :
- https://docs.github.com/en/billing/concepts/product-billing/github-actions
- https://docs.github.com/en/billing/reference/actions-runner-pricing
- https://docs.github.com/en/actions/reference/runners/github-hosted-runners

Exécution dans une seule session ; modèle/effort effectifs non exposés.
Recommandation GPT-6.1 Sol : moyen.
