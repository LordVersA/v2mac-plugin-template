"""Package boundary checks, without Docker: python3 -m unittest discover -s Tests -p '*_test.py'."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
BASE = "base-cli@sha256:" + "a" * 64


class PackageTests(unittest.TestCase):
    def test_packages_and_refuses_invalid_inputs(self):
        with tempfile.TemporaryDirectory() as tmp:
            work = Path(tmp)
            plugin = work / "plugin"
            plugin.mkdir()
            manifest = json.loads((ROOT / "plugin.json").read_text())
            (plugin / "plugin.json").write_text(json.dumps(manifest))
            # Only stand in for the image build/export; exercise the real packager and hashing.
            docker = work / "docker"
            docker.write_text('#!/bin/sh\ncase "$1" in\n'
                              'image) echo "${IMAGE_ID:-sha256:' + "a" * 64 + '}";;\n'
                              'build) exit "${BUILD_EXIT:-0}";;\n'
                              'save) printf "image archive" > "$4";;\n'
                              '*) exit 99;;\nesac\n')
            docker.chmod(0o755)
            env = {**os.environ, "PATH": str(work) + os.pathsep + os.environ["PATH"]}

            def package(base=BASE, **extra):
                return subprocess.run([str(ROOT / "Scripts/package.sh"), str(plugin), base,
                                       "https://github.com/a/b/releases/download/v1/", "https://github.com/a/b", "b" * 40],
                                      cwd=work, env={**env, **extra}, capture_output=True, text=True)

            result = package()
            self.assertEqual(result.returncode, 0, result.stderr)
            built = json.loads((work / "dist/plugin.json").read_text())
            layer = built["layers"][0]
            self.assertEqual(built["from"], BASE)
            self.assertEqual(built["source"]["commit"], "b" * 40)
            self.assertEqual(layer["sha256"], hashlib.sha256(b"image archive").hexdigest())
            self.assertEqual(layer["size"], len(b"image archive"))
            self.assertTrue(layer["url"].endswith("/my-plugin-0.1.0.tar"))
            self.assertNotEqual(package("ghcr.io/a/base:latest").returncode, 0)
            self.assertNotEqual(package("ghcr.io/a/base@sha256:REPLACE").returncode, 0)
            self.assertNotEqual(package(IMAGE_ID="sha256:" + "b" * 64).returncode, 0)
            self.assertNotEqual(package(BUILD_EXIT="1").returncode, 0)
            manifest["id"] = "../../escape"
            (plugin / "plugin.json").write_text(json.dumps(manifest))
            self.assertNotEqual(package().returncode, 0)


if __name__ == "__main__":
    unittest.main()
