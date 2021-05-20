module Crucible
  module Tests
    class FhirPathPatchTest < BaseSuite

      def id
        'FhirPathPatchTest'
      end

      def description
        'FHIRPath PATCH Test.'
      end

      def initialize(client1, client2 = nil)
        super(client1, client2)
        @tags.append('fhirpath')
        @category = { id: 'fhirpath', title: 'FHIRPath' }
        @supported_versions = [:stu3, :r4]
      end

      def setup
        @medication_order = Crucible::Generator::Resources.new(fhir_version).medicationorder_simple
        @medication_order.id = nil # clear the identifier, in case the server checks for duplicates
        @medication_order.identifier = nil # clear the identifier, in case the server checks for duplicates

        reply = @client.create(@medication_order, {}, @default_format)

        assert_response_ok(reply)
        @medication_order_id = reply.id
      end

      def teardown
        @client.destroy(FHIR::MedicationRequest, @medication_order_id) unless @medication_order_id.nil?
      end

      ['JSON', 'XML'].each do |fmt|

        #
        # Get the MedicationRequest that was just created.
        #
        test "FPP01(#{fmt})", "Get Existing MedicationRequest by #{fmt}" do
          metadata {
            links "#{REST_SPEC_LINK}#read"
            links "#{BASE_SPEC_LINK}/medicationorder.html"
            links 'https://github.com/FirelyTeam/spark/issues/363'
            links 'https://github.com/FirelyTeam/spark/issues/302#issuecomment-843059176'
            requires resource: 'MedicationRequest', methods: ['read']
            validates resource: 'MedicationRequest', methods: ['read']
          }

          reply = @client.read(FHIR::MedicationRequest, @medication_order_id, resource_format(fmt))
          assert_response_ok(reply)
          assert_resource_type(reply, FHIR::MedicationRequest)
          assert_resource_content_type(reply, fmt.downcase)
          warning {
            assert(!reply.resource.meta.nil?, 'Last Updated and VersionId not present.')
            assert(!reply.resource.meta.versionId.nil?, 'VersionId not present.')
            @previous_version_id = reply.resource.meta.versionId
            assert(!reply.resource.meta.lastUpdated.nil?, 'Last Updated not present.')
          }
        end

        #
        # Patch the MedicationRequest.
        #
        test "FPP02(#{fmt})", "#{fmt} Patch Existing MedicationRequest" do
          metadata {
            links "#{REST_SPEC_LINK}#patch"
            links 'http://wiki.hl7.org/index.php?title=201605_PATCH_Connectathon_Track_Proposal'
            requires resource: 'MedicationRequest', methods: ['read']
            validates resource: 'MedicationRequest', methods: ['read']
          }

          format = resource_format(fmt)

          patchset = patchset_resource("replace", "MedicationRequest.status", nil, "completed")
          reply = @client.fhir_patch(FHIR::MedicationRequest, @medication_order_id, patchset, {}, format)

          assert_response_ok(reply)
          warning {
            assert_resource_type(reply, FHIR::MedicationRequest)
            assert_resource_content_type(reply, fmt.downcase)
          }
          reply = @client.read(FHIR::MedicationRequest, @medication_order_id, format)
          assert_response_ok(reply)
          assert_equal(reply.resource.status, 'completed', 'Status not updated from patch.')
          warning {
            assert(reply.resource.meta.versionId != @previous_version_id, 'VersionId not updated after patch.') unless @previous_version_id.nil?
          }
        end

        #
        # Attempt to PATCH the MedicationRequest with an old Version Id.
        #
        test "FPP03(#{fmt})", "#{fmt} Patching Medication Order with old Version Id should result in error" do
          metadata {
            links "#{REST_SPEC_LINK}#patch"
            links 'http://wiki.hl7.org/index.php?title=201605_PATCH_Connectathon_Track_Proposal'
            requires resource: 'MedicationRequest', methods: ['read']
            validates resource: 'MedicationRequest', methods: ['read']
          }

          skip 'TODO: Issue link (conditional patch - see http://www.hl7.org/fhir/R4/http.html#concurrency)'

          assert(!@previous_version_id.nil?, "VersionId of Existing Medication Request not returned in C12PATCH_1_(#{fmt}).")

          patchset = patchset_resource("replace", "MedicationRequest.status", nil, "active")

          # http://hl7.org/fhir/2016Sep/http.html#2.42.0.2
          # According to the FHIR spec, the If-Match eTag for version id should be weak.
          additional_headers = { 'If-Match' => "\"#{@previous_version_id}\"" }

          reply = @client.fhir_patch(FHIR::MedicationRequest, @medication_order_id, patchset, {}, resource_format(fmt), additional_headers)
          assert_response_conflict(reply)

          reply = @client.read(FHIR::MedicationRequest, @medication_order_id, resource_format(fmt))
          assert_response_ok(reply)
          assert_equal(reply.resource.status, 'completed', 'Resource should not have been patched because version id was stale.')

        end

      end

      def resource_format(f)
        "FHIR::Formats::ResourceFormat::RESOURCE_#{f}".constantize
      end

      def patchset_resource(op, path, name, value)
        parameters = get_resource(:Parameters).new
        parameters.parameter = new_parameter("operation")
        parameters.parameter.part = [
          new_parameter("type"),
          new_parameter("path"),
          new_parameter("value")
        ]
        parameters.parameter.part[0].valueCode = op
        parameters.parameter.part[1].valueString = path
        parameters.parameter.part[2].valueString = value
        if !name.nil?
          parameters.parameter.part += new_parameter("name")
          parameters.parameter.part[3].valueString = name
        end
        parameters
      end

      def new_parameter(name)
        parameter = get_resource(:Parameters)::Parameter.new
        parameter.name = name
        parameter
      end

    end
  end
end
