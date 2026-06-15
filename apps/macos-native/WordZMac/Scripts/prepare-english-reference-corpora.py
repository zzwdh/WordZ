#!/usr/bin/env python3
"""Prepare BNC/OANC source packages as WordZ-importable text folders.

This script converts locally downloaded corpus archives/directories into plain
UTF-8 .txt files. It does not download corpora or accept licences on the user's
behalf.
"""

from __future__ import annotations

import argparse
import io
import json
import re
import sys
import zipfile
from dataclasses import dataclass
from datetime import datetime, timezone
from html import unescape
from pathlib import Path
from typing import Iterable, Iterator
from xml.etree import ElementTree


BNC_OUTPUT_NAME = "BNC1994 English Reference"
OANC_OUTPUT_NAME = "OANC American English Reference"
TEXT_EXTENSIONS = {".txt", ".text"}
XML_EXTENSIONS = {".xml"}
SKIP_NAME_PARTS = {
    "readme",
    "license",
    "licence",
    "copying",
    "index",
    "manifest",
    "dtd",
    "schema",
}
NO_SPACE_BEFORE = set(".,;:!?%)]}’”")
NO_SPACE_AFTER = set("([{£$#“‘")


@dataclass(frozen=True)
class PreparedDocument:
    relative_name: str
    text: str


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Convert local BNC1994 and OANC packages into WordZ reference-corpus text folders."
    )
    parser.add_argument("--bnc", type=Path, help="Path to BNC1994 zip or extracted directory.")
    parser.add_argument("--oanc", type=Path, help="Path to OANC zip or extracted directory.")
    parser.add_argument("--output", type=Path, required=True, help="Output directory for prepared text folders.")
    parser.add_argument("--min-chars", type=int, default=80, help="Skip documents shorter than this many characters.")
    parser.add_argument("--limit", type=int, default=0, help="Optional per-corpus document limit for smoke tests.")
    args = parser.parse_args()

    if not args.bnc and not args.oanc:
        parser.error("provide --bnc and/or --oanc")

    args.output.mkdir(parents=True, exist_ok=True)
    manifest: dict[str, object] = {
        "generatedAt": datetime.now(timezone.utc).isoformat(),
        "output": str(args.output),
        "corpora": [],
    }

    if args.bnc:
        bnc_docs = list(iter_bnc_documents(args.bnc, args.min_chars, args.limit))
        bnc_dir = args.output / BNC_OUTPUT_NAME
        write_documents(bnc_dir, bnc_docs)
        manifest["corpora"].append(
            {
                "name": BNC_OUTPUT_NAME,
                "source": str(args.bnc),
                "documentCount": len(bnc_docs),
                "licenceNote": "BNC1994 is Restricted Use under the BNC User Licence. Do not redistribute prepared text output unless your licence allows it.",
            }
        )
        print(f"Prepared {len(bnc_docs)} BNC documents: {bnc_dir}")

    if args.oanc:
        oanc_docs = list(iter_oanc_documents(args.oanc, args.min_chars, args.limit))
        oanc_dir = args.output / OANC_OUTPUT_NAME
        write_documents(oanc_dir, oanc_docs)
        manifest["corpora"].append(
            {
                "name": OANC_OUTPUT_NAME,
                "source": str(args.oanc),
                "documentCount": len(oanc_docs),
                "licenceNote": "OANC is intended as an open American English reference corpus. Keep upstream attribution and licence notes with local exports.",
            }
        )
        print(f"Prepared {len(oanc_docs)} OANC documents: {oanc_dir}")

    manifest_path = args.output / "wordz-reference-corpora-manifest.json"
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote manifest: {manifest_path}")
    return 0


def iter_bnc_documents(source: Path, min_chars: int, limit: int) -> Iterator[PreparedDocument]:
    count = 0
    for name, data in iter_source_files(source, XML_EXTENSIONS):
        normalized = name.replace("\\", "/")
        if "/Texts/" not in normalized and not normalized.startswith("Texts/"):
            continue
        text = extract_bnc_xml_text(data)
        if len(text) < min_chars:
            continue
        yield PreparedDocument(relative_name=output_name_for(normalized), text=text)
        count += 1
        if limit and count >= limit:
            return


