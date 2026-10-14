#!/usr/bin/env python3
"""Remove redundant local-package navigator folders, keeping real package references.

XcodeGen emits both; Shark 1.8.7's XcodeGraph mapper treats them as duplicate
packages and traps. Keep the generated OpenStep formatting intact.
"""

import json
from pathlib import Path
import re
import subprocess
import sys


project = Path(sys.argv[1])
source_root = project.resolve().parent.parent
objects = json.loads(subprocess.check_output(
    ["plutil", "-convert", "json", "-o", "-", str(project)]
))["objects"]
package_paths = {
    (source_root / obj["relativePath"]).resolve()
    for obj in objects.values()
    if obj["isa"] == "XCLocalSwiftPackageReference"
}
text = project.read_text()
for key, obj in objects.items():
    if (obj["isa"] != "PBXFileReference"
            or obj.get("lastKnownFileType") != "folder"
            or obj.get("sourceTree") != "SOURCE_ROOT"
            or (source_root / obj["path"]).resolve() not in package_paths):
        continue
    # Remove the file declaration and its navigator group membership only.
    text, count = re.subn(
        rf"^\s*{re.escape(key)} /\*[^\n]*?\*/(?: = \{{[^\n]*\}};|,)\n",
        "", text, flags=re.MULTILINE,
    )
    if count != 2:
        raise SystemExit(f"Expected two navigator entries for {key}, found {count}")
project.write_text(text)
