import bpy, sys, math, os
from mathutils import Vector
blend, outdir = sys.argv[sys.argv.index('--')+1:][:2]
clips = [c for c in sys.argv[sys.argv.index('--')+3:] if not c.startswith('--')]
bpy.ops.wm.open_mainfile(filepath=blend)
sc = bpy.context.scene
arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
for t in arm.animation_data.nla_tracks: t.mute = True
sc.render.engine = 'CYCLES'; sc.cycles.samples = 10; sc.cycles.device = 'CPU'; sc.cycles.use_denoising = False
sc.render.resolution_x = 360; sc.render.resolution_y = 420
sc.view_settings.view_transform = 'Standard'
w = bpy.data.worlds.new('w'); sc.world = w; w.use_nodes = True; w.node_tree.nodes['Background'].inputs[1].default_value = 1.0
sun = bpy.data.objects.new('s', bpy.data.lights.new('s', 'SUN')); sun.data.energy = 3; sun.rotation_euler = (0.8, 0.2, 0.6); sc.collection.objects.link(sun)
bpy.ops.mesh.primitive_plane_add(size=60, location=(0, 0, 0))
cam = bpy.data.cameras.new('c'); co = bpy.data.objects.new('c', cam); sc.collection.objects.link(co); sc.camera = co
cam.type = 'ORTHO'; cam.ortho_scale = 7.5
def look(frm, to):
    d = Vector(to) - Vector(frm); co.location = frm; co.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler()
os.makedirs(outdir, exist_ok=True)
slot_ok = True
for name in clips:
    a = bpy.data.actions[name]
    arm.animation_data.action = a
    try:
        if hasattr(arm.animation_data, 'action_slot') and arm.animation_data.action_slot is None and a.slots: arm.animation_data.action_slot = a.slots[0]
    except Exception as e: print('slot', e)
    n = int(a.frame_range[1])
    lows = []
    for f in range(0, n+1):
        sc.frame_set(f)
        lows.append(min((arm.matrix_world @ arm.pose.bones[b].head).z for b in ('Foot.L', 'Foot.R')))
    print(name, 'pied le plus bas : min %.2f max %.2f (repos 0.05) ; bassin z %.2f' % (min(lows), max(lows), (arm.matrix_world @ arm.pose.bones['Body'].head).z), flush=True)
    if '--mesure' in sys.argv: continue
    for i in range(6):
        f = round(i*n/5) if name != 'mx_repos' else round(i*n/5)
        sc.frame_set(f)
        c = arm.matrix_world @ arm.pose.bones['Body'].head
        look((c.x+9, c.y-9, 4.5), (c.x, c.y, 2.2))
        sc.render.filepath = os.path.join(outdir, f'{name}-{i}.png'); bpy.ops.render.render(write_still=True)