def iter_oanc_documents(source: Path, min_chars: int, limit: int) -> Iterator[PreparedDocument]:
    count = 0
    text_candidates = list(iter_source_files(source, TEXT_EXTENSIONS))
    if text_candidates:
        for name, data in text_candidates:
            if should_skip_source_name(name):
                continue
            text = decode_text(data)
            if len(text) < min_chars:
                continue
            yield PreparedDocument(relative_name=output_name_for(name), text=normalize_text(text))
            count += 1
            if limit and count >= limit:
                return
        return

    for name, data in iter_source_files(source, XML_EXTENSIONS):
        if should_skip_source_name(name):
            continue
        text = extract_generic_xml_text(data)
        if len(text) < min_chars:
            continue
        yield PreparedDocument(relative_name=output_name_for(name), text=text)
        count += 1
        if limit and count >= limit:
            return


def iter_source_files(source: Path, extensions: set[str]) -> Iterator[tuple[str, bytes]]:
    if source.is_file() and source.suffix.lower() == ".zip":
        with zipfile.ZipFile(source) as archive:
            for info in sorted(archive.infolist(), key=lambda item: item.filename):
                if info.is_dir():
                    continue
                if Path(info.filename).suffix.lower() not in extensions:
                    continue
                yield info.filename, archive.read(info)
        return

    if source.is_dir():
        for path in sorted(source.rglob("*")):
            if path.is_file() and path.suffix.lower() in extensions:
                yield str(path.relative_to(source)), path.read_bytes()
        return

    raise FileNotFoundError(f"Source is not a zip file or directory: {source}")


def extract_bnc_xml_text(data: bytes) -> str:
    tokens: list[str] = []
    for event, element in ElementTree.iterparse(io.BytesIO(data), events=("end",)):
        tag = local_name(element.tag)
        if tag in {"w", "c"} and element.text:
            tokens.append(unescape(element.text))
        element.clear()
    return normalize_token_stream(tokens)


def extract_generic_xml_text(data: bytes) -> str:
    tokens: list[str] = []
    try:
        for event, element in ElementTree.iterparse(io.BytesIO(data), events=("end",)):
            if element.text and local_name(element.tag) not in {"header", "metadata"}:
                tokens.extend(element.text.split())
            if element.tail:
                tokens.extend(element.tail.split())
            element.clear()
    except ElementTree.ParseError:
        return normalize_text(strip_xml_tags(decode_text(data)))
    return normalize_text(" ".join(tokens))


def normalize_token_stream(tokens: Iterable[str]) -> str:
    output: list[str] = []
    previous = ""
    for raw in tokens:
        token = raw.strip()
        if not token:
            continue
        if not output:
            output.append(token)
        elif token in NO_SPACE_BEFORE or token.startswith("'"):
            output[-1] += token
        elif previous in NO_SPACE_AFTER:
            output[-1] += token
        else:
            output.append(token)
        previous = token
    return normalize_text(" ".join(output))


def normalize_text(text: str) -> str:
    text = text.replace("\r\n", "\n").replace("\r", "\n")
    text = re.sub(r"[ \t\f\v]+", " ", text)
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text.strip() + "\n"


def decode_text(data: bytes) -> str:
    for encoding in ("utf-8", "utf-16", "latin-1"):
        try:
            return data.decode(encoding)
        except UnicodeDecodeError:
            continue
    return data.decode("utf-8", errors="replace")


def strip_xml_tags(text: str) -> str:
    return re.sub(r"<[^>]+>", " ", text)


def local_name(tag: str) -> str:
    return tag.rsplit("}", 1)[-1]


def should_skip_source_name(name: str) -> bool:
    lowered = Path(name).name.lower()
    return any(part in lowered for part in SKIP_NAME_PARTS)


def output_name_for(source_name: str) -> str:
    normalized = source_name.replace("\\", "/")
    stem_parts = [
        re.sub(r"[^A-Za-z0-9._-]+", "-", part)
        for part in Path(normalized).with_suffix("").parts
        if part not in {"Texts", "data", "corpus"}
    ]
    stem = "__".join(part.strip("-") for part in stem_parts if part.strip("-"))
    if not stem:
        stem = "document"
    return f"{stem}.txt"


def write_documents(output_dir: Path, documents: Iterable[PreparedDocument]) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)
    for existing in output_dir.glob("*.txt"):
        existing.unlink()
    for document in documents:
        (output_dir / document.relative_name).write_text(document.text, encoding="utf-8")


if __name__ == "__main__":
    sys.exit(main())
