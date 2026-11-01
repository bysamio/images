"""Validate all active dependency requirements, retaining upstream's cv2 alias."""
import importlib.metadata as metadata
from packaging.requirements import Requirement
from packaging.utils import canonicalize_name

installed = {canonicalize_name(d.metadata['Name']): d for d in metadata.distributions()}
for name, distribution in installed.items():
    for raw in distribution.requires or []:
        requirement = Requirement(raw)
        if requirement.marker and not requirement.marker.evaluate({'extra': ''}): continue
        dependency = canonicalize_name(requirement.name)
        # Upstream uv.lock intentionally substitutes opencv-python-headless for
        # rapidocr's GUI package. Both expose cv2; never install both variants.
        if name == 'rapidocr' and dependency == 'opencv-python':
            assert dependency not in installed
            dependency = 'opencv-python-headless'
        assert dependency in installed, (name, dependency)
        assert installed[dependency].version in requirement.specifier, (name, str(requirement))
assert metadata.version('pillow') == '13.0.0'
assert metadata.version('starlette') == '1.3.1'
print('PASS: installed dependency graph and upstream headless OpenCV substitution')
