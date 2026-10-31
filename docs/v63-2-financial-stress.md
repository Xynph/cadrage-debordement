# V63.2 — Tests de stress natifs et financier

La suite `tests/v63-2-stress-native.cjs` exécute les vrais scripts de rugby par `tests/harness.cjs` (et non le simulateur fictif V51).

Trois campagnes : référence sur 6 saisons, trésorerie faible sur 5 saisons, club initialement déficitaire sur 5 saisons, soit **16 saisons jouées par le véritable moteur**, avec six checkpoints de sauvegarde et reprise par contexte isolé. Les écritures du ledger, réputations, champions, taille des sauvegardes et intégrité après chaque saison sont contrôlées. Investissement dans les installations testé quand abordable, et recrutement/risque des entraîneurs natifs.

Les valeurs initiales des deux scénarios de crise sont **des hypothèses expérimentales**, pas des finances réelles de clubs. Le niveau de réalisme, le budget négatif et les règles du moteur n'ont pas été modifiés. Des données d'analyse année par année sont exportées en JSON de CI.

**Limites :** le `harness` recrée sa graine aléatoire lors d'une reprise ; ce test confirme la continuité et la validité de la carrière, pas l'identité bit à bit d'un replay. Les modules candidats V58–V61 ne sont pas intégrés. Aucun test Windows natif. Ne pas fusionner sans revue de l'intégrateur.
