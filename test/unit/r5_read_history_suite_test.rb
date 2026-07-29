require_relative '../test_helper'

class R5ReadHistorySuiteTest < Test::Unit::TestCase
  Reply = Struct.new(:code, :resource, :body, keyword_init: true)

  def setup
    @client = FHIR::Client.new('http://r5.example', fhir_version: :r5)
    @read_suite = Crucible::Tests::ReadTest.new(@client)
    @history_suite = Crucible::Tests::HistoryTest.new(@client)
  end

  def test_read_and_history_suites_explicitly_advertise_r5
    expected = [:dstu2, :stu3, :r4, :r4b, :r5]

    assert_equal expected, @read_suite.supported_versions
    assert_equal expected, @history_suite.supported_versions
  end

  def test_mocked_r5_read_vread_and_conditional_responses_parse_in_the_r5_namespace
    patient_json = FHIR::R5::Patient.new(id: 'patient-1').to_json

    read = @read_suite.resource_from_contents(patient_json)
    vread = @history_suite.resource_from_contents(patient_json)
    conditional_full = @read_suite.resource_from_contents(patient_json)
    conditional_not_modified = Reply.new(code: 304, resource: nil, body: '')

    assert_instance_of FHIR::R5::Patient, read
    assert_instance_of FHIR::R5::Patient, vread
    assert_instance_of FHIR::R5::Patient, conditional_full
    assert_nil conditional_not_modified.resource
  end

  def test_mocked_r5_delete_and_history_responses_parse_in_the_r5_namespace
    deleted = FHIR::R5::OperationOutcome.new(
      issue: [{ severity: 'information', code: 'deleted' }]
    )
    history_json = <<~JSON
      {
        "resourceType": "Bundle",
        "type": "history",
        "entry": [
          {
            "resource": { "resourceType": "Patient", "id": "patient-1" },
            "request": { "method": "POST", "url": "Patient" }
          },
          {
            "request": { "method": "DELETE", "url": "Patient/patient-1/_history/3" }
          }
        ]
      }
    JSON

    delete_response = @history_suite.resource_from_contents(deleted.to_json)
    history_response = @history_suite.resource_from_contents(history_json)

    assert_instance_of FHIR::R5::OperationOutcome, delete_response
    assert_instance_of FHIR::R5::Bundle, history_response
    assert_equal 1, @history_suite.deleted_entries(history_response.entry).length
    assert_equal 1, @history_suite.active_entries(history_response.entry).length
    assert_equal '3', @history_suite.deleted_history_version(history_response)
  end

  def test_r5_response_status_expectations_distinguish_not_found_and_gone
    @read_suite.assert_response_ok(Reply.new(code: 200, resource: FHIR::R5::Patient.new))
    @read_suite.assert_response_not_found(Reply.new(code: 404, resource: nil))
    @history_suite.assert_response_gone(Reply.new(code: 410, resource: nil))
  end
end
