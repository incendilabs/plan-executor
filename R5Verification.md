# FHIR R5 Harness Verification

Verification date: 2026-07-28

## Scope

This records the Task 5H routing regression matrix. It verifies the
plan-executor R5 harness against the local R5 implementations in
`fhir_models` and `fhir_client`, while retaining the existing DSTU2 and STU3
model dependencies.

Suite compatibility and real-endpoint execution are not part of this task.
Individual suites do not advertise R5 support yet.

## Source Revisions

| Repository | Revision | Branch |
| --- | --- | --- |
| `plan-executor` | `105c365ac611ce0dcb35435e67116e6a74c73333` | `add-r5-support` |
| `fhir_models` | `695ea76f0078465d2da8225cbb82be8ba2eec7fd` | `add-r5-support` |
| `fhir_client` | `4273d633730df70bdd58c3f5b14cd595edc04e95` | `add-r5-support` |
| `fhir_stu3_models` | `71db01196b6cafe2310498135849cae356fe6f44` | `master` |
| `fhir_dstu2_models` | `66c58438d323f634116dc937446d42d9b4356687` | `master` |

## Dependency Provenance

The committed `Gemfile.lock` was not used as evidence for R5 dependency
resolution. It currently locks the GitHub repositories to pre-R5 revisions:

- `fhir_models`: `a143d2e21d0253b33fdaeb17e2d152ad656c9a3e`
- `fhir_client`: `79026641f9b2ac7cf30bc27a3528e505d34c67e8`

For the Docker verification, exact `git archive` snapshots of the revisions
above were copied into a disposable build context under
`tmp/task-5h/r5-docker-context`. Its temporary Gemfile selected all four model
and client repositories with Bundler `path:` dependencies. The resulting
image therefore contains the local R5 work and does not depend on unmerged
GitHub branches.

The container runs used no sibling source mounts and no `RUBYLIB` override.
The installed sources resolved to:

```text
fhir_client: /workspace/fhir_client
fhir_models: /workspace/fhir_models
```

Updating the committed lockfile to merged GitHub revisions remains Task 8E.

## Environment

| Component | Host | Container |
| --- | --- | --- |
| Platform | macOS arm64 | Linux aarch64 |
| Ruby | 3.4.9 | 3.4.9 |
| RubyGems | 3.6.9 | 3.6.9 |
| Bundler | 4.0.10 | 4.0.10 |
| `plan_executor` | 1.8.0 | 1.8.0 |
| `fhir_client` | 5.1.0 | 5.1.0 |
| `fhir_models` | 4.1.0 | 4.1.0 |
| `fhir_stu3_models` | 3.0.1 | 3.0.1 |
| `fhir_dstu2_models` | 1.0.10 | 1.0.10 |
| Docker engine | 29.6.2 | n/a |

Docker verification image:

```text
incendi/plan_executor:r5-task-5h-local
sha256:36d0db4e13944dba3871304360e78da7dcade83066a1e1935ceb5c5ecb51f3d8
```

## Results

| Check | Tests | Assertions | Failures | Errors | Omissions | Exit |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Focused Task 5 routing matrix | 160 | 486 | 0 | 0 | 0 | 0 |
| Unchanged R4B and R4 routing regressions | 1,118 | 3,414 | 0 | 0 | 0 | 0 |
| Complete unit suite in Docker | 1,271 | 3,865 | 0 | 0 | 0 | 0 |
| R5 namespace and structure gate in Docker | 15 | 62 | 0 | 0 | 0 | 0 |

The focused matrix covered version parsing, structure generation and lookup,
fixtures, R5 routing, task routing, TestScript version handling, metadata, and
supported-version behavior.

The unchanged R4B and R4 regression selection covered version routing, R4B
routing, format handling, and resource generation.

## R5 Purity And Reproducibility

The Docker R5 gate verifies:

- explicit clients, suites, resource lookup, parsing, and structure ownership
  resolve through `FHIR::R5`;
