# CALENDRIER-04 — 422 rencontres officielles LNR 2026–2027

## Résultat vérifié
Les **deux PDF officiels fournis par l'utilisateur** ont été traités avec PyMuPDF en conservant les coordonnées des colonnes, plutôt qu'un simple texte concaténé. Chaque en-tête `J1..J26` et `J1..J30` a été associé par position géométrique à ses deux colonnes domicile/extérieur, ligne par ligne. Une variante typographique `STADE FRANÇAIS` a été harmonisée en `STADE FRANÇAIS PARIS`.

**Résultat : 182/182 TOP14, 240/240 PRO D2.** Vérifications *effectivement exécutées* lors de l'extraction : 7 ou 8 matchs par journée, 14 ou 16 clubs distincts, chaque club une fois par journée, 182/240 couples ordonnés uniques, aller-retour dans les deux sens, aucune rencontre répétée, fenêtres de dates respectées. Le contrôle a retourné SUCCESS.

## Fichiers
- `world-data/calendrier04/fixtures-packed-2026-2027.txt` : données sources encodées sans pertes, format JSON compressé zlib et base64 (30 noms d'équipes, 56 dates initiales, 422 couples domicile/extérieur) ;
- `tools/calendrier04-build.cjs` : reconstruit les 422 rencontres, vérifie leur cohérence et produit le JSON complet ;
- `tests/calendrier04.cjs` : tests de structure et de programmation.

Générer le JSON : `node tools/calendrier04-build.cjs world-data/calendrier04/full-fixtures-2026-2027.json`. Il ne dépend que du module natif Node `zlib`.

## Distinction officielle / simulation
**Officiel :** adversaires domicile/extérieur, journée, fenêtre jeudi–vendredi en PRO D2 et samedi–dimanche en TOP 14, selon PDF LNR du 9 juillet 2026. **Simulé :** jour et heure *précis* de chaque match, avec une grille variable par journée, fuseau Europe/Paris (`+01:00` ou `+02:00`). Les PDF indiquent explicitement que la LNR publiera ensuite les jours/heures détaillés : `officialKickoff:null` et `kickoffStatus:simulated-not-official` pour **tous les 422** matchs jusqu'à confrontation ultérieure aux pages LNR en ligne. Ne pas présenter les heures simulées comme publiées par la LNR. **Résultats jamais préremplis.**

Démarrage des nouvelles carrières fixé au **1er juillet 2026**. Le jeu de base alternatif et le mod Rugby Réel partagent les mêmes confrontations **après correspondance explicite entre les identités des clubs** : ne jamais faire l'association sur la simple position dans un tableau.

## Intégration
Pas de modification directe de `dist/**` ni des sauvegardes. Le compte intégrateur doit importer le fichier généré au lancement d'une nouvelle carrière, vérifier la correspondance identités réelles/alternatives, préserver les anciennes sauvegardes et éventuellement remplacer les heures simulées par les programmations officielles publiées plus tard.

Les effectifs/staffs réels DATA-02 restent un chantier distinct non terminé.
