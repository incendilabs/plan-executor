# R4B Support Action Points

## Design Rules

- Treat `:r4` and `:r4b` as distinct harness versions.
- Never allow R4B to resolve through implicit R4 fallback.
- Shared R4/R4B behavior is allowed only through explicit compatibility annotations.
- Keep R4 models at the existing top-level `FHIR::*` namespace for backward compatibility and expose R4B models through the required `FHIR::R4B::*` namespace.
- Require an explicit version at every client, task, structure, fixture, and
  resource-generator boundary. Omitted and unknown versions must fail fast.
- `fhir_client` may use the explicit sentinel `fhir_version: :auto` only for
  CapabilityStatement discovery. Versioned resource operations must remain
  unavailable until discovery selects a concrete version.
- Keep version annotations explicit, even for resources that are normative or unchanged across R4 and R4B.
- Add R4B model support to `fhir_models`; do not introduce a separate R4B model gem by default.
- Keep the registry of versions understood by the harness separate from the versions supported by each test suite.

## Related Repositories

- `git@github.com:incendilabs/fhir_client.git`, local path `../fhir_client`
- `git@github.com:incendilabs/fhir_models.git`, local path `../fhir_models`
- `git@github.com:incendilabs/fhir_dstu2_models.git`, local path `../fhir_dstu2_models`
- `git@github.com:incendilabs/fhir_stu3_models.git`, local path `../fhir_stu3_models`

R4B feature work is expected in `fhir_models`, `fhir_client`, and this repository. The DSTU2 and STU3 model repositories remain in scope as regression dependencies, but no R4B feature changes are expected in them.

## Implementation Status

- `fhir_models` now has namespace-aware infrastructure, generated
  `FHIR::R4B` models, checked-in R4B runtime definitions, documented generation,
  and R4B XML schema validation. These changes are split across commits
  `cf7f5d5a`, `03059207`, `90cd55fd`, `67738dfe`, and `444f74f7`.
- `fhir_client` now has explicit R4B routing and CapabilityStatement version
  detection in commit `7bde8ed2`.
- Strict client versioning is a separate breaking change in commit `75d3c33`:
  `FHIR::Client.new` requires `fhir_version:`, direct R4 remains
  `fhir_version: :r4`, and automatic discovery must be requested with
  `fhir_version: :auto`.
- `plan-executor` now has a central version registry, version-aware resource
  routing, a generated R4B structure index, corrected version-specific fixture
  lookup, and explicit suite compatibility annotations. These changes are split
  across commits `17537c9a`, `2e7a759`, `d70c01c`, `12e10e8`, and `a2b1482`.
- Strict harness versioning and namespace-explicit generator helpers are in
  commit `16347df`.
- All 12 executable Ruby suites that already support R4 now explicitly support
  R4B in commit `826433b`. STU3-only, DSTU2-only, TestScript, and explicitly
  unsupported suites retain their existing annotations.
- The R4B PackagedProductDefinition fixture defect is resolved. Empty generated
  `CodeableReference` values now receive a same-namespace text concept, so
  recursive `containedItem.item` elements remain present when serialized. The
  fix is commit `49e713f`.
- The nondeterministic R4B Questionnaire defect is resolved. Generated codes
  are selected from concrete expansion entries while abstract and inactive
  entries remain available in the checked-in terminology definitions. The fix
  is commit `84fa7c4`.
- `plan-executor` now resolves `fhir_models` and `fhir_client` from their merged
  `origin/master` branches, with the exact resolved revisions retained in
  `Gemfile.lock`.
- Remaining integration work consists of completing the STU3 and DSTU2
  cross-version regression matrix.

## Baseline And Dependency Actions

