"""
Generates INFORME_FINAL_template.docx from INFORME_FINAL_template.md.
Reuses build_docx.py rendering engine.
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from build_docx import build_document

MD_PATH  = Path(__file__).parent / "INFORME_FINAL_template.md"
OUT_PATH = Path(__file__).parent / "INFORME_FINAL_template.docx"

if __name__ == "__main__":
    md_text = MD_PATH.read_text(encoding="utf-8")
    doc = build_document(md_text)
    doc.save(OUT_PATH)
    print(f"[OK] Saved: {OUT_PATH}")
