# FHIR R5 Suite Compatibility Inventory

Status date: 2026-07-29

This is the complete initial R5 audit inventory. It is derived from the 12
suite classes that currently declare `:r4b` in `supported_versions`.
R4B compatibility is not evidence of R5 compatibility, so every entry starts
as `unaudited` and no suite declares `:r5`.

| Suite | Current versions | R5 status | Reason | Evidence |
| --- | --- | --- | --- | --- |
| `ConsentSearchByPatientReferenceTest` | STU3, R4, R4B | unaudited | R5 search-reference behavior has not been audited. | `SupportedVersionsTest#test_r5_compatibility_inventory_matches_the_complete_r4b_suite_set` |
| `ElementsSearchParameterTest` | STU3, R4, R4B | unaudited | R5 `_elements` semantics have not been audited. | Same inventory test |
| `FhirPathPatchTest` | STU3, R4, R4B | unaudited | R5 FHIRPath Patch semantics have not been audited. | Same inventory test |
| `FormatTest` | DSTU2, STU3, R4, R4B | unaudited | R5 media-type and serialization behavior has not been audited. | Same inventory test |
| `HistoryTest` | DSTU2, STU3, R4, R4B | unaudited | R5 history interaction semantics have not been audited. | Same inventory test |
| `ReadTest` | DSTU2, STU3, R4, R4B | unaudited | R5 read and conditional-read semantics have not been audited. | Same inventory test |
| `ResourceTest` | DSTU2, STU3, R4, R4B | unaudited | R5 resource coverage and interaction behavior have not been audited. | Same inventory test |
| `RobustSearchTest` | STU3, R4, R4B | unaudited | R5 robust-search expectations have not been audited. | Same inventory test |
| `SearchTest` | DSTU2, STU3, R4, R4B | unaudited | R5 search semantics have not been audited. | Same inventory test |
| `SprinklerSearchTest` | DSTU2, STU3, R4, R4B | unaudited | R5 sprinkler-search behavior has not been audited. | Same inventory test |
| `TransactionAndBatchTest` | DSTU2, STU3, R4, R4B | unaudited | R5 transaction and batch rules have not been audited. | Same inventory test |
| `UnknownSearchParameterTest` | STU3, R4, R4B | unaudited | R5 unknown-search-parameter behavior has not been audited. | Same inventory test |

`supported_versions` is the sole eligibility annotation. The same annotation
controls suite listing, metadata generation, and execution. A suite may add
`:r5` only in the atomic commit that changes its recorded status to
`compatible`, `conditionally compatible`, or `incompatible` and includes the
supporting audit evidence.

FHIR TestScript artifacts are excluded from this inventory. They use
`supported_versions == [:stu3]`, are loaded only for STU3 clients, and R5
TestScript task requests are rejected.
