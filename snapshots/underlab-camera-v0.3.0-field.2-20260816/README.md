# Underlab Camera v0.3.0-field.2 snapshot

- Release lock: `FieldLock-20260816`
- Created: 2026-08-16 (Asia/Seoul)
- Updated: 2026-08-16 (AF slider capture fix and S10 verification)
- Purpose: current known-good rollback and regression-comparison baseline
- Release note: `docs/release-underlab-camera-v0.3.0-field.2-20260816.md`

This snapshot preserves the active Flutter client sources, Opal remote UI and
runtime, OpenWrt/ddserver packaging, deployment and contract scripts, known-good
documents, the versioned APK, and deployed-device hash/status evidence.

The updated baseline includes the verified idle-mode AF slider path, Nikon
`0xA003` post-capture handling, preserved structured camera errors, and removal
of the duplicate release-detent `shutter-hold-start` request.

Restore files selectively. Do not replace a complete workspace without first
comparing `SHA256SUMS.txt` and preserving newer user work.
