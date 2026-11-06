# Économie V2 E2.9 — témoin indépendant d'intégrité et jouabilité des crises

**R&D uniquement.** Branche empilée sur E2.8 (#349), module de laboratoire non chargé par `dist/index.html`. Aucun changement des finances natives, de l'IA, des salaires, des sauvegardes existantes ni du gate.

## Contrat de confiance, strictement borné

Une empreinte SHA256 conservée **dans** le même fichier que le registre détecte une corruption, mais ne détecte pas un remplacement complet par une sauvegarde antérieure valide. E2.9 exige donc une **autorité de confiance distincte, injectée explicitement** `{current(), compareAndSet(expected,next)}`. Son état monotone contient la révision et le hash exact de l'enveloppe E2.7. Chaque lecture `verifiedRead` échoue fermement si la paire du disque diverge du dernier ancrage.

L'écriture `transact` vérifie l'ancien ancrage, utilise la transaction atomique E2.7, puis exige la progression CAS de l'autorité à la révision suivante. Une rupture entre le commit disque et celui du témoin laisse le registre **inaccessible en mode normal**, ce qui est volontaire. `confirmedRecovery` n'accepte qu'un écart d'une seule révision avec approval explicite et des preuves d'identité stables, et refuse toute réparation automatique. Elle ne peut pas prouver l'intention métier du commit : un opérateur de confiance doit vérifier le journal externe avant d'autoriser.

Le module expose `fixtureAuthority(anchorFile,key)` **uniquement pour les tests**, utilisant une signature HMAC SHA256 sur la paire de témoin et un fichier séparé. **Cette fixture n'est PAS une autorité indépendante solide de production** : si un adversaire peut restaurer ensemble le témoin et le registre, ou compromettre la clé locale, elle ne protège pas du rollback. En production l'autorité doit être hors de portée de l'écrivain du registre, disposer d'une monotonie garantie (service sécurisé/append-only), d'une identité et d'un contrôle des permissions indépendants, et auditer les preuves documentaires. Le verrou `.e29-guard` sérialise seulement les processus coopérants et requiert un protocole supervisé en cas d'abandon. Aucune disponibilité réseau/Windows/NFS garantie.

## Campagnes sur données réelles *du moteur fictif*

Six profils/graines × quinze saisons. Les 14 clubs ont leur trésorerie **observée**, leurs salaires hebdomadaires et un indicateur illustratif `29 × salaire hebdomadaire`. Pour ne pas confondre estimation et dette, `cash < 29×salaires` est uniquement étiqueté **pression budgétaire illustrative**. Une transition ultérieure au-dessus du seuil est une **récupération observée de l'indicateur**, et non la preuve d'un redressement après faillite. Les rapports conservent le cash minimum, les dégradations de trésorerie et les transitions comparées, sans écrire ni corriger le moteur. Aucune exigence d'argent artificielle ajoutée.

La simulation ne prouve pas encore une expérience utilisateur réussie : des tests UX de décisions économiques (prêt volontaire, priorité sportive, économie progressive, récupération d'une mauvaise saison) restent nécessaires avant toute activation. Le résultat doit rester un **jeu de management**, pas une simulation comptable irréversible.

## Qualificatifs de test

- Tentative de rollback par remplacement du JSON avec une version plus ancienne, contrôle de la signature témoin, corruption du hash, refus de réancrage non autorisé.
- Commit disque avant attestation externe, STOP sûr puis intervention explicite et journal de récupération.
- Huit processus Node indépendants produisant seize écritures sérialisées, cash et nombre d'événements cohérents.
- Réutilisation des tests E2.8 SIGKILL, E2.7 durabilité et E1–E2.6 preuves/anti-double.
- Six campagnes de quinze saisons, trois imports chacune, parité état et checksum des sauvegardes, zéro passif historique automatiquement créé.

**Limites maintenues** : anti-rollback absolu impossible sans témoin indépendant non rembobinable ; cas de test HMAC local = démonstration seulement. Ni authentification de factures par source métier, ni restauration concurrente hostile, ni durabilité d'une vraie panne noyau/disque. Aucun READY, gate, fusion ou intégration gameplay.
