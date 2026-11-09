extends SceneTree
## Offline comparison: no import cache, gameplay scene or user profile is opened.
var errors: Array[String] = []
var worst := {"position_units":0.0,"rotation_rad":0.0,"scale":0.0}
var locations := {}
var comparisons := 0
var initial_transforms := {}
func remember(n: Node):
 if n is Node3D: initial_transforms[n] = n.transform
 for c in n.get_children(): remember(c)
func restore(n: Node):
 if n is Node3D: n.transform = initial_transforms[n]
 for c in n.get_children(): restore(c)
func rotation_error(a: Basis, b: Basis) -> float:
 var qa=a.orthonormalized().get_rotation_quaternion().normalized()
 var qb=b.orthonormalized().get_rotation_quaternion().normalized()
 var d=(qa.inverse()*qb).normalized()
 return 2.0*atan2(Vector3(d.x,d.y,d.z).length(),abs(d.w))
func locate(n: Node, kind: String) -> Node:
 if n.is_class(kind): return n
 for c in n.get_children():
  var found = locate(c, kind)
  if found != null: return found
 return null
func load_glb(path: String) -> Node:
 var doc := GLTFDocument.new()
 var state := GLTFState.new()
 var err := doc.append_from_file(path, state)
 if err != OK:
  errors.append("GLB read failed: %s (%s)" % [path, err]); return null
 var n := doc.generate_scene(state)
 if n == null: errors.append("No generated scene: " + path); return null
 root.add_child(n)
 remember(n)
 return n
func measure(a: Transform3D, b: Transform3D, label: String):
 var values := {"position_units":a.origin.distance_to(b.origin),"rotation_rad":rotation_error(a.basis,b.basis),"scale":0.0}
 values.scale = (a.basis.get_scale()-b.basis.get_scale()).abs()[(a.basis.get_scale()-b.basis.get_scale()).abs().max_axis_index()]
 for key in values:
  var value: float = values[key]
  if not is_finite(value): errors.append("Non-finite transform at " + label); continue
  if value > float(worst[key]): worst[key]=value; locations[key]=label
 comparisons += 1
func pose(player: AnimationPlayer, skeleton: Skeleton3D, clip: String, t: float):
 player.stop()
 skeleton.reset_bone_poses()
 restore(skeleton.get_parent())
 player.play(clip)
 player.seek(t, true)
 player.advance(0)
 skeleton.force_update_all_bone_transforms()
func _initialize():
 call_deferred("run")
func run():
 var args := OS.get_cmdline_user_args()
 if args.size()!=7:
  push_error("source candidate output samples position_units rotation_rad scale"); quit(2); return
 var samples := int(args[3])
 var limits := {"position_units":float(args[4]),"rotation_rad":float(args[5]),"scale":float(args[6])}
 if samples<2: errors.append("samples must be at least 2")
 var a = load_glb(args[0]); var b = load_glb(args[1])
 var sa: Skeleton3D; var sb: Skeleton3D; var pa: AnimationPlayer; var pb: AnimationPlayer
 var clips: Array = []; var bones: Array = []; var sampled := 0
 if a != null and b != null:
  sa=locate(a,"Skeleton3D"); sb=locate(b,"Skeleton3D"); pa=locate(a,"AnimationPlayer"); pb=locate(b,"AnimationPlayer")
  if sa==null or sb==null or pa==null or pb==null: errors.append("Skeleton or animation player missing")
  else:
   pa.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
   pb.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
   for i in sa.get_bone_count(): bones.append(sa.get_bone_name(i))
   var candidate_bones: Array=[]
   for i in sb.get_bone_count(): candidate_bones.append(sb.get_bone_name(i))
   if bones!=candidate_bones: errors.append("Bone names/order differ")
   clips=Array(pa.get_animation_list())
   if clips!=Array(pb.get_animation_list()): errors.append("Clip names/order differ")
   if clips.is_empty() or bones.is_empty(): errors.append("Empty clips/bones")
   for clip in clips:
    if not pb.has_animation(clip): continue
    var aa=pa.get_animation(clip); var ab=pb.get_animation(clip)
    if abs(aa.length-ab.length)>0.0001: errors.append("Duration differs: " + clip)
    if aa.loop_mode!=ab.loop_mode: errors.append("Loop mode differs: " + clip)
    for step in samples:
     var t: float=aa.length*float(step)/float(samples-1)
     a.free(); b.free()
     initial_transforms.clear()
     a=load_glb(args[0]); b=load_glb(args[1])
     sa=locate(a,"Skeleton3D"); sb=locate(b,"Skeleton3D"); pa=locate(a,"AnimationPlayer"); pb=locate(b,"AnimationPlayer")
     pa.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
     pb.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
     pose(pa,sa,clip,t); pose(pb,sb,clip,t)
     var label="%s@%.6f" % [clip,t]
     measure(a.global_transform,b.global_transform,label+":scene_root")
     measure(sa.global_transform,sb.global_transform,label+":skeleton_root")
     for i in sa.get_bone_count():
      var j=sb.find_bone(sa.get_bone_name(i))
      if j<0: continue
      measure(sa.get_bone_pose(i),sb.get_bone_pose(j),label+":"+sa.get_bone_name(i)+":local")
      measure(sa.global_transform*sa.get_bone_global_pose(i),sb.global_transform*sb.get_bone_global_pose(j),label+":"+sa.get_bone_name(i)+":world")
     sampled+=1
 for key in limits:
  if float(worst[key])>float(limits[key]): errors.append("%s exceeds threshold: %.9f > %.9f" % [key,worst[key],limits[key]])
 var report={"schema":1,"engine":Engine.get_version_info().string,"passed":errors.is_empty(),"errors":errors,"bones":bones.size(),"clips":clips.size(),"sampled_poses":sampled,"transform_comparisons":comparisons,"samples_per_clip":samples,"max_error":worst,"worst_location":locations,"thresholds":limits,"bounds":"not measured: static mesh AABB is not skinned bounds","root_motion":"bone world transforms compared; no gameplay displacement applied", "sampling":"fresh scene pair at every sample, manual animation evaluation; reset poses", "distance_units":"raw imported Godot units, not calibrated gameplay metres"}
 var f=FileAccess.open(args[2],FileAccess.WRITE)
 if f==null: push_error("Cannot write report"); quit(2); return
 f.store_string(JSON.stringify(report,"  ")); f.close()
 print(JSON.stringify(report))
 quit(0 if report.passed else 1)
