# PR 552 — reprise du head 5666193

**Verdict : À CORRIGER**, SHA exact `5666193089a9cd4dd9b37ab6d71f934c1aa2a0c8`.
Réception du 11 novembre 2026 : [description et commentaires](https://github.com/Xynph/cadrage-debordement/pull/552) relus, métadonnées conservées dans le reçu.
Comparaison à `a25d3066a02da68fcc19818ff6fd7c92e5043ac2` : fusion de main96 et correction du décompte des saisons sans club ; aucune correction des hooks de reprise.
Le blob `worker.cjs` est identique aux deux heads (`b2e1dcf74e1cfafe7c29fa4dd40ba85e9591c5a6`).
La sonde originale est rejouée sur une archive Git isolée, Node 22.23.4 Linux, graine 27, horloge 1794178800000, carrière commune club 29.
Création avec `CD_SALAIRES_PAR_NIVEAU=1`, fermeture, réouverture sans drapeau : la toute première commande est `snapshot`, sans mutation préalable.
Résultat : plancher **270 € → absent**, budget **présent → absent**, recettes prévues **222 300 → 160 000 €**, charges **258 900 → 50 670 €**.
Prévision de trésorerie : **2 449 900 → 6 017 220 €** ; marque sauvegardée version 3 / 52 semaines conservée.
Sonde indépendante d’intégrité : octets du profil identiques après démarrage, snapshot et export ; export complet identique.
RNG du protocole profil (`seed`) : **27 → 27**, horloge identique ; aucun impact persistant observé.
Le profil conserve le SHA256 `2e349715d9b5d783c668df8c5ac986c0e3dc7c8b684c7c833af9afd8c70a203d` ; les deux exports conservent `f685b334f8832c224d67998cc423020ae24288497115a28b69ada5d6021cc51d`.
Cause en source : retours `snapshot` ligne 300, `export` ligne 308 et `shutdown` ligne 309, avant installation des hooks ligne 324.
[Sondes, sorties, commande, empreintes et métadonnées PR](../qa/experimental-flags-20261111/552-refresh/receipt.json) ; [résultat intégrité](../qa/experimental-flags-20261111/552-refresh/resume-integrity-5666193.json).
`resume-probe.cjs <archive>` sort 0 (observation) ; `timeout 90 node resume-integrity-probe.cjs <archive> <résultat>` sort 1 : intégrité PASS, première projection RED.
Le worker-probe complet et les anciennes 53 suites ne sont pas relancés : le cas initial reproduit le blocage connu.
Limites : cette graine et cette carrière ; aucun nouveau reçu OFF contre main96, aucune recette graphique/Godot/Windows ni conformité rugby revendiquée.
Aucune production modifiée. Prochaine étape : Claude doit installer les hooks avant toute projection de reprise, puis faire passer ce premier cas sans commande mutante.
