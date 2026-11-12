# Fabrique « bras_croises » : la respiration de « repos » pour le corps, bras croisés posés par cinématique inverse puis cuits.
import bpy, sys
from mathutils import Vector
bpy.ops.wm.open_mainfile(filepath='' + sys.argv[sys.argv.index('--')+1] + '')
sc = bpy.context.scene; arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
for t in arm.animation_data.nla_tracks: t.mute = True
base = bpy.data.actions['repos']; act = base.copy(); act.name = 'bras_croises'
arm.animation_data.action = act; arm.animation_data.action_slot = act.slots[0]
n = int(act.frame_range[1]); sc.frame_set(0)
W = arm.matrix_world
def P(b): return W @ arm.pose.bones['mixamorig:' + b].head
chest = (P('Spine2') + P('Neck')) * 0.5
fwd = Vector((0, -1, 0))  # Gabi regarde vers -Y
cibles = {}
# main droite posée sur le haut du bras gauche, main gauche glissée sous le coude droit
cibles['Right'] = Vector((P('LeftArm').x * 0.75, -0.30, chest.z - 0.08))
cibles['Left'] = Vector((P('RightArm').x * 0.7, -0.40, chest.z - 0.17))
poles = {'Right': chest + Vector((-0.5, -0.6, -0.3)), 'Left': chest + Vector((0.45, -1.0, -0.25))}
objs = []
for cote in ('Right', 'Left'):
    e = bpy.data.objects.new('cible_' + cote, None); e.location = cibles[cote]; sc.collection.objects.link(e)
    p = bpy.data.objects.new('pole_' + cote, None); p.location = poles[cote]; sc.collection.objects.link(p)
    c = arm.pose.bones['mixamorig:%sForeArm' % cote].constraints.new('IK')
    c.target = e; c.pole_target = p; c.chain_count = 2; c.pole_angle = 0
    objs += [e, p]
# mains rabattues vers le bras opposé (doigts glissés sous le biceps)
for cote, autre in (('Right', 'Left'), ('Left', 'Right')):
    v = bpy.data.objects.new('vise_' + cote, None); v.location = Vector((P(autre + 'Arm').x * 1.25, -0.02, chest.z - 0.12)); sc.collection.objects.link(v)
    d = arm.pose.bones['mixamorig:%sHand' % cote].constraints.new('DAMPED_TRACK'); d.target = v; d.influence = 0.85
    objs.append(v)
bpy.context.view_layer.objects.active = arm; arm.select_set(True)
bpy.ops.object.mode_set(mode='POSE')
bpy.ops.pose.select_all(action='DESELECT')
for cote in ('Right', 'Left'):
    for b in ('Arm', 'ForeArm', 'Hand'):
        pb = arm.pose.bones['mixamorig:%s%s' % (cote, b)]
        try: pb.select = True
        except AttributeError: pb.bone.select = True
bpy.ops.nla.bake(frame_start=0, frame_end=n, only_selected=True, visual_keying=True, clear_constraints=True, use_current_action=True, bake_types={'POSE'})
bpy.ops.object.mode_set(mode='OBJECT')
for o in objs: bpy.data.objects.remove(o, do_unlink=True)
act.use_fake_user = True
tr = arm.animation_data.nla_tracks.new(); tr.name = 'bras_croises'; tr.strips.new('bras_croises', 0, act).name = 'bras_croises'
arm.animation_data.action = None
bpy.ops.wm.save_mainfile()
print('ok bras_croises', n)
