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
        @supported_versions = [:stu3, :r4]
      end

      def setup

        @patient = ResourceGenerator.minimal_patient(nil, nil, version_namespace)
        reply = @client.create(@patient)
        assert_response_ok(reply)
        @patient_id = reply.id

        @consent = ResourceGenerator.generate(version_namespace.const_get(:Consent))
        @consent.patient = @patient.to_reference
        reply = @client.create(@consent)
        assert_response_ok(reply)
        @consent_id = reply.id

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
        assert(1 == reply.resource.entry.size, "Consent not returned by search")
      end

    end
  end
end
