extends SceneTree
## Offline comparison: no import cache, gameplay scene or user profile is opened.
var errors: Array[String] = []
var worst := {"position_units":0.0,"rotation_rad":0.0,"scale":0.0}
var locations := {}
var comparisons := 0
var per_clip := {}
var active_clip := ""
var active_time := 0.0
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
  if not is_finite(value):
   errors.append("Non-finite transform at " + label)
   if not active_clip.is_empty(): per_clip[active_clip].errors.append("Non-finite transform at " + label)
   continue
  if value > float(worst[key]): worst[key]=value; locations[key]=label
  if not active_clip.is_empty() and value > float(per_clip[active_clip].max_error[key]):
   per_clip[active_clip].max_error[key] = value
   per_clip[active_clip].worst_location[key] = {"label":label,"time_seconds":active_time}
   per_clip[active_clip].worst_location[key]["bone_or_root"] = label.split(":")[1]
   per_clip[active_clip].worst_location[key]["space"] = label.split(":")[-1]
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
 if args.size() not in [7,8]:
  push_error("source candidate output samples position_units rotation_rad scale [clips_json]"); quit(2); return
 var samples := int(args[3])
 var limits := {"position_units":float(args[4]),"rotation_rad":float(args[5]),"scale":float(args[6])}
 if samples<2: errors.append("samples must be at least 2")
 var a = load_glb(args[0]); var b = load_glb(args[1])
 var sa: Skeleton3D; var sb: Skeleton3D; var pa: AnimationPlayer; var pb: AnimationPlayer
 var clips: Array = []; var bones: Array = []; var sampled := 0
 var available_clips: Array = []
 var selected: Array = JSON.parse_string(args[7]) if args.size()==8 else []
 var partial := not selected.is_empty()
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
   available_clips=Array(pa.get_animation_list())
   clips = available_clips if selected.is_empty() else selected
   if available_clips!=Array(pb.get_animation_list()): errors.append("Clip names/order differ")
   for requested in clips:
    if not pa.has_animation(requested) or not pb.has_animation(requested): errors.append("Requested clip missing in source or candidate: " + str(requested))
   if clips.is_empty() or bones.is_empty(): errors.append("Empty clips/bones")
   # Cheap structural metadata remains global even when pose sampling is partial.
   for manifest_clip in available_clips:
    if not pb.has_animation(manifest_clip): continue
    var ma := pa.get_animation(manifest_clip)
    var mb := pb.get_animation(manifest_clip)
    if absf(ma.length-mb.length)>0.0001: errors.append("Duration differs: " + str(manifest_clip))
    if ma.loop_mode!=mb.loop_mode: errors.append("Loop mode differs: " + str(manifest_clip))
   for clip in clips:
    if not pa.has_animation(clip) or not pb.has_animation(clip): continue
    var aa=pa.get_animation(clip); var ab=pb.get_animation(clip)
    active_clip = clip
    per_clip[clip] = {"duration_source_seconds":aa.length,"duration_candidate_seconds":ab.length,"loop_source":aa.loop_mode,"loop_candidate":ab.loop_mode,"max_error":{"position_units":0.0,"rotation_rad":0.0,"scale":0.0},"worst_location":{},"sampled_poses":0,"errors":errors.duplicate(),"feet":{}}
    for side in ["L","R"]:
     per_clip[clip].feet[side] = {"source":[],"candidate":[]}
    var times: Array[float] = []
    for step in samples: times.append(aa.length*float(step)/float(samples-1))
    if aa.length > 0.0001: times.insert(times.size()-1, aa.length-0.0001)
    per_clip[clip].sample_times_seconds = times
    for t: float in times:
     active_time = t
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
     for side in ["L","R"]:
      for item in [[sa,"source"],[sb,"candidate"]]:
       var skeleton: Skeleton3D = item[0]
       var index := skeleton.find_bone("Foot." + side)
       if index>=0:
        var foot: Vector3 = (skeleton.global_transform*skeleton.get_bone_global_pose(index)).origin
        per_clip[clip].feet[side][item[1]].append(foot)
     sampled+=1
     per_clip[clip].sampled_poses += 1
    for side in ["L","R"]:
     for key in ["source","candidate"]:
      var positions: Array = per_clip[clip].feet[side][key]
      var travel := 0.0
      var max_step := 0.0
      for i in range(1,positions.size()):
       var step_distance: float = positions[i].distance_to(positions[i-1])
       travel += step_distance
       max_step = maxf(max_step,step_distance)
      per_clip[clip].feet[side][key] = {"samples":positions.size(),"sampled_path_length_units":travel,"max_sample_step_units":max_step,"endpoint_gap_units":positions[0].distance_to(positions[-1]) if positions.size()>1 else 0.0,"pre_end_gap_units":positions[0].distance_to(positions[-2]) if positions.size()>2 else 0.0}
    per_clip[clip].within_pose_thresholds = true
    for key in limits:
     if float(per_clip[clip].max_error[key]) > float(limits[key]): per_clip[clip].within_pose_thresholds = false
    per_clip[clip].passed = per_clip[clip].errors.is_empty() and per_clip[clip].within_pose_thresholds and absf(aa.length-ab.length)<=0.0001 and aa.loop_mode==ab.loop_mode
 for key in limits:
  if float(worst[key])>float(limits[key]): errors.append("%s exceeds threshold: %.9f > %.9f" % [key,worst[key],limits[key]])
 var report={"schema":1,"engine":Engine.get_version_info().string,"passed":errors.is_empty(),"errors":errors,"bones":bones.size(),"clips":clips.size(),"available_clips":available_clips,"selected_clips":clips,"validation_scope":"selected clips only; not global asset acceptance" if partial else "all available clips; sampled poses only","complete_clip_coverage":not partial,"global_manifest_checks":"bone names/order, clip names/order, all durations and loop modes","per_clip":per_clip,"sampled_poses":sampled,"transform_comparisons":comparisons,"samples_per_clip":samples,"additional_end_sample":"duration minus 0.0001 seconds, then exact endpoint (may wrap)","max_error":worst,"worst_location":locations,"thresholds":limits,"bounds":"not measured: static mesh AABB is not skinned bounds","root_motion":"bone world transforms compared; no gameplay displacement applied", "sampling":"fresh scene pair at every sample, manual animation evaluation; reset poses", "distance_units":"raw imported Godot units, not calibrated gameplay metres"}
 var f=FileAccess.open(args[2],FileAccess.WRITE)
 if f==null: push_error("Cannot write report"); quit(2); return
 f.store_string(JSON.stringify(report,"  ")); f.close()
 print(JSON.stringify(report))
 quit(0 if report.passed else 1)
