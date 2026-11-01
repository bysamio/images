# Immich machine learning CPU pilot

Minimal derivative of the official Immich v3.3.5 CPU worker. The production base
is its immutable linux/amd64 manifest `1270449e…`; no application or ONNX runtime
code changes. It adds a locked wheel-only security overlay, removes runtime pip
and its vulnerable vendor tree, and defaults to UID/GID 1000 and one CPU thread.

```sh
make build-local
make test
make scan
```

The runtime test owns and cleans only its nonce-labelled container/model volume.
It downloads six public default CLIP inputs by immutable revision and hash, then
proves actual visual/text HTTP vectors with `--network none`, effective 2816-MiB
memory/no-extra-swap/one-CPU limits, zero capabilities, malformed input refusal,
worker exit after inactivity and subsequent offline reload. No host media,
credentials or published ports are used. Model preparation needs a writable cache.

The home-server rollout supplies a separate internal API/worker network, encrypted
cache, read-only root, bounded tmpfs/logs and `HF_HUB_OFFLINE=1`. It enables Smart
Search only for the accepted sample; it does not enable faces, OCR or duplicates.
No hardware acceleration, new model or Paperless change is included.

For local ARM64 compatibility testing, override `UPSTREAM` with the matching
v3.3.5 arm64 manifest `3719420e…`. CI verifies and publishes native amd64 only.
CI publishes the exact tested artifact with a unique `3.3.5-r1-<run>-<attempt>` tag;
consumers must pin its published digest. See [security assessment](security/REVIEW.md).
