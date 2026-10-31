# UNIVERS-01 — Deux univers, une saison 2026-2027 commune

## Décision de game design
**Le début d'une nouvelle carrière est fixé au 1er juillet 2026** : c'est une convention de simulation pour permettre recrutement, négociations, préparation et amicaux. Il ne s'agit pas d'une date officielle de reprise de toutes les équipes. La pré-saison est jouable avant le TOP 14 (5 septembre 2026) et la PRO D2 (27–28 août 2026).

Le **jeu de base** utilise 14+16 noms alternatifs originaux, avec identifiants R1 inchangés. Pas de copies à une lettre, de photographies, logos, marques ou portraits réels. Un expert devra revoir les identités avant diffusion. Les fiches des joueurs alternatifs et les écussons originaux sont à produire à une étape distincte.

Le **mod Rugby Réel** présente les vrais noms et effectifs avec sources/droits vérifiés, mais exploite **le même calendrier officiel**. Les matchs exacts, oppositions, lieux et horaires ne sont **pas encore importés** dans cette PR : les déclarer « réels » serait incorrect. Un import futur doit croiser les PDF officiels LNR 9 juillet 2026 et les pages journée par journée ; le jeu peut employer ces dates officielles sans inventer d'opposition attribuée à la LNR. Les matchs amicaux de préparation sont générés comme **événements fictifs**, jamais présentés comme des vrais amicaux.

## Sources officielles des jalons
- https://top14.lnr.fr/actualite/calendrier-20262027-les-dates-connues
- https://top14.lnr.fr/actualite/decouvrez-le-calendrier-2026-2027-de-top-14
- https://prod2.lnr.fr/actualite/decouvrez-le-calendrier-2026-2027-de-pro-d2
- https://www.lnr.fr/presse/calendrier-des-competitions

## Intégration (compte intégrateur uniquement)
- Fichiers `world-data/univers01/**` indépendants. Ne pas modifier `world-data/r1/fr-2026-2027.json` ou `dist/**` actuellement réservés.
- Au **nouveau départ** : sélectionner univers alternatif et la date `2026-07-01`; conserver les identifiants R1 pour compatibilité.
- Au chargement d'une **ancienne partie** : conserver identiquement la date, le club et le calendrier sérialisés. Jamais de migration silencieuse.
- Le mod réel bascule les noms/données mais ne décale pas les journées réelles. Prévoir les semaines internationales/doublons et dates de trêve, une fois les calendriers complets vérifiés.
- Les données DATA-01 (#109) sont un inventaire de recherche distinct ; elles ne constituent pas encore un pack installable.

Test : `node tests/univers01.cjs`. L'installation dans le jeu et le test Chromium sont à réaliser après réception par l'intégrateur.
