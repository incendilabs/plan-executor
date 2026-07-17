# R4B Support Action Points

## Design Rules

- Treat `:r4` and `:r4b` as distinct harness versions.
- Never allow R4B to resolve through implicit R4 fallback.
- Shared R4/R4B behavior is allowed only through explicit compatibility annotations.
- Keep R4 models at the existing top-level `FHIR::*` namespace for backward compatibility and expose R4B models through the required `FHIR::R4B::*` namespace.
- An omitted version may continue to default to R4, but an explicitly supplied unknown version must fail fast.
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
- `plan-executor` now has a central version registry, version-aware resource
  routing, a generated R4B structure index, corrected version-specific fixture
  lookup, and explicit suite compatibility annotations. These changes are split
  across commits `17537c9a`, `2e7a759`, `d70c01c`, `12e10e8`, and `a2b1482`.
- No executable suite currently declares R4B compatibility. Suites must be
  audited individually before `:r4b` is added to their annotations.
- Remaining integration work consists of publishing or pinning compatible
  `fhir_models` and `fhir_client` revisions, updating dependency resolution,
  auditing candidate suites, and running endpoint smoke tests and the final
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
- Update gem version constraints and `Gemfile.lock` to released versions or immutable commit references before final integration.

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
- Audit every suite and add `:r4b` only after its behavior, resources, fixtures, and assertions have been checked against R4B.
- All executable suites now have explicit annotations. Seven suites that
  previously relied on the base default explicitly preserve their existing
  `[:dstu2, :stu3, :r4]` compatibility; none implicitly gained R4B support.
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
- Make JSON and XML reply parsing select R4B explicitly instead of allowing the existing non-DSTU2/STU3 fallback to use R4.
- Map CapabilityStatement `fhirVersion` values explicitly: `4.0.x` to `:r4` and `4.3.x` to `:r4b`.
- Do not classify every version beginning with `4` as R4. Unknown FHIR 4.x releases must be reported as unsupported rather than silently parsed as R4.
- Test both explicit `use_r4b` selection and automatic version detection.

### 3. R4B Routing In `plan-executor`

- Add `r4b` parsing to the rake version resolver and test that omitted versions default to R4 while unknown supplied values fail fast.
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
- An omitted CLI version still selects R4; an unknown supplied version exits with a clear error.
- `FHIR_structure_r4b.json` passes resource-list consistency and duplicate-name checks.
- Version-specific fixture override selection has focused unit coverage.
- At least one read, search, JSON, and XML smoke path runs against an R4B endpoint.
- Existing R4, STU3, and DSTU2 tests remain unchanged in behavior and pass their regression matrix.

## Recommended Implementation Order

1. Complete: reconcile the `fhir_models` baseline and dependency strategy.
2. Complete: refactor `fhir_models` generation and runtime for explicit `FHIR::R4B` support.
3. Complete: generate and validate the R4B model set.
4. Complete: add R4B routing, parsing, capability handling, and detection to `fhir_client`.
5. Complete: add the central version registry and fail-fast version resolution to `plan-executor`.
6. Pending: audit suites and add explicit R4B compatibility annotations only where verified.
7. In progress: R4B structures and documentation are complete; R4B fixtures,
   endpoint smoke tests, dependency updates, and the full regression matrix
   remain.
