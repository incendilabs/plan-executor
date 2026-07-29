require_relative '../test_helper'
require 'webmock/test_unit'

class R5FhirPathPatchSuiteTest < Test::Unit::TestCase
  BASE_URL = 'http://fhirpath-patch-suite.test/fhir'.freeze
  MEDICATION_REQUEST_ID = 'r5-medication-request'.freeze

  def setup
    @client = FHIR::Client.new(BASE_URL, fhir_version: :r5)
    @patch_requests = []
    @medication_request = r5_medication_request
    stub_create
    stub_read
    stub_patch
    stub_delete
  end

  def test_r5_patch_suite_uses_r5_parameters_and_rejects_stale_versions
    suite = Crucible::Tests::FhirPathPatchTest.new(@client)
    results = suite.execute.fetch('FhirPathPatchTest')

    assert_equal 6, results.length
    assert_equal 6, results.count { |result| result['status'] == 'pass' }, failure_summary(results)
    assert_equal 0, results.count { |result| result['status'] == 'skip' }, failure_summary(results)
    assert_empty suite.warnings
    assert_include suite.supported_versions, :r5
    assert_equal [
      FHIR::Formats::ResourceFormat::RESOURCE_JSON,
      FHIR::Formats::ResourceFormat::RESOURCE_XML
    ], @patch_requests.map { |request| request[:content_type] }

    @patch_requests.each do |request|
      assert_instance_of FHIR::R5::Parameters, request[:parameters]
      assert_r5_model_graph(request[:parameters])
      operation = request[:parameters].parameter.first
      assert_equal 'operation', operation.name
      assert_equal %w[type path value], operation.part.map(&:name)
      assert_equal 'replace', operation.part[0].valueCode
      assert_equal 'MedicationRequest.status', operation.part[1].valueString
      assert_equal 'completed', operation.part[2].valueString
    end
  end

  def test_r5_choice_patch_uses_unsuffixed_fhirpath_name_with_a_typed_value
    suite = Crucible::Tests::FhirPathPatchTest.new(@client)
    patchset = suite.patchset_resource('add', 'Observation', 'value', 'patched value')
    operation = patchset.parameter.first

    assert_instance_of FHIR::R5::Parameters, patchset
    assert_equal %w[type path value name], operation.part.map(&:name)
    assert_equal 'Observation', operation.part[1].valueString
    assert_equal 'patched value', operation.part[2].valueString
    assert_equal 'value', operation.part[3].valueString
    assert_round_trips_in_r5_json_and_xml(patchset)
  end

  def test_stale_version_patch_returns_an_r5_operation_outcome_without_updating_the_resource
    patchset = Crucible::Tests::FhirPathPatchTest.new(@client).patchset_resource(
      'replace', 'MedicationRequest.status', nil, 'active'
    )
    stale_response = FHIR::R5::OperationOutcome.new(
      issue: [{ severity: 'error', code: 'conflict' }]
    )
    stub_request(:patch, "#{BASE_URL}/MedicationRequest/#{MEDICATION_REQUEST_ID}").with(
      headers: { 'If-Match' => 'W/"1"' }
    ).to_return(
      status: 412,
      body: stale_response.to_json,
      headers: { 'Content-Type' => FHIR::Formats::ResourceFormat::RESOURCE_JSON }
    )

    reply = @client.fhir_patch(
      FHIR::R5::MedicationRequest,
      MEDICATION_REQUEST_ID,
      patchset,
      {},
      FHIR::Formats::ResourceFormat::RESOURCE_JSON,
      'If-Match' => 'W/"1"'
    )

    assert_equal 412, reply.code
    assert_instance_of FHIR::R5::OperationOutcome, reply.resource
    assert_equal 'active', @medication_request.status
  end

  private

  def r5_medication_request
    Crucible::Generator::Resources.new(:r5).medicationorder_simple
  end

  def stub_create
    stub_request(:post, "#{BASE_URL}/MedicationRequest").to_return do |request|
      created = FHIR::R5.from_contents(request.body)
      assert_instance_of FHIR::R5::MedicationRequest, created
      assert_r5_model_graph(created)
      @medication_request = created
      @medication_request.id = MEDICATION_REQUEST_ID
      @medication_request.meta = FHIR::R5::Meta.new(
        versionId: '1',
        lastUpdated: '2026-07-29T12:00:00Z'
      )

      response(@medication_request, request).tap do |reply|
        reply[:headers]['Location'] = "#{BASE_URL}/MedicationRequest/#{MEDICATION_REQUEST_ID}/_history/1"
      end
    end
  end

  def stub_read
    stub_request(:get, "#{BASE_URL}/MedicationRequest/#{MEDICATION_REQUEST_ID}").to_return do |request|
      response(@medication_request, request)
    end
  end

  def stub_patch
    stub_request(:patch, "#{BASE_URL}/MedicationRequest/#{MEDICATION_REQUEST_ID}").to_return do |request|
      if request.headers['If-Match']
        next stale_patch_response
      end

      parameters = parse_parameters(request)
      @patch_requests << { content_type: request.headers['Content-Type'].split(';').first, parameters: parameters }
      @medication_request.status = parameters.parameter.first.part[2].valueString
      @medication_request.meta.versionId = (@medication_request.meta.versionId.to_i + 1).to_s
      @medication_request.meta.lastUpdated = '2026-07-29T12:01:00Z'

      response(@medication_request, request)
    end
  end

  def stub_delete
    stub_request(:delete, "#{BASE_URL}/MedicationRequest/#{MEDICATION_REQUEST_ID}").to_return(status: 204)
  end

  def parse_parameters(request)
    if request.headers['Content-Type'].include?('xml')
      FHIR::R5::Xml.from_xml(request.body)
    else
      FHIR::R5::Json.from_json(request.body)
    end
  end

  def response(resource, request)
    xml = request.headers['Accept'].include?('xml')
    {
      status: 200,
      body: xml ? resource.to_xml : resource.to_json,
      headers: {
        'Content-Type' => xml ? FHIR::Formats::ResourceFormat::RESOURCE_XML :
                                FHIR::Formats::ResourceFormat::RESOURCE_JSON
      }
    }
  end

  def stale_patch_response
    outcome = FHIR::R5::OperationOutcome.new(issue: [{ severity: 'error', code: 'conflict' }])
    {
      status: 409,
      body: outcome.to_json,
      headers: { 'Content-Type' => FHIR::Formats::ResourceFormat::RESOURCE_JSON }
    }
  end

  def assert_round_trips_in_r5_json_and_xml(resource)
    json = FHIR::R5::Json.from_json(resource.to_json)
    xml = FHIR::R5::Xml.from_xml(resource.to_xml)

    assert_instance_of FHIR::R5::Parameters, json
    assert_instance_of FHIR::R5::Parameters, xml
    assert_r5_model_graph(json)
    assert_r5_model_graph(xml)
  end

  def assert_r5_model_graph(value, seen = {})
    return if value.nil? || seen[value.object_id]

    seen[value.object_id] = true
    if value.is_a?(FHIR::Model)
      assert_match(/\AFHIR::R5(?:::\w+)*\z/, value.class.name)
      value.instance_variables.each do |variable|
        assert_r5_model_graph(value.instance_variable_get(variable), seen)
      end
    elsif value.is_a?(Array)
      value.each { |entry| assert_r5_model_graph(entry, seen) }
    elsif value.is_a?(Hash)
      value.each_value { |entry| assert_r5_model_graph(entry, seen) }
    end
  end

  def failure_summary(results)
    results.reject { |result| %w[pass skip].include?(result['status']) }.map do |result|
      "#{result[:test_method]}: #{result['status']} #{result['message']}"
    end.join("\n")
  end
end
