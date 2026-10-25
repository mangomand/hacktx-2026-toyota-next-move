import json
import struct
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class VehicleAssetTests(unittest.TestCase):
    def test_reveal_manifest_has_bounded_revisioned_anchors(self):
        manifest = json.loads((ROOT / "assets" / "reveal-surfaces.json").read_text())
        self.assertEqual(manifest["revision"], "crown-reveal-2.0")
        self.assertEqual(len(manifest["anchors"]), 8)
        for anchor in manifest["anchors"]:
            weights = anchor["barycentric"]
            self.assertEqual(len(anchor["triangleVertexIndices"]), 3)
            self.assertEqual(len(weights), 3)
            self.assertTrue(all(0 <= value <= 1 for value in weights))
            self.assertAlmostEqual(sum(weights), 1.0, places=6)
            self.assertEqual(len(anchor["surfaceNormal"]), 3)
            self.assertGreater(sum(value * value for value in anchor["surfaceNormal"]), 1e-6)

    def test_glb_contains_only_revisioned_anchor_nodes(self):
        raw = (ROOT / "assets" / "nextmove-crown.glb").read_bytes()
        magic, version, total_length = struct.unpack_from("<4sII", raw, 0)
        self.assertEqual(magic, b"glTF")
        self.assertEqual(version, 2)
        self.assertEqual(total_length, len(raw))
        offset = 12
        json_chunk = None
        while offset < len(raw):
            length, chunk_type = struct.unpack_from("<II", raw, offset)
            offset += 8
            chunk = raw[offset : offset + length]
            offset += length
            if chunk_type == 0x4E4F534A:
                json_chunk = json.loads(chunk.decode("utf-8"))
                break
        self.assertIsNotNone(json_chunk)
        nodes = json_chunk["nodes"]
        self.assertFalse(any(node.get("name", "").startswith("REVIEW_ONLY_") for node in nodes))
        anchors = [node for node in nodes if node.get("name", "").startswith("anchor-")]
        self.assertEqual(len(anchors), 8)
        self.assertTrue(all(node.get("extras", {}).get("assetRevision") == "crown-reveal-2.0" for node in anchors))


if __name__ == "__main__":
    unittest.main()
