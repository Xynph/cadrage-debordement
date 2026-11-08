# Gabi — voix et synchronisation native07

La personnalité de Gaston « Gabi » Darroux, 68 ans, ancien pilier et menuisier, ainsi que les 74 répliques des 25 pages sont conservées. Léo retient exactement la voix ElevenLabs approuvée. Les nouvelles prises doivent être produites pendant l'abonnement payant ; les essais Free restent privés et ne sont jamais distribués.

## Synchronisation reçue

La bouche respecte désormais les silences du vrai PCM local. Une enveloppe RMS par fenêtre de 40 ms est calculée une fois lors de la lecture d'un nouveau fichier PCM16. Le calcul est limité à 30 secondes et 4 Mio ; un cache FIFO garde au plus huit enveloppes. La boucle d'image lit seulement l'enveloppe correspondant à la position de lecture, avec le débit et le mélange audio, sans rescanner le PCM.

Les poses contextualisées et leur articulation restent celles de l'atlas original. Le silence ferme la bouche, sans annoncer la fin de la phrase ; Stop, Muet, une nouvelle bulle et un ancien callback ne laissent pas une ancienne articulation active. Le mode mouvement réduit conserve la pose fermée. La synthèse système, dépourvue de PCM, garde sa cadence cosmétique explicite ; aucun alignement phonétique inventé n'est annoncé.

Mesure locale headless sur les 74 prises : 93,114 ms cumulées de préparation d'enveloppes, maximum 2,02 ms pour une prise ; le cache reste limité à huit entrées. Ces mesures décrivent cette machine, pas une garantie de cadence sur tous les PC.

## Voix retenue et production

Voix `xzXYWXH0dYPY9VdmuYZE`, modèle `eleven_v4`, stabilité 0,5, similarité 0,75. Le compte intégrateur a confirmé cet identifiant depuis la vraie voix sélectionnée et a observé Starter actif avant génération. Aucun paiement n'a été effectué par le sous-agent. Les fichiers payants et les observations de génération sont conservés hors du dépôt sur E:.

Les 74 fichiers texte et quatre lots ont été préparés sans préfixe, identifiant ni direction prononcés : 10 506 caractères de paroles, 10 646 avec les séparateurs. Le plan conserve pour chaque réplique ID, page, texte, empreinte et offsets UTF-16. Le contenu et les offsets ont été vérifiés réellement. Les anciens treize WAV Google ne constituent pas une couverture des textes finaux : quatre seulement correspondent encore exactement ; ils ne sont pas mélangés avec la voix retenue.

Les [conditions officielles de publication ElevenLabs](https://elevenlabs.io/docs/help-center/legal/can-i-publish-the-content-i-generate-on-the-platform) attachent l'usage commercial admissible aux créations produites pendant un abonnement payant, avec les conditions particulières applicables ; elles ne rendent pas commerciaux les anciens essais Free. Le plan [Starter](https://elevenlabs.io/pricing), 30 000 crédits/mois, est le premier plan affichant une licence commerciale. Les preuves du compte actif et les empreintes sont distinctes de la documentation publique des conditions.

La réception utilise Whisper-small local avec mots horodatés sur CPU, comparaison normalisée et contrôle des pauses du signal. Les divergences ASR et les homophones sont consignés ; une seconde transcription indépendante utilise le modèle local Whisper-base lorsqu'utile. Aucun texte attendu n'est fourni comme amorce au modèle. Les champs d'écoute humaine restent faux lorsqu'aucune écoute n'a eu lieu. L'identité de voix configurée est vérifiée ; cela ne constitue pas une appréciation humaine exhaustive de l'accent.

Les quatre lots payants sont reçus : **74 WAV actifs, aucune prise en attente**, soit 665,73 secondes et 31 958 330 octets en PCM16 mono 24 kHz. Les 70 bornes internes sont placées au milieu de pauses soutenues du signal ; les 32 extraits où l'ASR différait ont une seconde transcription indépendante conservée. Trois alertes initiales de seuil ont été résolues par des équivalences phonétiques explicites, sans remplacer les textes : `ceux/ce`, `jouent/joue`, `leur/leurs`, `prénom/prénoms`, `pour suivre/poursuivre`, `mets/mais`, `profites/profite`, `points/point`, `matchs/match` et `joués/joué`. Les métriques et transcriptions brutes restent conservées. Une première coupe inadéquate, due à l'horodatage ASR incluant une pause dans le mot « tien », est conservée comme échec externe ; la coupe finale utilise le silence PCM réel.

Les noms `eleven-final-<id>.wav` permettent de garder les 38 WAV historiques et leurs empreintes intacts. Seules les 74 prises payantes sont actives dans le nouveau manifeste. Aucun audio ElevenLabs Free ni Google n'a été ajouté au programme. Les crédits et la notice de provenance décrivent la souscription observée, les conditions officielles et les contrôles réellement exécutés. L'exécution reste entièrement locale.

Le plan d'origine reste attaché au SHA brut `fbe7036e9113ee8e193afb9a47cd275ec8dccf7d69cb2c9bcd74357ccac44057`. Retirer les 59 champs `audioStatus=pending` donne le nouveau SHA brut `3455816a8ef62c3d806f5b5faa4606eccfaf2e160da1d5ff93b7e4dd0f5ec6ea` dans la copie de réception. Une comparaison complète du JSON confirme que ces retraits sont la seule modification de valeurs. Les 74 tuples ID/page/route/empreinte texte restent identiques ; leur empreinte commune est `eccf9a03aca505e47c90766a4cd1a24e68f95b074daa22a8ed3e5ec7c224e176`. Les différences de fins de ligne d'un checkout ne doivent pas être confondues avec un changement de paroles.

## Vérifications et limites

- Voix locale : 197 contrôles réussis, avec vrais WAV silence/parole/silence, débit accéléré, stéréo, arrêt, muet, changement rapide, callbacks périmés, invalidation et borne du cache. La disponibilité complète n'est annoncée que si chaque texte courant est reçu ; Options indique alors « Voix de Gabi enregistrée ».
- Contexte : 176 contrôles réussis ; premières visites et décisions factuelles, profil distinct et absence de répétition conservés.
- Guide général : 263 contrôles réussis ; refus d'écriture : 46 contrôles réussis. Les assertions distinguent la cadence de secours d'un PCM silencieux et la disponibilité des WAV de celle d'une TTS système. L'ancienne attente lexicale du mot « résultat » vérifie désormais la destination et le premier fragment exact de cette page. Les échecs intermédiaires sont conservés dans les preuves externes.
- Personnalité et validateur des assets : vérifiés avec les textes courants et les 38 empreintes historiques. Les gardes stricts du build restent identiques ; la couverture et la notice reflètent désormais les 74 prises reçues.

Ces contrôles sont headless sous Windows avec Godot 4.7.2 ; ils ne constituent pas une nouvelle réception graphique de l'exécutable. La TTS système réelle n'est pas disponible dans ce mode. Les carrières personnelles, le moteur, les règles, l'économie et le format des sauvegardes n'ont pas été modifiés par ce lot.

Les preuves locales, la préparation reproductible, les rapports ASR et les observations de provenance sont conservés sous `E:/Cadrage-Debordement/artefacts/native07-gabi` et les originaux payants sous `E:/Cadrage-Debordement/audio/ElevenLabs-Gabi-final-Starter-20261108`. La réception de l'exécutable reconstruit et la CI du SHA publié restent des étapes du compte intégrateur.
