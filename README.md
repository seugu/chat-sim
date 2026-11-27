# chat-sim

Simulations of [logos-chat](https://github.com/logos-messaging/logos-chat) groups: does a group of
logos-chat clients still hold one group when the network delays and loses what its members send?

A scenario says how many members there are, what they do, what the network does to them, and what
the group is expected to come to. [`tools/sim`](tools/sim/README.md) runs it with every member in
one process on a virtual clock, where on Linux a run is the same every time from its seed. A run of
a group that grows says from its lineage how many epochs the group lasted before it first forked.
For any other run, [`tools/forks`](tools/forks/README.md) reads the members' logs and says whether
they still hold one group.

CI publishes the [guide](https://logos-messaging.github.io/chat-sim/guide/) to the
repository's [Pages site](https://logos-messaging.github.io/chat-sim/), with a report of its
simulations for master and for each open pull request, the runs of logos-chat that
`simulate.yml` keeps, and the [graph over logos-chat's main](https://logos-messaging.github.io/chat-sim/logos-chat/)
drawn from the runs of main. The guide's
[Your pull request's result](https://logos-messaging.github.io/chat-sim/guide/track/pull-request/)
says what a logos-chat pull request's run does and how to read it, and
[logos-chat main over time](https://logos-messaging.github.io/chat-sim/guide/track/main/) what the
runs of main keep. [CONTRIBUTING.md](CONTRIBUTING.md) says what chat-sim's own CI runs and what a
change to the runs takes.

## Layout

| Path | What it is |
|------|------------|
| [`crates/harness`](crates/harness/README.md) | A group of logos-chat clients in one process on a virtual clock, and `harness-run`, which runs a plan on it |
| [`crates/network-model`](crates/network-model/src/lib.rs) | The model of a lossy network the runner puts between a client and what it receives |
| [`tools/sim`](tools/sim/README.md) | Runs a scenario, and sweeps one over seeds and rates |
| [`tools/forks`](tools/forks/README.md) | Reads the logs of a group's members and says whether the group forked |
| [`guide`](guide) | The guide, a Starlight site: how a run works, what the scenarios are, how to read what CI finds, and how to take a run to your machine |
| `.github/scripts/measure.py` | Says whether `simulate.yml`'s main suite is to run at logos-chat main's tip, from the points on `gh-pages` and the runs going, and on Sundays whether its long suite is |
| `.github/scripts/pages.py` | Writes the Pages site: the report of a CI run from the text its sim jobs upload, the list of the reports, and the landing page; and keeps the points of logos-chat's main, its long runs and the runs of its pull requests that `simulate.yml` makes, draws the page of each, draws the graph over main from the points, with the page of each commit found to change a run, and names the runs of logos-chat's pull requests that are no longer open |
| `.github/scripts/simulate.py` | Plans the jobs of `simulate.yml` and the seeds a pull request's run widens to, says whether a commit changes a path the runs depend on, writes the comment on what the runs came to, says where it goes on a logos-chat pull request, and writes the updates of the check run there |

## The logos-chat it runs

The simulation runs logos-chat at one revision, pinned twice: [`Cargo.toml`](Cargo.toml) pins
logos-chat's crates, and [`flake.nix`](flake.nix) takes the toolchain from logos-chat's flake, so it
is the store path logos-chat's CI pushes to the Logos cache. CI checks that the two name the same
revision. To move it, change the revision in both, then run
`nix flake lock`; cargo updates `Cargo.lock` on the next build.

`de-mls` and `chat-proto` are spelled in `Cargo.toml` as logos-chat spells them, and move with it.

## Running it

With Nix, one command builds what a run needs and runs a scenario:

```sh
nix run .#groupv2-simulation -- run tools/sim/scenarios/50-epochs.json --out tmp/50-epochs
```

The dev shell has the toolchain for cargo:

```sh
nix develop
cargo build --release --workspace
python3 tools/sim run tools/sim/scenarios/50-epochs.json --one-process target/release/harness-run --out tmp/50-epochs
```

[`tools/sim`](tools/sim/README.md#running-it) has the flags and what a run reports.

## License

Licensed under either of [Apache License, Version 2.0](LICENSE-APACHE) or [MIT license](LICENSE-MIT)
at your option.

## Branch `sds-reliability-fixes`

This branch runs logos-chat `a74ad35` with a GroupV3 delivery fix. See
[DELIVERY-FIX.md](DELIVERY-FIX.md) for the results against `master` and how to reproduce them.
