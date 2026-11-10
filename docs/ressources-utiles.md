# Ressources utiles pour Oval Legacy

Registre partagé des liens transmis par Léo ou retenus pendant le développement.
À consulter à chaque reprise avec AGENTS.md, côté PC comme Cloud. Une nouvelle
conversation doit avoir accès au dépôt pour réutiliser ce document.

Ce premier inventaire rassemble les références identifiées dans la conversation
et les fichiers du projet. Il ne constitue pas une archive exhaustive des anciens
chats. Un lien enregistré ne signifie pas que son contenu a été lu ou approuvé.

## Tenir le registre à jour

- Ajouter les nouveaux liens utiles dès leur réception, avec leur provenance et
  ce qu’ils peuvent apporter au jeu. Regrouper les doublons par URL pérenne.
- Indiquer le coût et la licence connus ; écrire « à vérifier » si inconnus.
  Gratuit à consulter ne signifie pas libre à intégrer ou à redistribuer.
- Utiliser les statuts : **À explorer**, **Évalué**, **Retenu**, **Intégré**,
  **Écarté**. Expliquer une décision d’abandon ; conserver la référence.
- Dater le relevé et préciser ce qui a réellement été vérifié. Recontrôler
  disponibilité, version et conditions avant une nouvelle utilisation.
- Relier l’entrée à la décision, au fichier ou à la PR correspondante.
  Garder une courte synthèse utile si la page devient inaccessible.
- Conserver des adresses durables sans identifiants secrets ni URL signée
  temporaire. Ne pas copier automatiquement les conversations privées.

## Inspirations et recherches

| Ressource | Provenance / relevé | Utilité pour le jeu | Coût / licence | Statut et suite |
| --- | --- | --- | --- | --- |
| [Publication X de nikosolenne](https://x.com/nikosolenne/status/2119937933264212212) | Lien fourni par Léo dans la conversation ; enregistré le 10 novembre 2026. Adresse du statut sans paramètres de partage. | Piste d’inspiration pour transitions, animations et immersion. | Contenu, disponibilité et droits à vérifier. | **À explorer** : le contenu du post n’est pas attesté par ce registre. Ne pas lui attribuer une bibliothèque ou une recommandation sans le relire. |
| [Étude de sept outils GitHub — PR 425](https://github.com/Xynph/cadrage-debordement/pull/425) | Étude existante du projet ; titre et référence relevés le 10 novembre 2026. | Retrouver les recherches sur assets et animations avant de recommencer une étude. | Coût/licence propres à chaque outil à vérifier dans son dossier. | **À explorer** : consulter la PR et ses fichiers avant de retenir un outil. L’ouverture d’une PR ne prouve pas une intégration. |
| [Essais parallèles des sept outils — PR 426](https://github.com/Xynph/cadrage-debordement/pull/426) | Réception existante du projet ; titre et référence relevés le 10 novembre 2026. | Retrouver les essais et leurs limites. | À vérifier par outil. | **À explorer** : rapprocher les résultats de la PR 425 et de l’état actuel du code. |

## Assets et licences

| Ressource | Provenance / relevé | Utilité pour le jeu | Coût / licence | Statut et preuve |
| --- | --- | --- | --- | --- |
| [Kenney Furniture Kit](https://kenney.nl/assets/furniture-kit) | Source conservée dans les crédits 3D ; relevé local du 10 novembre 2026. | Mobilier des scènes contextuelles : banc, chaise de bureau, plante et accessoires. | Ressources gratuites, **CC0 1.0**, selon la notice conservée avec la version intégrée. | **Intégré** : [crédits et inventaire des huit GLB](../native/godot/ui/contextual/rooms/CREDITS.md). |
| [Quaternius Animated Men Pack](https://quaternius.com/packs/animatedmen.html) | Source conservée dans les crédits 3D ; relevé local du 10 novembre 2026. | Modèle humain stylisé animé et riggé. | Ressource gratuite, **CC0 1.0**, selon la notice conservée avec le modèle. | **Intégré** : [provenance du modèle](../native/godot/ui/contextual/rooms/assets/athlete/QUATERNIUS-CC0.md). |
| [CC0 1.0 Universal](https://creativecommons.org/publicdomain/zero/1.0/) | Licence référencée par les deux notices précédentes. | Retrouver le texte de la licence des ressources concernées. | Texte de licence ; vérifier aussi les éventuels éléments tiers d’un nouveau pack. | **Retenu** : les notices des versions effectivement livrées restent la preuve locale. |

Les liens d’auteurs ci-dessus sont relevés depuis les notices du dépôt ; ce
relevé n’est pas une nouvelle vérification en ligne de leurs pages.

## Décisions et points d’entrée du projet

| Référence | Rôle / état constaté le 10 novembre 2026 |
| --- | --- |
| [Dépôt du jeu](https://github.com/Xynph/cadrage-debordement) | Référence partagée du code et de l’avancement. Consulter main et les PR pertinentes avant toute reprise. |
| [Règle de collaboration — PR 537](https://github.com/Xynph/cadrage-debordement/pull/537) | **Intégré** : conseil critique, désaccords expliqués, alternatives recommandées, distinction entre réalisé et proposé ; règle conservée dans [AGENTS.md](../AGENTS.md). |
| [Rendez-vous 3D et staffs — PR 527](https://github.com/Xynph/cadrage-debordement/pull/527) | **Intégré** dans a741f98196b5f9a604915d21ea1df381d68b56c8 ; source des scènes et de leurs validations. |
| [Références rugby](rugby-rules-reference.md) | Points d’entrée vers les lois et règlements ; recontrôler la saison applicable avant une modification sportive. |
| [Données du jeu](donnees-du-jeu.md) | Provenance, périmètre et limites des données. |
| [Crédits des scènes 3D](../native/godot/ui/contextual/rooms/CREDITS.md) | Auteurs, licences et ressources réellement redistribuées. |
| [Audit des idées GitHub](idees-github-20261108.md) | Inventaire historique du 8 novembre ; ses états peuvent être dépassés. Suivre ses renvois vers la réception et comparer au code actuel. |

## Modèle pour une nouvelle entrée

- **Titre et URL pérenne :**
- **Fourni par / contexte :**
- **Utilité pour Oval Legacy :**
- **Coût et licence :** connus ou à vérifier.
- **Statut :** À explorer / Évalué / Retenu / Intégré / Écarté.
- **Date et vérification effectuée :** distinguer lecture, essai et intégration.
- **Décision, preuve et prochaine action :** lien vers le fichier ou la PR.
