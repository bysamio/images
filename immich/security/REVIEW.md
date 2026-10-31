# Pilot risk review — 2026-10-31

Review again by **2026-11-07**, on any new advisory or upstream release, and
before expanding beyond a small sample. No CVEs are suppressed. The publication
gate matches the existing Paperless image: all fixable HIGH/CRITICAL findings
block publication; full reports retain advisories with no stable-distribution fix.

The first local ARM64 candidate scan found 84 HIGH and 3 CRITICAL occurrences,
with zero fixable HIGH/CRITICAL findings after the dependency and OS updates.
Native amd64 CI remains authoritative for publication. The two deployed pnpm
production-lockfile audits passed at HIGH/CRITICAL. Builder-only docs/web/Vite
development-server findings are outside the rebuilt server/CLI runtime; this
build never starts their development servers or builds the docs/web workspaces.
The broader workspace audit used during development is retained in the home-server diagnostics.

The remaining OS findings are not uniformly unreachable. In particular:

- OpenEXR CVE-2026-42216 and CVE-2026-42217 remain in Debian trixie's 3.1.13-2.
  Upstream has fixes; the stable distribution does not yet supply them. These are
  malformed EXR input memory-safety/information-disclosure findings. Do not label
  them false positives or assume a VPN blocks malicious media.
- libxml2 CVE-2026-6653 remains in trixie's security-backported 2.9.14-based
  library. Debian describes this as a minor XML-input DoS issue and has not
  scheduled a DSA; Trivy's CRITICAL label alone overstates that vendor assessment.
  Native SVG/XML processing remains an input boundary.
- The full report also includes TIFF/GSF/media and local-system library findings.
  Capabilities dropped, non-root execution, internal networking, bounded memory
  and no Docker socket reduce the consequences; they do not repair those parsers.

The controlled pilot uses the operator's own camera JPEG/HEIC/video sample first,
without public exposure, external libraries or broad third-party media ingestion.
Keep the original files and independent backup. Reassess native parser exposure
before bulk importing WhatsApp/unknown-source archives; consider a tested native
library rebuild or wait for upstream/distribution fixes if those paths are needed.
The server keeps ML off, concurrency one, bounded containers and loopback-only
application publishing behind VPN HTTPS. No generic PostgreSQL/Paperless change
is included. PostgreSQL and Valkey scans are tracked independently.

Sources: [OpenEXR 42216](https://security-tracker.debian.org/tracker/CVE-2026-42216),
[OpenEXR 42217](https://security-tracker.debian.org/tracker/CVE-2026-42217),
[libxml2 vendor assessment](https://security-tracker.debian.org/tracker/CVE-2026-6653).
