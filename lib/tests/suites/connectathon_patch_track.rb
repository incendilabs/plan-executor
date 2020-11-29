module Crucible
  module Tests
    class ConnectathonPatchTrackTest < BaseSuite

      def id
        'ConnectathonPatchTrackTest'
      end

      def description
        'Connectathon PATCH Test.'
      end

      def initialize(client1, client2=nil)
        super(client1, client2)
        @tags.append('connectathon')
        @category = {id: 'connectathon', title: 'Connectathon'}
        @supported_versions = [:stu3]
      end

      def setup
        @medication_order = Crucible::Generator::Resources.new(fhir_version).medicationorder_simple
        @medication_order.id = nil # clear the identifier, in case the server checks for duplicates
        @medication_order.identifier = nil # clear the identifier, in case the server checks for duplicates

        reply = @client.create(@medication_order)

        assert_response_ok(reply)
        @medication_order_id = reply.id
      end

      def teardown
        @client.destroy(FHIR::MedicationRequest, @medication_order_id) unless @medication_order_id.nil?
      end

      ['JSON','XML'].each do |fmt|

        #
        # Get the MedicationRequest that was just created.
        #
        test "C12PATCH_1_(#{fmt})","Get Existing MedicationRequest by #{fmt}" do
          metadata {
            links "#{REST_SPEC_LINK}#read"
            links "#{BASE_SPEC_LINK}/medicationorder.html"
            links 'http://wiki.hl7.org/index.php?title=201605_PATCH_Connectathon_Track_Proposal'
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
        test "C12PATCH_2_(#{fmt})","#{fmt} Patch Existing MedicationRequest" do
          metadata {
            links "#{REST_SPEC_LINK}#patch"
            links 'http://wiki.hl7.org/index.php?title=201605_PATCH_Connectathon_Track_Proposal'
            requires resource: 'MedicationRequest', methods: ['read']
            validates resource: 'MedicationRequest', methods: ['read']
          }

          skip 'TODO: https://github.com/FirelyTeam/spark/issues/302'

          patchset = [{ op: "replace", path: "MedicationRequest/status", value: "completed" }]
          reply = @client.partial_update(FHIR::MedicationRequest, @medication_order_id, patchset, {}, resource_format(fmt))

          assert_response_ok(reply)
          warning { 
            assert_resource_type(reply, FHIR::MedicationRequest)
            assert_resource_content_type(reply, fmt.downcase)
          }
          reply = @client.read(FHIR::MedicationRequest, @medication_order_id, resource_format(fmt))
          assert_response_ok(reply)
          assert_equal(reply.resource.status, 'completed', 'Status not updated from patch.')
          warning {
            assert(reply.resource.meta.versionId != @previous_version_id, 'VersionId not updated after patch.') unless @previous_version_id.nil?
          }
        end

        #
        # Attempt to PATCH the MedicationRequest with an old Version Id.
        #
        test "C12PATCH_3_(#{fmt})","#{fmt} Patching Medication Order with old Version Id should result in error" do
          metadata {
            links "#{REST_SPEC_LINK}#patch"
            links 'http://wiki.hl7.org/index.php?title=201605_PATCH_Connectathon_Track_Proposal'
            requires resource: 'MedicationRequest', methods: ['read']
            validates resource: 'MedicationRequest', methods: ['read']
          }

          skip 'TODO: https://github.com/FirelyTeam/spark/issues/302'

          assert(!@previous_version_id.nil?, "VersionId of Existing Medication Request not returned in C12PATCH_1_(#{fmt}).")

          patchset = [{ op: "replace", path: "MedicationRequest/status", value: "active" }]

          # http://hl7.org/fhir/2016Sep/http.html#2.42.0.2
          # According to the FHIR spec, the If-Match eTag for version id should be weak.
          options = { 'If-Match' => "W/\"#{@previous_version_id}\"" }

          reply = @client.partial_update(FHIR::MedicationRequest, @medication_order_id, patchset, options, resource_format(fmt))

          assert_response_conflict(reply)

          reply = @client.read(FHIR::MedicationRequest, @medication_order_id, resource_format(fmt))
          assert_response_ok(reply)
          assert_equal(reply.resource.status, 'completed', 'Resource should not have been patched because version id was stale.')

        end

      end

      def resource_format(f)
        "FHIR::Formats::ResourceFormat::RESOURCE_#{f}".constantize
      end

    end
  end
end
