require_relative '../test_helper'

class R5RecursiveGenerationTest < Test::Unit::TestCase
  AUDITED_DEPTHS = Crucible::Tests::R5ResourceGenerationAudit::DEFAULT_DEPTHS

  def setup
    @required_node_class = Class.new(FHIR::R5::Model)
    @required_node_class.include(FHIR::R5::Hashable)
    FHIR::R5.const_set(:Task6ERequiredNode, @required_node_class)
    @required_node_class.const_set(
      :METADATA,
      {
        'child' => {
          'path' => 'Task6ERequiredNode.child',
          'type' => 'Task6ERequiredNode',
          'min' => 1,
          'max' => 1
        }
      }.freeze
    )
    @required_node_class.class_eval { attr_accessor :child }
  end

  def teardown
    FHIR::R5.send(:remove_const, :Task6ERequiredNode) if
      FHIR::R5.const_defined?(:Task6ERequiredNode, false)
  end

  def test_direct_and_indirect_r5_recursion_terminates_at_every_audited_depth
    AUDITED_DEPTHS.each do |depth|
      questionnaire = generator.generate(FHIR::R5::Questionnaire, depth)
      characteristics = generator.generate(
        FHIR::R5::EvidenceVariable::Characteristic,
        depth
      )
      identifier = generator.generate(FHIR::R5::Identifier, depth)

      items = questionnaire_items(questionnaire.item)
      recursive_characteristics = combination_characteristics(characteristics)

      assert_not_empty items, "Questionnaire depth #{depth}"
      assert_operator items.length, :<=, depth + 1
      assert_operator recursive_characteristics.length, :<=, depth + 1
      assert_empty questionnaire.validate, "Questionnaire depth #{depth}"
      assert_empty characteristics.validate,
                   "EvidenceVariable::Characteristic depth #{depth}"
      assert_empty identifier.validate, "Identifier depth #{depth}"
    end
  end

  def test_required_recursive_descendants_and_references_are_populated
    AUDITED_DEPTHS.each do |depth|
      characteristic = generator.generate(
        FHIR::R5::EvidenceVariable::Characteristic,
        depth
      )
      schedule = generator.generate(FHIR::R5::Schedule, depth)

      combinations = combination_characteristics(characteristic).filter_map(
        &:definitionByCombination
      )

      assert_not_empty combinations, "Characteristic depth #{depth}"
      assert_true combinations.all? do |combination|
        combination.characteristic.to_a.length >= 1
      end
      assert_not_empty schedule.actor, "Schedule depth #{depth}"
      assert_true schedule.actor.all? do |reference|
        reference.is_a?(FHIR::R5::Reference)
      end
      assert_empty characteristic.validate, "Characteristic depth #{depth}"
      assert_empty schedule.validate, "Schedule depth #{depth}"
    end
  end

  def test_empty_r5_codeable_reference_gets_exactly_one_r5_value
    codeable_reference = generator.generate(FHIR::R5::CodeableReference)
    populated = [
      codeable_reference.concept,
      codeable_reference.reference
    ].compact

    assert_equal 1, populated.length
    assert_instance_of FHIR::R5::CodeableConcept,
                       codeable_reference.concept
    assert_nil codeable_reference.reference
    assert_r5_graph(codeable_reference)
  end

  def test_populated_r5_codeable_reference_is_preserved
    existing_reference = FHIR::R5::Reference.new(
      display: 'Existing R5 reference'
    )
    codeable_reference = FHIR::R5::CodeableReference.new(
      reference: existing_reference
    )

    generator.apply_invariants!(codeable_reference)

    assert_nil codeable_reference.concept
    assert_same existing_reference, codeable_reference.reference
    assert_r5_graph(codeable_reference)
  end

  def test_nested_generated_codeable_references_stay_in_r5
    AUDITED_DEPTHS.each do |depth|
      supply_request = generator.generate(FHIR::R5::SupplyRequest, depth)
      codeable_references = collect_models(supply_request).select do |model|
        model.is_a?(FHIR::R5::CodeableReference)
      end

      assert_not_empty codeable_references, "SupplyRequest depth #{depth}"
      codeable_references.each { |reference| assert_r5_graph(reference) }
      assert_empty supply_request.validate, "SupplyRequest depth #{depth}"
    end
  end

  def test_required_cycle_fails_with_the_complete_element_path
    error = assert_raise(generator::RequiredElementGenerationError) do
      generator.generate(@required_node_class)
    end
    expected_path = 'FHIR::R5::Task6ERequiredNode' +
                    ('.child' * (generator::EMBEDDED_LOOP_GUARD + 1))

    assert_include error.message, expected_path
    assert_include error.message, 'Task6ERequiredNode.child'
    assert_include error.message, 'minimum 1'
  end

  private

  def generator
    Crucible::Tests::ResourceGenerator
  end

  def questionnaire_items(items)
    items.to_a.flat_map do |item|
      [item] + questionnaire_items(item.item)
    end
  end

  def combination_characteristics(root)
    values = [root]
    root.definitionByCombination&.characteristic.to_a.each do |child|
      values.concat(combination_characteristics(child))
    end
    values
  end

  def collect_models(root)
    models = []
    generator.each_fhir_model(root) { |model| models << model }
    models
  end

  def assert_r5_graph(root)
    collect_models(root).each do |model|
      assert_true model.class.name.start_with?('FHIR::R5::'),
                  model.class.name
    end
  end
end
