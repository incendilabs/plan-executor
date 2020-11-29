module Crucible
  module Tests
    class ConnectathonAuditEventAndProvenanceTrackTest < BaseSuite

      def id
        'ConnectathonAuditEventAndProvenanceTrackTest'
      end

      def description
        'Connectathon AuditEvent and Provenance Track Test focuses on server-created AuditEvents and Provenance resources.'
      end

      def initialize(client1, client2=nil)
        super(client1, client2)
        @category = {id: 'connectathon', title: 'Connectathon'}
        @supported_versions = [:stu3]
      end

      def setup
        @resources = Crucible::Generator::Resources.new(fhir_version)
      end

      def teardown
        @client.destroy(FHIR::STU3::Provenance, @provenance1.id) if @provenance1 && !@provenance1.id.nil?
        @client.destroy(FHIR::STU3::Provenance, @provenance2.id) if @provenance2 && !@provenance2.id.nil?
        @client.destroy(FHIR::STU3::Provenance, @provenance3.id) if @provenance3 && !@provenance3.id.nil?
        @client.destroy(FHIR::STU3::Provenance, @provenance4.id) if @provenance4 && !@provenance4.id.nil?
        @client.destroy(FHIR::STU3::Patient, @patient.id) if @patient && !@patient.id.nil?
        @client.destroy(FHIR::STU3::Patient, @patient1.id) if @patient1 && !@patient1.id.nil?
        @client.destroy(FHIR::STU3::Patient, @patient2.id) if @patient2 && !@patient2.id.nil?
        FHIR::ResourceAddress::DEFAULTS.delete('X-Provenance') # just in case
      end

      # Create a Patient then check for AuditEvent
      test 'CAEP1','Create a Patient then check for AuditEvent' do
        metadata {
          links "#{REST_SPEC_LINK}#create"
          links "#{BASE_SPEC_LINK}/patient.html"
          links "#{REST_SPEC_LINK}#search"
          links "#{BASE_SPEC_LINK}/auditevent.html"
          links 'http://wiki.hl7.org/index.php?title=FHIR_Connectathon_10#Track_4_-EHR_record_lifecycle_architecture'
          requires resource: 'Patient', methods: ['create']
          requires resource: 'AuditEvent', methods: ['search']
          validates resource: 'Patient', methods: ['create']
          validates resource: 'AuditEvent', methods: ['search']
          validates resource: nil, methods: ['Audit Logging']
        }

        skip "TODO: https://github.com/FirelyTeam/spark/issues/301"

        @patient = @resources.minimal_patient
        @patient.id = nil # clear the identifier
        reply = @client.create(@patient)
        assert_response_ok(reply)
        @patient.id = reply.id

        options = {
          :search => {
            :flag => false,
            :compartment => nil,
            :parameters => {
              'entity' => "Patient/#{@patient.id}"
            }
          }
        }
        sleep 5 # give a few seconds for the Audit Event to be generated
        reply = @client.search(FHIR::STU3::AuditEvent, options)
        assert_response_ok(reply)
        assert_bundle_response(reply)
        assert_equal(1, reply.resource.entry.size, 'There should only be one AuditEvent for the test Patient currently in the system.', reply.body)
        assert(reply.resource.entry[0].try(:resource).try(:entity).try(:first).try(:reference).try(:reference).include?(@patient.id), 'The correct AuditEvent was not returned.', reply.body)
        warning { assert_equal('rest', reply.resource.entry[0].try(:resource).try(:type).try(:code), 'Was expecting an AuditEvent.event.type.code of rest', reply.body) }
        warning { assert_equal('http://hl7.org/fhir/audit-event-type', reply.resource.entry[0].try(:resource).try(:type).try(:system), 'Was expecting an AuditEvent.event.type.system of http://hl7.org/fhir/audit-event-type', reply.body) }
      end

      # Create a Patient with Provenance as a transaction
      test 'CAEP2','Create a Patient with Provenance as transaction' do
        metadata {
          links "#{REST_SPEC_LINK}#create"
          links "#{BASE_SPEC_LINK}/patient.html"
          links "#{REST_SPEC_LINK}#search"
          links "#{BASE_SPEC_LINK}/provenance.html"
          links "#{BASE_SPEC_LINK}/provenance.html#6.4.4.2" # submit as transaction
          links 'http://wiki.hl7.org/index.php?title=FHIR_Connectathon_10#Track_4_-EHR_record_lifecycle_architecture'
          requires resource: 'Patient', methods: ['create']
          requires resource: 'Provenance', methods: ['search']
          validates resource: 'Patient', methods: ['create']
          validates resource: 'Provenance', methods: ['search']
          validates resource: nil, methods: ['transaction-system', 'provenance']
        }

        skip "TODO: https://github.com/FirelyTeam/spark/issues/296"

        @patient1 = @resources.minimal_patient
        @patient1.id = 'foo'

        @provenance1 = FHIR::STU3::Provenance.new
        @provenance1.target = [ FHIR::STU3::Reference.new ]
        @provenance1.target[0].reference = "Patient/#{@patient1.id}"
        @provenance1.recorded = DateTime.now.strftime("%Y-%m-%dT%T.%LZ")
        @provenance1.reason = [ FHIR::STU3::Coding.new ]
        @provenance1.reason[0].system = 'http://hl7.org/fhir/v3/ActReason'
        @provenance1.reason[0].display = 'patient administration'
        @provenance1.reason[0].code = 'PATADMIN'
        @provenance1.agent = [ FHIR::STU3::Provenance::Agent.new ]
        @provenance1.agent[0].role = FHIR::STU3::CodeableConcept.new
        @provenance1.agent[0].role.coding = FHIR::STU3::Coding.new
        @provenance1.agent[0].role.coding.system = 'http://hl7.org/fhir/provenance-participant-role'
        @provenance1.agent[0].role.coding.display = 'Author'
        @provenance1.agent[0].role.coding.code = 'author'

        @client.begin_transaction
        @client.add_transaction_request('POST',nil,@patient1)
        @client.add_transaction_request('POST',nil,@provenance1)
        reply = @client.end_transaction

        # set the patient id as nil, until we know that the transaction was successful, so teardown doesn't try
        # to delete something that wasn't created
        @patient1.id = nil

        assert([200,201,202].include?(reply.code), 'Expected response code 200, 201, or 202', reply.body)
        assert_bundle_response(reply)

        # set the patient id back from nil to whatever the server created
        @patient1.id = FHIR::ResourceAddress.pull_out_id('Patient',reply.resource.entry[0].try(:response).try(:location))
        @provenance1.id = FHIR::ResourceAddress.pull_out_id('Provenance',reply.resource.entry[1].try(:response).try(:location))

        options = {
          :search => {
            :flag => false,
            :compartment => nil,
            :parameters => {
              'target' => "Patient/#{@patient1.id}"
            }
          }
        }
        reply = @client.search(FHIR::STU3::Provenance, options)
        assert_response_ok(reply)
        assert_bundle_response(reply)
        assert_equal(1, reply.resource.entry.size, 'There should only be one Provenance for the test Patient currently in the system.', reply.body)
        assert(reply.resource.entry[0].try(:resource).try(:target).try(:first).try(:reference).include?(@patient1.id), 'The correct Provenance was not returned.', reply.body)
      end

      # Create a Patient with a Provenance header:
      # Grahame says: "json format, in the X-Provenance header - I'll pick it up and store it after fixing the target reference (just leave target blank)"
      test 'CAEP2X','Create a Patient with X-Provenance header' do
        metadata {
          links "#{REST_SPEC_LINK}#create"
          links "#{BASE_SPEC_LINK}/patient.html"
          links "#{REST_SPEC_LINK}#search"
          links "#{BASE_SPEC_LINK}/provenance.html"
          links 'http://wiki.hl7.org/index.php?title=FHIR_Connectathon_10#Track_4_-EHR_record_lifecycle_architecture'
          requires resource: 'Patient', methods: ['create']
          requires resource: 'Provenance', methods: ['search']
          validates resource: 'Patient', methods: ['create']
          validates resource: 'Provenance', methods: ['search']
          validates resource: nil, methods: ['provenance']
        }

        @patient2 = @resources.minimal_patient
        @patient2.id = nil # clear the identifier

        @provenance2 = FHIR::STU3::Provenance.new
        @provenance2.target = [ FHIR::STU3::Reference.new ]
        # @provenance2.target[0].reference = "Patient/#{@patient2.id}"
        @provenance2.recorded = DateTime.now.strftime("%Y-%m-%dT%T.%LZ")
        @provenance2.reason = [ FHIR::STU3::Coding.new ]
        @provenance2.reason[0].system = 'http://hl7.org/fhir/v3/ActReason'
        @provenance2.reason[0].display = 'patient administration'
        @provenance2.reason[0].code = 'PATADMIN'
        @provenance2.agent = [ FHIR::STU3::Provenance::Agent.new ]
        @provenance2.agent[0].role = FHIR::STU3::Coding.new
        @provenance2.agent[0].role.system = 'http://hl7.org/fhir/provenance-participant-role'
        @provenance2.agent[0].role.display = 'Author'
        @provenance2.agent[0].role.code = 'author'

        skip 'TODO: https://github.com/FirelyTeam/spark/issues/297'

        headers = { 'X-Provenance' => URI::encode(@provenance2.to_json) }
        reply = @client.base_create(@patient2, nil, @client.default_format, headers)

        assert_response_ok(reply)
        @patient2.id = reply.id

        options = {
          :search => {
            :flag => false,
            :compartment => nil,
            :parameters => {
              'target' => "Patient/#{@patient2.id}"
            }
          }
        }
        reply = @client.search(FHIR::STU3::Provenance, options)
        assert_response_ok(reply)
        assert_bundle_response(reply)
        assert_equal(1, reply.resource.entry.size, 'There should only be one Provenance for the test Patient currently in the system.', reply.body)
        assert(reply.resource.entry[0].try(:resource).try(:target).try(:first).try(:reference).include?(@patient2.id), 'The correct Provenance was not returned.', reply.body)
        @provenance2.id = FHIR::ResourceAddress.pull_out_id('Provenance',reply.resource.entry[0].try(:response).try(:location))
      end

      # Update a Patient and check for AuditEvent
      test 'CAEP3','Update a Patient then check for AuditEvent' do
        metadata {
          links "#{REST_SPEC_LINK}#update"
          links "#{BASE_SPEC_LINK}/patient.html"
          links "#{REST_SPEC_LINK}#search"
          links "#{BASE_SPEC_LINK}/auditevent.html"
          links 'http://wiki.hl7.org/index.php?title=FHIR_Connectathon_10#Track_4_-EHR_record_lifecycle_architecture'
          requires resource: 'Patient', methods: ['create','update']
          requires resource: 'AuditEvent', methods: ['search']
          validates resource: 'Patient', methods: ['update']
          validates resource: 'AuditEvent', methods: ['search']
          validates resource: nil, methods: ['Audit Logging']
        }

        skip 'TODO: https://github.com/FirelyTeam/spark/issues/297'

        assert @patient, 'Patient record hasn\'t been created in the previous tests'

        @patient.gender = 'male'
        reply = @client.update(@patient,@patient.id)
        assert_response_ok(reply)

        options = {
          :search => {
            :flag => false,
            :compartment => nil,
            :parameters => {
              'entity' => "Patient/#{@patient.id}"
            }
          }
        }
        sleep 5 # give a few seconds for the Audit Event to be generated
        reply = @client.search(FHIR::STU3::AuditEvent, options)
        assert_response_ok(reply)
        assert_bundle_response(reply)
        found_update_type = false
        reply.resource.entry.each do |entry|
          assert(entry.try(:resource).try(:entity).try(:first).try(:reference).try(:reference), 'An incorrect AuditEvent was returned.', reply.body)
          assert(entry.try(:resource).try(:entity).try(:first).try(:reference).try(:reference).include?(@patient.id), 'An incorrect AuditEvent was returned.', reply.body)
          if entry.try(:resource).try(:action) == 'U'
            found_update_type = true
            warning { assert_equal('rest', entry.try(:resource).try(:type).try(:code), 'Was expecting an AuditEvent.event.type.code of rest', reply.body) }
            warning { assert_equal('http://hl7.org/fhir/audit-event-type', entry.try(:resource).try(:type).try(:system), 'Was expecting an AuditEvent.event.type.system of http://hl7.org/fhir/audit-event-type', reply.body) }
          end
        end
        assert(found_update_type, 'No update AuditEvent returned', reply.body)
      end

      # Update a Patient with Provenance as a transaction
      test 'CAEP4','Update a Patient with Provenance as transaction' do
        metadata {
          links "#{REST_SPEC_LINK}#update"
          links "#{BASE_SPEC_LINK}/patient.html"
          links "#{REST_SPEC_LINK}#search"
          links "#{BASE_SPEC_LINK}/provenance.html"
          links "#{BASE_SPEC_LINK}/provenance.html#6.4.4.2" # submit as transaction
          links 'http://wiki.hl7.org/index.php?title=FHIR_Connectathon_10#Track_4_-EHR_record_lifecycle_architecture'
          requires resource: 'Patient', methods: ['create','update']
          requires resource: 'Provenance', methods: ['search']
          validates resource: 'Patient', methods: ['update']
          validates resource: 'Provenance', methods: ['search']
          validates resource: nil, methods: ['transaction-system', 'provenance']
        }

        skip 'TODO: https://github.com/FirelyTeam/spark/issues/297'

        assert(@patient1, 'Patient record hasn\'t been created in the previous tests')

        @patient1.gender = 'male'

        @provenance3 = FHIR::STU3::Provenance.new
        @provenance3.target = [ FHIR::STU3::Reference.new ]
        @provenance3.target[0].reference = "Patient/#{@patient1.id}"
        @provenance3.recorded = DateTime.now.strftime("%Y-%m-%dT%T.%LZ")
        @provenance3.reason = [ FHIR::STU3::Coding.new ]
        @provenance3.reason[0].system = 'http://hl7.org/fhir/v3/ActReason'
        @provenance3.reason[0].display = 'patient administration'
        @provenance3.reason[0].code = 'PATADMIN'
        @provenance3.agent = [ FHIR::STU3::Provenance::Agent.new ]
        @provenance3.agent[0].role = FHIR::STU3::Coding.new
        @provenance3.agent[0].role.system = 'http://hl7.org/fhir/provenance-participant-role'
        @provenance3.agent[0].role.display = 'Author'
        @provenance3.agent[0].role.code = 'author'

        @client.begin_transaction
        @client.add_transaction_request('PUT',nil,@patient1)
        @client.add_transaction_request('POST',nil,@provenance3)
        reply = @client.end_transaction

        assert([200,201,202].include?(reply.code), 'Expected response code 200, 201, or 202', reply.body)
        assert_bundle_response(reply)

        @provenance3.id = FHIR::ResourceAddress.pull_out_id('Provenance',reply.resource.entry[1].try(:response).try(:location))

        options = {
          :search => {
            :flag => false,
            :compartment => nil,
            :parameters => {
              'target' => "Patient/#{@patient1.id}"
            }
          }
        }
        reply = @client.search(FHIR::STU3::Provenance, options)
        assert_response_ok(reply)
        assert_bundle_response(reply)
        assert_equal(2, reply.resource.entry.size, 'There should be two Provenance resources for the test Patient currently in the system.', reply.body)
        reply.resource.entry.each do |entry|
          assert(entry.try(:resource).try(:target).try(:first).try(:reference).include?(@patient1.id), 'An incorrect Provenance was returned.', reply.body)
        end
      end

      # Update a Patient with a Provenance header:
      # Grahame says: "json format, in the X-Provenance header - I'll pick it up and store it after fixing the target reference (just leave target blank)"
      test 'CAEP4X','Update a Patient with X-Provenance header' do
        metadata {
          links "#{REST_SPEC_LINK}#create"
          links "#{BASE_SPEC_LINK}/patient.html"
          links "#{REST_SPEC_LINK}#search"
          links "#{BASE_SPEC_LINK}/provenance.html"
          links 'http://wiki.hl7.org/index.php?title=FHIR_Connectathon_10#Track_4_-EHR_record_lifecycle_architecture'
          requires resource: 'Patient', methods: ['create']
          requires resource: 'Provenance', methods: ['search']
          validates resource: 'Patient', methods: ['create']
          validates resource: 'Provenance', methods: ['search']
        }

        skip 'TODO: https://github.com/FirelyTeam/spark/issues/297'

        assert(@patient2, 'Patient record hasn\'t been created in the previous tests')

        @patient2.gender = 'male'

        @provenance4 = FHIR::STU3::Provenance.new
        @provenance4.target = [ FHIR::STU3::Reference.new ]
        # @provenance4.target[0].reference = "Patient/#{@patient2.id}"
        @provenance4.recorded = DateTime.now.strftime("%Y-%m-%dT%T.%LZ")
        @provenance4.reason = [ FHIR::STU3::Coding.new ]
        @provenance4.reason[0].system = 'http://hl7.org/fhir/v3/ActReason'
        @provenance4.reason[0].display = 'patient administration'
        @provenance4.reason[0].code = 'PATADMIN'
        @provenance4.agent = [ FHIR::STU3::Provenance::Agent.new ]
        @provenance4.agent[0].role = FHIR::STU3::Coding.new
        @provenance4.agent[0].role.system = 'http://hl7.org/fhir/provenance-participant-role'
        @provenance4.agent[0].role.display = 'Author'
        @provenance4.agent[0].role.code = 'author'

        headers = { 'X-Provenance' => URI::encode(@provenance4.to_json) }
        reply = @client.base_update(@patient2, @patient2.id, nil, @client.default_format, headers)
        assert_response_ok(reply)


        options = {
          :search => {
            :flag => false,
            :compartment => nil,
            :parameters => {
              'target' => "Patient/#{@patient2.id}"
            }
          }
        }
        reply = @client.search(FHIR::STU3::Provenance, options)
        assert_response_ok(reply)
        assert_bundle_response(reply)
        assert_equal(2, reply.resource.entry.size, 'There should be two Provenance resources for the test Patient currently in the system.', reply.body)
        reply.resource.entry.each do |entry|
          assert(entry.try(:resource).try(:target).try(:first).try(:reference), 'An incorrect Provenance was returned.', reply.body)
          assert(entry.try(:resource).try(:target).try(:first).try(:reference).include?(@patient2.id), 'An incorrect Provenance was returned.', reply.body)
        end
        @provenance3.id = FHIR::ResourceAddress.pull_out_id('Provenance',reply.resource.entry[0].try(:response).try(:location))
        @provenance4.id = FHIR::ResourceAddress.pull_out_id('Provenance',reply.resource.entry[1].try(:response).try(:location))
      end

      # Read a Patient and check for AuditEvent
      test 'CAEP5','Read a Patient and check for AuditEvent' do
        metadata {
          links "#{REST_SPEC_LINK}#read"
          links "#{BASE_SPEC_LINK}/patient.html"
          links "#{REST_SPEC_LINK}#search"
          links "#{BASE_SPEC_LINK}/auditevent.html"
          links 'http://wiki.hl7.org/index.php?title=FHIR_Connectathon_10#Track_4_-EHR_record_lifecycle_architecture'
          requires resource: 'Patient', methods: ['create','read']
          requires resource: 'AuditEvent', methods: ['search']
          validates resource: 'Patient', methods: ['read']
          validates resource: 'AuditEvent', methods: ['search']
          validates resource: nil, methods: ['Audit Logging']
        }

        skip 'TODO: https://github.com/FirelyTeam/spark/issues/297'

        assert(@patient, 'Patient record hasn\'t been created in the previous tests')

        reply = @client.read(FHIR::STU3::Patient,@patient.id)
        assert_response_ok(reply)

        options = {
          :search => {
            :flag => false,
            :compartment => nil,
            :parameters => {
              'entity' => "Patient/#{@patient.id}"
            }
          }
        }
        sleep 5 # give a few seconds for the Audit Event to be generated
        reply = @client.search(FHIR::STU3::AuditEvent, options)
        assert_response_ok(reply)
        assert_bundle_response(reply)
        found_read_type = false
        reply.resource.entry.each do |entry|
          assert(entry.try(:resource).try(:entity).try(:first).try(:reference).try(:reference), 'An incorrect AuditEvent was returned.', reply.body)
          assert(entry.try(:resource).try(:entity).try(:first).try(:reference).try(:reference).include?(@patient.id), 'An incorrect AuditEvent was returned.', reply.body)
          if entry.try(:resource).try(:action) == 'R'
            found_read_type = true
            warning { assert_equal('rest', entry.try(:resource).try(:type).try(:code), 'Was expecting an AuditEvent.event.type.code of rest', reply.body) }
            warning { assert_equal('http://hl7.org/fhir/audit-event-type', entry.try(:resource).try(:type).try(:system), 'Was expecting an AuditEvent.event.type.system of http://hl7.org/fhir/audit-event-type', reply.body) }
          end
        end
        assert(found_read_type, 'No read AuditEvent returned', reply.body)
      end

    end
  end
end
