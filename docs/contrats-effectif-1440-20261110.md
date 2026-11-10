# Revue des contrats de l'effectif — 1440p

Lot en développement sur la base `272bd7f`, branche dédiée au-dessus de la PR #510.
Réservation : nouveau `ui/contract_review.gd` et raccord minimal de l'onglet
Contrats dans `ui/immersive08/squad_canvas.gd`. Le moteur et les règles de
contrat restent inchangés. La prolongation appelle `SquadViews.contract(app,p,false)`
maintenue par le chantier négociation.

La vue doit présenter les échéances classées, les salaires hebdomadaires projetés,
les disponibilités de prolongation et les postes à anticiper. Les filtres et la
consultation doivent rester sans écriture sportive, avec retour sur la bonne
fiche et conservation du focus. Une fin de saison n'est pas assimilée à une
urgence quotidienne : aucune date d'expiration exacte n'est inventée.

Recettes et captures exclusivement en 2560 × 1440. Les résultats seront consignés
après réception du parcours intégré et des cas limites de projection.
