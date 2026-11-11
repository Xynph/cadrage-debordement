# Classification des 26 suites SDK — 11 novembre 2026

Produit de référence : `96f537040bf9f2e37bf10b0a9b09518b732244a2`. Périmètre : les20 suites de l’audit fe79 et les six blocages. Ce reçu fige les preuves disponibles ; aucune modification WIP ne constitue un PASS. Les neuf suites de sdk_preloads ont leur propre rapport.

Les durées Node excluent l’attente du verrou. Borne globale180s, VM et budgets des tests conservés. Les trois premiers anciens reçus mesurent séparément une durée TAP et un temps mural incluant le verrou : leur temps mural ne qualifie pas la CI. `diagnostic_stop=true` indique un arrêt terminal ou à la première assertion rouge : les assertions suivantes n’ont pas été exécutées.

| Suite | Preuve | Code / secondes Node | Cause / observation | État |
| --- | --- | --- | --- | --- |
| `godot-review-regressions` | Sondes P1 exécutées ; wrapper non exécuté | — | Défaut produit géométrique : dialogue de contrat1540px aux petites fenêtres. | Classée P1 ; aucun PASS SDK |
| `godot-carnet-ui` | Sondes P1 exécutées ; wrapper non exécuté | — | Défauts produit géométriques contrats/calendrier ; ancien parcours du direct également visible en source. | Classée P1 ; aucun PASS SDK |
| `godot-fatigue-overview` | Sondes P1 exécutées ; wrapper non exécuté | — | Défaut produit : préparation entraînement déborde de39px à1920 ; setup rendez-vous ancien. | Classée P1 ; aucun PASS SDK |
| `godot-pack-ui` | Lecture seule | — | Source96 déjà migrée vers Réception et règlement des rendez-vous ; exécution interrompue avant reçu. | Verdict non établi |
| `deepen-youth-draft` | Exécutée | 1 / 40.351 | Confirmation refusée tant que les rendez-vous persistent ; ancienne progression hebdomadaire. | WIP non qualifié ; replay corrigé finit au timeout enfant150s |
| `deepen-youth-ui` | Exécutée | 1 / 96.367 | Activation refusée après setup sans clôture des rendez-vous. | WIP non qualifié |
| `godot-guide-integration` | Exécutée | 1 / 151.109 | Timeout enfant150s reçu, étape exacte non localisée. clear_press incomplet établi par lecture seulement. | Cause du timeout non attribuée ; WIP non qualifié |
| `godot-reception-decisions` | Lecture seule | — | Ancien écran Presse et retour libre ; la salle actuelle est obligatoire et conserve un rendez-vous. | WIP non exécuté |
| `native-press-ui` | Lecture seule | — | Ancien écran Presse remplacé par salle3D, réponses et continuation persistante. | WIP non exécuté |
| `godot-playbook-watch-ui` | Lecture seule | — | Navigation de gestion verrouillée pendant le vrai direct ; ancien pilote attend ces écrans. | WIP non exécuté |
| `godot-career-final-fixes` | Lecture seule | — | Anciennes propriétés du panneau de direct remplacées par drawer_tab/drawer_body. | WIP non exécuté |
| `godot-office-ui` | Lecture seule | — | Attend OfficeCarnet, remplacé par les compositions ImmersiveOffice actuelles. | WIP non exécuté |
| `godot-squad-column-sort` | Exécutée | 1 / ancien reçu TAP, voir JSON | Fixture potentiel exact au lieu des intervalles potentialRange et des valeurs inconnues. | PASS corrigé105 assertions ; `c458a91`, 21.242s /180 |
| `godot-portrait-continuity` | Exécutée partiellement, arrêt diagnostic | 1 / 29.321 | float(null) sur une note de marché inconnue. Un spotlight vide peut être légitime. | WIP non qualifié ; premier replay corrigé rouge |
| `godot-academy-portraits` | Exécutée | 1 / 27.607 | Joueur U18 recherché dans la page U21 ; identité de texture reste rouge après changement de page. | WIP non qualifié ; replay79 assertions/1 échec |
| `godot-youth-scout-ui` | Lecture seule | — | Suppose plus de20 candidats et présence simultanée de modèles XP/annuels dans la vraie carrière. | WIP non exécuté |
| `godot-club-memory` | Exécutée | 1 / 17.876 | Attend le texte volontairement retiré «Aucun passé». | PASS corrigé75 assertions + archives S2/S6 ; `e8e8ee4`, 23.23s /180 |
| `godot-regen-portraits` | Exécutée | 1 / ancien reçu TAP, voir JSON | Infobulle actuelle donne le nom du joueur ; ancien avertissement retiré. | PASS corrigé526 assertions ; `9ef8c6c`, 2.693s /180 |
| `godot-immersion-copy` | Exécutée | 1 / ancien reçu TAP, voir JSON | Hôte simulé sans façade Immersive utilisée par le composant courant. | PASS corrigé12 assertions ; `3c8d19b`, 2.285s /180 |
| `godot-match-journal` | Exécutée | 0 / 54.445 | Déjà migrée sur96. | PASS inchangé351 assertions |
| `deepen-match` | Exécutée partiellement, arrêt diagnostic | 1 / 21.179 | Appel inexistant _select_tab dans live_view.gd à la ligne42. Course reconnexion supplémentaire déduite des sources. | WIP non qualifié |
| `deepen-staff-hire-ui` | Exécutée partiellement, arrêt à la première assertion rouge | 1 / 20.483 | Première confirmation refusée ; rendez-vous initiaux non acquittés. Hérite staff-real/youth-scout. | WIP non qualifié |
| `deepen-staff-real-ui` | Exécutée partiellement, arrêt à la première assertion rouge | 1 / 17.436 | Première confirmation refusée ; rendez-vous initiaux non acquittés. Carrière fiction, pas attribution automatique à cadence quotidienne. | WIP non qualifié |
| `godot-art-direction` | Exécutée jusqu’à borne globale | 124 / 180.059 | 180s atteints pendant captures actives (39PNG à1280), sans erreur terminale reçue ; matrice trois tailles non terminée. | Budget non qualifié ; pas de hausse du délai |
| `godot-contextual` | Exécutée intégralement | 0 / 100.907 | Les cinq sous-suites passent sur96 après staging/import et sérialisation ; cause historique du timeout non démontrée. | PASS inchangé, cinq sous-suites et1114 assertions de flow |
| `godot-contract-negotiation` | Exécutée partiellement, arrêt diagnostic | 1 / 20.712 | Refus explicite : terminer le rendez-vous du club, puis propriété de négociation absente. Salaire affiché arrondi/exact autre attente ancienne déduite. | WIP non qualifié |

