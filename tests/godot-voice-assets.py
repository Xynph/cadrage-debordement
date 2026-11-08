"""Exercise the actual release asset validator, with no network or asset edits."""
import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
import wave

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("native_build", ROOT / "scripts/build-godot-prototype.py")
build = importlib.util.module_from_spec(spec)
spec.loader.exec_module(build)


class VoiceAssets(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="cd-voice-assets-")
        self.project = Path(self.tmp.name)
        self.voice = self.project / "guide/assets/voice"
        self.voice.mkdir(parents=True)
        with wave.open(str(self.voice / "clip.wav"), "wb") as wav:
            wav.setnchannels(1)
            wav.setsampwidth(2)
            wav.setframerate(24000)
            wav.writeframes(bytes(48000))
        (self.voice / "CREDITS.txt").write_text("Fixture de validation.", encoding="utf-8")
        (self.voice / "LICENSE-test.txt").write_text("Fixture originale.", encoding="utf-8")
        self.dialogues = {"pages": [{"fragments": [
            {"id": "recorded", "text": "Une bulle enregistrée."},
            {"id": "waiting", "text": "Un nouveau conseil.", "audioStatus": "pending"}]}]}
        text = self.dialogues["pages"][0]["fragments"][0]["text"]
        self.manifest = {"clips": [{"id": "recorded", "text": text,
            "text_sha256": hashlib.sha256(text.encode()).hexdigest(),
            "file": "clip.wav", "sha256": build.digest(self.voice / "clip.wav")} ]}
        self.write()

    def tearDown(self):
        self.tmp.cleanup()

    def write(self):
        (self.project / "guide/dialogues.json").write_text(json.dumps(self.dialogues), encoding="utf-8")
        (self.voice / "manifest.json").write_text(json.dumps(self.manifest), encoding="utf-8")

    def rejects(self):
        self.write()
        with self.assertRaises((AssertionError, KeyError)):
            build.validate_voice_assets(self.project)

    def test_explicit_pending(self):
        self.assertEqual(build.validate_voice_assets(self.project), {
            "status": "provisional", "total": 2, "recorded": 1, "pending": 1, "pendingIds": ["waiting"]})

    def test_missing_recording_must_be_declared(self):
        del self.dialogues["pages"][0]["fragments"][1]["audioStatus"]
        self.rejects()

    def test_old_recording_must_match_text(self):
        self.dialogues["pages"][0]["fragments"][0]["text"] = "Le texte a changé."
        self.rejects()

    def test_no_stale_or_duplicate_id(self):
        for field in ("obsolete", "recorded"):
            with self.subTest(field=field):
                item = copy.deepcopy(self.manifest["clips"][0])
                item["id"] = field
                self.manifest["clips"].append(item)
                self.rejects()
                self.manifest["clips"].pop()

    def test_invalid_hash_or_filename(self):
        for key, value in (("text_sha256", "0" * 64), ("sha256", "0" * 64), ("file", "../clip.wav")):
            with self.subTest(key=key):
                previous = self.manifest["clips"][0][key]
                self.manifest["clips"][0][key] = value
                self.rejects()
                self.manifest["clips"][0][key] = previous

    def test_actual_shipped_coverage(self):
        coverage = build.validate_voice_assets(build.PROJECT)
        self.assertEqual((coverage["recorded"], coverage["pending"], coverage["total"]), (38, 36, 74))


if __name__ == "__main__":
    unittest.main()
