extends SceneTree
## Invariants du vrai GLB skinné : aucune simulation ni sauvegarde chargée.
const Athlete = preload("res://match_athlete.gd")
var passed := 0
var failed := 0
func check(ok: bool, message: String) -> void:
 if ok: passed += 1
 else:
  failed += 1
  if failed <= 10: push_error(message)
func _initialize(): call_deferred("run")
func run():
 var template=load("res://assets/match3d/quaternius-rugby-athlete.glb")
 var original=template.instantiate()
 var candidate=template.instantiate()
 root.add_child(original)
 root.add_child(candidate)
 await process_frame
 var original_mesh:MeshInstance3D=original.find_children("*","MeshInstance3D",true,false)[0]
 var candidate_mesh:MeshInstance3D=candidate.find_children("*","MeshInstance3D",true,false)[0]
 var source:Mesh=original_mesh.mesh
 var immutable_positions:Array=[]
 var immutable_bones:Array=[]
 var immutable_weights:Array=[]
 for surface in source.get_surface_count():
  var arrays=source.surface_get_arrays(surface)
  immutable_positions.append(arrays[Mesh.ARRAY_VERTEX].duplicate())
  immutable_bones.append(arrays[Mesh.ARRAY_BONES].duplicate())
  immutable_weights.append(arrays[Mesh.ARRAY_WEIGHTS].duplicate())
 var started=Time.get_ticks_usec()
 Athlete.prepare(candidate)
 var build_us=Time.get_ticks_usec()-started
 Athlete.prepare(candidate)
 check(candidate_mesh.mesh.get_surface_count()==1,"Une seule surface attendue")
 var combined=candidate_mesh.mesh.surface_get_arrays(0)
 check(combined[Mesh.ARRAY_VERTEX].size()==3981,"Nombre de sommets identique")
 check(combined[Mesh.ARRAY_INDEX].size()==5562,"Nombre de triangles identique")
 var vertex_offset:=0
 var weight_offset:=0
 var index_offset:=0
 var max_leg_z_change:=0.0
 var max_morph:=0.0
 for surface in source.get_surface_count():
  var arrays=source.surface_get_arrays(surface)
  var positions:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
  check(arrays[Mesh.ARRAY_VERTEX]==immutable_positions[surface],"Position source inchangée")
  check(arrays[Mesh.ARRAY_BONES]==immutable_bones[surface],"Bones source inchangés")
  check(arrays[Mesh.ARRAY_WEIGHTS]==immutable_weights[surface],"Poids source inchangés")
  for i in positions.size():
   var p:Vector3=combined[Mesh.ARRAY_VERTEX][vertex_offset+i]
   var rest_uv:Vector2=combined[Mesh.ARRAY_TEX_UV][vertex_offset+i]
   var rest_uv2:Vector2=combined[Mesh.ARRAY_TEX_UV2][vertex_offset+i]
   var normal:Vector3=combined[Mesh.ARRAY_NORMAL][vertex_offset+i]
   check(p.is_finite() and normal.is_finite(),"Coordonnées et normales finies")
   check(absf(normal.length()-1.0)<0.002,"Normale unitaire")
   check(roundi(rest_uv2.y)==surface,"Région de repos conservée")
   check(absf(rest_uv.x-positions[i].z)<0.00000001,"Hauteur de repos encodée")
   if surface==3:
    max_leg_z_change=maxf(max_leg_z_change,absf(p.z-positions[i].z))
    check(is_equal_approx(p.z,positions[i].z),"Hauteur de jambe inchangée")
   if surface in [4,5,6,7,8]: check(p.is_equal_approx(positions[i]),"Chaussures/cheveux/yeux inchangés")
   max_morph=maxf(max_morph,p.distance_to(positions[i]))
  for i in arrays[Mesh.ARRAY_BONES].size():
   check(combined[Mesh.ARRAY_BONES][weight_offset+i]==arrays[Mesh.ARRAY_BONES][i],"Index de skinning identique")
   check(is_equal_approx(combined[Mesh.ARRAY_WEIGHTS][weight_offset+i],arrays[Mesh.ARRAY_WEIGHTS][i]),"Poids de skinning identique")
  for i in arrays[Mesh.ARRAY_INDEX].size(): check(combined[Mesh.ARRAY_INDEX][index_offset+i]==vertex_offset+arrays[Mesh.ARRAY_INDEX][i],"Topologie identique")
  vertex_offset+=positions.size()
  weight_offset+=arrays[Mesh.ARRAY_BONES].size()
  index_offset+=arrays[Mesh.ARRAY_INDEX].size()
 var rig_a:Skeleton3D=original_mesh.get_parent()
 var rig_b:Skeleton3D=candidate_mesh.get_parent()
 check(rig_a.get_bone_count()==31 and rig_b.get_bone_count()==31,"31bones conservés")
 for i in 31:
  check(rig_a.get_bone_rest(i)==rig_b.get_bone_rest(i),"Rest rig identique")
  check(rig_a.get_bone_name(i)==rig_b.get_bone_name(i),"Nom rig identique")
 var animation_a:AnimationPlayer=original.find_children("*","AnimationPlayer",true,false)[0]
 var animation_b:AnimationPlayer=candidate.find_children("*","AnimationPlayer",true,false)[0]
 check(animation_a.get_animation_list()==animation_b.get_animation_list(),"11clips conservés")
 for clip in animation_a.get_animation_list():
  animation_a.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
  animation_b.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
  animation_a.play(clip)
  animation_b.play(clip)
  animation_a.advance(0.13)
  animation_b.advance(0.13)
  for i in 31: check(rig_a.get_bone_global_pose(i).is_equal_approx(rig_b.get_bone_global_pose(i)),"Pose source identique "+str(clip))
 var kit={"shirt":Color("a12f41"),"detail":Color("d8a8a3"),"shorts":Color("202b35")}
 Athlete.dress(candidate,kit,"0-0")
 check(candidate_mesh.material_override is ShaderMaterial,"Matériau original appliqué")
 var looks:Dictionary={}
 var instances:Array=[]
 for i in 30:
  var other=template.instantiate()
  root.add_child(other)
  Athlete.prepare(other)
  Athlete.dress(other,kit,str(i))
  var mesh:MeshInstance3D=other.find_children("*","MeshInstance3D",true,false)[0]
  check(mesh.mesh==candidate_mesh.mesh,"Mesh partagé sur30acteurs")
  looks[str(Athlete.appearance(str(i)))]=true
  check(Athlete.appearance(str(i))==Athlete.appearance(str(i)),"Apparence stable sans RNG")
  instances.append(other)
 check(looks.size()>=12,"Variations sobres déterministes")
 var first_material:ShaderMaterial=candidate_mesh.material_override
 var alternate_kit=kit.duplicate()
 alternate_kit.shorts=Color("e5dfd1")
 Athlete.dress(candidate,alternate_kit,"0-0")
 var alternate_material:ShaderMaterial=candidate_mesh.material_override
 check(alternate_material!=first_material,"Le short fait partie de la clé de cache")
 check(alternate_material.get_shader_parameter("shorts_color")==Color("e5dfd1"),"Short extérieur effectivement appliqué")
 check(alternate_material.get_shader_parameter("jersey_color")==kit.shirt,"La variation de short conserve le jersey")
 check(alternate_material.get_shader_parameter("skin_color")==Athlete.appearance("0-0").skin,"Carnation appliquée au shader")
 check(alternate_material.get_shader_parameter("hair_color")==Athlete.appearance("0-0").hair,"Cheveux appliqués au shader")
 var before_palette_clear=alternate_material
 Athlete.clear_palette()
 Athlete.dress(candidate,alternate_kit,"0-0")
 check(candidate_mesh.material_override!=before_palette_clear,"Changement de palette libère son ancien cache")
 check((candidate_mesh.material_override as ShaderMaterial).get_shader_parameter("shorts_color")==Color("e5dfd1"),"Palette reconstruite sans ancienne couleur")
 print("MATCH_SILHOUETTES_CHECKS ",JSON.stringify({"passed":passed,"failed":failed,"build_us":build_us,"vertices":3981,"triangles":1854,"surfaces":1,"looks_over_30":looks.size(),"leg_height_change":max_leg_z_change,"max_section_displacement_source":max_morph,"renderer":DisplayServer.get_name()}))
 for instance in instances: instance.queue_free()
 original.queue_free()
 candidate.queue_free()
 await process_frame
 quit(1 if failed else 0)

