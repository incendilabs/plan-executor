# Plan Executor [![Build Status](https://travis-ci.org/fhir-crucible/plan_executor.svg?branch=master)](https://travis-ci.org/fhir-crucible/plan_executor)

Plan Executor runs test suites against a FHIR server. The harness recognizes
`DSTU2`, `STU3`, `R4`, `R4B`, and `R5` versions of FHIR. Each suite declares its
supported versions explicitly; recognizing a version does not make every suite
compatible with it.
Commands that execute suites require this version argument; omission is an
error and does not select R4 implicitly.
Tests can either be written in [Ruby](https://github.com/fhir-crucible/plan_executor#adding-a-new-test-suite),
or using the [TestScript Resource](https://github.com/fhir-crucible/plan_executor/wiki/Using-Plan-Executor-with-TestScripts#testscript).
TestScript execution remains STU3-only.

## Getting Started

```
$ bundle install
$ bundle exec rake -T
```

## Listing Test Suites

List all available Test Suites, excluding supported `TestScripts`. Pass the
version, which can be `dstu2`, `stu3`, `r4`, `r4b`, or `r5`. Only suites
explicitly annotated for the selected version are listed.

```
$ bundle exec rake "crucible:list_suites[dstu2]"
$ bundle exec rake "crucible:list_suites[r4b]"
$ bundle exec rake "crucible:list_suites[r5]"
```

## Executing a Test Suite

Crucible tests can be executed by suite from the command line by calling the
`crucible:execute` Rake task with the following parameters:

* `url` the FHIR endpoint
* `fhir_version` the explicit FHIR version: `dstu2`, `stu3`, `r4`, `r4b`, or
  `r5`
* `test` the name of the test suite (see `crucible:list_suites`)
* `resource` (optional) limit `ResourceTest` or `SearchTest` to a resource such
  as `Patient`
* `output` (optional) a pipe-separated selection of `html`, `json`, and
  `stdout`

Run an R4 Suite limited by Resource
```
$ bundle exec rake "crucible:execute[http://hapi.fhir.org/r4,r4,ResourceTest,Patient]"
```

Run a STU3 Suite limited by Resource
```
$ bundle exec rake "crucible:execute[http://hapi.fhir.org/baseDstu3,stu3,ResourceTest,Patient]"
```

Run a DSTU2 Suite
```
$ bundle exec rake "crucible:execute[http://hapi.fhir.org/baseDstu2,dstu2,TransactionAndBatchTest]"
```

## R5 Harness Support

R5 is an explicit harness version, not an alias for R4 or R4B. Registering it
does not enable any test suite automatically. A suite is eligible for R5 only
when its `supported_versions` includes `:r5`; listing, execution, and metadata
generation all use that annotation. Use the listing task to discover the
currently eligible suites:

```
$ bundle exec rake "crucible:list_suites[r5]"
$ bundle exec rake "crucible:list_all[r5]"
```

Supply `r5` explicitly when executing an eligible suite or generating its
metadata. Replace `EligibleSuite` with a suite returned by the listing task:

```
$ bundle exec rake "crucible:execute[https://server.example/fhir,r5,EligibleSuite]"
$ bundle exec rake "crucible:execute_all[https://server.example/fhir,r5,html|json|stdout]"
$ bundle exec rake "crucible:metadata[EligibleSuite,r5]"
```

FHIR TestScript tasks remain STU3-only. Passing `r5` to
`crucible:execute_all_testscripts` or `crucible:testreport` is rejected rather
than being routed through another FHIR version.

The R5 specification navigation index is checked in at
`lib/FHIR_structure_r5.json`. It is generated from the official
`https://hl7.org/fhir/R5/definitions.json.zip` archive, pinned to SHA-256
`df0d7259b4a8741d59f4971d96dd486423ecbd414c7060e9dc006ae3c3209c0c`.
The generator verifies the checksum and reads the exact archive entry
`profiles-resources.json`.

Regenerate the checked-in index from a repository-local download:

```
$ mkdir -p tmp/r5-structure
$ curl --fail --location --output tmp/r5-structure/r5-definitions.json.zip https://hl7.org/fhir/R5/definitions.json.zip
$ bundle exec rake "crucible:generate_r5_structure[tmp/r5-structure/r5-definitions.json.zip]"
$ git diff --exit-code -- lib/FHIR_structure_r5.json
```

The downloaded archive is a source input and is not committed.

## Logging Output

The shell scripts output directly to stdout/stderr. To save logs to a file while also displaying output, use `tee`:

```
$ ./execute_all.sh http://localhost:8080/fhir r4 'html|json|stdout' 2>&1 | tee logs/execute_all.log
```

To redirect output to a file only (silent):

```
$ ./execute_all.sh http://localhost:8080/fhir r4 'html|json|stdout' > logs/execute_all.log 2>&1
```

## Adding a New Test Suite

1. Fork the repo
2. Write the test suite in Ruby
3. Issue a pull request

Add a Test Suite by adding a Ruby file to `lib/tests/suites` that extends `Crucible::Tests::BaseTest` -- for example, `FooTest`:

```ruby
module Crucible
  module Tests
    class FooTest < BaseSuite

      def id
        'FooTest'
      end

      def description
        'FooTest is an example of adding a new test suite.'
      end

      def initialize(client1, client2=nil)
        super(client1, client2)
        @supported_versions = [:r4]
        @category = {id: 'connectathon', title: 'Connectathon'}
      end

      def setup
        # create any fixtures you need here
        @patient = ResourceGenerator.generate(get_resource(:Patient),3)
        reply = @client.create(@patient)
        @id = reply.id
        @body = reply.body
      end

      def teardown
        # perform any clean up here
        @client.destroy(get_resource(:Patient), @id)
      end

      # test 'KEY', 'DESCRIPTION'
      test 'FOO', 'Foo Test checks headers' do
        metadata {
          links "#{REST_SPEC_LINK}#read"
          requires resource: "Patient", methods: ["create", "read"]
          validates resource: "Patient", methods: ["read"]
        }

        assert(@id, 'Setup was unable to create a patient.',@body)
        reply = @client.read(get_resource(:Patient), @id)
        assert_response_ok(reply)
        assert_equal @id, reply.id, 'Server returned wrong patient.'
        warning { assert_valid_resource_content_type_present(reply) }
        warning { assert_etag_present(reply) }
        warning { assert_last_modified_present(reply) }
      end
    end
  end
end
```

Every Test Suite needs to override the following methods:
* `id` The unique id of the test, typically matches the class name
* `description` The description that is displayed within the Crucible web app
* `initialize` Use the example above. Change the `@category` -- the `id` and `title`
determine where the test suite is categorized within the Crucible web app
and set `@supported_versions` explicitly. A suite is not eligible for any FHIR
version until that annotation is present.
* `setup` (optional) Use this method to create fixtures and perform any required
assertions prior to execution of individual `test` blocks.
* `test` These blocks are the individual tests within the suites. Each block should start with a `metadata` section so Crucible knows how to tie the success or failures to portions of the FHIR specification (displayed in the web app with a starburst). See `lib/FHIR_structure.json` for the values associated with the `name` keys that you can link to.
* `teardown` (optional) Use this method to perform any clean up, so you don't leave
a trail of test data behind.

# License

Copyright 2014-2020 The MITRE Corporation

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
