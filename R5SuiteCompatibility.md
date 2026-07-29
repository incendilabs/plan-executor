# FHIR R5 Suite Compatibility Inventory

Status date: 2026-07-29

This is the complete initial R5 audit inventory. It is derived from the 12
suite classes that currently declare `:r4b` in `supported_versions`.
R4B compatibility is not evidence of R5 compatibility. Every entry began as
`unaudited`; only suites with a completed audit explicitly declare `:r5`.

| Suite | Current versions | R5 status | Reason | Evidence |
| --- | --- | --- | --- | --- |
| `ConsentSearchByPatientReferenceTest` | STU3, R4, R4B | unaudited | R5 search-reference behavior has not been audited. | `SupportedVersionsTest#test_r5_compatibility_inventory_matches_the_complete_r4b_suite_set` |
| `ElementsSearchParameterTest` | STU3, R4, R4B | unaudited | R5 `_elements` semantics have not been audited. | Same inventory test |
| `FhirPathPatchTest` | STU3, R4, R4B, R5 | compatible | R5 FHIRPath Patch Parameters, JSON/XML request and response negotiation, R5 MedicationRequest lifecycle, choice-element syntax, and version-aware stale patch handling audited. | `R5FhirPathPatchSuiteTest`; `tmp/task-7f/FhirPathPatchEndpointAfterSparkFix.log`; `tmp/task-7f/StalePatchProbeAfterSparkFix.log` |
| `FormatTest` | DSTU2, STU3, R4, R4B, R5 | compatible | R5 JSON/XML negotiation, canonical media types, `_format` aliases, request content types, cross-format parsing, and unsupported-media handling audited; targeted R5 endpoint run passed. | `FormatSuiteTest`; `TaskRoutingTest#test_r5_eligibility_is_limited_to_audited_suites`; `tmp/task-7d/FormatTestEndpoint.log`; `tmp/task-7d/FormatContentTypesEndpoint.log` |
| `HistoryTest` | DSTU2, STU3, R4, R4B, R5 | compatible | R5 history, vread, deleted-resource, and error-response behavior audited; targeted R5 endpoint run passed. | `R5ReadHistorySuiteTest`; `TaskRoutingTest#test_r5_eligibility_is_limited_to_audited_suites`; `tmp/task-7b/HistoryTestEndpoint.log` |
| `ReadTest` | DSTU2, STU3, R4, R4B, R5 | compatible | R5 read, conditional-read, response parsing, and lifecycle setup audited; targeted R5 endpoint run passed. | `R5ReadHistorySuiteTest`; `TaskRoutingTest#test_r5_eligibility_is_limited_to_audited_suites`; `tmp/task-7b/ReadTestEndpoint.log` |
| `ResourceTest` | DSTU2, STU3, R4, R4B, R5 | compatible | R5 structure expansion, generated/parsing namespace ownership, and representative unchanged, changed, and R5-only endpoint cases audited. | `R5ResourceSuiteTest`; `tmp/task-7c` endpoint cases; `fhir_models` `67c146c4` |
| `RobustSearchTest` | STU3, R4, R4B, R5 | conditionally compatible | R5 setup and cleanup construct `FHIR::R5::Patient`; its only MPI `$match` case is explicitly skipped for Spark issue #310. | `R5SearchSuiteTest`; `tmp/task-7g/RobustSearchEndpointAfterCurrentRebuild.log` |
| `SearchTest` | DSTU2, STU3, R4, R4B, R5 | compatible | R5 CapabilityStatement parameter names and types are compared with R5 SearchParameter definitions; R5 generic `Resource` parameters and `_summary` are handled explicitly. | `R5SearchSuiteTest`; `tmp/task-7g/SearchEndpointAfterCurrentRebuild.log` |
| `SprinklerSearchTest` | DSTU2, STU3, R4, R4B, R5 | conditionally compatible | R5 parameter types, quantity boundaries, UCUM syntax, chaining, include, unknown and malformed parameters are audited. `_revinclude` remains the existing explicit Spark #307 skip. | `R5SprinklerSearchSuiteTest`; `tmp/task-7h/R5EndpointWithExpressionIncludes.log`; `tmp/task-7h/R4BEndpointWithExpressionIncludes.log` |
| `TransactionAndBatchTest` | DSTU2, STU3, R4, R4B, R5 | conditionally compatible | R5 transaction construction, conditional operations, temporary references, response parsing, and Bundle response types are audited. Five existing Spark issue skips remain for transaction ordering, fetch-and-update, and historical batch cases. | `R5TransactionSuiteTest`; `TaskRoutingTest#test_r5_task_clients_construct_and_audited_suites_are_eligible`; `tmp/task-7e/TransactionAndBatchEndpoint.log`; `tmp/task-7e/BatchEndpointProbe.log` |
| `UnknownSearchParameterTest` | STU3, R4, R4B | unaudited | R5 unknown-search-parameter behavior has not been audited. | Same inventory test |

`supported_versions` is the sole eligibility annotation. The same annotation
controls suite listing, metadata generation, and execution. A suite may add
`:r5` only in the atomic commit that changes its recorded status to
`compatible`, `conditionally compatible`, or `incompatible` and includes the
supporting audit evidence.

FHIR TestScript artifacts are excluded from this inventory. They use
`supported_versions == [:stu3]`, are loaded only for STU3 clients, and R5
TestScript task requests are rejected.
