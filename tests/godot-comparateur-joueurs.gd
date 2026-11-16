extends SceneTree
## Comparateur de joueurs : logique pure de sélection et d’écarts (aucun moteur, aucun écran).
const Comparison = preload("res://ui/immersive08/recruitment_comparison.gd")
var checks := 0
var failures := 0
func check(value: bool,message: String) -> void:
	checks+=1
	if not value:failures+=1;printerr("FAIL: ",message)
func person(id: String,pos: String,rating: float,extra: Dictionary={}) -> Dictionary:
	var result:={"id":id,"name":"Joueur "+id,"pos":pos,"rating":rating,"condition":80,"age":25,"salary":1000}
	result.merge(extra,true)
	return result
func _initialize() -> void:
	var squad:=[person("s1","Talonneur",70),person("s2","Talonneur",78),person("s3","Pilier",74)]
	var market:=[person("m1","Talonneur",90),person("s2","Talonneur",78)]
	var pool:=Comparison.pool({"squad":squad,"market":market})
	check(pool.size()==4,"Réserve : effectif puis marché, sans doublon")
	check(str(pool[0].id)=="s1" and str(pool[3].id)=="m1","Réserve : mon effectif passe d’abord")
	var own:=["s1","s2","s3"]
	var ids:=Comparison.initial_ids(pool,"m1",[],own)
	check(ids[0]=="m1" and ids[1]=="s2","Second choix par défaut : le meilleur de mon effectif au même poste")
	ids=Comparison.initial_ids(pool,"s3",[],own)
	check(ids[0]=="s3" and ids[1]!="s3" and ids[1]!="","Second choix : jamais le même joueur")
	ids=Comparison.initial_ids(pool,"",["s1","s3"],own)
	check(ids[0]=="s1" and ids[1]=="s3","Mémoire A/B respectée quand elle est complète")
	ids=Comparison.initial_ids(pool,"m1",["s1","s3"],own)
	check(ids[0]=="m1" and ids[1]=="s2","Mémoire d’un autre premier joueur ignorée")
	# Second choix par défaut : même poste dans mon effectif, puis poste proche, puis meilleur disponible, avec mention.
	var roster:=[person("h1","Demi de mêlée",72),person("h2","Demi de mêlée",66),person("l1","Deuxième ligne",80),person("l2","Deuxième ligne",75),person("c1","Centre",60),person("mh","Demi de mêlée",90)]
	var mine:=["h1","h2","l1","l2","c1"]
	ids=Comparison.initial_ids(roster,"h1",[],mine)
	check(ids[1]=="h2","Demi de mêlée : B est l’autre demi de mêlée de mon effectif, pas un deuxième ligne ni le marché")
	check(Comparison.default_note(roster,"h1","h2",mine)=="","Même poste dans mon effectif : aucune mention")
	var lone:=[person("o1","Ailier",70),person("o2","Centre",65),person("o3","Talonneur",90),person("o4","Ailier",50)]
	ids=Comparison.initial_ids(lone,"o1",[],["o1","o2","o3"])
	check(ids[1]=="o2","Poste proche dans mon effectif (centre pour un ailier) avant un autre poste")
	check(Comparison.default_note(lone,"o1","o2",["o1","o2","o3"]).contains("poste proche"),"Poste proche : mention claire")
	ids=Comparison.initial_ids(lone,"o3",[],["o1","o2","o3"])
	check(ids[1]=="o1","Aucun poste proche : le meilleur disponible")
	check(Comparison.default_note(lone,"o3","o1",["o1","o2","o3"]).contains("meilleur disponible"),"Meilleur disponible : mention claire")
	check(Comparison.default_note(lone,"o3","o2",["o1","o2","o3"])=="","Choix de B différent du défaut : aucune mention")
	check(Comparison.close_position("Pilier gauche","Talonneur") and not Comparison.close_position("Centre","Pilier droit"),"Familles de postes proches")
	var a:=person("a","Talonneur",70,{"__own":true,"condition":90,"age":30,"salary":500})
	var b:=person("b","Talonneur",70,{"__own":true,"condition":70,"age":22,"salary":2000})
	check(Comparison.leader("condition",[a,b])==0,"Meilleure condition : A en tête")
	check(Comparison.leader("condition",[b,a])==1,"Meilleure condition : B en tête")
	check(Comparison.leader("age",[a,b])==-1 and Comparison.leader("salary",[a,b])==-1,"Âge et salaire ne sont jamais un avantage à eux seuls")
	b.condition=90
	check(Comparison.leader("condition",[a,b])==-1,"Égalité : aucun écart mis en évidence")
	b.erase("condition")
	check(Comparison.leader("condition",[a,b])==-1,"Valeur inconnue : aucun écart mis en évidence")
	var x:=person("x","Talonneur",99,{"ratingRange":{"min":70,"max":78},"knowledge":{"owned":false,"stage":"observed"}})
	var y:=person("y","Talonneur",99,{"ratingRange":{"min":74,"max":82},"knowledge":{"owned":false,"stage":"observed"}})
	check(Comparison.leader("rating",[x,y])==-1,"Fourchettes qui se chevauchent : pas de vainqueur")
	y.ratingRange={"min":80,"max":86}
	check(Comparison.leader("rating",[x,y])==1,"Fourchettes disjointes : le mieux classé est désigné")
	print("COMPARATEUR JOUEURS : %d contrôles ; %d échecs" % [checks,failures])
	quit(0 if failures==0 else 1)
