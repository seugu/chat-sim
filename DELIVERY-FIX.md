# GroupV3 delivery fix: results and how to reproduce them

This branch runs the GroupV3 scenarios on logos-chat `a74ad35` (the revision `master` pins) with
one change. The change is the same as the one proposed for logos-chat `main` in
[seugu/logos-chat `sds-reliability-fixes`](https://github.com/seugu/logos-chat/tree/sds-reliability-fixes),
backported to `a74ad35` so chat-sim can run it as is:

- logos-chat: [`sds-reliability-fixes-a74ad35`](https://github.com/seugu/logos-chat/tree/sds-reliability-fixes-a74ad35)
- sds-rs: [`sync-reports-missing-648283e`](https://github.com/seugu/sds-rs/tree/sync-reports-missing-648283e)

Only the pin changes (`Cargo.toml`, `Cargo.lock`), plus the expected outcomes it moves. Scenarios,
runner, network model and tools are those of `master`.

## Why GroupV3 forked

A member finalizes a commit 120 s after it first defers one, and picks the lowest fingerprint it
has seen. When three members commit at once and the lowest commit is lost at one member, that
member has to get it back within 120 s. In practice it never did:

- **ACKs need a message to ride on.** SDS acknowledges only through the receiver's next message. A
  quiet member syncs only after 30 s of silence, and every message it receives restarts that wait.
  In a busy group it never sends anything.
- **One ACK stops resends.** The sender stops resending once any one member names the message.
  That member is rarely the one that missed it.
- **Nobody asks for what is missing.** Other members' syncs name the lost commit, but SDS gives
  that only to SDS-R, which GroupV3 turns off. The member noticed only when a later content
  message named the commit, about 180 s later. By then its timer had already fired and it had
  finalized another commit.

## What the change does

- **Fetch on sync:** a member fetches from the store any message that a sync names and it lacks.
- **ACK sync:** a member syncs within 0–5 s of receiving a message. Senders hear from quiet
  members, and everyone sees often what they are missing.

Together, a lost commit comes back within seconds. Every member sees the same commits before
120 s, and they all finalize the same one.

## Results

Each side runs 10 runs per `grow` scenario and 2 runs per `50-epochs` scenario, both on Linux.
`base` is `master`; its first runs match `tools/sim/expected` on `master` exactly. `head` is this
branch.

`grow-waku-loss-*-groupv3`: 200-member pool, 3 adders per round, aiming for 50 epochs.

| Loss | One group to the end (base → head) | Trunk epoch, mean | Side lines, mean | First fork, median (base) |
|---|---|---|---|---|
| 0% | 10/10 → 10/10 | 50 → 50 | 0 → 0 | – |
| 0.1% | 4/10 → **10/10** | 50 → 50 | 0.8 → 0 | 40 |
| 0.5% | 1/10 → **10/10** | 45.2 → 50 | 3.3 → 0 | 20 |
| 1% | 0/10 → **10/10** | 38.9 → 50 | 4.9 → 0 | 14 |
| 5% | 0/10 → **10/10** | 22.9 → 50 | 4.9 → 0 | 10 |

`50-epochs-by-saro-waku-loss-*-groupv3`: 51 members, one committer.

| Loss | Ended (base → head) | Members behind or off trunk, mean | Virtual time for 50 epochs |
|---|---|---|---|
| 0% | whole → whole | 0 → 0 | 6050 s → 6050 s |
| 0.1% | whole → whole | 0 → 0 | 6109 s → 6052 s |
| 1% | 1 of 2 behind → whole | 0.5 → 0 | 6640 s → 6066 s |
| 5% | 2 of 2 behind → whole | 6 → 2.5 | 7849 s → 6254 s |

`sim matrix tmp/head --base tmp/base` gives the verdict **`later`**: at the head, groups fork
later or not at all. The difference is beyond chance at 0.5%, 1% and 5% loss (sign test
p = 0.004, 0.002, 0.002). No cell forked earlier.

`never_joined` stays around 50 in `grow`, with or without the change. Each round, three adders
commit at once and only one commit is applied, so the joiners of the other two never join. This
comes from how the scenario is built, not from a fork.

## Reproduce it step by step

You need Linux (or WSL). A run is the same every time only on Linux, so on macOS the numbers can
differ. You also need git, Python 3.9+, protoc (`sudo apt install protobuf-compiler`) and Rust.
`rust-toolchain.toml` picks the version, so rustup installs it on the first build.

```sh
# 1. Get chat-sim and build the base runner (master).
git clone https://github.com/logos-messaging/chat-sim && cd chat-sim
cargo build --release -p harness
cp target/release/harness-run /tmp/harness-base

# 2. Build the head runner (this branch).
git remote add seugu https://github.com/seugu/chat-sim
git fetch seugu sds-reliability-fixes && git checkout sds-reliability-fixes
cargo build --release -p harness
cp target/release/harness-run /tmp/harness-head

# 3. Sweep the GroupV3 scenarios with each runner (10 grow runs, 2 fifty-epoch runs each).
bash tools/sim/delivery-fix.sh /tmp/harness-base tmp/base
bash tools/sim/delivery-fix.sh /tmp/harness-head tmp/head

# 4. Compare.
python3 tools/sim matrix tmp/head --base tmp/base --out tmp/matrix.json   # verdict: later
python3 tools/sim compare tools/sim/expected/grow-waku-loss-1-groupv3.json tmp/head/grow-waku-loss-1-groupv3
git diff master -- tools/sim/expected    # what moved: "split" outcomes became "whole"
```

- Each runner takes about 5 minutes to build.
- Each sweep is 58 runs, about 1 minute each.
- `tools/sim/expected` on this branch holds the head's outcomes, so `compare` says `same` for every
  run. The `git diff` shows each `split at epoch N` of `master` that became `whole`.

## Limits

- Agreement still rests on the 120 s timer. The change makes forks rare in these scenarios; it does
  not make them impossible.
- `flake.lock` still pins upstream `a74ad35`, which only provides the toolchain. Nix users get the
  same toolchain, but CI's pin check would flag the mismatch.
- The network model has fixed per-member delays and no jitter, as on `master`.
