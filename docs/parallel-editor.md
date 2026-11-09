# Atelier de calendrier fictif — 9 novembre 2026

## Intention et conception
Depuis la page Packs, créer un calendrier tous contre tous (2–32 clubs), en aller simple ou aller-retour, le modifier en JSON, le contrôler et l'échanger localement. Un nombre impair de clubs produit des journées de repos. Identifiants stables distincts des noms affichés ; aucune identité ou compétition officielle n'est réécrite.

L'alternative d'étendre les packs d'identités est écartée : leur contrat actuel ne transporte pas de calendrier. Le module pur propose génération et validation ; une commande worker consultative hors transaction retourne le document vérifié. L'interface conserve son brouillon et ses erreurs. Export JSON dans un fichier choisi explicitement, remplacement atomique existant ; import limité à 1 Mio. Le document ne lance pas encore une carrière personnalisée : cette limite est annoncée dans l'interface et dans l'export.

## Plan
- [ ] Tester couverture complète des paires, alternance aller-retour, repos, conflits, entrées malformées et absence de mutation.
- [ ] Implémenter module pur et projection bornée, sans état ni hasard.
- [ ] Brancher atelier Godot depuis Packs : édition des clubs, génération, import/export et aperçu.
- [ ] Vérifier Node et chargement réel Godot ; transmettre hooks worker au coordinateur.

## Vérifications
À compléter à la livraison. Aucun changement de sauvegarde ou de règle rugby.
