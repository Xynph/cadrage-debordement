# Réception native IA défensive — main final V17

Référence de base : `b41dc9668c03184aa1d00a5a0e40ec144066f538` (PR #248 intégrée).

Cette branche de preuve déclenche le workflow existant `opponent-combined-audit.yml` depuis un HEAD qui reprend exactement le moteur et les tests de `main` après intégration V17. L'objectif est une réception réelle, via Chromium, de 24 graines appariées / 48 matchs et du chargement d'une sauvegarde historique V16. Le workflow vérifie également l'absence de régression PASS 07.

Ce document est un **protocole** et ne certifie aucun résultat. Le verdict final doit reprendre le SHA exact, l'identifiant du run, les conclusions des jobs et, lorsque disponibles, les artefacts de tests. Aucun changement du moteur ou de données réelles n'est autorisé par ce document.
