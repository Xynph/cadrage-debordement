# Centre de disponibilité et rotation — UI jouable

Nouvel onglet **Disponibilité & rotation** du menu Effectif. Le panneau exploite exclusivement les états du moteur (blessures, condition, charge physique cumulée, feuille à 23, couvertures de poste et plans individuels).
- Synthèse de l'effectif par disponibilité, avec seuils d'alerte **conseils UI uniquement** : à ménager pour charge ≥55/100 ou condition <65 %, à surveiller dès charge ≥35/100 ou condition <80 %.
- Alerte sur les titulaires à risque, navigation vers les fiches et feuille à 23, sans remplacement automatique.
- Couverture de chacun des 15 postes selon `slotEligible` et présence de joueurs aptes et frais ; raccourcis vers les remplaçants et le recrutement natif.
- Tableau des joueurs filtrable par statut et recherche ; plans individuels réglables avec `setPhysicalTraining`, soumis aux mêmes verrous que l'effectif historique.
- **Aucune simulation ou donnée persistée supplémentaire** : tous les calculs consultatifs passent par `squadHealthSnapshot` ; seul un changement explicite de plan utilise le moteur et la sauvegarde native. Format de sauvegarde inchangé.

Tests : `node tests/squad-health-center.cjs`, réception Chromium réelle `tests/squad-health-center-browser.py` (ordinateur, mobile, recherche, filtres, changement de plan, navigation, sauvegarde), CI complète gate et post-fusion obligatoires. Une campagne Chromium Linux ne certifie pas Windows ou appareil tactile physique.
