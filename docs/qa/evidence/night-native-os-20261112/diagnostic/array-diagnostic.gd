extends SceneTree
func _initialize() -> void:
 var score: Variant = JSON.parse_string("[15,20]")
 print(JSON.stringify({"json_array":score,"literal_array":[15,20],"array_equality":score==[15,20],"first_type":typeof(score[0]),"literal_type":typeof(15),"element_equality":score[0]==15}))
 quit(0)
