# Concurrence entre clubs IA sur le marché
## Usage
À chaque fenêtre native de recrutement (début de saison après la première et mi-saison), les clubs concurrents proposent simultanément une cible parmi les joueurs déjà disponibles. Le joueur ne signe qu'une fois. En cas de concurrence, le besoin sportif urgent départage les offres, puis la marge financière, puis l'identifiant du club pour conserver un résultat reproductible.

Les clubs battus peuvent se reporter vers d'autres joueurs du même marché au tour suivant. Les signatures réelles retirent le joueur du marché et débitent sa prime de recrutement du club gagnant ; le salaire hebdomadaire et le contrat restent soumis aux mécanismes natifs. La limite existante de six recrutements par fenêtre et deux recrutements par club et saison est maintenue, ainsi que la réserve de 400 000 € et le plafond salarial.

## Visibilité joueur
Le journal des transferts mentionne désormais le nombre de clubs intéressés lorsque plusieurs clubs IA convoitaient le même joueur. L'observatoire natif affiche les recrutements et dépenses déjà produits par la carrière. Il ne s'agit pas d'un nouveau menu isolé.

## Compatibilité et limites
Aucun champ ajouté aux sauvegardes, aucun changement de format, aucun contournement du marché d'agents libres et aucun recrutement des joueurs encore sous contrat avec un autre club. Les anciennes carrières sans cycle IA ne sont pas activées. Les enchères sont un arbitrage déterministe fictif, **pas** une reproduction de négociations contractuelles réelles ; les offres ne sont pas des promesses faites aux joueurs et les notes secrètes restent hors scoring. Aucun changement aux règles de match.

Tests ciblés : `node tests/ai-transfer-competition.cjs` et `node tests/ai-roster-cycle.cjs`. CI de PR obligatoire sur le dernier SHA, puis CI post-fusion réservée à l'intégrateur.
