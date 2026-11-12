# Ajoute à Gabi trois formes d'expression pour un regard plus chaleureux :
#   SourireYeux  : joues remontées, paupières inférieures qui remontent, coin externe de l'œil plissé,
#                  légères pattes d'oie (le sourire « des yeux ») ;
#   SourcilsDoux : sourcils relevés au centre, détendus, paupière supérieure un peu relevée (expression
#                  bienveillante, regard moins fatigué) ;
#   Clignement   : paupière supérieure qui descend jusqu'à fermer l'œil (la paupière inférieure monte un peu).
# Formes posées sur le visage (Mesh_0, après MouthOpen/MouthRound/MouthPress/MouthWide, qui gardent leurs indices 0 à 3)
# et sur les deux paupières (Gabi_Paupieres_D/G : seulement les trois formes, indices 0 à 2 ; pas de formes de
# bouche sur les paupières, sinon le jeu, qui prend le premier maillage portant « MouthOpen », animerait une paupière).
#
# Usage :
#   python3 ajouter-expressions-gabi.py <gabi.glb> <sortie.glb> [--repos SourireYeux=0.3,SourcilsDoux=0.4]
#   python3 ajouter-expressions-gabi.py <gabi.blend> [--repos ...]          (le .blend est modifié et enregistré)
# Le .glb n'a besoin que de numpy et pygltflib ; le .blend, de Blender en module Python (pip install bpy).
# --repos : valeurs par défaut des formes (poids du maillage glTF / valeur des clés Blender). Les instances Godot
# démarrent pourtant à 0 : le jeu pose les valeurs par set_blend_shape_value (guide/gabi_visage.gd).
#
# Le script répare aussi les paupières (géométrie de repos et couleurs) : voir reparer_paupieres et traiter_glb.
#
# Les déplacements sont calculés à partir de la géométrie (et non des numéros de sommets) : le même calcul
# vaut pour le Gabi d'origine et pour le Gabi rigué par Mixamo, dont l'ordre des sommets peut différer.
# Repère de calcul : celui du glTF (mètres, Y en haut, Gabi regarde vers +Z).
#  - joues, pattes d'oie, sourcils : champ de déplacement doux (gaussiennes et rampes « smoothstep »), le même
#    pour la peau et pour les paupières, qui restent donc collées au visage ;
#  - paupières (et, pour SourireYeux, peau sous l'œil) : rotation autour de l'axe horizontal passant par le centre
#    du globe, angle variant continûment (bord libre 1, bord collé au visage 0 ; interpolation entre les deux
#    bords aux coins, donc ni déchirure ni croisement) ; près de l'ouverture, le bord glisse sur le globe
#    (même écart à sa surface qu'au repos) ;
#  - projection : un mélange de formes est linéaire (la corde, pas l'arc) ; les sommets de paupière qui bougent
#    sont repoussés radialement, juste assez pour que tout point visible (sommets, milieux d'arêtes, centres de
#    triangles) reste devant le globe (marge 0,4 mm) à 1/4, 1/2, 3/4 et 1 de la forme ; la poussée est lissée
#    sur les voisins pour ne pas créer de bosses. Pour Clignement, le contrôle couvre aussi de petits mouvements
#    du regard (±10° de côté, ±6° en hauteur).
import sys, os
import numpy as np

FORMES = ['SourireYeux', 'SourcilsDoux', 'Clignement']
BOUCHE = ['MouthOpen', 'MouthRound', 'MouthPress', 'MouthWide']
REPOS = {'SourireYeux': 0.3, 'SourcilsDoux': 0.4, 'Clignement': 0.0}
YEUX = (('Gabi_Oeil_D', 'Gabi_Paupieres_D', -1.0), ('Gabi_Oeil_G', 'Gabi_Paupieres_G', 1.0))  # côté : +1 = vers +X
MARGE = 0.0004
# Couleur des paupières (linéaire) : peau du visage autour des yeux, moyenne de la texture du visage sous l'œil et
# vers la tempe. Avec des couleurs de sommets blanches, le jeu (couleur du matériau × couleur des sommets) et
# Blender donnent la même teinte que la peau voisine.
PEAU_PAUPIERES = (0.394, 0.0625, 0.044)


