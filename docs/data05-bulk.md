# DATA-05-BULK — contrôle industrialisé et premières preuves de staff

## Extraction vérifiable du 31 octobre 2026

Échantillon reproductible fixé dans `selection.json` : trois premiers joueurs listés dans DATA-03 pour chacun des **30 clubs**, soit **90 profils individuels** consultés via Firecrawl, chaque URL de fiche LNR propre.

Cinq fichiers `profiles-01.json` à `profiles-05.json` : identifiant, club, nom affiché, URL source, groupe de poste, nationalité, âge publié, taille en cm et poids kg. **88/90 ont les trois valeurs âge/taille/poids** ; Rayane Tafili (Vannes) et Gabriel Atlan (Narbonne) n'ont pas de taille/poids sur les pages extraites, donc valeurs null. **90/90 postes et nationalités**. Les dates de naissance exactes ne sont pas affichées sur ces 90 fiches : `birthDate: null`. **Aucune** présence au 1er juillet 2026 n'a été historiquement prouvée par ces seules pages.

## Staff officiel, ne pas créer artificiellement 30 encadrants
- ASM Clermont : Christophe Urios, annoncé au sportif depuis janvier 2023 ; l'arrivée de Joe El-Abd comme entraîneur principal n'est prévue qu'en juillet 2027. Source officielle : https://www.asm-rugby.com/actus/2026-10-07-12-32-38-en-2027-l-asm-lancera-un-nouveau-cycle .
- UBB : Yannick Bru identifié par le club lui-même dans la composition du 4 septembre 2026 : https://www.ubbrugby.com/actualites/10470-la-compo-pour-la-j1-face-au-racing-92.html .

**2/30 clubs ont au moins une preuve nominative de staff** dans cette collecte, **28/30 sans preuve conservés à null**. Une source septembre/octobre n'est pas une preuve directe au 01/07/2026.

## Reconstitution chronologique des transferts

Les **30 arrivées DATA-02** ont été répertoriées et contrôlées dans `transfer-date-audit.json`. La table de transferts saison 2026-2027 confirme des mouvements de saison, **pas la date d'effet exacte**. Pour chacune, `effectiveDate=null`, `loanStatus=null`, `atCareerStart=undetermined`. Aucun de ces 30 ne peut être déclaré officiellement dans le club dès le 1er juillet sans source supplémentaire.

## Contrôles exécutés

Les 5 fichiers GitHub ont été relus et validés via JavaScript : **90/90 URLs/ID/club concordent avec la sélection, 90 IDs distincts, 30 clubs, 88 profils avec mensurations disponibles, 2 absences explicites, 90 dates de naissance nulles**. Tests Node reproductibles en `tests/data05-bulk.cjs` pour la CI. Ne pas confondre CI antérieure sur les PR #121/#122/#123 avec celle de cette PR.

**Cette PR ne touche aucun `dist/**`, sauvegarde ni données déjà enregistrées**. Les données restent un lot documentaire du mod Rugby Réel, pas une installation jouable. Étape suivante : traiter les ~1 500 profils restants par nouveaux lots et trouver des documents officiels datés des 30 staffs et transferts.
