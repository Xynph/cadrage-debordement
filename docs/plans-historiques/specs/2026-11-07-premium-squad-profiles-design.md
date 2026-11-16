# Effectif et fiches joueurs Premium

Lot demandé et autorisé par « ok go » après la recommandation Effectif + fiches joueurs. Léo a déjà demandé une exécution autonome ; les choix de présentation ci-dessous sont ceux de l'intégrateur.

Objectif : consulter davantage de joueurs simultanément et prendre une décision depuis leur dossier réel, dans le jeu natif `dist/`, à 1440×900 et 1920×1080. Continuer la direction forêt, cuivre et ivoire du Bureau.

Approches considérées : modifier les composants UI02 eux-mêmes exposerait leurs autres consommateurs ; ajouter une nouvelle application créerait un second jeu. Retenir une couche de présentation native dédiée, après le décorateur éditorial, utilisant les projections et commandes UI02 existantes.

Le tableau conserve recherches, filtres de poste, quatre présentations, colonnes personnalisées et tris. Une commande d'aperçu par ligne actualise le panneau latéral ; le nom ouvre la vraie fiche. La sélection reste locale et se réconcilie avec les lignes filtrées. Objectif minimal : dix lignes entièrement visibles à 1440×900, en-tête fixe et défilement local. Aucun défilement global.

La comparaison native et les charges individuelles restent accessibles dans des fenêtres modales ; les changements de sélection de comparaison conservent la fenêtre et le focus. Échap ferme et restitue le focus. Les commandes natives d'entraînement conservent leurs verrouillages.

La fiche garde ses quatre onglets. L'accueil présente une identité compacte, les valeurs natives de condition, charge, salaire, échéance, minutes et statut ; un seul radar de six attributs nommés sur 100, avec valeurs textuelles, plus les qualités les plus élevées. Les actions ouvrent la comparaison, la couverture des postes, la feuille à 23 et l'onglet contrat ; elles ne sélectionnent ni ne prolongent automatiquement un joueur.

Ne changer ni moteur, ni règles rugby, ni calculs UI02, ni format de sauvegarde. Les lectures ne doivent modifier ni S ni la carrière enregistrée et ne consomment aucun aléatoire. Les monogrammes LNR remplacent les portraits fictifs. Les valeurs absentes restent explicitement absentes. Les noms longs, les filtres vides et les effectifs réduits ne doivent produire ni débordement ni ancien dossier trompeur.

Réception : tests purs de projection/échappement, parcours navigateur sur carrières native neuve et avancée, consultations invariantes, filtres et actions, les deux résolutions et thèmes, LNR sans faux portraits ; tests de sauvegarde existants, régressions Bureau/match et revue indépendante finale. Publication branche/PR, CI sur HEAD exact et intégration uniquement après disponibilité de l'intégrateur et gate officiel. Aucune release portable dans ce lot.
