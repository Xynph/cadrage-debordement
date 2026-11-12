# Analyse, Club et Bureau — réception graphique ciblée

Sur `bd6a5fe63fe52fbb5ecf4a55859676876c7d983e` : **72 contrôles, zéro échec,
sortie 0**, durée TAP 65,703 s. Godot 4.7.2/X11/llvmpipe, audio Dummy. Aucun
SDK/import n’a été exécuté pour constituer ces preuves.

Le checkpoint réel est copié vers un profil jetable. La fixture conservée
`accession:2026:league:0:4`, clubs 16/29, score 19–10, saison 1, est lue sans
reconstruction de rencontre ou de statistiques individuelles. Le fichier source
a le même SHA-256 avant/après :
`989fabbd101c29417c39d280d29152b84384e7be5dad4529ec450d85f70c59a1`.
La copie et sa préparation publique sont distinctes des consultations. Aucun
profil entier n’est publié.

## Trois PNG originaux inspectés

- [Analyse et vrai résultat](images/analyse-rencontre-reelle-2560.png).
- [Fiche de la rencontre et statistiques collectives conservées](images/fiche-rencontre-reelle-2560.png).
- [Bureau et liens du contexte réel](images/bureau-liens-reels-2560.png).

Les trois images sont natives 2560×1440, sans retouche. La première représente
la vue Club/Histoire contenant l’analyse, pas une route nommée Analyse. Elle
montre une bulle textuelle Gabi et son personnage stock. Le test vérifie les
compteurs requested/started et l’identifiant de parole à zéro ; cette assertion
passe avec audio Dummy. Ces compteurs ne sont pas sérialisés dans report.json :
aucun champ supplémentaire ni silence déduit de l’image n’est inventé.

Les visites originales du rapport documentent score→rencontre, adversaire→club,
joueur→fiche, staff→profil, cash/wages→onglets financiers ; puis Bureau→club
adverse, date exacte, joueur surveillé et vrai résultat récent. Les assertions
contrôlent les retours, le choix du joueur, les instances/focus/défilements,
l’absence de commande et d’écriture pendant la consultation, et l’état sportif/
registre/RNG inchangé après export de contrôle. Les statistiques individuelles
passées ne sont pas reconstruites par l’activation préparatoire du registre.

## Historiques rouges, sans leurs images

- `b4c894ec` : 40 contrôles/6 échecs après de vrais Back ; défaut produit de
  lecteur encore actif, pas une réussite ni un simple échec de setup.
- `58e4651e` : parsing de test, incompatibilité du paramètre Node avec SceneTree ;
  aucun contrôle produit qualifié.
- `8c2f8d15` : compilation du helper returned et timeout enfant 150 s ; aucun
  contrôle produit qualifié.

Chaque essai conserve son propre rapport lorsqu’il existe, ses journaux et
source-copy.json. La source de checkpoint reste inchangée dans les trois.
Aucun PNG rouge n’est repris parmi les trois images qualifiées. Le propriétaire
du contrôleur documente séparément la cause et le correctif des vrais Back.

[Contrat Analyse/Club](../../analysis-club-links-20261111.md) ·
[Contrat Bureau](../../office-entity-links-20261112.md).
Le manifeste donne tailles/origines/SHA256 ; la provenance hache les sources
exactes. Vérification : `sha256sum --check SHA256SUMS`. Ce reçu ciblé ne qualifie
ni toutes les surfaces de l’inventaire, ni une campagne SDK globale, ni Windows.
