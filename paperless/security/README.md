# Paperless patch and outstanding findings

Reviewed 11 October 2026; next vendor/applicability review due 18 October 2026.

The base index is pinned in the Dockerfile. This revision changes dependencies
and the default user; it does not rewrite the application or strip scan metadata.

| Change | Evidence |
| --- | --- |
| Ghostscript and all three libgs packages to `10.05.1~dfsg-1+deb13u3` | Debian fixes [CVE-2026-101258](https://security-tracker.debian.org/tracker/CVE-2026-101258) and [CVE-2026-103226](https://security-tracker.debian.org/tracker/CVE-2026-103226); parser/OCR/PDF-A tests pass. |
| fsspec `2026.6.0`, wheel SHA-256 pinned | Fix for CVE-2026-104851; `uv pip check --system` passes for the application environment. |
| Remove unused pip and its bootstrap wheel | pip 26.2.1 vendors msgpack 1.1.2 (GHSA-6v7p-g79w-8964), setuptools 70.3.0 (CVE-2025-47273) and urllib3 2.7.0 (CVE-2026-97687 / CVE-2026-97689). Updating the global application copies does not update these bundled copies. Tests assert pip absence and preserve uv. |
| Default UID/GID `1000:1000` | Default and explicit UID startup pass with all capabilities dropped and no-new-privileges. Data paths must be owned by the selected UID. |

## Scan evidence

The initial full HIGH/CRITICAL scan of the patched native ARM64 image with
Trivy 0.71.1 and its 11 October database reports **209 HIGH, 9 CRITICAL**, representing
**73 distinct advisories**, with **zero vendor-listed fixes**. These counts include
package occurrences; they are not 218 independent reachable exploits. The official
AMD64 baseline had 222 HIGH / 9 CRITICAL / 13 fixable occurrences. Architecture and
image provenance differ, so the AMD64 CI scan is the authoritative release report.

The full ARM64 filesystem was scanned with no analysis exclusions; database
updates were skipped only to keep the same cached database during comparison.
CI updates its database, retains all severities and generates an SBOM. A later
database can introduce new findings or fixes and must be assessed again.

## Deployment decisions still required

| Finding | Scope, evidence and disposition |
| --- | --- |
| CVE-2026-49261, four MariaDB package occurrences | [MariaDB server advisory](https://github.com/MariaDB/server/security/advisories/GHSA-3p3m-4x7c-p4pw) requires `wsrep_notify_cmd`. No `mariadbd`/`mysqld` executable is installed in the tested image. The intended database is PostgreSQL. Inapplicable to that server path; reassess if MariaDB integrations are introduced. |
| CVE-2026-44172, four MariaDB package occurrences | [MariaDB client advisory](https://github.com/MariaDB/server/security/advisories/GHSA-pv9p-5w55-55jm) is rated moderate by MariaDB and requires Big5 with `mysql_real_escape_string()` and the text protocol. Expected to be outside the PostgreSQL connection path. Verify the effective backend/integrations on the deployed digest before acceptance. |
| CVE-2026-6653, libxml2 | [Debian tracker](https://security-tracker.debian.org/tracker/CVE-2026-6653) describes XML-parser denial of service, marks Trixie minor and lists no stable fix. The package remains vulnerable. Application/parser reachability and a bounded mitigation or deferral still need review. |
| CVE-2026-81726, NLTK | No fix is listed in this scan for installed 3.10.3. Review model-artifact path handling in the actual application; do not treat absence of a fix as absence of risk. |
| Remaining HIGH package findings | Kept in full reports. Complete vendor/applicability triage before accepting the image for personal documents. |

For phase-1 development, use only synthetic documents and disposable state.
The intended consumer has loopback-only web access, an internal network,
non-root execution, no extra capabilities, no-new-privileges, limited OCR workers
and CPU/memory limits. These controls bound exposure; they do not fix parser bugs.
No family documents should be ingested until image triage, host mount/runtime
guards and backup/restore gates pass. Publication is for reproducible review and
future consumption, and is not a declaration of personal-data readiness.
