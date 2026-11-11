# Six suites SDK — relecture statique du 11 novembre 2026

Lecture seule, terminée à 14:47 UTC. Aucun Godot, test Node ou changement dans
le périmètre du producteur. Références : copie immuable
`/workspace/qa/sdk-semantics-96`, SHA `96f53704`, et fichiers non commités dans
`/workspace/work/rg27-sdk-semantics`. Ces derniers évoluent pendant la lecture ;
les positions de ligne ci-dessous correspondent au relevé de 14:46 UTC.

**Les six baselines ne sont pas encore exécutées.** Le producteur a confirmé
que le premier passage avait été interrompu avant ces six entrées. Les causes
ci-dessous sont établies par les sources ou signalées comme risques ; aucune
nouvelle panne produit ni réussite de suite n'est déduite d'une lecture.

## Diagnostic par suite

| Suite | Obsolescence certaine du scénario 96 | État des changements du producteur et résidu |
| --- | --- | --- |
| `deepen-match` | `tests/deepen-match.gd:42` appelle `_select_tab("Journal")` puis cherche sous `app.body:44`. En direct immersif, le vrai écran est `ui/contextual/live_view.gd`, expose `_toggle_drawer:207` et est affecté à `app.match_screen` par `ui/contextual/director.gd:95`. L'ancienne méthode n'y existe pas. | Adressé : vrai tiroir et recherche sous `app.match_screen`. Autre course identifiée puis adressée à `deepen-match.gd:172` : attendre aussi `app.waiting` après reconnexion, pas le seul `last_response_ok` conservé du shutdown. Le helper `command:15–23` vérifie désormais l'acceptation locale, mais retourne `void` : un échec enregistré n'empêche pas un appelant de déréférencer le modèle suivant. À recevoir par exécution. |
| `deepen-staff-hire-ui` | Setup `tests/deepen-staff-hire-ui.gd:24` ouvrait Staff directement après création, sans terminer les rendez-vous réels. `main.gd:414` conserve la salle obligatoire et `club-meetings.cjs:189` refuse les décisions hors contexte. L'échec d'un sélecteur/commande peut ensuite cascader. | Adressé : settlement après création. L'héritage est important : ce pilote étend `deepen-staff-real-ui.gd`, qui étend `godot-youth-scout-ui.gd`. Copier uniquement le fichier cible ne reçoit pas les changements des parents. Le helper hérité `godot-youth-scout-ui.gd:18–20` ignore toujours le booléen `_command` et n'interrompt pas le parcours après une réponse refusée. |
| `deepen-staff-real-ui` | Setup de création sans settlement à `:33`. Ancienne chaîne `:80` entraînement/composition/coup d'envoi/délégation/clôture ignorant les rendez-vous déclenchés et la distinction confirmation du résultat/clôture de semaine. | Adressé à `:81–85` par les helpers publics et le contrôle du retour `finish_match_week`. Attention : le mode testé est `fiction`, pas `common` ; une cadence absente peut être légitime. Ne pas attribuer automatiquement le refus au jour du match. Le helper de préparation traite aussi les meetings après entraînement, même sans cadence journalière. Le salaire staff doit être vérifié après la vraie clôture de semaine, comme le fait maintenant la version modifiée. |
| `godot-art-direction` | Ancien `:121` appelait `begin_match` immédiatement après création commune, alors que `worker.cjs:381` exige le jour autorisé. Son ancien `wait_model` enregistrait une erreur mais pouvait retourner vrai et poursuivre vers des contrôles inexistants. | Adressé : `wait_model:15–22` vérifie maintenant `last_response_ok` et erreur vide ; `send:23–28` vérifie l'acceptation ; préparation du jour et fin de semaine bornées. **Résidu de couverture** : les listes de routes `:53` et `:131` incluent Presse ; `main.gd:420` refuse cette navigation sans origine courrier. Sans assertion de route réelle, la capture peut montrer l'écran précédent sous un nom Presse. Passer par le courrier réel ou déclarer ce cas hors portée ; ne pas fabriquer la métadonnée. |
| `godot-contextual` | Pas d'ancien onglet ni de passage direct hors calendrier identifié dans le flux : il possède déjà `prepare_match_day`, traite les meetings, exerce les refus attendus et avance les jours restants. Ne pas lui imputer le défaut des autres pilotes sans journal. | `tests/godot-contextual.cjs:11–19` contient cinq sous-tests, chacun avec un enfant borné à 285 s (`:37`) et un test Node à 300 s. Le runner baseline borne pourtant **le fichier entier** à 270 s. Une terminaison globale ne permet pas de conclure que le flux individuel bloque. `godot-contextual-flow.gd:35` ignore encore l'acceptation locale de `_command` ; ses contrôles de réponse n'arrêtent pas la coroutine. |
| `godot-contract-negotiation` | Setup commun sans settlement à l'ancien `:52`, puis attentes de salaire brut dans le texte et le SpinBox (`:88–94` ancien). La production utilise `Salary.format`, arrondit l'affichage à la centaine et garde le salaire hebdomadaire exact dans les métadonnées. | Adressé : settlement, `Salary.amount` à `:92`, `Salary.input_weekly` à `:98/131` et comparaison séparée de l'affichage arrondi. Ce sont des attentes de test périmées, pas une perte de salaire démontrée. `command:20–23` ignore encore l'acceptation locale et `low_offer:40–46` déréférence le dialogue après un simple check ; une ouverture refusée peut donc empêcher d'atteindre le `quit` final. |

