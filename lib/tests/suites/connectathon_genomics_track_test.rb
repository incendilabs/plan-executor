module Crucible
  module Tests
    class ConnectathonGenomicsTrackTest < BaseSuite

      def id
        'ConnectathonGenomicsTrackTest'
      end

      def description
        'Genomic data are of increasing importance to clinical care and secondary analysis. FHIR Genomics consists of the Sequence resource and several profiles built on top of existing FHIR resources.'
      end

      def initialize(client1, client2=nil)
        super(client1, client2)
        @tags.append('connectathon')
        @category = {id: 'connectathon', title: 'Connectathon'}
        @supported_versions = [:stu3]
      end

      def setup
        @resources = Crucible::Generator::Resources.new(fhir_version)
        @records = {}

        patient = @resources.patient_register
        practitioner = @resources.practitioner_register

        create_object(patient, :patient)
        create_object(practitioner, :practitioner)
      end

      def teardown
        @records.each_value do |value|
          @client.destroy(value.class, value.id)
        end
      end

      # register sequence and observation
      test 'CGT01','Register a New Sequence and Observation' do
        metadata {
          links "#{REST_SPEC_LINK}#create"
          links "#{BASE_SPEC_LINK}/sequence.html"
          links 'http://wiki.hl7.org/index.php?title=201605_FHIR_Genomics_on_FHIR_Connectathon_Track_Proposal'
          requires resource: 'Patient', methods: ['create']
          requires resource: 'Practitioner', methods: ['create']
          requires resource: 'Sequence', methods: ['create']
          requires resource: 'Specimen', methods: ['create']
          requires resource: 'Observation', methods: ['create']
          validates resource: 'Sequence', methods: ['create']
          validates resource: 'Specimen', methods: ['create']
          validates resource: 'Observation', methods: ['create']
        }

        sequence = @resources.sequence_register
        specimen = @resources.specimen_register
        observation = @resources.observation_register

        specimen.subject = @records[:patient].to_reference
        create_object(specimen, :specimen_register_create)

        sequence.patient = @records[:patient].to_reference
        sequence.specimen = @records[:specimen_register_create].to_reference
        create_object(sequence, :sequence_register_create)

        observation.subject = @records[:patient].to_reference
        observation.specimen = @records[:specimen_register_create].to_reference
        observation.performer = @records[:practitioner].to_reference
        create_object(observation, :observation_register_create)
      end

      test 'CGT02', 'Retrieve Genomic Source data for given patient' do
        metadata {
          links "#{REST_SPEC_LINK}#search"
          links 'http://wiki.hl7.org/index.php?title=201605_FHIR_Genomics_on_FHIR_Connectathon_Track_Proposal'
          requires resource: 'Sequence', methods: ['read']
          requires resource: 'Observation', methods: ['read']
          requires resource: 'Patient', methods: ['create','read']
          requires resource: 'Practitioner', methods: ['create']
        }

        options = {
          :search => {
            :flag => false,
            :compartment => nil,
            :parameters => {
              'subject' => "Patient/#{@records[:patient].id}"
            }
          }
        }

        reply = @client.search(FHIR::STU3::Observation, options)
        assert_response_ok(reply)

        ext = reply.resource.entry.find {|entry| entry.resource.extension.find { |exten| exten.url == "http://hl7.org/fhir/StructureDefinition/observation-geneticsGenomicSourceClass" } }

        assert ext, "No Genomic Source Class extension found on returned Observations"

        assert_equal 'LA6683-2', ext.resource.extension.find { |exten| exten.url == 'http://hl7.org/fhir/StructureDefinition/observation-geneticsGenomicSourceClass'}.valueCodeableConcept.coding[0].code
      end

      test 'CGT03', 'Retrieve Family History data for the given patient' do
        metadata {
          links "#{REST_SPEC_LINK}#search"
          links 'http://wiki.hl7.org/index.php?title=201605_FHIR_Genomics_on_FHIR_Connectathon_Track_Proposal'
          requires resource: 'Sequence', methods: ['read']
          requires resource: 'Observation', methods: ['create', 'read']
          requires resource: 'Patient', methods: ['create', 'read']
          requires resource: 'Practitioner', methods: ['create']
          requires resource: 'Specimen', methods: ['create', 'read']
          requires resource: 'FamilyMemberHistory', methods: ['create', 'read']
          requires resource: 'DiagnosticReport', methods: ['create', 'read']
        }

        patient = @resources.patient_familyhistory
        create_object(patient, :family_patient)

        observation = @resources.observation_familyhistory
        observation.subject = @records[:family_patient].to_reference
        create_object(observation, :family_observation)

        familymemberhistory = @resources.family_member_history
        familymemberhistory.patient = @records[:family_patient].to_reference
        familymemberhistory.extension.find { |exten| exten.url == 'http://hl7.org/fhir/StructureDefinition/family-member-history-genetics-observation'}.valueReference = @records[:family_observation].to_reference
        create_object(familymemberhistory, :family_member_history)

        specimen = @resources.specimen_familyhistory
        specimen.subject = @records[:family_patient].to_reference
        create_object(specimen, :family_specimen)

        diag_report = @resources.diagnostic_familyhistory
        diag_report.result = @records[:family_observation].to_reference
        diag_report.subject = @records[:family_patient].to_reference
        diag_report.performer = @records[:practitioner].to_reference
        diag_report.specimen = @records[:family_specimen].to_reference
        create_object(diag_report, :family_report)

        reply = @client.read FHIR::STU3::FamilyMemberHistory, @records[:family_member_history].id
        assert_response_ok(reply)

        ext = reply.resource.extension.find { |exten| exten.url == 'http://hl7.org/fhir/StructureDefinition/family-member-history-genetics-observation'}

        assert ext, "No Family History extension found"

        reply = @client.read FHIR::STU3::Observation, ext.valueReference.reference.split("/")[1]
        assert_response_ok(reply)

        assert @records[:family_observation].equals?(reply.resource, ['meta']), "Observation doesn't match the stored Observation; difference is: #{@records[:family_observation].mismatch(reply.resource, ['meta'])}"
      end

      test 'CGT04', 'Clinical data warehouse search' do
        metadata {
          links "#{REST_SPEC_LINK}#search"
          links 'http://wiki.hl7.org/index.php?title=201605_FHIR_Genomics_on_FHIR_Connectathon_Track_Proposal'
          requires resource: 'Patient', methods: ['create']
          requires resource: 'Practitioner', methods: ['create']
          requires resource: 'Observation', methods: ['create', 'read']
        }

        if @records[:family_patient].nil? || @records[:practitioner].nil? || @records[:family_specimen].nil? || @records[:family_observation].nil?
          skip 'Not all necessary resources successfully created in previous test.' 
        end


        dw_obs = @resources.observation_datawarehouse
        dw_obs.performer = @records[:practitioner].to_reference
        dw_obs.subject = @records[:family_patient].to_reference
        dw_obs.specimen = @records[:family_specimen].to_reference
        create_object(dw_obs, :dw_obs)

        options = {
          :search => {
            :flag => false,
            :compartment => nil,
            :parameters => {
              'subject' => "Patient/#{@records[:family_patient].id}"
            }
          }
        }

        reply = @client.search(FHIR::STU3::Observation, options)
        assert_response_ok(reply)

        assert reply.resource.get_by_id(@records[:dw_obs].id), "No Observation found for that patient"

      end

      test 'CGT05', 'HLA Typing' do
        metadata {
          links "#{REST_SPEC_LINK}#search"
          links 'http://wiki.hl7.org/index.php?title=201605_FHIR_Genomics_on_FHIR_Connectathon_Track_Proposal'
          requires resource: 'Patient', methods: ['create']
          requires resource: 'Practitioner', methods: ['create']
          requires resource: 'DiagnosticReport', methods: ['create', 'read']
          validates resource: 'DiagnosticReport', methods: ['create', 'read']
        }

        if @records[:family_patient].nil? || @records[:practitioner].nil? || @records[:family_specimen].nil?
          skip 'Not all necessary resources successfully created in previous test.' 
        end

        dr_hla = @resources.diagnosticreport_hltyping
        dr_hla.subject = @records[:family_patient].to_reference
        dr_hla.performer = [@records[:practitioner].to_reference]
        dr_hla.specimen = [@records[:family_specimen].to_reference]

        create_object(dr_hla, :dr_hla)

        reply = @client.read(FHIR::STU3::DiagnosticReport, @records[:dr_hla].id)
        assert_response_ok(reply)

        assert @records[:dr_hla].equals?(reply.resource, ['meta', 'text', 'narrative']), "DiagnosticReport doesn't match the stored DiagnosticReport; difference is: #{@records[:dr_hla].mismatch(reply.resource, ['meta', 'text', 'narrative'])}"
      end

      test 'CGT07', 'Comprehensive Pathology Report' do
        metadata {
          links "#{REST_SPEC_LINK}#search"
          links 'http://wiki.hl7.org/index.php?title=201605_FHIR_Genomics_on_FHIR_Connectathon_Track_Proposal'
          requires resource: 'Patient', methods: ['create']
          requires resource: 'Practitioner', methods: ['create']
          requires resource: 'DiagnosticReport', methods: ['create', 'read', 'search', 'delete']
          validates resource: 'DiagnosticReport', methods: ['create', 'read', 'search', 'delete']
        }

        if @records[:family_patient].nil? || @records[:practitioner].nil? || @records[:family_specimen].nil?
          skip 'Not all necessary resources successfully created in previous test.' 
        end

        dr = @resources.diagnosticreport_pathology
        dr.subject = @records[:family_patient].to_reference
        dr.performer = [@records[:practitioner].to_reference]
        dr.specimen = [@records[:family_specimen].to_reference]
        create_object(dr, :dr_pathreport)

        reply = @client.read(FHIR::STU3::DiagnosticReport, @records[:dr_pathreport].id)
        assert_response_ok(reply)

        assert reply.resource.equals?(@records[:dr_pathreport], ['text', 'meta', 'lastUpdated']), "DiagnosticReport returned does not match DiagnosticReport sent, mismatch in #{reply.resource.mismatch(@records[:dr_pathreport], ['text', 'meta', 'lastUpdated'])}"
      end

      test 'GCT08', 'Sequence Quality' do
        metadata {
          links "#{REST_SPEC_LINK}#search"
          links 'http://wiki.hl7.org/index.php?title=201605_FHIR_Genomics_on_FHIR_Connectathon_Track_Proposal'
          requires resource: 'Patient', methods: ['create']
          requires resource: 'Practitioner', methods: ['create']
          requires resource: 'Sequence', methods: ['read', 'search', 'delete']
          validates resource: 'Sequence', methods: ['read', 'search', 'delete']
        }

        options = {
          :search => {
            :flag => false,
            :compartment => nil,
            :parameters => {
              'patient' => "Patient/#{@records[:patient].id}"
            }
          }
        }

        reply = @client.search(FHIR::STU3::Sequence, options)
        assert_response_ok(reply)

        entries = reply.resource.entry.collect { |e| e.resource if e.resource.quality }

        assert entries.count >= 1, 'No entries with Sequence quality found for Patient'
      end

      private

      def create_object(obj, obj_sym)
        reply = @client.create obj
        assert_response_ok(reply)
        obj.id = reply.id
        @records[obj_sym] = obj

        warning { assert_valid_resource_content_type_present(reply) }
        warning { assert_valid_content_location_present(reply) }
      end

    end
  end
end
