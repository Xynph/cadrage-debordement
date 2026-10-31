# Passation definitive V58–V58.2 au compte integrateur

Base : PR #60, #61 et #62, non fusionnees. **Ne pas fusionner directement les branches empilees**, reprendre les trois nouveaux modules `dist/coach-career.js`, `dist/coach-negotiations.js` et `dist/coach-contract-cycle.js` dans un lot d'integration audite a partir du dernier `main`.

## Capacites independantes
- V58 : profils, postes, offres, embauches, licenciements et mouvements d'entraineurs IA.
- V58.1 : candidature joueur, offre concurrente, contre-proposition, contrat, reputation, historique.
- V58.2 : expiration des offres et des contrats, transition annuelle idempotente, audit d'unicite.

## Raccordements necessaires
1. Mapper les identifiants et reputations aux valeurs natives du manager et des clubs.
2. Brancher au systeme financier reel **sans double debit salarial** ; decider si salaire est un forfait annuel ou un cout periodique.
3. Synchroniser la vacance de poste, le titulaire du club et le contrat actif du manager dans **une seule source de verite**.
4. Prevoir la migration optionnelle des sauvegardes v1/v2, avec tests sur copies et export de secours, sans mutation silencieuse.
5. Construire interfaces candidature/offres/negociation et navigation de changement de club.
6. Tester les situations de fin de saison, offres expirees, demission, licenciement et perte de poste.

## Limites et risques a gerer
Les contrats sont des objets **synthetiques**; pas de test de vrai moteur ni d'anciennes sauvegardes. Les licenciements et demissions ne facturent aucune indemnite; une signature peut representer un changement de club sans enregistrer de vraie transaction bancaire; les candidatures ne sont pas encore automatisees par une decision de direction. La logique de validation autorise une mutation de club sur un objet de laboratoire seulement. Ne pas annoncer cette fonctionnalite comme jouable avant integration.

## Test
`tests/v58-final-integration-audit.cjs` ajoute six controles croises aux suites V58 (10), V58.1 (10) et V58.2 (11), pour **37 tests cibles**; statut de la CI dernier commit a verifier avant passation.
