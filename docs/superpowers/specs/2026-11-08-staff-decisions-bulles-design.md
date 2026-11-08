# Staffs, décisions et bulles — conception du 8 novembre 2026

## Intention et autorisation

Léo accepte le lot proposé : BDD cohérente, préparation et analyse des rencontres,
recrutement/progression et carrière longue. Il demande en plus un récapitulatif des
bonnes idées GitHub absentes du jeu natif, des staffs réels photographiés dans son
pack privé et anonymisés dans la base, et un coach qui parle avec voix et bulle BD.
L'autonomie de conception et d'intégration ordinaire est déjà accordée ; pas de
nouveau tour de validation par écran. Le gate technique reste obligatoire.

## Choix

Conserver Godot et la DA carnet. Porter sélectivement les fonctions existantes
depuis main évite de fusionner les branches historiques déjà supplantées. Un
remplacement massif par les prototypes React ou économiques changerait de produit
et est écarté. La recherche des staffs est indépendante du moteur : les identités
et photos du pack n'apportent aucun bonus caché et ne changent pas la sauvegarde.

## Résultat attendu

- Inventaire français sourcé par liens GitHub, confronté au code réellement chargé.
  Distinguer absent du natif, déjà présent, recherche isolée, supplanté et blocage.
- Bulle ivoire avec contour et pointe vers le coach, texte sombre lisible ; la
  totalité du texte affiché est prononcée par le service vocal existant. Garder
  animation, défilement, clavier, arrêt, muet, relecture et garde des dialogues.
- Registre de personnes du staff, IDs stables distincts des joueurs, club, rôle et
  provenance datée. Les sources publiées à une autre saison restent étiquetées.
  Page d'encadrement consultable pour les trente clubs, photos officielles privées
  ou avatar neutre explicite, noms proches anonymisés dans la base publique.
- Extension compatible des packs : ancien format inchangé et nouveau format pour
  les staffs ; chemins et images strictement validés, installation atomique,
  changement d'identité sans mutation sportive/RNG, ancien pack toujours lisible.
- Préparation : lecture adverse et état de l'effectif à partir des vrais helpers
  du moteur ; conséquences et limites des choix expliquées, pas de promesse de
  victoire ni causalité inventée. Résultat : bilan chiffré des deux équipes.
- Recrutement/progression : besoins de couverture et échéances réellement
  calculées, potentiel présenté comme estimation ; examiner le plafond42 puis
  corriger uniquement le cas commun démontré bloquant, sans modifier les règles
  économiques centrales ni le comportement historique.
- Campagne longue sur les deux divisions et anciennes sauvegardes ; recette du
  ZIP Windows livré. Tous les tests utilisent des profils E: indépendants.

## Contraintes

Identités réelles et photographies hors distribution publique. Capacités/salaires
de simulation non officiels. Données LNR/recherches concurrentes non écrasées.
Pas de changement des lois du match ni du format de carrière sans nécessité et
validation renforcée. Saison de compétition2026/27 et lois historiques2025/26
annoncées distinctement. Aucun reset ni écriture de test du profil personnel.
Tous fichiers et livraisons sur E:, seul raccourci autorisé sur le bureau.

## Vérification

Tests du pack hostile/ancien/nouveau, médias manquants, noms longs et accents,
pack actif avant/après sauvegarde/reprise et invariance de l'état. Contrôles
graphiques1280×800/1440×900/1920×1080, texte et voix identiques, coach sans
recouvrement des commandes. Tests des décisions sans tirage RNG ni mutation de
lecture, compatibilité v1/v2 et bilan sur plusieurs saisons. CI complète exacte,
gate officiel puis sept jobs post-fusion ; aucun résultat en attente annoncé vert.
