# Décisions prises pendant la mission du 8 novembre 2026

Ces arbitrages restent distincts des règles officielles du rugby et des protections GitHub. Ils sont conservés pour rendre les choix de l'intégrateur vérifiables.

1. Les scripts Bash du dispositif de revue n'étant pas disponibles localement, le workspace et le paquet de revue sont produits avec Git, Node et PowerShell en conservant plan, diff, base, HEAD et journal. Coût si ce choix est insuffisant : une omission du paquet doit être corrigée avant intégration ; aucun test Bash n'est déclaré réussi à partir de cet équivalent.
2. Le workspace de travail et ses preuves restent sur E:, conformément à la demande explicite de continuité, plutôt que d'être supprimés après la revue. Coût : quelques fichiers locaux ignorés, sans effet sur le jeu distribué.
3. La capacité professionnelle de la base commune est le nombre initial de joueurs plus six, borné entre 42 et 100. Le plafond historique de 42 reste applicable aux anciennes bases. Les deux voies de promotion partagent le quota de trois et le même plafond, sans changement salarial implicite. Coût si cet équilibrage convient mal : ajuster cette abstraction et ses migrations, sans la présenter comme une règle officielle.
4. Les choix de supporters exposent leurs coûts et prévisions ; aucune recette n'est ajoutée une seconde fois à la billetterie existante. Coût : certains leviers restent des prévisions et des politiques ; une nouvelle recette devra disposer d'une validation économique dédiée.

Le refus automatique d'installation de Git portable est respecté. Les suites nécessitant Bash doivent être exécutées réellement dans la CI Linux existante. Les conditions techniques du release gate et les protections de branche ne sont pas modifiées par ces arbitrages.
