module Crucible
  module Tests
    class ElementsSearchParameterTest < BaseSuite

      def id
        'ElementsSearchParameterTest'
      end

      def description
        'Searching with _elements should return resources containing only the requested elements'
      end

      def initialize(client1, client2 = nil)
        super(client1, client2)
        @tags.append('incendilabs')
        @category = { id: 'incendilabs', title: 'Incendilabs' }
        @supported_versions = [:stu3, :r4, :r4b]
      end

      def setup
        @patient = ResourceGenerator.minimal_patient('elements-search-parameter', 'Elements', namespace: version_namespace)
        @patient.gender = 'male'
        @patient.birthDate = '1974-12-25'

        reply = @client.create(@patient)
        assert_response_ok(reply)
        @patient_id = reply.id

        # Sleep to allow the server to index the new Patient before we attempt to search for it.
        # This only applies if the server uses an asynchronous indexing process.
        sleep(0.2)
      end

      def teardown
        @client.destroy(version_namespace.const_get(:Patient), @patient_id) unless @patient_id.nil?
      end

      def elements_search_options
        {
          search: {
            compartment: nil,
            parameters: {
              '_id' => @patient_id,
              '_elements' => 'name,birthDate'
            }
          }
        }
      end

      test 'I_ELEMENTS_001', 'Search with _elements returns only requested Patient elements' do
        metadata {
          links "#{BASE_SPEC_LINK}/search.html#elements"
          links "#{REST_SPEC_LINK}#search"
          validates resource: 'Patient', methods: ['search']
        }

        reply = @client.search(version_namespace.const_get(:Patient), elements_search_options)

        assert_response_ok(reply)
        assert_bundle_response(reply)

        entries = reply.resource.entry || []

        outcome_entries = entries.select do |e|
          e.resource.is_a?(version_namespace.const_get(:OperationOutcome)) &&
            e.search&.mode == 'outcome'
        end

        assert(
          outcome_entries.empty?,
          'Expected _elements to be handled as a general search result parameter, but the searchset Bundle contained an OperationOutcome entry with search.mode=outcome',
          reply.body
        )

        patient_entries = entries.select do |e|
          e.resource.is_a?(version_namespace.const_get(:Patient))
        end

        assert_equal 1, patient_entries.size, 'Expected search by _id and _elements to return exactly one Patient entry.', reply.body

        patient = patient_entries.first.resource
        assert_equal @patient_id, patient.id, 'Expected the Patient id to be retained even when _elements omits id.', reply.body
        assert(patient.name && patient.name.any?, 'Expected Patient.name to be retained when _elements includes name.', reply.body)
        assert(patient.gender.nil?, 'Expected Patient.gender to be omitted when _elements only includes name,birthDate.', reply.body)
        assert_equal '1974-12-25', patient.birthDate, 'Expected Patient.birthDate to be retained when _elements includes birthDate.', reply.body
      end

      test 'I_ELEMENTS_002', 'Read with _elements returns only requested Patient elements' do
        skip 'TODO: https://github.com/FirelyTeam/spark/issues/1336'

        metadata {
          links "#{BASE_SPEC_LINK}/http.html#read"
          links "#{BASE_SPEC_LINK}/search.html#elements"
          validates resource: 'Patient', methods: ['read']
        }

        reply = @client.get(URI::encode("Patient/#{@patient_id}?_elements=name,birthDate"), @client.fhir_headers)
        reply.resource = @client.parse_reply(version_namespace.const_get(:Patient), @client.default_format, reply)

        assert_response_ok(reply)
        assert_resource_type(:Patient, reply.resource)

        patient = reply.resource
        assert_equal @patient_id, patient.id, 'Expected the Patient id to be retained even when _elements omits id.', reply.body
        assert(patient.name && patient.name.any?, 'Expected Patient.name to be retained when _elements includes name.', reply.body)
        assert(patient.gender.nil?, 'Expected Patient.gender to be omitted when _elements only includes name,birthDate.', reply.body)
        assert_equal '1974-12-25', patient.birthDate, 'Expected Patient.birthDate to be retained when _elements includes birthDate.', reply.body
      end

    end
  end
end
