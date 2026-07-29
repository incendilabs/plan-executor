require_relative '../test_helper'

class R5ResourceSuiteTest < Test::Unit::TestCase
  R5_ONLY_RESOURCES = %w[
    ActorDefinition
    ArtifactAssessment
    GenomicStudy
    Permission
    Requirements
    TestPlan
    Transport
  ].freeze
  REMOVED_R4B_RESOURCES = %w[
    CatalogEntry
    DeviceUseStatement
    DocumentManifest
    Media
    RequestGroup
    ResearchDefinition
    ResearchElementDefinition
  ].freeze

  def setup
    @client = FHIR::Client.new('http://r5.example', fhir_version: :r5)
    @suite = Crucible::Tests::ResourceTest.new(@client)
  end

  def test_resource_test_expands_to_every_crud_testable_r5_structure_resource
    expected = structure_resource_names.map(&:downcase) -
               Crucible::Tests::BaseSuite::EXCLUDED_RESOURCES.map(&:downcase)
    actual = @suite.fhir_resources.map { |resource| resource.name.demodulize.downcase }.sort

    assert_equal expected.sort, actual
    assert_equal 156, actual.length
    assert_true @suite.fhir_resources.all? { |resource| resource.name.start_with?('FHIR::R5::') }
  end

  def test_r5_only_resources_are_listed_and_removed_r4b_resources_are_not
    listed = Crucible::Tests::SuiteEngine.list_all
    r5_resource_tests = listed.select do |name, metadata|
      name.start_with?('ResourceTest') && metadata.fetch('supported_versions').include?(:r5)
    end.keys

    R5_ONLY_RESOURCES.each do |resource|
      assert_include r5_resource_tests, "ResourceTest#{resource}"
    end
    REMOVED_R4B_RESOURCES.each do |resource|
      assert_not_include r5_resource_tests, "ResourceTest#{resource}"
    end
  end

  def test_resource_test_generation_and_parsing_remain_in_the_r5_namespace
    @suite.fhir_resources.each do |resource_class|
      generated = Crucible::Tests::ResourceGenerator.generate(resource_class, 2)
      parsed = @suite.resource_from_contents(generated.to_json)

      assert_r5_graph(generated, resource_class.name)
      assert_r5_graph(parsed, "parsed #{resource_class.name}")
    end
  end

  private

  def structure_resource_names
    structure = Crucible::FHIRStructure.get(:r5)
    resource_root = structure.fetch('children').find { |child| child['name'] == 'RESOURCES' }

    resource_root.fetch('children').flat_map do |section|
      section.fetch('children').flat_map do |category|
        category.fetch('children').map { |resource| resource.fetch('name').delete(' ') }
      end
    end
  end

  def assert_r5_graph(value, description, seen = {})
    return if value.nil?
    return value.each { |entry| assert_r5_graph(entry, description, seen) } if value.is_a?(Array)
    return value.each_value { |entry| assert_r5_graph(entry, description, seen) } if value.is_a?(Hash)
    return unless value.is_a?(FHIR::Model)
    return if seen[value.object_id]

    seen[value.object_id] = true
    assert_true value.class.name.start_with?('FHIR::R5::'), "#{description} includes #{value.class}"

    value.class::METADATA.each do |field, metadata|
      local_name = metadata['local_name'] || field
      assert_r5_graph(value.instance_variable_get("@#{local_name}"), description, seen)
    end
  end
end
