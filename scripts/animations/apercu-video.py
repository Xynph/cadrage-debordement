import bpy, sys, os, json, math
from mathutils import Vector
blend, outdir = sys.argv[sys.argv.index('--')+1:][:2]
seq = json.loads(sys.argv[sys.argv.index('--')+3])
bpy.ops.wm.open_mainfile(filepath=blend)
sc = bpy.context.scene
arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
for t in arm.animation_data.nla_tracks: t.mute = True
sc.render.engine = 'BLENDER_WORKBENCH'
sh = sc.display.shading; sh.light = 'STUDIO'; sh.color_type = 'TEXTURE'; sh.show_shadows = True; sh.shadow_intensity = 0.35; sh.show_cavity = True
sc.display.render_aa = '8'
sc.render.resolution_x = 960; sc.render.resolution_y = 540; sc.render.image_settings.file_format = 'JPEG'; sc.render.image_settings.quality = 92
sc.view_settings.view_transform = 'Standard'
w = bpy.data.worlds.new('w'); sc.world = w; w.color = (0.55, 0.68, 0.82)
bpy.ops.mesh.primitive_plane_add(size=400, location=(0, 0, 0)); g = bpy.context.object
m = bpy.data.materials.new('g'); m.diffuse_color = (0.16, 0.42, 0.17, 1); g.data.materials.append(m); sh.color_type = 'TEXTURE'
cam = bpy.data.cameras.new('c'); co = bpy.data.objects.new('c', cam); sc.collection.objects.link(co); sc.camera = co; cam.lens = 55
os.makedirs(outdir, exist_ok=True)
FPS_OUT = 24; n_out = 0; marks = []; focus = None
for name, loops in seq:
    a = bpy.data.actions[name]; arm.animation_data.action = a
    if getattr(arm.animation_data, 'action_slot', None) is None and getattr(a, 'slots', None): arm.animation_data.action_slot = a.slots[0]
    dur = a.frame_range[1] / 30.0; total = dur * loops
    start = n_out
    for j in range(int(round(total * FPS_OUT))):
        t = (j / FPS_OUT) % dur if loops > 1 else min(j / FPS_OUT, dur)
        fr = t * 30.0; sc.frame_set(int(fr), subframe=fr - int(fr))
        c = arm.matrix_world @ arm.pose.bones['Body'].head
        tgt = Vector((c.x, c.y, 2.3))
        focus = tgt if focus is None or j == 0 else focus.lerp(tgt, 0.12)
        co.location = focus + Vector((10.5, -12.5, 2.2))
        co.rotation_euler = (focus - co.location).to_track_quat('-Z', 'Y').to_euler()
        sc.render.filepath = os.path.join(outdir, f'{n_out:05d}.jpg')
        if not os.path.exists(sc.render.filepath): bpy.ops.render.render(write_still=True)
        n_out += 1
    marks.append((name, start, n_out - 1))
    print('fait', name, n_out, flush=True)
json.dump(marks, open(os.path.join(outdir, 'marques.json'), 'w'))
