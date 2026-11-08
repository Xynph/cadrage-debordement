# Mission autonome — Oval Legacy 27 — 8 novembre 2026

Lancée par Léo : exécuter `E:/Cadrage-Debordement/prompts/mission-autonome-6h.txt` avec un objectif persistant.

- Début réel : **12:20:56 UTC / 13:20:56 Europe/Paris**.
- Seuil minimal : **18:20:56 UTC / 19:20:56 Europe/Paris**. Les agents simultanés ne cumulent pas leur durée.
- Base distante contrôlée : `3fe6d160a34a9bf3b19005eaef003ac4b1e4ec21`.
- Branche de reprise : `feature/portage-inventaire-20261108`, HEAD initial `2e0fff1042ae978d8676130785eb15291a8ded6a` ; modifications du portage encore non publiées au départ.
- Plan et preuves : `docs/superpowers/plans/2026-11-08-portage-inventaire.md` et journal local `.superpowers/sdd/2026-11-08-portage-inventaire/progress.md`.
- Interruptions constatées depuis le lancement : aucune à ce stade.

## Ordre initial

1. Corriger les trois P2 démontrés : conseils tactiques locaux masqués, suivi interdit à effectif plein, types de réseau de formation insuffisamment validés à l'import.
2. Raccorder la présence contextuelle de Gabi ; vérifier ses nouveaux textes, les préférences et la couverture audio explicite (38 anciens fragments enregistrés, nouveaux fragments en attente de la voix approuvée).
3. Rendre les tests portables en CI sans confondre absence du SDK et validation native ; stabiliser les sources existantes avant d'ajouter des fonctions.
4. Auditer au moins dix améliorations absentes, les classer et développer plusieurs choix utiles dans des domaines différents.
5. Recevoir le vrai exécutable Windows déplacé, publier les évolutions selon les protections du dépôt et fournir les preuves utiles.

Les captures, tests ciblés et longues campagnes déjà reçus restent des preuves datées de leurs versions. Ne pas les annoncer comme réception du futur build. Données personnelles, pack privé et clés restent hors publication.

Audit des nouvelles pistes : [douze améliorations comparées](ameliorations-autonomes-20261108.md), quatre lots retenus : navigation rapide, mémoire du club/comparaison de saisons, journal filtrable du match et confort durable. Leur statut détaillé sera suivi avec leurs preuves.

## Journal des lots

### 12:20 UTC — lancement

Objectif persistant créé ; mission lue intégralement. Main et commentaires récents #73 vérifiés. Aucun recouvrement actif identifié sur les chemins repris. Rapports de Gabi et des deux revues indépendantes récupérés. Les trois défauts ont des scénarios reproductibles et sont traités avant tout élargissement fonctionnel.

### 13:21 UTC — première heure

Les troisP2 initiaux et le défaut de navigation des bulles de Gabi sont corrigés et relus. Le validateur réseau refuse110imports hostiles V1/V2 à checksum exact, avec état et fichier préservés. Les nouveaux lots navigation et mémoire du club sont raccordés au vrai jeu et ont une revue indépendante favorable ; le journal de match a222contrôles ciblés et des captures Windows. Les réglages de confort ont144contrôles graphiques avec vrais effets Match/Portrait et redémarrage.

Un défaut réel du remplacement de fichier Godot sous Windows a été découvert par lecture de source et test concurrent. Un helper partagé utilise le runtimeNode déjà livré ; les erreurs conservent le fichier antérieur. Deux défauts de protocole/encodage trouvés en revue ont ensuite été corrigés et recontrôlés. La réception du futur EXE déplacé reste indispensable.

La campagne globale Node22.23.4 Windows est en cours,372suites initialement sélectionnées. Cinq échecs de dispositifs de test ont été diagnostiqués : référence native incomplète, fauxghPOSIX, deux casCRLF et Bash absent. Les quatre premiers sont corrigés avec assertions strictes conservées sousNode22 etNode26 ; les sept cas shell du témoin restent non exécutables localement et devront réussir sur la CI Linux existante. Aucun gate, workflow ou contrôle d'autorité n'a été modifié.

L'installation automatique de Git portable officiel, envisagée pour fournir Bash, a été rejetée par le contrôle automatique avec le motif «blocked by policy». Aucune nouvelle tentative par un autre chemin ou format. Ce blocage d'outillage ne suspend pas les travaux indépendants.

BDD : rapprochement des16dossiers de postesV16 avec le vrai état initial natif et le registrev2. Douze sont déjà conformes ; quatre correspondent exactement aux quarantaines existantes. Les1592profils compilés sont inchangés ; seules deux empreintes de sources du générateur ont été mises à jour. Les neuf propositions de calibration ne sont pas activées.