- generated Patient and Bundle object graphs contain only `FHIR::R5` model
  classes;
- parsed Patient, Bundle, CapabilityStatement, and OperationOutcome resources
  use R5 classes;
- the structure index contains each of the 158 concrete R5 resources exactly
  once, includes representative R5-only resources, and excludes resources
  removed after R4B;
- the pinned official definitions archive regenerates the checked-in structure
  artifact byte-for-byte on two consecutive generations.

Pinned artifacts:

| Artifact | SHA-256 |
| --- | --- |
| `tmp/task-5c/r5-definitions.json.zip` | `df0d7259b4a8741d59f4971d96dd486423ecbd414c7060e9dc006ae3c3209c0c` |
| `lib/FHIR_structure_r5.json` | `fa26a3b092cfa9232765d0e3042e03331535a985856957cfd6aefed3a15b9225` |

The zero-omission Docker result confirms that the archive-backed
reproducibility test ran rather than taking its missing-archive omission path.

## Commands

Focused tests were loaded together with:

```sh
ruby -Ilib -Itest -e \
  'files = ARGV.dup; ARGV.clear; files.each { |file| require File.expand_path(file) }' \
  test/unit/fhir_version_test.rb \
  test/unit/fhir_structure_generator_test.rb \
  test/unit/fhir_structure_test.rb \
  test/unit/r5_structure_test.rb \
  test/unit/fixture_selection_test.rb \
  test/unit/fixtures_test.rb \
  test/unit/r5_routing_test.rb \
  test/unit/task_routing_test.rb \
  test/unit/testscript_version_test.rb \
  test/unit/metadata_test.rb \
  test/unit/supported_versions_test.rb
```

The unchanged R4B and R4 regression selection used:

```sh
ruby -Ilib -Itest -e \
  'files = ARGV.dup; ARGV.clear; files.each { |file| require File.expand_path(file) }' \
  test/unit/fhir_version_test.rb \
  test/unit/r4b_routing_test.rb \
  test/unit/format_suite_test.rb \
  test/unit/resource_generator_test.rb
```

The self-contained Docker image ran the complete suite with:

```sh
bundle exec ruby -Itest -e \
  'Dir["test/unit/**/*_test.rb"].sort.each { |file| require File.expand_path(file) }'
```

The in-container R5 gate used:

```sh
R5_DEFINITIONS_ARCHIVE=/sources/r5-definitions.json.zip \
bundle exec ruby -Itest -e \
  'ARGV.each { |file| require File.expand_path(file) }' \
  test/unit/r5_routing_test.rb \
  test/unit/r5_structure_test.rb
```

Raw logs, numeric exit-status files, source snapshots, and the disposable
Docker build context remain under `tmp/task-5h/` and are not committed.

The archive snapshots do not contain `.git` metadata, so gemspec evaluation
emits non-fatal `not a git repository` diagnostics. Bundler installation and
all verification commands still exit successfully.

## R5 Generator Compatibility Adjustments

Task 6F keeps specification-valid resource generation separate from stricter
wire-format compatibility adjustments. The all-resource audit identified one
such adjustment:

- The R5 StructureDefinition for
  `ImagingSelection.instance.imageRegion2D.regionType` permits `point`,
  `polyline`, `interpolated`, `circle`, and `ellipse`.
- The official R5 XML schema applies its shared 3D graphic-type enumeration to
  both the 2D and 3D elements. It therefore rejects the otherwise valid 2D
  values `interpolated` and `circle`.
- Generated 2D regions are restricted to the specification-valid intersection
  `point`, `polyline`, and `ellipse`, while already compatible values are
  preserved.

This is an official-schema compatibility adjustment, not an endpoint-specific
server workaround. No server-specific generator adjustment was added.

The same audit found no equivalent R5 invariant requirement for
`RequestOrchestration` or `DeviceUsage`. Their R4B predecessors
`RequestGroup` and `DeviceUseStatement` are not resolved from R5 invariant
dispatch.
