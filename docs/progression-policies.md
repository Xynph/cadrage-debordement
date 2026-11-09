# Deux politiques expérimentales de gestion visible

## Périmètre figé avant comparaison

`ci/progression-policies.cjs` fournit deux contrôleurs déterministes pour un banc de carrières appariées : `minimal` (« Gestion minimale jouable ») et `attentive` (« Renouvellement sélectif avec réserve »). Ce second identifiant n'est ni une preuve de bonne gestion, ni une stratégie optimale, ni un substitut validé à un joueur humain.

Version : `progression-policies-v1`. Les paramètres suivants ont été fixés avant les résultats comparatifs ; ils ne sont pas ajustés en fonction des gains mesurés. Le SHA-256 de la source est exporté en `sourceHash` pour figer la méthode de chaque exécution.

Les deux bras utilisent les mêmes actions nécessaires pour jouer : avant chaque match, `auto_lineup` via le sélecteur public, puis `promote_cover` avec confirmation si la sélection reste invalide. Une erreur de couverture n'est jamais transformée en succès. Le runner exécute lui-même `begin_match`, `delegate`, `finish_round` et `next_season`. L'entraînement normal implicite du moteur reste commun aux deux bras ; il n'est pas présenté comme un traitement supplémentaire.

Le bras minimal n'effectue aucun renouvellement volontaire ; il conserve les opérations de couverture et les automatismes existants. Il n'est pas saboté par un mauvais XI/XV imposé, une suppression de joueur ou un refus artificiel de promotion. Le bras de renouvellement sélectif peut considérer au plus **six candidats par saison** :

- contrat expirant cette saison ou déjà expiré, renouvellement disponible dans le modèle visible, âge au plus30ans ;
- tri déterministe par note visible décroissante, potentiel visible décroissant, âge croissant puis identifiant opaque croissant ; les notes et potentiels restent les estimations affichées du jeu ;
- durée cible de deux saisons, bornée par `renewal.minYears` / `renewal.maxYears`, jamais hors1–3 ;
- salaire offert `renewal.salary`, frais exacts `renewal.fee` du modèle public ; aucune demande cachée recalculée ;
- après paiement des frais, réserve d'au moins **max(500000€, huit semaines de nouvelle masse salariale)** ; ce seuil est une heuristique expérimentale, pas un coût du moteur ou un objectif d'équilibrage ;
- une contre-proposition publiée par le vrai worker peut être acceptée **une seule fois**, avec son salaire/frais observés et le même garde de réserve. Une contre-proposition issue d'une autre semaine ou devenue inaccessible est abandonnée et journalisée.

Les candidats déjà considérés ne sont pas proposés à nouveau cette saison. Il peut donc y avoir moins de six signatures. Les demandes, contre-propositions, signatures, frais réellement payés, refus et champs publics utilisés sont journalisés ; aucun total de commande ne remplace la preuve d'une signature.

## Données et commandes autorisées

La politique reçoit uniquement la projection JSON visible du worker : saison/semaine, trésorerie, payroll, sélection et profils de l'effectif (`note`, `potential`, `age`, salaire, échéance, `renewal`). Elle ne reçoit pas l'état exporté, le fichier de profil, le curseur RNG ou les traits cachés. Les exports peuvent servir à mesurer et vérifier les bras dans le runner, jamais à décider des actions.

Commandes produites :

```text
auto_lineup {}
promote_cover {confirmed:true}
extend_contract {playerId,salary,years,confirmed:true}
```

`native/engine/model.cjs` projette l'offre et les bornes de renouvellement. `native/engine/gestion.cjs` contrôle le contrat via les fonctions métier existantes, paie la prime uniquement à signature et renvoie `meta.negotiation`. La couverture publique est facturée2500€/semaine et par espoir par le moteur, sans prix inventé par le contrôleur.

Aucune tactique, recette, subvention, attribut, difficulté adverse, transaction de vente ou investissement n'est ajouté dans cette première version. Les conséquences sportives et financières peuvent changer parce que les contrats conservés modifient la continuité de l'effectif ; c'est le traitement étudié.

## Contrat API du runner

```js
const {createPolicy, profiles, version, sourceHash, commands} = require('./progression-policies.cjs');
const controller = createPolicy('attentive');
const action = controller.nextAction(model, 'before-week');
if (action) {
  const reply = worker.handle({id: nextId, command: action.command, payload: action.payload});
  const observation = controller.observe(action, reply);
  if (observation.critical) throw new Error(reply.error);
  model = reply.model;
}
const audit = controller.summary();
```

Phases : `before-week`, `before-match`, `after-season`, `transition`. La phase `transition` ne produit aucune action ; le runner reste propriétaire du passage de saison. Une action au plus est émise avant `observe()`. Une nouvelle action se calcule sur le nouveau modèle. Les deux profils ont une borne de **16actions par phase**, suffisante pour six offres, six réponses aux contres et la couverture. Le runner doit appliquer cette même borne aux deux bras et refuser les commandes hors allowlist.

Une réponse worker `ok:true` avec `negotiation.status:counter` est un résultat métier attendu, pas une signature et pas une dépense de prime. Toute réponse `ok:false` est enregistrée comme rejet critique et bloque ce contrôleur : elle ne doit pas disparaître derrière un statut de trajectoire achevée. `summary()` expose les événements, le nombre de signatures, les frais et les candidats considérés par saison.

## Qualification avant pilote

Commande : `node --test tests/progression-policies.cjs` sous Node22.

Le smoke apparié utilise deux vrais workers, la même graine827381 et le même instant de création Monde club0. Les états initiaux sont strictement identiques. Le bras sélectif signe réellement **six renouvellements**, pour **78000€ de frais payés**, contre aucune signature volontaire pour le minimal. Les deux feuilles initiales préparées restent identiques et valides. Il s'agit d'une preuve que le traitement est exercé, pas d'un résultat comparatif sur une saison.

Les tests vérifient aussi la détermination, la réserve de trésorerie, le dédoublonnage, l'attente de réponse avant nouvelle action, l'interdiction d'accès aux traits cachés, la non-mutation du modèle d'entrée et le blocage après erreur. Un devis visible périmé est simulé dans une fixture de test, sans modifier le worker : sa véritable négociation publie une contre-proposition puis signe la réponse publique en deux commandes au maximum pour ce joueur. Cette fixture de faute n'est pas utilisée dans les comparaisons.

Les profils sont des méthodes expérimentales. Deux saisons et quelques graines peuvent révéler un effet de continuité, un coût et des risques ; ils ne suffisent pas à conclure à une gestion optimale ou à calibrer l'économie du jeu. La comparaison doit conserver revenus et coûts, cohortes/renouvellements, âge, niveau, risque et résultats sportifs, pas seulement le cash final ou le nombre de signatures. Aucun changement de coefficient du jeu n'est inclus.
