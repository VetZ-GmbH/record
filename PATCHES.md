# VetZ patch stack

`vetz/main` is a released upstream [llfbandit/record](https://github.com/llfbandit/record) version
plus the VetZ-specific commits listed below.

## How to update

Rebase the patch stack onto the newer upstream version. Never merge upstream into `vetz/main`.

1. Branch off the upstream commit of a version published on pub.dev. Upstream does not tag releases,
   so use the commit that bumped the version in `record_windows/pubspec.yaml`, and check that
   `record_windows` did not change between that commit and the publish date. Do not base on
   unreleased upstream `main`.
2. Replay each patch below (cherry-pick or port by hand if upstream refactored the code).
3. For every patch, check whether upstream has fixed the issue in the meantime. If it has, drop
   the patch and move it to "Dropped patches" with the reason.
4. Update this file.

## Releases

Releases are annotated tags on `vetz/main`, named `record_windows-<version>-r<n>`:

- `<version>` is the `record_windows` version from `record_windows/pubspec.yaml` of the upstream base.
- `r<n>` counts VetZ releases on that upstream version: bump it for each new release on the same base,
  and start again at `r1` after rebasing onto a new upstream version.

Example: `record_windows-2.3.0-r1`.

Never move or delete a tag once it has been pushed; publish a new `r<n>` instead.

## Current base

Upstream `c8b0bd6` = `record_windows` 2.3.0 as published on pub.dev (2026-09-11).

Latest release: `record_windows-2.3.0-r1`.

## Active patches

| Commit | Original | Package | Change |
|---|---|---|---|
| `e6eedf9` | `9d648af` | record_windows | `Recorder::EndRecording` is best-effort: a `Finalize()` error from the sink writer is logged and `S_OK` is returned, so a teardown error (e.g. `MF_E_SHUTDOWN`) no longer surfaces to Dart as a `PlatformException` on `stop()`. Ported by hand: 2.3.0 already ignores source shutdown errors, only the finalize result still propagated. Trade-off: a genuinely failed finalize (possibly unusable file) is now only visible in the log. |

## Dropped patches

Dropped when rebasing onto 2.3.0. The fixes were written against the pre-2.3.0 Windows recorder;
upstream's move to a single dispatcher thread (`c8b0bd6`) and earlier fixes removed the bugs.

| Original | Change | Why dropped |
|---|---|---|
| `7a82ce5` | Flush pending `OnReadSample` callbacks before releasing the source reader (two-phase `EndRecording`, flush event, `m_bStopping`). | All Media Foundation work runs on one dispatcher thread. `EndRecording` disarms the `ReaderCallback`, and the callback holds its own reference while a sample is queued, so late samples are dropped instead of touching freed objects. |
| `c4330e8` | Cast `MF_SOURCE_READER_FIRST_AUDIO_STREAM` to `DWORD` in the `Flush` call. | Follow-up to `7a82ce5`; upstream never calls `Flush`. |
| `9fc11bc` | Fix vector double-sizing and out-of-bounds read in the amplitude calculation. | Amplitude moved to `AmplitudeTracker::update`, which sizes the vector once (`size / 2`) and iterates over its actual elements. |
| `a96ba86` | Call `MFShutdown` once on `Dispose` instead of on every stop (memory growth on rapid start/stop). | `RecorderDispatcher` calls `MFStartup` once when its thread starts and `MFShutdown` once when it exits, spanning every take. |
| `3fed2c1` | Snapshot the record event handler before queueing the PCM lambda (null deref after `Dispose`). | `RecorderWrapper` captures the handler by value and guards every posted callback with a shared `alive` flag. |
| `8807fcc` | Restore the stream event handler in `StartStream` (no PCM data reached Dart), plus `record_windows` 2.2.1 changelog/version bump. | Fixed upstream in `db895d8`; the recorder also no longer nulls the handler. Upstream versioning (2.3.0) supersedes the 2.2.1 bump. |

## History

- 2026-10-01: `record_windows-2.4.0-r1` was briefly published on unreleased upstream `main`
  (`247bcb7`, 2.4.0 not on pub.dev). The tag was deleted and `vetz/main` rebased onto 2.3.0 the
  same day. The patch stack was identical.
