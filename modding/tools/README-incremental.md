# Rugby Réel — une BDD centrale, import incrémental

La seule BDD centrale reste `modding/data06/rugby-master-2026-2027.json`. Ce script **ne crée pas de BDD versionnée**. Chaque lot futur part de la dernière branche `main` et propose **une seule PR par lot**, sans empiler les PR. Les anciennes versions restent dans l'historique Git. Cette PR outillage ne modifie pas le JSON réservé par l'intégrateur DATA.

## Usage

```bash
node --test tests/rugby-incremental-import.test.cjs
node modding/tools/rugby-incremental-import.cjs --input /chemin/lot.json
# Après examen du bilan, sur une branche issue de main :
node modding/tools/rugby-incremental-import.cjs --input /chemin/lot.json --write
```

`--db chemin.json` permet de tester contre une copie. Le mode par défaut est **dry-run** : aucune écriture. Le mode `--write` produit un seul fichier JSON, en passant par un fichier temporaire et un renommage. Toujours sauvegarder la version Git avant l'opération et n'utiliser l'option écriture que sur une branche dédiée.

Exemple de lot :

```json
{
  "schema": "rugby-incremental-batch-v1",
  "observations": [
    {
      "competition": "TOP 14",
      "season": "2025-2026",
      "phase": "Phase régulière",
      "type": "Joueur",
      "entityId": "lnr:862",
      "indicator": "Essais marqués",
      "category": "Essais marqués",
      "unit": "Essais",
      "value": 3,
      "scope": "Phase régulière",
      "sourceUrl": "https://rugbydata.fr/statistics/panel/51"
    }
  ],
  "playerUpdates": []
}
```

Les valeurs d'exemple ci-dessus sont **fictives, uniquement pédagogiques**, et ne doivent pas être importées comme statistiques réelles. Les observations de production exigent des sources effectivement vérifiées et les droits d'utilisation nécessaires.

## Invariants et exclusions

- Identité observation : compétition, saison, phase, type, identifiant d'entité, catégorie, indicateur, unité, portée. Une même observation déjà présente avec valeur identique est conservée ; une valeur divergente est bloquée et doit passer par une correction documentée distincte.
- Joueurs : ID `lnr:...` existant obligatoire pour observation individuelle ; clubs limités aux identifiants déjà présents. Pour un recalibrage, ID et éventuels nom/club/ligue sont confrontés strictement ; sans ID, le triplet nom-club-ligue doit être unique.
- On ne remplit jamais les inconnues avec zéro, ne fabrique aucune performance, ne modifie pas les 763 relevés antérieurs, et n'efface pas les saisons passées.
- Les notes simulées `rating`, `potential`, `skills`, `attributesV2` ne changent que sur instruction de lot explicite et justifiée ; un recalibrage n'est **pas** une observation réelle.
- Aucun changement du format des sauvegardes du jeu, aucun accès réseau ni collecte automatique. Pas de fusion sans CI, gate officiel et intégrateur unique. Ne pas éditer la BDD pendant la réservation DATA #6588026086.

## État de livraison

Pipeline préparé sur branche outillage indépendante. À réception du JSON final #252 sur `main`, faire un **essai sur copie** et vérifier impérativement : 1 592 IDs distincts, 805 TOP14 / 787 PRO D2, 763 observations conservées, import idempotent et aucun changement de statistiques précédentes. Puis intégrer cette PR outillage selon le gate officiel.
