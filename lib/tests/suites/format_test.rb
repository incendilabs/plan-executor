module Crucible
  module Tests
    class FormatTest < BaseSuite

        @@xml_format_params = ['xml', 'text/xml', 'application/xml', 'XML_FORMAT']
        @@json_format_params = ['json', 'application/json', 'JSON_FORMAT']
        @@alpha = ['A', 'B', 'C', 'D']

      def id
        'Format001'
      end

      def description
        'Initial Sprinkler tests (CT01, CT02, CT03, CT04) for testing resource format requests.'
      end

      def initialize(client1, client2=nil)
        super(client1, client2)
        if fhir_version == :dstu2
          @xml_format = FHIR::Formats::ResourceFormat::RESOURCE_XML_DSTU2
          @json_format = FHIR::Formats::ResourceFormat::RESOURCE_JSON_DSTU2
        else
          @xml_format = FHIR::Formats::ResourceFormat::RESOURCE_XML
          @json_format = FHIR::Formats::ResourceFormat::RESOURCE_JSON
        end
        @category = {id: 'core_functionality', title: 'Core Functionality'}
      end

      # Create a patient and store its details for format requests
      def setup
        @cached_conformance = @client.capability_statement
        @supports_xml = @cached_conformance.format.any?{|f| f.downcase.include?('xml')}
        @supports_json = @cached_conformance.format.any?{|f| f.downcase.include?('json')}

        @resources = Crucible::Generator::Resources.new(fhir_version)
        @resource = @resources.minimal_patient
        @create_failed = false

        create_reply = @client.create(@resource)

        begin
          assert_response_created create_reply
          result = create_reply.resource
        rescue AssertionException
          @create_failed = true
        end

        if @create_failed
          # If create fails, pick one from the Patient Bundle
          begin
            bundle_reply = request_bundle(get_resource(:Patient), @xml_format)
            assert_response_ok bundle_reply
            bundle_patient = bundle_reply.resource.entry.first.resource
            @id = bundle_patient.id
            @create_failed = false
          rescue Exception
            @create_failed = true            
          end
        else
          @id = create_reply.id
        end

        assert(!@create_failed, 'Unable to create or read a patient.')
      end

      # Delete the reference patient if we created it
      def teardown
        @client.destroy(get_resource(:Patient), @id) unless @create_failed
      end

      test 'CT01', 'Request xml using headers' do
        metadata {
          links "#{BASE_SPEC_LINK}/formats.html"
          links "#{REST_SPEC_LINK}#mime-type"
          links "#{REST_SPEC_LINK}#read"
          requires resource: 'Patient', methods: ['create','read']
          validates resource: 'Patient', methods: ['read'], formats: ['XML']
        }
        skip unless @supports_xml
        begin
          patient = request_entry(get_resource(:Patient), @id, @xml_format)
          assert compare_response_format(patient, @xml_format), "XML format header mismatch: requested #{@xml_format}, received #{patient.response_format}"
          warning { assert compare_response(patient), 'requested XML response does not match created resource' }
        rescue => e
          raise AssertionException.new("CTO1 - Failed to handle XML format header response. Error: #{e.message}")
        end
      end

      @@xml_format_params.each_with_index do |format, index|
        test "CT02#{@@alpha[index]}", "Request [#{format}] using _format" do
          metadata {
            links "#{BASE_SPEC_LINK}/formats.html"
            links "#{REST_SPEC_LINK}#mime-type"
            links "#{REST_SPEC_LINK}#read"
            requires resource: 'Patient', methods: ['create','read']
            validates resource: 'Patient', methods: ['read'], formats: ['XML']
          }
          skip unless @supports_xml
          begin
            wire_format = format
            wire_format = @xml_format if format == 'XML_FORMAT'
            wire_format = @json_format if format == 'JSON_FORMAT'
            patient = request_entry(get_resource(:Patient), @id, wire_format, true)
            assert compare_response_format(patient, @xml_format), "XML format param mismatch: requested #{format}, received #{patient.response_format}"
            warning { assert compare_response(patient), 'requested XML response does not match created resource' }
          rescue => e
            @client.use_format_param = false
            raise AssertionException.new("CTO2 - Failed to handle XML format param response. Error: #{e.message}")
          end
        end
      end

      test 'CT03', 'Request json using headers' do
        metadata {
          links "#{BASE_SPEC_LINK}/formats.html"
          links "#{REST_SPEC_LINK}#mime-type"
          links "#{REST_SPEC_LINK}#read"
          requires resource: 'Patient', methods: ['create','read']
          validates resource: 'Patient', methods: ['read'], formats: ['JSON']
        }
        skip unless @supports_json
        begin
          patient = request_entry(get_resource(:Patient), @id, @json_format)
          assert compare_response_format(patient, @json_format), "JSON format header mismatch: requested #{@json_format}, received #{patient.response_format}"
          warning { assert compare_response(patient), 'requested JSON resource does not match created resource' }
        rescue => e
          raise AssertionException.new("CTO3 - Failed to handle JSON format header response. Error: #{e.message}")
        end
      end

      @@json_format_params.each_with_index do |format, index|
        test "CT04#{@@alpha[index]}", "Request [#{format}] using _format" do
          metadata {
            links "#{BASE_SPEC_LINK}/formats.html"
            links "#{REST_SPEC_LINK}#mime-type"
            links "#{REST_SPEC_LINK}#read"
            requires resource: 'Patient', methods: ['create','read']
            validates resource: 'Patient', methods: ['read'], formats: ['JSON']
          }
          skip unless @supports_json
          begin
            wire_format = format
            wire_format = @xml_format if format == 'XML_FORMAT'
            wire_format = @json_format if format == 'JSON_FORMAT'
            patient = request_entry(get_resource(:Patient), @id, wire_format, true)
            assert compare_response_format(patient, @json_format), "JSON format param mismatch: requested #{wire_format}, received #{patient.response_format}"
            warning { assert compare_response(patient), 'requested JSON response does not match created resource' }
          rescue => e
            @client.use_format_param = false
            raise AssertionException.new("CTO4 - Failed to handle JSON format param response. Error: #{e.message}")
          end
        end
      end

      test 'FT01', 'Request xml and json using headers' do
        metadata {
          links "#{BASE_SPEC_LINK}/formats.html"
          links "#{REST_SPEC_LINK}#mime-type"
          links "#{REST_SPEC_LINK}#read"
          requires resource: 'Patient', methods: ['create','read']
          validates resource: 'Patient', methods: ['read'], formats: ['XML','JSON']
        }
        skip unless @supports_xml && @supports_json
        begin
          patient_xml = request_entry(get_resource(:Patient), @id, @xml_format)
          patient_json = request_entry(get_resource(:Patient), @id, @json_format)

          assert compare_response_format(patient_xml, @xml_format), "XML format header mismatch: requested #{@xml_format}, received #{patient_xml.response_format}"
          assert compare_response_format(patient_json, @json_format), "JSON format header mismatch: requested #{@json_format}, received #{patient_json.response_format}"
          warning { assert compare_entries(patient_xml, patient_json), 'requested XML & JSON resources do not match created resource or each other' }
        rescue => e
          @client.use_format_param = false
          raise AssertionException.new("FT01 - Failed to handle XML & JSON header param response. Error: #{e.message}")
        end
      end

      test 'FT02', 'Request xml and json using _format' do
        metadata {
          links "#{BASE_SPEC_LINK}/formats.html"
          links "#{REST_SPEC_LINK}#mime-type"
          links "#{REST_SPEC_LINK}#read"
          requires resource: 'Patient', methods: ['create','read']
          validates resource: 'Patient', methods: ['read'], formats: ['XML','JSON']
        }
        skip unless @supports_xml && @supports_json
        begin
          patient_xml = request_entry(get_resource(:Patient), @id, @xml_format, true)
          patient_json = request_entry(get_resource(:Patient), @id, @json_format, true)

          assert compare_response_format(patient_xml, @xml_format), "XML format header mismatch: requested #{@xml_format}, received #{patient_xml.response_format}"
          assert compare_response_format(patient_json, @json_format), "JSON format header mismatch: requested #{@json_format}, received #{patient_json.response_format}"
          warning { assert compare_entries(patient_xml, patient_json), 'requested XML & JSON responses do not match created resource or each other' }
        rescue => e
          @client.use_format_param = false
          raise AssertionException.new("FT02 - Failed to handle XML & JSON format param response. Error: #{e.message}")
        end
      end

      test 'FT03', 'Request xml Bundle using headers' do
        metadata {
          links "#{BASE_SPEC_LINK}/formats.html"
          links "#{REST_SPEC_LINK}#mime-type"
          links "#{REST_SPEC_LINK}#read"
          requires resource: 'Patient', methods: ['create','read']
          validates resource: 'Patient', methods: ['read'], formats: ['XML']
        }
        skip unless @supports_xml
        begin
          patients_bundle = request_bundle(get_resource(:Patient), @xml_format)

          assert compare_response_format(patients_bundle, @xml_format), "Bundle XML format header mismatch: requested #{@xml_format}, received #{patients_bundle.response_format}"
        rescue => e
          raise AssertionException.new("FT03 - Failed to handle Bundle XML format header response. Error: #{e.message}")
        end
      end

      @@xml_format_params.each_with_index do |format, index|
        test "FT04#{@@alpha[index]}", "Request [#{format}] Bundle using _format" do
          metadata {
            links "#{BASE_SPEC_LINK}/formats.html"
            links "#{REST_SPEC_LINK}#mime-type"
            links "#{REST_SPEC_LINK}#read"
            requires resource: 'Patient', methods: ['create','read']
            validates resource: 'Patient', methods: ['read'], formats: ['XML']
          }
          skip unless @supports_xml
          begin
            wire_format = format
            wire_format = @xml_format if format == 'XML_FORMAT'
            wire_format = @json_format if format == 'JSON_FORMAT'

            patients_bundle = request_bundle(get_resource(:Patient), wire_format, true)

            assert compare_response_format(patients_bundle, @xml_format), "Bundle XML format param mismatch: requested #{wire_format}, received #{patients_bundle.response_format}"
          rescue => e
            raise AssertionException.new("FT04- Failed to handle Bundle XML format param response. Error: #{e.message}")
          end
        end
      end

      test 'FT05', 'Request json Bundle using headers' do
        metadata {
          links "#{BASE_SPEC_LINK}/formats.html"
          links "#{REST_SPEC_LINK}#mime-type"
          links "#{REST_SPEC_LINK}#read"
          requires resource: 'Patient', methods: ['create','read']
          validates resource: 'Patient', methods: ['read'], formats: ['JSON']
        }
        skip unless @supports_json
        begin
          patients_bundle = request_bundle(get_resource(:Patient), @json_format)

          assert compare_response_format(patients_bundle, @json_format), "Bundle JSON format header mismatch: requested #{@json_format}, received #{patients_bundle.response_format}"
        rescue => e
          raise AssertionException.new("FT05 - Failed to handle Bundle JSON format header response. Error: #{e.message}")
        end
      end

      @@json_format_params.each_with_index do |format, index|
        test "FT06#{@@alpha[index]}", "Request [#{format}] Bundle using _format" do
          metadata {
            links "#{BASE_SPEC_LINK}/formats.html"
            links "#{REST_SPEC_LINK}#mime-type"
            links "#{REST_SPEC_LINK}#read"
            requires resource: 'Patient', methods: ['create','read']
            validates resource: 'Patient', methods: ['read'], formats: ['JSON']
          }
          skip unless @supports_json
          begin
            wire_format = format
            wire_format = @xml_format if format == 'XML_FORMAT'
            wire_format = @json_format if format == 'JSON_FORMAT'

            patients_bundle = request_bundle(get_resource(:Patient), wire_format, true)

            assert compare_response_format(patients_bundle, @json_format), "Bundle JSON format param mismatch: requested #{wire_format}, received #{patients_bundle.response_format}"
          rescue => e
            raise AssertionException.new("FT06 - Failed to handle Bundle JSON format param response. Error: #{e.message}")
          end
        end
      end

      test 'FT07', 'Request invalid mime-type using headers' do
        metadata {
          links "#{BASE_SPEC_LINK}/formats.html#wire"
          requires resource: 'Patient', methods: ['read']
          validates resource: 'Patient', methods: ['read']
        }

        # There's no such a strict requirement in DSTU2 spec.
        # http://hl7.org/fhir/DSTU2/http.html#mime-type
        skip if fhir_version == :dstu2 || fhir_version == :stu3

        @client.use_format_param = false
        reply = @client.read_feed(get_resource(:Patient),'application/foobar')

        # Per http://hl7.org/fhir/http.html#mime-type (on 3/15/19):
        # 406 Not Acceptable is the appropriate response when the Accept header requests a format that the server does not support, 
        # and 415 Unsupported Media Type when the client posts a format that is not supported to the server.
        assert( (reply.code==406), "406 Not Acceptable is the appropriate response when the Accept header requests a format that the server does not support. Received #{reply.code}.")
      end

      test 'FT08', 'Request invalid mime-type using _format' do
        metadata {
          links "#{BASE_SPEC_LINK}/formats.html#wire"
          requires resource: 'Patient', methods: ['read']
          validates resource: 'Patient', methods: ['read']
        }

        # There's no such a strict requirement in DSTU2 spec.
        # http://hl7.org/fhir/DSTU2/http.html#mime-type
        skip if fhir_version == :dstu2 || fhir_version == :stu3

        @client.use_format_param = true
        reply = @client.read_feed(get_resource(:Patient),'application/foobar')
        @client.use_format_param = false

        # Per http://hl7.org/fhir/http.html#mime-type (on 3/15/19):
        # 406 Not Acceptable is the appropriate response when the Accept header requests a format that the server does not support, 
        # and 415 Unsupported Media Type when the client posts a format that is not supported to the server.
        assert( (reply.code==406), "406 Not Acceptable is the appropriate response when the Accept header requests a format that the server does not support. Received #{reply.code}.")
      end

      private

      # Compare requested resource with created resource
      # @resource is a fixture before it has been posted to the server.
      # entry is what was returned from a read.
      # The server is expected to update 'id' and add 'meta.lastUpdated',
      # and if history is supported add meta.versionId.  Ignore any changes to these.
      def compare_response(entry)
        entry&.resource&.equals?(@resource,['id','lastUpdated','versionId']) == true
      end

      # Compare response format with requested format
      def compare_response_format(entry, requested_format)
        !entry.nil? && !entry.response.nil? && entry.response_format == requested_format
      end

      # Compare two requested entries
      def compare_entries(entry1, entry2)
        compare_response(entry1) && compare_response(entry2) && entry1.resource.equals?(entry2.resource,['id'])
      end

      # Unify resource requests and format specification
      def request_entry(resource_class, id, format, use_format_param=false)
        @client.use_format_param = use_format_param
        entry = @client.read(resource_class, id, format)
        @client.use_format_param = false
        assert_response_ok entry, "Failed to retrieve resource: #{entry.request[:url]}"
        # entry.resource.id = id if !entry.resource.nil?
        entry
      end

      # Unify Bundle requests and format specification
      def request_bundle(resource_class, format, use_format_param=false)
        @client.use_format_param = use_format_param
        entry = @client.read_feed(resource_class, format)
        @client.use_format_param = false
        assert_response_ok entry, "Failed to retrieve Bundle: #{entry.request[:url]}"
        entry
      end

    end
  end
end
