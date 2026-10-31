# CALENDRIER-02 — Récupération incrémentale contrôlée

**Livraison :** 23 affiches supplémentaires lues dans les PDF officiels LNR, page 1 : les 7 de la J2 TOP 14 et les 8 de chacune des J2 et J3 PRO D2. Elles **s'ajoutent** aux 15 affiches J1 de PR #113 (total théorique après réception des deux PR : 38 sur 422). Il reste **384 matchs** à saisir, relire et valider. Aucune heure individuelle ni aucun score inventé. Saison 2026–2027, nouvelle carrière 1er juillet 2026.

Sources primaires : https://assets.lnr.fr/2/9/4/0/4/6/TOP14_Calendrier_26-27_52f176c3bd1630dc2d08bce2b2edfa7b.pdf ; https://assets.lnr.fr/2/9/4/0/2/9/PROD2-Calendrier_26-27-1_e05e7a437154a5d2f0f49cb1bde6e3d5.pdf.

**Blocage technique réel :** les PDF sont visibles sur le navigateur de recherche, mais le conteneur d'exécution ne résout pas `assets.lnr.fr` ; aucune extraction automatique complète du binaire n'a pu être vérifiée. Il est donc interdit de parler de 422 matchs importés. La priorité suivante est d'obtenir le fichier source par téléchargement ou pièce jointe, puis d'extraire les blocs **spatialement** (et pas d'après l'ordre de texte linéaire qui regroupe des colonnes éloignées) et de recouper chaque journée avec le visuel. Le script de validation CALENDRIER-01 doit alors contrôler les 182+240 matchs et la double confrontation unique.

**Correspondance réelle/alternative :** interdiction d'associer les clubs par ordre de tableau. Il faut vérifier, une à une, les 30 correspondances auprès des responsables produit, et ne les activer qu'avec un dictionnaire explicitement validé. Les PR #109 et #112 sont fusionnées, #113 attend sa réception.

**DATA-02 :** les effectifs complets, staff, jeunes, contrats et budgets n'ont pas été collectés dans ce lot : aucun nom ou poste non vérifié n'est ajouté. Pas d'images protégées.

Tests : `node tests/calendrier02.cjs` ; ne pas annoncer un test réussi sans exécution ou CI du SHA exact.
