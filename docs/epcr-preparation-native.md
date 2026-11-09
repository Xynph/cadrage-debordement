# Préparer une liste européenne depuis le moteur natif

La projection `epcrPreparation` et la commande `epcr_preview` permettent de composer un brouillon de liste, puis de comparer ce brouillon à la composition actuelle. Cette consultation n'inscrit pas les joueurs, ne bloque pas de match et ne modifie aucun document de carrière. Les règles d'inscription additionnelle et les attestations club/Union ne sont pas entièrement représentées dans la carrière actuelle.

## Contrat du client

Pour un club engagé en Champions Cup ou en Challenge Cup, `snapshot` expose `model.epcrPreparation` : saison, compétition, candidats (IDs et identités de présentation), liste proposée, diagnostic de liste et diagnostic de feuille. Hors coupe ou hors mode Monde, la propriété vaut `null`. Les saisons après 2026/27 sont indiquées `supported:false` : le moteur ne reconduit pas silencieusement un règlement officiel futur.

```json
{"command":"epcr_preview","payload":{"competitionId":"champions","registeredIds":["opaque-player-id"]}}
```

La commande exige `registeredIds`, accepte au plus 100 identifiants uniques du club courant et ne permet ni l'inscription dans une autre coupe ni l'ajout d'un joueur extérieur. Elle renvoie le modèle avec le brouillon diagnostiqué. Chaque réponse garde exactement l'ordre des IDs transmis. Le client conserve son brouillon tant que la fenêtre est ouverte ; la commande ne le stocke pas. Le `snapshot` suivant revient à l'effectif complet : aucune sélection automatique de 42 joueurs et aucune exclusion silencieuse.

Les résultats `registration` et `teamSheet` contiennent `status` (`valid`, `invalid`, `unknown`), `violations`, `unknowns`, `counts`, `messages` et `pendingMessages`. `valid` signifie uniquement que les contraintes vérifiées par le module pur sont satisfaites ; ce n'est pas une homologation EPCR.

## Première ligne : poste et attestation sont distincts

La carrière courante ne stocke pas de certificat de qualification club/Union. Les candidats portent donc `frontRow:null`, `qualificationKnown:false`, même si leur poste de jeu est pilier ou talonneur. Le diagnostic signale les qualifications à confirmer au lieu de fabriquer une preuve à partir de `pos` ou `fam`. Les affichages de poste ne servent pas d'attestation. Les conditions contractuelles et apparitions antérieures dans la compétition ne sont pas certifiées par cette fonction.

Les seuils 42 inscrits, dix premières lignes, feuille 19–23, six premières lignes et couverture des trois postes au premier remplacement proviennent des résumés officiels 2026/27 ; voir [sources et limites du validateur](epcr-eligibility-2026-27.md). Aucun nouveau format de sauvegarde ou de joueur n'est ajouté.

## Vérifications

`node --test tests/epcr-eligibility.cjs tests/epcr-preparation-worker.cjs` vérifie le module pur et le vrai worker : modes Monde et Monde+Champ, liste choisie, feuille et joueurs absents, payloads refusés, non-participation, qualification inconnue et saison non couverte. Le test compare les octets du profil, le document exporté, la reprise avec une graine et une horloge d'ouverture différentes, l'import de l'ancien document, puis une commande d'entraînement appariée pour prouver l'intégrité de la trajectoire RNG. Le profil de chaque scénario est jetable. Les builds recopient les fichiers du dossier engine, y compris les deux nouveaux modules.

Ce lot n'est pas un système d'inscription persistante. Son futur raccordement exige une politique explicite pour les listes officielles, les échéances, les remplacements d'inscrits, les contrats, les apparitions et les anciennes carrières.
