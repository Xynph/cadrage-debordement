extends SceneTree
const Observation = preload("res://ui/player_observation.gd")
const Sort = preload("res://ui/recruitment_sort.gd")
const P = preload("res://ui/immersive08/projection.gd")
const K = preload("res://ui/player_knowledge_text.gd")
var checks := 0
var failures := 0
func check(value: bool,message: String) -> void:
	checks+=1
	if not value:failures+=1;printerr("FAIL: ",message)
func _initialize() -> void:
	var own := {"rating":82,"potential":99,"potentialRange":{"min":81,"max":85},"knowledge":{"owned":true,"stage":"club"}}
	check(K.rating_text(own)=="82","Niveau du club exact")
	check(K.potential_text(own)=="81–85","Potentiel propre toujours en fourchette fournie")
	check(K.sort_value(own,"potential")==81,"Tri par borne basse visible, jamais potentiel réel")
	check(K.attributes_known(own),"Attributs propres connus")
	var legacy := {"rating":82,"potential":99}
	check(K.rating_text(legacy)=="—","Ancienne projection sans appartenance : pas de niveau exact par défaut")
	check(K.rating_text(legacy,true)=="82","Contexte propre explicite autorisé")
	check(K.potential_text(legacy)=="—","Ancien potentiel scalaire jamais publié")
	check(K.sort_value(legacy,"potential")==null,"Ancien potentiel scalaire exclu du tri")
	var foreign := {"rating":99,"potential":100,"ratingRange":{"min":70,"max":78},"potentialRange":{"min":80,"max":90},"knowledge":{"owned":false,"stage":"unobserved"}}
	check(K.rating_text(foreign)=="—" and K.potential_text(foreign)=="—","Non observé : aucune qualité révélée même dans une projection mal formée")
	check(not K.attributes_known(foreign),"Attributs étrangers masqués")
	foreign.knowledge.stage="observed"
	check(K.rating_text(foreign)=="70–78" and K.potential_text(foreign)=="80–90","Première observation : fourchettes fournies")
	check(K.rating_text(foreign,true)=="70–78","Métadonnée étrangère prioritaire sur un contexte propre erroné")
	check(K.sort_value(foreign,"rating")==70 and K.sort_value(foreign,"potential")==80,"Tri étranger limité aux bornes visibles")
	check(not K.attributes_known(foreign),"Première observation sans attributs détaillés")
	foreign.knowledge.stage="deep";foreign.ratingRange={"min":75,"max":79};foreign.potentialRange={"min":83,"max":87}
	check(K.rating_text(foreign)=="75–79" and K.potential_text(foreign)=="83–87","Observation approfondie : toujours aucune valeur exacte étrangère")
	check(K.attributes_known(foreign),"Attributs détaillés accessibles après approfondissement")
	check(K.potential_text({"potentialRange":{"min":82,"max":82}})=="—","Fourchette dégénérée de potentiel refusée")
	check(K.potential_text({"potentialRange":{"min":90,"max":80}})=="—","Fourchette inversée refusée")
	check(K.potential_text({"potentialRange":{"min":NAN,"max":80}})=="—","Valeur non finie refusée")
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
