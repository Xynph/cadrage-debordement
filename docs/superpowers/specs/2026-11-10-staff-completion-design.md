# Complétion fictive des staffs insuffisants

Autorisation de Léo : compléter tous les staffs insuffisants. Architecture et seuils validés par l’intégrateur le 10 novembre 2026. Le lot est indépendant des salles 3D et ne modifie aucun de leurs fichiers.

## Résultat attendu

Les bases initiales France30 et Monde116 disposent d’au moins 15 personnes actives, hors manager humain, avec les fonctions suivantes : adjoint ; avants/mêlée/touche ; arrières/attaque/pied ; défense ; responsable physique, préparateur, réathlétisation ; médecin et deux kinés ; analyste ; recrutement ; formation ; team manager et intendant. Les intitulés existants sont normalisés sans être renommés. Un rôle générique ne vaut pas une spécialité médicale réglementée ; une personne ne couvre qu’un poste minimum à la fois. Les coachs/adjoints génériques peuvent être affectés aux quatre fonctions techniques de jeu, les préparateurs aux trois fonctions physiques et la direction/intendance aux deux fonctions support, sans renommer leur intitulé source ni prétendre une spécialité officielle.

Cible d’effectif de jeu : 15 si club.base<72, 20 entre72 et81, 26 à partir de82. Jamais de suppression des grands staffs existants. Les fiches historiques restent en référence et ne comptent pas comme actives. Les références réelles/anonymisées et leurs fichiers sources restent intacts.

## Approches

Modifier les annuaires vérifiés aurait mélangé faits documentés et personnages fictifs : écarté. Compléter seulement l’affichage aurait laissé les carrières sans ces fonctions : écarté. Choix validé : module pur de complétion, vue composée en lecture et copie persistante à la création du cycle. Le constructeur natif existant reçoit cette vue par son raccord actuel ; pas de modification du worker.

`staff-completion.cjs` fournit classification spécialisée, appariement personnes/postes, génération déterministe de noms/âges/niveaux et construction du supplément. Les références sont copiées telles quelles ; ajouts marqués `sourceKind:generated`, `identityStatus:fictional`, portrait synthétique de banque2, identifiants stables par base/club/fonction/slot. Les IDs autorisés aux packs restent ceux du seul annuaire de référence.

`staff.cjs` compose et met en cache la vue par édition, y compris son chemin common. `staff-career.cjs` conserve une politique optionnelle de complétion pour les nouvelles carrières ; les anciennes carrières actives sans marqueur gardent leur schéma et leurs cibles historiques. Aucune lecture ou reprise ne remplit un licenciement décidé par le manager. Le renouvellement annuel IA respecte les fonctions cibles de la nouvelle politique. Les retraites ne font pas réapparaître l’identité initiale. Le contexte de création de la source composée et `completionOrigins` persisté ancrent les noms/profils/cibles : une évolution annuelle de `club.base` ne les recompose jamais.

La factory pure du module est intégrée à la factory de carrière exportée pour rester autonome lors de sa sérialisation existante dans la VM ; aucune entrée protocole n’est évaluée.

## Identités et économie

Portraits locaux déjà présents : `portraits.describe({id,appearanceId,portraitRole:'staff',appearanceAge,age,appearanceBankVersion:2})`. Aucun téléchargement, aucune photo extérieure. Noms complets de personnages explicitement fictifs, âge et niveau estimés selon le tier, sans RNG de jeu. Le manager humain n’est pas une fiche de staff générée. Aucun diplôme réel ni identité publique attribué aux compléments.

Politique financière inchangée : `descriptive-no-cost-v1`, salaire/prime0, aucun débit de trésorerie ni bonus sportif.

## Preuves

Rapport par club France30/Monde116 : nombre actif avant/après, ajouts par fonction, cible. Tests de couverture minimale, identifiants/noms uniques, sources byte-identiques, pureté/déterminisme, portraits2 stables, sourceKinds corrects, compatibilité ancien cycle, licenciement/reprise sans refill, retraites et recrutements IA annuels, vrai worker import/export/redémarrage/rollback sans coût.
