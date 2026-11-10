"""运行 AHK 配置测试，并检查 Python 与 AHK 的 JSON 文件互读。"""

import json
import subprocess
import sys
import tempfile
from pathlib import Path


def main():
    root = Path(__file__).resolve().parents[1]
    executable = Path(sys.argv[1]).resolve()
    temporary_root = root / "tmp"
    temporary_root.mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="json_interop_", dir=temporary_root) as directory:
        fixture = Path(directory) / "python.json"
        data = {
            "text": '中文 한국어 😀 "引号" \\ 路径\n\t\r',
            "literals": [True, False, None],
            "number": -12.5,
            "numeric_string": "001",
            "nested": {"items": ["中文", {}, []]},
        }
        # 使用 ASCII 转义，验证 \uXXXX 和 UTF-16 代理对。
        fixture.write_text(json.dumps(data, ensure_ascii=True), encoding="utf-8")
        result = subprocess.run(
            [str(executable), "/ErrorStdOut=UTF-8", str(root / "tests/test_json_config.ahk"), str(fixture)],
            cwd=root,
            capture_output=True,
            text=True,
            encoding="utf-8",
            timeout=30,
        )
        if result.returncode:
            raise RuntimeError(result.stdout + result.stderr)
        print(result.stdout, end="")
        output = Path(str(fixture) + ".roundtrip.json")
        raw = output.read_bytes()
        assert not raw.startswith(b"\xef\xbb\xbf"), "JSON 应为无 BOM 的 UTF-8"
        restored = json.loads(raw.decode("utf-8"))
        # 沿用 JsonGo 的 AHK 表示：布尔值为 1/0，null 为空字符串。
        data["literals"] = [1, 0, ""]
        assert restored == data, "Python → AHK → Python 的内容不一致"
        print("PASS: Python/AHK JSON interoperability")


if __name__ == "__main__":
    main()
