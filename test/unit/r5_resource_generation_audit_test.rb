require_relative '../test_helper'
require 'tmpdir'

class R5ResourceGenerationAuditTest < Test::Unit::TestCase
  ABSTRACT_RESOURCES = Crucible::Tests::R5ResourceGenerationAudit::ABSTRACT_RESOURCES

  def setup
    @tmpdir = Dir.mktmpdir('r5-resource-generation-audit')
  end

  def teardown
    FileUtils.rm_rf(@tmpdir)
  end

  def test_cases_enumerate_every_concrete_resource_once_per_depth_and_iteration
    audit = build_audit(depths: [2, 3], iterations: 2)
    concrete_resources = (FHIR::R5::RESOURCES - ABSTRACT_RESOURCES).sort
    expected = concrete_resources.product([2, 3], [0, 1])
    actual = audit.cases.map do |audit_case|
      [audit_case.resource_name, audit_case.depth, audit_case.iteration]
    end

    assert_equal 158, concrete_resources.length
    assert_equal expected, actual
    assert_equal actual.length, actual.uniq.length
    assert_empty actual.map(&:first) & ABSTRACT_RESOURCES
  end

  def test_exceptions_and_validation_failures_write_actionable_diagnostics
    generator = lambda do |klass, _depth|
      raise ArgumentError, 'controlled generator failure' if klass == FHIR::R5::Patient

      FHIR::R5::Observation.new(
        status: 'not-a-real-status',
        code: FHIR::R5::CodeableConcept.new
      )
    end
    result = build_audit(
      resources: %w[Patient Observation],
      depths: [2],
      iterations: 1,
      generator: generator
    ).run

    assert_false result.success?
    assert_equal 2, result.failures.length

    patient_diagnostic = diagnostic_for('Patient')
    assert_equal 'ArgumentError', patient_diagnostic.fetch('exception').fetch('class')
    assert_equal 'controlled generator failure', patient_diagnostic.fetch('exception').fetch('message')
    assert_nil patient_diagnostic.fetch('serialized_fixture')

    observation_diagnostic = diagnostic_for('Observation')
    assert_not_empty observation_diagnostic.fetch('validation_errors')
    assert_nil observation_diagnostic.fetch('exception')
    assert_true File.exist?(observation_diagnostic.fetch('serialized_fixture'))
    assert_match(
      /crucible:audit_r5_resource_generation/,
      observation_diagnostic.fetch('replay_command')
    )
  end

  def test_namespace_contamination_and_empty_required_elements_fail_the_audit
    generator = lambda do |_klass, _depth|
      FHIR::R5::Bundle.new(
        type: '',
        entry: [
          FHIR::R5::Bundle::Entry.new(resource: FHIR::Patient.new)
        ]
      )
    end
    result = build_audit(
      resources: ['Bundle'],
      depths: [2],
      iterations: 1,
      generator: generator
    ).run
    failure = result.failures.fetch(0)

    assert_false result.success?
    assert_true failure.namespace_errors.any? do |error|
      error.fetch('actual_class') == 'FHIR::Patient'
    end
    assert_true failure.required_element_errors.any? do |error|
      error.fetch('path').end_with?('.type')
    end
  end

  def test_successful_cases_leave_no_error_artifacts
    result = build_audit(
      resources: ['Patient'],
      depths: [2],
      iterations: 2,
      generator: ->(_klass, _depth) { FHIR::R5::Patient.new }
    ).run

    assert_true result.success?
    assert_equal 2, result.audit_cases.length
    assert_empty result.failures
    assert_equal ['manifest.json'], Dir.children(@tmpdir)
    assert_empty Dir[File.join(@tmpdir, '*.diagnostic.json')]
    assert_empty Dir[File.join(@tmpdir, '*.fixture.json')]
    manifest = JSON.parse(File.read(result.manifest_path))
    assert_equal 2, manifest.fetch('case_count')
    assert_equal 0, manifest.fetch('failure_count')
  end

  def test_required_choice_is_checked_once_as_a_group
    generator = lambda do |_klass, _depth|
      FHIR::R5::Task.new(
        status: 'requested',
        intent: 'order',
        input: [
          FHIR::R5::Task::Input.new(
            type: FHIR::R5::CodeableConcept.new
          )
        ]
      )
    end
    result = build_audit(
      resources: ['Task'],
      depths: [2],
      iterations: 1,
      generator: generator
    ).run
    value_errors = result.failures.fetch(0).required_element_errors.select do |error|
      error.fetch('definition_path') == 'Input.value[x]'
    end

    assert_equal 1, value_errors.length
    assert_match(/value\[x\]\z/, value_errors.fetch(0).fetch('path'))
  end

  def test_case_seed_replays_random_and_datetime_values
    generated_values = []
    generator = lambda do |_klass, _depth|
      generated_values << [
        SecureRandom.base64,
        SecureRandom.uuid,
        SecureRandom.random_number(10_000),
        %w[a b c].sample,
        rand(10_000),
        DateTime.now.strftime('%Y-%m-%dT%H:%M:%S.%L%:z')
      ]
      FHIR::R5::Patient.new
    end

    first = build_audit(
      resources: ['Patient'],
      depths: [2],
      iterations: 1,
      seed: 1234,
      generator: generator
    )
    first.run
    second = build_audit(
      resources: ['Patient'],
      depths: [2],
      iterations: 1,
      seed: 1234,
      generator: generator
    )
    second.run

    assert_equal first.cases.map(&:seed), second.cases.map(&:seed)
    assert_equal generated_values.fetch(0), generated_values.fetch(1)
  end

  private

  def build_audit(**options)
    Crucible::Tests::R5ResourceGenerationAudit.new(
      output_dir: @tmpdir,
      **options
    )
  end

  def diagnostic_for(resource_name)
    path = Dir[File.join(@tmpdir, "r5-#{resource_name}-*.diagnostic.json")].fetch(0)
    JSON.parse(File.read(path))
  end
end
