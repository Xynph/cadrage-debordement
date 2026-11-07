# BDD — postes et contrats vérifiés, lot 2

## Périmètre et provenance

Le registre courant v2 conserve les 1 592 identifiants et le catalogue commun du 31 octobre 2026. Il ajoute 229 postes précis aux 12 du premier lot, 66 échéances fermes aux 20 initiales et huit statuts explicitement documentés au statut mixte initial. Bilan : **241 postes, 86 échéances et 9 statuts officiels documentaires** ; respectivement 1 351, 1 506 et 1 583 références restent estimées. Tous les salaires restent fictifs et inchangés.

Les profils sportifs anonymisés proviennent toujours du catalogue commun actif : notes, 36 attributs, 11 compétences, potentiels, traits, âges et barèmes salariaux sont conservés. La qualification de 67 postes principaux change effectivement par rapport à v1 ; les autres postes ajoutés corroborent le rôle existant. La note calculée au poste peut donc varier. Aucun pack privé, attribut réel nouveau, calibration candidate ou règle de match n'est appliqué.

Les pages courantes des dix clubs ont été lues le **7 novembre 2026**. Elles corroborent les postes actuels, sans démontrer leur validité historique au 31 octobre. Les liens, libellés relevés et correspondances d'identité sont conservés dans `data/roster-foundation/verified.json`, uniquement pour le développement. Sources : [Racing](https://www.racing92.fr/racingmen/), [UBB](https://www.ubb.link/equipes/equipe-premiere/effectif.html), [Grenoble](https://fcgrugby.com/fr/players), [Lyon](https://www.lourugby.fr/effectif/), [Colomiers](https://colomiers-rugby.com/effectif/), [Oyonnax](https://oyonnaxrugby.com/effectif-les-oyomen-equipe-pro), [Provence](https://www.provencerugby.com/lequipe-pro/), [Valence Romans](https://www.vrdr.fr/seniors), [Brive](https://cabrive-rugby.com/effectif/effectif.html), [Pau](https://www.section-paloise.com/effectif). Les URL exactes de référence font autorité dans le registre de développement.

Aucune polyvalence n'est déduite : qualifications initiales limitées au poste principal. Traini, Ez Zahouany, Tumania et González restent en quarantaine. Un poste publié n'est pas une attestation réglementaire d'entraînement en première ligne ; le cadre historique de match n'est pas modifié.

Les annonces contractuelles retenues sont datées au plus tard le 31 octobre 2026. Les quatre dossiers Nevers `lnr:213`, `lnr:1499`, `lnr:1555`, `lnr:11655` et le statut Rosette sont exclus : leur date absolue est insuffisamment établie. Les huit nouveaux statuts sont les contrats professionnels explicitement annoncés de Corso et Sokobale, et les six contrats Espoir explicitement annoncés à La Rochelle. Les preuves paraphrasées sont attachées aux sources `c2_08`, `c2_09`, `c2_29` du registre.

Deux seuls nouveaux mois sont connus : juin 2028 pour Vanverberghe et juin 2027 pour Chilachava. Le mois reste `null` dans les autres ajouts. Avec Rebbadj du premier lot, cela donne trois mois documentés au total. L'option de Hewat (2029) reste séparée de l'année ferme (2028), sans activation automatique. Aucun contrat renouvelé en jeu ne devient une référence officielle actuelle.

## Deux versions, sans migration

`data/roster-foundation/archive/v1/` conserve les octets de la copie de travail Windows de la politique, des preuves et du module runtime v1. Le manifeste SHA-256 est vérifié à chaque génération ; `.gitattributes` interdit les conversions de fin de ligne dans cette archive. Empreinte runtime archivé CRLF : `baf77c4a83517adb02358d11f177cd938cf86d356a13be119e8c0cae505fd398`. Le module de la distribution Windows lot1 utilise LF (SHA `8574fb78d79498f962dfaef0d1d916f536c2399ea39a8ad14703072c17675d75`) : comparaison réelle des deux fichiers identique après la seule normalisation CRLF/LF, et non égalité brute des octets. Aucun contenu de registre ne diffère.

Le seul module runtime existant `dist/rugby-roster-foundation.js` contient le registre courant et l'archive anonymisée v1. `resolve(marker)` exige exactement les deux clés `id`, `version` et renvoie le registre de cette version, ou `null`. Les initialiseurs de nouvelles carrières utilisent v2 ; validations et sources du modèle utilisent le marqueur sauvegardé. `commonDatabase` reste inchangé à deux clés ; `rosterFoundation` reste distinct, à deux clés.

Les carrières v1 conservent leurs profils v1, contrats vivants et RNG. Les carrières communes historiques sans marqueur restent sans marqueur et sans overlay. Aucun import n'est réétiqueté ou converti. Versions inconnues, marqueurs supplémentaires, profils, qualifications, sources, contrats initiaux et positions falsifiés sont refusés sans mutation ni écriture. Les plafonds de 5 Mio, de profondeur et de nœuds demeurent inchangés.

Les noms et URL des preuves restent hors runtime : les profils exposent les identifiants anonymes et des codes neutres (`p2_01` à `p2_10`, `c2_01` à `c2_30` pour les sources retenues), avec publication et observation. Les dates distinguent observation courante et publication d'une annonce. Le modèle Godot conserve son interface existante.

## Vérifications réelles

La fixture `tests/fixtures/roster-foundation-v1-s2.json.gz` est le véritable export saison 2 fourni depuis le binaire v1 livré, et non une nouvelle carrière v2 réétiquetée. SHA-256 gzip : `92374c5b242f003649feecf029f4d9d4863fc98a22b83016583ba996510f3e99` ; JSON UTF-8 : 3 722 104 octets. Test : import strict identique, source modèle v1, rejets sans écriture, entraînement, comparaison de continuation avec le catalogue archivé (état et RNG), export/import puis redémarrage disque. Les contrats courants restent distincts des références initiales.

Tests exécutés : `roster-foundation-data`, `roster-foundation-versions`, `godot-roster-foundation`, `godot-common-rosters`, `saves`, `france-saves`, `godot-media-packs`, `godot-import-limits` (six contrôles, dont 5 Mio exacts) et génération commune `--check`. Les deux tests natifs exercent aussi une saison entière, l'intersaison, les échecs disque et la restauration RNG ; les tests de packs vérifient la séparation des identités. Le club 29 dispose désormais d'une feuille complète grâce aux postes documentés : aucune promotion artificielle de trois joueurs n'est nécessaire à la création v2.

Mesures du parcours marqué v2 (état JSON, hors enveloppe) : début 3 026 921 octets /184 705 nœuds ; fin de saison 3 622 115 /227 998 ; saison 2 : 3 681 660 /226 651. Les seuils ne sont pas relevés. Ces parcours ne garantissent pas une taille bornée pour toutes les carrières futures.

Le build Windows, la réception graphique du ZIP, la revue indépendante, la CI distante, la publication et l'intégration sont confiés au parent. Aucun de ces résultats n'est annoncé comme acquis par le producteur de ce lot.
