# Réception de la délégation avec copies durables

Sur la base `0293972`, `tests/native-delegate-transaction06.cjs` échouait à la
comparaison des réponses JSON complètes entre le témoin historique et le moteur
actuel. La reproduction locale échoue après 58,9 secondes au premier scénario
`ordinary`, dans `sameFile`, avec le message `Complete JSON/file bytes must match`.

Le premier écart observé porte sur
`reply[3].model.meta.profileSafety.entries[0].createdAt` et `.id`. Les deux
variantes utilisent le même code de persistance et de copies ; seule la branche
de délégation est remplacée dans le témoin. Chaque variante crée pourtant de
nouveaux UUID et dates murales de copie, qui doivent être distincts en production.
Le gel de `Date.now` du banc ne remplace pas le constructeur `new Date()`.

Le correctif reste dans la copie jetable du module `profile-safety.cjs` utilisée
par ce banc. Sa génération d'identifiants et sa date de création deviennent
répétables, avec compteur propre au magasin et évitement des UUID déjà présents
au redémarrage. Les marqueurs de remplacement sont exigés uniques. Aucun module
de production, calcul de rugby, quota, validation de copie ou mécanisme de
transaction n'est modifié.

Toutes les comparaisons intégrales des réponses, exports et profils sont
conservées. Le banc compare en plus récursivement les copies durables, avec
égalité de tous les chemins et octets. Les empreintes du module original et de
sa fixture, ainsi que le caractère déterministe de son entropie, figurent dans
le rapport de recette. Le témoin historique et son empreinte restent inchangés.

Commande : `node --test tests/native-delegate-transaction06.cjs`, avec Node 22.
Le rapport terminal de l'exécution porte les onze scénarios appariés, la vraie
entrée stdio et les empreintes, sans normalisation des sorties.
