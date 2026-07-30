require_relative '../test_helper'
require 'rake'
require 'stringio'
require 'tmpdir'

unless Rake::Task.task_defined?('crucible:execute')
  load File.expand_path('../../lib/tasks/tasks.rake', __dir__)
end

class TaskRoutingTest < Test::Unit::TestCase
  TASK_ARGUMENTS = {
    'crucible:execute' => [:url, :fhir_version, :test, :resource, :output],
    'crucible:execute_all' => [:url, :fhir_version, :output],
    'crucible:execute_custom' => [:test, :fhir_version, :resource_type, :output],
    'crucible:execute_all_custom' => [:fhir_version, :output],
    'crucible:list_all' => [:fhir_version],
    'crucible:list_suites' => [:fhir_version],
    'crucible:metadata' => [:test, :fhir_version],
    'crucible:execute_w_requirements' => [:url, :fhir_version, :test, :resource, :html_summary]
  }.freeze

  def test_r5_resolves_and_constructs_an_r5_client
    assert_equal :r5, resolve_fhir_version('R5')

    client = build_fhir_client('http://r5.example', 'r5')

    assert_instance_of FHIR::Client, client
    assert_equal :r5, client.fhir_version
  end

  def test_versioned_tasks_expose_explicit_fhir_version_arguments
    TASK_ARGUMENTS.each do |task_name, arguments|
      assert_equal arguments, Rake::Task[task_name].arg_names
    end
  end

  def test_r5_task_clients_construct_and_audited_suites_are_eligible
    client = build_fhir_client('http://r5.example', 'r5')
    consent_test = Crucible::Tests::Executor.new(client).find_test('ConsentSearchByPatientReferenceTest')
    elements_test = Crucible::Tests::Executor.new(client).find_test('ElementsSearchParameterTest')
    patch_test = Crucible::Tests::Executor.new(client).find_test('FhirPathPatchTest')
    resource_test = Crucible::Tests::Executor.new(client).find_test('ResourceTest')
    robust_search_test = Crucible::Tests::Executor.new(client).find_test('RobustSearchTest')
    search_test = Crucible::Tests::Executor.new(client).find_test('SearchTest')
    sprinkler_search_test = Crucible::Tests::Executor.new(client).find_test('SprinklerSearchTest')
    transaction_test = Crucible::Tests::Executor.new(client).find_test('TransactionAndBatchTest')
    unknown_search_parameter_test = Crucible::Tests::Executor.new(client).find_test('UnknownSearchParameterTest')

    assert_equal :r5, client.fhir_version
    assert_true eligible_for_fhir_version?(consent_test, :r5)
    assert_true eligible_for_fhir_version?(elements_test, :r5)
    assert_true eligible_for_fhir_version?(patch_test, :r5)
    assert_true eligible_for_fhir_version?(resource_test, :r5)
    assert_true eligible_for_fhir_version?(robust_search_test, :r5)
    assert_true eligible_for_fhir_version?(search_test, :r5)
    assert_true eligible_for_fhir_version?(sprinkler_search_test, :r5)
    assert_true eligible_for_fhir_version?(transaction_test, :r5)
    assert_true eligible_for_fhir_version?(unknown_search_parameter_test, :r5)
  end

  def test_r5_custom_execution_rejects_a_non_r5_suite
    execute_output = capture_stdout do
      invoke_task('crucible:execute_custom', 'ConnectathonPatientTrackTest', 'r5')
    end

    assert_match(/does not support fhir version r5/, execute_output)
    assert_match(/Execute Custom ConnectathonPatientTrackTest completed/, execute_output)
  end

  def test_unknown_and_omitted_task_versions_fail_before_client_construction
    omitted = nil
    unknown = nil

    Dir.mktmpdir do |directory|
      Dir.chdir(directory) do
        omitted = assert_raise(Crucible::FHIRVersion::UnsupportedVersionError) do
          invoke_task('crucible:execute', 'http://r5.example')
        end
        unknown = assert_raise(Crucible::FHIRVersion::UnsupportedVersionError) do
          invoke_task('crucible:execute', 'http://r5.example', 'r6', 'ResourceTest')
        end
      end
    end

    omitted_listing = assert_raise(Crucible::FHIRVersion::UnsupportedVersionError) do
      invoke_task('crucible:list_all')
    end

    assert_match(/FHIR version is required/, omitted.message)
    assert_match(/Unsupported FHIR version 'r6'/, unknown.message)
    assert_match(/FHIR version is required/, omitted_listing.message)
  end

  def test_r5_eligibility_is_limited_to_audited_suites
    suites = Crucible::Tests::SuiteEngine.new.tests
    listed_tests = Crucible::Tests::Executor.list_all

    executable_suites = suites.select { |suite| eligible_for_fhir_version?(suite, :r5) }
                              .map(&:title)
                              .sort
    listed_suites = listed_tests.select do |_name, test|
      eligible_for_fhir_version?(test, :r5)
    end.keys.map do |name|
      if name.start_with?('ResourceTest')
        'ResourceTest'
      elsif name.start_with?('SearchTest')
        'SearchTest'
      else
        name
      end
    end.uniq.sort

    assert_equal %w[ConsentSearchByPatientReferenceTest ElementsSearchParameterTest FhirPathPatchTest FormatTest HistoryTest ReadTest ResourceTest RobustSearchTest SearchTest SprinklerSearchTest TransactionAndBatchTest UnknownSearchParameterTest], executable_suites
    assert_equal executable_suites, listed_suites
  end

  def test_r5_listing_includes_audited_suites_and_excludes_non_r5_suites
    listing_output = capture_stdout do
      invoke_task('crucible:list_all', 'r5')
    end
    suite_listing_output = capture_stdout do
      invoke_task('crucible:list_suites', 'r5')
    end
    assert_match(/ResourceTest/, listing_output)
    assert_match(/ResourceTest/, suite_listing_output)
    assert_match(/FormatTest/, listing_output)
    assert_match(/FormatTest/, suite_listing_output)
    assert_match(/FhirPathPatchTest/, listing_output)
    assert_match(/FhirPathPatchTest/, suite_listing_output)
    assert_match(/TransactionAndBatchTest/, listing_output)
    assert_match(/TransactionAndBatchTest/, suite_listing_output)
    assert_match(/RobustSearchTest/, listing_output)
    assert_match(/RobustSearchTest/, suite_listing_output)
    assert_match(/SearchTest/, listing_output)
    assert_match(/SearchTest/, suite_listing_output)
    assert_match(/SprinklerSearchTest/, listing_output)
    assert_match(/SprinklerSearchTest/, suite_listing_output)
    assert_match(/ConsentSearchByPatientReferenceTest/, listing_output)
    assert_match(/ConsentSearchByPatientReferenceTest/, suite_listing_output)
    assert_match(/ElementsSearchParameterTest/, listing_output)
    assert_match(/ElementsSearchParameterTest/, suite_listing_output)
    assert_match(/UnknownSearchParameterTest/, listing_output)
    assert_match(/UnknownSearchParameterTest/, suite_listing_output)
    assert_no_match(/ConnectathonPatientTrackTest/, listing_output)
    assert_no_match(/ConnectathonPatientTrackTest/, suite_listing_output)
  end

  def test_r5_metadata_task_rejects_a_non_r5_suite
    error = assert_raise(Crucible::FHIRVersion::UnsupportedVersionError) do
      invoke_task('crucible:metadata', 'ConnectathonPatientTrackTest', 'r5')
    end

    assert_match(/Test ConnectathonPatientTrackTest does not support fhir version r5/, error.message)
  end

  def test_testscript_tasks_remain_stu3_only
    error = nil

    Dir.mktmpdir do |directory|
      Dir.chdir(directory) do
        error = assert_raise(Crucible::FHIRVersion::UnsupportedVersionError) do
          invoke_task('crucible:execute_all_testscripts', 'http://r5.example', 'r5')
        end
      end
    end

    assert_equal 'FHIR TestScripts require STU3, got r5', error.message
  end

  private

  def invoke_task(name, *arguments)
    task = Rake::Task[name]
    task.reenable
    task.invoke(*arguments)
  ensure
    task&.reenable
  end

  def capture_stdout
    original_stdout = $stdout
    output = StringIO.new
    $stdout = output
    yield
    output.string
  ensure
    $stdout = original_stdout
  end
end
