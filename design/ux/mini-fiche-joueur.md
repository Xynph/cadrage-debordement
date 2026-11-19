# Fiche UX — Mini-fiche joueur au survol

> **Statut** : validé par Léo (19/11/2026, maquette `revue-20261119/apercus/07-effectif-retouche-v2.png`, classe `.mf`)
> **Liés** : 07 (effectif), 08 (fiche joueur), 09 (recrutement), 19 (formation)

## But

Lire un joueur en une seconde sans quitter la liste : qui il est, s'il est disponible, son contrat et ses 36
attributs. La fiche complète reste à un clic.

## Déclenchement

| Geste | Effet |
|---|---|
| Survol du **nom** ou du petit « i » voisin | la mini-fiche apparaît près du nom |
| La souris quitte le nom / le « i » | la mini-fiche disparaît |
| Clic sur le nom | fiche complète (plein écran, fiche 08) |
| Clavier : focus sur le nom + touche **I** | montre / cache la mini-fiche ; elle disparaît quand le focus part ou à Échap |

Valable dans Effectif, Recrutement et Formation, et partout où un nom passe par le lien joueur commun.

## Forme

- **Control flottant dans la coque** (jamais une fenêtre ni un popup système), au-dessus du contenu, ne capte pas
  la souris ; largeur 400 px à 1080p ; placé à droite du nom, sinon à gauche, puis recalé pour ne **jamais sortir
  de l'écran**.
- Fond `PANNEAU_3`, filet `FILET`, ombre légère.

## Contenu (de haut en bas)

1. **En-tête** : vignette avec le n° de feuille, NOM (capitales italiques), poste · statut (titulaire n° / remplaçant
   / hors groupe), drapeau en couleur + pays · âge ; à droite NIVEAU et « pot. a-b ».
2. **Forme** (condition % + barre + « apte ») et **Contrat** (échéance · salaire). Si le joueur est **blessé,
   suspendu ou en sélection**, la ligne Forme est remplacée par la raison et le retour connu (« Blessé · retour dans
   3 sem. »), jamais une date inventée.
3. **36 attributs** en 4 familles réelles du jeu (Ballon et jeu au pied, Lecture et collectif, Physique et jeu
   aérien, Défense et conquête), chiffre coloré selon le barème de la fiche 08 ; « — » en ivoire-3 si inconnus.
4. **Légende** du barème, puis le pied : « Clic : fiche complète » · « I : aperçu au clavier ».

## Critères d'acceptation

- [ ] Survol du nom ⇒ un Control (aucune Window) entièrement dans l'écran, 36 valeurs ou « — ».
- [ ] Souris hors du nom ⇒ plus de mini-fiche ; clic sur le nom ⇒ fiche complète.
- [ ] Focus clavier sur le nom + I ⇒ même mini-fiche.
