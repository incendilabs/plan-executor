# FHIR R5 Harness Verification

Verification date: 2026-07-28

## Scope

This records the Task 5H routing regression matrix. It verifies the
plan-executor R5 harness against the local R5 implementations in
`fhir_models` and `fhir_client`, while retaining the existing DSTU2 and STU3
model dependencies.

Suite compatibility and real-endpoint execution were not part of this task.
They are recorded separately in the Task 7B section below.

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

## Task 7B: Read And History Suite Verification

Verification performed: 2026-07-29.

`ReadTest` and `HistoryTest` were audited against FHIR R5 read, conditional
read, vread, delete, and history behavior. They now explicitly advertise
`:r5`; the other ten R4B-capable suites remain unaudited and ineligible for
R5.

Ruby-level checks used rbenv Ruby 3.4.9 and the visible
`tmp/task-7b/Gemfile`, whose `path:` dependencies select the local sibling
`fhir_models`, `fhir_client`, `fhir_stu3_models`, and
`fhir_dstu2_models` checkouts. No FHIR implementation was resolved from
GitHub.

| Verification | Result |
| --- | --- |
| `test/unit/r5_read_history_suite_test.rb` | 4 tests, 11 assertions, 0 failures, 0 errors, 0 omissions |
| `test/unit/supported_versions_test.rb` | 8 tests, 11 assertions, 0 failures, 0 errors, 0 omissions |
| `TaskRoutingTest#test_r5_eligibility_is_limited_to_audited_suites` | 1 test, 2 assertions, 0 failures, 0 errors, 0 omissions |
| R5 `ReadTest` endpoint run | 6 pass, 0 fail, 0 error, 0 skip |
| R5 `HistoryTest` endpoint run | 11 pass, 0 fail, 0 error, 0 skip |
| R4B `ReadTest` regression endpoint run | 6 pass, 0 fail, 0 error, 0 skip |
| R4B `HistoryTest` regression endpoint run | 11 pass, 0 fail, 0 error, 0 skip |

The endpoint runs used the local-source Task 6G image
`incendi/plan_executor:r5-task-6g-local` with the Task 7B suite files mounted
for execution, against the user-built `sparkfhir/spark:r5-latest` and
`sparkfhir/mongo:r5-latest` images. The raw logs and the captured deletion
history payload are retained locally under `tmp/task-7b/` and are not
committed.

The audit makes the following R5-specific behavior explicit:

- Conditional read accepts either a full `200` response or `304 Not Modified`.
- A deleted resource's ordinary read and version read expect `410 Gone`.
- A history deletion entry has no resource body; its request URL carries the
  version identifier used for the deleted-resource vread assertion.
- A `404` history response may carry an R5 `OperationOutcome` and must parse
  through the selected R5 model namespace.
- `_summary=text` must parse as R5. The suite warns, rather than fails, when a
  server returns full content without a narrative because servers may ignore a
  requested summary form.

