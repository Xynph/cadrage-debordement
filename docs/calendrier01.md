# CALENDRIER-01 + DATA-02 — Rapport de collecte (31 octobre 2026)

## Sources consultées
La LNR a publié les **deux calendriers complets d'oppositions** le 9 juillet 2026 :
- TOP 14, PDF officiel 2 pages : https://assets.lnr.fr/2/9/4/0/4/6/TOP14_Calendrier_26-27_52f176c3bd1630dc2d08bce2b2edfa7b.pdf
- PRO D2, PDF officiel 2 pages : https://assets.lnr.fr/2/9/4/0/2/9/PROD2-Calendrier_26-27-1_e05e7a437154a5d2f0f49cb1bde6e3d5.pdf
- Catalogue presse LNR : https://www.lnr.fr/presse/calendrier-des-competitions

**Limite explicite :** l'accès aux deux PDF dans cette session a permis d'en inspecter la première page visuellement mais pas d'automatiser une extraction exhaustive fiable (le téléchargement direct depuis le conteneur échoue). Les **15 rencontres J1** ont été relevées et vérifiées visuellement, sans prétendre avoir importé les **407 autres**. Les affiches et *fenêtres de dates* sont officielles ; les jours et heures détaillés sont fixés ultérieurement par la LNR : `kickoff:null` signifie *non vérifié*, et `score:null` empêche de prédéterminer les résultats de la simulation.

## Tests/gate
`node tests/calendrier01.cjs` doit valider la saisie partielle et garantir l'absence d'invention. `node tools/calendrier01-validate.cjs world-data/calendrier01/official-fixtures-partial.json --complete` **doit échouer** tant que les 182 affiches TOP 14 et 240 PRO D2 ne sont pas intégralement validées. Le mode complet vérifie nombre de matchs, 7/8 rencontres par journée, 14/16 clubs, identifiants et couples domicile/extérieur uniques.

## Identifiants et univers
**Ne jamais associer les vrais clubs aux clubs alternatifs par rang de tableau.** La PR #112 donne des noms alternatifs mais aucun dictionnaire vérifié club réel ↔ club alternatif. Il faut créer et vérifier une table explicite avant d'afficher le calendrier dans le jeu alternatif. Dans le mod Rugby Réel #109, conserver les noms réels. Les deux calendriers utilisent les mêmes fenêtres de dates 2026-2027 et un début de carrière fixé au **1er juillet 2026**. Aucun ancien fichier de sauvegarde ni fichier `dist/**` n'est modifié.

## DATA-02 (effectifs)
Sources potentielles officielles : pages effectifs LNR TOP 14/PRO D2 et fiches des clubs. **Aucun effectif complet n'est livré dans ce lot** : le calendrier a été priorisé, et aucune ligne joueur insuffisamment vérifiée n'a été inventée. Les staffs, centres de formation, contrats, budgets et droits de photographies restent à recouper. Révision nécessaire de la liste clubs/divisions de #109 : le jeu et les saisons officielles doivent être comparés avec une correspondance explicite, non par ordre des tableaux.

## Résultat honnête
15/422 rencontres vérifiées et sauvegardées ; 407 non importées, test exhaustif non passé par construction. Prochaine étape prioritaire : réception des deux PDF avec extraction géométrique fiable puis vérification manuelle journée par journée, sans bloquer les nouvelles recherches d'effectifs.
