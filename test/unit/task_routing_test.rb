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

  def test_r5_execute_and_execute_all_construct_clients_without_enabling_suites
    execute_output = capture_stdout do
      invoke_task('crucible:execute', 'http://r5.example', 'r5', 'ResourceTest')
    end
    execute_all_output = capture_stdout do
      invoke_task('crucible:execute_all', 'http://r5.example', 'r5')
    end

    assert_match(/does not support fhir version r5/, execute_output)
    assert_match(/Execute ResourceTest completed/, execute_output)
    assert_match(/Execute All completed/, execute_all_output)
  end

  def test_r5_custom_execution_constructs_clients_without_enabling_suites
    execute_output = capture_stdout do
      invoke_task('crucible:execute_custom', 'ResourceTest', 'r5')
    end
    execute_all_output = capture_stdout do
      invoke_task('crucible:execute_all_custom', 'r5')
    end

    assert_match(/does not support fhir version r5/, execute_output)
    assert_match(/Execute Custom ResourceTest completed/, execute_output)
    assert_match(/Execute All Custom completed/, execute_all_output)
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

  def test_r5_is_known_but_no_suite_or_metadata_becomes_eligible
    suites = Crucible::Tests::SuiteEngine.new.tests
    listed_tests = Crucible::Tests::Executor.list_all
    generated_metadata = nil

    capture_stdout do
      generated_metadata = Crucible::Tests::SuiteEngine.generate_metadata(:r5)
    end

    assert_true suites.none? { |suite| eligible_for_fhir_version?(suite, :r5) }
    assert_true listed_tests.none? { |_name, test| eligible_for_fhir_version?(test, :r5) }
    assert_empty generated_metadata
  end

  def test_r5_listing_and_execution_both_exclude_unsupported_suites
    listing_output = capture_stdout do
      invoke_task('crucible:list_all', 'r5')
    end
    suite_listing_output = capture_stdout do
      invoke_task('crucible:list_suites', 'r5')
    end
    client = build_fhir_client('http://r5.example', :r5)
    execution_result = nil
    execution_output = capture_stdout do
      execution_result = execute_test(
        'http://r5.example',
        client,
        'ResourceTest'
      )
    end

    assert_no_match(/ResourceTest/, listing_output)
    assert_no_match(/ResourceTest/, suite_listing_output)
    assert_nil execution_result
    assert_match(/does not support fhir version r5/, execution_output)
  end

  def test_r5_metadata_task_rejects_an_unsupported_suite
    error = assert_raise(Crucible::FHIRVersion::UnsupportedVersionError) do
      invoke_task('crucible:metadata', 'ResourceTest', 'r5')
    end

    assert_match(/Test ResourceTest does not support fhir version r5/, error.message)
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