These conditions follow the R5 [HTTP interaction
rules](https://hl7.org/fhir/R5/http.html) and [search summary
rules](https://hl7.org/fhir/R5/search.html).

An additional direct R4 endpoint attempt could not start the locally supplied
R4 Spark image: it was configured to require an HTTPS certificate that was
not present. This was an environment startup limitation, not a suite result;
the R4B regression runs above completed successfully.

## Task 7G: General Search Suite Verification

Verification performed: 2026-07-29.

`SearchTest` and `RobustSearchTest` now explicitly advertise `:r5`. The
SearchTest R5 branch compares each endpoint-advertised search parameter name
and type with the R5 SearchParameter definition for that resource, including
the generic `Resource` parameters. `_summary` remains an explicitly allowed
result-control parameter because it is not a SearchParameter resource.

The focused unit tests use the local sibling R5 model and client repositories
through `tmp/task-7b/Gemfile` and rbenv Ruby 3.4.9:

| Verification | Result |
| --- | --- |
| `R5SearchSuiteTest` | 5 tests, 25 assertions, 0 failures, 0 errors |
| `SupportedVersionsTest` and `TaskRoutingTest` with `R5SearchSuiteTest` | 22 tests, 82 assertions, 0 failures, 0 errors |
| R5 `SearchTest` endpoint run | 1,092 pass, 0 fail, 0 error, 0 skip |
| R5 `RobustSearchTest` endpoint run | 0 pass, 0 fail, 0 error, 1 explicit Spark #310 skip |

The endpoint runs used local-source image
`incendi/plan_executor:r5-task7g-local-deps` against
`sparkfhir/spark:r5-task7g-local` and
`sparkfhir/mongo:r5-task7g-local`. Raw output is retained under
`tmp/task-7g/` and is not committed.

The R5 definition coverage includes representative string, token, reference,
date, number, and quantity parameters. `SearchTest` itself executes only its
existing `_id` and `_count` GET/POST cases; it does not exercise modifiers,
chaining, inclusion, sorting, paging, or arbitrary typed query values. Those
behaviors remain in scope for Task 7H. `RobustSearchTest` contains only the
MPI `$match` case, which remains an explicit skip for
[Spark issue #310](https://github.com/FirelyTeam/spark/issues/310).

## Task 7C: Resource Suite Verification

Verification performed: 2026-07-29.

`ResourceTest` now explicitly advertises `:r5`. It enumerates 156 R5
CRUD-testable resource classes from the checked-in R5 structure index. The R5
index contains 158 concrete resources; `OperationOutcome` and `Parameters`
remain intentionally excluded because they are response and operation payload
resources rather than ordinary CRUD targets. This is the pre-existing
cross-version `BaseSuite::EXCLUDED_RESOURCES` policy, not an R4B fallback.

`test/unit/r5_resource_suite_test.rb` verifies all of the following with local
siblings selected through `tmp/task-7b/Gemfile` and rbenv Ruby 3.4.9:

- ResourceTest's 156 classes equal the R5 structure-index resources after the
  two payload exclusions.
- Every ResourceTest-generated resource and every parsed JSON round-trip graph
  stays entirely in `FHIR::R5`.
- R5-only `ActorDefinition`, `ArtifactAssessment`, `GenomicStudy`,
  `Permission`, `Requirements`, `TestPlan`, and `Transport` are listed.
- Removed R4B resources `CatalogEntry`, `DeviceUseStatement`,
  `DocumentManifest`, `Media`, `RequestGroup`, `ResearchDefinition`, and
  `ResearchElementDefinition` have no R5 ResourceTest entry.

| Verification | Result |
| --- | --- |
| `test/unit/r5_resource_suite_test.rb` | 3 tests, 15,832 assertions, 0 failures, 0 errors, 0 omissions |
| `test/unit/supported_versions_test.rb` | 8 tests, 11 assertions, 0 failures, 0 errors, 0 omissions |
| Focused R5 ResourceTest routing checks | 5 tests, 12 assertions, 0 failures, 0 errors, 0 omissions |
| R5 `ResourceTest_Patient` endpoint run | 15 pass, 3 expected `$validate` TODO skips, 0 fail, 0 error |
| R5 `ResourceTest_MedicationRequest` endpoint run | 15 pass, 3 expected `$validate` TODO skips, 0 fail, 0 error |
| R5 `ResourceTest_ActorDefinition` endpoint run | 15 pass, 3 expected `$validate` TODO skips, 0 fail, 0 error |

The three endpoint resources cover an unchanged resource (`Patient`), a
shared R5-changed resource (`MedicationRequest`, whose R5 medication element
uses `CodeableReference`), and an R5-only resource (`ActorDefinition`). The
existing ResourceTest behavior intentionally skips `$validate` cases pending
Spark issue 205; no optional interaction was treated as a universal endpoint
requirement. The endpoint logs are retained locally at
`tmp/task-7c/ResourceTestPatientEndpoint.log`,
`tmp/task-7c/ResourceTestMedicationRequestEndpoint.log`, and
`tmp/task-7c/ResourceTestActorDefinitionEndpoint.log`.

During the endpoint audit, generated `Patient.photo.size` exposed an R5 JSON
wire-format defect in `fhir_models`: R5 `integer64` values must be JSON
strings, but the shared serializer emitted JSON numbers. The prerequisite
`fhir_models` commit `67c146c4 Serialize R5 integer64 values as JSON strings`
keeps integer64 values as Ruby integers internally while serializing their JSON
form as strings. The corrected local file was mounted into the local-source
Task 6G test image for the endpoint runs. The rule is specified by the R5
[JSON representation](https://hl7.org/fhir/R5/json.html).

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

## Task 6G: Generator Regression Matrix

Verification performed: 2026-07-28 through 2026-07-29.

This matrix verifies that repeated generation remains valid for every
advertised R4, R4B, and concrete R5 resource. Each generated object graph is
checked for generator exceptions, model validation failures, model classes
from another FHIR version, and required elements that were left empty.

### Local Source Provenance

The committed top-level `Gemfile` still selects the published GitHub `master`
branches. It was deliberately not used for this pre-merge R5 verification,
because that copy of `fhir_models` does not yet provide the R5 models.

A disposable Docker build context under `tmp/task-6d/docker-context` copied
the exact local source revisions below. Its temporary `plan-executor/Gemfile`
uses Bundler `path:` dependencies for every sibling model/client repository:

| Repository | Revision |
| --- | --- |
| `plan-executor` | `10ea167f0a59968ccc926be990b2871c9ecdaf70` |
| `fhir_models` | `aad13e057050c7511c20cab6d24fdd03dba1a39e` |
| `fhir_client` | `4273d633730df70bdd58c3f5b14cd595edc04e95` |
| `fhir_stu3_models` | `71db01196b6cafe2310498135849cae356fe6f44` |
| `fhir_dstu2_models` | `66c58438d323f634116dc937446d42d9b4356687` |

The tests ran in this self-contained image, with no sibling-source bind mount
or `RUBYLIB` override:

```text
incendi/plan_executor:r5-task-6g-local
sha256:d09f63ecae581d6ffb0fa88bf63f95f64d20f0f106d83d05adb7fb1fe058b352
```

Inside the image, Bundler resolved `fhir_models` from
`/workspace/fhir_models` and `fhir_client` from `/workspace/fhir_client`.
The image used Ruby 3.4.9, RubyGems 3.6.9, and Bundler 4.0.10. Its source
snapshots intentionally omit `.git` metadata, which causes five non-fatal
`not a git repository` gemspec diagnostics during test startup.

The R5 definitions archive used by the R5 matrix was:

| Artifact | SHA-256 |
| --- | --- |
| `tmp/task-5c/r5-definitions.json.zip` | `df0d7259b4a8741d59f4971d96dd486423ecbd414c7060e9dc006ae3c3209c0c` |

### Results

| Verification | Coverage | Result |
| --- | --- | --- |
| R5 repeated all-resource audit | 158 concrete resources x depths 2, 3, 4 x 2 iterations = 948 cases | 0 failures |
| R4 repeated all-resource audit | 148 resources x depths 2, 3, 4 x 2 iterations = 888 cases | 0 failures |
| R4B repeated all-resource audit | 143 resources x depths 2, 3, 4 x 2 iterations = 858 cases | 0 failures |
| Focused R5 generator tests | 42 tests, 934 assertions | 0 failures, 0 errors, 0 omissions |
| Complete unit suite in Docker | 1,313 tests, 4,793 assertions | 0 failures, 0 errors, 0 omissions |

All repeated audits used base seed `20260728`. The R5 audit excludes exactly
four abstract model types: `Resource`, `DomainResource`, `CanonicalResource`,
and `MetadataResource`. No concrete R5 resource is intentionally unsupported.
The R4 and R4B audits cover every resource advertised by their respective
`RESOURCES` constants. No verification command reported a skip or omission.

The R5 audit manifest is at
`tmp/task-6g/R5GenerationAudit/manifest.json`; the R4/R4B report is at
`tmp/task-6g/LegacyGenerationAudit.json`. Raw focused and complete-suite logs
are `tmp/task-6g/FocusedGeneratorSuite.log` and
`tmp/task-6g/FullUnitSuite.log`. These artifacts are retained locally and are
not committed.

The R5 all-resource format audit that drove Task 6F was also rerun using the
same seed/depth/iteration matrix. It changed from 42 failures across 29
resources before the invariants to 0 failures across all 948 cases after the
invariants and XML-schema compatibility adjustment.

The main R5 command was:

```sh
R5_DEFINITIONS_ARCHIVE=/sources/r5-definitions.json.zip \
bundle exec rake 'crucible:audit_r5_resource_generation[/evidence/R5GenerationAudit,20260728,2]'
```

The complete unit suite command was:

```sh
bundle exec ruby -Itest -e \
  'Dir["test/unit/**/*_test.rb"].sort.each { |file| require File.expand_path(file) }'
```

## Task 7D: Format Suite Verification

Verification performed: 2026-07-29.

`FormatTest` now explicitly advertises `:r5`. The R5 audit adds the canonical
R5 `_format` values `application/fhir+xml` and `application/fhir+json` while
retaining the existing generic XML/JSON aliases and the DSTU2-specific MIME
selection. R5 response equality is strict: it ignores only server-managed
`id`, `meta.versionId`, and `meta.lastUpdated` fields. DSTU2, STU3, R4, and
R4B retain the prior warning-only comparison behavior.

The existing `FormatSuiteTest` matrix ran under rbenv Ruby 3.4.9 using the
visible `tmp/task-7b/Gemfile` local-path dependencies. It covers STU3, R4,
R4B, and R5 without changing the legacy cases; the added canonical R5 aliases
raise the suite total from 22 to 26 cases for every version.

| Verification | Result |
| --- | --- |
| `test/unit/format_suite_test.rb` | 4 tests, 27 assertions, 0 failures, 0 errors, 0 omissions |
| `test/unit/supported_versions_test.rb` | 8 tests, 11 assertions, 0 failures, 0 errors, 0 omissions |
| `test/unit/task_routing_test.rb` | 9 tests, 33 assertions, 0 failures, 0 errors, 0 omissions |
| R5 `FormatTest` endpoint run | 26 pass, 0 fail, 0 error, 0 skip |
| R5 default/JSON/XML POST content-type probe | 3 created `FHIR::R5::Patient` resources, each `201 Created` |

The endpoint suite ran against the user-built
`sparkfhir/spark:r5-latest` and `sparkfhir/mongo:r5-latest` images using the
local-source Task 6G image `incendi/plan_executor:r5-task-6g-local`. It
verified header negotiation, generic and canonical `_format` values, XML and
JSON Bundle responses, cross-format resource equivalence, and the expected
`406 Not Acceptable` behavior for unsupported Accept and `_format` values.
The direct probe additionally verified default JSON, explicit JSON, and
explicit XML `Content-Type` values end-to-end; each response parsed as
`FHIR::R5::Patient`.

Raw endpoint logs and the retained probe are under `tmp/task-7d/` and are not
committed. The endpoint image source snapshot intentionally omits `.git`
metadata, which accounts for its non-fatal `not a git repository` startup
diagnostics.

## Task 7E: Transaction And Batch Suite Verification

Verification performed: 2026-07-29.

`TransactionAndBatchTest` now explicitly advertises `:r5`. Transaction
assertions require `transaction-response` and batch assertions require
`batch-response` across every supported FHIR version. The generator now
supplies the mandatory R5
`Condition.clinicalStatus` alongside `verificationStatus`, using the selected
FHIR namespace for both R4B and R5 models.

`R5TransactionSuiteTest` verifies R5 request construction and parsing for
POST, PUT, DELETE, GET search, conditional create, conditional update,
temporary `urn:uuid` references, failure `OperationOutcome` handling, and
transaction/batch response Bundle distinctions. Its recursive namespace check
rejects response graphs containing non-R5 model instances.

| Verification | Result |
| --- | --- |
| `test/unit/r5_transaction_suite_test.rb` | 3 tests, 53 assertions, 0 failures, 0 errors |
| R5 `TransactionAndBatchTest` endpoint run | 8 pass, 0 fail, 0 error, 5 existing Spark issue skips |
| Independent R5 batch endpoint probe | `200 OK`, `batch-response`, 2 `201 Created` response entries, both `FHIR::R5::Observation` |

The endpoint run used the clean local Spark master image containing Spark
commit `955b25e7` (`Engine: Return correct bundle response for
batch/transaction bundles`), plus `sparkfhir/mongo:r5-latest`. The Spark fix
applies to batch and transaction responses across all supported FHIR versions;
this audit verifies its R5 behavior. The five skips remain linked to existing
Spark issues: XFER4, XFER11, and XFER12 (`#305`), XFER5 (`#304`), and XFER10
(`#306`). The independent batch probe is retained because those historical
batch cases remain skipped; it verifies that a live two-entry R5 batch now
returns one `batch-response` entry per submitted create.

Raw endpoint logs and the retained probe are under `tmp/task-7e/` and are not
committed. As with prior local-source endpoint runs, the image source snapshot
omits `.git` metadata, causing non-fatal `not a git repository` diagnostics at
startup.

## Task 7F: FHIRPath Patch Suite Verification

Verification performed: 2026-07-29.

`FhirPathPatchTest` now explicitly advertises `:r5`. Its R5 fixture uses the
required `MedicationRequest.medication` `CodeableReference` rather than the
STU3 `medicationCodeableConcept` representation. The PATCH client uses the
requested format for both the Parameters body and `Accept` header, so JSON and
XML patch requests negotiate matching JSON and XML representations.

`R5FhirPathPatchSuiteTest` executes the suite lifecycle with an R5 client and
verifies R5 Parameters construction, JSON/XML round trips, choice-element
syntax, version changes, and stale-version rejection without a resource
mutation. The stale assertion sends the correct weak ETag form,
`If-Match: W/"[versionId]"`, and accepts the specification-valid `409` or
`412` result.

| Verification | Result |
| --- | --- |
| `test/unit/r5_fhirpath_patch_suite_test.rb` | 3 tests, 57 assertions, 0 failures, 0 errors |
| R5 `FhirPathPatchTest` endpoint run | 6 pass, 0 fail, 0 error, 0 skip |
| Live version-aware probe | Matching `W/"1"`: `200`; stale `W/"1"`: `409 Conflict` with `FHIR::R5::OperationOutcome`; final status `completed`, final version `2` |

The endpoint evidence uses a local R5 Spark image built from the shared engine
change that validates the versioned PATCH key before applying the patch. That
change sits in `Libraries/Spark.Engine/Service/FhirService.cs`, so the same
behavior applies to the STU3, R4, R4B, and R5 Spark applications. The R5
endpoint used `sparkfhir/mongo:r5-latest` and the Task 6G local-source harness
image.

Raw endpoint logs and the retained probe are under `tmp/task-7f/` and are not
committed. The harness source snapshot omits `.git` metadata, causing its
non-fatal `not a git repository` diagnostics at startup.
