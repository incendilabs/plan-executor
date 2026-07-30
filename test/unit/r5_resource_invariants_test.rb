require_relative '../test_helper'

class R5ResourceInvariantsTest < Test::Unit::TestCase
  REMOVED_R4B_RESOURCES = [
    :DeviceUseStatement,
    :RequestGroup
  ].freeze

  def test_ingredient_reference_strength_has_a_serializable_required_choice
    reference_strength =
      FHIR::R5::Ingredient::Substance::Strength::ReferenceStrength.new(
        substance: codeable_reference('Reference substance'),
        strengthRatio: FHIR::R5::Ratio.new
      )

    generator.apply_invariants!(reference_strength)

    assert_nil reference_strength.strengthRatio
    assert_nil reference_strength.strengthRatioRange
    assert_instance_of FHIR::R5::Quantity,
                       reference_strength.strengthQuantity
    assert_not_nil reference_strength.strengthQuantity.value

    resource = FHIR::R5::Ingredient.new(
      status: 'draft',
      role: concept('Active ingredient'),
      substance: FHIR::R5::Ingredient::Substance.new(
        code: codeable_reference('Ingredient'),
        strength: [
          FHIR::R5::Ingredient::Substance::Strength.new(
            referenceStrength: [reference_strength]
          )
        ]
      )
    )
    assert_r5_json_and_xml_valid(resource)
  end

  def test_medication_knowledge_environment_has_a_serializable_required_choice
    environment =
      FHIR::R5::MedicationKnowledge::StorageGuideline::EnvironmentalSetting.new(
        type: concept('Temperature'),
        valueRange: FHIR::R5::Range.new
      )

    generator.apply_invariants!(environment)

    assert_nil environment.valueRange
    assert_nil environment.valueCodeableConcept
    assert_instance_of FHIR::R5::Quantity, environment.valueQuantity
    assert_not_nil environment.valueQuantity.value

    resource = FHIR::R5::MedicationKnowledge.new(
      storageGuideline: [
        FHIR::R5::MedicationKnowledge::StorageGuideline.new(
          environmentalSetting: [environment]
        )
      ]
    )
    assert_r5_json_and_xml_valid(resource)
  end

  def test_service_request_parameter_has_a_serializable_required_choice
    parameter = FHIR::R5::ServiceRequest::OrderDetail::Parameter.new(
      code: concept('Device setting'),
      valueRatio: FHIR::R5::Ratio.new
    )

    generator.apply_invariants!(parameter)

    assert_nil parameter.valueQuantity
    assert_nil parameter.valueRatio
    assert_nil parameter.valueRange
    assert_nil parameter.valueCodeableConcept
    assert_nil parameter.valuePeriod
    assert_not_empty parameter.valueString

    resource = FHIR::R5::ServiceRequest.new(
      status: 'active',
      intent: 'order',
      subject: FHIR::R5::Reference.new(display: 'Patient'),
      orderDetail: [
        FHIR::R5::ServiceRequest::OrderDetail.new(parameter: [parameter])
      ]
    )
    assert_r5_json_and_xml_valid(resource)
  end

  def test_element_definition_example_has_a_serializable_required_choice
    example = FHIR::R5::ElementDefinition::Example.new(
      label: 'Example',
      valueQuantity: FHIR::R5::Quantity.new
    )

    generator.apply_invariants!(example)

    populated_choices = generator
                        .multiple_type_fields(example.class)
                        .fetch('value')
                        .values
                        .select { |field| !example.public_send(field).nil? }
    assert_equal ['valueString'], populated_choices
    assert_not_empty example.valueString

    resource = FHIR::R5::StructureDefinition.new(
      url: 'http://example.test/StructureDefinition/example',
      name: 'Example',
      status: 'draft',
      kind: 'resource',
      abstract: false,
      type: 'Patient',
      differential: FHIR::R5::StructureDefinition::Differential.new(
        element: [
          FHIR::R5::ElementDefinition.new(
            path: 'Patient',
            example: [example]
          )
        ]
      )
    )
    assert_r5_json_and_xml_valid(resource)
  end

  def test_sampled_data_uses_the_r5_numeric_sample_grammar
    sampled_data = FHIR::R5::SampledData.new(
      origin: FHIR::R5::Quantity.new(value: 0),
      intervalUnit: 's',
      dimensions: 1,
      data: 'not numeric sampled data'
    )

    generator.apply_invariants!(sampled_data)

    assert_equal '0', sampled_data.data

    resource = FHIR::R5::Observation.new(
      status: 'final',
      code: concept('Sampled observation'),
      valueSampledData: sampled_data
    )
    assert_r5_json_and_xml_valid(resource)
  end

  def test_usage_context_has_a_serializable_required_choice
    usage_context = FHIR::R5::UsageContext.new(
      code: FHIR::R5::Coding.new(
        system: 'http://terminology.hl7.org/CodeSystem/usage-context-type',
        code: 'workflow'
      ),
      valueRange: FHIR::R5::Range.new
    )

    generator.apply_invariants!(usage_context)

    assert_required_choice(
      usage_context,
      'value',
      'valueCodeableConcept'
    )
    resource = FHIR::R5::ActorDefinition.new(
      status: 'draft',
      type: 'system',
      useContext: [usage_context]
    )
    assert_r5_json_and_xml_valid(resource)
  end

  def test_populated_r5_required_choice_is_preserved
    existing_value = concept('Existing usage context')
    usage_context = FHIR::R5::UsageContext.new(
      code: FHIR::R5::Coding.new(code: 'workflow'),
      valueCodeableConcept: existing_value
    )

    generator.apply_invariants!(usage_context)

    assert_same existing_value, usage_context.valueCodeableConcept
    assert_required_choice(
      usage_context,
      'value',
      'valueCodeableConcept'
    )
  end

  def test_biologically_derived_product_property_has_a_serializable_choice
    property = FHIR::R5::BiologicallyDerivedProduct::Property.new(
      type: concept('Collection property'),
      valueRatio: FHIR::R5::Ratio.new
    )

    generator.apply_invariants!(property)

    assert_required_choice(property, 'value', 'valueString')
    resource = FHIR::R5::BiologicallyDerivedProduct.new(
      property: [property]
    )
    assert_r5_json_and_xml_valid(resource)
  end

  def test_evidence_variable_definition_has_a_serializable_required_choice
    definition =
      FHIR::R5::EvidenceVariable::Characteristic::DefinitionByTypeAndValue.new(
        type: concept('Definition type'),
        valueReference: FHIR::R5::Reference.new
      )

    generator.apply_invariants!(definition)

    assert_required_choice(definition, 'value', 'valueId')
    resource = FHIR::R5::EvidenceVariable.new(
      status: 'draft',
      characteristic: [
        FHIR::R5::EvidenceVariable::Characteristic.new(
          definitionByTypeAndValue: definition
        )
      ]
    )
    assert_r5_json_and_xml_valid(resource)
  end

  def test_group_characteristic_has_a_serializable_required_choice
    characteristic = FHIR::R5::Group::Characteristic.new(
      code: concept('Group characteristic'),
      valueReference: FHIR::R5::Reference.new,
      exclude: false
    )

    generator.apply_invariants!(characteristic)

    assert_required_choice(characteristic, 'value', 'valueBoolean')
    assert_equal true, characteristic.valueBoolean
    resource = FHIR::R5::Group.new(
      type: 'person',
      membership: 'definitional',
      characteristic: [characteristic]
    )
    assert_r5_json_and_xml_valid(resource)
  end

  def test_measure_report_stratifier_component_has_a_serializable_required_choice
    component =
      FHIR::R5::MeasureReport::Group::Stratifier::Stratum::Component.new(
        code: concept('Measure stratifier'),
        valueRange: FHIR::R5::Range.new
      )

    generator.apply_invariants!(component)

    assert_required_choice(component, 'value', 'valueCodeableConcept')
    assert_not_empty component.valueCodeableConcept.text

    resource = FHIR::R5::MeasureReport.new(
      status: 'complete',
      type: 'individual',
      measure: 'http://example.test/Measure/example',
      period: FHIR::R5::Period.new(
        start: '2026-01-01T00:00:00Z',
        end: '2026-01-01T00:00:00Z'
      ),
      group: [
        FHIR::R5::MeasureReport::Group.new(
          stratifier: [
            FHIR::R5::MeasureReport::Group::Stratifier.new(
              stratum: [
                FHIR::R5::MeasureReport::Group::Stratifier::Stratum.new(
                  component: [component]
                )
              ]
            )
          ]
        )
      ]
    )
    assert_r5_json_and_xml_valid(resource)
  end

  def test_inventory_item_association_has_a_serializable_required_ratio
    association = FHIR::R5::InventoryItem::Association.new(
      associationType: concept('Package'),
      relatedItem: FHIR::R5::Reference.new(display: 'Inventory item'),
      quantity: FHIR::R5::Ratio.new
    )

    generator.apply_invariants!(association)

    assert_instance_of FHIR::R5::Quantity, association.quantity.numerator
    assert_instance_of FHIR::R5::Quantity, association.quantity.denominator
    assert_not_nil association.quantity.numerator.value
    assert_not_nil association.quantity.denominator.value
    resource = FHIR::R5::InventoryItem.new(
      status: 'active',
      code: [concept('Inventory item')],
      association: [association]
    )
    assert_r5_json_and_xml_valid(resource)
  end

  def test_r5_imaging_selection_2d_codes_are_compatible_with_the_official_xsd
    region = FHIR::R5::ImagingSelection::Instance::ImageRegion2D.new(
      regionType: 'circle',
      coordinate: [1.0, 2.0]
    )

    generator.apply_invariants!(region)

    assert_equal 'point', region.regionType
    resource = FHIR::R5::ImagingSelection.new(
      status: 'available',
      code: concept('Imaging selection'),
      instance: [
        FHIR::R5::ImagingSelection::Instance.new(
          uid: 'image-1',
          imageRegion2D: [region]
        )
      ]
    )
    assert_r5_json_and_xml_valid(resource)

    compatible_region =
      FHIR::R5::ImagingSelection::Instance::ImageRegion2D.new(
        regionType: 'polyline',
        coordinate: [1.0, 2.0]
      )
    generator.apply_invariants!(compatible_region)
    assert_equal 'polyline', compatible_region.regionType
  end

  def test_test_report_test_has_a_serializable_required_action
    test = FHIR::R5::TestReport::Test.new(
      action: [FHIR::R5::TestReport::Test::Action.new]
    )

    generator.apply_invariants!(test)

    assert_equal 1, test.action.length
    assert_instance_of FHIR::R5::TestReport::Setup::Action::Operation,
                       test.action.first.operation
    assert_equal 'pass', test.action.first.operation.result
    resource = FHIR::R5::TestReport.new(
      status: 'completed',
      testScript: 'http://example.test/TestScript/example',
      result: 'pass',
      test: [test]
    )
    assert_r5_json_and_xml_valid(resource)
  end

  def test_test_script_test_has_a_serializable_required_action
    test = FHIR::R5::TestScript::Test.new(
      action: [FHIR::R5::TestScript::Test::Action.new]
    )

    generator.apply_invariants!(test)

    assert_equal 1, test.action.length
    assert_instance_of FHIR::R5::TestScript::Setup::Action::Operation,
                       test.action.first.operation
    assert_equal true, test.action.first.operation.encodeRequestUrl
    resource = FHIR::R5::TestScript.new(
      name: 'GeneratedTestScript',
      status: 'draft',
      test: [test]
    )
    assert_r5_json_and_xml_valid(resource)
  end

  def test_r5_replacements_do_not_resolve_removed_r4b_constants
    install_removed_resource_sentinels

    resources = [
      FHIR::R5::RequestOrchestration.new(status: 'active', intent: 'order'),
      FHIR::R5::DeviceUsage.new(
        status: 'active',
        patient: FHIR::R5::Reference.new(display: 'Patient'),
        device: codeable_reference('Device')
      )
    ]
    resources.each do |resource|
      generator.apply_invariants!(resource)
      assert_r5_json_and_xml_valid(resource)
    end
  ensure
    remove_removed_resource_sentinels
  end

  def test_representative_r5_only_resource_stays_in_the_r5_namespace
    resource = generator.generate(FHIR::R5::ActorDefinition, 3)

    assert_r5_graph(resource)
    assert_instance_of FHIR::R5::ActorDefinition,
                       FHIR::R5::Json.from_json(resource.to_json)
  end

  private

  def generator
    Crucible::Tests::ResourceGenerator
  end

  def concept(text)
    FHIR::R5::CodeableConcept.new(text: text)
  end

  def codeable_reference(text)
    FHIR::R5::CodeableReference.new(concept: concept(text))
  end

  def assert_r5_json_and_xml_valid(resource)
    assert_empty resource.validate, resource.class.name

    json_resource = FHIR::R5::Json.from_json(resource.to_json)
    assert_instance_of resource.class, json_resource
    assert_empty json_resource.validate, "#{resource.class.name} JSON"
    assert_r5_graph(json_resource)

    xml = resource.to_xml
    assert_empty FHIR::R5::Xml.validate(xml).map(&:message),
                 "#{resource.class.name} XML schema"
    xml_resource = FHIR::R5::Xml.from_xml(xml)
    assert_instance_of resource.class, xml_resource
    assert_empty xml_resource.validate, "#{resource.class.name} XML"
    assert_r5_graph(xml_resource)
  end

  def assert_required_choice(resource, prefix, expected_field)
    populated_choices = generator
                        .multiple_type_fields(resource.class)
                        .fetch(prefix)
                        .values
                        .select do |field|
      !resource.public_send(field).nil?
    end
    assert_equal [expected_field], populated_choices
    value = resource.public_send(expected_field)
    assert_false(value.respond_to?(:empty?) && value.empty?)
  end

  def assert_r5_graph(root)
    generator.each_fhir_model(root) do |model|
      assert_true model.class.name.start_with?('FHIR::R5::'),
                  model.class.name
    end
  end

  def install_removed_resource_sentinels
    REMOVED_R4B_RESOURCES.each do |name|
      sentinel = Class.new
      sentinel.define_singleton_method(:===) do |_resource|
        raise "R5 dispatch resolved removed R4B resource #{name}"
      end
      FHIR::R5.const_set(name, sentinel)
    end
  end

  def remove_removed_resource_sentinels
    REMOVED_R4B_RESOURCES.each do |name|
      FHIR::R5.send(:remove_const, name) if
        FHIR::R5.const_defined?(name, false)
    end
  end
end
