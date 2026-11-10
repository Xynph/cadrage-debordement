# Recrutement : tous les tris et liste complète — 10 novembre 2026

Les neuf en-têtes du marché sont actifs : joueur, poste, âge, niveau, potentiel,
prime, salaire, rapport et avis. Les quatre en-têtes des archives le sont aussi :
joueur observé, poste, date du rapport et avis daté. Entrée ou un clic active le
champ ; une nouvelle activation inverse le sens. Une flèche indique le champ
et le sens actifs. Les tris des archives et du marché sont mémorisés séparément.

Les comparaisons utilisent les valeurs publiées : nombres réels pour les coûts,
âges, notes et potentiels ; texte normalisé pour noms/postes/statuts ; semaine
chronologique de suivi conservée dans les rapports datés. Les dates incomplètes
ne sont pas inventées. Un rapport conservé sans date est présenté **Non daté**.
Les inconnus restent en dernier dans les deux sens, et les égalités sont
stabilisées par l'identifiant. Le tri ne réordonne jamais les tableaux du modèle.

Tous les filtres — poste, disponibilité, suivis, âge, budget et mots-clés — sont
appliqués avant le tri final. Le helper commun possède un argument optionnel
`sort_result=false` pour ne faire que son filtrage ; son comportement antérieur
reste celui de tous les appels existants. Un âge ou coût inconnu reste consultable
sans filtre, mais n'est pas assimilé à zéro lorsqu'un plafond est demandé.

## Défilement interne

La pagination du recrutement et des rapports est retirée. Toutes les lignes
filtrées sont rendues dans **MarketScroll**, avec des lignes de 38 px et des
portraits compacts. Seule cette liste défile à la molette ; ses en-têtes, filtres
et fiche sélectionnée restent fixes. Les événements de molette en bout de liste
ne sont pas transmis au panneau extérieur. Le focus rend la dernière ligne
accessible sans bouton de page. Après tri et sélection, la fiche correspond à
l'identifiant de la ligne, pas à son ancienne position.

Les réglages d'unité salariale sont raccordés par le lot dédié. Ils ne modifient
pas la comparaison, qui continue de porter sur le salaire hebdomadaire du moteur.
Le raccord conserve les coordonnées compactes de la ligne : salaire x864/y22,
font17 ; barre y28/h5.

## Réception

Le banc dédié démarre une vraie carrière puis utilise une projection UI contrôlée
à 40 joueurs et 40 rapports pour recevoir toutes les colonnes dans les deux sens.
Il distingue le test algorithmique par résultats attendus fixes du raccord entre
les en-têtes, l'ordre rendu et les fiches. Sont aussi contrôlés : inconnus et
infinis, dates incomplètes, égalités, filtres combinés, absence de pagination,
molette et borne basse, panneaux fixes, dernière ligne, identité après sélection,
compteur de commandes et empreinte sportive inchangés.

```sh
CD_GODOT_EXECUTABLE=/chemin/godot node --test tests/godot-recruitment-sorting.cjs
```

Le rendu de référence est 2560×1440. Pour les captures Linux, ajouter
`CD_RECRUITMENT_SORT_GRAPHICS=1` et `CD_RECRUITMENT_SORT_OUTPUT=/tmp/preuves-tris`.
Le profil est créé séparément hors du dossier de l'application. Les captures
représentent les lignes de recette explicitement contrôlées, pas quarante
nouvelles signatures ou observations simulées. Aucune recette Windows ni
modification du moteur, des contrats ou des sauvegardes n'est revendiquée.
