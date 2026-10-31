# V55 — Kit de contrats pour une future carrière jouable

**Périmètre strict :** tests synthétiques et documentations, sans modifier le véritable jeu. Les fixtures ne sont pas importées dans le moteur ; ne pas présenter les tests comme une validation d'intégration réelle.

Sept contrôles indépendants :
1. Contrat de sauvegarde, identifiants et rattachement unique des joueurs.
2. Transfert signé : opération atomique, débit/crédit cohérents, effectifs mis à jour.
3. Refus des achats impossibles et des doublons, sans mutation d'état.
4. Investissement : dépense unique, niveau installé et événement réconcilié.
5. Changement d'entraîneur : ancien et nouveau titulaires traçables.
6. Sérialisation et reprise JSON sans perte des transactions.
7. Rejet des associations de joueur corrompues.

Le fichier `tests/v55-playable-contracts.cjs` fournit un **contrat cible**, non un raccordement effectif aux modules du jeu. Son rapport JSON est disponible par GitHub Actions. Pour étendre ces contrôles au jeu réel, il faut documenter le format de sauvegarde existant, faire adapter les clés par l'intégrateur et tester d'anciennes sauvegardes sur des copies.

Ne pas fusionner les branches de laboratoire contenant des snapshots V46–V51 en production.
