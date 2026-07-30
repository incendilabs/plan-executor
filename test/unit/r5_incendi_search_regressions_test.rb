require_relative '../test_helper'

class R5IncendiSearchRegressionsTest < Test::Unit::TestCase
  SUBSETTED_SYSTEM = 'http://terminology.hl7.org/CodeSystem/v3-ObservationValue'.freeze

  def setup
    @client = FHIR::Client.new('http://r5-incendi-search-regressions.test/fhir', fhir_version: :r5)
  end

  def test_consent_uses_r5_subject_and_patient_search_parameter
    suite = Crucible::Tests::ConsentSearchByPatientReferenceTest.new(@client)
    consent = Crucible::Tests::ResourceGenerator.generate(FHIR::R5::Consent)
    consent.subject = FHIR::R5::Reference.new(reference: 'Patient/r5-consent-patient')
    definition = find_search_parameter('Consent', 'patient')

    assert_include suite.supported_versions, :r5
    assert_instance_of FHIR::R5::Consent, consent
    assert_instance_of FHIR::R5::Reference, consent.subject
    assert_equal 'reference', definition['type']
    assert_include definition['target'], 'Patient'
    assert_match(/Consent\.subject/, definition['expression'])
  end

  def test_consent_setup_builds_the_r5_subject_reference_from_the_create_response_id
    client = SetupRecorder.new
    suite = Crucible::Tests::ConsentSearchByPatientReferenceTest.new(client)

    suite.setup

    consent = client.created.last
    assert_instance_of FHIR::R5::Consent, consent
    assert_instance_of FHIR::R5::Reference, consent.subject
    assert_equal 'Patient/patient-from-create-response', consent.subject.reference
  end

  def test_elements_search_uses_exact_r5_request_and_subsetted_response_contract
    suite = Crucible::Tests::ElementsSearchParameterTest.new(@client)
    suite.instance_variable_set(:@patient_id, 'r5-elements-patient')
    parameters = suite.elements_search_options.fetch(:search).fetch(:parameters)
    patient = FHIR::R5::Patient.new(
      id: 'r5-elements-patient',
      meta: { tag: [{ system: SUBSETTED_SYSTEM, code: 'SUBSETTED' }] },
      name: [{ family: 'Elements' }],
      birthDate: '1974-12-25'
    )

    assert_include suite.supported_versions, :r5
    assert_equal({ '_id' => 'r5-elements-patient', '_elements' => 'name,birthDate' }, parameters)
    assert_instance_of FHIR::R5::Patient, patient
    assert_equal 'SUBSETTED', patient.meta.tag.first.code
    assert_nil patient.gender
  end

  def test_unknown_parameter_remains_unknown_in_r5_and_uses_r5_outcome_entries
    suite = Crucible::Tests::UnknownSearchParameterTest.new(@client)
    definitions = FHIR::R5::Definitions.send(:search_params)
    response = FHIR::R5::Bundle.new(
      type: 'searchset',
      entry: [{
        resource: FHIR::R5::OperationOutcome.new(issue: [{ severity: 'warning', code: 'invalid' }]),
        search: { mode: 'outcome' }
      }]
    )

    assert_include suite.supported_versions, :r5
    assert_nil definitions.find { |definition| definition['code'] == 'basedOn' && definition.fetch('base', []).include?('QuestionnaireResponse') }
    assert_not_nil definitions.find { |definition| definition['code'] == 'based-on' && definition.fetch('base', []).include?('QuestionnaireResponse') }
    assert_instance_of FHIR::R5::Bundle, response
    assert_instance_of FHIR::R5::OperationOutcome, response.entry.first.resource
    assert_equal 'outcome', response.entry.first.search.mode
    assert_equal 'warning', response.entry.first.resource.issue.first.severity
  end

  def test_incendi_teardowns_target_r5_resource_classes
    client = DestroyRecorder.new
    consent_suite = Crucible::Tests::ConsentSearchByPatientReferenceTest.new(client)
    elements_suite = Crucible::Tests::ElementsSearchParameterTest.new(client)
    unknown_suite = Crucible::Tests::UnknownSearchParameterTest.new(client)
    consent_suite.instance_variable_set(:@patient_id, 'patient')
    consent_suite.instance_variable_set(:@consent_id, 'consent')
    elements_suite.instance_variable_set(:@patient_id, 'elements')
    unknown_suite.instance_variable_set(:@questionnaire_response_id, 'questionnaire-response')

    consent_suite.teardown
    elements_suite.teardown
    unknown_suite.teardown

    assert_equal [
      [FHIR::R5::Patient, 'patient'],
      [FHIR::R5::Consent, 'consent'],
      [FHIR::R5::Patient, 'elements'],
      [FHIR::R5::QuestionnaireResponse, 'questionnaire-response']
    ], client.destroyed
  end

  private

  def find_search_parameter(resource, code)
    FHIR::R5::Definitions.send(:search_params).find do |definition|
      definition['code'] == code && definition.fetch('base', []).include?(resource)
    end.tap { |definition| assert_not_nil definition, "Expected R5 #{resource} search parameter #{code}." }
  end

  class DestroyRecorder
    attr_reader :destroyed

    def initialize
      @destroyed = []
    end

    def fhir_version
      :r5
    end

    def monitor_requests
    end

    def destroy(resource_class, id)
      @destroyed << [resource_class, id]
    end
  end

  class SetupRecorder < DestroyRecorder
    Reply = Struct.new(:code, :id, :body)

    attr_reader :created

    def initialize
      super
      @created = []
    end

    def create(resource)
      @created << resource
      id = @created.length == 1 ? 'patient-from-create-response' : 'consent-from-create-response'
      resource.id = id
      Reply.new(201, id, '')
    end
  end
end
