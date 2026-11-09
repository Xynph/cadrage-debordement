#!/usr/bin/env python3
"""Rejoue les contrôles d'animation dans un nouveau dossier de preuves.

Aucun téléchargement, import/staging automatique ou remplacement d'asset. Les
phases Godot sont explicites : --candidate et/ou --reader-project avec --godot.
Exit 0 : toutes phases demandées reçues ; 1 : échec ; 2 : préflight refusé.
Une réception partielle reste déclarée partial, avec phases not_run visibles.
"""
import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import re
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[2]
TOOLS = Path(__file__).resolve().parent


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest() if path.is_file() else None


def write_json(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2, allow_nan=False) + '\n', encoding='utf-8')


def validate_reader_artifact(report, expected_hash):
    """Une assertion de lecteur favorable doit porter sur l'asset demandé."""
    if not isinstance(report, dict) or report.get('schema') != 'oval-animation-reader/v1' or report.get('failures') != [] or type(report.get('passed')) is not int or report['passed'] <= 0:
        raise ValueError('Verdict lecteur absent, incomplet ou en échec')
    metrics = report.get('metrics')
    loaded_hash = metrics.get('loaded_asset_sha256') if isinstance(metrics, dict) else None
    if expected_hash is None or loaded_hash != expected_hash:
        raise ValueError('Le lecteur ne porte pas sur le GLB demandé : empreinte stagée différente ou absente')


def validate_skin_artifact(report, expected_clips):
    # Un verdict favorable doit couvrir tous les clips et points de la source.
    if not isinstance(report, dict):
        raise ValueError('Verdict skin : objet JSON attendu')
    samples = report.get('samples', [])
    if not isinstance(samples, list) or not all(isinstance(row, dict) for row in samples):
        raise ValueError('Verdict skin : échantillons incomplets')
    counts = {clip: sum(row.get('clip') == clip for row in samples) for clip in expected_clips}
    coverage = expected_clips and {row.get('clip') for row in samples} == expected_clips and all(count >= 9 for count in counts.values())
    maximum = report.get('max_skinned_distance')
    threshold = report.get('threshold')
    numeric = type(maximum) in (int, float) and type(threshold) in (int, float) and math.isfinite(maximum) and math.isfinite(threshold)
    points = report.get('source_points')
    if (report.get('passed') is not True or not coverage or report.get('unmatched') != 0
            or type(points) is not int or points <= 0 or report.get('compared_vertices_per_pose') != points
            or not numeric or threshold <= 0 or maximum > threshold):
        raise ValueError('Comparaison skin non reçue ou couverture des clips/vertices incomplète')


