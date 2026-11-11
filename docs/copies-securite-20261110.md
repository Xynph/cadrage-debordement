# Copies durables de carrière

Le menu de carrière ouvre **Copies de sécurité**. La liste affiche club, saison,
journée, date UTC, origine et espace consommé. **Reprendre cette copie** annonce
le remplacement et demande confirmation ; **Supprimer** confirme séparément
la suppression définitive de la seule copie choisie. Annuler ou consulter ne
modifie pas la carrière.

Avant un import vérifié ou une nouvelle carrière, le moteur conserve une copie
durable de la carrière actuelle. Elle reste disponible après les sauvegardes
suivantes, contrairement au fichier rotatif `donnees-precedentes.json`. Une
adaptation détectée à la reprise conserve le profil original avant la première
nouvelle publication sur disque. Aucun checkpoint n'est créé par un snapshot,
une consultation ou un import invalide.

## Conservation et reprise

Les dossiers `Copies-securite/<UUID>/` restent à côté du profil utilisateur,
hors du programme. Chaque dossier contient :

- `profil.json` : octets du profil disque d'origine, inchangés ;
- `carriere.json` : export vérifié de l'état courant avec aléatoire et horloge
  de reprise, protégés par la même empreinte que cet export ;
- `copie.json` : descriptif et empreintes SHA-256 des deux fichiers.

Le profil brut permet de conserver l'original même si sa reprise demande des
normalisations. Le bouton de reprise ne réinjecte pas aveuglément ce profil :
il emprunte la validation et la reprise compatibles de l'import. Les rencontres
reprennent en pause. Les préférences extérieures à la carrière ne sont pas
remplacées. Une copie de la carrière quittée est conservée avant restauration.

L'état, la graine et l'horloge de reprise proviennent du même instant moteur,
y compris si la présentation a avancé depuis le dernier profil disque. La
date d'export est stabilisée sur cet instant : retenter le même remplacement
refusé ne remplit pas la liste avec des copies identiques.

## Bornes et refus

La limite est de **8 copies ou 256 Mio cumulés**. Le profil brut est limité à
64 Mio et l'export à 24 Mio, plus une petite enveloppe de reprise. Aucune copie
n'est effacée automatiquement. Si le quota ou l'écriture bloque la protection,
le remplacement est refusé et la carrière actuelle est conservée. Le joueur
peut supprimer explicitement une copie puis réessayer.

Les identifiants sont des UUID, jamais des chemins transmis par l'interface.
Les liens symboliques et fichiers non ordinaires sont refusés. Une empreinte
différente interdit la reprise. Une préparation interrompue est visible comme
indisponible, compte dans le quota et peut être supprimée explicitement. Un
contenu inattendu n'est pas parcouru ni supprimé automatiquement.

Chaque fichier est synchronisé avant publication du dossier de copie. Le profil
principal conserve son mécanisme transactionnel existant : un refus de
publication restaure état, stockage, graine et horloge en mémoire et conserve
les fichiers principal/précédent. La copie de protection déjà publiée reste
disponible. Cela ne constitue pas une garantie matérielle contre toutes les
pannes ; conserver un export sur un autre support reste recommandé.

## Vérification observée sur Linux

- `tests/profile-safety.cjs` : 8 tests de fichiers, quotas, corruption,
  chemins, liens, préparation interrompue, refus disque et déduplication.
- `tests/profile-safety-worker.cjs` : 7 scénarios moteur reçus (5 scénarios
  communs/mondiaux, plus aller-retour A→B→A→B et adaptation à la reprise).
  L'action suivante après restauration est comparée à un moteur témoin de B.
  Les refus d'import et de publication sont contrôlés octet par octet.
- `tests/godot-profile-safety.cjs` : 15 contrôles sans fenêtre dans la vraie
  application, avec création des carrières, focus, confirmation/annulation,
  restauration et suppression réelles. Les captures rendues sont à recevoir
  lors de l'intégration parent.

Node 22.23.4 et Godot 4.7.2. Aucune recette native Windows revendiquée. Les
accroches du bouton dans `main.gd` appartiennent à l'intégrateur ; l'API est
`preload("res://ui/profile_safety_view.gd").open(self)` et les reçus sont
`meta.profileSafetyReceipt={command,id}`. Les commandes exigent
`{id,confirmed:true}`. Le succès de `restore_checkpoint` reprend la route
Réception et doit réinitialiser les caches de carrière comme un import.

## Lecture en 1440p

La réception courante cible exclusivement **2560 × 1440**. Le dialogue mesure
1460 × 1080, avec textes de lecture réellement affichés à 20–24 px et titres à
28–32 px. La surface papier, les cartes et les actions sont espacées. Les
confirmations sont centrées dans l'écran, avec texte à 24 px et focus initial
sur **Annuler** ; Entrée sur Annuler conserve la carrière. Le bouton Fermer et
les boutons de confirmation gardent de grandes zones cliquables après
l'habillage natif.

La recette conserve le parcours clavier du vrai menu Carrière, la reprise vers
Réception et les vérifications d'absence d'écriture à la consultation. **30
contrôles sans fenêtre et 36 en rendu X11** ont réussi avec trois captures
vérifiées à 2560 × 1440 : liste, confirmation de reprise et confirmation de
suppression. Les garanties et commandes du moteur restent inchangées. Aucune
nouvelle réception des autres définitions ou de Windows n'est revendiquée.

Pour rejouer : définir `QA_RESOLUTION=2560x1440`, `CD_SAFETY_GRAPHICS=1`,
`CD_GODOT_EXECUTABLE` et éventuellement `CD_SAFETY_OUTPUT`, puis lancer
`node --test tests/godot-profile-safety.cjs` sur un écran X11 2560 × 1440.
