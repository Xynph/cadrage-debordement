# Comparer les renforts et retrouver une piste

Le bouton **Comparer deux pistes** du Recrutement ouvre une consultation sans
commande moteur. La piste active est A ; B retrouve le choix précédent par
identifiant, sinon une autre piste au même poste lorsqu'elle existe. Cette
présélection n'est pas un classement ni une recommandation de signature.

Les cartes montrent le nom, la possibilité d'offre et le motif fourni par le
moteur, ainsi que la source du rapport. La synthèse compare le poste, l'âge,
le niveau, le potentiel observé, la condition lorsqu'elle est projetée, la
prime et le salaire hebdomadaire. Les écarts lisent **B moins A** : un coût ou
un âge plus élevé n'est pas présenté comme un avantage. Les valeurs inconnues
restent « Non communiqué » et leurs écarts « Non comparable ».

L'onglet **36 attributs** suit les quatre familles existantes et laisse toutes
les lignes dans une zone défilante. Les chiffres sont les notes de simulation
déjà projetées. Le potentiel reste celui des observations datées ; aucune
estimation ni donnée réelle supplémentaire n'est introduite. Prime et salaire
ne sont pas additionnés en faux coût annuel, et cette consultation ne signe
aucun contrat.

Le champ de recherche du comparateur et le choix **Même poste que A** réduisent
la liste proposée sans effacer les deux choix actuels. Les indisponibles
restent consultables. Dans la recherche principale, le filtre **Indisponibles**
complète Tous/Disponibles ; plusieurs mots du nom et du poste peuvent être
combinés dans un ordre libre, avec normalisation des accents. Les filtres de
prime, d'âge, le suivi et le tri existants restent actifs.

Les contrôles sont accessibles au clavier. Le focus initial va au choix B ;
Échap ferme le comparateur et revient au bouton d'origine. La fenêtre s'ajuste
à la largeur disponible et son contenu défile aux définitions compactes.

## Réception

`tests/godot-recruitment-comparison.cjs` charge la vraie application, crée une
carrière temporaire commune et consulte ses vrais candidats. Le banc reçoit
les écarts positifs/négatifs/zéro, les valeurs absentes et non finies, les
présélections, les identifiants stables sous recherche, la disponibilité moteur,
les familles d'attributs et le retour de focus par Échap à 720p/1080p/1440p. Il
compare l'empreinte du profil sportif avant/après : aucune écriture de carrière
ni négociation. Le profil du banc reste dans le dossier temporaire système,
hors de l'application.

Préparer les ressources avec le script de staging et Godot 4.7.2, définir
`CD_GODOT_EXECUTABLE`, puis :

```sh
node --test tests/godot-recruitment-comparison.cjs
```

Avec un écran X11 disponible, `CD_COMPARISON_GRAPHICS=1` et
`CD_COMPARISON_OUTPUT=/chemin/absolu/preuves` activent les captures de la
synthèse et des attributs aux trois définitions. Aucun test Windows natif n'est
revendiqué. La réception de l'intégration cumulée et les captures sont
coordonnées par l'intégrateur.

Résultat local final : **45 contrôles, zéro échec** sous Godot 4.7.2 sans fenêtre,
Node 22.23.4, aux trois définitions ([rapport](recrutement-comparaison-cloud-20261110/headless.json)).
La recette historique `godot-recruitment06.cjs` s'arrête dans son montage JS,
avant l'ouverture de Godot : `nativePlayerAttributes is not defined` dans
`nativeDecisions`. Les deux bancs ne sont pas déclarés verts ensemble ; le
banc historique et son exposition de modules sont transmis à l'intégrateur.
