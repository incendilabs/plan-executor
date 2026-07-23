require_relative '../test_helper'

class R4BRoutingTest < Test::Unit::TestCase
  def setup
    @client = FHIR::Client.new('http://r4b', fhir_version: :r4b)
    @suite = Crucible::Tests::BaseSuite.new(@client)
  end

  def test_client_extension_does_not_replace_r4b_selection
    assert_equal :r4b, @client.fhir_version
  end

  def test_base_test_uses_r4b_namespace
    assert_same FHIR::R4B, @suite.version_namespace
  end

  def test_base_suite_resolves_r4b_resources
    assert_same FHIR::R4B::Citation, Crucible::Tests::BaseSuite.get_resource(:r4b, :Citation)
    assert_true Crucible::Tests::BaseSuite.valid_resource?(:r4b, 'Citation')
    assert_false Crucible::Tests::BaseSuite.valid_resource?(:r4, 'Citation')
  end

  def test_base_suite_parses_r4b_resources
    patient = @suite.resource_from_contents(FHIR::R4B::Patient.new(id: 'r4b').to_json)
    outcome = @suite.parse_operation_outcome(
      FHIR::R4B::OperationOutcome.new(issue: [{ severity: 'error', code: 'invalid' }]).to_json
    )

    assert_instance_of FHIR::R4B::Patient, patient
    assert_instance_of FHIR::R4B::OperationOutcome, outcome
  end

  def test_r4b_resource_enumeration_stays_in_r4b_namespace
    resources = Crucible::Tests::BaseSuite.fhir_resources(:r4b)

    assert_not_empty resources
    assert_true resources.all? { |resource| resource.name.start_with?('FHIR::R4B::') }
  end

  def test_resource_generator_uses_r4b_types
    patient = Crucible::Tests::ResourceGenerator.generate(FHIR::R4B::Patient)

    assert_instance_of FHIR::R4B::Patient, patient
    assert_instance_of FHIR::R4B::Meta, patient.meta
  end

  def test_minimal_resource_helpers_require_an_explicit_namespace
    assert_raise(ArgumentError) do
      Crucible::Tests::ResourceGenerator.minimal_patient
    end
  end

  def test_minimal_patient_keeps_all_children_in_r4b_namespace
    patient = Crucible::Tests::ResourceGenerator.minimal_patient(namespace: FHIR::R4B)

    assert_instance_of FHIR::R4B::Patient, patient
    assert_instance_of FHIR::R4B::Identifier, patient.identifier.first
    assert_instance_of FHIR::R4B::HumanName, patient.name.first
    assert_instance_of FHIR::R4B::Meta, patient.meta
    assert_instance_of FHIR::R4B::Coding, patient.meta.tag.first
  end

  def test_minimal_condition_uses_r4b_status_datatype
    condition = Crucible::Tests::ResourceGenerator.minimal_condition(namespace: FHIR::R4B)

    assert_instance_of FHIR::R4B::Condition, condition
    assert_instance_of FHIR::R4B::CodeableConcept, condition.verificationStatus
    assert_instance_of FHIR::R4B::Coding, condition.verificationStatus.coding.first
    assert_equal 'confirmed', condition.verificationStatus.coding.first.code
  end

  def test_condition_status_conversion_preserves_each_version_namespace
    r4_condition = FHIR::Condition.new
    r4_condition.clinicalStatus = 'active'
    r4_condition.verificationStatus = 'confirmed'
    r4b_condition = FHIR::R4B::Condition.new
    r4b_condition.clinicalStatus = 'active'
    r4b_condition.verificationStatus = 'confirmed'
    stu3_condition = FHIR::STU3::Condition.new
    stu3_condition.clinicalStatus = 'active'
    stu3_condition.verificationStatus = 'confirmed'

    Crucible::Tests::ResourceGenerator.fix_condition(r4_condition)
    Crucible::Tests::ResourceGenerator.fix_condition(r4b_condition)
    Crucible::Tests::ResourceGenerator.fix_condition(stu3_condition)

    assert_instance_of FHIR::CodeableConcept, r4_condition.clinicalStatus
    assert_instance_of FHIR::CodeableConcept, r4_condition.verificationStatus
    assert_instance_of FHIR::R4B::CodeableConcept, r4b_condition.clinicalStatus
    assert_instance_of FHIR::R4B::CodeableConcept, r4b_condition.verificationStatus
    assert_equal 'active', stu3_condition.clinicalStatus
    assert_equal 'confirmed', stu3_condition.verificationStatus
  end

  def test_resource_fixture_helper_uses_r4b_namespace
    resources = Crucible::Generator::Resources.new(:r4b)

    assert_same FHIR::R4B, resources.instance_variable_get(:@namespace)
  end

  def test_resource_suite_metadata_advertises_r4b_support
    resource_test = Crucible::Tests::ResourceTest.new(nil)
    resource_suite_metadata = Crucible::Tests::SuiteEngine.list_all.values.select do |metadata|
      metadata.key?('resource_class')
    end
    advertises_r4b = resource_suite_metadata.any? do |metadata|
      metadata['supported_versions'].include?(:r4b)
    end

    assert_include resource_test.supported_versions, :r4b
    assert_true advertises_r4b
  end
end
