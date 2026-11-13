# Retouches de teint du Gabi d'origine (gabi.glb), demandées le 12 novembre 2026 :
#   - peau moins saturée : la texture du corps (Material_0) donnait un orange-rouge uniforme (nez, joues) ; les tons
#     chair (teinte 0 à 40°) perdent SATURATION de leur saturation, un peu plus là où ils sont très saturés, et les
#     plus saturés (nez, joues) glissent légèrement vers le rose (TEINTE_ROSE degrés) : teint chaud, joues et nez
#     un peu plus rosés que le reste, sans orange uniforme. Chemise, jean, barbe : hors de ces teintes, inchangés ;
#   - paupières : leur couleur (matériau Gabi_Paupières) est remesurée sur la nouvelle peau autour des yeux et un
#     peu assombrie (PAUPIERE_OMBRE) : plus de liseré clair au-dessus des paupières supérieures ;
#   - dents : moins blanches (ivoire plus sombre), elles ressortaient trop pendant la parole ;
#   - Material_0 affiché des deux côtés : les faces intérieures entre les doigts (fentes noires) prennent la
#     couleur de la peau.
# Le Gabi Mixamo reprend ces matériaux et textures à l'export (exporter-gabi-mixamo.py, --origine).
# Usage : python3 retoucher-teint-gabi.py <gabi.glb> <sortie.glb>   (une seule fois par .glb)
import sys, io
import numpy as np
from PIL import Image
import pygltflib

SATURATION = 0.80
TEINTE_ROSE = 5.0
PAUPIERE_OMBRE = 0.90
DENTS = (0.24, 0.19, 0.15)


def lin(c): c = np.asarray(c, float) / 255; return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def main(src, dst):
    g = pygltflib.GLTF2().load(src); blob = bytearray(g.binary_blob())
    if (g.asset.extras or {}).get('teint_retouche'): sys.exit(f'{src} : teint déjà retouché')

    def image(ti):
        im = g.images[g.textures[ti].source]; bv = g.bufferViews[im.bufferView]
        return Image.open(io.BytesIO(bytes(blob[bv.byteOffset:bv.byteOffset + bv.byteLength]))).convert('RGB')

    def remplacer(ti, img):
        buf = io.BytesIO(); img.save(buf, 'PNG', optimize=True); data = buf.getvalue()
        while len(blob) % 4: blob.append(0)
        off = len(blob); blob.extend(data)
        g.bufferViews.append(pygltflib.BufferView(buffer=0, byteOffset=off, byteLength=len(data)))
        im = g.images[g.textures[ti].source]; im.bufferView = len(g.bufferViews) - 1; im.mimeType = 'image/png'

    mats = {m.name: m for m in g.materials}
    corps = mats['Material_0']; ti = corps.pbrMetallicRoughness.baseColorTexture.index
    hsv = np.asarray(image(ti).convert('HSV')).astype(float)
    h, s, v = hsv[..., 0] * 360 / 255, hsv[..., 1] / 255, hsv[..., 2] / 255
    # tons chair : teinte 0-40° (et 350-360°), pondération douce aux bords
    poids = np.where(h <= 40, 1.0, np.where(h < 50, (50 - h) / 10, np.where(h >= 350, (h - 345) / 5, 0.0)))
    poids = np.clip(poids, 0, 1) * np.clip((s - 0.12) / 0.15, 0, 1)
    s2 = s * (1 - poids * (1 - SATURATION) * (1 + 0.5 * np.clip((s - 0.5) / 0.4, 0, 1)))
    h2 = (h - poids * TEINTE_ROSE * np.clip((s - 0.45) / 0.35, 0, 1)) % 360
    nouv = np.stack([h2 * 255 / 360, s2 * 255, v * 255], -1).clip(0, 255).astype(np.uint8)
    peau = Image.fromarray(nouv, 'HSV').convert('RGB')
    remplacer(ti, peau)
    corps.doubleSided = True
    print('peau : saturation des tons chair ×', SATURATION, '; nez et joues glissés de', TEINTE_ROSE, '° vers le rose')

    # paupières : peau autour des yeux (sommets du visage autour des globes), en linéaire
    def lire(i, k):
        a = g.accessors[i]; bv = g.bufferViews[a.bufferView]
        return np.frombuffer(blob, np.float32, a.count * k, (bv.byteOffset or 0) + (a.byteOffset or 0)).reshape(-1, k)
    me = {m.name: m for m in g.meshes}
    pr = me['Mesh_0'].primitives[0]
    P = lire(pr.attributes.POSITION, 3); UV = lire(pr.attributes.TEXCOORD_0, 2) % 1.0
    A = np.asarray(peau)
    choix = np.zeros(len(P), bool)
    for oeil in ('Gabi_Oeil_D', 'Gabi_Oeil_G'):
        E = lire(me[oeil].primitives[0].attributes.POSITION, 3); c = (E.min(0) + E.max(0)) / 2
        d = P - c; r = np.linalg.norm(d[:, :2], axis=1)
        choix |= (r > 0.030) & (r < 0.045) & (d[:, 2] > 0) & (d[:, 1] > -0.02) & (d[:, 1] < 0.02)
    uv = UV[choix]
    moy = A[(uv[:, 1] * A.shape[0]).astype(int).clip(0, A.shape[0] - 1), (uv[:, 0] * A.shape[1]).astype(int).clip(0, A.shape[1] - 1)].mean(0)
    coul = lin(moy) * PAUPIERE_OMBRE
    mats['Gabi_Paupières'].pbrMetallicRoughness.baseColorFactor = [float(x) for x in coul] + [1.0]
    print('paupières : couleur', [round(float(x), 3) for x in coul], '(', choix.sum(), 'sommets de peau mesurés )')
    mats['M_Gabi_Dents_Ivoire'].pbrMetallicRoughness.baseColorFactor = list(DENTS) + [1.0]
    print('dents :', DENTS)
    g.asset.extras = dict(g.asset.extras or {}, teint_retouche=True)
    blob = compacter(g, blob)
    g.buffers[0].byteLength = len(blob); g.set_binary_blob(bytes(blob)); g.save(dst); print('ok', dst, len(blob), 'octets')


def compacter(g, blob):
    """Retire du tampon les vues que plus rien n'utilise (anciennes textures remplacées par ce script et par
    ajouter-sourire-gabi.py) : le .glb du dépôt garde sa taille."""
    refs = []
    for a in g.accessors:
        if a.bufferView is not None: refs.append((a, 'bufferView'))
        if a.sparse:
            refs.append((a.sparse.indices, 'bufferView')); refs.append((a.sparse.values, 'bufferView'))
    for im in g.images:
        if im.bufferView is not None: refs.append((im, 'bufferView'))
    utilises = sorted({getattr(o, k) for o, k in refs})
    neuf = bytearray(); vues = []; nouvel = {}
    for i in utilises:
        bv = g.bufferViews[i]
        while len(neuf) % 4: neuf.append(0)
        off = len(neuf); neuf.extend(blob[(bv.byteOffset or 0):(bv.byteOffset or 0) + bv.byteLength])
        bv.byteOffset = off; nouvel[i] = len(vues); vues.append(bv)
    for o, k in refs: setattr(o, k, nouvel[getattr(o, k)])
    g.bufferViews = vues
    print('tampon compacté :', len(blob), '->', len(neuf), 'octets')
    return neuf


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