def ss(a, b, x):
    t = np.clip((np.asarray(x, dtype=np.float64) - a) / (b - a), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def gauss(x, s):
    return np.exp(-0.5 * (x / s) ** 2)


# ---------------------------------------------------------------- champs de peau (visage et paupières)
def champ_sourire(P, N):
    """Bosse des joues, coin externe qui se plisse, pattes d'oie. P, N : (n,3) au repos. S'ajoute à la rotation
    de la paupière inférieure et de la peau sous l'œil (angles_sourire)."""
    x, y, z = P[:, 0], P[:, 1], P[:, 2]
    ax = np.abs(x); sx = np.sign(x) + (x == 0)
    D = np.zeros_like(P)
    avant = ss(0.07, 0.10, z)                                          # seulement le devant du visage
    moustache = ss(1.500, 1.530, y)                                     # la moustache et la bouche non plus
    # joue : bosse qui monte et avance (s'éteint avant la boule du nez ; un masque selon la profondeur plierait
    # la peau là où elle plonge vers le nez)
    j = gauss(ax - 0.076, 0.024) * gauss(y - 1.542, 0.016) * avant * ss(0.032, 0.054, ax) * moustache
    D[:, 1] += 0.0035 * j; D[:, 2] += 0.0028 * j; D[:, 0] += sx * 0.0005 * j
    # coin externe : la peau se resserre vers le coin (plissement) et remonte légèrement
    K = np.stack([sx * 0.0795, np.full_like(x, 1.586)], 1)
    v = np.stack([x, y], 1) - K; dist = np.linalg.norm(v, axis=1) + 1e-9
    lat = (ax - 0.0795)                                               # > 0 : côté tempe
    zone = gauss(dist, 0.016) * ss(-0.006, 0.006, lat) * avant
    D[:, 0] += -sx * 0.0016 * zone                                     # vers le coin
    D[:, 1] += 0.0008 * zone
    # pattes d'oie : trois plis rayonnants légers (le maillage, ~5 mm entre sommets, ne permet pas plus fin)
    ang = np.degrees(np.arctan2(v[:, 1], np.abs(v[:, 0])))
    plis = sum(gauss(ang - a, 12.0) for a in (-28.0, 0.0, 26.0))
    anneau = ss(0.006, 0.011, dist) * (1 - ss(0.020, 0.028, dist)) * ss(0.0, 0.004, lat) * avant
    # creux vers l'intérieur de la tête (direction commune au visage et aux paupières, pas leurs normales :
    # la paupière, coque fine à normales variées, sortirait sinon de la peau)
    dedans = np.stack([-sx * 0.5, np.zeros_like(x), -np.full_like(x, 0.85)], 1)
    D += dedans * (0.0005 * plis * anneau)[:, None]
    return D


def champ_sourcils(P, N):
    """Sourcils (peints dans la texture du visage, donc portés par ses sommets) : intérieur relevé et
    légèrement arrondi, extérieur détendu (un peu plus bas)."""
    x, y, z = P[:, 0], P[:, 1], P[:, 2]
    ax = np.abs(x); sx = np.sign(x) + (x == 0)
    D = np.zeros_like(P)
    avant = ss(0.07, 0.10, z)
    # hauteur : 1 dans la bande des sourcils (1,625-1,665 m), nulle sur les paupières et en haut du front
    bande = ss(1.604, 1.630, y) * (1 - ss(1.668, 1.71, y))
    montee = 0.0070 * (1 - ss(0.026, 0.082, ax)) * ss(0.004, 0.022, ax) + 0.0040 * (1 - ss(0.004, 0.022, ax))
    descente = -0.0015 * ss(0.072, 0.100, ax)
    D[:, 1] += (montee + descente) * bande * avant
    # front qui se détend : sourcils à peine écartés, léger arrondi vers l'avant à l'intérieur
    D[:, 0] += sx * 0.0008 * ss(0.012, 0.03, ax) * (1 - ss(0.05, 0.08, ax)) * bande * avant
    D[:, 2] += 0.0006 * (1 - ss(0.03, 0.07, ax)) * bande * avant
    return D


# ---------------------------------------------------------------- paupières (autour du globe)
# Bord libre mesuré sur le modèle (angle vertical en degrés autour du centre du globe, 0 = droit devant),
# en fonction de « lat » = écart latéral au centre de l'œil (> 0 vers la tempe). Identique pour les deux yeux.
LAT = np.array([-0.0165, -0.0105, 0.0015, 0.0105, 0.0165, 0.0225, 0.0265])
HAUT = np.array([9.0, 9.4, 10.6, 11.5, 11.7, 11.1, 6.0])
BAS = np.array([-21.6, -22.6, -21.8, -19.1, -14.8, -8.1, 4.0])
LARG_HAUT, LARG_BAS = 38.0, 30.0       # étendue de la paupière, du bord libre au bord collé au visage


def angles(P, c, cote, forme):
    """Angle (degrés, > 0 vers le haut) dont tourne chaque point autour de l'axe horizontal passant par le centre
    du globe. Champ continu : entre les deux bords libres (coins de l'œil), interpolation linéaire, donc ni
    déchirure ni croisement des paupières."""
    d = P - c; lat = cote * d[:, 0]; r = np.linalg.norm(d, axis=1)
    phi = np.degrees(np.arctan2(d[:, 1], d[:, 2]))
    ph, pb = np.interp(lat, LAT, HAUT), np.interp(lat, LAT, BAS); ouv = ph - pb
    tomb = lambda t: 1 - ss(0.08, 1.0, t)
    haut = tomb((phi - ph) / LARG_HAUT)
    if forme == 'Clignement':
        # les bords se rejoignent à 20 % de l'ouverture au-dessus du bord inférieur ; seules les paupières
        attenue = ss(-0.033, -0.025, lat) * (1 - ss(0.027, 0.034, lat))
        dh, db = 0.8 * ouv * attenue, 0.2 * ouv * attenue
        bas = tomb((pb - phi) / LARG_BAS)
    elif forme == 'SourireYeux':
        # paupière inférieure et peau sous l'œil remontent presque d'un bloc (la joue pousse), davantage côté
        # tempe ; coin externe de la paupière supérieure un peu abaissé (l'œil se plisse) ; plafonnés par
        # l'ouverture locale pour ne jamais croiser les bords aux coins
        attenue = ss(-0.030, -0.008, lat) * (1 - ss(0.030, 0.052, lat))   # côté nez : presque rien (pli)
        loin = 1 - ss(0.040, 0.085, r)         # jusque sur le haut de la joue, puis s'éteint (partout, nez compris)
        # plafond lié à l'ouverture locale au bord libre, relâché en s'éloignant sous le bord (sinon pli au coin)
        db = np.minimum((6.5 + 1.5 * ss(-0.01, 0.016, lat)) * attenue * loin,
                        0.6 * ouv + 0.6 * np.maximum(pb - phi, 0))
        dh = np.minimum(3.0 * ss(0.0, 0.022, lat), 0.25 * ouv) * attenue * loin
        bas = np.ones_like(r)
    elif forme == 'SourcilsDoux':
        # le front qui se relève remonte un peu la paupière supérieure (regard plus ouvert, moins fatigué)
        attenue = ss(-0.033, -0.022, lat) * (1 - ss(0.022, 0.032, lat))
        dh, db = -4.0 * attenue, 0.0 * attenue
        bas = np.zeros_like(r)
    else:
        raise ValueError(forme)
    return np.where(phi >= ph, -dh * haut, np.where(phi <= pb, db * bas,
                    db + (-dh - db) * np.clip((phi - pb) / np.maximum(ouv, 1e-6), 0, 1)))


def ouverture(P, c, cote):
    """1 pour les points de paupière autour de l'ouverture de l'œil (jusqu'à ~8° des bords libres), 0 au-delà de
    18° : ailleurs, la paupière est cachée derrière la peau du visage et doit bouger exactement comme elle."""
    d = P - c; lat = cote * d[:, 0]; phi = np.degrees(np.arctan2(d[:, 1], d[:, 2]))
    ph, pb = np.interp(lat, LAT, HAUT), np.interp(lat, LAT, BAS)
    loin = np.maximum(np.maximum(pb - phi, phi - ph), 0)
    return (1 - ss(8, 18, loin)) * ss(-0.031, -0.024, lat) * (1 - ss(0.027, 0.033, lat))


def tourner(P, globe, dphi, glisser):
    """Rotation de chaque point de dphi (degrés) autour de l'axe X passant par le centre du globe. glisser (0 à 1
    par point) : le point garde sa distance à la surface du globe (le globe est un ellipsoïde, plus bombé devant :
    une simple rotation ferait entrer le bord de la paupière dans la cornée). Sans glissement (peau du visage,
    paupière cachée sous la peau), la peau qui passe derrière la surface du globe recouvre simplement l'œil."""
    c = globe.c; d = P - c
    a = np.radians(dphi); ca, sa = np.cos(a), np.sin(a)
    v = d.copy(); v[:, 1] = d[:, 1] * ca + d[:, 2] * sa; v[:, 2] = -d[:, 1] * sa + d[:, 2] * ca
    glisser = np.broadcast_to(np.asarray(glisser, dtype=np.float64), dphi.shape)
    if not glisser.any(): return c + v
    r0 = np.linalg.norm(d, axis=1); u0 = d / np.maximum(r0, 1e-9)[:, None]; u1 = v / np.maximum(r0, 1e-9)[:, None]
    bouge = (np.abs(dphi) > 1e-4) & (glisser > 0)
    dr = np.zeros(len(P))
    if bouge.any(): dr[bouge] = globe.rayon_lisse(u1[bouge]) - globe.rayon_lisse(u0[bouge])
    return c + u1 * (r0 + dr * glisser)[:, None]


def directions(n):
    i = np.arange(n) + 0.5; t = np.arccos(1 - 2 * i / n); f = np.pi * (1 + 5 ** 0.5) * i
    return np.stack([np.sin(t) * np.cos(f), np.sin(t) * np.sin(f), np.cos(t)], 1)


def rot(axe, deg):
    a = np.radians(deg); c, s = np.cos(a), np.sin(a); x, y, z = axe
    return np.array([[c + x * x * (1 - c), x * y * (1 - c) - z * s, x * z * (1 - c) + y * s],
                     [y * x * (1 - c) + z * s, c + y * y * (1 - c), y * z * (1 - c) - x * s],
                     [z * x * (1 - c) - y * s, z * y * (1 - c) + x * s, c + z * z * (1 - c)]])


class Globe:
    """Surface du globe de l'œil : rayon maximal selon la direction depuis son centre (centre de la boîte
    englobante, comme pour l'orientation des pupilles et les formes de regard du jeu). Pour les formes : enveloppe
    sur de petits mouvements du regard (±10° à gauche/droite, ±6° en haut/en bas) pour que la paupière reste
    devant la cornée quand Gabi regarde un peu de côté pendant un clignement. Le globe est un ellipsoïde allongé
    vers l'avant : au-delà, la cornée remonte vite sous la paupière supérieure."""
    REGARD_LACET, REGARD_TANGAGE = (-10, -5, 0, 5, 10), (-6, -3, 0, 3, 6)

    def __init__(self, E, regard=True):
        if not regard: self.REGARD_LACET, self.REGARD_TANGAGE = (0,), (0,)
        self.c = (E.min(0) + E.max(0)) / 2
        d = E - self.c
        pts = np.concatenate([d @ (rot((0, 1, 0), l) @ rot((1, 0, 0), t)).T
                              for l in self.REGARD_LACET for t in self.REGARD_TANGAGE])
        r = np.linalg.norm(pts, axis=1); u = pts / r[:, None]
        self.dirs = directions(4000); cmin = np.cos(np.radians(4.0))
        R = np.zeros(len(self.dirs))
        for i in range(0, len(self.dirs), 200):
            cs = self.dirs[i:i + 200] @ u.T
            m = np.where(cs > cmin, r[None, :], 0.0).max(1)
            R[i:i + 200] = np.where(m > 0, m, r[np.argmax(cs, 1)])
        self.R = R

    def rayon(self, u):
        """Rayon strict (maximum des directions de la grille à moins de 3,5°)."""
        out = np.empty(len(u))
        for i in range(0, len(u), 1024):
            cs = u[i:i + 1024] @ self.dirs.T
            m = np.where(cs > np.cos(np.radians(3.5)), self.R[None, :], 0.0).max(1)
            out[i:i + 1024] = np.where(m > 0, m, self.R[np.argmax(cs, 1)])
        return out

    def rayon_lisse(self, u):
        out = np.empty(len(u))
        for i in range(0, len(u), 1024):
            w = np.exp(80.0 * (u[i:i + 1024] @ self.dirs.T - 1)); out[i:i + 1024] = (w @ self.R) / w.sum(1)
        return out

    def ecart(self, P):
        d = P - self.c; r = np.linalg.norm(d, axis=1)
        return r - self.rayon(d / np.maximum(r, 1e-9)[:, None])


def voisins(P, F):
    """Liste d'arêtes entre sommets soudés par position (les coutures d'UV séparent des sommets confondus)."""
    cle = np.round(P / 1e-5).astype(np.int64)
    _, soude = np.unique(cle, axis=0, return_inverse=True); soude = soude.ravel()
    F = soude[F]
    A = np.concatenate([F[:, [0, 1]], F[:, [1, 2]], F[:, [2, 0]]]); A = np.unique(np.sort(A, 1), axis=0)
    return soude, A[A[:, 0] != A[:, 1]]


def echantillons(F, mobiles):
    """Points de contrôle : sommets, milieux d'arêtes et centres des triangles qui touchent un sommet mobile
    (une face plate peut traverser la cornée même si ses trois sommets sont devant)."""
    F = F[mobiles[F].any(1)]
    idx = [np.stack([F[:, 0]] * 3, 1), np.stack([F[:, 1]] * 3, 1), np.stack([F[:, 2]] * 3, 1),
           np.stack([F[:, 0], F[:, 1], F[:, 1]], 1), np.stack([F[:, 1], F[:, 2], F[:, 2]], 1),
           np.stack([F[:, 2], F[:, 0], F[:, 0]], 1), F]
    w = [np.array([1, 0, 0.])] * 3 + [np.array([0.5, 0.5, 0])] * 3 + [np.array([1 / 3] * 3)]
    I = np.concatenate(idx); W = np.concatenate([np.tile(x, (len(F), 1)) for x in w])
    return I, W


def lisser(delta, soude, aretes, masque, passes=3):
    """La poussée se propage aux voisins (sommets soudés par position), sans jamais diminuer."""
    n = soude.max() + 1
    for _ in range(passes):
        ds = np.zeros(n); np.maximum.at(ds, soude, delta)
        som = np.zeros(n); cnt = np.zeros(n)
        np.add.at(som, aretes[:, 0], ds[aretes[:, 1]]); np.add.at(cnt, aretes[:, 0], 1)
        np.add.at(som, aretes[:, 1], ds[aretes[:, 0]]); np.add.at(cnt, aretes[:, 1], 1)
        ds = np.maximum(ds, 0.6 * ds + 0.4 * som / np.maximum(cnt, 1))
        delta = np.where(masque, ds[soude], 0.0)
    return delta


def projeter(P0, P1, globes, F, soude, aretes, temps=(0.25, 0.5, 0.75, 1.0), exige=None, zone=None):
    """Pousse radialement (depuis le centre du globe) les sommets qui bougent pour qu'aux instants « temps » la
    position mélangée P0 + t (P1 - P0) ne laisse pas passer le globe : tout point (sommet, milieu d'arête,
    centre de triangle) visible au repos (devant le globe) y reste, à MARGE au moins (ou à son écart du repos
    s'il était plus près). Ce qui est caché dans le globe au repos peut le rester. globes : globe au repos, puis
    enveloppe des petits mouvements du regard. Poussée minimale, lissée sur les voisins, puis re-vérifiée.
    Renvoie la cible corrigée et la poussée maximale (m)."""
    mobiles = np.linalg.norm(P1 - P0, axis=1) > 5e-5
    if exige is not None: mobiles = mobiles | (exige > 0)
    if zone is not None: mobiles = mobiles & zone
    if not mobiles.any(): return P1.copy(), 0.0
    I, W = echantillons(F, mobiles)
    if zone is not None:
        garde = zone[I].all(1); I, W = I[garde], W[garde]
    S = lambda X: (X[I] * W[:, :, None]).sum(1)
    contraintes = []
    for globe in globes:
        e0 = globe.ecart(S(P0)); req = np.where(e0 > -0.0003, np.minimum(e0, MARGE), -np.inf)
        if exige is not None: req = np.maximum(req, (exige[I] * W).sum(1))
        contraintes.append((globe, req))
    part = np.maximum((W * mobiles[I]).sum(1), 0.34)       # part de l'échantillon portée par des sommets mobiles
    c = globes[0].c
    v = P1 - c; uv = v / np.maximum(np.linalg.norm(v, axis=1), 1e-9)[:, None]
    delta = np.zeros(len(P0))

    def besoin(delta):
        Q = P1 + uv * delta[:, None]; b = np.zeros(len(P0))
        for globe, req in contraintes:
            for t in temps:
                manque = (req - globe.ecart(S(P0 + t * (Q - P0)))) / (t * part)
                manque = np.where(np.isfinite(manque), manque, 0)
                for k in range(3): np.maximum.at(b, I[:, k], np.where(W[:, k] > 0, manque, 0))
        return np.where(mobiles, np.maximum(b, 0), 0.0)

    for etape in (0, 1):
        for _ in range(40):
            b = besoin(delta)
            if b.max() <= 1e-5: break
            delta = delta + np.where(b > 0, b + 2e-5, 0)
        if etape == 0: delta = lisser(delta, soude, aretes, mobiles, passes=2)
    reste = besoin(delta).max()
    if reste > 5e-5: print(f'    (reste {reste * 1000:.2f} mm non résolu)')
    return P1 + uv * delta[:, None], float(delta.max())


def reparer_paupieres(maillages):
    """Défauts du modèle d'origine, corrigés dans la géométrie de repos des paupières :
    1. quatre sommets de Gabi_Paupieres_G projetés 4,3 cm en avant (petit éclat sombre à côté du nez) : remis
       en symétrique de la paupière droite ;
    2. au-dessus du bord de la paupière supérieure, la face avant passait sous la surface du globe (on voyait un
       croissant d'iris à travers la paupière) : les faces tournées vers l'extérieur, dans l'ouverture, sont
       amenées devant le globe au repos (marge 0,3 mm), poussée lissée sur les voisins."""
    from numpy.linalg import norm
    D = maillages['Gabi_Paupieres_D'][0]; G = maillages['Gabi_Paupieres_G'][0].copy()
    M = D * np.array([-1, 1, 1])
    dist = norm(G[:, None, :] - M[None, :, :], axis=2); proche = dist.min(1)
    eclats = np.where(proche > 0.01)[0]
    if len(eclats):
        # sommets symétriques à la même position (x, y), associés dans l'ordre de profondeur
        dxy = norm(G[eclats, None, :2] - M[None, :, :2], axis=2)
        groupes = {}
        for k, i in enumerate(eclats):
            cand = tuple(sorted(np.where(dxy[k] < 0.001)[0], key=lambda j: M[j, 2]))
            groupes.setdefault(cand, []).append(i)
        for cand, ids in groupes.items():
            ids = sorted(ids, key=lambda i: G[i, 2])
            if len(cand) >= len(ids):
                for i, j in zip(ids, cand[-len(ids):]): G[i] = M[j]
        print(f'  Gabi_Paupieres_G : {len(eclats)} sommets égarés remis en place')
    sorties = {'Gabi_Paupieres_D': maillages['Gabi_Paupieres_D'][0].copy(), 'Gabi_Paupieres_G': G}
    for oeil, paup, cote in YEUX:
        P = sorties[paup]; F = maillages[paup][1]; globe = Globe(maillages[oeil][0], regard=False)
        soude, aretes = voisins(P, F)
        d = P - globe.c; lat = cote * d[:, 0]; phi = np.degrees(np.arctan2(d[:, 1], d[:, 2]))
        e0 = globe.ecart(P); dehors = (normales(P, F) * d).sum(1) / np.linalg.norm(d, axis=1)
        zone = ((lat > -0.026) & (lat < 0.028) & (phi > np.interp(lat, LAT, BAS) - 14)
                & (phi < np.interp(lat, LAT, HAUT) + 24) & (e0 > -0.003) & (dehors > 0.3))
        exige = np.where(zone, 0.0003, -1.0)
        Q, pousse = projeter(P, P, [globe], F, soude, aretes, temps=(1.0,), exige=exige)
        print(f'  {paup} : faces visibles ramenées devant le globe, poussée max {pousse * 1000:.2f} mm')
        sorties[paup] = Q
    return sorties


def normales(P, F):
    n = np.zeros_like(P)
    fn = np.cross(P[F[:, 1]] - P[F[:, 0]], P[F[:, 2]] - P[F[:, 0]])
    for k in range(3): np.add.at(n, F[:, k], fn)
    return n / np.maximum(np.linalg.norm(n, axis=1), 1e-12)[:, None]


def calculer(maillages):
    """maillages : nom -> (P (n,3) repère glTF, F (m,3) triangles).
    Renvoie (nouvelles positions de repos des paupières, nom -> {forme: déplacements (n,3)})."""
    res = {}
    globes = {oeil: Globe(maillages[oeil][0]) for oeil, _, _ in YEUX}
    fixes = {oeil: Globe(maillages[oeil][0], regard=False) for oeil, _, _ in YEUX}
    # visage : champs de peau + rotation de la peau sous chaque œil (sans glissement)
    P, F = maillages['Mesh_0']; N = normales(P, F)
    res['Mesh_0'] = {'SourireYeux': champ_sourire(P, N), 'SourcilsDoux': champ_sourcils(P, N),
                     'Clignement': np.zeros_like(P)}
    for oeil, _, cote in YEUX:
        gl = globes[oeil]
        res['Mesh_0']['SourireYeux'] += tourner(P, gl, angles(P, gl.c, cote, 'SourireYeux'), False) - P
    repos = reparer_paupieres(maillages)
    for oeil, paup, cote in YEUX:
        globe = globes[oeil]
        P = repos[paup]; F = maillages[paup][1]; N = normales(P, F); soude, aretes = voisins(P, F)
        champ = {'SourireYeux': champ_sourire(P, N), 'SourcilsDoux': champ_sourcils(P, N), 'Clignement': 0.0}
        g = ouverture(P, globe.c, cote)
        res[paup] = {}
        for f in FORMES:
            if f == 'Clignement':
                # toute la paupière supérieure passe devant le globe : glissement sur le globe et contrôle complet
                # (globe au repos et petits mouvements du regard)
                cible = tourner(P, globe, angles(P, globe.c, cote, f), g)
                Q, pousse = projeter(P, cible, [fixes[oeil], globe], F, soude, aretes)
            else:
                cible = tourner(P, fixes[oeil], angles(P, globe.c, cote, f), g) + champ[f]
                Q, pousse = projeter(P, cible, [fixes[oeil]], F, soude, aretes, zone=g > 0.5)
            print(f'  {paup} {f} : poussée max {pousse * 1000:.2f} mm')
            res[paup][f] = Q - P
    return repos, res


# ---------------------------------------------------------------- .glb (pygltflib)
def traiter_glb(src, dst, valeurs):
    import pygltflib
    g = pygltflib.GLTF2().load(src); blob = bytearray(g.binary_blob())
    TYPES = {5126: np.float32, 5125: np.uint32, 5123: np.uint16, 5121: np.uint8}

    def lire(i):
        a = g.accessors[i]; bv = g.bufferViews[a.bufferView]; dt = TYPES[a.componentType]
        k = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4}[a.type]
        assert not bv.byteStride or bv.byteStride == k * np.dtype(dt).itemsize
        x = np.frombuffer(blob, dtype=dt, count=a.count * k, offset=(bv.byteOffset or 0) + (a.byteOffset or 0))
        return x.reshape(a.count, k) if k > 1 else x

    def ecrire(data, cible=None):
        while len(blob) % 4: blob.append(0)
        off = len(blob); blob.extend(data.tobytes())
        g.bufferViews.append(pygltflib.BufferView(buffer=0, byteOffset=off, byteLength=data.nbytes, target=cible))
        return len(g.bufferViews) - 1

    def accesseur(D):
        """Delta de forme : accesseur clairsemé (sans bufferView, zéros sauf les sommets qui bougent)."""
        D = D.astype(np.float32); idx = np.nonzero(np.abs(D).max(1) > 1e-7)[0].astype(np.uint32)
        a = pygltflib.Accessor(componentType=5126, count=len(D), type='VEC3',
                               min=(D.min(0) if len(D) else np.zeros(3)).tolist(), max=D.max(0).tolist())
        if len(idx):
            a.sparse = pygltflib.Sparse(count=int(len(idx)),
                indices=pygltflib.AccessorSparseIndices(bufferView=ecrire(idx), componentType=5125),
                values=pygltflib.AccessorSparseValues(bufferView=ecrire(np.ascontiguousarray(D[idx]))))
        else:
            a.min = [0.0, 0.0, 0.0]; a.max = [0.0, 0.0, 0.0]
        g.accessors.append(a); return len(g.accessors) - 1

    noms = ['Mesh_0', 'Gabi_Paupieres_D', 'Gabi_Paupieres_G', 'Gabi_Oeil_D', 'Gabi_Oeil_G']
    mesh = {m.name: m for m in g.meshes}
    for n in ('Mesh_0', 'Gabi_Paupieres_D', 'Gabi_Paupieres_G'):
        if any(f in ((mesh[n].extras or {}).get('targetNames') or []) for f in FORMES):
            sys.exit(f'{src} : {n} a déjà les formes d\'expression ; partir du .glb sans ces formes')
    assert (mesh['Mesh_0'].extras or {}).get('targetNames') == BOUCHE, 'formes de bouche inattendues'
    # géométrie (en pose de liaison, repère du glTF : les nœuds des maillages n'ont pas de transformation)
    morceaux, maillages = {}, {}
    for n in noms:
        Ps, Fs, base = [], [], 0
        for pr in mesh[n].primitives:
            P = lire(pr.attributes.POSITION).astype(np.float64)
            F = lire(pr.indices).reshape(-1, 3).astype(np.int64) if pr.indices is not None else np.arange(len(P)).reshape(-1, 3)
            Ps.append(P); Fs.append(F + base); base += len(P)
        morceaux[n] = [len(p) for p in Ps]
        maillages[n] = (np.concatenate(Ps), np.concatenate(Fs))
    nouveaux, res = calculer(maillages)
    for n in ('Mesh_0', 'Gabi_Paupieres_D', 'Gabi_Paupieres_G'):
        P, F = maillages[n]; N0 = normales(P, F)
        bornes = np.cumsum([0] + morceaux[n])
        if n in nouveaux:   # géométrie de repos réparée : positions et normales (corrigées là où elle a bougé)
            P2 = nouveaux[n]; N2 = normales(P2, F)
            for k, pr in enumerate(mesh[n].primitives):
                a, b = bornes[k], bornes[k + 1]
                for att, X in (('POSITION', P2[a:b]), ('NORMAL', None)):
                    acc = g.accessors[getattr(pr.attributes, att)]; bv = g.bufferViews[acc.bufferView]
                    off = (bv.byteOffset or 0) + (acc.byteOffset or 0)
                    if X is None:
                        N = lire(getattr(pr.attributes, att)).astype(np.float64)
                        bouge = np.linalg.norm(P2[a:b] - P[a:b], axis=1) > 1e-7
                        X = N + np.where(bouge[:, None], N2[a:b] - N0[a:b], 0)
                        X /= np.linalg.norm(X, axis=1, keepdims=True)
                    X = X.astype(np.float32); blob[off:off + X.nbytes] = X.tobytes()
                    if att == 'POSITION': acc.min = X.min(0).tolist(); acc.max = X.max(0).tolist()
            P, N0 = P2, N2
        for k, pr in enumerate(mesh[n].primitives):
            a, b = bornes[k], bornes[k + 1]
            cibles = list(pr.targets or [])
            avec_normales = all('NORMAL' in t for t in cibles) if cibles else True
            for f in FORMES:
                D = res[n][f]
                t = {'POSITION': accesseur(D[a:b])}
                if avec_normales:
                    DN = normales(P + D, F) - N0
                    DN[np.linalg.norm(DN, axis=1) < 1e-4] = 0
                    t['NORMAL'] = accesseur(DN[a:b])
                cibles.append(t)
            pr.targets = cibles
        ex = dict(mesh[n].extras or {})
        noms_formes = (ex.get('targetNames') or []) + FORMES
        ex['targetNames'] = noms_formes; mesh[n].extras = ex
        poids = list(mesh[n].weights or [0.0] * (len(noms_formes) - len(FORMES)))
        mesh[n].weights = poids + [float(valeurs.get(f, 0.0)) for f in FORMES]
        print(n, 'formes :', ', '.join(f'{i}:{x}' for i, x in enumerate(noms_formes)))
    # couleurs de sommets des paupières : rouge sombre hérité, multiplié par le matériau dans le jeu
    # (vertex_color_use_as_albedo) ; ramenées au blanc, le matériau Gabi_Paupières (couleur peau) donne la teinte
    for n in ('Gabi_Paupieres_D', 'Gabi_Paupieres_G'):
        for pr in mesh[n].primitives:
            if pr.attributes.COLOR_0 is None: continue
            acc = g.accessors[pr.attributes.COLOR_0]; bv = g.bufferViews[acc.bufferView]
            dt = TYPES[acc.componentType]; k = {'VEC3': 3, 'VEC4': 4}[acc.type]
            assert not bv.byteStride or bv.byteStride == k * np.dtype(dt).itemsize
            blanc = np.full((acc.count, k), 1.0 if dt == np.float32 else np.iinfo(dt).max, dtype=dt)
            off = (bv.byteOffset or 0) + (acc.byteOffset or 0); blob[off:off + blanc.nbytes] = blanc.tobytes()
            if acc.min is not None: acc.min = [float(blanc[0, 0])] * k
            if acc.max is not None: acc.max = [float(blanc[0, 0])] * k
        print(n, 'couleurs de sommets ramenées au blanc')
    for mat in g.materials:
        if mat.name == 'Gabi_Paupières':
            mat.pbrMetallicRoughness.baseColorFactor = list(PEAU_PAUPIERES) + [1.0]
            print('matériau Gabi_Paupières : couleur de la peau voisine', PEAU_PAUPIERES)
    g.buffers[0].byteLength = len(blob)
    g.set_binary_blob(bytes(blob)); g.save(dst)
    print('ok', dst, os.path.getsize(dst), 'octets')


