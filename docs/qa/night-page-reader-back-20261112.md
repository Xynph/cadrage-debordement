# Retour des lecteurs ouverts depuis une page

Le retour clavier d’un lecteur ouvert depuis une page est reçu dans trois
reçus natifs distincts :

| Scénario | SHA exact | Résultat observé |
| --- | --- | --- |
| Contrat commun, reprise du wrapper existant `godot-entity-navigation` | `58e4651e4abdcb78113a249cbc50699471df702b` | 50 contrôles / 0 échec, wrapper code 0, 18,634 s |
| Graphique Analyse / Club / Bureau depuis un checkpoint réel copié | `bd6a5fe63fe52fbb5ecf4a55859676876c7d983e` | 72 contrôles / 0 échec, wrapper code 0, 65,703 s ; trois PNG 2560×1440 |
| Régression SDK headless des chaînes de lecteurs, préparation publique world-champ / club 29 | `bd6a5fe63fe52fbb5ecf4a55859676876c7d983e` | 115 contrôles / 0 échec, wrapper code 0 ; 113,959 s natifs, 114,019 s TAP |

Le blob de `navigation_controller.gd` est identique sur ces deux SHA, ce que
consigne le [manifeste](evidence/night-page-reader-back-20261112/receipt.json).
Ces reçus ciblés ne constituent pas une nouvelle campagne globale SDK/CI ni
une qualification Windows.

## Cause et correction

La [réception graphique rouge antérieure](evidence/night-page-reader-back-20261112/red-b4c894ec-graphics.log)
avait bien ouvert le détail de rencontre, puis six navigations échouaient.
`open_entity` ne raccordait la fermeture et le retour clavier d’un lecteur que
lorsqu’une **fenêtre source** avait été suspendue. Le premier lecteur ouvert
sur une page n’avait pas de parent enregistré. Alt + gauche restait bloqué par
cette fenêtre encore visible. Le focus apparent du contrôle source ne prouvait
pas sa fermeture et donnait une assertion faussement positive.

Un registre séparé conserve désormais les références faibles des seuls lecteurs
club, rencontre et rapport réellement ouverts par l’API depuis une page.
Le lecteur enfant actif conserve la priorité. Alt + gauche ferme le lecteur
exact, libère son exclusivité puis restitue les contrôles de lecture, focus et
scroll. La restitution exige la même page encore valide, ou sa même entrée
historique lorsqu’un aller-retour a reconstruit la page, et la même route.
Les invalidations et suppressions d’historique oublient ce retour avant de
libérer les fenêtres ; elles ne ressuscitent aucune page périmée.

Aucune détection générale de fenêtres n’est utilisée pour fermer un dialogue.
Les fenêtres métier, les confirmations enfant et les scènes obligatoires
conservent leurs gardes. Aucun callback métier n’est rejoué.

## Vérifications effectivement reçues

La [réception du composant](evidence/night-page-reader-back-20261112/entity-58e4651e-wrapper.log)
réutilise une carrière réelle du wrapper existant, sans nouvelle semaine
simulée : page → club → Retour ; page → club → joueur → Retour au même club →
Retour à la page reconstruite ; confirmation enfant bloquante et fenêtre métier
non fermée. Les assertions exigent fenêtre invisible ou libérée, garde libre,
registre nettoyé, focus revenu, sauvegarde et RNG inchangés.

La [réception graphique](evidence/night-page-reader-back-20261112/graphics-bd6a5fe6-wrapper.log)
vérifie réellement score → fiche de la rencontre → Retour avec disparition du
dialogue et libération de la garde, adversaire, joueur sélectionné, staff,
trésorerie et salaires. Depuis le Bureau, elle active le club du prochain match,
sa date, une alerte de fatigue et un résultat historique. Elle conserve les
assertions sur le focus, le scroll, l’absence de commandes ou écritures par les
liens, l’état sportif exporté et le silence.

Le [rapport](evidence/night-page-reader-back-20261112/graphics-bd6a5fe6-report.json)
retient les véritables identifiants visités. La rencontre
`accession:2026:league:0:4` provient d’une archive réelle ; la
[preuve de copie du checkpoint](evidence/night-page-reader-back-20261112/graphics-bd6a5fe6-source-copy.json)
conserve son identifiant, la saison, les deux clubs et le score. Le SHA-256 du
profil source reste identique avant/après la copie et la recette.

Les trois PNG originaux ont été inspectés par l’intégrateur. Leurs dimensions
et empreintes sont vérifiées dans le manifeste ; ils ne sont pas dupliqués
dans cette preuve légère. Les avertissements d’environnement restent dans les
journaux complets.


## Régression des chaînes de lecteurs sur le contrôleur actuel

Le [journal complet du nouveau passage](evidence/night-page-reader-back-20261112/reader-history-bd6a5fe6-wrapper.log)
reçoit **115 contrôles / 0 échec** sur
`bd6a5fe63fe52fbb5ecf4a55859676876c7d983e`. Ce passage SDK headless conserve
la préparation réelle `world-champ`, club 29, avec commandes publiques de
calendrier et clôture hebdomadaire avant consultation d’un résultat archivé.
Il vérifie club → rencontre → retour, réutilisation du club ancêtre,
date → calendrier → retour à la même fenêtre, confirmation bloquante,
sauvegarde et RNG inchangés, invalidation du cache et absence de fenêtres ou
contextes de lecture oubliés.

Le [reçu et les empreintes des sources](evidence/night-page-reader-back-20261112/reader-history-bd6a5fe6-receipt.json)
retiennent le SHA exact, le journal, les principaux fichiers du contrôleur et
du pilote, ainsi que l’empreinte du profil de recette. **Le profil n’est pas
copié.** Le contrôleur est identique sur la base documentaire `0e644e61`.

L’ancien reçu 115/0 sur `a4326db5ff9d079dfabf64b79ad6100314d5145d` reste une
preuve historique distincte, antérieure au retour des lecteurs racines.
Les deux compteurs ne sont pas additionnés ni présentés comme une campagne
nouvelle. La préparation CI fraîche `common0` introduite sur `0e644e61`
modifie le pilote : ce nouveau cas attend son propre résultat et n’est pas
qualifié par la régression `world-champ` reçue ici.
