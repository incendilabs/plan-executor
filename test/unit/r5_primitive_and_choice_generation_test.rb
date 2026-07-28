require_relative '../test_helper'

class R5PrimitiveAndChoiceGenerationTest < Test::Unit::TestCase
  INTEGER64_VALUES = [
    -9_223_372_036_854_775_808,
    -1,
    0,
    1,
    9_223_372_036_854_775_807
  ].freeze

  def test_integer64_boundaries_are_generated_as_integers
    generator = Crucible::Tests::ResourceGenerator
    offsets = INTEGER64_VALUES.map do |value|
      value - generator::INTEGER64_MIN
    end

    generated = offsets.map do |offset|
      random = Struct.new(:offset) do
        def random_number(limit)
          raise "offset #{offset} is outside 0...#{limit}" unless
            offset >= 0 && offset < limit

          offset
        end
      end.new(offset)
      generator.random_integer64(random: random)
    end

    assert_equal INTEGER64_VALUES, generated
    assert_true generated.all? { |value| value.is_a?(Integer) }
    assert_true generated.all? do |value|
      FHIR::R5.primitive?(datatype: 'integer64', value: value)
    end
  end

  def test_integer64_json_and_xml_round_trips_preserve_each_boundary
    INTEGER64_VALUES.each do |value|
      resource = integer64_parameters(value)

      assert_empty resource.validate

      json = resource.to_json
      json_value = JSON.parse(json).dig('parameter', 0, 'valueInteger64')
      assert_instance_of Integer, json_value
      assert_equal value, json_value
      assert_match(/"valueInteger64"\s*:\s*#{value}(?:\s*[,}])/, json)

      xml_value = FHIR::R5.from_contents(resource.to_xml)
                          .parameter
                          .first
                          .valueInteger64
      assert_instance_of Integer, xml_value
      assert_equal value, xml_value
    end
  end

  def test_r5_choice_candidates_follow_the_owning_element_metadata
    generator = Crucible::Tests::ResourceGenerator
    r4b_content = generator.selectable_multiple_type_fields(
      FHIR::R4B::Communication::Payload,
      'FHIR::R4B'
    ).fetch('content')
    r5_content = generator.selectable_multiple_type_fields(
      FHIR::R5::Communication::Payload,
      'FHIR::R5'
    ).fetch('content')
    r5_input = generator.selectable_multiple_type_fields(
      FHIR::R5::Task::Input,
      'FHIR::R5'
    ).fetch('value')

    assert_equal %w[Attachment Reference string], r4b_content.keys.sort
    assert_equal %w[Attachment CodeableConcept Reference], r5_content.keys.sort
    assert_not_include r5_content.keys, 'string'
    assert_include r5_input.keys, 'integer64'
    assert_equal 'valueInteger64', r5_input.fetch('integer64')
  end

  def test_generated_r5_choices_populate_exactly_one_allowed_property
    assertions = [
      [
        FHIR::R5::Communication::Payload,
        'content',
        'CodeableConcept'
      ],
      [
        FHIR::R5::Task::Input,
        'value',
        'integer64'
      ]
    ]

    assertions.each do |klass, prefix, selected_type|
      resource = klass.new
      selector = lambda do |types|
        types.include?(selected_type) ? selected_type : types.first
      end
      Crucible::Tests::ResourceGenerator.set_fields!(
        resource,
        'FHIR::R5',
        2,
        choice_selector: selector
      )
      fields = Crucible::Tests::ResourceGenerator
               .multiple_type_fields(klass)
               .fetch(prefix)
               .values
      populated = fields.select { |field| !resource.public_send(field).nil? }

      assert_equal ["#{prefix}#{selected_type[0].upcase}#{selected_type[1..]}"],
                   populated
      assert_empty resource.validate
    end
  end

  def test_quantity_choice_exclusion_remains_dstu2_only
    generator = Crucible::Tests::ResourceGenerator
    versions = {
      'FHIR' => FHIR::Observation,
      'FHIR::R4B' => FHIR::R4B::Observation,
      'FHIR::R5' => FHIR::R5::Observation,
      'FHIR::STU3' => FHIR::STU3::Observation
    }

    versions.each do |namespace, klass|
      choices = generator.selectable_multiple_type_fields(
        klass,
        namespace
      ).fetch('value')
      assert_include choices.keys, 'Quantity', namespace
    end

    dstu2_choices = generator.selectable_multiple_type_fields(
      FHIR::DSTU2::Observation,
      'FHIR::DSTU2'
    ).fetch('value')
    assert_not_include dstu2_choices.keys, 'Quantity'
  end

  private

  def integer64_parameters(value)
    FHIR::R5::Parameters.new(
      parameter: [
        FHIR::R5::Parameters::Parameter.new(
          name: 'integer64',
          valueInteger64: value
        )
      ]
    )
  end
end
