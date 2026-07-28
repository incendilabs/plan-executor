require 'digest'
require 'date'
require 'fileutils'
require 'json'
require 'securerandom'

module Crucible
  module Tests
    module DeterministicSecureRandom
      THREAD_KEY = :crucible_resource_generation_random

      def gen_random(length)
        random = Thread.current[THREAD_KEY]
        return super unless random

        random.bytes(length)
      end
    end

    SecureRandom.singleton_class.prepend(DeterministicSecureRandom) unless
      SecureRandom.singleton_class.ancestors.include?(DeterministicSecureRandom)

    module DeterministicDateTime
      THREAD_KEY = :crucible_resource_generation_datetime

      def now(*arguments)
        datetime = Thread.current[THREAD_KEY]
        return datetime if datetime

        super
      end
    end

    DateTime.singleton_class.prepend(DeterministicDateTime) unless
      DateTime.singleton_class.ancestors.include?(DeterministicDateTime)

    class R5ResourceGenerationAudit
      ABSTRACT_RESOURCES = %w[
        Resource
        DomainResource
        CanonicalResource
        MetadataResource
      ].freeze
      DEFAULT_DEPTHS = [2, 3, 4].freeze
      DEFAULT_ITERATIONS = 2
      DEFAULT_SEED = 20_260_728
      DEFAULT_OUTPUT_DIR = File.join(
        'tmp',
        'errors',
        'R5ResourceGenerationAudit'
      ).freeze
      RANDOM_MUTEX = Mutex.new

      Case = Struct.new(
        :resource_name,
        :depth,
        :iteration,
        :seed,
        keyword_init: true
      ) do
        def to_h
          {
            'resource' => resource_name,
            'depth' => depth,
            'iteration' => iteration,
            'seed' => seed
          }
        end
      end

      Failure = Struct.new(
        :audit_case,
        :exception,
        :validation_errors,
        :namespace_errors,
        :required_element_errors,
        :diagnostic_path,
        :fixture_path,
        keyword_init: true
      ) do
        def summary
          details = []
          details << "#{exception.fetch('class')}: #{exception.fetch('message')}" if exception
          details << "#{validation_errors.length} validation field(s)" unless validation_errors.empty?
          details << "#{namespace_errors.length} namespace error(s)" unless namespace_errors.empty?
          details << "#{required_element_errors.length} empty required element(s)" unless required_element_errors.empty?
          "#{audit_case.resource_name} depth=#{audit_case.depth} " \
            "iteration=#{audit_case.iteration} seed=#{audit_case.seed}: " \
            "#{details.join(', ')} (#{diagnostic_path})"
        end
      end

      Result = Struct.new(
        :audit_cases,
        :failures,
        :output_dir,
        :base_seed,
        :manifest_path,
        keyword_init: true
      ) do
        def success?
          failures.empty?
        end

        def summary
          "cases=#{audit_cases.length} failures=#{failures.length} " \
            "seed=#{base_seed} output=#{output_dir}"
        end
      end

      def initialize(
        resources: nil,
        depths: DEFAULT_DEPTHS,
        iterations: DEFAULT_ITERATIONS,
        iteration_indices: nil,
        seed: DEFAULT_SEED,
        output_dir: DEFAULT_OUTPUT_DIR,
        generator: ResourceGenerator.method(:generate)
      )
        @namespace = FHIR::R5
        @resources = Array(resources || concrete_resources).map(&:to_s).sort
        @depths = Array(depths).map { |depth| Integer(depth) }.sort
        @iterations = if iteration_indices
                        Array(iteration_indices).map { |iteration| Integer(iteration) }.sort
                      else
                        (0...Integer(iterations)).to_a
                      end
        @seed = Integer(seed)
        @output_dir = File.expand_path(output_dir)
        @generator = generator
      end

      attr_reader :output_dir, :seed

      def concrete_resources
        FHIR::R5::RESOURCES - ABSTRACT_RESOURCES
      end

      def cases
        @cases ||= @resources.flat_map do |resource_name|
          @depths.flat_map do |depth|
            @iterations.map do |iteration|
              Case.new(
                resource_name: resource_name,
                depth: depth,
                iteration: iteration,
                seed: seed_for(resource_name, depth, iteration)
              )
            end
          end
        end
      end

      def run
        FileUtils.rm_rf(output_dir)
        FileUtils.mkdir_p(output_dir)
        failures = []

        cases.each do |audit_case|
          failure = run_case(audit_case)
          failures << failure if failure
        end

        manifest_path = write_manifest(failures)
        Result.new(
          audit_cases: cases,
          failures: failures,
          output_dir: output_dir,
          base_seed: seed,
          manifest_path: manifest_path
        )
      end

      private

      def run_case(audit_case)
        resource = nil
        exception = nil
        validation_errors = {}
        namespace_errors = []
        required_element_errors = []

        begin
          with_seed(audit_case.seed) do
            klass = @namespace.const_get(audit_case.resource_name, false)
            resource = @generator.call(klass, audit_case.depth)
          end
          raise "Generator returned nil for #{audit_case.resource_name}" unless resource

          validation_errors = resource.validate
          namespace_errors = collect_namespace_errors(resource)
          required_element_errors = collect_required_element_errors(resource)
        rescue StandardError => error
          exception = exception_details(error)
        end

        return if exception.nil? &&
                  validation_errors.empty? &&
                  namespace_errors.empty? &&
                  required_element_errors.empty?

        write_failure(
          audit_case,
          resource,
          exception,
          validation_errors,
          namespace_errors,
          required_element_errors
        )
      end

      def write_failure(
        audit_case,
        resource,
        exception,
        validation_errors,
        namespace_errors,
        required_element_errors
      )
        stem = artifact_stem(audit_case)
        diagnostic_path = File.join(output_dir, "#{stem}.diagnostic.json")
        fixture_path, fixture_exception = write_fixture(stem, resource)
        diagnostic = {
          'fhir_version' => 'r5',
          'base_seed' => seed,
          'case' => audit_case.to_h,
          'exception' => exception,
          'validation_errors' => validation_errors,
          'namespace_errors' => namespace_errors,
          'required_element_errors' => required_element_errors,
          'serialized_fixture' => fixture_path,
          'fixture_exception' => fixture_exception,
          'replay_command' => replay_command(audit_case)
        }
        File.write(diagnostic_path, JSON.pretty_generate(diagnostic))

        Failure.new(
          audit_case: audit_case,
          exception: exception,
          validation_errors: validation_errors,
          namespace_errors: namespace_errors,
          required_element_errors: required_element_errors,
          diagnostic_path: diagnostic_path,
          fixture_path: fixture_path
        )
      end

      def write_fixture(stem, resource)
        return [nil, nil] unless resource

        fixture_path = File.join(output_dir, "#{stem}.fixture.json")
        File.write(fixture_path, resource.to_json)
        [fixture_path, nil]
      rescue StandardError => error
        [nil, exception_details(error)]
      end

      def collect_namespace_errors(resource)
        errors = []
        each_model(resource) do |model, path|
          next if model.class.name.start_with?("#{@namespace.name}::")

          errors << {
            'path' => path,
            'expected_namespace' => @namespace.name,
            'actual_class' => model.class.name
          }
        end
        errors
      end

      def collect_required_element_errors(resource)
        errors = []
        each_model(resource) do |model, path|
          choice_fields = collect_required_choice_errors(model, path, errors)
          model.class::METADATA.each do |field, metadata|
            next if choice_fields.include?(field)

            definitions = metadata.is_a?(Array) ? metadata : [metadata]
            definitions.each do |definition|
              next unless definition.fetch('min', 0).positive?

              local_name = definition['local_name'] || field
              value = model.instance_variable_get("@#{local_name}")
              next unless required_value_empty?(value, definition.fetch('min'))

              errors << {
                'path' => "#{path}.#{local_name}",
                'definition_path' => definition['path'],
                'minimum' => definition.fetch('min'),
                'value' => value
              }
            end
          end
        end
        errors
      end

      def collect_required_choice_errors(model, path, errors)
        multiple_types = if model.class.const_defined?(:MULTIPLE_TYPES)
                           model.class.const_get(:MULTIPLE_TYPES)
                         else
                           {}
                         end
        choice_fields = []

        multiple_types.each do |prefix, suffixes|
          fields = suffixes.map { |suffix| choice_field_name(prefix, suffix) }
          choice_fields.concat(fields)
          definitions = fields.flat_map do |field|
            metadata = model.class::METADATA[field]
            metadata.is_a?(Array) ? metadata : [metadata].compact
          end
          next unless definitions.any? { |definition| definition.fetch('min', 0).positive? }

          selected_fields = fields.select do |field|
            choice_value_present?(model.instance_variable_get("@#{field}"))
          end
          selected_field = selected_fields.first
          selected_value = model.instance_variable_get("@#{selected_field}") if selected_field
          next if selected_field && !required_value_empty?(selected_value, 1)

          definition = definitions.find { |candidate| candidate.fetch('min', 0).positive? }
          errors << {
            'path' => selected_field ? "#{path}.#{selected_field}" : "#{path}.#{prefix}[x]",
            'definition_path' => definition['path'],
            'minimum' => definition.fetch('min'),
            'value' => selected_value
          }
        end

        choice_fields
      end

      def choice_field_name(prefix, suffix)
        "#{prefix}#{suffix[0].upcase}#{suffix[1..-1]}"
      end

      def choice_value_present?(value)
        return false if value.nil?
        return !value.empty? if value.is_a?(Array)

        true
      end

      def each_model(value, path = nil, seen = {}, &block)
        if value.is_a?(Array)
          value.each_with_index do |entry, index|
            each_model(entry, "#{path}[#{index}]", seen, &block)
          end
          return
        end
        if value.is_a?(Hash)
          value.each do |key, entry|
            each_model(entry, "#{path}.#{key}", seen, &block)
          end
          return
        end
        return unless value.is_a?(FHIR::Model)
        return if seen[value.object_id]

        seen[value.object_id] = true
        model_path = path || value.class.name
        yield value, model_path
        value.instance_variables.each do |variable|
          field = variable.to_s.delete_prefix('@')
          each_model(
            value.instance_variable_get(variable),
            "#{model_path}.#{field}",
            seen,
            &block
          )
        end
      end

      def required_value_empty?(value, minimum)
        return true if value.nil?
        return value.length < minimum if value.is_a?(Array)
        return value.empty? if value.respond_to?(:empty?)

        false
      end

      def exception_details(error)
        {
          'class' => error.class.name,
          'message' => error.message,
          'backtrace' => Array(error.backtrace).first(20)
        }
      end

      def artifact_stem(audit_case)
        [
          'r5',
          audit_case.resource_name,
          "depth-#{audit_case.depth}",
          "iteration-#{audit_case.iteration}",
          "seed-#{audit_case.seed}"
        ].join('-')
      end

      def write_manifest(failures)
        manifest_path = File.join(output_dir, 'manifest.json')
        manifest = {
          'fhir_version' => 'r5',
          'base_seed' => seed,
          'case_count' => cases.length,
          'failure_count' => failures.length,
          'cases' => cases.map(&:to_h),
          'failure_diagnostics' => failures.map(&:diagnostic_path)
        }
        File.write(manifest_path, JSON.pretty_generate(manifest))
        manifest_path
      end

      def replay_command(audit_case)
        replay_output_dir = File.join(output_dir, 'replay')
        arguments = [
          replay_output_dir,
          seed,
          @iterations.length,
          audit_case.resource_name,
          audit_case.depth,
          audit_case.iteration
        ].join(',')
        "bundle exec rake \"crucible:audit_r5_resource_generation[#{arguments}]\""
      end

      def seed_for(resource_name, depth, iteration)
        material = [seed, resource_name, depth, iteration].join(':')
        Digest::SHA256.hexdigest(material).first(16).to_i(16)
      end

      def with_seed(case_seed)
        RANDOM_MUTEX.synchronize do
          previous_random = Thread.current[DeterministicSecureRandom::THREAD_KEY]
          previous_datetime = Thread.current[DeterministicDateTime::THREAD_KEY]
          Thread.current[DeterministicSecureRandom::THREAD_KEY] = Random.new(case_seed)
          Thread.current[DeterministicDateTime::THREAD_KEY] = datetime_for(case_seed)
          srand(case_seed)
          yield
        ensure
          Thread.current[DeterministicSecureRandom::THREAD_KEY] = previous_random
          Thread.current[DeterministicDateTime::THREAD_KEY] = previous_datetime
          srand
        end
      end

      def datetime_for(case_seed)
        epoch = DateTime.new(2020, 1, 1, 0, 0, 0, '+00:00')
        milliseconds = case_seed % (10 * 365 * 24 * 60 * 60 * 1_000)
        epoch + Rational(milliseconds, 24 * 60 * 60 * 1_000)
      end
    end
  end
end
