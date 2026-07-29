module Crucible
  module Tests
    class SprinklerSearchTest < BaseSuite

      attr_accessor :use_post

      INDEXING_RETRY_COUNT = 10
      INDEXING_RETRY_DELAY = 0.2

      def id
        'Search001'
      end

      def description
        'Initial Sprinkler tests for testing search capabilities.'
      end

      def initialize(client1, client2=nil)
        super(client1, client2)
        @supported_versions = [:dstu2, :stu3, :r4, :r4b, :r5]
        @category = {id: 'core_functionality', title: 'Core Functionality'}
      end

      def setup
        # Create a patient with gender:missing
        @resources = Crucible::Generator::Resources.new(fhir_version)
        @patient = @resources.minimal_patient
        @patient_family = "Sprinkler#{SecureRandom.urlsafe_base64(12)}"
        @patient_given = "Search#{SecureRandom.urlsafe_base64(12)}"
        @patient.name[0].family = fhir_version == :dstu2 ? [@patient_family] : @patient_family
        @patient.name[0].given = [@patient_given]
        @patient.identifier = [get_resource(:Identifier).new]
        @patient_identifier = SecureRandom.urlsafe_base64
        @patient.identifier[0].value = @patient_identifier
        @patient.gender = nil
        result = @client.create(@patient)
        @patient_id = result.id
        @patient.id = @patient_id
        wait_for_index(get_resource(:Patient), @patient_id)

        # Create a condition matching the uniquely identified setup patient.
        @condition = ResourceGenerator.generate(get_resource(:Condition),3)
        if fhir_version == :dstu2
          @condition.patient = @patient.to_reference
        else
          @condition.subject = @patient.to_reference
        end

        reply = @client.create(@condition)
        @condition_id = reply.id
        wait_for_index(get_resource(:Condition), @condition_id)

        @observation_code = "sprinkler-#{SecureRandom.urlsafe_base64(12)}"

        # Create quantity observations with a unique code so their result sets are isolated.
        @obs_a = create_observation(2.0)
        @obs_b = create_observation(1.96)
        @obs_c = create_observation(2.04)
        @obs_d = create_observation(1.80)
        @obs_e = create_observation(5.12)
        @obs_f = create_observation(6.12)
      end

      def create_observation(value)
        observation = get_resource(:Observation).new
        observation.status = 'preliminary'
        code = get_resource(:Coding).new
        code.system = 'http://projectcrucible.org/sprinkler'
        code.code = @observation_code
        observation.code = get_resource(:CodeableConcept).new
        observation.code.coding = [ code ]
        observation.valueQuantity = get_resource(:Quantity).new
        observation.valueQuantity.system = 'http://unitsofmeasure.org'
        observation.valueQuantity.value = value
        observation.valueQuantity.unit = 'mmol'
        body = get_resource(:Coding).new
        body.system = 'http://snomed.info/sct'
        body.code = '182756003'
        observation.bodySite = get_resource(:CodeableConcept).new
        observation.bodySite.coding = [ body ]
        Crucible::Generator::Resources.new(fhir_version).tag_metadata(observation)
        reply = @client.create(observation)
        wait_for_index(get_resource(:Observation), reply.id)
        reply.id
      end

      def wait_for_index(resource_class, id)
        INDEXING_RETRY_COUNT.times do
          reply = @client.search(resource_class, search: { parameters: { '_id' => id } })
          return if reply.code == 200 && reply.resource&.entry&.any? { |entry| entry.resource&.id == id }

          sleep(INDEXING_RETRY_DELAY)
        end

        raise "Timed out waiting for #{resource_class.name.demodulize}/#{id} to be indexed."
      end

      def assert_exact_result_ids(reply, expected_ids)
        assert_response_ok(reply)
        assert_bundle_response(reply)

        actual_ids = reply.resource.entry.filter_map { |entry| entry.resource&.id }.sort
        assert_equal expected_ids.sort, actual_ids, 'The search returned an unexpected set of resource ids.'
        assert_equal expected_ids.length, reply.resource.total, 'The server did not report the expected number of results.'
      end

      def assert_condition_search_result(reply)
        assert_exact_result_ids(reply, [@condition_id])
      end

      def assert_exact_paginated_result_ids(reply, expected_ids)
        actual_ids = []
        total = nil

        while reply
          assert_response_ok(reply)
          assert_bundle_response(reply)
          total ||= reply.resource.total
          actual_ids.concat(reply.resource.entry.filter_map { |entry| entry.resource&.id })
          reply = @client.next_page(reply)
        end

        assert_equal expected_ids.sort, actual_ids.sort, 'The search returned an unexpected set of resource ids.'
        assert_equal expected_ids.length, total, 'The server did not report the expected number of results.'
      end

      def teardown
        @client.use_format_param = false
        @client.destroy(get_resource(:Patient), @patient_id) if @patient_id
        @client.destroy(get_resource(:Condition), @condition_id) if @condition_id
        @client.destroy(get_resource(:Observation), @obs_a) if @obs_a
        @client.destroy(get_resource(:Observation), @obs_b) if @obs_b
        @client.destroy(get_resource(:Observation), @obs_c) if @obs_c
        @client.destroy(get_resource(:Observation), @obs_d) if @obs_d
        @client.destroy(get_resource(:Observation), @obs_e) if @obs_e
        @client.destroy(get_resource(:Observation), @obs_f) if @obs_f
      end
 
    [true,false].each do |flag|  
      action = 'GET'
      action = 'POST' if flag

      test "SE01#{action[0]}",'Search patients without criteria (except _count)' do
        metadata {
          links "#{REST_SPEC_LINK}#search"
          links "#{BASE_SPEC_LINK}/search.html"
          validates resource: "Patient", methods: ["search"]
        }
        options = {
          :search => {
            :flag => flag,
            :compartment => nil,
            :parameters => {
              '_count' => '1'
            }
          }
        }
        reply = @client.search(get_resource(:Patient), options)
        assert_response_ok(reply)
        assert_bundle_response(reply)
        assert_equal 1, reply.resource.entry.size, 'The server did not return the correct number of results.'
      end

      test "SE02#{action[0]}", 'Search on non-existing resource' do
        metadata {
          links "#{REST_SPEC_LINK}#search"
          links "#{BASE_SPEC_LINK}/search.html"
        }
        options = {
          :resource => Crucible::Tests::SprinklerSearchTest,
          :search => {
            :flag => flag,
            :compartment => nil,
            :parameters => nil
          }
        }
        reply = @client.search_all(options)
        assert( (reply.code >= 400 && reply.code < 600), 'If the search fails, the return value should be status code 4xx or 5xx.', reply)
      end

      test "SE03#{action[0]}",'Search patient resource on partial family surname' do
        metadata {
          links "#{REST_SPEC_LINK}#search"
          links "#{BASE_SPEC_LINK}/search.html"
          links "#{BASE_SPEC_LINK}/patient.html#search"
          validates resource: "Patient", methods: ["search"]
        }

        search_string = @patient_family[0..2]

        options = {
          :search => {
            :flag => flag,
            :compartment => nil,
            :parameters => {
              'family' => search_string
            }
          }
        }
        reply = @client.search(get_resource(:Patient), options)
        assert_exact_result_ids(reply, [@patient_id])
      end

      test "SE04#{action[0]}", 'Search patient resource on given name' do
        metadata {
          links "#{REST_SPEC_LINK}#search"
          links "#{BASE_SPEC_LINK}/search.html"
          links "#{BASE_SPEC_LINK}/patient.html#search"
          validates resource: "Patient", methods: ["search"]
        }

        search_string = @patient_given

        options = {
          :search => {
            :flag => flag,
            :compartment => nil,
            :parameters => {
              'given' => search_string
            }
          }
        }
        reply = @client.search(get_resource(:Patient), options)
        assert_exact_result_ids(reply, [@patient_id])
      end

      test "SE05.0#{action[0]}", 'Search condition by patient reference url (partial)' do
        metadata {
          links "#{REST_SPEC_LINK}#search"
          links "#{BASE_SPEC_LINK}/search.html"
          links "#{BASE_SPEC_LINK}/condition.html#search"
          validates resource: "Condition", methods: ["search"]
        }

        options = {
          :search => {
            :flag => flag,
            :compartment => nil,
            :parameters => {
              'patient' => @patient.to_reference.reference
            }
          }
        }
        reply = @client.search(get_resource(:Condition), options)
        assert_condition_search_result(reply)
      end

      test "SE05.0F#{action[0]}", 'Search condition by patient reference url (full)' do
        metadata {
          links "#{REST_SPEC_LINK}#search"
          links "#{BASE_SPEC_LINK}/search.html"
          links "#{BASE_SPEC_LINK}/condition.html#search"
          validates resource: "Condition", methods: ["search"]
        }

        options = {
          :id => @patient.id,
          :resource => @patient.class
        }
        temp = @client.use_format_param
        @client.use_format_param = false
        patient_url = @client.full_resource_url(options)
        @client.use_format_param = temp

        options = {
          :search => {
            :flag => flag,
            :compartment => nil,
            :parameters => {
              'patient' => patient_url
            }
          }
        }
        reply = @client.search(get_resource(:Condition), options)
        assert_condition_search_result(reply)
      end

      test "SE05.1#{action[0]}", 'Search condition by patient reference id' do
        metadata {
          links "#{REST_SPEC_LINK}#search"
          links "#{BASE_SPEC_LINK}/search.html"
          links "#{BASE_SPEC_LINK}/condition.html#search"
          validates resource: "Condition", methods: ["search"]
        }

        patient_id = @patient.id

        options = {
          :search => {
            :flag => flag,
            :compartment => nil,
            :parameters => {
              'patient' => patient_id
            }
          }
        }
        reply = @client.search(get_resource(:Condition), options)
        assert_condition_search_result(reply)
      end

      test "SE05.2#{action[0]}", 'Search condition by patient:Patient reference url' do
        metadata {
          links "#{REST_SPEC_LINK}#search"
          links "#{BASE_SPEC_LINK}/search.html"
          links "#{BASE_SPEC_LINK}/condition.html#search"
          validates resource: "Condition", methods: ["search"]
        }

        options = {
          :id => @patient.id,
          :resource => @patient.class
        }
        temp = @client.use_format_param
        @client.use_format_param = false
        patient_url = @client.resource_url(options)
        patient_url = patient_url[1..-1] if patient_url[0]=='/'
        @client.use_format_param = temp
       
        options = {
          :search => {
            :flag => flag,
            :compartment => nil,
            :parameters => {
              'patient:Patient' => patient_url
            }
          }
        }
        reply = @client.search(get_resource(:Condition), options)
        assert_condition_search_result(reply)
      end

      test "SE05.3#{action[0]}", 'Search condition by patient:Patient reference id' do
        metadata {
          links "#{REST_SPEC_LINK}#search"
          links "#{BASE_SPEC_LINK}/search.html"
          links "#{BASE_SPEC_LINK}/condition.html#search"
          validates resource: "Condition", methods: ["search"]
        }
        
        patient_id = @patient.id

        options = {
          :search => {
            :flag => flag,
            :compartment => nil,
            :parameters => {
              'patient:Patient' => patient_id
            }
          }
        }
        reply = @client.search(get_resource(:Condition), options)
        assert_condition_search_result(reply)
      end

      test "SE05.4#{action[0]}", 'Search condition by patient:_id reference' do
        metadata {
          links "#{REST_SPEC_LINK}#search"
          links "#{BASE_SPEC_LINK}/search.html"
          links "#{BASE_SPEC_LINK}/condition.html#search"
          validates resource: "Condition", methods: ["search"]
        }
        patient_id = @patient.id

        options = {
          :search => {
            :flag => flag,
            :compartment => nil,
            :parameters => {
              'patient._id' => patient_id
            }
          }
        }
        reply = @client.search(get_resource(:Condition), options)
        assert_condition_search_result(reply)
      end

      test "SE05.5#{action[0]}", 'Search condition by patient.name reference' do
        metadata {
          links "#{REST_SPEC_LINK}#search"
          links "#{BASE_SPEC_LINK}/search.html"
          links "#{BASE_SPEC_LINK}/condition.html#search"
          validates resource: "Condition", methods: ["search"]
        }
        patient_name = @patient_family

        options = {
          :search => {
            :flag => flag,
            :compartment => nil,
            :parameters => {
              'patient.name' => patient_name
            }
          }
        }
        reply = @client.search(get_resource(:Condition), options)
        assert_condition_search_result(reply)
      end

      test "SE05.6#{action[0]}", 'Search condition by patient.identifier reference' do
        metadata {
          links "#{REST_SPEC_LINK}#search"
          links "#{BASE_SPEC_LINK}/search.html"
          links "#{BASE_SPEC_LINK}/condition.html#search"
          validates resource: "Condition", methods: ["search"]
        }
        assert @patient_id, 'Could not create a patient in setup.'
        patient_identifier = @patient_identifier

        options = {
          :search => {
            :flag => flag,
            :compartment => nil,
            :parameters => {
              'patient.identifier' => patient_identifier
            }
          }
        }
        reply = @client.search(get_resource(:Condition), options)
        assert_condition_search_result(reply)
      end

      test "SE06#{action[0]}", 'Search condition and _include' do
        metadata {
          links "#{REST_SPEC_LINK}#search"
          links "#{BASE_SPEC_LINK}/search.html"
          links "#{BASE_SPEC_LINK}/condition.html#search"
          validates resource: "Condition", methods: ["search"]
        }
        assert @condition_id, 'Could not create Condition in setup.'

        options = {
          :search => {
            :flag => flag,
            :compartment => nil,
            :parameters => {
              '_include' => 'Condition:patient',
              '_id' => @condition_id
            }
          }
        }
        reply = @client.search(get_resource(:Condition), options)
        assert_response_ok(reply)
        assert_bundle_response(reply)
        assert_equal 1, reply.resource.total, 'The server did not report the expected number of primary results.'
        assert_equal [@condition_id, @patient_id].sort,
                     reply.resource.entry.filter_map { |entry| entry.resource&.id }.sort,
                     'The server did not return the expected primary and included resources.'
      end

      test "SE07#{action[0]}", 'Search patient and _revinclude' do
        metadata {
          links "#{REST_SPEC_LINK}#search"
          links "#{BASE_SPEC_LINK}/search.html"
          links "#{BASE_SPEC_LINK}/patient.html#search"
          validates resource: "Patient", methods: ["search"]
        }

        skip 'TODO: https://github.com/FirelyTeam/spark/issues/307'
        
        assert @patient_id, 'Could not create a patient in setup.'

        # next, we're going execute a series of searches for conditions referencing the patient
        options = {
          :search => {
            :flag => flag,
            :compartment => nil,
            :parameters => {
              '_revinclude' => 'Condition:patient',
              '_id' => @patient_id
            }
          }
        }
        reply = @client.search(get_resource(:Patient), options)
        assert_response_ok(reply)
        assert_bundle_response(reply)
        assert reply.resource.total > 0, 'The server should have Patients that are _revinclude=Condition:patient.'
        has_condition = false
        reply.resource.entry.each do |entry|
          has_condition = true if (entry.resource && entry.resource.class == get_resource(:Condition))
        end
        assert(has_condition,'The server did not include the Condition referencing the Patient.', reply.body)
      end

      test "SE21#{action[0]}", 'Search for quantity (in observation) - precision tests' do
        metadata {
          links "#{REST_SPEC_LINK}#search"
          links "#{BASE_SPEC_LINK}/search.html#quantity"
          links "#{BASE_SPEC_LINK}/observation.html#search"
          validates resource: "Observation", methods: ["search"]
        }

        assert (@obs_a && @obs_b && @obs_c && @obs_d), 'Could not create Observations in setup.'

        options = {
          :search => {
            :flag => flag,
            :compartment => nil,
            :parameters => {
              'code' => "http://projectcrucible.org/sprinkler|#{@observation_code}",
              'value-quantity' => '2.0|http://unitsofmeasure.org|mmol'
            }
          }
        }
        reply = @client.search(get_resource(:Observation), options)
        assert_exact_paginated_result_ids(reply, [@obs_a, @obs_b, @obs_c])
      end

      test "SE22#{action[0]}", 'Search for quantity (in observation) - operators' do
        metadata {
          links "#{REST_SPEC_LINK}#search"
          links "#{BASE_SPEC_LINK}/search.html#quantity"
          links "#{BASE_SPEC_LINK}/observation.html#search"
          validates resource: "Observation", methods: ["search"]
        }

        assert (@obs_a && @obs_e && @obs_f), 'Could not create Observations in setup.'

        options = {
          :search => {
            :flag => flag,
            :compartment => nil,
            :parameters => {
              'code' => "http://projectcrucible.org/sprinkler|#{@observation_code}",
              'value-quantity' => 'gt5|http://unitsofmeasure.org|mmol'
            }
          }
        }
        reply = @client.search(get_resource(:Observation), options)
        assert_exact_paginated_result_ids(reply, [@obs_e, @obs_f])
      end

      test "SE23#{action[0]}", 'Search with quantifier :missing, on Patient.gender' do
        metadata {
          links "#{REST_SPEC_LINK}#search"
          links "#{BASE_SPEC_LINK}/search.html"
          links "#{BASE_SPEC_LINK}/patient.html#search"
          validates resource: "Patient", methods: ["search"]
        }

        options = {
          :search => {
            :flag => flag,
            :compartment => nil,
            :parameters => {
              'gender:missing' => true,
              'identifier' => @patient_identifier
            }
          }
        }
        reply = @client.search(get_resource(:Patient), options)
        assert_exact_result_ids(reply, [@patient_id])
      end

      test "SE24#{action[0]}", 'Search with non-existing parameter' do
        metadata {
          links "#{REST_SPEC_LINK}#search"
          links "#{BASE_SPEC_LINK}/search.html"
          links "#{BASE_SPEC_LINK}/patient.html#search"
          validates resource: "Patient", methods: ["search"]
        }
        # non-existing parameters should be ignored
        options = {
          :search => {
            :flag => flag,
            :compartment => nil,
            :parameters => {
              'bonkers' => 'foobar'
            }
          }
        }
        reply = @client.search(get_resource(:Patient), options)
        assert_response_ok(reply)
        assert_bundle_response(reply)
      end

      test "SE25#{action[0]}", 'Search with malformed parameters' do
        metadata {
          links "#{REST_SPEC_LINK}#search"
          links "#{BASE_SPEC_LINK}/search.html"
          links "#{BASE_SPEC_LINK}/patient.html#search"
          validates resource: "Patient", methods: ["search"]
        }

        # a malformed parameters are non-existing parameters, and they should be ignored
        options = {
          :search => {
            :flag => flag,
            :compartment => nil,
            :parameters => {
              '...' => 'foobar'
            }
          }
        }
        reply = @client.search(get_resource(:Patient), options)
        assert_response_ok(reply)
        assert_bundle_response(reply)
      end

    end # EOF [true,false].each

    end
  end
end
