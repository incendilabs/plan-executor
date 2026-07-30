module Crucible
  module Tests
    class ConsentSearchByPatientReferenceTest < BaseSuite

      def id
        'ConsentSearchByPatientReferenceTest'
      end

      def description
        'Consent search by patient reference appears broken #329'
      end

      def initialize(client1, client2 = nil)
        super(client1, client2)
        @tags.append('indendilabs')
        @category = { id: 'indendilabs', title: 'Indendilabs' }
        @supported_versions = [:stu3, :r4, :r4b, :r5]
      end

      def setup

        @patient = ResourceGenerator.minimal_patient(nil, nil, namespace: version_namespace)
        reply = @client.create(@patient)
        assert_response_ok(reply)
        @patient_id = reply.id

        @consent = ResourceGenerator.generate(version_namespace.const_get(:Consent))
        if fhir_version == :r5
          @consent.subject = @patient.to_reference
        else
          @consent.patient = @patient.to_reference
        end
        reply = @client.create(@consent)
        assert_response_ok(reply)
        @consent_id = reply.id

        # Sleep to allow the server to index the new Consent before we attempt to search for it.
        # This only applies if the server uses an asynchronous indexing process.
        sleep(0.2)

      end

      def teardown
        @client.destroy(version_namespace.const_get(:Patient), @patient_id) unless @patient_id.nil?
        @client.destroy(version_namespace.const_get(:Consent), @consent_id) unless @consent_id.nil?
      end

      test 'I329', 'Consent search by patient reference appears broken #329' do
        metadata {
          links "#{BASE_SPEC_LINK}/consent.html"
          links "#{REST_SPEC_LINK}#search"
          validates resource: 'Consent', methods: ['search']
        }
        options = {
          :search => {
            :compartment => nil,
            :parameters => {
              'patient' => "Patient/#{@patient_id}"
            }
          }
        }
        reply = @client.search(version_namespace.const_get(:Consent), options)
        assert_response_ok(reply)
        assert_bundle_response(reply)
        consent_entries = reply.resource.entry.select do |entry|
          entry.resource.is_a?(version_namespace.const_get(:Consent))
        end
        assert_equal [@consent_id], consent_entries.map { |entry| entry.resource.id }, 'The search did not return the created Consent.'
      end

    end
  end
end
