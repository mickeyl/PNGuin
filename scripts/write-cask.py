#!/usr/bin/env python3
"""Generate the cask from the final, stapled release archive."""

import argparse
import hashlib
import io
from pathlib import Path
import plistlib
import re
import sys
import zipfile


def main():
    parser = argparse.ArgumentParser(
        description="Create a PNGuin cask with the archive's version and SHA-256.",
        epilog="Run make app-release to sign, notarize and package the app first.",
    )
    parser.add_argument("--archive", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()

    try:
        archive = args.archive.read_bytes()
        with zipfile.ZipFile(io.BytesIO(archive)) as bundle:
            info = plistlib.loads(bundle.read("PNGuin.app/Contents/Info.plist"))
        version = info["CFBundleShortVersionString"]
        if not re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", version):
            raise ValueError("Expected a numeric major.minor.patch app version")
        if info["CFBundleIdentifier"] != "de.vanille.ScreenGrab":
            raise ValueError("The archive does not contain the PNGuin app")
        if info["LSMinimumSystemVersion"] != "26.0":
            raise ValueError("Update the cask's macOS requirement for this app")
        if args.archive.name != f"PNGuin-{version}-macOS.zip":
            raise ValueError("Archive filename must match the app version")
        template = Path(__file__).resolve().parents[1] / "Packaging/pnguin.rb.in"
        cask = template.read_text().replace("@VERSION@", version)
        cask = cask.replace("@SHA256@", hashlib.sha256(archive).hexdigest())
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(cask)
        print(args.output)
    except (OSError, KeyError, ValueError, TypeError, zipfile.BadZipFile) as error:
        print(f"write-cask: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
