# Ajoute à Gabi une forme « Sourire » (bouche) : commissures qui remontent et partent un peu en arrière, joues
# qui montent, lèvre supérieure à peine relevée, légère asymétrie (côté gauche de Gabi un peu plus haut). Demande de
# Léo, 12 novembre 2026 : « retravaille sa bouche ». Avant, le sourire n'utilisait que MouthWide/MouthPress
# (3 mm au plus, commissures presque immobiles) : la bouche restait une fente figée.
# Forme posée sur Mesh_0 (visage, lèvres et cavité : un seul champ de déplacement, ils restent collés), après les
# formes existantes ; le jeu la cherche par son nom (guide/gabi_visage.gd).
#
# Usage :
#   python3 ajouter-sourire-gabi.py <gabi.glb> <sortie.glb>     (refuse un .glb qui a déjà « Sourire »)
#   python3 ajouter-sourire-gabi.py <gabi.blend>                (le .blend est modifié ; la forme est remplacée)
# Le script donne aussi du volume aux lèvres au repos (une seule fois : propriété « volume_levres » sur Mesh_0 dans le
# .blend) et, dans le .glb, une teinte plus soutenue au matériau des lèvres (le Gabi Mixamo reprend les matériaux du
# .glb d'origine à l'export).
# Repère de calcul : glTF (mètres, Y en haut, Gabi regarde vers +Z ; son côté gauche est +X).
import sys, os
import numpy as np

FORME = 'Sourire'
# Commissures mesurées sur le modèle (bord des lèvres) : x = ±0,066 m, y = 1,470 m, z = 0,14 m.
COIN_X, COIN_Y = 0.066, 1.470
MONTEE, RECUL, ECART = 0.0088, 0.0032, 0.0028     # déplacement des commissures (m)
ASYMETRIE = 0.12                                   # côté gauche (+X) 12 % plus haut, côté droit 12 % moins


