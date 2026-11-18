"""Prépare les bruits de match enregistrés (ElevenLabs, 18/11/2026) pour Godot.

Usage : python -I scripts/prepare-bruits-match.py <dossier des MP3 choisis>
Dépendances : numpy, soundfile (libsndfile >= 1.1, lecture MP3 et écriture OGG Vorbis).

Pour chaque son retenu par Léo : décodage, mono pour l'arbitre, les impacts et le ballon,
coupe du silence de tête et fondu de fin pour les sons ponctuels, raccord en fondu
à puissance constante pour les boucles (fin fondue dans le début, aucune couture),
niveau fixé (voir NIVEAUX), écriture en OGG Vorbis et manifest.json (SHA-256 des
sources et des fichiers produits). Le rendu n'est pas bit à bit garanti d'une version
de libsndfile à l'autre : les fichiers publiés font foi, ce script documente le traitement.
"""
import hashlib, json, os, sys
import numpy as np
import soundfile as sf

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEST = os.path.join(ROOT, 'native', 'godot', 'audio', 'assets', 'match')
# fichier publié : (source, mono, boucle, mesure, niveau visé en dBFS)
# Mesure « actif » : RMS des 50 % de fenêtres de 50 ms les plus fortes (nappes, foule).
# Mesure « crete » : RMS de la fenêtre de 50 ms la plus forte (sons brefs). Les sons
# brefs sont tous fixés à -16 dBFS de crête (référence commune) et mixés par les gains
# d'EFFECTS dans soundscape.gd ; la foule et l'ambiance portent leur niveau de mixage
# final (leurs lecteurs restent à gain 1, voix exceptée).
SONS = {
    'sifflet-court.ogg': ('sifflet-court-v2.mp3', True, False, 'crete', -16.0),
    'sifflet-fin.ogg': ('sifflet-fin-v2.mp3', True, False, 'crete', -16.0),
    'plaquage.ogg': ('plaquage-v3.mp3', True, False, 'crete', -16.0),
    'melee.ogg': ('melee-v1.mp3', True, False, 'crete', -16.0),
    'coup-de-pied.ogg': ('coup-de-pied-v1.mp3', True, False, 'crete', -16.0),
    'ambiance-stade-1.ogg': ('ambiance-stade-v1.mp3', False, True, 'actif', -39.0),
    'ambiance-stade-2.ogg': ('ambiance-stade-v3.mp3', False, True, 'actif', -39.0),
    'foule-rumeur.ogg': ('foule-rumeur-v2.mp3', False, True, 'actif', -31.0),
    'foule-essai.ogg': ('foule-essai-v1.mp3', False, False, 'actif', -27.0),
    'foule-decue.ogg': ('foule-decue-v1.mp3', False, False, 'actif', -29.0),
    'applaudissements.ogg': ('applaudissements-v1.mp3', False, False, 'actif', -32.0),
}
PEAK_MAX = 10 ** (-1.0 / 20)
LOOP_FADE_S = 0.5


def windows(x, rate):
    mono = x.mean(axis=1)
    w = int(rate * 0.05)
    n = max(1, len(mono) // w)
    return np.sqrt((mono[:n * w].reshape(n, w) ** 2).mean(axis=1) + 1e-20)


def level(x, rate, kind):
    st = windows(x, rate)
    if kind == 'crete':
        return float(st.max())
    top = np.sort(st)[::-1][:max(1, len(st) // 2)]
    return float(np.sqrt((top ** 2).mean()))


def db(v):
    return 20 * np.log10(max(v, 1e-12))


def one_shot(x, rate):
    st = windows(x, rate)
    floor = st.max() * 10 ** (-45 / 20)
    w = int(rate * 0.05)
    start = max(0, int(np.argmax(st > floor)) * w - int(rate * 0.005))
    last = len(st) - 1 - int(np.argmax(st[::-1] > st.max() * 10 ** (-55 / 20)))
    end = min(len(x), (last + 1) * w)
    x = x[start:end].copy()
    fin, fout = int(rate * 0.003), min(int(rate * 0.04), len(x) // 4)
    x[:fin] *= np.linspace(0, 1, fin)[:, None]
    x[-fout:] *= np.linspace(1, 0, fout)[:, None]
    return x


def seamless(x, rate):
    # Raccord à puissance constante : la fin (LOOP_FADE_S) se fond dans le début.
    f = int(rate * LOOP_FADE_S)
    t = np.linspace(0, np.pi / 2, f)[:, None]
    head = x[:f] * np.sin(t) + x[-f:] * np.cos(t)
    return np.concatenate([head, x[f:-f]])


def sha(path):
    return hashlib.sha256(open(path, 'rb').read()).hexdigest()


def main(src):
    os.makedirs(DEST, exist_ok=True)
    rows = []
    for name, (source, mono, loop, kind, target) in SONS.items():
        path = os.path.join(src, source)
        x, rate = sf.read(path, always_2d=True, dtype='float64')
        if mono:
            x = x.mean(axis=1, keepdims=True)
        x = seamless(x, rate) if loop else one_shot(x, rate)
        gain = min(10 ** (target / 20) / level(x, rate, kind), PEAK_MAX / np.abs(x).max())
        x = x * gain
        out = os.path.join(DEST, name)
        sf.write(out, x, rate, format='OGG', subtype='VORBIS', compression_level=0.6)
        y, _ = sf.read(out, always_2d=True)
        rows.append({
            'file': name, 'source': source, 'source_sha256': sha(path), 'loop': loop,
            'channels': int(x.shape[1]), 'sample_rate': int(rate), 'duration_seconds': round(len(x) / rate, 3),
            'measure': kind, 'target_dbfs': target, 'level_dbfs': round(db(level(y, rate, kind)), 1),
            'peak_dbfs': round(db(float(np.abs(y).max())), 1), 'gain_db': round(db(gain), 1),
            'bytes': os.path.getsize(out), 'sha256': sha(out)})
        print(f"{name:22s} {rows[-1]['duration_seconds']:6.2f}s gain {rows[-1]['gain_db']:+6.1f} dB -> {kind} {rows[-1]['level_dbfs']} dBFS, crête {rows[-1]['peak_dbfs']} dBFS, {rows[-1]['bytes']} o")
    manifest = {
        'version': 1,
        'origin': 'ElevenLabs Sound Effects (eleven_text_to_sound_v3), générés le 18/11/2026, offre Starter (usage commercial autorisé)',
        'prompts': 'docs/provenance/elevenlabs-bruits-match-20261118.json',
        'processor': 'scripts/prepare-bruits-match.py',
        'recordings': True, 'third_party_assets': True, 'format': 'OGG Vorbis',
        'sounds': rows,
    }
    with open(os.path.join(DEST, 'manifest.json'), 'w', encoding='utf-8', newline='\n') as f:
        f.write(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n')


if __name__ == '__main__':
    main(sys.argv[1])
