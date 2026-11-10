# Trois nouveaux lieux contextuels 3D

Léo a demandé les trois propositions le 10 novembre 2026 : salle de presse, infirmerie et salle de direction. Elles prolongent le lot525, qui reste figé pendant sa CI.

Le choix retenu réutilise Godot4.6 et les décisions de carrière existantes. Des scènes indépendantes natives sont préférables à trois images statiques (pas de vraie immersion) ou à trois nouveaux systèmes de simulation (effets et données non demandés). Chaque vue propose une décision ou un bilan réel, porte les couleurs et le blason du club, utilise les portraits connus et des ressources locales gratuites. Les visites ne produisent aucun bonus et ne font pas avancer la semaine.

La presse montre les questions et journalistes réellement projetés puis envoie press_conference avec les IDs autorisés. L’infirmerie présente les indisponibilités/charges enregistrées et les décisions de gestion autorisées, sans diagnostic ni guérison inventés. La direction expose les bilans/objectifs et arbitrages déjà disponibles, sans attribuer de fausse demande au président. Les conditions précises et chemins sont confirmés par lecture des projections existantes avant écriture.

Les accès sont contextuels depuis les écrans concernés, jamais pendant un match ou un entretien prioritaire. Une fermeture retrouve la gestion ; un changement de carrière ou un contexte périmé invalide la visite. Match/causeries restent prioritaires. Les salles ne sont pas des routes permanentes de promenade.

Cadrage d’implémentation décidé par l’intégrateur : trois composants séparés et une extension commune du directeur/factory ; commandes serveur existantes uniquement, aucune nouvelle règle sportive. XV adulte élite, saison2026–27 ; références rugby du dépôt applicables.

## Précision ultérieure explicite de Léo
Les trois salles sont plein écran, s’ouvrent automatiquement au moment opportun et sont impassables avant les décisions ou conversations attendues. Un domaine natif persistant clubMeetings programme ces rendez-vous et conserve la scène jusqu’à sa résolution puis Continuer. Les gardes serveur bloquent les commandes sans rapport ; sauvegarde/export/fermeture de l’application restent possibles. Reprendre la carrière retrouve le rendez-vous, sans rejouer les effets.
