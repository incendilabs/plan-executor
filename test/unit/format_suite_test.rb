require_relative '../test_helper'
require 'webmock/test_unit'

class FormatSuiteTest < Test::Unit::TestCase
  BASE_URL = 'http://format-suite.test/fhir'.freeze
  PATIENT_ID = 'format-suite-patient'.freeze
  FHIR_VERSIONS = {
    stu3: '3.0.2',
    r4: '4.0.1',
    r4b: '4.3.0'
  }.freeze

  FHIR_VERSIONS.each do |version, specification_version|
    define_method("test_format_suite_executes_all_cases_with_#{version}_resources") do
      execute_format_suite(version, specification_version)
    end
  end

  private

  def execute_format_suite(version, specification_version)
    @namespace = Crucible::FHIRVersion.namespace(version)
    @client = FHIR::Client.new(BASE_URL, fhir_version: version)
    @created_patient = nil
    stub_capability_statement(specification_version)
    stub_create
    stub_reads
    stub_delete

    suite = Crucible::Tests::FormatTest.new(@client)
    tests = suite.execute.fetch('Format001')

    assert_equal 22, tests.length
    assert_true tests.all? { |test| test['status'] == 'pass' }, failure_summary(tests)
    assert_instance_of @namespace.const_get(:Patient), @created_patient
    assert_include suite.supported_versions, version
  end

  def stub_capability_statement(specification_version)
    capability_statement = @namespace.const_get(:CapabilityStatement).new(
      status: 'active',
      date: '2026-07-17',
      kind: 'instance',
      fhirVersion: specification_version,
      format: ['xml', 'json']
    )

    stub_request(:get, "#{BASE_URL}/metadata").to_return(
      status: 200,
      body: capability_statement.to_json,
      headers: { 'Content-Type' => FHIR::Formats::ResourceFormat::RESOURCE_JSON }
    )
  end

  def stub_create
    stub_request(:post, "#{BASE_URL}/Patient").to_return do |request|
      @created_patient = @namespace.from_contents(request.body)
      @created_patient.id = PATIENT_ID
      @created_patient.meta ||= @namespace.const_get(:Meta).new
      @created_patient.meta.versionId = '1'
      @created_patient.meta.lastUpdated = '2026-07-17T12:00:00Z'

      {
        status: 201,
        body: @created_patient.to_json,
        headers: {
          'Content-Type' => FHIR::Formats::ResourceFormat::RESOURCE_JSON,
          'Location' => "#{BASE_URL}/Patient/#{PATIENT_ID}/_history/1"
        }
      }
    end
  end

  def stub_reads
    stub_request(:get, %r{\A#{Regexp.escape(BASE_URL)}/Patient(?:/#{PATIENT_ID})?(?:\?.*)?\z}).to_return do |request|
      requested_format = request_format(request)
      next { status: 406 } if requested_format.include?('application/foobar')

      resource = if request.uri.path.end_with?("/Patient/#{PATIENT_ID}")
                   @created_patient
                 else
                   search_bundle
                 end
      xml = requested_format.downcase.include?('xml')

      {
        status: 200,
        body: xml ? resource.to_xml : resource.to_json,
        headers: {
          'Content-Type' => xml ? FHIR::Formats::ResourceFormat::RESOURCE_XML :
                                  FHIR::Formats::ResourceFormat::RESOURCE_JSON
        }
      }
    end
  end

  def stub_delete
    stub_request(
      :delete,
      %r{\A#{Regexp.escape(BASE_URL)}/Patient/#{PATIENT_ID}(?:\?.*)?\z}
    ).to_return(status: 204)
  end

  def request_format(request)
    query_format = request.uri.query_values&.fetch('_format', nil)
    (query_format || request.headers['Accept'] || '').to_s
  end

  def search_bundle
    bundle_class = @namespace.const_get(:Bundle)
    bundle_class.new(
      type: 'searchset',
      total: 1,
      entry: [
        {
          'fullUrl' => "#{BASE_URL}/Patient/#{PATIENT_ID}",
          'resource' => @created_patient.to_hash
        }
      ]
    )
  end

  def failure_summary(tests)
    tests.reject { |test| test['status'] == 'pass' }.map do |test|
      "#{test[:test_method]}: #{test['status']} #{test['message']}"
    end.join("\n")
  end
end
