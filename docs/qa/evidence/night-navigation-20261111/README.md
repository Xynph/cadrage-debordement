# Preuves ciblées de navigation — nuit du 11 novembre 2026

Ces fichiers sont des copies exactes des dernières recettes locales qualifiées
par cas. Ils ne constituent ni une campagne SDK complète sur un seul SHA, ni une
recette Windows. Les essais antérieurs rouges et le repro visuel staff restent
dans les dossiers de travail et dans le bilan historique.

| Cas | Contrôles / échecs | SHA réellement testé |
| --- | --- | --- |
| France depuis l’Angleterre | 23 / 0 | `8ad4b0239e70931f3d49672a2dc9b959fbb8e8f8` |
| Gardes et résultat historique | 103 / 0 | `0d19ddfa21332c846b086b496ebb7f9a81f2fa4f` |
| Liens et historique de lecture | 133 / 0 | `37ede657c3085e67e3727817d8eb0e28ca70b3ae` |
| Catalogues et brouillons de prospects | 70 / 0 | `37ede657c3085e67e3727817d8eb0e28ca70b3ae` |
| Staff après correction visuelle | 54 / 0 | `fbc642e1d3069895d5614caca433ab8f4c83bcf8` |
| Vrai devis interclubs non vide | 66 / 0 | `dbe6a7e2b7bb22b0cb9d7d5f924e396f9cdd8e3f` |

Chaque sous-dossier contient `report.json`, `provenance.json`, les sorties TAP,
le journal Godot et le journal moteur. Les reçus consignent les identifiants
visés, les commandes de préparation, l’absence de commande de consultation,
l’égalité de l’état sportif et du profil, les seed/horloge persistés et les
compteurs de parole à zéro. Le SDK utilisé est Godot 4.7.2, avec audio Dummy et
un seul processus Godot lourd sous verrou partagé.

## Images sélectionnées

Les huit PNG sont les originaux du rendu de l’application stock, sans retouche,
recadrage ni recomposition. Aucun modèle, export Mixamo, profil sportif complet
ou fixture complète n’est inclus.

- [France consultée depuis l’Angleterre, 2560×1440](images/nation-france-depuis-angleterre-2560.png).
- [Fiche complète d’un joueur, 2560×1440](images/joueur-fiche-2560.png).
- [Retour du graphique de fatigue filtré, 2560×1440](images/fatigue-tranche-retour-2560.png).
- [Staff corrigé, 2560×1440](images/staff-fiche-2560-1440.png).
- [Staff corrigé, 1280×720](images/staff-fiche-1280-720.png).
- [Vrai devis non vide avant inspection, 2560×1440](images/devis-interclub-recu-2560.png).
- [Même devis après retour, 2560×1440](images/devis-interclub-retour-2560.png).
- [Résultat historique réellement joué, 2560×1440](images/rencontre-historique-2560.png).

La fiche joueur n’est pas présentée comme une capture du nouveau lecteur modal :
ses premières recettes étaient headless et n’ont pas produit ce PNG. Le groupe
`reading` conserve dans son JSON d’origine la référence à une ancienne capture
staff incorrecte ; cette image est volontairement exclue du présent dossier.
La réception visuelle du staff provient uniquement du groupe `staff` corrigé.
La rencontre historique montre le résultat conservé : la projection de cette
carrière ne conservait pas ses statistiques détaillées, qui ne sont pas inventées.

## Vérification

[`manifest.json`](manifest.json) associe chaque fichier à son chemin d’origine,
sa taille, son SHA-256 et son SHA de code exact ; les PNG incluent leurs dimensions
natives. Les copies ont été vérifiées octet pour octet contre leurs sources.

```sh
sha256sum --check SHA256SUMS
```

`SHA256SUMS` couvre le manifeste, ce document et toutes les pièces copiées ; il
ne s’inclut pas lui-même. Les répertoires temporaires indiqués dans les reçus
servent uniquement à identifier la provenance, sans livrer les sauvegardes.
