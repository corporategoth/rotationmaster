"""Asset and release-manifest checks use only the Python standard library."""
import fnmatch
import hashlib
import importlib.util
import json
import struct
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('artwork_generator', ROOT / 'tools/generate_artwork_catalog.py')
GENERATOR = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(GENERATOR)


class ArtworkTests(unittest.TestCase):
    def manifests(self):
        for directory, count, sizes in [('Assets/Conditions/v2', 128, (64, 128)),
                                         ('Assets/Overlays/v1', 9, (128, 256))]:
            yield directory, count, sizes, json.loads((ROOT / directory / 'provenance.json').read_text())['entries']

    def test_selected_originals_and_rgba_runtime(self):
        for directory, count, sizes, entries in self.manifests():
            self.assertEqual(len(entries), count)
            hashes, pixels = set(), set()
            for entry in entries:
                raw = (ROOT / directory / 'source' / (entry['name'] + '.png')).read_bytes()
                digest = hashlib.sha256(raw).hexdigest();hashes.add(digest)
                self.assertEqual(digest, entry['source_sha256'])
                self.assertEqual(raw[:8], b'\x89PNG\r\n\x1a\n')
                self.assertEqual(raw[24:26], b'\x08\x06', 'original must be RGBA8')
                for size in sizes:
                    suffix = '' if size == max(sizes) else '-' + str(size)
                    path = ROOT / directory / (entry['name'] + suffix + '.tga')
                    data = path.read_bytes();width, height = struct.unpack_from('<HH', data, 12)
                    self.assertEqual((width, height, data[2], data[16], data[17] & 15), (size, size, 2, 32, 8), str(path))
                    payload = data[18 + data[0]:18 + data[0] + size * size * 4]
                    self.assertEqual(len(payload), size * size * 4)
                    alpha = payload[3::4];self.assertEqual(min(alpha), 0);self.assertGreater(max(alpha), 0)
                    for corner in (0, size - 1, size * (size - 1), size * size - 1):
                        self.assertEqual(alpha[corner], 0, str(path))
                    if size == max(sizes):
                        pixels.add(hashlib.sha256(payload).hexdigest())
            self.assertEqual(len(hashes), count);self.assertEqual(len(pixels), count)

    def test_catalog_and_release_rules_are_current(self):
        self.assertEqual((ROOT / 'Data/artwork.lua').read_text(), GENERATOR.generate())
        self.assertEqual((ROOT / '.pkgmeta').read_text(), GENERATOR.release_metadata())

    def test_release_package_matches_case_sensitive_root_toc(self):
        # The release packager resolves package-as + flavor suffix + '.toc'
        # case-sensitively on Linux; compare actual directory entry names too.
        entries = [line.split(':', 1)[1].strip() for line in
                   (ROOT / '.pkgmeta').read_text().splitlines()
                   if line.startswith('package-as:')]
        self.assertEqual(len(entries), 1)
        names = {path.name for path in ROOT.iterdir() if path.is_file()}
        self.assertIn(entries[0] + '.toc', names,
                      'package-as must name the actual root TOC with matching case')

    def test_release_excludes_legacy_qa_without_excluding_runtime_or_provenance(self):
        qa = sorted(str(path.relative_to(ROOT)) for path in
                    (ROOT / 'Assets/Conditions/qa').rglob('*') if path.is_file())
        self.assertTrue(qa, 'legacy QA fixture must contain actual files')
        for label, text in [('generated', GENERATOR.release_metadata()),
                            ('committed', (ROOT / '.pkgmeta').read_text())]:
            items = [line[4:] for line in text.splitlines() if line.startswith('  - ')]
            patterns = [item + '/*' if (ROOT / item).is_dir() else item for item in items]
            def ignored(path):
                return any(fnmatch.fnmatchcase(path, pattern) for pattern in patterns)
            self.assertEqual([path for path in qa if not ignored(path)], [], label + ' ships legacy QA')
            for directory, _, sizes, entries in self.manifests():
                for entry in entries:
                    for size in sizes:
                        suffix = '' if size == max(sizes) else '-' + str(size)
                        self.assertFalse(ignored(f"{directory}/{entry['name']}{suffix}.tga"))
                self.assertFalse(ignored(directory + '/provenance.json'))
                self.assertFalse(ignored(directory + '/README.md'))

    def test_release_keeps_selected_runtime_and_excludes_originals_and_superseded_art(self):
        items = [line[4:] for line in GENERATOR.release_metadata().splitlines() if line.startswith('  - ')]
        patterns = [item + '/*' if (ROOT / item).is_dir() else item for item in items]
        def ignored(path):
            return any(fnmatch.fnmatchcase(path, pattern) for pattern in patterns)
        for directory, _, sizes, entries in self.manifests():
            selected = set()
            for entry in entries:
                for size in sizes:
                    suffix = '' if size == max(sizes) else '-' + str(size)
                    name = f"{directory}/{entry['name']}{suffix}.tga";selected.add(name)
                    self.assertFalse(ignored(name), name)
                self.assertTrue(ignored(f"{directory}/source/{entry['name']}.png"))
            for path in (ROOT / directory).glob('*.tga'):
                relative = str(path.relative_to(ROOT))
                self.assertEqual(ignored(relative), relative not in selected, relative)
            self.assertFalse(ignored(directory + '/provenance.json'))
            self.assertFalse(ignored(directory + '/README.md'))
        for path in ('Assets/Conditions/v2/zonepvp.tga', 'Assets/Conditions/v2/zonepvp-64.tga'):
            self.assertTrue(ignored(path), path)
        for line in (ROOT / 'RotationMaster.toc').read_text().splitlines():
            if line and not line.startswith('#'):
                self.assertFalse(ignored(line), 'runtime loader excluded: ' + line)


if __name__ == '__main__':
    unittest.main()
