# Économie V2 — E2.7 preuves signées et stockage transactionnel isolé

**Statut : R&D, non activé dans le gameplay.** Aucun raccord à `dist/index.html`, à la sauvegarde native, aux transferts ou aux salaires. Empilé sur PR #346 E2.6, elle-même empilée sur #344 E2.5.

## Ce qui est protégé

- **Contrôle d'intégrité des pièces.** Enveloppe documentaire versionnée avec HMAC-SHA256 et clé secrète de 32 octets minimum, calcul sur la **totalité du document canonisé** et un domaine séparant facture/reçu. La vérification utilise une comparaison de MAC en temps constant. `sealFixture` est exclusivement un générateur de preuve pour tests ; il ne prouve pas qu'une facture est émise par une autorité réelle. Le gestionnaire de clé et la vérification métier sont à fournir par une future source de confiance. Une clé exposée, un fournisseur compromis ou un faux document signé restent hors garantie.
- **Cohérence des registres.** Les transactions s'appuient sur la vérification E1↔E2.5 d'E2.6. Aucun passif inféré du legacy : le dossier persistant commence vierge avec clubIds explicitement fournis. Aucun doublon de règlement, d'identifiant, de reçu ou de facture n'est admis.
- **Persistance transactionnelle locale.** Chaque écriture est entièrement préparée, validée, sauvegardée dans un fichier temporaire de même répertoire, `fsync` du fichier, `rename` atomique, `fsync` du répertoire. L'enveloppe de stockage inclut la révision et une empreinte SHA256 de cohérence (pas une signature anti-falsification de la base). Les reprises de fichier incomplet, JSON invalide, checksum incohérent ou registres E1/E2.5 divergents sont rejetées, sans réinitialisation silencieuse.
- **Concurrence.** Un répertoire de verrou exclusif `.lock` est acquis par `mkdirSync`. Deux écrivains utilisant cet adaptateur sur un filesystem local qui respecte `mkdir` et `rename` ne peuvent modifier le fichier simultanément. Un verrou orphelin après arrêt brutal provoque un **STOP explicite** ; aucune récupération automatique dangereuse ni vol de verrou.
- **Crash/replay.** Les points d'injection `before-rename` et `after-rename` vérifient qu'on recharge soit l'ancien état complet soit le nouvel état complet, jamais un règlement E1 sans reçu E2.5. Un retry identique n'ajoute ni événement comptable ni deuxième débit.

## Limites non négociables

Ce prototype est destiné aux tests sur le filesystem local POSIX (GitHub Actions Ubuntu). Il n'établit pas la sécurité de NFS, du stockage cloud partagé ou de Windows. Un disque/FS qui viole les garanties de `fsync`/`rename`, un arrêt brutal laissant le verrou, une clé de signature perdue ou compromise, un adversaire ayant droit d'écriture sur le dossier, ou un opérateur qui supprime un lock actif restent hors garantie. Le module est synchrone et ne prédit pas la fiabilité opérationnelle de l'UI. Les journaux inter-processus et la récupération des verrous orphelins nécessitent un protocole supervisé distinct avant toute activation.

**Jouabilité :** aucune charge, facture, pénalité ou déficit ne s'ajoute à la carrière ; fixtures monétaires uniquement dans un sandbox séparé. Le jeu actuel conserve son modèle fictif. Les scénarios 6 × 15 saisons vérifient l'état/save/checksum natifs et l'absence de dette auto-créée. Les chiffres des fixtures ne sont pas des budgets réels de clubs.

## Validation

`node --test tests/economy-v2-durable-store.cjs` + E1–E2.6 ; tests signatures et falsification, insuffisance de liquidité, rollback, crash avant/après rename, relance en nouveau processus, verrou de concurrence, JSON corrompu et rejeu. Matrice GitHub `reference/modeste/alternatif × 827381/99173` = six campagnes natives de quinze saisons, 3 imports natifs par campagne et six artefacts attendus. Ne déclarer aucun test ni job SUCCESS avant sa conclusion GitHub réelle.

**Aucun gate, READY ni fusion.** Suite éventuelle : récupération supervisée des verrous, preuve d'autorité métier, protection des clés, tests agressifs `SIGKILL` pendant chaque étape, stockage Windows et UX d'économie non punitive avant raccord au jeu.