def run(args):
    if args.out.is_symlink():
        raise ValueError('Le dossier de preuves ne peut pas être un lien symbolique')
    proof = args.out.resolve()
    inputs = [args.source.resolve()]
    if args.candidate:
        inputs.append(args.candidate.resolve())
    if proof == ROOT or ROOT in proof.parents:
        raise ValueError('Le dossier de preuves doit rester hors du dépôt source')
    if args.reader_project and (proof == args.reader_project.resolve() or args.reader_project.resolve() in proof.parents):
        raise ValueError('Le dossier de preuves doit rester hors du projet lecteur')
    if proof.exists() or proof.is_symlink():
        raise ValueError('Le dossier de preuves doit être nouveau et inexistant')
    if any(path == proof or proof in path.parents for path in inputs):
        raise ValueError('Une entrée ne peut pas se trouver dans le dossier de preuves')
    if args.reader_project and not args.godot:
        raise ValueError('--reader-project exige --godot explicite')
    if args.candidate and not args.godot:
        raise ValueError('--candidate exige --godot explicite')
    if args.godot and not (args.candidate or args.reader_project):
        raise ValueError('--godot exige --candidate ou --reader-project pour définir le travail demandé')
    proof.mkdir(parents=True, exist_ok=False)
    source = args.source.resolve()
    candidate = args.candidate.resolve() if args.candidate else None
    before = {str(path): digest(path) for path in inputs}
    checks = []
    env = dict(os.environ)
    # Un runner lancé par node:test doit créer une nouvelle suite TAP autonome.
    env.pop('NODE_TEST_CONTEXT', None)
    for name in ('XDG_DATA_HOME', 'XDG_CONFIG_HOME', 'XDG_CACHE_HOME'):
        env[name] = str(proof / 'runtime' / name.lower())
        Path(env[name]).mkdir(parents=True)
    if os.name == 'nt':
        for name in ('APPDATA', 'LOCALAPPDATA'):
            env[name] = str(proof / 'runtime' / name.lower())
            Path(env[name]).mkdir(parents=True)
    env['PYTHON'] = sys.executable

    def phase(name, command, validate=None, extra_env=None):
        start = time.monotonic()
        row = {'name': name, 'status': 'fail', 'requested': True, 'command': list(map(str, command))}
        try:
            process = subprocess.run(row['command'], cwd=ROOT, env={**env, **(extra_env or {})},
                                     capture_output=True, text=True, timeout=args.timeout)
            (proof / f'{name}.stdout.log').write_text(process.stdout, encoding='utf-8')
            (proof / f'{name}.stderr.log').write_text(process.stderr, encoding='utf-8')
            row['exit_code'] = process.returncode
            row['stdout_log'] = f'{name}.stdout.log'
            row['stderr_log'] = f'{name}.stderr.log'
            if process.returncode != 0:
                row['error'] = f'exit {process.returncode}'
            elif validate:
                validate(process)
                row['status'] = 'pass'
            else:
                row['status'] = 'pass'
        except (OSError, ValueError, KeyError, TypeError, subprocess.TimeoutExpired) as error:
            row['error'] = str(error)
            row['timed_out'] = isinstance(error, subprocess.TimeoutExpired)
        row['seconds'] = round(time.monotonic() - start, 3)
        checks.append(row)
        return row['status'] == 'pass'

    def artifact_json(name):
        path = proof / name
        if not path.is_file():
            raise ValueError(f'Preuve absente : {name}')
        return json.loads(path.read_text(encoding='utf-8'))

    def inventory_ok(name):
        def validate(_process):
            report = artifact_json(name)
            if report.get('schema') != 'oval.animation-inventory.v1' or not report.get('sha256'):
                raise ValueError('Inventaire sans schéma/empreinte')
        return validate

    source_ok = phase('inventory_source', [sys.executable, TOOLS / 'inventory.py', source,
                                           '--output', proof / 'inventory-source.json'], inventory_ok('inventory-source.json'))

    def node_tests(process):
        logs = process.stdout + '\n' + process.stderr
        # Le reporter TAP garde des compteurs explicites, y compris sous Node22.
        for key in ('tests', 'pass', 'fail', 'skipped'):
            match = re.search(r'^# ' + key + r' (\d+)\s*$', logs, re.MULTILINE)
            if not match:
                raise ValueError('Compteur TAP absent : ' + key)
            value = int(match.group(1))
            if (key in ('tests', 'pass') and value == 0) or (key in ('fail', 'skipped') and value != 0):
                raise ValueError(f'Suite incomplète : {key}={value}')

    phase('tests_inventory', [args.node, '--test', '--test-reporter=tap', ROOT / 'tests/animation-pipeline.cjs'], node_tests)

    def python_tests(process):
        logs = process.stdout + '\n' + process.stderr
        match = re.search(r'Ran (\d+) tests?', logs)
        if not match or int(match.group(1)) == 0 or re.search(r'skipped[= ]', logs, re.IGNORECASE) or not re.search(r'^OK\s*$', logs, re.MULTILINE):
            raise ValueError('Suite CLI incomplète ou ignorée')

    cli_command = [sys.executable, TOOLS / 'test_compare_cli.py'] + ([] if args.godot else ['Guards'])
    phase('tests_compare_cli', cli_command, python_tests, {'CD_GODOT_EXE': args.godot} if args.godot else None)
    checks[-1]['scope'] = 'guards_and_missing_clip' if args.godot else 'guards_only_without_godot'
    phase('tests_export_guards', [sys.executable, TOOLS / 'test_export_roundtrip.py', 'ExportGuards'], python_tests)
    if args.godot:
        numeric_tests = "import sys, unittest; sys.path.insert(0, sys.argv[1]); suite=unittest.defaultTestLoader.loadTestsFromNames(['test_restore_normals','test_skin_contract']); result=unittest.TextTestRunner().run(suite); sys.exit(not result.wasSuccessful())"
        phase('tests_numeric_contract', [sys.executable, '-c', numeric_tests, TOOLS], python_tests)
    else:
        checks.append({'name': 'tests_numeric_contract', 'requested': False, 'status': 'not_run', 'reason': 'Réception numérique non demandée sans --godot explicite ; nécessite NumPy/SciPy'})
    if candidate:
        candidate_ok = phase('inventory_candidate', [sys.executable, TOOLS / 'inventory.py', candidate,
                                                    '--output', proof / 'inventory-candidate.json'], inventory_ok('inventory-candidate.json'))
        if source_ok and candidate_ok:
            def poses_ok(process):
                report = artifact_json('poses.json')
                if any(marker in process.stdout + process.stderr for marker in ('SCRIPT ERROR:', 'Parse Error:', 'ERROR:')):
                    raise ValueError('Erreur moteur dans les journaux du comparateur')
                if report.get('inputs_unchanged') is not True or report.get('candidate', {}).get('passed') is not True:
                    raise ValueError('Verdict candidat non reçu')
            phase('compare_poses', [sys.executable, TOOLS / 'compare_poses.py', source, candidate,
                                   '--godot', args.godot, '--out', proof / 'poses.json'], poses_ok)
            if (proof / 'poses.json').is_file():
                try:
                    checks[-1]['candidate_verdict'] = artifact_json('poses.json').get('candidate')
                except (OSError, ValueError):
                    checks[-1]['status'] = 'fail'
                    checks[-1]['error'] = 'Verdict candidat JSON illisible'
            def skin_ok(_process):
                expected = {row['name'] for row in artifact_json('inventory-source.json')['animations']}
                validate_skin_artifact(artifact_json('skin.json'), expected)
            phase('compare_skin', [sys.executable, TOOLS / 'compare_skin.py', source, candidate,
                                  '--out', proof / 'skin.json'], skin_ok)
            if (proof / 'skin.json').is_file():
                try:
                    checks[-1]['skin_verdict'] = {key: value for key, value in artifact_json('skin.json').items() if key != 'samples'}
                except (OSError, ValueError):
                    checks[-1]['status'] = 'fail'
                    checks[-1]['error'] = 'Verdict skin JSON illisible'
        else:
            checks.append({'name': 'compare_poses', 'requested': True, 'status': 'not_run', 'reason': 'Inventaire source ou candidat en échec'})
            checks.append({'name': 'compare_skin', 'requested': True, 'status': 'not_run', 'reason': 'Inventaire source ou candidat en échec'})
    else:
        checks.append({'name': 'inventory_candidate', 'requested': False, 'status': 'not_run', 'reason': '--candidate absent'})
        checks.append({'name': 'compare_poses', 'requested': False, 'status': 'not_run', 'reason': '--candidate absent'})
        checks.append({'name': 'compare_skin', 'requested': False, 'status': 'not_run', 'reason': '--candidate absent'})
    if args.reader_project:
        project = args.reader_project.resolve()
        if not (project / 'project.godot').is_file() or not (project / '.godot').is_dir():
            checks.append({'name': 'reader', 'requested': True, 'status': 'fail', 'error': 'Projet non préparé : project.godot et .godot requis ; aucun import automatique'})
        else:
            def reader_ok(process):
                report = artifact_json('reader.json')
                if any(marker in process.stdout + process.stderr for marker in ('SCRIPT ERROR:', 'Parse Error:', 'ERROR:')):
                    raise ValueError('Erreur moteur dans les journaux du lecteur')
                validate_reader_artifact(report, before[str(candidate if candidate else source)])
            phase('reader', [args.godot, '--headless', '--path', project, '--script', TOOLS / 'check_match_reader.gd'], reader_ok,
                  {'CD_ANIMATION_READER_RESULTS': str(proof / 'reader.json')})
    else:
        checks.append({'name': 'reader', 'requested': False, 'status': 'not_run', 'reason': '--reader-project absent'})
    after = {str(path): digest(path) for path in inputs}
    unchanged = before == after and all(value is not None for value in before.values())
    checks.append({'name': 'inputs_unchanged', 'requested': True, 'status': 'pass' if unchanged else 'fail', 'before': before, 'after': after})
    counts = {state: sum(row['status'] == state for row in checks) for state in ('pass', 'fail', 'not_run')}
    requested_ok = all(row['status'] == 'pass' for row in checks if row['requested'])
    status = 'fail' if not requested_ok else ('partial' if counts['not_run'] else 'pass')
    summary = {'schema': 'oval.animation-checks.v1', 'status': status, 'requested_checks_passed': requested_ok,
               'all_checks_executed': counts['not_run'] == 0, 'counts': counts, 'checks': checks,
               'limits': ['Contrôles headless : aucune réception graphique ou Windows.',
                          'Aucun candidat installé dans le jeu ; comparer les poses ne valide pas tous les usages du lecteur.']}
    write_json(proof / 'summary.json', summary)
    print(json.dumps(summary, ensure_ascii=False, indent=2))
    return 0 if requested_ok else 1


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out', type=Path, required=True, help='Nouveau dossier de preuves, refus si déjà présent')
    parser.add_argument('--source', type=Path, default=ROOT / 'dist/match3d/assets/quaternius-rugby-athlete.glb')
    parser.add_argument('--candidate', type=Path)
    parser.add_argument('--godot', help='Exécutable explicite pour comparaison et/ou lecteur')
    parser.add_argument('--reader-project', type=Path, help='Projet Godot déjà préparé/importé ; jamais modifié par staging')
    parser.add_argument('--node', default='node')
    parser.add_argument('--timeout', type=int, default=180, help='Limite par commande en secondes')
    args = parser.parse_args()
    if args.timeout <= 0:
        parser.error('--timeout doit être positif')
    try:
        return run(args)
    except (OSError, ValueError) as error:
        print(json.dumps({'ok': False, 'error': str(error)}, ensure_ascii=False), file=sys.stderr)
        return 2


if __name__ == '__main__':
    sys.exit(main())
