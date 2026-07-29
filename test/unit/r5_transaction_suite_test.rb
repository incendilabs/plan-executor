require_relative '../test_helper'
require 'webmock/test_unit'

class R5TransactionSuiteTest < Test::Unit::TestCase
  BASE_URL = 'http://transaction-suite.test/fhir'.freeze

  def setup
    @client = FHIR::Client.new(BASE_URL, fhir_version: :r5)
    @submitted_bundles = []
  end

  def test_transaction_preserves_r5_request_semantics_and_parses_response_bundle
    patient_reference = "urn:uuid:#{SecureRandom.uuid}"
    patient = Crucible::Tests::ResourceGenerator.minimal_patient('transaction-r5', 'Transaction', namespace: FHIR::R5)
    observation = Crucible::Tests::ResourceGenerator.minimal_observation(
      'http://loinc.org', '8302-2', 170, 'cm', nil, namespace: FHIR::R5
    )
    observation.subject = FHIR::R5::Reference.new(reference: patient_reference)
    condition = Crucible::Tests::ResourceGenerator.minimal_condition(
      'http://snomed.info/sct', '414915002', nil, namespace: FHIR::R5, patient_ref: patient_reference
    )
    stub_bundle_response(transaction_response_bundle)

    @client.begin_transaction
    @client.add_transaction_request('POST', nil, patient).fullUrl = patient_reference
    @client.add_transaction_request('POST', nil, observation).fullUrl = "urn:uuid:#{SecureRandom.uuid}"
    @client.add_transaction_request('POST', nil, patient, 'identifier=http://projectcrucible.org|transaction-r5')
    @client.add_transaction_request('PUT', 'Condition?subject=Patient/patient-r5&code=http://snomed.info/sct|414915002', condition)
    @client.add_transaction_request('DELETE', 'Observation/observation-r5')
    @client.add_transaction_request('GET', 'Observation?subject=Patient/patient-r5&code=http://loinc.org|8302-2')
    reply = @client.end_transaction

    submitted = @submitted_bundles.fetch(0)
    assert_equal 'transaction', submitted.type
    assert_equal 6, submitted.entry.length
    assert_equal patient_reference, submitted.entry[0].fullUrl
    assert_equal patient_reference, submitted.entry[1].resource.subject.reference
    assert_equal 'POST', submitted.entry[2].request.local_method
    assert_equal 'identifier=http://projectcrucible.org|transaction-r5', submitted.entry[2].request.ifNoneExist
    assert_equal 'PUT', submitted.entry[3].request.local_method
    assert_equal 'Condition?subject=Patient/patient-r5&code=http://snomed.info/sct|414915002', submitted.entry[3].request.url
    assert_equal 'DELETE', submitted.entry[4].request.local_method
    assert_equal 'GET', submitted.entry[5].request.local_method
    assert_equal 'Observation?subject=Patient/patient-r5&code=http://loinc.org|8302-2', submitted.entry[5].request.url

    assert_equal 200, reply.code
    assert_instance_of FHIR::R5::Bundle, reply.resource
    assert_equal 'transaction-response', reply.resource.type
    assert_instance_of FHIR::R5::Patient, reply.resource.entry.first.resource
    assert_instance_of FHIR::R5::Bundle, reply.resource.entry.last.resource
    assert_r5_model_graph(reply.resource)
  end

  def test_batch_preserves_r5_response_bundle_type_and_independent_results
    patient = Crucible::Tests::ResourceGenerator.minimal_patient('batch-r5', 'Batch', namespace: FHIR::R5)
    stub_bundle_response(batch_response_bundle)

    @client.begin_batch
    @client.add_batch_request('POST', nil, patient).fullUrl = "urn:uuid:#{SecureRandom.uuid}"
    @client.add_batch_request('GET', 'Patient?identifier=http://projectcrucible.org|batch-r5')
    reply = @client.end_batch

    submitted = @submitted_bundles.fetch(0)
    assert_equal 'batch', submitted.type
    assert_equal %w[POST GET], submitted.entry.map { |entry| entry.request.local_method }
    assert_equal 200, reply.code
    assert_instance_of FHIR::R5::Bundle, reply.resource
    assert_equal 'batch-response', reply.resource.type
    assert_equal '201 Created', reply.resource.entry.first.response.status
    assert_equal '400 Bad Request', reply.resource.entry.last.response.status
    assert_instance_of FHIR::R5::OperationOutcome, reply.resource.entry.last.resource
    assert_r5_model_graph(reply.resource)
  end

  def test_failed_transaction_parses_an_r5_operation_outcome
    stub_request(:post, system_endpoint).to_return(
      status: 400,
      body: FHIR::R5::OperationOutcome.new(issue: [{ severity: 'error', code: 'processing' }]).to_json,
      headers: { 'Content-Type' => FHIR::Formats::ResourceFormat::RESOURCE_JSON }
    )

    @client.begin_transaction
    @client.add_transaction_request('POST', nil, FHIR::R5::Patient.new)
    reply = @client.end_transaction

    assert_equal 400, reply.code
    assert_instance_of FHIR::R5::OperationOutcome, reply.resource
    assert_equal 'processing', reply.resource.issue.first.code
  end

  private

  def stub_bundle_response(bundle)
    stub_request(:post, system_endpoint).to_return do |request|
      @submitted_bundles << FHIR::R5.from_contents(request.body)
      {
        status: 200,
        body: bundle.to_json,
        headers: { 'Content-Type' => FHIR::Formats::ResourceFormat::RESOURCE_JSON }
      }
    end
  end

  def transaction_response_bundle
    FHIR::R5::Bundle.new(
      type: 'transaction-response',
      entry: [
        { response: { status: '201 Created', location: 'Patient/patient-r5/_history/1' }, resource: FHIR::R5::Patient.new(id: 'patient-r5') },
        { response: { status: '201 Created', location: 'Observation/observation-r5/_history/1' }, resource: FHIR::R5::Observation.new(id: 'observation-r5') },
        { response: { status: '200 OK', location: 'Patient/patient-r5/_history/1' }, resource: FHIR::R5::Patient.new(id: 'patient-r5') },
        { response: { status: '200 OK', location: 'Condition/condition-r5/_history/1' }, resource: FHIR::R5::Condition.new(id: 'condition-r5') },
        { response: { status: '204 No Content' } },
        {
          response: { status: '200 OK' },
          resource: FHIR::R5::Bundle.new(type: 'searchset', total: 0, entry: [])
        }
      ]
    )
  end

  def batch_response_bundle
    FHIR::R5::Bundle.new(
      type: 'batch-response',
      entry: [
        { response: { status: '201 Created', location: 'Patient/batch-r5/_history/1' }, resource: FHIR::R5::Patient.new(id: 'batch-r5') },
        {
          response: { status: '400 Bad Request' },
          resource: FHIR::R5::OperationOutcome.new(issue: [{ severity: 'error', code: 'invalid' }])
        }
      ]
    )
  end

  def system_endpoint
    %r{\A#{Regexp.escape(BASE_URL)}/?\z}
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
end
