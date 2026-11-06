# Économie V2 — E2.6 : adaptateur de règlement atomique (recherche)

**Non activé** : `dist/economy-v2-atomic-adapter.js` est un module CommonJS indépendant, jamais inséré dans `dist/index.html`, aucune migration et aucune modification des sauvegardes natives. PR empilée sur #344, elle-même sur #343. Préserve les anciens modules E1–E2.5 et les producteurs.

## Contrat

- `create(clubIds)` produit un ensemble neuf `{version:1,ledger:E1,due:E2.5}` ; il ne reconstruit **aucun passif legacy**.
- `register(bundle,document,verify)` refuse toute admission sans fonction externe de vérification qui renvoie strictement `true` pour le **document complet**. La vérification est à charge d'une future intégration de confiance ; cet adaptateur ne prouve **ni la source ni l'authenticité** d'une pièce en l'absence de celle-ci. Un enregistrement crée dans le même objet de sortie une pièce E2.5 et une promesse E1 non encore payée. Pas d'écriture cash.
- `mature(bundle,period)` constate l'échéance E2.5 sans débit.
- `settle(bundle,receipt,verify)` exige la preuve positive d'un reçu complet, la maturité, une trésorerie E1 suffisante et un identifiant de paiement disponible. Il calcule le débit E1 sur une copie puis atteste le paiement E2.5 sur une copie ; l'objet final n'est livré qu'après `validate` des **deux** registres et de leurs liaisons. Crash/rejet avant commit : le bundle initial est inchangé. Replay du même reçu déjà vérifié : référence originale sans nouvel effet.
- `validate` refuse toute discordance entre les engagements E1 et les attestations E2.5, les doubles reçus/références globales interclubs, les états payés sans écriture comptable exacte et les flux inconnus de remboursement. `restore` vérifie le JSON sauvegardé du **sandbox** avant de l'accepter.
- `summary` préserve l'historique des impayés au mois consulté. Les passifs historiques non mesurables restent `null` dans E2.5.

**Frontière d'atomicité :** transaction immuable et tout-ou-rien **dans le processus** + reprise d'un JSON entier validé. La persistance réelle sur disque ou dans une base et l'atomicité du stockage/anti-concurrence multi-processus ne sont PAS garanties par E2.6 : il faudra un journal transactionnel ou un stockage CAS et des preuves de crash système avant activation. L'authentification des pièces est injectée par l'appelant et n'est pas livrée par le prototype.

## Jouabilité et données

Aucun nouveau règlement automatique, dette historique, faillite forcée ni obstacle salarial n'est introduit. Aucun pilote financier fictif de la carrière n'est modifié. Les tests suivent six campagnes natives de quinze saisons et contrôlent des sauvegardes identiques. Le débit E1 de 350 000 dans les tests est une **facture synthétique de test en sandbox**, jamais une dette du jeu.

## Tests et CI

`node --test tests/economy-v2-atomic-adapter.cjs` et suites E1–E2.5 ; matrice `reference/modeste/alternatif × 827381/99173` = 6 campagnes × 15 saisons, imports, parité de sauvegardes et artefacts JSON. Les scénarios de faillite, reçu falsifié, paiement précoce, rejet atomique, rejouabilité, reçus interclubs et reprise JSON sont dédiés. Résultats uniquement après exécution GitHub Actions ; ne jamais assimiler le statut en attente à une réussite.

Pas de /cd-check, READY, gate ou fusion. Pour E2.7 : authentificateur documentaire fiable, stockage transactionnel atomique et stress de collisions concurrentes + UX d'économie accessible, toujours sur zone isolée.
