# Windows Delivery Implementation Plan

> For agentic workers: use superpowers:executing-plans or subagent-driven-development task-by-task, with an independent final review.

**Goal:** Livrer un ZIP Windows reçu sur son véritable EXE, rattaché au commit final et accompagné de preuves téléchargeables, pour un budget externe de 0 €.
**Architecture:** Un outillage CI indépendant prépare le SDK et appelle le constructeur existant. Le pilote intégré couvre le cycle long ; des classes SceneTree de recette embarquées couvrent le démarrage graphique et la reprise. Un override.cfg déclaré dans la seule copie QA sélectionne ces classes et une scène vide ; le paquet normal garde main.tscn. La livraison finale main est reconstruite/reçue puis jointe à un brouillon de Release.
**Tech Stack:** Python standard, PowerShell7, Node22.23.4, Godot4.7.2, Windows2022 standard, API GitHub Releases.
**Spec:** docs/superpowers/specs/2026-11-11-windows-delivery-design.md et demande utilisateur détaillée du11novembre.

## Global Constraints
- Budget externe0€, dépôt public, standard runner uniquement ; pas d'Artifacts/cache payants nouveaux.
- Gabi silencieux, audioDummy, profils jetables absolus hors jeu.
- Aucun contournement du gate ou des contrôles de sauvegarde ; SHA exacts avant/après fusion.
- Fenêtre/canvas cible2560×1440, captures originales seulement.
- ZIP officiel inchangé après QA, manifeste complet, preuves d'un Node embarqué.
- Les anciennes preuves PC ne remplacent pas celles du paquet final.

## Review Focus
- Archive hostile : traversée, doublons Windows insensibles à la casse, lien, fichier inattendu ou SHA erroné refusés.
- Reprise : même état/citations au chargement, aucune réécriture silencieuse ; décisions suivantes décrites séparément.
- Recette partielle : un rapport resume/headless ne peut satisfaire le reçu frais/graphique complet.
- Provenance : mauvais commit, EXE, runtime ou manifeste rejetés ; aucun jeton dans l'environnement de l'EXE.
- Graphique : échec renderer/PNG absent ou vide reste un échec explicite, jamais une capture Linux présentée Windows.

## Task1 — Préparer les outils et le build officiel
Files: ci/windows-toolchain.json ; ci/prepare-windows-toolchain.py ; scripts/build-godot-prototype.py ; tests/windows-toolchain.cjs.
Consumes: pins publics reçus sous work/windows-toolchain-research/windows-toolchain.candidate.json.
Produces: prepare-windows-toolchain.py --root DIR --config FILE, reçu toolchain-receipt.json ; SDK/editor/4.7.2-stable/...console.exe, SDK/templates/4.7.2-stable/windows_release_x86_64.exe, SDK/licenses.
- [ ] Tests négatifs des empreintes, chemins d'archives et notices ; aucun binaire fictif présenté comme reçu.
- [ ] Télécharger/contrôler les distributions figées sur Windows ; extraire uniquement les membres nécessaires des templates.
- [ ] Ajouter --source-commit au constructeur, vérifier le SHA fourni contre Git et inscrire sourceCommit/sourceTree dans manifest-build.json.
- [ ] Clarifier la notice de voix : Gabi silencieux, aucun repli TTS actif dans cet export.
- [ ] Vérifier syntaxe/tests locaux ; première exécution native Windows dans la recette ciblée, puis revue.

