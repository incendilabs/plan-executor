require_relative '../test_helper'

class R5SprinklerSearchSuiteTest < Test::Unit::TestCase
  def setup
    @client = FHIR::Client.new('http://r5-sprinkler-search-suite.test/fhir', fhir_version: :r5)
    @suite = Crucible::Tests::SprinklerSearchTest.new(@client)
  end

  def test_r5_resource_specific_and_generic_search_parameters_match_the_sprinkler_contract
    definitions = FHIR::R5::Definitions.send(:search_params)

    assert_search_parameter definitions, 'Patient', 'family', 'string'
    assert_search_parameter definitions, 'Patient', 'given', 'string'
    assert_search_parameter definitions, 'Patient', 'gender', 'token'
    assert_search_parameter definitions, 'Patient', 'identifier', 'token'
    assert_search_parameter definitions, 'Condition', 'patient', 'reference', ['Patient']
    assert_search_parameter definitions, 'Observation', 'code', 'token'
    assert_search_parameter definitions, 'Observation', 'value-quantity', 'quantity'
    assert_search_parameter definitions, 'Resource', '_id', 'token'
  end

  def test_r5_setup_patient_uses_the_r5_namespace
    patient = Crucible::Generator::Resources.new(:r5).minimal_patient

    assert_instance_of FHIR::R5::Patient, patient
    assert_include @suite.supported_versions, :r5
  end

  def test_exact_result_assertion_is_independent_of_bundle_order
    first = FHIR::R5::Patient.new(id: 'first')
    second = FHIR::R5::Patient.new(id: 'second')
    bundle = FHIR::R5::Bundle.new(
      type: 'searchset',
      total: 2,
      entry: [{ resource: second }, { resource: first }]
    )
    reply = Struct.new(:code, :resource, :body).new(200, bundle, bundle.to_json)

    @suite.assert_exact_result_ids(reply, %w[first second])
  end

  private

  def assert_search_parameter(definitions, resource, code, type, targets = nil)
    definition = definitions.find do |candidate|
      candidate['code'] == code && candidate.fetch('base', []).include?(resource)
    end

    assert_not_nil definition, "Expected R5 #{resource} search parameter #{code}."
    assert_equal type, definition['type']
    assert_equal targets, definition['target'] if targets
  end
end
