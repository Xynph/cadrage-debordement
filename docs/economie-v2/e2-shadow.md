# E2 — audit legacy en miroir, sans activation du nouveau moteur

Statut : **R&D / DRAFT**, dépend de E1 PR #337. Aucun chargement de `economy-v2-shadow.js` dans le jeu. Pas de mutation de `S`, du moteur financier, ni des sauvegardes.

## Contrat d'observation

`capture(state)` extrait seulement saison, tour, phase, identifiant manager et trésorerie des clubs depuis un état natif reçu. `observe(before,after,entries,label)` rapproche l'écart de trésorerie avec les **vraies écritures de `S.ledger` pour le club manager seulement**. La trésorerie IA existe dans `S.clubs` mais les flux IA ne bénéficient pas encore d'un journal exhaustif similaire : résidus **non expliqués** explicites, aucun flux ajouté arbitrairement. Une entrée manquante pour le manager bloque les assertions des tours.

Pour l'intersaison, l'ancien journal peut être réinitialisé : observation de cash avec flux inconnus, et non rapprochement fictif. Ne pas qualifier une comptabilité globale réconciliée tant que chaque variation IA et intersaison n'a pas une source vérifiable.

## Campagnes natives

Workflow de matrice 3 clubs (référence 0, modeste 13, alternatif 6) × 2 graines (827381, 99173) = **6 campagnes**, chaque campagne parcourt **15 saisons × 29 tours = 435 tours**, soit **90 saisons et 2 610 tours**. Trois rechargements natifs via `N.reload` aux saisons 5, 10, 15. Pas de plancher salarial ni intervention financière ; le jeu est laissé tel quel. Artifacts JSON par campagne avec trésorerie réelle par club et saison, nombres de résidus inexpliqués et statut de rapprochement manager. Ne présenter les quantités comme réussies qu'après conclusion terminale des six jobs.

## Préparation cockpit PC

Source autorisée aujourd'hui : vrais relevés de cash par saison/tour, flux `S.ledger` du club dirigé, dette actuelle si l'observateur la capte explicitement ; pas de revenus IA, marge par catégorie, budget mensuel ou engagements inventés. Les prochains graphiques s'appuieront sur séries réellement enregistrées. Aucun montage dans `dist/index.html` avant rapprochement et audit UX aux résolutions 1920×1080 et 1440×900.

## Limites qui empêchent E2 VERT intégral

Le test natif `N.round` prouve seulement que les écarts du club manager pendant un tour correspondent au journal legacy. Il **ne** prouve **pas** la provenance des flux IA et des transitions d'intersaison. La phase d'après doit instrumenter les points de mutation existants sur une branche autorisée, sans modifier le résultat du moteur ; avant cela, feu ORANGE pour la réconciliation totale et interdiction d'activer E1.