Aucun commit/PR de ce nouveau lot ni nouveau build installé n'est encore déclaré. Le profil personnel et le raccourci existant restent préservés. Le QCM de direction3D est en attente ; aucun changement fondamental de style n'est imposé pendant cette attente.

### 13:58 UTC — trajectoires et lisibilité

Réception C02 terminée : neuf saisons initiales réelles, huit carrières àS2semaine2, une limite de banc incomplet àS2semaine1 sans contournement. Les53checkpoints et18reprises de division préservent exactement export/RNG. Retraite, fins de contrat, rating et note au poste restent distingués ; les neuf calibrations ne sont pas activées. Le bornage historique à60agents libres peut faire disparaître un joueur non retraité du monde courant : limite consignée, pas corrigée silencieusement.

La réception globale Node22Windows est terminée :372suites sélectionnées, six échecs initiaux. Quatre défauts de harness ont une correction ciblée verte ; Bash reste absent et le test de saison support a dépassé180secondes pendant la charge concurrente. Un passage isolé est lancé avant toute décision sur sa durée ou sa structure. Aucun échec n'est requalifié en succès sans exécution.

L'audit visuel de24captures compare stretch et pixels natifs. Le texte natif est meilleur à720p, mais le journal n'offre alors que22pixels de lecture et Gabi masque trop de contenu. La production conserve le stretch pendant la correction. Préparation est restructurée en trois sous-onglets ; Journal reçoit le correctif Unicode et compteur après import ainsi qu'une disposition compacte. Une nouvelle comparaison sera nécessaire avant de modifier l'échelle globale.

### 15:28 UTC — réception du lot natif0.5

Préparation, Journal, Composition et Gabi ont leurs corrections et revues. Le Journal montre trois faits complets à720p, recherche Unicode et reset d'import compris. Composition présente quinze cartes distinctes et conserve le banc focalisé ; Effectif libère trois lignes complètes. La référence physique est maintenant adaptative jusqu'à1600×900 : taille native à720p et confort1,2 à1080p. Les redimensionnements modifient les espacements en place, sans reconstruire champs, confirmation, brouillon Presse, caméra ou lecture.

L'audit intégré a trouvé puis fait corriger deux effets croisés : Gabi compact interceptait52% du bouton des décisions et une réduction depuis grande fenêtre gardait le banc hors champ. Un dock transparent dans le pied de page existant sépare les contrôles ; les bulles restent libres au-dessus. Le dernier guide432E a691contrôles intégrés et30sondes indépendantes réussis ; la revue est favorable, limitée au code source. Le nouvel historique des décisions a293contrôles et42sondes indépendantes après correction de son défilement clavier.

Présentation3D : TV rapprochée et suivie, Action plus proche, Tactique entière ; tenue extérieure originale contrastée quand les couleurs se confondent. Portage180trames et préférences restent reçus. Une pose de porteur sans ballon a été démontrée puis supprimée ; retour du ballon et entrée immuable vérifiés. Mesures troisLOD sur RTX4080SUPER seulement, contact à deux corps toujours partiel.

Recette étendue du vrai shell/worker :867contrôles réussis en158,713s, saison complète puisS2, vingt routes, huit domaines,38WAV décodés, réglages atomiques, import v1/v2 et état/checksum/RNG exacts. Premier passage866/1 avait une comparaison erronée de la date d'enveloppe d'export : l'état et le checksum étaient identiques ; aucune garde métier assouplie. Le harness attend désormais explicitement le vrai changement de fenêtre et le debounce avant de mesurer les tailles. Le candidat EXE déplacé reste à recevoir séparément.

Voix : un nouvel essai gratuit après4h37 a réussi, puis la production a de nouveau rencontré429 à15:05:27UTC. Treize fichiers sur74 sont préparés et transcrits hors du jeu ; trois écarts ASR à écouter. Aucun retry, nouvelle clé/projet ou facturation, aucun mélange dans le programme. Les38anciens clips restent provisoires et36textes pending. Voir le [rapport vocal](voix-gabi-production-20261108.md).

Main distant3fe6d160 et ruleset26326518 recontrôlés : PR obligatoire, ValidationCI stricte, aucun bypass, suppression/force-push interdits. Le wrapper préparé exécute la copie immuable du gate officiel ; aucune fusion lancée à ce stade. Le code doit maintenant être committé/publié, revu globalement et reçu en CI/Windows. Le seuil minimal de mission reste18:20:56UTC ; aucune interruption globale constatée.
