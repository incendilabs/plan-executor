require_relative '../test_helper'

class ObservationGenerationTest < Test::Unit::TestCase
  VERSIONS = {
    r4: FHIR,
    r4b: FHIR::R4B
  }.freeze
  SHARED_SIMPLE_QUANTITY_VERSIONS = VERSIONS.merge(r5: FHIR::R5).freeze
  DEPTHS = [2, 3, 4].freeze
  ITERATIONS = 10

  def test_repeated_r4_and_r4b_observations_are_valid
    VERSIONS.each do |version, namespace|
      DEPTHS.each do |depth|
        ITERATIONS.times do |iteration|
          observation = Crucible::Tests::ResourceGenerator.generate(namespace::Observation, depth)
          errors = observation.validate

          assert_empty errors, failure_context(version, depth, iteration, errors)
          assert_prohibited_comparators_cleared(observation, version, depth, iteration)
        end
      end
    end
  end

  def test_observation_simple_quantities_have_no_comparator_across_namespaces
    SHARED_SIMPLE_QUANTITY_VERSIONS.each do |version, namespace|
      observation = observation_with_prohibited_comparators(namespace)

      Crucible::Tests::ResourceGenerator.apply_invariants!(observation)

      prohibited_quantities(observation).each do |path, quantity|
        assert_nil quantity.comparator, "#{version} retained a comparator at #{path}"
      end
    end
  end

  def test_r4_and_r4b_observation_quantities_that_allow_comparators_are_unchanged
    VERSIONS.each do |version, namespace|
      observation = observation_with_allowed_comparators(namespace)
      expected = allowed_quantities(observation).map { |path, quantity| [path, quantity.comparator] }

      Crucible::Tests::ResourceGenerator.apply_invariants!(observation)

      actual = allowed_quantities(observation).map { |path, quantity| [path, quantity.comparator] }
      assert_equal expected, actual, "#{version} cleared an allowed Quantity comparator"
    end
  end

  private

  def observation_with_prohibited_comparators(namespace)
    observation = namespace::Observation.new
    observation.valueRange = range(namespace)
    observation.valueSampledData = sampled_data(namespace)
    observation.referenceRange = [reference_range(namespace)]
    observation.component = [namespace::Observation::Component.new(
      valueRange: range(namespace),
      valueSampledData: sampled_data(namespace),
      referenceRange: [reference_range(namespace)]
    )]
    observation
  end

  def observation_with_allowed_comparators(namespace)
    observation = namespace::Observation.new
    observation.valueQuantity = quantity(namespace, '<')
    observation.valueRatio = ratio(namespace, '>', '<=')
    observation.component = [namespace::Observation::Component.new(
      valueQuantity: quantity(namespace, '>='),
      valueRatio: ratio(namespace, '<=', '>')
    )]
    observation
  end

  def reference_range(namespace)
    namespace::Observation::ReferenceRange.new(
      low: quantity(namespace),
      high: quantity(namespace),
      age: range(namespace)
    )
  end

  def range(namespace)
    namespace::Range.new(
      low: quantity(namespace),
      high: quantity(namespace)
    )
  end

  def sampled_data(namespace)
    namespace::SampledData.new(origin: quantity(namespace))
  end

  def ratio(namespace, numerator_comparator, denominator_comparator)
    namespace::Ratio.new(
      numerator: quantity(namespace, numerator_comparator),
      denominator: quantity(namespace, denominator_comparator)
    )
  end

  def quantity(namespace, comparator = '<')
    namespace::Quantity.new(value: 1, comparator: comparator)
  end

  def assert_prohibited_comparators_cleared(observation, version, depth, iteration)
    prohibited_quantities(observation).each do |path, quantity|
      assert_nil quantity.comparator,
                 "#{version} depth #{depth} iteration #{iteration} retained a comparator at #{path}"
    end
  end

  def prohibited_quantities(observation)
    quantities = []
    add_range_quantities(quantities, 'valueRange', observation.valueRange)
    add_sampled_data_quantity(quantities, 'valueSampledData', observation.valueSampledData)
    add_reference_ranges(quantities, 'referenceRange', observation.referenceRange)

    observation.component.to_a.each_with_index do |component, index|
      prefix = "component[#{index}]"
      add_range_quantities(quantities, "#{prefix}.valueRange", component.valueRange)
      add_sampled_data_quantity(quantities, "#{prefix}.valueSampledData", component.valueSampledData)
      add_reference_ranges(quantities, "#{prefix}.referenceRange", component.referenceRange)
    end

    quantities
  end

  def allowed_quantities(observation)
    quantities = [
      ['valueQuantity', observation.valueQuantity],
      ['valueRatio.numerator', observation.valueRatio&.numerator],
      ['valueRatio.denominator', observation.valueRatio&.denominator]
    ]
    observation.component.to_a.each_with_index do |component, index|
      quantities.concat(
        [
          ["component[#{index}].valueQuantity", component.valueQuantity],
          ["component[#{index}].valueRatio.numerator", component.valueRatio&.numerator],
          ["component[#{index}].valueRatio.denominator", component.valueRatio&.denominator]
        ]
      )
    end
    quantities.reject { |_path, quantity| quantity.nil? }
  end

  def add_reference_ranges(quantities, prefix, ranges)
    ranges.to_a.each_with_index do |reference_range, index|
      range_prefix = "#{prefix}[#{index}]"
      quantities << ["#{range_prefix}.low", reference_range.low] if reference_range.low
      quantities << ["#{range_prefix}.high", reference_range.high] if reference_range.high
      add_range_quantities(quantities, "#{range_prefix}.age", reference_range.age)
    end
  end

  def add_range_quantities(quantities, prefix, range)
    return unless range

    quantities << ["#{prefix}.low", range.low] if range.low
    quantities << ["#{prefix}.high", range.high] if range.high
  end

  def add_sampled_data_quantity(quantities, prefix, sampled_data)
    quantities << ["#{prefix}.origin", sampled_data.origin] if sampled_data&.origin
  end

  def failure_context(version, depth, iteration, errors)
    "#{version} depth #{depth} iteration #{iteration}: #{JSON.generate(errors)}"
  end
end
