require_relative '../test_helper'

class R5RoutingTest < Test::Unit::TestCase
  def setup
    @client = FHIR::Client.new('http://r5', fhir_version: :r5)
    @suite = Crucible::Tests::BaseSuite.new(@client)
  end

  def test_base_test_and_base_suite_use_r5
    assert_equal :r5, @client.fhir_version
    assert_same FHIR::R5, @suite.version_namespace
    assert_same @client, FHIR::R5::Resource.new.client
  end

  def test_r5_resource_lookup_and_validation_are_explicit
    assert_same FHIR::R5::Patient, Crucible::Tests::BaseSuite.get_resource(:r5, :Patient)
    assert_true Crucible::Tests::BaseSuite.valid_resource?(:r5, 'Patient')
    assert_false Crucible::Tests::BaseSuite.valid_resource?(:r5, 'ResearchDefinition')

    patient = @suite.resource_from_contents(FHIR::R5::Patient.new(id: 'r5').to_json)

    assert_instance_of FHIR::R5::Patient, patient
    assert_empty patient.validate
  end

  def test_r5_resource_enumeration_contains_only_concrete_r5_classes
    resources = Crucible::Tests::BaseSuite.fhir_resources(:r5)

    assert_not_empty resources
    assert_true resources.all? { |resource| resource.name.start_with?('FHIR::R5::') }
    assert_not_include resources, FHIR::R5::CanonicalResource
    assert_not_include resources, FHIR::R5::MetadataResource
  end

  def test_r5_response_parsing_uses_r5_classes
    patient = @suite.resource_from_contents(FHIR::R5::Patient.new(id: 'r5').to_json)
    bundle = @suite.resource_from_contents(
      FHIR::R5::Bundle.new(type: 'collection', entry: [{ resource: patient }]).to_json
    )
    capability_statement = @suite.resource_from_contents(
      FHIR::R5::CapabilityStatement.new(
        status: 'active',
        date: '2026-07-28',
        kind: 'instance',
        fhirVersion: '5.0.0',
        format: ['json']
      ).to_json
    )
    operation_outcome = @suite.parse_operation_outcome(
      FHIR::R5::OperationOutcome.new(
        issue: [{ severity: 'error', code: 'invalid' }]
      ).to_json
    )

    assert_instance_of FHIR::R5::Patient, patient
    assert_instance_of FHIR::R5::Bundle, bundle
    assert_instance_of FHIR::R5::Patient, bundle.entry.first.resource
    assert_instance_of FHIR::R5::CapabilityStatement, capability_statement
    assert_instance_of FHIR::R5::OperationOutcome, operation_outcome
  end

  def test_generated_r5_patient_graph_has_no_r4_or_r4b_models
    patient = Crucible::Tests::ResourceGenerator.generate(FHIR::R5::Patient, 2)

    model_classes = assert_r5_model_graph(patient)

    assert_include model_classes, FHIR::R5::HumanName
    assert_include model_classes, FHIR::R5::Meta
  end

  def test_generated_r5_bundle_graph_has_no_r4_or_r4b_models
    bundle = Crucible::Tests::ResourceGenerator.generate(FHIR::R5::Bundle, 2)

    model_classes = assert_r5_model_graph(bundle)

    assert_include model_classes, FHIR::R5::Bundle::Entry
    assert_include model_classes, FHIR::R5::Meta
  end

  def test_condition_status_normalization_preserves_r5_types
    condition = FHIR::R5::Condition.new
    condition.clinicalStatus = 'active'
    condition.verificationStatus = 'confirmed'

    Crucible::Tests::ResourceGenerator.fix_condition(condition)

    assert_instance_of FHIR::R5::CodeableConcept, condition.clinicalStatus
    assert_instance_of FHIR::R5::CodeableConcept, condition.verificationStatus
    assert_instance_of FHIR::R5::Coding, condition.clinicalStatus.coding.first
    assert_instance_of FHIR::R5::Coding, condition.verificationStatus.coding.first
  end

  def test_r5_resource_ownership_selects_the_r5_structure
    r5_structure = Crucible::FHIRStructure.for_resource(FHIR::R5::ActorDefinition)
    r4b_structure = Crucible::FHIRStructure.for_resource(FHIR::R4B::Citation)

    assert_equal Crucible::FHIRStructure.get(:r5), r5_structure
    assert_equal r5_structure, Crucible::FHIRStructure.get('R5')
    assert_equal Crucible::FHIRStructure.get(:r4b), r4b_structure
    assert_equal 'Specialized', @suite.resource_category(FHIR::R5::ActorDefinition)
    assert_equal 'Specialized', @suite.resource_category(FHIR::R4B::Citation)
  end

  private

  def assert_r5_model_graph(resource)
    model_classes = collect_model_classes(resource)

    assert_not_empty model_classes
    assert_true model_classes.all? { |klass| klass.name.start_with?('FHIR::R5::') },
                "Non-R5 classes found: #{model_classes.reject { |klass| klass.name.start_with?('FHIR::R5::') }.uniq}"
    model_classes
  end

  def collect_model_classes(value, seen = {})
    return [] if value.nil?
    return value.flat_map { |item| collect_model_classes(item, seen) } if value.is_a?(Array)
    return value.values.flat_map { |item| collect_model_classes(item, seen) } if value.is_a?(Hash)
    return [] unless value.is_a?(FHIR::Model)
    return [] if seen[value.object_id]

    seen[value.object_id] = true
    [value.class] + value.instance_variables.flat_map do |variable|
      collect_model_classes(value.instance_variable_get(variable), seen)
    end
  end
end
