# Négociations et concurrence interclubs

## Conception retenue
Devis de négociation sans nouvel état persistant : indemnité et salaire sont modifiables, le vendeur et le joueur répondent séparément avec contre-proposition. Les clubs IA intéressés présentent des offres reproductibles calculées sur profondeur par poste, disponibilité, échéances et moyens financiers publics. Aucune lecture de rating, potentiel, compétences ou traits cachés. La seule consultation ne transfère personne.

Le manager confirme ensuite une clôture explicite et voit le gagnant pressenti ; le worker recalcule toutes les offres et refuse tout résultat devenu périmé. Le gagnant peut être IA : il paie réellement le vendeur et reçoit le même joueur avec son salaire promis. Le joueur préfère le meilleur salaire parmi les indemnités acceptées ; égalités : indemnité, besoin public puis identifiant. Montants et logique fictifs, aucune fenêtre officielle ou inscription automatique revendiquée. Pas de précontrat différé sans cadre réglementaire attesté.

## Plan
1. Écrire et constater rouges les tests de contre-proposition pure, indépendance des notes cachées, gagnant IA et paiement réel.
2. Ajouter commandes interclub_negotiate/interclub_auction au domaine et revalidation stricte sans état neuf.
3. Modifier dialogue : champs éditables, réponse détaillée, clôture confirmée sans perdre le brouillon.
4. Tester vrai worker, reprises/imports, refus disque et devis périmés ; réception UI réelle et régressions existantes.

## Raccord root
Commandes automatiquement découvertes dans native-systems. Projections existantes restent sous clubLife.interclubMarket. La réponse consultative est meta.interclubNegotiation ; la clôture meta.interclubTransfer. Préserver le dialogue InterclubMarket lors refus de ces commandes dans main.gd (_failed), pour garder la saisie et montrer le refus local.

## Comportement livré
La consultation retourne des contre-propositions séparées du vendeur et du joueur, la recevabilité de l'offre humaine et les offres IA réellement finançables. Le besoin public compte les joueurs aptes et sous contrat au-delà de la saison, par famille (par côté pour les piliers). Les IA respectent leur plafond salarial existant, une place disponible et la réserve/provision financière ; elles ne recrutent pas automatiquement ailleurs dans la carrière avec ce nouveau mécanisme.

La concurrence est déclenchée explicitement dans l'atelier de négociation et conclut au maximum un transfert à chaque confirmation. La consultation peut être répétée sans aucun engagement. Une clôture peut donc être remportée par un autre club ; le dialogue l'annonce avant de confirmer. Le transfert est revalidé avec contexte, contrat source et gagnant/montants attendus. Les anciennes commandes d'achat direct restent disponibles pour compatibilité du protocole, distinctes de ce nouveau parcours : la concurrence ne couvre pas rétroactivement tous les transferts du jeu.

## Vérifications reçues
- `node --test tests/deepen-market.cjs tests/deepen-market-worker.cjs tests/interclub-market.cjs` : 15/15 verts (cinq cas purs, deux recettes worker, huit régressions du marché initial). Contre-propositions sans mutation, indépendance des notes cachées, vrai paiement du gagnant IA, offre humaine améliorée, devis devenu périmé après journée ou insolvabilité, rollback disque et import/reprise exacts.
- Consultation worker temporairement raccordée en lecture seule dans la fixture producteur. Le coordinateur possède le raccord de production, testé dans le client complet.
- Godot4.7.2 Linux, client complet et vrai worker avec hooks du coordinateur copiés dans une application jetable : 30 contrôles verts. Montants saisis, contre-propositions, export/disque inchangés après consultation, refus périmé et brouillon conservés, resoumission, confirmation et achat persistant. Rapport `/tmp/cd-deep-market-ui-mcuRfg/report.json`, log `/tmp/deepen-market-ui.log`.
- Aucun test Windows ni nouveau règlement officiel revendiqué. Aucun nouveau champ de sauvegarde : consultations et négociations ne migrent pas les anciennes parties.

La recette UI historique `tests/native-interclub-market.gd` ciblait le premier parcours à achat direct (confirmation dès le clic Approcher). Ce nouveau parcours passe par les champs et un devis ; `tests/deepen-market-ui.gd` reçoit désormais le dialogue réel et le vrai worker.

## Correction de la borne salariale après revue indépendante
Un salaire source de 100 000 €/semaine provoque une demande à105 000€. Le plafonnement des offres IA à100 000€ ne doit jamais faire accepter une offre inférieure à cette demande. Les IA sont désormais exclues si leur offre plafonnée reste sous le seuil du joueur ; le devis humain annonce clairement l'impossibilité au-delà du plafond. Tests de sources100 000 et95 239€ : aucune offre ni gagnant et clôture refusée sans mutation. À95 238€, demande100 000€ : une IA solvable peut encore signer réellement au plafond, avec débit/crédit et contrat valides. Suite finale ciblée :17/17 tests Node réussis.

## Profondeur du marché fictif et personnalisé
Les départs fictifs historiques et personnalisés contiennent réellement trente professionnels par club, y compris quand `aiRosterVersion` vaut2. Ce marqueur de cycle n'est donc pas une preuve d'effectif initial à37. Le marché applique une garde de libération locale à28 uniquement au schéma historique reconnu : version2, worldVersion1, integratedManagementVersion1, quatorze clubs aux identifiants canoniques, aucun marqueur de référence (commonDatabase, worldMode, franceMode, lnrMode, rosterFoundation, identityPack), et métadonnées personnalisées absentes ou version1 à quatorze clubs. Le worker valide par ailleurs les identités et le calendrier personnalisé.

C'est une abstraction de jeu : une feuille de23 et cinq couvertures ; aucune règle fédérale de transfert n'est inventée. Les garde-fous de deux joueurs par famille et deux piliers de chaque côté restent inchangés. Les références communes/mondiales et formes inconnues conservent37. Le minimum37 de la population IA n'est pas modifié dans son moteur : seul le seuil local de départ du marché fictif change. La projection et l'écran annoncent la politique applicable.

Recettes supplémentaires : deux achats réels font passer un vendeur fictif30→29→28, puis il refuse tout nouveau départ ; les piliers initialement seulement deux par côté restent bloqués. Les nouveaux départs natifs fictif, personnalisé et Monde sont créés et effectuent une négociation puis un transfert, sans injecter de faux effectif. Le banc producteur peut copier les raccordements du coordinateur via `CD_MARKET_DEPTH_ENGINE` avant l'intégration ; après intégration, il utilise le worker, les identités et le module personnalisés du dépôt courant.

Suite finale reçue sous Node22 : `node --test tests/deepen-market-depth.cjs tests/deepen-market.cjs tests/deepen-market-worker.cjs tests/interclub-market.cjs` :20/20 tests réussis, zéro échec.