## Preuves et reproduction

Les TSV voisins conservent les reçus bornés originaux et corrigés, y compris les replays rouges. Le JSON voisin conserve les SHA256 des journaux, leurs extraits et les blobs Git96 des tests. Les journaux complets restent dans les chemins consignés ; les extraits sont durables dans ce dépôt. Les747 fichiers GD/CJS de la copie de référence ont été comparés à leurs blobs96, sans divergence (manifest SHA256 dans le JSON).

Commande de staging : `python scripts/build-godot-prototype.py --stage-only --node /workspace/.cloud-setup/tools/node-v22.23.4-linux-x64/bin/node`, exécutée sur copie isolée, puis import SDK de cette copie. Godot4.7.2 stable, Node22.23.4, audio Dummy, profils jetables, Gabi silencieux. Chaque invocation Node passe sous le verrou `/tmp/rg27-godot-sdk.lock` avec borne180s hors attente. Les sources racines ne sont pas importées.

Réexécution d’une suite : `CD_GODOT_EXECUTABLE=<adaptateur SDK Dummy> CD_GODOT_EXE=<adaptateur SDK Dummy> node tests/<suite>.cjs` dans la copie stagée/importée. Les scripts directs deepen sont exécutés par leur wrapper CJS, avec les mêmes limites. L’adaptateur interrompt les erreurs GDScript terminales ; le mode de classification96 peut aussi interrompre la première assertion rouge. Aucun arrêt diagnostic n’est utilisé pour revendiquer un PASS.

Les quatre commits corrigés qualifiés ne dépendent pas des ajouts WIP du helper. Helper96 : `d9c2c5792f93e2c5f7d19980b046286f9b9208869ddc1fd15a5af4bdd86c625d`. Les ajouts autorisés prepare_match_day/finish_match_week restent hors de ce reçu qualifié et hors de ce commit documentaire.

## Défauts produit classés par preuves indépendantes

Les trois wrappers géométriques n’ont pas été rejoués intégralement. Les sondes P1 réelles sur96 fournissent leur classement produit : contrats1540px (36 échecs géométriques avant correction, commit preuve `6be4134ede8ebe39f96bcc6ecd5bc8b72a9932a2`), Réception+119px, entraînement+39px, calendrier+69px à1920×1080. Le JSON joint contient les rapports RED originaux. Les correctifs produit appartiennent aux familles P1, pas à cette branche de tests.

Relecture indépendante des six : commit `e3071be`, `docs/sdk-six-suites-static-review-20261111.md`. Elle distingue les déductions des sources et les exécutions. Nos six nouveaux reçus remplacent les états «non exécuté» de cette relecture.

Aucun ancien texte volontairement retiré n’est réintroduit. Aucun PASS Windows natif ni conformité rugby n’est revendiqué. L’interruption exec-server antérieure et un DISPLAY perdu n’ont pas été classés comme défauts du jeu.
