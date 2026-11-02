# V60 — Relations presse et communication du manager

## Pourquoi ce chantier
La V58–V58.2 prépare le marché des entraîneurs; V59 concerne les effectifs et l'IA. Cette V60 explore un système **distinct** de gestion des conférences de presse, sans modifier ni les contrats ni le recrutement.

## Module
`dist/press-relations.js` est pur et compatible Node/navigateur. Il représente des conférences de presse par sujet (derby, blessure, forme, transferts, objectifs) et ton (honnête, confiant, prudent, agressif). Les réponses produisent des variations bornées de confiance des médias, des supporters, pression de la direction et moral. Les interventions sont datées, les doublons interdits, les décisions et indicateurs historisés. Le briefing produit une suggestion basée sur six résultats maximum. Une transition annuelle fait converger lentement les opinions vers une valeur neutre.

## Raccordement à la carrière réelle
Les indicateurs sont **fictifs**. Avant toute intégration, l'autre développeur doit :
1. Lire les scores réellement joués et les objectifs déjà présents sans créer un second registre.
2. Associer la réputation et la confiance de la direction aux indicateurs existants, sans double impact.
3. Ajouter le panneau d'interviews et les choix de dialogue dans l'interface.
4. Déterminer si les effets sur le moral nécessitent une traduction vers le moral des joueurs existants (pas de mutation automatique).
5. Ajouter éventuellement des champs optionnels à la sauvegarde et valider les anciens exports sur copies.

## Tests et limites
La suite `tests/v60-press-relations.cjs` vérifie 10 propriétés, notamment refus des doublons, dates, performances, bornes, briefing, corruption, 15 saisons reproductibles et reprise JSON. Il n'y a **aucun** test du véritable gameplay, aucune interface, aucune sauvegarde officielle modifiée. Les coefficients n'ont pas été calibrés sur des utilisateurs et ne doivent pas être activés en production sans revue.

## Isolation
Nouvelle branche depuis `main`, uniquement un module, un test, un workflow et cette documentation. Pas de fusion. Aucun changement aux fichiers du chantier V59 ni aux V58–V58.2.
