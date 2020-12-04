module Crucible
  module Tests
    class ArgonautSprint1Test < BaseSuite
      attr_accessor :rc
      attr_accessor :conformance
      attr_accessor :searchParams
      attr_reader   :canSearchById
      attr_accessor :patient_id

      def id
        'ArgonautSprint1Test'
      end

      def description
        'Argonaut Sprint 1 tests for testing Argonauts Sprint 1 goals: read patient by ID, search for patients by various demographics.'
      end

      def details
        {
          'Overview' => 'Argonaut Sprint 1 tests for testing Argonauts Sprint 1 goals: read patient by ID, search for patients by various demographics.',
          'Instructions' => 'Servers should provide the following information for the sprint: Organization name and contact, FHIR endpoint URL, List of FHIR Patient IDs (that is, Patient.id, not Patient.identifier), Authorization token(s), which are simple fixed values for now (Note: some servers, including Argonaut\'s reference server, may need to issue different tokens to different clients for policy reasons)',
          'FHIR API Calls' => 'We\'ll focus on the basics, beginning with two FHIR API calls that every participating server should expose, and every participating client should invoke: GET /Patient/{id} Retrieve a patient\'s basic demographics and identifiers, given a unique patient id. Think of this as the "Hello world" of FHIR. And cross-patient demographics search, using a single FHIR API call: GET /Patient?[parameters] Find patients based on a variety of demographic criteria. The following search parameters must be supported at a minimum: (name, family, given, identifier, gender, birthdate)',
          'Authorization' => 'The first Argonaut sprint will focus on getting data services up and running even before a complete authorization flow is implemented. This way we can ensure that all participating servers have correctly exposed FHIR API endpoints before we lock those endpoints down with a full OAuth approval process. So for this first sprint, each server will publish its FHIR endpoint URL along with an access token that clients can include in an HTTP Authorization header with each API call',
        }
      end

      def initialize(client1, client2=nil)
        super(client1, client2)
        @tags.append('argonautp1')
        @category = {id: 'argonautp1', title: 'Argonaut Phase 1'}
        @supported_versions = [:notsupported] # test requires patient id to be specified via patient query param
      end

      def setup
        @searchParams = [:name, :family, :given, :identifier, :gender, :birthdate]
        @rc = FHIR::DSTU2::Patient

        if !@client.client.try(:params).nil? && @client.client.params["patient"]
          @patient_id = @client.client.params["patient"]
        end
      end

      def get_patient_by_param(params = {}, flag = true)
        assert !params.empty?, "No params for patient"
        options = {
          :search => {
            :flag => flag,
            :compartment => nil,
            :parameters => params
          }
        }
        reply = @client.search(@rc, options)
        assert_response_ok(reply)
        assert_bundle_response(reply)
        assert reply.resource.get_by_id(@patient_id).equals?(@patient, ['_id', "text", "meta", "lastUpdated"]), 'Server returned wrong patient.'
      end

      def define_metadata(method)
        links "#{REST_SPEC_LINK}##{method}"
        links "#{BASE_SPEC_LINK}/#{@rc.name.demodulize.downcase}.html"
        validates resource: @rc.name.demodulize, methods: [method]
      end

      # [SprinklerTest("R001", "Result headers on normal read")]
      test 'AS001', 'Get patient by ID' do
        metadata {
          links "#{REST_SPEC_LINK}#read"
          requires resource: "Patient", methods: ["read", "search"]
          validates resource: "Patient", methods: ["read", "search"]
        }

        begin
          options = {
            :search => {
              :flag => true,
              :compartment => nil,
              :parameters => {
                _count: 1
              }
            }
          }
          @patient_id ||= @client.search(@rc, options).resource.entry.first.resource.xmlId
        rescue NoMethodError
          @patient = nil
        end

        skip if !@patient_id

        reply = @client.read(FHIR::DSTU2::Patient, @patient_id)
        assert_response_ok(reply)
        assert_equal @patient_id, reply.id, 'Server returned wrong patient.'
        @patient = reply.resource
        assert @patient, "could not get patient by id: #{@patient_id}"
        warning { assert_valid_resource_content_type_present(reply) }
        warning { assert_last_modified_present(reply) }
      end

      test 'AS002', 'Search by identifier' do
        metadata {
          define_metadata('search')
        }
        skip if !@patient
        get_patient_by_param(:identifier => @patient[:identifier].first.try(:value))
      end

      test 'AS003', 'Identifier without search keyword' do
        metadata {
          define_metadata('search')
        }
        skip if !@patient
        get_patient_by_param({ :identifier => @patient[:identifier].first.try(:value) }, false)
      end

      test 'AS004', 'Search by Family & Given' do
        metadata {
          define_metadata('search')
        }
        skip if !@patient
        family = @patient[:name].first.try(:family).try(:first)
        given = @patient[:name].first.try(:given).try(:first)
        assert family, "Patient family name not returned"
        assert given, "Patient given name not returned"
        get_patient_by_param(family: family, given: given)
      end

      test 'AS005', 'Family & Given without search keyword' do
        metadata {
          define_metadata('search')
        }
        skip if !@patient
        family = @patient[:name].first.try(:family).try(:first)
        given = @patient[:name].first.try(:given).try(:first)
        assert family, "Patient family name not provided"
        assert given, "Patient given name not provided"
        get_patient_by_param({ family: family, given: given }, false)
      end

      test 'AS006', 'Search by name and gender' do
        metadata {
          define_metadata('search')
        }
        skip if !@patient
        name = @patient[:name].first.try(:family).try(:first)
        gender = @patient[:gender]
        assert name, "Patient name not provided"
        assert gender, "Patient gender not provided"
        get_patient_by_param(name: name, gender: gender)
      end

      test 'AS007', 'Name and gender without search keyword' do
        metadata {
          define_metadata('search')
        }
        skip if !@patient
        name = @patient[:name].first.try(:family).try(:first)
        gender = @patient[:gender]
        assert name, "Patient name not provided"
        assert gender, "Patient gender not provided"
        get_patient_by_param(name: name, gender: gender)
      end

      test 'AS008', 'Search by Birthdate' do
        metadata {
          define_metadata('search')
        }
        skip if !@patient
        birthdate = @patient[:birthDate]
        gender = @patient[:gender]
        assert birthdate, "Patient birthdate not provided"
        assert gender, "Patient gender not provided"
        get_patient_by_param(birthdate: birthdate, gender: gender)
      end

      test 'AS009', 'Birthdate without search keyword' do
        metadata {
          define_metadata('search')
        }
        skip if !@patient
        birthdate = @patient[:birthDate]
        gender = @patient[:gender]
        assert birthdate, "Patient birthdate not provided"
        assert gender, "Patient gender not provided"
        get_patient_by_param({ birthdate: birthdate, gender: gender }, false)
      end

    end
  end
end