def ss(a, b, x):
    t = np.clip((np.asarray(x, dtype=np.float64) - a) / (b - a), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def gauss(x, s):
    return np.exp(-0.5 * (x / s) ** 2)


def champ(P):
    x, y, z = P[:, 0], P[:, 1], P[:, 2]
    ax = np.abs(x); sx = np.sign(x) + (x == 0)
    avant = ss(0.05, 0.10, z)
    asym = 1.0 + ASYMETRIE * sx
    D = np.zeros_like(P)
    # bouche : 0 au milieu, 1 aux commissures, s'éteint 2 cm au-delà ; hauteur : autour de la ligne des lèvres,
    # plus vite vers le menton que vers la moustache (qui suit un peu les commissures)
    lat = np.where(ax <= COIN_X, ss(0.004, COIN_X, ax) ** 1.3, gauss(ax - COIN_X, 0.022))
    dy = y - COIN_Y
    haut = np.where(dy >= 0, gauss(dy, 0.024), gauss(dy, 0.014))
    w = lat * haut * avant * asym
    D[:, 1] += MONTEE * w
    D[:, 2] -= RECUL * w
    D[:, 0] += sx * ECART * w
    # joues : remontent et avancent (au-dessus et en dehors des commissures)
    j = gauss(ax - 0.074, 0.022) * gauss(y - 1.505, 0.020) * avant * asym
    D[:, 1] += 0.0048 * j; D[:, 2] += 0.0030 * j
    # lèvre supérieure à peine relevée au centre (le sourire découvre un peu la lèvre)
    sup = (1 - ss(0.03, 0.055, ax)) * gauss(y - 1.474, 0.006) * avant
    D[:, 1] += 0.0006 * sup
    # la lèvre supérieure s'étire et s'amincit : son bord haut descend un peu vers la fente
    _, frac = position_levre(P)
    mince = (1 - ss(0.02, 0.05, ax)) * ss(0.3, 0.9, frac) * (1 - ss(1.0, 1.5, frac)) * (y > COIN_Y - 0.003) * avant
    D[:, 1] -= 0.0012 * mince
    return D


# Lèvres au repos. Avant, les lèvres étaient une bande plate, uniformément rose pâle, posée sur le visage (coque
# séparée, contour en dents de scie), la supérieure presque cachée sous la moustache (Léo : « on dirait qu'il
# n'en a pas »). Les lèvres sont redessinées dans leur texture (projection de face : u suit x, v suit y) et
# bombées dans la géométrie, d'après un même contour lisse (contour_levres) :
#   - fente y_f(x), bord de la lèvre supérieure y_f + h_sup(x) (arc de Cupidon), bord inférieur y_f - h_inf(x) ;
#   - texture : rose soutenu, plus foncé près de la fente, liseré clair au bord de la lèvre supérieure (bord
#     vermillon) ; hors du contour, la couleur de la peau voisine : les dents de scie de la coque disparaissent ;
#   - géométrie : chaque lèvre avance en arrondi (VOLUME_*), au plus au milieu de sa hauteur, rien au bord, et
#     s'étire en hauteur depuis la fente (ETIRE ; la peau au-delà du bord se resserre).
# Même champ pour le visage, les lèvres et la cavité : rien ne se décolle.
# Versions des lèvres : v3 (12 novembre, validée en couleur et en sourire), v4 (Léo, 12 novembre après-midi :
# « rends ses lèvres un peu plus en volume et un peu plus épaisses ») : supérieure 22 % plus haute, inférieure 28 %,
# avancée 4,6 et 5,8 mm au lieu de 3,4 et 3,8, étirement 2,2 mm au lieu de 1,5. Le .blend garde la version appliquée
# (propriété « volume_levres ») : on n'y ajoute que la différence.
VERSIONS = {
    3: dict(sup=1.00, inf=1.00, volume_sup=0.0034, volume_inf=0.0038, etire=0.0015),
    4: dict(sup=1.22, inf=1.28, volume_sup=0.0046, volume_inf=0.0058, etire=0.0022, portee_inf=1.3),
}
VERSION = 4
COIN = 0.066
LEVRE_COEUR = (104, 44, 48)       # sRGB près de la fente
LEVRE = (150, 76, 76)             # sRGB, milieu des lèvres : rose chaud un peu terne (vers rose-brun), proche de la peau
REFLET = 22                       # éclaircissement au plus fort du reflet de la lèvre inférieure (sRGB)
CAVITE = ((92, 30, 30), (52, 16, 18))   # intérieur de la bouche : rouge sombre, plus sombre au fond
LEVRES_RUGOSITE = 0.6
# La coque des lèvres, plus en avant que la peau, reçoit plus de lumière : sa partie hors contour est assombrie
# d'autant pour se fondre dans le visage.
PEAU_COQUE = 0.965
OMBRE_MOUSTACHE = 0.42           # assombrissement de la coque sous la moustache (au-delà du bord de la lèvre supérieure)


def contour_levres(x, version=VERSION):
    """Fente, hauteur de la lèvre supérieure et de la lèvre inférieure (m) en fonction de x (repère glTF, avant
    toute déformation)."""
    V = VERSIONS[version]
    t = np.clip(np.abs(x) / COIN, 0, 1)
    fente = 1.4685 + 0.0045 * t ** 2
    # supérieure : épaisse au centre, effilée vers les commissures ; creux du philtrum au milieu, arc de Cupidon
    h_sup = 0.0128 * (1 - t ** 1.25) ** 1.1 - 0.0019 * gauss(x, 0.0050) + 0.0011 * gauss(np.abs(x) - 0.0115, 0.0050)
    # inférieure : charnue au centre
    h_inf = 0.0160 * (1 - t ** 2.2) ** 1.2
    return fente, V['sup'] * np.maximum(h_sup, 0), V['inf'] * np.maximum(h_inf, 0)


def position_levre(P, version=VERSION):
    """Pour chaque point : côté (+1 lèvre supérieure, -1 inférieure) et fraction de hauteur (0 à la fente,
    1 au bord, > 1 au-delà)."""
    fente, hs, hi = contour_levres(P[:, 0], version)
    h = P[:, 1] - fente
    cote = np.where(h >= 0, 1.0, -1.0)
    frac = np.where(h >= 0, h / np.maximum(hs, 1e-4), -h / np.maximum(hi, 1e-4))
    return cote, frac


def volume(P, version=VERSION):
    V = VERSIONS[version]
    z = P[:, 2]; avant = ss(0.09, 0.125, z)
    cote, frac = position_levre(P, version)
    # lèvre inférieure (v4) : l'avancée s'éteint plus bas que le bord peint, sur le premier rang de la barbe. Le bord
    # de la coque descend de 11,5 à 21 mm sous la fente : avec une avancée qui s'éteint au bord peint, ses sommets
    # avançaient inégalement (pointe en V au bas de la lèvre).
    frac = np.where(cote < 0, frac / V.get('portee_inf', 1.0), frac)
    bombe = np.sin(np.pi * np.clip(frac, 0, 1)) ** 0.8 * (1 - ss(0.80, 1.0, np.abs(P[:, 0]) / COIN))
    D = np.zeros_like(P)
    D[:, 2] += np.where(cote > 0, V['volume_sup'], V['volume_inf']) * bombe * avant
    etire = V['etire'] * np.clip(frac, 0, 1) * (1 - ss(1.0, 1.8, frac)) * (1 - ss(0.85, 1.05, np.abs(P[:, 0]) / COIN))
    D[:, 1] += cote * etire * avant
    return D


def peindre_levres(u2x, v2y, taille, peau):
    """Texture des lèvres (sRGB, uint8). u2x, v2y : coefficients (a, b) tels que x = a u + b, y = a v + b.
    peau : couleur (3,) ou fonction (X, Y) -> couleurs (h, w, 3) de la peau du visage sous chaque texel."""
    W, H = taille
    u = (np.arange(W) + 0.5) / W; v = (np.arange(H) + 0.5) / H
    U, V = np.meshgrid(u, v)
    X = u2x[0] * U + u2x[1]; Y = v2y[0] * V + v2y[1]
    fond = peau(X, Y) if callable(peau) else np.array(peau, dtype=np.float64)[None, None, :] * np.ones(X.shape + (1,))
    out = teinte_levres(X, Y, fond)
    # au-dessus de la lèvre supérieure, la coque passe sous la moustache : la peau y est dans l'ombre (sur les côtés,
    # le visage y est rendu vers 105/75/70). Sans cela, bande claire polygonale entre la moustache et la lèvre (v4).
    P = np.stack([X.ravel(), Y.ravel(), np.zeros(X.size)], 1)
    cote, frac = position_levre(P); cote = cote.reshape(X.shape); frac = frac.reshape(X.shape)
    ombre = OMBRE_MOUSTACHE * ss(1.0, 1.35, frac) * (cote > 0) * (1 - ss(0.65, 0.9, np.abs(X) / COIN))   # pas aux coins
    out = out * (1 - ombre)[..., None]
    return np.clip(out, 0, 255).astype(np.uint8)


def teinte_levres(X, Y, fond):
    """Couleur (sRGB, réels) des lèvres aux points (X, Y) du contour (repère glTF), fondue dans fond (couleur de la
    peau sous chaque point, même forme que X + (3,)). Sert à la coque des lèvres et, depuis la v4, à la texture de
    la tête autour de la coque (nettete-tete-gabi.py) : les lèvres ne s'arrêtent plus au bord de la coque.
    Modelé peint : plus sombre près de la fente, lèvre supérieure (tournée vers le bas) un peu plus sombre que
    l'inférieure, reflet doux sur la lèvre inférieure seulement, bord fondu dans la peau (pas de trait), bas de la
    lèvre inférieure un peu ombré et petit creux d'ombre aux commissures."""
    X = np.asarray(X, dtype=np.float64); Y = np.asarray(Y, dtype=np.float64)
    P = np.stack([X.ravel(), Y.ravel(), np.zeros(X.size)], 1)
    cote, frac = position_levre(P); cote = cote.reshape(X.shape); frac = frac.reshape(X.shape)
    lateral = np.abs(X) / COIN
    dedans = (1 - ss(0.72, 1.06, frac)) * (1 - ss(0.86, 1.0, lateral))
    c = lambda t: np.array(t, dtype=np.float64)
    coul = c(LEVRE)[None, :] + (c(LEVRE_COEUR) - c(LEVRE))[None, :] * (1 - ss(0.0, 0.55, frac))[..., None]
    coul = coul * np.where(cote > 0, 0.92, 1.0)[..., None]
    reflet = REFLET * gauss(frac - 0.42, 0.16) * gauss(X / COIN, 0.35) * (cote < 0)
    coul = coul + reflet[..., None]
    out = fond + (coul - fond) * dedans[..., None]
    # ombres douces, à l'intérieur du contour : bas de la lèvre inférieure, et un creux à chaque commissure
    sous = ss(0.70, 0.95, frac) * (1 - ss(0.95, 1.05, frac)) * (cote < 0) * (1 - ss(0.5, 0.95, lateral))
    coin = gauss(np.hypot((lateral - 0.97) * COIN, (Y - contour_levres(X)[0])), 0.0035)
    return out * (1 - 0.10 * sous - 0.30 * coin)[..., None]


# Lèvre inférieure dans la forme MouthOpen d'origine : un sommet du bord de la coque (x ≈ +1 cm, 11,5 mm sous la
# fente, là où le contour de la coque remonte en dent de scie) ne descend que de 8,3 mm quand ses voisins descendent
# de 11 à 13 mm : la lèvre se pince et casse en parole. On lisse le déplacement de MouthOpen sur la lèvre
# inférieure et le haut du menton (moyenne gaussienne, surtout le long de la lèvre), sans toucher la fente ni la
# lèvre supérieure. Fonction des seules positions : le visage et la coque, qui partagent leurs sommets de bord,
# restent collés.
def lisser_ouverture(P, D):
    """P : positions au repos (glTF), D : déplacements de MouthOpen. Renvoie D lissé sur la lèvre inférieure."""
    from scipy.spatial import cKDTree
    fente = contour_levres(P[:, 0], 3)[0]; rel = P[:, 1] - fente
    devant = P[:, 2] > 0.12
    voisins = np.where(devant & (rel < -0.0025) & (rel > -0.032) & (np.abs(P[:, 0]) < 0.07))[0]
    w = (1 - ss(-0.0065, -0.0045, rel)) * ss(-0.028, -0.021, rel) * (1 - ss(0.050, 0.060, np.abs(P[:, 0]))) * devant
    zone = np.where(w > 0)[0]
    if not len(zone) or not len(voisins): return D
    # régression linéaire locale pondérée (gaussienne 12 mm le long de la lèvre, 4 mm en hauteur) : garde la
    # pente naturelle (la lèvre descend plus près de la fente qu'au menton) ; chaque sommet est estimé d'après les
    # colonnes de sommets voisines : la colonne qui traîne est effacée
    S = np.array([1 / 0.012, 1 / 0.004])
    arbre = cKDTree(P[voisins][:, :2] * S)
    out = D.copy()
    for i in zone:
        q = voisins[arbre.query_ball_point(P[i, :2] * S, 3.0)]
        d = (P[q, :2] - P[i, :2]) * S; a = np.exp(-0.5 * (d ** 2).sum(1))
        a = a * (np.abs(P[q, 0] - P[i, 0]) > 0.004)       # estimé d'après les colonnes voisines, pas la sienne
        A = np.column_stack([np.ones(len(q)), d]) * np.sqrt(a)[:, None]
        coef = np.linalg.lstsq(A, D[q] * np.sqrt(a)[:, None], rcond=None)[0]
        out[i] = D[i] + (coef[0] - D[i]) * w[i]
    return out


def normales(P, F):
    n = np.zeros_like(P)
    fn = np.cross(P[F[:, 1]] - P[F[:, 0]], P[F[:, 2]] - P[F[:, 0]])
    for k in range(3): np.add.at(n, F[:, k], fn)
    return n / np.maximum(np.linalg.norm(n, axis=1), 1e-12)[:, None]


def peindre_texture(g, blob, me, lire, ecrire):
    """Remplace la texture du matériau des lèvres par une texture peinte (peindre_levres) ; couleur du matériau
    ramenée au blanc (la teinte est dans la texture)."""
    import io
    from PIL import Image
    mat_i = next(i for i, m in enumerate(g.materials) if m.name == 'M_Gabi_V3_Levres')
    pr = next(p for p in me.primitives if p.material == mat_i)
    P = lire(pr.attributes.POSITION).astype(np.float64); UV = lire(pr.attributes.TEXCOORD_0).astype(np.float64)
    u2x = np.polyfit(UV[:, 0], P[:, 0], 1); v2y = np.polyfit(UV[:, 1], P[:, 1], 1)
    # peau voisine : texture du visage autour du contour des lèvres (sommets du visage juste au-delà du bord)
    face = me.primitives[0]; mat_f = g.materials[face.material]
    Pf = lire(face.attributes.POSITION).astype(np.float64); UVf = lire(face.attributes.TEXCOORD_0).astype(np.float64)
    def image(idx):
        im = g.images[g.textures[idx].source]; bv = g.bufferViews[im.bufferView]
        return Image.open(io.BytesIO(bytes(blob[bv.byteOffset:bv.byteOffset + bv.byteLength]))).convert('RGB')
    tf = image(mat_f.pbrMetallicRoughness.baseColorTexture.index); A = np.asarray(tf)
    # peau du visage sous chaque texel : point du visage le plus proche (vu de face, partie avant de la tête),
    # couleur de sa texture ; hors du contour, la coque prend exactement la couleur de la peau qu'elle couvre
    from scipy.spatial import cKDTree
    devant = np.where((Pf[:, 2] > 0.10) & (np.abs(Pf[:, 0]) < 0.11) & (np.abs(Pf[:, 1] - 1.47) < 0.06))[0]
    arbre = cKDTree(Pf[devant][:, :2])
    def peau(X, Y):
        _, k = arbre.query(np.stack([X.ravel(), Y.ravel()], 1), k=4)
        uv = UVf[devant[k]] % 1.0
        col = A[(uv[..., 1] * A.shape[0]).astype(int).clip(0, A.shape[0] - 1), (uv[..., 0] * A.shape[1]).astype(int).clip(0, A.shape[1] - 1)]
        return (col.mean(1) * PEAU_COQUE).reshape(X.shape + (3,))
    mat = g.materials[mat_i]; tex = mat.pbrMetallicRoughness.baseColorTexture.index
    taille = tuple(2 * x for x in image(tex).size)        # deux fois plus fine : dégradés doux
    T = peindre_levres(u2x, v2y, taille, peau)
    buf = io.BytesIO(); Image.fromarray(T).save(buf, 'PNG')
    im = g.images[g.textures[tex].source]; im.bufferView = ecrire(np.frombuffer(buf.getvalue(), np.uint8)); im.mimeType = 'image/png'
    mat.pbrMetallicRoughness.baseColorFactor = [1.0, 1.0, 1.0, 1.0]
    mat.pbrMetallicRoughness.roughnessFactor = LEVRES_RUGOSITE
    print('lèvres : texture repeinte', taille)
    # intérieur de la bouche : rouge sombre (il paraissait noir), plus sombre au fond (bas de la texture)
    cav = next((m for m in g.materials if m.name == 'M_Gabi_V3_Cavite'), None)
    if cav is not None and cav.pbrMetallicRoughness.baseColorTexture is not None:
        ti = cav.pbrMetallicRoughness.baseColorTexture.index; w_, h_ = image(ti).size
        t = np.linspace(0, 1, h_)[:, None, None]
        Tc = (c0 := np.array(CAVITE[0], float)) + (np.array(CAVITE[1], float) - c0) * t * np.ones((1, w_, 1))
        buf = io.BytesIO(); Image.fromarray(np.clip(Tc, 0, 255).astype(np.uint8)).save(buf, 'PNG')
        imc = g.images[g.textures[ti].source]; imc.bufferView = ecrire(np.frombuffer(buf.getvalue(), np.uint8)); imc.mimeType = 'image/png'
        cav.pbrMetallicRoughness.baseColorFactor = [1.0, 1.0, 1.0, 1.0]
        print('cavité : rouge sombre')


def traiter_glb(src, dst):
    import pygltflib
    g = pygltflib.GLTF2().load(src); blob = bytearray(g.binary_blob())
    TYPES = {5126: np.float32, 5125: np.uint32, 5123: np.uint16, 5121: np.uint8}

    def lire(i):
        a = g.accessors[i]; bv = g.bufferViews[a.bufferView]; dt = TYPES[a.componentType]
        k = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4}[a.type]
        x = np.frombuffer(blob, dtype=dt, count=a.count * k, offset=(bv.byteOffset or 0) + (a.byteOffset or 0))
        return x.reshape(a.count, k) if k > 1 else x

    def ecrire(data):
        while len(blob) % 4: blob.append(0)
        off = len(blob); blob.extend(data.tobytes())
        g.bufferViews.append(pygltflib.BufferView(buffer=0, byteOffset=off, byteLength=data.nbytes))
        return len(g.bufferViews) - 1

    def accesseur(D):
        D = D.astype(np.float32); idx = np.nonzero(np.abs(D).max(1) > 1e-7)[0].astype(np.uint32)
        a = pygltflib.Accessor(componentType=5126, count=len(D), type='VEC3', min=[0.0] * 3, max=[0.0] * 3)
        if len(idx):
            a.min = D.min(0).tolist(); a.max = D.max(0).tolist()
            a.sparse = pygltflib.Sparse(count=int(len(idx)),
                indices=pygltflib.AccessorSparseIndices(bufferView=ecrire(idx), componentType=5125),
                values=pygltflib.AccessorSparseValues(bufferView=ecrire(np.ascontiguousarray(D[idx]))))
        g.accessors.append(a); return len(g.accessors) - 1

    def lire_cible(i):
        a = g.accessors[i]
        D = lire(i).astype(np.float64).copy() if a.bufferView is not None else np.zeros((a.count, 3))
        if a.sparse:
            sp = a.sparse; bi = g.bufferViews[sp.indices.bufferView]; bv = g.bufferViews[sp.values.bufferView]
            idx = np.frombuffer(blob, dtype=TYPES[sp.indices.componentType], count=sp.count, offset=(bi.byteOffset or 0) + (sp.indices.byteOffset or 0))
            val = np.frombuffer(blob, dtype=np.float32, count=sp.count * 3, offset=(bv.byteOffset or 0) + (sp.values.byteOffset or 0)).reshape(-1, 3)
            D[idx] = val
        return D

    me = next(m for m in g.meshes if m.name == 'Mesh_0')
    noms = list((me.extras or {}).get('targetNames') or [])
    if FORME in noms: sys.exit(f'{src} : Mesh_0 a déjà la forme {FORME}')
    # MouthOpen : lèvre inférieure lissée (visage et coque ensemble, avant le volume)
    if 'MouthOpen' in noms:
        k_o = noms.index('MouthOpen')
        prs = [pr for pr in me.primitives if pr is me.primitives[0] or g.materials[pr.material].name == 'M_Gabi_V3_Levres']
        Ps = [lire(pr.attributes.POSITION).astype(np.float64) for pr in prs]
        Ds = [lire_cible(pr.targets[k_o]['POSITION']) for pr in prs]
        L = lisser_ouverture(np.concatenate(Ps), np.concatenate(Ds)); debut = 0; ecart = 0.0
        for pr, P_, D_ in zip(prs, Ps, Ds):
            Dn = L[debut:debut + len(P_)]; debut += len(P_)
            ecart = max(ecart, float(np.abs(Dn - D_).max()))
            pr.targets[k_o] = dict(pr.targets[k_o], POSITION=accesseur(Dn))
        print('MouthOpen : lèvre inférieure lissée, correction max', round(ecart * 1000, 1), 'mm')
    total = 0.0
    for k_pr, pr in enumerate(me.primitives):
        P0 = lire(pr.attributes.POSITION).astype(np.float64)
        F = lire(pr.indices).reshape(-1, 3).astype(np.int64)
        P = P0 + volume(P0)                                # lèvres au repos : positions et normales
        acc = g.accessors[pr.attributes.POSITION]; bv = g.bufferViews[acc.bufferView]
        off = (bv.byteOffset or 0) + (acc.byteOffset or 0); X = P.astype(np.float32)
        blob[off:off + X.nbytes] = X.tobytes(); acc.min = X.min(0).tolist(); acc.max = X.max(0).tolist()
        bouge = np.linalg.norm(P - P0, axis=1) > 1e-7
        if bouge.any() and pr.attributes.NORMAL is not None:
            accn = g.accessors[pr.attributes.NORMAL]; bvn = g.bufferViews[accn.bufferView]
            offn = (bvn.byteOffset or 0) + (accn.byteOffset or 0)
            N = lire(pr.attributes.NORMAL).astype(np.float64)
            N = N + np.where(bouge[:, None], normales(P, F) - normales(P0, F), 0)
            N = (N / np.linalg.norm(N, axis=1, keepdims=True)).astype(np.float32)
            blob[offn:offn + N.nbytes] = N.tobytes()
        if k_pr == 0:
            visage_P = P; visage_N = lire(pr.attributes.NORMAL).astype(np.float64)
        elif g.materials[pr.material].name == 'M_Gabi_V3_Levres' and pr.attributes.NORMAL is not None:
            # hors du contour des lèvres, la coque prend les normales de la peau qu'elle couvre (même éclairage,
            # pas de halo) ; fondu entre 1 et 1,3 fois la hauteur des lèvres
            from scipy.spatial import cKDTree
            _, plus_proche = cKDTree(visage_P).query(P)
            _, frac = position_levre(P)
            f = ss(1.0, 1.3, frac)[:, None]
            N = lire(pr.attributes.NORMAL).astype(np.float64)
            N = N * (1 - f) + visage_N[plus_proche] * f
            N = (N / np.linalg.norm(N, axis=1, keepdims=True)).astype(np.float32)
            accn = g.accessors[pr.attributes.NORMAL]; bvn = g.bufferViews[accn.bufferView]
            offn = (bvn.byteOffset or 0) + (accn.byteOffset or 0); blob[offn:offn + N.nbytes] = N.tobytes()
            print('lèvres : normales de la peau au bord de la coque,', int((f[:, 0] > 0).sum()), 'sommets')
        D = champ(P); total = max(total, float(np.linalg.norm(D, axis=1).max()))
        cibles = list(pr.targets or [])
        t = {'POSITION': accesseur(D)}
        if cibles and all('NORMAL' in c for c in cibles):
            DN = normales(P + D, F) - normales(P, F); DN[np.linalg.norm(DN, axis=1) < 1e-4] = 0
            t['NORMAL'] = accesseur(DN)
        pr.targets = cibles + [t]
    peindre_texture(g, blob, me, lire, ecrire)
    me.extras = dict(me.extras or {}, targetNames=noms + [FORME])
    me.weights = list(me.weights or [0.0] * len(noms)) + [0.0]
    g.buffers[0].byteLength = len(blob); g.set_binary_blob(bytes(blob)); g.save(dst)
    print('Mesh_0 formes :', ', '.join(f'{i}:{n}' for i, n in enumerate(noms + [FORME])), '; déplacement max', round(total * 1000, 1), 'mm')
    print('ok', dst)


