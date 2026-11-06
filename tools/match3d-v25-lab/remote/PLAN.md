# Autonomie Chat — plan d’exécution V25

Spécification : demande Work exceptionnel du 5 novembre 2026. Aucun gate/fusion, aucune retouche du lot 24.

- [ ] Acquisition : PR #300 au SHA 2d8c8c7eee5aa0dad899aa6bb119e95bda0e7987, trois sources externes épinglées, Blender 4.5.3 LTS officiel et contrôle checksum ; données MakeHuman épinglées, pack CC0 avec SHA256 enregistré puis verrouillé. Ne pas exécuter de téléchargement mocap supplémentaire.
- [ ] Pipeline isolé : workflow push uniquement sur branche R&D et chemins laboratoire, dispatch manuel ; Node 24, Chromium Playwright 1.57, sources et npm ci verrouillés par locks upstream. Chaque essai a son statut propre, aucun téléchargement ne vaut essai réussi.
- [ ] Réception : auditeur publié sur 16 vrais GLB, attributs binaires/matrices/topologie, Blender import/export sur copie et Rigger registration/test ; builds Mesh2Motion et Ara export headless ; tests Chromium préexistants du HEAD lot24 dans copie isolée (LOD, contact, surfaces, 30, benchmark SwiftShader).
- [ ] Preuve : manifeste HEAD/outils/SHA256, rapports/captures/logs/GLB sous artefacts 14 jours ; vérifier téléchargement et inspection par connecteur GitHub accessible Chat.
- [ ] Passation : README commandes et diagnostics, limites licences/runtime/GPU, compte rendu réel dans #73.

Points de revue : checksum invalide doit arrêter l’acquisition ; aucun chemin original modifié ; échec facultatif visible en JSON, réception indispensable en échec si corps/Blender/capture manquent ; sorties CMU non redistribuées comme banque autonome ; archive expirée régénérable sans Work.

Choix : exécution directe dans cette session autorisée par la demande, sans étape d’approbation supplémentaire. Le réseau local ne répond pas aux domaines GitHub ; exécution des téléchargements sur runner distant et non copies locales anciennes.
