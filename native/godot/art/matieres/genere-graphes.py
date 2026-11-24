import json, sys, os
out = sys.argv[1]
def grad(a, b):
    return {"interpolation": 1, "type": "Gradient", "points": [
        {"a": 1, "r": a, "g": a, "b": a, "pos": 0}, {"a": 1, "r": b, "g": b, "b": b, "pos": 1}]}
def material(rough):
    return {"name": "Material", "type": "material", "node_position": {"x": 400, "y": 0}, "parameters": {
        "albedo_color": {"a": 1, "b": 1, "g": 1, "r": 1, "type": "Color"}, "ao_light_affect": 1, "depth_scale": 0.2,
        "emission_energy": 1, "metallic": 0, "normal_scale": 1, "resolution": 1, "roughness": rough, "size": 10,
        "subsurf_scatter_strength": 0}}
def nmap(name, amount):
    return {"name": name, "type": "normal_map2", "node_position": {"x": 200, "y": 200}, "seed": 0,
            "parameters": {"buffer": 1, "param2": 0, "size": 10, "strength": amount}}
def node(name, typ, params, x=0, y=0):
    return {"name": name, "type": typ, "node_position": {"x": x, "y": y}, "parameters": params}
def c(a, ap, b, bp): return {"from": a, "from_port": ap, "to": b, "to_port": bp}
def graph(nodes, conns):
    return {"label": "Graph", "name": "g", "node_position": {"x": 0, "y": 0}, "nodes": nodes, "connections": conns, "parameters": {}, "type": "graph"}

# Pelouse : brins (bruit anisotrope fin) + touffes (fbm) ; hauteur exportée dans l'albedo,
# la normal map est calculée ensuite par Godot (le noeud Normal Map plante l'export en ligne de commande).
pelouse = graph([
    material(1),
    node("brins", "noise_anisotropic", {"scale_x": 48, "scale_y": 384, "smoothness": 1, "interpolation": 1}),
    node("touffes", "fbm2", {"noise": 2, "scale_x": 12, "scale_y": 12, "folds": 0, "iterations": 4, "persistence": 0.55, "offset": 0}),
    node("melange", "blend", {"amount": 0.45, "blend_type": 0}),
    node("hauteur", "colorize", {"gradient": grad(0.0, 1.0)}),
], [c("brins", 0, "melange", 0), c("touffes", 0, "melange", 1), c("melange", 0, "hauteur", 0), c("hauteur", 0, "Material", 0)])

# Tissu : maille serrée (weave2) + léger grain fbm ; hauteur exportée dans l'albedo.
tissu = graph([
    material(1),
    node("maille", "weave2", {"columns": 32, "rows": 32, "width_x": 0.85, "width_y": 0.85, "stitch": 1}),
    node("grain", "fbm2", {"noise": 2, "scale_x": 64, "scale_y": 64, "folds": 0, "iterations": 3, "persistence": 0.5, "offset": 0}),
    node("melange", "blend", {"amount": 0.85, "blend_type": 0}),
    node("hauteur", "colorize", {"gradient": grad(0.0, 1.0)}),
], [c("maille", 0, "melange", 0), c("grain", 0, "melange", 1), c("melange", 0, "hauteur", 0), c("hauteur", 0, "Material", 0)])

for name, g in [("pelouse", pelouse), ("tissu", tissu)]:
    with open(os.path.join(out, name + ".ptex"), "w", encoding="utf8") as f:
        json.dump(g, f, indent="\t")
print("ok")
