require_relative '../test_helper'

class ResourceGeneratorTest < Test::Unit::TestCase

  ERROR_DIR = File.join('tmp', 'errors', 'GeneratorTest')
  # Create a blank folder for the errors
  FileUtils.rm_rf(ERROR_DIR) if File.directory?(ERROR_DIR)
  FileUtils.mkdir_p ERROR_DIR

  # Define test methods for each resource type
  FHIR::RESOURCES.each do | resource_type |    
    3.times do |index|
      max_depth = index + 2
      define_method("test_resource_generator_r4_#{resource_type}_#{max_depth}") do
        run_generator(resource_type, :r4, max_depth )
      end
    end
  end

  # Also check to make sure that everything in the resource is within the STU3 namespace
  FHIR::STU3::RESOURCES.each do | resource_type |    
    3.times do |index|
      max_depth = index + 2
      define_method("test_resource_generator_stu3_#{resource_type}_#{max_depth}") do
        resource = run_generator(resource_type, :stu3, max_depth)
        assert check_valid_namespaces(resource, 'FHIR::STU3'), "Resource Generator created a class of type FHIR::STU3::#{resource_type} that contained elements from the wrong version."
      end
    end
  end

  # Also check to make sure that everything in the resource is within the DSTU2 namespace
  FHIR::DSTU2::RESOURCES.each do | resource_type |    
    3.times do |index|
      max_depth = index + 2
      define_method("test_resource_generator_dsut2_#{resource_type}_#{max_depth}") do
        resource = run_generator(resource_type, :dstu2, max_depth)
        assert check_valid_namespaces(resource, 'FHIR::DSTU2'), "Resource Generator created a class of type FHIR::DSTU2::#{resource_type} that contained elements from the wrong version."
      end
    end
  end

  def test_empty_r4b_codeable_reference_gets_a_concept
    reference = Crucible::Tests::ResourceGenerator.generate(FHIR::R4B::CodeableReference)

    assert_instance_of FHIR::R4B::CodeableConcept, reference.concept
    assert_not_empty reference.concept.text
    assert_nil reference.reference
  end

  def test_populated_r4b_codeable_reference_is_preserved
    reference = FHIR::R4B::CodeableReference.new
    reference.reference = FHIR::R4B::Reference.new(display: 'Existing reference')

    Crucible::Tests::ResourceGenerator.apply_invariants!(reference)

    assert_nil reference.concept
    assert_equal 'Existing reference', reference.reference.display
  end

  def test_r4b_packaged_product_definition_has_valid_contained_items
    resource = Crucible::Tests::ResourceGenerator.generate(FHIR::R4B::PackagedProductDefinition, 5)
    packages = [resource.package].compact
    contained_items = []

    until packages.empty?
      package = packages.shift
      contained_items.concat(package.containedItem || [])
      packages.concat(package.package || [])
    end

    assert_not_empty contained_items
    assert_true contained_items.all? do |contained_item|
      contained_item.item && (contained_item.item.concept || contained_item.item.reference)
    end
    assert_empty FHIR::R4B::Xml.validate(resource.to_xml).map(&:message)
  end

  def test_r4b_questionnaire_selectable_codes_exclude_abstract_question
    metadata = FHIR::R4B::Questionnaire::Item::METADATA['type']
    generated_codes = Crucible::Tests::ResourceGenerator.selectable_valid_codes(metadata, 'FHIR::R4B')

    assert_include metadata['valid_codes']['http://hl7.org/fhir/item-type'], 'question'
    assert_not_include generated_codes['http://hl7.org/fhir/item-type'], 'question'
    assert_include generated_codes['http://hl7.org/fhir/item-type'], 'string'
  end

  def test_selectable_code_cache_preserves_each_fields_metadata_subset
    generator = Crucible::Tests::ResourceGenerator
    generator.remove_instance_variable(:@selectable_expansion_codes_cache) if generator.instance_variable_defined?(:@selectable_expansion_codes_cache)
    metadata = FHIR::R4B::Questionnaire::Item::METADATA['type']
    generator.selectable_valid_codes(metadata, 'FHIR::R4B')
    subset_metadata = metadata.deep_dup
    subset_metadata['valid_codes'] = { 'http://hl7.org/fhir/item-type' => ['string'] }

    generated_codes = generator.selectable_valid_codes(subset_metadata, 'FHIR::R4B')

    assert_equal({ 'http://hl7.org/fhir/item-type' => ['string'] }, generated_codes)
  end

  def test_generated_r4b_questionnaire_items_use_selectable_types
    resource = Crucible::Tests::ResourceGenerator.generate(FHIR::R4B::Questionnaire, 5)
    items = questionnaire_items(resource.item)
    selectable_types = Crucible::Tests::ResourceGenerator.selectable_valid_codes(
      FHIR::R4B::Questionnaire::Item::METADATA['type'],
      'FHIR::R4B'
    ).values.flatten

    assert_not_empty items
    assert_true items.all? { |item| selectable_types.include?(item.type) }
  end

  def run_generator(resource_type, version, max_depth)

    klass_namespace = "FHIR"
    if version != :r4
      klass_namespace = "FHIR::#{version.to_s.upcase}"
    end
    klass = Module.const_get("#{klass_namespace}::#{resource_type}")
    
    r = Crucible::Tests::ResourceGenerator.generate(klass,max_depth)
    assert !r.nil?, "Resource Generator could not generate #{resource_type} with max depth #{max_depth}"
    errors = r.validate

    if !errors.empty?
      File.open("#{ERROR_DIR}/#{version}_#{resource_type}_#{max_depth}.err", 'w:UTF-8') do |file|
        file.write(JSON.pretty_generate(errors))
      end
      File.open("#{ERROR_DIR}/#{version}_#{resource_type}_#{max_depth}.json", 'w:UTF-8') { |file| file.write(r.to_json) }
    end

    assert errors.empty?, "Resource Generator could not generate valid #{resource_type} with max depth #{max_depth}"

    r
  end

  def check_valid_namespaces(resource, namespace)
    return resource.all? {|v| check_valid_namespaces(v, namespace)} if resource.class.name == 'Array'
    return true unless resource.class.name.start_with?("FHIR")
    return false unless resource.class.name.start_with?(namespace)
    return resource.instance_values.values.all? { |v| check_valid_namespaces(v, namespace) }
  end

  def questionnaire_items(items)
    items.to_a.flat_map { |item| [item] + questionnaire_items(item.item) }
  end

  def test_valid_oid_generator
    500.times do
      random_oid = Crucible::Tests::ResourceGenerator.random_oid
      assert /urn:oid:[0-2](\.[1-9]\d*)+/.match?(random_oid), "Randomly generated #{random_oid} does not appear to be a valid oid."
    end
  end

end
