# Préparation publique du replay Analyse/Club/Bureau

La variante graphique fraîche sur bd6 a atteint le plafond enfant de 150 s, dernière trace `advance_day 2026-08-30`, sans capture ni rapport UI. Son reçu rouge demeure dans `/workspace/work/night-phase10/analysis-club-office-public` ; ce changement ne le requalifie pas.

Le wrapper prépare désormais la carrière jetable CI via `tests/helpers/analysis-club-public-prepare.cjs`, puis ouvre exactement son profil complet dans le vrai client Godot. Mode `world-champ`, club 29 ; options identiques au worker CLI : calendrier quotidien, presse obligatoire, carrière internationale et éventuelle `CD_GODOT_SEED` validée selon le même domaine. Aucun changement de moteur, timeout VM, transport graphique ou état sportif fabriqué.

La séquence reproduit l’ancien setup GDScript : nouvelle carrière, rendez-vous projetés publics (presse/accusés/protocole médical existant), journées réelles jusqu’à `matchReady`, composition automatique, début de match, continuation explicite des causeries pré/après, délégation, confirmation éventuelle, rendez-vous et clôture quotidienne de semaine. Les entraînements planifiés sont exécutés par les vraies journées ; aucun `train` supplémentaire ne figurait dans le setup graphique remplacé. Le helper ferme le bridge avant la réouverture. La sauvegarde n’est lue que pour vérifier l’archive ; elle n’est jamais réécrite par le test.

Le reçu `public-preparation.json` contient commandes et charges exactes, dates/semaines, version Node, SHA worker/profil, résultat archivé et ID réel, durée et état succès/erreur. Le journal JSONL est persisté après chaque réponse, donc conservé même si le processus est interrompu. Aucun checkpoint externe n’est requis en CI. Le mode checkpoint local conserve sa copie intégrale et sa vérification SHA source avant/après, y compris en échec.

Le budget total reste 180 s dès l’entrée du test ; préparation Node plafonnée à 60 s, enfant Godot limité au minimum de 150 s et du temps global restant (réserve finale de 1 s). Le replay GDScript n’est pas modifié : mêmes assertions de lecture/retour, même vraie interaction clavier, trois captures 2560×1440, sauvegarde/RNG/silence et absence de commande métier pendant la consultation. Ce cas qualifie ces consultations ; les anciennes suites continuent à couvrir les scènes de préparation 3D.

Vérification locale limitée à `node --check` des deux scripts et `git diff --check`. Aucun SDK, import ni préparation de carrière exécuté ici. Réception fonctionnelle et collecte confiées à l’intégrateur dans le common.
