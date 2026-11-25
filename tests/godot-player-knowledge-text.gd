extends SceneTree
const Observation = preload("res://ui/player_observation.gd")
const Sort = preload("res://ui/recruitment_sort.gd")
const P = preload("res://ui/immersive08/projection.gd")
const K = preload("res://ui/player_knowledge_text.gd")
const Notation = preload("res://ui/notation_staff.gd")
var checks := 0
var failures := 0
func check(value: bool,message: String) -> void:
	checks+=1
	if not value:failures+=1;printerr("FAIL: ",message)
## Niveau et Potentiel s'affichent en lettre du staff (« B », « B/B+ », « ? »), jamais en chiffre.
func lettre(texte: String) -> bool:
	return texte == "?" or Array(texte.split("/")).all(func(l: String) -> bool: return l in Notation.LETTRES)
func _initialize() -> void:
	var own := {"rating":82,"potential":99,"potentialRange":{"min":81,"max":85},"knowledge":{"owned":true,"stage":"club"}}
	check(K.text(own,"rating")=="82" and lettre(K.rating_text(own)) and K.rating_text(own)!="?","Niveau du club exact (valeur lue 82, montré en lettre)")
	check(K.text(own,"potential")=="81–85" and lettre(K.potential_text(own)) and K.potential_text(own)!="?","Potentiel propre toujours en fourchette fournie (montré en lettre)")
	check(K.sort_value(own,"potential")==81,"Tri par borne basse visible, jamais potentiel réel")
	check(K.attributes_known(own),"Attributs propres connus")
	check(K.potential_tooltip(own).contains("sans garantie") and K.potential_tooltip(own).contains("personnalité"),"Potentiel évolutif expliqué sans promesse")
	own.potentialDevelopment={"season":1,"label":"Potentiel en hausse"}
	check(K.potential_tooltip(own).contains("Potentiel en hausse"),"Bilan qualitatif propre affiché")
	var concealed := own.duplicate(true);concealed.knowledge={"owned":false,"stage":"unobserved"}
	check(not K.potential_tooltip(concealed).contains("Potentiel en hausse"),"Bilan propre jamais révélé sur un joueur étranger")
	var legacy := {"rating":82,"potential":99}
	check(K.text(legacy,"rating")=="—" and K.rating_text(legacy)=="?","Ancienne projection sans appartenance : pas de niveau exact par défaut")
	check(K.text(legacy,"rating",true)=="82" and K.rating_text(legacy,true)!="?","Contexte propre explicite autorisé")
	check(K.text(legacy,"potential")=="—" and K.potential_text(legacy)=="?","Ancien potentiel scalaire jamais publié")
	check(K.sort_value(legacy,"potential")==null,"Ancien potentiel scalaire exclu du tri")
	var foreign := {"rating":99,"potential":100,"ratingRange":{"min":70,"max":78},"potentialRange":{"min":80,"max":90},"knowledge":{"owned":false,"stage":"unobserved"}}
	check(K.text(foreign,"rating")=="—" and K.text(foreign,"potential")=="—" and K.rating_text(foreign)=="?" and K.potential_text(foreign)=="?","Non observé sans publication de qualités : rien révélé même dans une projection mal formée")
	check(not K.attributes_known(foreign) and not K.exact(foreign) and not K.qualities_visible(foreign),"Attributs étrangers masqués (option « En fourchette », joueur pas observé)")
	# Option « Précises » (défaut, décision de Léo du 25/11/2026) : le moteur publie knowledge.exact pour les autres clubs.
	var visible := foreign.duplicate(true);visible.knowledge.exact=true;visible.potentialRange=null
	check(K.exact(visible) and K.qualities_visible(visible) and K.attributes_known(visible),"Précises : qualités d'un autre club visibles même sans observation")
	check(K.text(visible,"rating")=="99" and K.rating_text(visible)!="?" and lettre(K.rating_text(visible)),"Précises : Niveau lu exact, montré en lettre")
	check(K.potential_text(visible)=="?","Précises : le potentiel reste inconnu tant que le joueur n'est pas observé")
	foreign.knowledge.stage="observed"
	check(K.text(foreign,"rating")=="70–78" and K.text(foreign,"potential")=="80–90" and K.rating_text(foreign)!="?" and K.potential_text(foreign)!="?","Première observation : fourchettes fournies (montrées en lettre)")
	check(K.text(foreign,"rating",true)=="70–78","Métadonnée étrangère prioritaire sur un contexte propre erroné")
	check(K.sort_value(foreign,"rating")==70 and K.sort_value(foreign,"potential")==80,"Tri étranger limité aux bornes visibles")
	check(not K.attributes_known(foreign),"Première observation sans qualités publiées")
	foreign.knowledge.stage="deep";foreign.ratingRange={"min":75,"max":79};foreign.potentialRange={"min":83,"max":87}
	check(K.text(foreign,"rating")=="75–79" and K.text(foreign,"potential")=="83–87","Observation approfondie : toujours aucune valeur exacte étrangère")
	check(not K.attributes_known(foreign),"Le stade seul ne révèle rien : seules les qualités publiées comptent")
	# Option « En fourchette » : observé = fourchette de 9 points, suivi en profondeur = 5 (knowledge.qualitesLargeur).
	foreign.knowledge.qualitesLargeur=5
	check(K.attributes_known(foreign) and K.qualities_visible(foreign) and not K.exact(foreign),"En fourchette : qualités visibles en fourchette, jamais exactes pour un autre club")
	check(K.text(foreign,"rating")=="75–79","En fourchette : le Niveau reste une fourchette")
	check(K.text({"potentialRange":{"min":82,"max":82}},"potential")=="—" and K.potential_text({"potentialRange":{"min":82,"max":82}})=="?","Fourchette dégénérée de potentiel refusée")
	check(K.text({"potentialRange":{"min":90,"max":80}},"potential")=="—" and K.potential_text({"potentialRange":{"min":90,"max":80}})=="?","Fourchette inversée refusée")
	check(K.text({"potentialRange":{"min":NAN,"max":80}},"potential")=="—" and K.potential_text({"potentialRange":{"min":NAN,"max":80}})=="?","Valeur non finie refusée")
	check(K.range_delta({"ratingRange":{"min":70,"max":78}},{"ratingRange":{"min":72,"max":80}},"rating")=="-6 à +10","Écart calculé uniquement sur intervalles visibles")
	check(K.range_delta(own,{"rating":84,"knowledge":{"owned":true}},"rating")=="+2","Écart exact uniquement entre niveaux propres exacts")
	check(not K.potential_text(own).to_lower().contains("estim"),"Pas de badge d’estimation")
	var cohort := {"squad":[{"rating":77},{"rating":79}]}
	var before := JSON.stringify(cohort)
	check(P.group(cohort).rating==78,"Moyenne uniquement entre niveaux propres exacts")
	check(P.group({"squad":[own,{"rating":99,"knowledge":{"owned":false,"stage":"unobserved"}}]}).rating=="—","Pas de faux zéro ou moyenne partielle si niveau étranger inconnu")
	check(P.group({"squad":[foreign]}).rating=="—","Une fourchette ne devient pas une moyenne exacte collective")
	check(P.group({}).rating=="—" and JSON.stringify(cohort)==before,"Effectif vide inconnu et agrégat sans mutation")
	check(Sort.report_label({"knowledge":{"stage":"unobserved"},"grade":"A"})=="À observer","Aucun avis chiffré ou lettre ne remplace une connaissance absente")
	check(Sort.report_label({"knowledge":{"stage":"observed"}})=="Observé","Badge première observation")
	check(Sort.report_label({"knowledge":{"stage":"deep"}})=="Approfondie","Badge approfondi")
	check(Sort.report_label({"knowledge":{"stage":"deep"},"assessment":{"stale":true}})=="Approfondie","Le badge décrit la connaissance courante, pas une appréciation historique")
	check(Observation.caption({"knowledge":{"stage":"unobserved"}})=="Observer","Action initiale")
	check(Observation.caption({"knowledge":{"stage":"observed"}})=="Approfondir","Action après première observation")
	check(Observation.caption({"knowledge":{"stage":"deep"}})=="Actualiser","Action après suivi approfondi")
	check(Observation.caption({"knowledge":{"stage":"deep"},"scouting":{"pending":true}})=="Observation en cours","Travail courant prioritaire sur l’action de suivi")
	print("CONNAISSANCE UI : %d contrôles ; %d échecs" % [checks,failures])
	quit(0 if failures==0 else 1)
