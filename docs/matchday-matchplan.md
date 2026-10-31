# MATCHDAY-03 — Poste de décision avant-match

Extension **jouable** et dépendante de MATCHDAY-02 (PR #124). Sous le briefing, dans **Préparation**, trois scénarios associant une feuille à 23 conforme et le plan de match : lecture du staff (équilibrée), rotation protégée (fraîcheur + défense prudente), prise d'initiative (performance + stratégie offensive adaptée).

Le projet utilise sans copie de moteur : \`matchday02Proposal\`, \`buildSheet\`, \`matchDossier\`, \`dossierMetrics\`, \`dossierAdvice\`, \`TACTICS\` et \`DEFENCES\`. Cinq duels chiffrés concernent les secteurs mêlée/avants, passe-vitesse, pied, discipline et plaquage, à partir des attributs natifs. Les menaces et la séquence des trois prochaines rencontres proviennent de la carrière. Les chiffres sont des **estimations fictives sur terrain sec**, jamais des probabilités garanties.

Le joueur peut comparer sans modifier son équipe ou le stockage. Avant toute application, l'empreinte du contexte d'équipe et de tactique est revalidée ; la feuille (23, absence de doublon/blessure, admissibilité aux postes) et les clés de tactique sont vérifiées. Une seule application synchrone de \`S.lineup\`, \`S.reserves\`, \`S.tactic\` et \`S.defence\`, suivie d'une **seule sauvegarde native**. Pas de mutation lors de la lecture ou de planification multi-match ; les prochains matchs sont affichés sans engager des sélections futures.

## Tests et limites
- \`node tests/matchday-matchplan.cjs\` : scénarios, cinq domaines, calendrier, transparence, empreinte périmée, verrou match, une seule action et sauvegarde rétrocompatible.
- \`python tests/matchday-matchplan-browser.py\` : Chromium Linux 1280/768/390/320, interaction, absence d'erreur et de débordement.
- Aucune loi de rugby, physique ou sauvegarde ajoutée ; pas de certification du lanceur Windows.
- PR dépendante : cibler \`integration/matchday02-lineup-advisor\`, jamais main tant que #124 n'est pas explicitement fusionnée et vérifiée post-fusion. Rebaser/retarget puis exiger CI HEAD complète et accord utilisateur.
