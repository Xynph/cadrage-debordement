# Salaires : affichage hebdomadaire, mensuel ou annuel

Dans **Paramètres → Affichage → Affichage des salaires**, choisir Hebdomadaire,
Mensuel ou Annuel. La préférence est locale et globale, conservée dans
`interface.json`, indépendante de la carrière. Les anciens fichiers sans ce
champ gardent l'affichage hebdomadaire. Une valeur invalide ou une écriture
refusée conserve le fichier et le dernier choix valide.

Convention d'affichage demandée : **mensuel = hebdomadaire × 52 ÷ 12** ;
**annuel = hebdomadaire × 52**. Il s'agit d'une présentation des rémunérations,
pas du coût d'une saison. Les paiements du moteur, les semaines comptables,
les engagements déjà calculés, les primes, les indemnités et la trésorerie ne
sont pas recalculés selon cette convention.

La préférence s'applique aux salaires des joueurs et du staff, à leurs fiches,
aux tableaux et comparateurs, au recrutement et aux contre-offres, aux rappels
du Bureau et aux masses salariales affichées. Dans Finances, le journal, les
charges comptables réelles, leur répartition hebdomadaire et les engagements
sur les semaines effectivement projetées restent des montants comptables.
Les libellés indiquent leur cadence réelle.

Fermer Paramètres actualise la vue courante sans devoir changer d'écran. La
préférence et les montants sont conservés dans les consultations suivantes.

## Saisie et sécurité des montants

Les demandes du moteur entrent toujours dans le formatteur en unités
hebdomadaires. Les champs de salaire présentent l'unité choisie et reconvertissent
vers l'euro hebdomadaire le plus proche lors de l'envoi d'une proposition.
L'absence d'édition restitue exactement le montant hebdomadaire d'origine,
y compris après des conversions successives entre les trois unités.

La reprise d'une contre-offre garde elle aussi sa valeur hebdomadaire exacte.
Le récapitulatif expose le montant contractuel réellement retenu après arrondi.
La conversion n'est appliquée ni à la prime ni à la durée. La négociation simple,
le marché entre clubs et le plafond salarial d'une mission d'observation utilisent
le même utilitaire de saisie. Aucun calcul du moteur n'est modifié.

## Interfaces et intégration

`ui/salary_display.gd` expose `format(weekly)`, `amount(weekly)`,
`period_label(short)`, `bind_input`, `input_weekly` et `set_input_weekly`.
Les vues utilisant `game_skin.gd` ou `carnet_skin.gd` disposent de `G.salary`,
`G.salary_amount` et `G.salary_period`. Les paramètres persistés sont
`salary_period = weekly | monthly | annual`.

Le lot Contrats à risque est adapté par l'intégrateur avec les mêmes fonctions.
Les nouveaux tris et défilements des tableaux, développés en parallèle,
conservent leur géométrie et leurs clés ; leurs titres de salaire doivent
reprendre la période choisie après intégration.

## Réception

Le banc `godot-salary-display.cjs` vérifie 43 contrôles : trois unités, conversions
sans dérive pour plusieurs montants, arrondi après une vraie édition, compatibilité
d'un ancien fichier, persistance, refus d'un choix invalide et refus d'écriture
sur un obstacle disque réel. Node 22.23.4 et Godot 4.7.2.

Le banc `godot-salary-preference-live.cjs` charge la vraie application et une
carrière commune jetable. Il change le paramètre dans sa vraie fenêtre, reçoit
la fiche actualisée à fermeture dans les trois unités, relit la préférence et
vérifie que le profil sportif reste identique. Une offre mensuelle correspondant
à 1 000 € hebdomadaires est enregistrée à 1 000 par le moteur, sans débit après
contre-offre. Une saisie annuelle de 5 200 000 € conduit à une signature à
100 000 € hebdomadaires, avec une seule prime au montant d'origine.

Pour les captures 2560×1440 du paramètre et d'un vrai joueur dans les trois
unités, définir `CD_SALARY_LIVE_GRAPHICS=1` et
`CD_SALARY_LIVE_OUTPUT=/chemin/absolu/preuves`, puis lancer le même banc. Les
profils de test restent dans le dossier temporaire système, hors du jeu.
