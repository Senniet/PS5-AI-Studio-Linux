import os
import shutil
import tempfile
import unittest
import sys
from pathlib import Path

import numpy as np
import gguf
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "apps" / "server"))
from validate_gguf import validate

class GGUFStructureTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="ps5-ai-studio-gguf-")
        self.addCleanup(self.temp.cleanup)
        self.valid = Path(self.temp.name) / "valid.gguf"
        writer = gguf.GGUFWriter(self.valid, arch="llama")
        writer.add_tensor("layer.0.weight", np.array([1, 2, 3, 4], dtype=np.float32))
        writer.add_tensor("layer.1.weight", np.array([5, 6, 7, 8], dtype=np.float32))
        writer.write_header_to_file()
        writer.write_kv_data_to_file()
        writer.write_tensors_to_file()
        writer.close()

    def test_valid_tensor_directory(self):
        result = validate(self.valid)
        self.assertEqual(result["tensors"], 2)
        self.assertLessEqual(result["lastTensorEnd"], result["fileSize"])

    def test_truncated_tensor_payload_is_rejected(self):
        target = Path(self.temp.name) / "truncated.gguf"
        shutil.copyfile(self.valid, target)
        last_tensor_end = validate(self.valid)["lastTensorEnd"]
        with target.open("r+b") as f:
            f.truncate(last_tensor_end - 1)
        with self.assertRaises(Exception):
            validate(target)

    def test_overlapping_tensor_offsets_are_rejected(self):
        target = Path(self.temp.name) / "overlap.gguf"
        shutil.copyfile(self.valid, target)
        reader = gguf.GGUFReader(target)
        second = reader.tensors[1].field
        offset_field = second.offset + sum(int(part.nbytes) for part in second.parts[:-1])
        del reader
        with target.open("r+b") as f:
            f.seek(offset_field)
            f.write((0).to_bytes(8, "little"))
        with self.assertRaisesRegex(ValueError, "overlapping tensor data"):
            validate(target)

if __name__ == "__main__":
    unittest.main()
