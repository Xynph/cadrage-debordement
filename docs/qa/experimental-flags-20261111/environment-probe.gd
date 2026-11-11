extends SceneTree
var bridge
var stage := 0
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 var view = load("res://match_view.gd").new()
 root.add_child(view)
 await process_frame
 var gestes = view._gestes != null
 print("ENV_GESTES ", JSON.stringify({"environment": OS.get_environment("CD_MATCH_GESTES"), "active": gestes}))
 view.queue_free()
 ProjectSettings.set_setting("native_engine/worker_path", "/workspace/tmp/flags-review/552-73/native/engine/worker.cjs")
 bridge = load("res://engine_bridge.gd").new()
 root.add_child(bridge)
 bridge.model_changed.connect(changed)
 bridge.command_failed.connect(failed)
 bridge.start(OS.get_environment("CD_ENV_PROBE_PROFILE"))
 get_tree_timeout()
func get_tree_timeout() -> void:
 await create_timer(180).timeout
 failed("environment probe timeout")
func changed(model: Dictionary) -> void:
 if stage == 0:
  stage = 1
  bridge.send("new_career", {"mode":"common","club":29})
 elif stage == 1:
  stage = 2
  bridge.send("export")
 elif stage == 2:
  var save = JSON.parse_string(model.meta.exportText)
  print("ENV_WORKER ", JSON.stringify({"environment":OS.get_environment("CD_SALAIRES_PAR_NIVEAU"), "marker":save.state.get("startingSalaries"),"salaryFloor":model.finance.get("salaryFloor"), "workerPid": bridge.child_pid}))
  stage = 3
  bridge.queue_free()
  await process_frame
  bridge = load("res://engine_bridge.gd").new()
  root.add_child(bridge)
  bridge.model_changed.connect(changed)
  bridge.command_failed.connect(failed)
  bridge.start(OS.get_environment("CD_ENV_PROBE_PROFILE"))
 elif stage == 3:
  print("ENV_RESUME ",JSON.stringify({"environment":OS.get_environment("CD_SALAIRES_PAR_NIVEAU"),"salaryFloor":model.finance.get("salaryFloor"),"budget":model.clubLife.clubStrategy.finance.get("budget"),"forecast":model.clubLife.clubStrategy.finance.get("baseForecast")}))
  quit(0)
func failed(message: String) -> void:
 printerr(message)
 quit(1)
