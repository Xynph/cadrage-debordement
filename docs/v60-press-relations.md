# V60 — Presse, personnalités et relations personnelles

Le catalogue est conservé : **30 identités**, dont 10 journalistes référencés avec URL publique et 20 personnages fictifs, réparties entre quatre groupes de médias réels et six fictifs. Les cinq styles (technique, analyse, entretien, enquête, éditorial) décrivent des **personnalités de jeu**, jamais une biographie ou une citation réelle.

La conférence interactive prépare deux à quatre questions parmi 500 IDs stables, 25 thèmes et 1 500 formulations. Chaque question propose maintenant cinq réponses : **Affirmé, Honnête, Agressif, Prudent, Humour**. Les IDs `r0` à `r3` sont préservés ; `r4` porte le ton ASCII `humour`. Les 500 reparties humoristiques sont adaptées au thème et au sujet, sans insulte ni citation empruntée. Les sujets médicaux et de crise gardent une réponse respectueuse. Les anciens libellés archivés ne sont jamais régénérés depuis la banque actuelle.

## Effets expliqués

La projection de chaque option expose son ton, ses conséquences et les variations de moral, médias, supporters, pression et relation individuelle. Les coefficients de base des quatre tons sont préservés. Le style du journaliste module l’accueil médiatique et sa relation personnelle. L’humour plaît davantage au style entretien et peut irriter le style enquête ; sur blessures, crise, défaite ou discipline, son accueil se dégrade. Une relation déjà tendue pénalise encore l’effet médiatique de l’humour. Aucun sourire ne garantit une hausse uniforme de confiance.

Les effets de base par réponse restent bornés : moral −2 à +2, médias −4 à +4, supporters −1 à +3, pression −2 à +3. Les sujets crise/direction conservent le multiplicateur 2 existant. La relation individuelle varie de −6 à +6, avec score final borné entre −100 et +100. L’affichage tient compte de la saturation du score. Les variations réelles des indicateurs collectifs sont enregistrées après application des bornes 0–100.

Le module historique d’interview simple reste compatible avec ses quatre tons et ses cinq sujets. La conférence riche et l’interview simple ne se cumulent pas dans un même contexte.

## Sauvegarde et mémoire

`S.pressPeople` est optionnel : `{version:1, contacts:{[journalistId]:{score, encounters, memory}}}`. Seules les réponses explicites créent ou modifient ce namespace. Chaque contact garde son compteur, son score et trois références datées d’échanges réellement joués (saison, semaine, club, questionId, answerId, delta effectif). La mémoire suit le coach après mobilité, sans réinitialisation annuelle. Elle ne duplique ni les carrières ni leurs dialogues.

Les textes exacts et l’identité du journaliste (ID, nom et média au moment de l’échange) sont dans `pressConference.history`, conservé sur 500 entrées. Le carnet résout les références vers cette archive ; si un libellé a expiré ou n’avait pas été archivé, il affiche son absence. Les anciens exports sans identité ne fabriquent aucune rencontre. Les anciennes réponses `r0` à `r3` et les anciennes conférences sans libellés restent acceptées.

Le contrôleur natif valide strictement la version, les clés connues, les IDs, les scores entiers, les dates, les doublons et les trois dernières références. Les vues restent pures : aucune initialisation, consommation du RNG ni sauvegarde à la consultation. Le worker garde l’unique transaction disque et annule aussi la mémoire individuelle en cas d’échec d’écriture.

## Interface et vérification

`native/godot/ui/press_people_view.gd` fournit un carnet Relations : catalogue complet, identité référencée/fictive correcte, initiales neutres, style simulé, spécialités, score et trois échanges. Les initiales ne prétendent jamais être une photo de journaliste. `build(app, data)` est raccordé au quatrième onglet Relations de la vue presse principale ; Journal, Conférence et Historique gardent leurs indices0/1/2. La conférence affiche chaque ton et ses conséquences, puis les variations personnelles effectives après publication. Son brouillon reste dans l’interface pendant la navigation et ne modifie pas la carrière. Le focus clavier fait défiler les cinq options, y compris Humour à1280×720.

Les suites `native-press-personalities*.cjs` couvrent les cinq choix, les IDs historiques, les différences entre styles, la pureté, les états hostiles, les plafonds, le vrai worker, les archives exactes, import/reprise, calendrier France34 et la mobilité réelle. Le test Godot du carnet reçoit les trois tailles 1280×720, 1600×900 et 1920×1080. Les preuves exécutées, le budget mesuré et les limites de réception sont consignés dans le rapport du lot ; le chargement d’un module ne vaut pas réception d’un EXE final.