- Reconcile the local `../fhir_models` checkout with the version currently resolved by this repository before implementing R4B. The local checkout identifies itself as gem version `4.1.0` with FHIR `4.0.1` definitions, while this repository currently locks released `fhir_models` version `4.3.0`.
- Do not confuse the `fhir_models` gem version with the FHIR specification version. Record both independently.
- Pin the official FHIR R4B `4.3.0` JSON definitions archive, JSON ValueSet
  expansion Bundle, and XML schema archive used for generation. Generate models
  and runtime definitions with
  `bundle exec rake "fhir:generate_r4b[path/to/r4b-definitions.json.zip,path/to/expansions.json]"`.
  Generate the XML schema set with
  `bundle exec rake "fhir:generate_r4b_schema[path/to/r4b-fhir-all-xsd.zip]"`.
  Download the artifacts from the official HL7
  [`definitions.json.zip`](https://www.hl7.org/fhir/R4B/definitions.json.zip) and
  [`expansions.json`](https://www.hl7.org/fhir/R4B/expansions.json) endpoints, and
  the [`fhir-all-xsd.zip`](https://www.hl7.org/fhir/R4B/fhir-all-xsd.zip)
  endpoint.
  The pinned SHA-256 values are
  `a2793a06853c2d4540db8a72fc1c6d972528b01d113c2bb70ae2d80dc062e963`
  for the definitions archive and
  `fe10ca33f0de85c16b367cb57092076d7e2fbd7aff6479c8862a32bd227e3b07`
  for the expansion Bundle, and
  `3528d4ff44c69f2908d6159367d58b9d12fb41a48d1be3ec897947129696e6b4`
  for the XML schema archive.
- Define the local cross-repository development setup, using temporary `path:` dependencies or equivalent local wiring so changes in `../fhir_models` and `../fhir_client` are exercised by this repository.
- Define the release and dependency update order: `fhir_models`, then `fhir_client`, then `plan-executor`.
- Complete: resolve `fhir_models` and `fhir_client` from their merged master
  branches and retain their immutable resolved revisions in `Gemfile.lock`.

## Model Definition Architecture

### R4 Baseline

- R4 runtime definitions remain under `lib/fhir_models/definitions/` in
  `fhir_models`.
- R4 stores separate preprocessed files for StructureDefinitions, ValueSets,
  expansions, XML schemas, and version metadata.
- `FHIR::Definitions` reads the individual JSON files directly. R4 XML
  validation reads the XSD files under `lib/fhir_models/definitions/schema/`.
- The generated R4 Ruby models remain separate under `lib/fhir_models/fhir/`.
- Preserve this layout and the existing top-level `FHIR::Definitions` API for
  backward compatibility.

### R4B Runtime Definitions

- Generated R4B Ruby models and metadata are stored under
  `lib/fhir_models/r4b/`.
- R4B runtime definitions follow the established R4 directory pattern under
  `lib/fhir_models/definitions/r4b/`, with separate `structures/`,
  `valuesets/`, and `schema/` directories plus `version.info`.
- `FHIR::Definitions` and `FHIR::R4B::Definitions` use the same configurable,
  directory-backed provider. R4 remains configured against
  `lib/fhir_models/definitions/`, while R4B is configured against
  `lib/fhir_models/definitions/r4b/` and constructs R4B model objects.
- Definition bundles are parsed lazily and cached in memory. The R4B provider
  verifies `version.info` against FHIR version `4.3.0` before loading them.
- StructureDefinition objects returned by the provider must be
  `FHIR::R4B::StructureDefinition` instances. Model binding, reference, and
  StructureDefinition validation must select definitions from the owning model
  namespace and must never fall back implicitly from R4B to R4.
- The checked-in generated files contain datatype and resource
  StructureDefinitions, profiles, extensions, search parameters, ValueSets,
  expansions, and version metadata.
- The shared provider preserves the existing R4 Definitions API for both
  versions, including raw `valuesets`, raw `expansions`, terminology lookup,
  display lookup, and dynamic `get_profile_class` behavior.

### Generation And Repository Policy

- Official HL7 `definitions.json.zip` and `expansions.json` files are generation
  inputs. Pin their URLs and SHA-256 checksums, but do not check the downloaded
  source artifacts into the repository.
- Generate and check in the R4B Ruby models and the derived, preprocessed
  runtime definition files. Normal use of the `fhir_models` gem must not require
  a network connection or local copies of the HL7 source downloads.
- Generation must be deterministic. Repeated generation from the pinned inputs
  must produce byte-identical Ruby models and runtime definition output.
- Keep the generated definition files as text. Git already compresses repository
  objects, while text files retain useful diffs and delta compression that a
  generated gzip index would prevent.

### Harness Structure Index

- `lib/FHIR_structure_r4b.json` is generated from the pinned R4B
  `definitions.json.zip` input and checked into `plan-executor`.
- Regenerate it with
  `bundle exec rake "crucible:generate_r4b_structure[path/to/r4b-definitions.json.zip]"`.
  The task verifies the pinned source checksum before reading
  `profiles-resources.json` from the archive.
- Resource names and categories come from concrete specialization
  StructureDefinitions. The existing R4 structure index supplies only the
  non-resource hierarchy and category template; it is not the source of the
  R4B resource list.
- The official R4B StructureDefinitions omit category extensions for
  `ResearchDefinition` and `ResearchElementDefinition`. The generator assigns
  both explicitly to `Specialized.Evidence-Based Medicine`.
- The downloaded definitions archive remains an untracked generation input.
  Repeated generation from the pinned input must produce byte-identical output.

### XML Schema Status

- The generated R4B JSON definition bundles do not contain the R4B XML XSD
  schema set; the schemas come from the separately pinned official archive.
- `FHIR::R4B::Xml.validate` uses the R4B `4.3.0` schema set and does not reuse
  the R4 `4.0.1` schema directory.
- Generated, preprocessed R4B schemas are checked in under
  `lib/fhir_models/definitions/r4b/schema/`, parallel to R4. Use the existing
  `FHIR::Boot::Preprocess.pre_process_schema` implementation rather than adding
  a separate schema generator or runtime schema abstraction.
- The original downloaded HL7 schema archive remains a checksum-pinned
  generation input and is not checked into the repository.

## Compatibility Annotation Actions

- Introduce one authoritative registry of FHIR versions understood by the harness. This registry may include `:r4b`, but it must not imply that every suite supports R4B.
- Keep `supported_versions` as the explicit suite compatibility annotation.
- `BaseTest#supported_versions` defaults to an empty list. Do not add `:r4b` or
  any other implicit compatibility to that default.
- Add `:r4b` explicitly to each compatible suite; do not infer R4B support from
  R4 support at runtime.
- All executable suites now have explicit annotations. Seven suites that
  previously relied on the base default explicitly preserve their existing
  compatibility. All 12 suites that support R4 now also declare R4B explicitly.
  No suite gains R4B support implicitly.
- Update resource-based suite enumeration so it intersects known versions, the suite's declared `supported_versions`, and resources available in that version. It must not overwrite a suite's declared compatibility.
- Ensure suite listing and suite execution use the same compatibility decision.
- Keep TestScripts STU3-only unless separate R4B TestScripts and an R4B TestScript parser are deliberately added.

## Implementation Actions

### 1. R4B Models In `fhir_models`

- Refactor model generation so the output directory and Ruby namespace are version-aware instead of being hard-coded to the top-level `FHIR` namespace.
- Refactor JSON and XML deserialization, resource detection, validation, metadata, definitions, and schema lookup so they resolve classes and resource lists through the selected model namespace.
- Preserve the current top-level R4 public API while adding generated R4B classes, metadata, parsers, validation, definitions, schemas, and resource lists under `FHIR::R4B`.
- Ensure embedded resources, contained resources, Bundle entries, complex data types, and generated references remain in the R4B namespace.
- Add model-level tests for generation, parsing, serialization, validation, and namespace purity.

### 2. R4B Routing In `fhir_client`

- Add `use_r4b` and route `:r4b` resource lookup, parsing, request replay, response validation, transactions, operations, and capability statements through `FHIR::R4B`.
- Require `fhir_version:` when constructing a client. Do not retain R4 as a
  constructor default.
- Permit `fhir_version: :auto` only as an explicit discovery mode. Metadata may
  establish a concrete version, but resource operations must reject `:auto`
  until that has happened.
- Make JSON and XML reply parsing select R4B explicitly instead of allowing the existing non-DSTU2/STU3 fallback to use R4.
- Map CapabilityStatement `fhirVersion` values explicitly: `4.0.x` to `:r4` and `4.3.x` to `:r4b`.
- Do not classify every version beginning with `4` as R4. Unknown FHIR 4.x releases must be reported as unsupported rather than silently parsed as R4.
- Test both explicit `use_r4b` selection and automatic version detection.

### 3. R4B Routing In `plan-executor`

- Add `r4b` parsing to the rake version resolver and test that omitted and
  unknown versions fail fast.
- Replace scattered version conditionals with a central namespace resolver where practical.
- Add explicit R4B namespace and resource resolution in `BaseTest`, `BaseSuite`, OperationOutcome parsing, capability statement handling, fixture validation, resource category lookup, and resource generation helpers.
- Initialize R4B base resources with the active client without affecting R4, STU3, or DSTU2 resources.
- Add `lib/FHIR_structure_r4b.json`, generated from the same pinned R4B definitions used by the models.
- Extend structure tests to compare R4B structure metadata against `FHIR::R4B::RESOURCES`, and fix existing structure-root tests so they make assertions.
- Fix version-specific fixture override lookup before adding `*.r4b.xml` or `*.r4b.json` fixtures.
- Version-specific fixture overrides are stored beside the base fixture as
  `<base>.r4b.xml` or `<base>.r4b.json`. Lookup falls back to the base fixture
  only when no version-specific file exists. Reuse of a base fixture still
  requires validation before a suite can declare R4B compatibility.
- Update README and shell usage documentation to list `r4b`.

## Pitfalls To Avoid

- Do not let `r4b` fall into top-level `FHIR::Patient` or `FHIR::Bundle` R4 classes by default.
- Do not treat passing R4 smoke tests as proof of R4B support.
- Do not reuse R4 fixtures for R4B unless validation proves they are compatible.
- Do not enable STU3 TestScripts for R4B unless separate R4B TestScripts are added.
- Watch for model/client dependency gaps where R4B model classes exist but parsing, capability statements, or client version activation do not.
- Do not let metadata listing advertise R4B support that execution would reject, or vice versa.
- Do not treat a normative resource as automatically compatible at the suite level; test semantics, search parameters, fixtures, and assertions still require an explicit audit.
- Do not allow generated R4B resources to contain top-level R4 complex types or contained resources.
- Do not publish the harness against a client or model dependency that is only available through an unrecorded local checkout.

## Validation Milestones

### Model Validation

- R4B JSON and XML examples parse into `FHIR::R4B::*` and round-trip successfully.
- Bundle entries and contained resources remain entirely within `FHIR::R4B`.
- R4B resource generation produces valid resources without top-level R4 model instances.
- At least one R4B-only field or changed structure is accepted by R4B validation and rejected by R4 validation, proving that R4B is not an alias.
- R4 behavior and its existing top-level namespace remain unchanged.

### Client Validation

- Explicit `use_r4`, `use_r4b`, `use_stu3`, and `use_dstu2` select the expected model namespace.
- CapabilityStatement detection distinguishes FHIR `4.0.x` from `4.3.x` and rejects unsupported versions.
- Read, search, create/update, Bundle, OperationOutcome, transaction, and format handling parse responses through the selected namespace.

### Harness Validation

- `bundle exec rake crucible:list_all[r4b]` lists only suites explicitly annotated for R4B.
- Resource-based suites instantiate R4B classes, not R4 classes, and only enumerate resources present in `FHIR::R4B::RESOURCES`.
- Listing and executing suites apply identical version eligibility rules.
- An omitted or unknown CLI version exits with a clear error. R4 must be
  selected explicitly with `r4`.
- `FHIR_structure_r4b.json` passes resource-list consistency and duplicate-name checks.
- Version-specific fixture override selection has focused unit coverage.
- `FormatTest` passes all 22 cases against a Spark endpoint whose
  CapabilityStatement reports FHIR `4.3.0` and both `xml` and `json`. The audit
  used `sparkfhir/spark:r4b-latest` image
  `sha256:720309c969f8562f418948197b794cc01cc07e5be2d7a82873562a8714719e82`
  and `sparkfhir/mongo:r4b-latest` image
  `sha256:10a44ee9fa2c6a42325656b1758b3fb14be00dfe84a6d999e1b9b3d695fc29d5`.
  This covers Patient read, search Bundle, JSON, XML, and format negotiation.
- Existing R4, STU3, and DSTU2 tests remain unchanged in behavior and pass their regression matrix.

## R4B Full-Suite Endpoint Audit (2026-07-17)

### Scope And Execution

- This was a diagnostic run against the local Spark R4B endpoint at
  `http://localhost:18080/fhir`. It used the same Spark and Mongo image digests
  recorded for the FormatTest audit above.
- The run used temporary `path:` dependencies for the local `../fhir_models`,
  `../fhir_client`, `../fhir_stu3_models`, and `../fhir_dstu2_models`
  repositories so the unpublished R4B model and client changes were loaded.
- Only suites whose existing `supported_versions` declaration contained `:r4`
  were temporarily given `:r4b`. STU3-only, DSTU2-only, TestScript, and
  explicitly unsupported suites were not enabled. These temporary annotations
  were made in an isolated copy. The later 2026-07-23 verification below
  records the permanent annotations after strict version routing was added.
- The normal suite registry exposed 12 eligible suites. Eligibility was checked
  with:

  ```sh
  bundle exec rake "crucible:list_suites[r4b]"
  ```

- Each suite was then run separately through the documented Rake entry point:

  ```sh
  bundle exec rake "crucible:execute[http://localhost:18080/fhir,r4b,SUITE_NAME,,stdout]"
  ```

  The empty resource argument caused `ResourceTest` and `SearchTest` to exercise
  every R4B resource rather than a single named resource. Suites were run
  sequentially because they create, update, and delete shared endpoint data.
- The test process must be allowed to connect to the local endpoint. A sandboxed
  attempt produced `Operation not permitted` TCP errors and invalid all-skip or
  all-error results; those results were discarded. The Rake task also expects
  the local `logs/` directory to exist.

### Results

| Suite | Pass | Fail | Error | TODO skip | Exit |
| --- | ---: | ---: | ---: | ---: | ---: |
| `SprinklerSearchTest` | 36 | 0 | 0 | 2 | 0 |
| `ConsentSearchByPatientReferenceTest` | 1 | 0 | 0 | 0 | 0 |
| `ElementsSearchParameterTest` | 1 | 0 | 0 | 1 | 0 |
| `UnknownSearchParameterTest` | 12 | 0 | 0 | 0 | 0 |
| `ReadTest` | 5 | 0 | 0 | 0 | 0 |
| `ResourceTest` | 2075 | 10 | 0 | 417 | 1 |
| `FhirPathPatchTest` | 4 | 0 | 0 | 2 | 0 |
| `FormatTest` | 22 | 0 | 0 | 0 | 0 |
| `TransactionAndBatchTest` | 2 | 6 | 0 | 5 | 1 |
| `SearchTest` | 973 | 0 | 0 | 0 | 0 |
| `HistoryTest` | 10 | 0 | 0 | 0 | 0 |
| `RobustSearchTest` | 0 | 0 | 0 | 1 | 0 |
| **Total** | **3141** | **16** | **0** | **428** | **2 suites failed** |

All 428 skips were existing `TODO` skips. They do not cause the Rake task to
exit non-zero. The 16 failures are concentrated in the two suites shown above;
they are not 16 independent compatibility defects.

### Failure Areas

#### 1. R4B Condition Status Conversion

- `TransactionAndBatchTest` fails first in `XFER0`. The generated transaction
  serializes `Condition.verificationStatus` as the primitive string
  `"confirmed"`, while R4B requires a `CodeableConcept`.
- Spark returns HTTP 400 with an OperationOutcome reporting that it encountered
  a JSON primitive where a non-primitive `verificationStatus` object was
  required. Five later transaction assertions then fail because they depend on
  `XFER0` having created the patient record.
- `ResourceGenerator.fix_condition` currently converts R4 status strings only
  when `resource.is_a?(FHIR::Condition)`. A `FHIR::R4B::Condition` does not
  satisfy that check, so the existing R4 compatibility correction is skipped.
- The correction must become namespace-aware and cover both
  `clinicalStatus` and `verificationStatus` without making R4B inherit from or
  fall back to the R4 model class. Add focused serialization coverage before
  rerunning `TransactionAndBatchTest`.

#### 2. Recursive PackagedProductDefinition Generation

- `ResourceTest` deterministically generates invalid deeply nested
  `PackagedProductDefinition` resources. At the generator recursion boundary,
  `package.package[].package[].containedItem[].item` is omitted even though its
  minimum cardinality is one.
- Spark rejects these resources with HTTP 400. The initial create failures then
  cause conditional create, conditional update, and history assertions to fail
  or operate on incomplete setup state.
- A targeted documented run reproduces the problem:

  ```sh
  bundle exec rake "crucible:execute[http://localhost:18080/fhir,r4b,ResourceTest,PackagedProductDefinition,stdout]"
  ```

- Fixing this requires a finite minimal representation for the recursive
  package structure. The recursion guard must still prevent infinite trees, but
  it cannot terminate by omitting a required child. Add a generator test that
  validates the generated JSON or XML against the R4B model/schema.

#### 3. Abstract Questionnaire Item Code Generation

- The generated R4B metadata for `Questionnaire.item.type` includes the
  abstract code `question` in `valid_codes`. `ResourceGenerator` samples from
  that list and may emit `type: "question"` in one or more nested items.
- Spark rejects that value because it is not a selectable
  `QuestionnaireItemType`. The exact number of failed ResourceTest assertions
  varies with random generation; a targeted rerun reproduced failures in
  create and update operations.
- Reproduce with:

  ```sh
  bundle exec rake "crucible:execute[http://localhost:18080/fhir,r4b,ResourceTest,Questionnaire,stdout]"
  ```

- Preserve the complete terminology definitions needed at runtime, but prevent
  abstract or non-selectable codes from being chosen for generated resource
  instances. Add deterministic coverage proving that generated Questionnaire
  items use only concrete item types.

### Follow-Up Sequence

1. Add focused failing tests for R4B Condition status conversion,
   PackagedProductDefinition recursion, and Questionnaire item-type selection.
2. Make the resource generator namespace-aware where it currently dispatches
   only on top-level R4 classes. Review the rest of `apply_invariants!` for the
   same pattern.
3. Fix and rerun the three targeted commands above, including
   `TransactionAndBatchTest` through `crucible:execute`.
4. Repeat the complete 12-suite R4B endpoint run and retain per-suite output and
   shell exit status.
5. Run the existing R4 unit and endpoint regression suites to detect shared
   generator regressions.

### Existing Endpoint Regression Baselines

The following existing endpoint results were provided on 2026-07-17. They were
not rerun as part of the R4B audit, but should be retained as the comparison
baseline for later cross-version regression runs.

| Version | Pass | Fail | Error | Skip |
| --- | ---: | ---: | ---: | ---: |
| STU3 | 2876 | 0 | 0 | 413 |
| R4 | 3267 | 0 | 0 | 443 |

Future runs should compare both the totals and the individual skipped tests.
The totals alone do not establish whether a changed skip is expected.

## Strict Versioning Docker Verification (2026-07-23)

- The Docker image was built with the repository `Dockerfile` and a disposable
  build context containing the current local `fhir_client`, `fhir_models`,
  `fhir_stu3_models`, and `fhir_dstu2_models` working trees as `path:`
  dependencies. The resulting image was
  `incendi/plan_executor:strict-r4b`, image ID
  `sha256:b5ae435552fd1305d072c021d1b140db1461daa2b23d2cd1183855ec96bfa975`.
- The plan-executor unit suite passed `1218` tests and `3680` assertions with no
  failures or errors inside that image.
- Focused `fhir_client` coverage for required versions, `:auto`, R4B routing,
  and external references passed `79` tests and `186` assertions with no
  failures or errors.
- The complete modified `fhir_client` suite reported `114` tests, `269`
  assertions, and the same five errors reproduced by the committed baseline in
  the identical container. Four are caused by invalid JSON escapes in the
  existing `fhir_api_validation.json`; one is existing shared model-client
  state in `test_class_partial_update`. The strict-versioning change introduced
  no additional full-suite failures.
- The CI-style Compose run used
  `sparkfhir/spark:r4b-latest` image ID
  `sha256:d5139dcba0a3e17aac71b36d31271326111248ad4af1bc16b095d423f2b7d2d8`
  and `sparkfhir/mongo:r4b-latest` image ID
  `sha256:9c8e741da8cbce3b5e10e845717c368f41a2e27311912541ed2192110d4d7741`.
  The initial
  `./execute_all.sh http://spark:8080/fhir r4b html|json|stdout` run included
  only `FormatTest` and passed all `22` cases. The expanded run is recorded
  below.

## R4B Enabled-Suite Verification (2026-07-23)

- Every Ruby suite that declares R4 support now also explicitly declares R4B
  support. `crucible:list_suites[r4b]` lists 12 suites:
  `ReadTest`, `ResourceTest`, `FhirPathPatchTest`, `FormatTest`,
  `TransactionAndBatchTest`, `SearchTest`, `HistoryTest`, `RobustSearchTest`,
  `SprinklerSearchTest`, `ConsentSearchByPatientReferenceTest`,
  `ElementsSearchParameterTest`, and `UnknownSearchParameterTest`.
- `FhirPathPatchTest` now obtains `MedicationRequest` through its selected
  version namespace instead of using the top-level R4 model class. An audit of
  the other 11 suites found no unversioned resource-model constants.
- A unit invariant requires the set of R4 suites and the set of R4B suites to
  remain identical. The Docker unit run passed `1218` tests and `3680`
  assertions with no failures or errors.
- The CI-style endpoint command was:

  ```sh
  docker compose run --rm --no-deps plan_executor \
    ./execute_all.sh http://spark:8080/fhir r4b 'html|json|stdout'
  ```

- The disposable plan-executor image was
  `incendi/plan_executor:all-r4b`, image ID
  `sha256:7891bc0c6347a99b54d5b5382b9081d7c8b422aee6bd3d85ca93e73c4cdd3221`.
  The Spark and Mongo image IDs were
  `sha256:d5139dcba0a3e17aac71b36d31271326111248ad4af1bc16b095d423f2b7d2d8`
  and
  `sha256:9c8e741da8cbce3b5e10e845717c368f41a2e27311912541ed2192110d4d7741`.
- The endpoint run completed 3,585 tests in 234 seconds:

  | Pass | Fail | Error | TODO skip |
  | ---: | ---: | ---: | ---: |
  | 3149 | 8 | 0 | 428 |

- All eight failures in this run were in
  `ResourceTest_PackagedProductDefinition`. Three create or update requests
  were rejected because generated nested package entries omitted required
  `containedItem.item`; five conditional and history assertions then failed
  because those resources were not created.
- All 428 skips remain existing `TODO` skips. FHIR TestScript artifacts remain
  explicitly STU3-only and were not part of this R4B run.

### PackagedProductDefinition Generator Fix

- The root cause was a recursion-boundary `CodeableReference` object with
  neither `concept` nor `reference`. Although the required object existed in
  memory, it serialized as an empty object and the effective
  `containedItem.item` element was omitted.
- `ResourceGenerator` now gives an otherwise empty generated
  `CodeableReference` a text-only `CodeableConcept` from the selected FHIR
  namespace. Existing concept or reference values are preserved. This is a
  datatype invariant rather than a PackagedProductDefinition-specific
  traversal.
- Focused unit coverage checks empty and populated R4B CodeableReference
  behavior, every recursively generated contained item, and R4B XML schema
  validation. The Docker unit suite passed `1221` tests and `3688` assertions
  with no failures or errors.
- A fresh focused endpoint run of
  `ResourceTest_PackagedProductDefinition` completed with `15` passes, no
  failures or errors, and the existing `3` TODO skips.
- A subsequent fresh 12-suite run confirmed the same PackagedProductDefinition
  result. The aggregate result was `3151` passes, `6` failures, no errors, and
  `428` TODO skips. All six failures were the separately documented
  nondeterministic Questionnaire `type: question` defect; none belonged to
  PackagedProductDefinition.
- Verification used `incendi/plan_executor:packaged-product-fix`, image ID
  `sha256:b8a9ee41b11496a99e38a6dc93ba061d720075477c31d9ea5deafcf6f5900c62`,
  with the same R4B Spark and Mongo image IDs recorded above.

### Questionnaire Selectable-Code Fix

- Generated model metadata continues to contain the complete required
  `QuestionnaireItemType` code set, including the abstract `question` grouping
  code. The terminology artifacts and generated models were not rewritten.
- `ResourceGenerator` now derives a cached selectable-code set from the
  namespace's original ValueSet expansion. Entries marked `abstract` or
  `inactive` are excluded from generated instances, while concrete descendants
  of abstract grouping entries remain selectable.
- The same filtering is used for primitive `code`, `Coding`, and
  `CodeableConcept` generation. If a binding has no matching expansion or
  filtering would remove every generated code, the existing generated metadata
  remains the fallback.
- Focused tests prove that the complete R4B Questionnaire metadata still
  includes `question`, the selectable set excludes it, and every recursively
  generated Questionnaire item uses a selectable type. The Docker unit suite
  passed `1224` tests and `3694` assertions with no failures or errors.
- Three initial consecutive `ResourceTest_Questionnaire` endpoint runs each
  completed with `15` passes and the existing `3` TODO skips. After correcting
  the cache scope to cache expansion data rather than field-specific
  intersections, the final image produced the same focused result and no
  generated Questionnaire payload contained `type: question`.
- A final fresh 12-suite R4B run completed in 236 seconds with `3157` passes,
  no failures or errors, and `428` existing TODO skips. The command exited
  successfully, and PackagedProductDefinition remained clean in the same run.
- Verification used `incendi/plan_executor:questionnaire-fix`, image ID
  `sha256:f6dda44f11bcf8eafac55695d4e9f066f377473b3310963e2b3d94fa83ca7680`,
  with the same R4B Spark and Mongo image IDs recorded above.

### R4 Regression Verification

- The final Questionnaire implementation was run against the fresh
  `sparkfhir/spark:r4-latest` and `sparkfhir/mongo:r4-latest` images, with image
  IDs
  `sha256:411d6ea0d92c8001359eec3d749c643a28b207f3ac6f0f3362f1d39081348bf7`
  and
  `sha256:cf64b34e58f6f88f5350cef5066456f69585e4ec4716bcdb56579e3153950e4c`.
  The plan-executor image was the same final image recorded above.
- The R4 Spark image contains a local Kestrel HTTPS endpoint configuration but
  no server certificate. Its first startup therefore entered a restart loop,
  and that infrastructure-only run was discarded. The clean retry used the
  disposable environment override
  `Kestrel__Endpoints__Https__Url=http://+:8080`; neither the image nor
  repository configuration was changed.
- The fresh full R4 run completed in 145 seconds with `3267` passes, no failures
  or errors, and `443` TODO skips. The command exited successfully and exactly
  matched the recorded R4 aggregate baseline.
- `ResourceTest_Questionnaire` completed with `15` passes, no failures or
  errors, and the existing `3` TODO skips. No generated Questionnaire payload
  contained `type: question`.

### Merged Dependency Verification

- `fhir_models` resolves from
  `https://github.com/incendilabs/fhir_models.git` master revision
  `a143d2e21d0253b33fdaeb17e2d152ad656c9a3e`.
- `fhir_client` resolves from
  `https://github.com/incendilabs/fhir_client.git` master revision
  `79026641f9b2ac7cf30bc27a3528e505d34c67e8`.
- A repository Docker build using only the merged Git dependencies produced
  `incendi/plan_executor:master-r4b-deps`, image ID
  `sha256:927c11680443ee857d039ec71eea63cfa8b6c28da5a96d494a1c5b9c9f974345`.
  The image loaded `fhir_client` 5.0.0, `fhir_models` 4.1.0, and
  `FHIR::R4B::Patient`.
- The Docker unit suite passed `1224` tests and `3694` assertions with no
  failures or errors.

### Deferred STU3 TestScript Regression

- Run the 71 FHIR TestScript artifacts against a STU3 endpoint as a separate
  regression exercise. They remain explicitly STU3-only and are not part of
  either the R4 or R4B suite runs.
- The dedicated `crucible:execute_all_testscripts` and
  `crucible:testreport` tasks now require a FHIR version and construct the
  client with that version. They still bypass the normal suite
  `supported_versions` filter, so the deferred regression must invoke them with
  `stu3` explicitly and verify the endpoint version.
- The eventual regression command must explicitly select `:stu3`, retain
  per-TestScript output and shell exit status, and use a CapabilityStatement to
  confirm that the target endpoint reports STU3 before execution.

## Recommended Implementation Order

1. Complete: reconcile the `fhir_models` baseline and dependency strategy.
2. Complete: refactor `fhir_models` generation and runtime for explicit `FHIR::R4B` support.
3. Complete: generate and validate the R4B model set.
4. Complete: add R4B routing, parsing, capability handling, and detection to `fhir_client`.
5. Complete: add the central version registry and fail-fast version resolution to `plan-executor`.
6. Complete: all 12 R4-capable Ruby suites explicitly declare R4B support and
   have been run against the R4B endpoint.
7. In progress: complete the STU3 and DSTU2 endpoint regression matrix. Merged
   dependency resolution and fresh R4 and R4B endpoint runs are complete.
8. Complete: remove implicit R4 defaults from `fhir_client` and
   `plan-executor`, make generator namespaces explicit, verify the breaking
   change in Docker, and commit it atomically.
