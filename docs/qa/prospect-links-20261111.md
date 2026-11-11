# Consultation des prospects hors marché général

Base : `8ad4b0239e70931f3d49672a2dc9b959fbb8e8f8`. Réservation dans le brouillon
#576 avant édition. Les deux vues ne sont pas modifiées par la branche salaires
Claude au relevé local du 11 novembre. Aucun moteur, fichier de calendrier,
animation, donnée, contrat métier ou configuration GitHub n'est modifié.

## Inventaire et décision

| Source | Avant | Destination ajoutée |
| --- | --- | --- |
| Détection de la relève, candidats | Nom et portrait statiques ; pas nécessairement dans `model.market` | Dossier du candidat identifié dans `regenScouting.candidates` |
| Détection, liste suivie et archives | Même carte ; archive pouvant différer du candidat courant | Dossier identifié dans `regenScouting.shortlist`, sans repli sur le candidat courant |
| Marché entre clubs | Nom statique, devis et actions de négociation | Dossier du joueur identifié dans `interclubMarket.candidates` |
| Négociation interclubs en préparation | Nom statique et champs de conditions | Même dossier, conservant devis, champs et fenêtre de négociation |
| Archive sans identité publiée | Identifiant et indisponibilité | Texte conservé ; pas de fiche inventée |
| Club du vendeur | Texte dans la carte | Reste à traiter : le dialogue Competition existant efface les fenêtres métier. Il faut un point d'inspection enfant pour préserver les conditions en cours. |

Les renderers existants ne conviennent pas directement : PlayerCanvas présume
un joueur de l'effectif, RecruitmentCanvas ajoute suivi/observation/offre et
Comparison utilise deux pistes du marché. Le nouveau renderer limité réutilise
les portraits, styles, libellés de connaissance, tableaux de conditions et
conteneurs existants, avec quatre lectures : profil, observation, contrat et
joueurs de votre effectif au même poste. Il ne recrée pas de statistiques absentes.

## Contrat

`inspect_entity({kind: prospect, source, id}, owner_window)` est distinct de
l'ouverture de route. Les sources acceptées sont `regen-candidates`,
`regen-shortlist` et `interclub`. Le contrôleur valide la fenêtre appelante et
les gardes avant d'ouvrir un détail enfant exclusif. La source métier ne reçoit
jamais `navigation_read_only` et n'est ni fermée ni reconstruite par ce clic.

Le renderer relit l'identifiant dans la seule collection demandée. Identifiant
absent, ambigu, source inconnue ou nom non publié : refus sans repli. Il ne
consulte ni le worker, ni une sauvegarde, ni un catalogue caché. `sourceSalary`
reste un paramètre interne du devis et n'est jamais affiché. Niveaux et potentiel
passent par les fonctions de connaissance existantes ; les valeurs brutes ne
sont pas affichées en remplacement des fourchettes.

Les fenêtres sources refusent l'inspection pendant une commande, une négociation
en attente ou toute fenêtre enfant visible, notamment la confirmation de
clôture. Le détail n'offre que le retour au catalogue ; il n'observe, ne suit,
ne propose et ne réserve aucun joueur. Sa fermeture restaure le focus d'origine
si le contrôle existe encore.

## Réception

Les nouveaux tests `godot-prospect-profile.gd/.cjs` couvrent le lookup strict,
les archives distinctes, le refus d'ambiguïté, l'absence de valeurs cachées,
l'absence de commande, la fenêtre source et ses champs, le focus et la non-
duplication. Aucun Godot lourd ni import n'est lancé dans ce worktree.
La recette du contrôleur réel, les captures et les contrôles sauvegarde/RNG
seront reçus sur le candidat commun assemblé, avec son SHA exact. Ce document
ne revendique pas encore ces résultats ni une recette Windows.
