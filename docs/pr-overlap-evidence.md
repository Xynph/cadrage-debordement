# Précontrôle — attestations de chevauchements historiques

## Portée
Cette modification ne concerne **que** le diagnostic consultatif `/cd-preflight`, pas le release gate, le ruleset ou les droits de fusion. Par défaut, chaque chemin partagé avec une PR ouverte reste bloquant. Une exception est possible **uniquement** pour `dist/index.html` et **uniquement** si toutes les conditions ci-dessous sont réunies. Elle ne classe jamais automatiquement une PR comme obsolète.

## Conditions cumulatives
1. Le propriétaire GitHub `Xynph` (user ID `350229047`) publie **une attestation autonome par PR historique** dans l'issue #73, incluant les deux HEAD de PR et le main SHA à l'instant considéré. L'attestation renonce seulement au caractère bloquant de ce chevauchement pour cette cible, sans modifier ou fermer la PR historique.
2. Les attestations ont le format exact suivant (une seule ligne par commentaire, sans texte ajouté) :
   `CD-RELEASE-OVERLAP v1 PR=209 HEAD=<sha40> CANDIDATE=336 CANDIDATE_HEAD=<sha40> MAIN=<sha40> PATH=dist/index.html`
   Répéter séparément pour chaque PR en collision (exemple #224 et #234). Les numéros/SHA sont vérifiés contre la réponse REST courante, sans valeur par défaut ni wildcard ; tout nouveau concurrent requiert sa propre preuve.
3. La branche candidate ajoute à `dist/index.html` **exactement une balise** `<script src="NOM.js"></script>`, dont le module figure aussi parmi les fichiers modifiés par la PR. Retirer cette balise doit restituer **octet pour octet** l'index du main au SHA vérifié. Aucun CSS, texte, script ou ordre ne peut être supprimé ou modifié ; l'include reste placé avant la scène MATCH 3D.
4. Les preuves sont relues depuis GitHub dans le précontrôle et les HEAD des PR historiques sont revérifiés avant le verdict. Si le main ou le HEAD candidate change pendant le contrôle, les garde-fous préexistants imposent STOP.
5. Toutes les autres exigences demeurent : commentaire de réservation complète de la candidate dans #73, `mergeable_state=clean`, PR HEAD/base exacte, CI JS 7/7 sur candidate et main, identité propriétaire et gate consultatif.

## Sécurité et limites
* Les libérations sont **explicites, périssables et liées aux SHAs**. Pas de déduction d'après une date, un état DRAFT, une simple similarité de code ou un numéro de PR prédéfini.
* Toute collision hors `dist/index.html`, tout changement destructif, absence ou ambiguïté d'attestation, changement de HEAD ou défaut d'API = STOP.
* La preuve d'un ajout non destructif ne démontre pas sa compatibilité fonctionnelle. La CI Chromium dédiée, la compatibilité des sauvegardes et la réception métier restent nécessaires.
* Le diagnostic conserve `authorizedToMerge=false` et indique toujours ruleset non attesté. Le workflow n'a pas de droit de fusion ; le gate officiel et les règles serveur restent obligatoires.
* La règle ne pourra être utilisée qu'après intégration indépendante de cette PR technique sur main, si et seulement si ses tests et son gate officiel l'autorisent. Aucune attestation n'est créée automatiquement pour #209/#224/#234.

## Tests
`node --check ci/pr-overlap-evidence.cjs`, `node --check ci/pr-preflight.cjs`, `node tests/pr-overlap-evidence.cjs`, `node tests/pr-preflight.cjs`. Scénarios : attestations absentes, doubles, auteur falsifié, SHAs erronés, nouveau chevauchement, changement de code, script dupliqué et module non modifié.