## Task2 — Recevoir le paquet et sa reprise
Files: ci/windows-package.py ; ci/windows-receipt.ps1 ; ci/windows-resume.gd ; tests/windows-package.cjs ; native/godot/qa_runner.gd.
Interfaces: windows-receipt.ps1 -PackageZip PATH -SourceCommit SHA -EvidenceRoot DIR -MesaRoot DIR ; produit windows-report.json et fresh/resume/captures sous EvidenceRoot.
Python offre verify_archive(zip_path, expected_commit), verify_tree(root, manifest, allowed_extras), validate_qa_report(report, expected_executable, expected_mode).
- [ ] Écrire les tests archive/manifeste/rapport refusant falsification, omission et réception partielle.
- [ ] Extraire le ZIP dans un chemin QA relocalisé avec espaces, vérifier toutes les entrées et leurs empreintes.
- [ ] Lancer l'EXE extrait, environnement filtré, runtime local, profil neuf ; contrôler processus enfant, arrêt, rapport et S2.
- [ ] Ajouter au pilote embarqué la sélection optionnelle QA_RESOLUTION=2560x1440 en conservant ses résolutions historiques par défaut ; déclarer mode/data_dir dans le reçu.
- [ ] Avec le même EXE, lancer ci/windows-resume.gd sur le profil existant, SELF_TEST désactivé, état/citations comparés avant actions ; réutiliser les commandes publiques.
- [ ] Qualifier Mesa et capturer réellement les écrans2560×1440 ; déclarer les outils graphiques ajoutés uniquement à la copie QA.
- [ ] Recontrôler ZIP/manifeste et les compteurs Gabi0, enregistrer chaque limite au lieu de la masquer.
- [ ] Syntaxe/tests locaux puis recette réelle sur Windows ; aucune preuve native déduite de Linux.

## Task3 — CI ciblée, gate et publication
Files: .github/workflows/windows-release.yml ; ci/publish-windows-release.ps1 ; docs/windows-delivery-20261111.md.
Interfaces: workflow PR interne étiquetée windows-receipt pour qualification sans publication ; workflow_dispatch depuis main avec SHA complet pour le paquet final. La publication crée un brouillon lié au SHA exact, avec ZIP, SHA256 et archive des preuves.
- [ ] Actions épinglées, permissions lecture pour recette PR ; contents:write uniquement pour le job manuel main.
- [ ] Aucun upload-artifact/cache ; les fichiers de preuves sont joints directement à un brouillon de Release dans le job autorisé.
- [ ] Qualifier543 sur la version commune, puis recevoir cette version dans539 sans nouvelle CI globale concurrente sur543.
- [ ] Lancer une seule CI globale sur la tête finale539, résoudre tout échec, puis gate check/merge aux SHA verrouillés.
- [ ] Vérifier le reçu main et ses sept jobs complets ; construire/recevoir le nouveau paquet main sur Windows.
- [ ] Inspecter les captures et les reçus téléchargés, contrôler le contenu public, puis publier le brouillon reçu.
- [ ] Mettre à jour539/543, fermer les seules PR reprises en conservant leurs branches ; bilan utilisateur avec commit/CI/ZIP/rapport/images/limites/procédure.

## Task4 — Entrée de recette compatible avec les templates release
Files: scripts/build-godot-prototype.py ; ci/windows-resume.gd ; ci/windows-graphics-smoke.gd ; ci/windows-receipt.ps1 ; ci/windows-package.py ; tests/windows-controller.ps1 ; tests/windows-package.cjs ; tests/test_windows_qa_bootstrap.py.
Interfaces: stage_windows_qa(project) copie les deux classes avant import/export et crée windows_qa/entry.tscn. Set-QA-Mode écrit uniquement override.cfg dans la copie QA et actualise qaExtras. driver-ack.json lie mode, chaîne de scripts embarqués, scène d'entrée, PID, EXE et profil ; Run-Game le vérifie sous 15 secondes pour graphics/resume, jamais pour fresh.
- [ ] Reproduire en tests le pilote absent/incorrect et un override livré pourtant manifesté ; les refuser.
- [ ] Embarquer les classes et la scène vide sans modifier main.gd, project.godot, le template officiel ou les défauts produit.
- [ ] Émettre l'ACK avant toute instanciation de main.tscn ; conserver les comparaisons pures du profil avant cette instanciation.
- [ ] Supprimer --script ; sélectionner la classe par override.cfg QA hashé et restaurer le démarrage normal pour fresh.
- [ ] Vérifier staging/cache/dispatch sous Godot Linux disponible, parse/contrôleur/validateur ; signaler qu'il ne s'agit pas d'un reçu Windows.
- [ ] Faire recevoir d'abord le smoke Windows court par l'intégrateur ; employer ensuite le renderer effectivement reçu pour la reprise complète.