def traiter_blend(chemin):
    import bpy
    bpy.ops.wm.open_mainfile(filepath=chemin)
    o = bpy.data.objects['Mesh_0']; me = o.data
    b2g = np.array([[1, 0, 0], [0, 0, 1], [0, -1, 0]], dtype=np.float64)
    M = np.array(o.matrix_world)
    if not me.shape_keys: o.shape_key_add(name='Basis', from_mix=False)
    ancien = me.shape_keys.key_blocks.get(FORME)
    if ancien: o.shape_key_remove(ancien)
    Minv = np.linalg.inv(M[:3, :3])
    base = np.empty(len(me.vertices) * 3); me.shape_keys.key_blocks[0].data.foreach_get('co', base); base = base.reshape(-1, 3)
    Pw = base @ M[:3, :3].T + M[:3, 3]
    deja = int(o.get('volume_levres') or 0)
    deja = 3 if deja in (1, 3) else deja                # 1 : ancienne marque de la v3
    if not o.get('ouverture_lissee') and 'MouthOpen' in me.shape_keys.key_blocks:
        # MouthOpen : lèvre inférieure lissée, avant le volume (repère du calcul : celui d'origine)
        Pg = Pw @ b2g.T
        if deja: Pg = Pg - volume(Pg, deja)           # à peu près la position d'origine
        kb = me.shape_keys.key_blocks['MouthOpen']
        c = np.empty(len(me.vertices) * 3); kb.data.foreach_get('co', c); c = c.reshape(-1, 3)
        D = ((c - base) @ M[:3, :3].T) @ b2g.T
        mat = np.empty(len(me.polygons), dtype=np.int64); me.polygons.foreach_get('material_index', mat)
        cav = next((i for i, m in enumerate(me.materials) if m and m.name.startswith('M_Gabi_V3_Cavite')), -1)
        hors_cavite = np.zeros(len(me.vertices), bool)
        for poly, mi in zip(me.polygons, mat):
            if mi != cav: hors_cavite[list(poly.vertices)] = True
        Dn = D.copy(); idx = np.where(hors_cavite)[0]
        Dn[idx] = lisser_ouverture(Pg[idx], D[idx])
        kb.data.foreach_set('co', (base + ((Dn @ b2g) @ Minv.T)).astype(np.float32).ravel())
        o['ouverture_lissee'] = 1
        print('MouthOpen : lèvre inférieure lissée, correction max', round(float(np.abs(Dn - D).max()) * 1000, 1), 'mm')
    if deja != VERSION:
        Pg = Pw @ b2g.T
        if deja: Pg0 = Pg - volume(Pg, deja); Dg = volume(Pg0, VERSION) - volume(Pg0, deja)
        else: Dg = volume(Pg, VERSION)
        Dv = (Dg @ b2g) @ Minv.T                        # ajouté à la base et à toutes les formes
        for kb in me.shape_keys.key_blocks:
            c = np.empty(len(me.vertices) * 3); kb.data.foreach_get('co', c)
            kb.data.foreach_set('co', (c.reshape(-1, 3) + Dv).astype(np.float32).ravel())
        me.vertices.foreach_set('co', (base + Dv).astype(np.float32).ravel()); me.update()
        o['volume_levres'] = VERSION; base = base + Dv; Pw = base @ M[:3, :3].T + M[:3, 3]
        print(f'lèvres : volume au repos v{VERSION} (avant : v{deja or "aucune"})')
    D = champ(Pw @ b2g.T) @ b2g                      # glTF -> Blender (b2g orthogonale)
    kb = o.shape_key_add(name=FORME, from_mix=False)
    kb.data.foreach_set('co', (base + D @ Minv.T).astype(np.float32).ravel())
    kb.value = 0.0; kb.slider_min = 0.0; kb.slider_max = 1.0
    # normales de la coque des lèvres hors du contour : celles de la peau couverte (comme dans le .glb)
    from scipy.spatial import cKDTree
    levres = next((i for i, m in enumerate(me.materials) if m and m.name.startswith('M_Gabi_V3_Levres')), None)
    if levres is not None:
        me.update()
        Pg = (base @ M[:3, :3].T + M[:3, 3]) @ b2g.T
        coins = np.empty(len(me.loops) * 3); me.corner_normals.foreach_get('vector', coins); coins = coins.reshape(-1, 3)
        lv = np.empty(len(me.loops), dtype=np.int64); me.loops.foreach_get('vertex_index', lv)
        mat = np.empty(len(me.polygons), dtype=np.int64); me.polygons.foreach_get('material_index', mat)
        debut = np.empty(len(me.polygons), dtype=np.int64); me.polygons.foreach_get('loop_start', debut)
        nb = np.empty(len(me.polygons), dtype=np.int64); me.polygons.foreach_get('loop_total', nb)
        coin_levre = np.zeros(len(me.loops), bool)
        for d, n in zip(debut[mat == levres], nb[mat == levres]): coin_levre[d:d + n] = True
        v_levre = np.zeros(len(me.vertices), bool); v_levre[lv[coin_levre]] = True
        peau = np.where(~v_levre & (Pg[:, 2] > 0.10) & (np.abs(Pg[:, 1] - 1.47) < 0.06))[0]
        coin_peau = ~coin_levre & np.isin(lv, peau)
        Nv = np.zeros((len(me.vertices), 3)); np.add.at(Nv, lv[coin_peau], coins[coin_peau])
        _, k = cKDTree(Pg[peau]).query(Pg[lv[coin_levre]])
        _, frac = position_levre(Pg[lv[coin_levre]])
        f = ss(1.0, 1.3, frac)[:, None]
        Nn = Nv[peau[k]]; Nn /= np.maximum(np.linalg.norm(Nn, axis=1, keepdims=True), 1e-9)
        nouv = coins.copy(); nouv[coin_levre] = coins[coin_levre] * (1 - f) + Nn * f
        nouv /= np.maximum(np.linalg.norm(nouv, axis=1, keepdims=True), 1e-9)
        me.normals_split_custom_set([tuple(v) for v in nouv])
        print('lèvres : normales de la peau au bord de la coque,', int((f[:, 0] > 0).sum()), 'coins')
    print('Mesh_0 formes :', ', '.join(f'{i}:{k.name}' for i, k in enumerate(me.shape_keys.key_blocks[1:])))
    bpy.ops.wm.save_mainfile(); print('ok', chemin)


if __name__ == '__main__':
    args = [a for a in sys.argv[1:] if a != '--']
    if not args: sys.exit('usage : voir l\'en-tête du script')
    if args[0].endswith('.blend'): traiter_blend(os.path.abspath(args[0]))
    else: traiter_glb(args[0], args[1])
