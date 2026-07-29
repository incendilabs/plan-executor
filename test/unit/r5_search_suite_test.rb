require_relative '../test_helper'
require 'webmock/test_unit'

class R5SearchSuiteTest < Test::Unit::TestCase
  BASE_URL = 'http://r5-search-suite.test/fhir'.freeze

  def setup
    @client = FHIR::Client.new(BASE_URL, fhir_version: :r5)
  end

  def test_search_test_uses_r5_definitions_for_advertised_parameter_names_and_types
    stub_capability_statement(search_param_type: 'string')
    stub_search_responses

    suite = Crucible::Tests::SearchTest.new(@client)
    results = suite.execute(FHIR::R5::Observation).fetch('SearchTest_Observation')

    assert_equal 7, results.length
    assert_true results.all? { |result| result['status'] == 'pass' }, failure_summary(results)
    assert_include suite.supported_versions, :r5
    assert_equal 'string', suite.r5_search_parameter_definitions.find { |definition|
      definition['code'] == 'value-markdown'
    }['type']
    assert_not_include FHIR::R4B::Definitions.search_parameters('Observation'), 'value-markdown'
  end

  def test_search_test_rejects_an_advertised_r5_parameter_with_the_wrong_type
    stub_capability_statement(search_param_type: 'token')
    stub_search_responses

    suite = Crucible::Tests::SearchTest.new(@client)
    result = suite.execute(FHIR::R5::Observation).fetch('SearchTest_Observation').first

    assert_equal 'fail', result['status']
    assert_match(/R5 defines it as string/, result['message'])
  end

  def test_search_test_accepts_r5_resource_parameters_and_the_summary_control_parameter
    stub_capability_statement(search_param_type: 'string', additional_search_params: [
      { name: '_id', type: 'token' },
      { name: '_lastUpdated', type: 'date' },
      { name: '_tag', type: 'token' },
      { name: '_profile', type: 'reference' },
      { name: '_security', type: 'token' },
      { name: '_summary', type: 'string' }
    ])
    stub_search_responses

    suite = Crucible::Tests::SearchTest.new(@client)
    result = suite.execute(FHIR::R5::Observation).fetch('SearchTest_Observation').first

    assert_equal 'pass', result['status']
  end

  def test_r5_search_parameter_definitions_cover_representative_types
    definitions = FHIR::R5::Definitions.send(:search_params)

    assert_search_parameter_type definitions, 'Patient', 'name', 'string'
    assert_search_parameter_type definitions, 'Patient', 'identifier', 'token'
    assert_search_parameter_type definitions, 'Observation', 'subject', 'reference'
    assert_search_parameter_type definitions, 'Patient', 'birthdate', 'date'
    assert_search_parameter_type definitions, 'RiskAssessment', 'probability', 'number'
    assert_search_parameter_type definitions, 'Observation', 'value-quantity', 'quantity'
  end

  def test_robust_search_setup_and_cleanup_stay_in_the_r5_namespace
    patient = FHIR::R5::Patient.new(id: 'r5-search-patient')
    stub_request(:post, "#{BASE_URL}/Patient").to_return(
      status: 201,
      body: patient.to_json,
      headers: { 'Content-Type' => FHIR::Formats::ResourceFormat::RESOURCE_JSON }
    )
    stub_request(:delete, "#{BASE_URL}/Patient/r5-search-patient").to_return(status: 204)

    suite = Crucible::Tests::RobustSearchTest.new(@client)
    results = suite.execute.fetch('Search002')

    assert_equal 1, results.length
    assert_equal 'skip', results.first['status']
    assert_match(/spark\/issues\/310/, results.first['message'])
    assert_instance_of FHIR::R5::Patient, suite.instance_variable_get(:@patient)
    assert_include suite.supported_versions, :r5
  end

  private

  def stub_capability_statement(search_param_type:, additional_search_params: [])
    capability_statement = FHIR::R5::CapabilityStatement.new(
      status: 'active',
      date: '2026-07-29',
      kind: 'instance',
      fhirVersion: '5.0.0',
      format: ['json'],
      rest: [
        {
          mode: 'server',
          resource: [
            {
              type: 'Observation',
              searchParam: [{ name: 'value-markdown', type: search_param_type }] + additional_search_params
            }
          ]
        }
      ]
    )

    stub_request(:get, "#{BASE_URL}/metadata").to_return(
      status: 200,
      body: capability_statement.to_json,
      headers: { 'Content-Type' => FHIR::Formats::ResourceFormat::RESOURCE_JSON }
    )
  end

  def stub_search_responses
    bundle = FHIR::R5::Bundle.new(type: 'searchset', total: 0, entry: [])
    stub_request(:any, %r{\A#{Regexp.escape(BASE_URL)}/Observation(?:/_search)?(?:\?.*)?\z}).to_return(
      status: 200,
      body: bundle.to_json,
      headers: { 'Content-Type' => FHIR::Formats::ResourceFormat::RESOURCE_JSON }
    )
  end

  def failure_summary(results)
    results.reject { |result| result['status'] == 'pass' }.map do |result|
      "#{result['id']}: #{result['status']} #{result['message']}"
    end.join("\n")
  end

  def assert_search_parameter_type(definitions, resource, code, expected_type)
    definition = definitions.find do |candidate|
      candidate['code'] == code && candidate.fetch('base', []).include?(resource)
    end

    assert_not_nil definition, "Expected R5 #{resource} search parameter #{code}."
    assert_equal expected_type, definition['type']
  end
end
