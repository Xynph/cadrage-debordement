# Retour natif OS Linux X11 — reçu du 12 novembre 2026

Source produit figée `37e085b687b4e9a603085beaa50fecf9d6cace22`. Root a reçu
**47 contrôles, zéro échec, sortie 0, 43,908 s**, avec trois PNG natifs 2560×1440.
[Rapport, scripts exécutés, captures, provenance et historique rouge](evidence/night-native-os-20261112/README.md).

Le vrai Return XTest ouvre la fixture `s1-elite-league-0-0` de la copie privée
du profil public Common 0 ; Alt_L+Left restitue la même source/focus/scroll et
libère le dialogue. Source originale (trois fichiers) et cinq sources produit
vérifiées par hashes ; profil/modèle/RNG/horloge/bridge_next_id inchangés après
baseline. Les compteurs de parole sont cette fois réellement sérialisés : 0/0,
identifiant 0, avec mute précoce et audio Dummy. Scroll conservé à 0 dans ce cas.

Cua getState était indisponible (« node_repl sandbox cannot be disabled »).
La recette utilise une alternative OS Linux avec libX11/libXtst existantes ;
aucune configuration de sandbox n’est contournée ou modifiée. Sur Xvfb nu,
root a d’abord focalisé explicitement le seul Godot observé 0x600003, car le focus
initial était PointerRoot ; les touches suivantes vont au focus X11 courant.
Le journal documente cette étape et les événements natifs reçus par Godot.
Aucune recette Windows ni couverture Cua n’est revendiquée.

Le premier essai 47/1 reste distinct : comparaison Array JSON flottante versus
littérale entière dans le harness, diagnostic reproduit, puis comparaison
numérique exacte corrigée. Ses retours OS et invariants passaient déjà. Aucun
PNG rouge n’est publié comme vert et aucun ancien résultat n’est remplacé.

Les sources privées restent uniquement hashées : aucun profil ni guide privé
publié. Ce reçu ciblé ne constitue pas une campagne SDK globale. Publication
documentaire uniquement, sans nouveau SDK/import/input/capture ni modification
de common, des workflows ou du registre SDK.
