# Sauvegarde : journal d'actions et fréquence réglable (16/11/2026)

Règle de Léo : tout ce qui n'est pas un vrai chargement est instantané. Vrais chargements acceptés : ouverture du
jeu, Continuer, lancement d'un match, sauvegarde automatique (fréquence réglable).

## Avant

Chaque commande qui modifiait la carrière réécrivait le profil entier (`donnees.json`, ~23 Mo) et sa copie de
secours (audit `docs/audit-20261111.md` F2). Depuis l'écriture différée, une décision répondait d'abord, puis le
moteur restait occupé ~0,4 s (validation stricte ~0,3 s, écriture ~0,06 s sur la machine de mesure, plusieurs
secondes sur un disque lent) : une deuxième décision attendait cette écriture. Chaque minute du direct suivait le même
chemin.

## Maintenant (`native/engine/action-journal.cjs`, `worker.cjs`, option `journal`)

- **Décision** : appliquée en mémoire ; une ligne de quelques centaines d'octets est ajoutée à
  `journal-actions.jsonl` (à côté du profil) et synchronisée sur disque **avant** la réponse. Ni sérialisation
  complète, ni validation, ni réécriture du profil.
- **Sauvegarde complète** (validation des décisions encore non validées, écriture atomique inchangée, copie de
  secours) : à la fin d'une avance du calendrier si la fréquence l'exige, à la fermeture, à « Sauvegarder »
  (Ctrl+S), à la création, à l'import, aux restaurations et à la nouvelle saison. Le journal repart alors de zéro.
- **Fréquence** (Réglages › Confort › « Sauvegarde automatique », préférence `autosave` d'`interface.json`, lue par
  le moteur dans le même dossier de profil) :
  - « Chaque jour » : à la fin de chaque avance (Continuer, Jour suivant…) dont la date a changé, jamais pendant ;
  - « Chaque semaine » (**défaut**) : à la fin de l'avance qui fait changer de semaine (lundi) ;
  - « Chaque mois » : à la fin de l'avance qui fait changer de mois.
  Pas d'option « À chaque Continuer » (identique à « Chaque jour ») ni « Désactivée » (décision de Léo, 16/11).
  Défaut « semaine » : la semaine est l'unité du rugby (un match, une clôture) ; le journal protège déjà chaque
  décision, la fréquence ne règle que la durée de reprise au chargement après un arrêt imprévu.
- **Indicateur** : la ligne d'état existante « Sauvegarde automatique » indique la fréquence et la date de la
  dernière sauvegarde complète, ou la reprise du journal après un arrêt imprévu (en couleur d'alerte si une partie n'a
  pas pu être reprise). Aucun nouveau composant.

## Format du journal

Une valeur JSON par ligne : en-tête `{"journal":1,"base":"<sha256 du donnees.json>"}`, puis une ligne par commande
réussie `{"c","p","k","s","e"}` (commande, paramètres, horloge utilisée, graine avant et après). Avant de publier un
nouveau profil, la marque `{"publication":"<sha256>"}` est ajoutée : si l'application s'arrête entre le renommage du
profil et la remise à zéro du journal, les actions déjà incluses ne sont pas rejouées une seconde fois.

## Au chargement

Les actions postérieures à la dernière sauvegarde complète sont rejouées avec leur horloge et leur graine ; la graine
obtenue après chaque action doit être celle notée. Une dernière ligne coupée (arrêt pendant l'ajout, jamais confirmée
au joueur) est ignorée. Une action qui échoue ou diverge arrête la reprise à la précédente : le journal d'origine est
**conservé** (`journal-non-rejoue-*.jsonl`) et le joueur en est informé. Un journal d'un autre profil ou illisible est
conservé de même (`journal-ecarte-*`, `journal-illisible-*`), jamais effacé.

Ancien journal (lignes sans séances de la semaine `w`, avant #1309) : les jours d'un « Continuer » gardaient les séances
de la dernière projection, parfois celles d'une semaine passée ; la clôture d'une semaine sans match les jouait ainsi
(carrière reprise différente sans alerte, ou arrêt sur « résultat différent »). Quand séances gardées et séances projetées
diffèrent, les deux sont essayées (jours consécutifs d'une avance : séances gardées d'abord), la graine notée départage,
au plus 8 retours en arrière ; sinon la plus longue suite confirmée est reprise. Les lignes reprises sont réécrites avec
leur `w`. Test : `tests/reprise-ancien-journal-semaine.cjs`.

## Garanties en cas de plantage

- Décision confirmée à l'écran = ligne déjà sur disque : rien n'est perdu (avant : la dernière décision pouvait
  l'être pendant les ~0,4 s d'écriture différée).
- Les jours d'un Continuer sont notés un par un : une coupure au milieu les garde.
- Le profil complet n'est jamais modifié en place (temporaire, synchronisation, renommage, copie de secours).
- Un ajout impossible au journal refuse la décision avec sa raison et l'annule en mémoire ; un échec de sauvegarde
  complète refuse l'avance comme avant.

## Limites connues

- La validation stricte d'une décision a lieu à la sauvegarde complète suivante (ou à la clôture de semaine) : une
  décision qui rendrait la carrière invalide (défaut du moteur) est refusée plus tard, avec l'avance qui la valide.
- La réponse d'une décision reste dominée par la projection du modèle (~0,3 s) et le filtre de connaissance
  (~0,15 s) : chantier distinct (audit E1/E2).

Tests : `tests/sauvegarde-journal-monde.cjs`. CD_JOURNAL=0 rétablit l'ancien chemin (écriture différée par décision) ;
CD_SAUVEGARDE_AUTO=jour|semaine|mois force la fréquence.

## Reprise avant le match (décision de Léo, 16/11/2026)

Une carrière n'est jamais enregistrée en plein match. Du coup d'envoi à la validation du résultat (`finish_round`), le
profil écrit (fermeture, « Sauvegarder », coupure) est celui d'avant le coup d'envoi (carrière, graine, horloge), le
journal ne note rien et l'export décrit aussi la carrière d'avant le match : au rechargement, jour du match, coup d'envoi
à rejouer. La validation du résultat enregistre la carrière en entier. Dans le jeu, « Quitter » pendant le match demande
confirmation ; une fermeture imposée par le système n'est jamais bloquée.
Anciennes sauvegardes : un journal qui contient le coup d'envoi est repris jusqu'à la veille de celui-ci (lignes du match
conservées dans `journal-avant-match-*.jsonl`) ; un profil écrit en plein match par une version précédente ne contient
pas l'état d'avant le coup d'envoi : il est lu tel quel, match en pause à la minute enregistrée, avec un avis
(`meta.matchResumeNotice`). Tests : `tests/reprise-avant-match.cjs`, `tests/godot-quitter-pendant-match.cjs` ;
`matchResume:false` ou CD_REPRISE_AVANT_MATCH=0 rétablit l'ancien comportement.