# ---------------------------------------------------------------- .blend (Blender en module)
def traiter_blend(chemin, valeurs):
    import bpy
    bpy.ops.wm.open_mainfile(filepath=chemin)
    noms = ['Mesh_0', 'Gabi_Paupieres_D', 'Gabi_Paupieres_G', 'Gabi_Oeil_D', 'Gabi_Oeil_G']
    obj = {n: bpy.data.objects[n] for n in noms}
    # Blender (Z haut, -Y avant) <-> glTF (Y haut, +Z avant) ; coordonnées monde de la pose de repos
    b2g = np.array([[1, 0, 0], [0, 0, 1], [0, -1, 0]], dtype=np.float64)
    maillages, W = {}, {}
    for n, o in obj.items():
        me = o.data; me.calc_loop_triangles()
        co = np.empty(len(me.vertices) * 3); me.vertices.foreach_get('co', co); co = co.reshape(-1, 3)
        M = np.array(o.matrix_world); W[n] = M
        Pw = co @ M[:3, :3].T + M[:3, 3]
        F = np.empty(len(me.loop_triangles) * 3, dtype=np.int64); me.loop_triangles.foreach_get('vertices', F)
        maillages[n] = (Pw @ b2g.T, F.reshape(-1, 3))
    if obj['Mesh_0'].data.shape_keys:
        cles = [k.name for k in obj['Mesh_0'].data.shape_keys.key_blocks[1:] if k.name not in FORMES]
        assert cles == BOUCHE, f'formes de bouche inattendues : {cles}'
    nouveaux, res = calculer(maillages)
    for n in ('Mesh_0', 'Gabi_Paupieres_D', 'Gabi_Paupieres_G'):
        o = obj[n]; me = o.data
        Minv = np.linalg.inv(W[n][:3, :3])
        if n in nouveaux:   # géométrie de repos réparée (avant d'ajouter la clé de base)
            Pw = nouveaux[n] @ b2g
            co = (Pw - W[n][:3, 3]) @ Minv.T
            me.vertices.foreach_set('co', co.astype(np.float32).ravel())
            if me.shape_keys:
                for kb in me.shape_keys.key_blocks: kb.data.foreach_set('co', co.astype(np.float32).ravel())
            me.update()
        if n != 'Mesh_0':   # couleurs de sommets des paupières ramenées au blanc (voir traiter_glb)
            for ca in me.color_attributes:
                ca.data.foreach_set('color', np.ones(len(ca.data) * 4, dtype=np.float32))
        if not me.shape_keys: o.shape_key_add(name='Basis', from_mix=False)
        for kb in [k for k in me.shape_keys.key_blocks if k.name in FORMES]: o.shape_key_remove(kb)
        base = np.empty(len(me.vertices) * 3); me.shape_keys.key_blocks[0].data.foreach_get('co', base)
        base = base.reshape(-1, 3)
        for f in FORMES:
            Dw = res[n][f] @ b2g          # glTF -> Blender (b2g est orthogonale : inverse = transposée)
            kb = o.shape_key_add(name=f, from_mix=False)
            kb.data.foreach_set('co', (base + Dw @ Minv.T).astype(np.float32).ravel())
            kb.value = float(valeurs.get(f, 0.0)); kb.slider_min = 0.0; kb.slider_max = 1.0
        print(n, 'formes :', ', '.join(f'{i}:{k.name}' for i, k in enumerate(me.shape_keys.key_blocks[1:])))
    mat = bpy.data.materials.get('Gabi_Paupières')
    if mat and mat.node_tree:
        for nd in mat.node_tree.nodes:
            if nd.type == 'BSDF_PRINCIPLED' and not nd.inputs['Base Color'].is_linked:
                nd.inputs['Base Color'].default_value = list(PEAU_PAUPIERES) + [1.0]
    bpy.ops.wm.save_mainfile(); print('ok', chemin)


def main(argv):
    repos = dict(REPOS)
    if '--repos' in argv:
        i = argv.index('--repos'); spec = argv[i + 1]; argv = argv[:i] + argv[i + 2:]
        for kv in filter(None, spec.split(',')):
            k, v = kv.split('='); assert k in FORMES, k; repos[k] = float(v)
    argv = [a for a in argv if a != '--']
    if not argv: sys.exit(__doc__ or 'usage : voir l\'en-tête du script')
    if argv[0].endswith('.blend'):
        traiter_blend(os.path.abspath(argv[0]), repos)
    else:
        if len(argv) < 2: sys.exit('usage : ajouter-expressions-gabi.py <entrée.glb> <sortie.glb>')
        traiter_glb(argv[0], argv[1], repos)


if __name__ == '__main__':
    main(sys.argv[1:])