## Pourquoi « timeout » ne suffit pas à conclure

`check(false)` accumule généralement un échec puis continue. Une erreur GDScript
sur un contrôle Nil abandonne la coroutine de test avant son `finish/quit`, tout
en laissant l'arbre actif. Le délai CJS est alors seulement le symptôme terminal.
L'adaptateur diagnostic `sdk-semantics-96/godot-dummy` conserve les sources,
redirige vers le vrai SDK/GL, puis termine sur code 86 après une erreur de script ;
ce code signifie « assertions restantes non exécutées », jamais succès.

Une autre course concrète était présente dans `deepen-match` : `main.reconnect`
met `waiting=true`, mais `NativeEngineBridge.start/_release` ne remet pas
`last_response_ok` à faux. La boucle pouvait sortir avant la réponse initiale ;
l'import suivant était refusé localement par `main._command:321` pendant le
snapshot et le helper attribuait sa réponse au mauvais appel. La version modifiée
attend désormais `not app.waiting`. Cela a été relu, pas rejoué dans cet audit.

Le chemin de sortie normal existe dans les six pilotes. En particulier
`main._close:1050–1060` attend un arrêt borné puis appelle `get_tree().quit` ;
`await app._close(...)` n'est pas à lui seul un oubli de quit.

## Rejouer sans augmenter les délais

1. L'owner exécute une fois les baselines 96 manquantes, après le P1, avec le
   même staging, SDK et profils temporaires. Conserver première erreur,
   dernière commande acceptée, dernier meeting et code enfant avant de classer.
2. Pour la copie corrigée, figer la liste de fichiers réellement exécutés,
   **parents GD et helper inclus**, et garder la même production 96. Ne pas
   mélanger un CJS ancien et un `--path` nouveau en pensant avoir changé le
   pilote : les CJS staff fixent `--script` depuis leur propre `__dirname`.
3. Garder les bornes existantes (30/45/60 s internes, 180/240/285 s enfants).
   Faire remonter les refus immédiatement dans les pilotes, fermer proprement
   puis sortir en échec avant la déréférence suivante. Ne supprimer aucune
   garde produit et ne pas remplacer une décision réelle par un état fabriqué.
4. Si le budget global de contextual coupe le fichier, isoler ses cinq noms
   `rooms`, `ui`, `match-club-branding`, `shutdown`, `flow` avec
   `node --test --test-name-pattern='^Native contextual NOM:' tests/godot-contextual.cjs`,
   chacun sous une acquisition et une limite externe existante. Cela sépare
   l'attribution sans agrandir un délai ; tracer explicitement les quatre skips.
5. Art direction exige le vrai affichage GL pour `capture:31` ; ne pas forcer
   headless en laissant un `await frame_post_draw` inconditionnel. Les modes
   `FOCUS`, `DIALOGS_ONLY`, `MATCH_ONLY` sont des diagnostics partiels, pas la
   réception complète. De même, une seule `QA_RESOLUTION` doit être déclarée
   comme portée réduite, pas assimilée aux contrôles multi-tailles complets.

Les constats ont été transmis directement à l'owner `sdk_semantics`. Il conserve
la responsabilité des modifications et de leur unique réception exécutée.
