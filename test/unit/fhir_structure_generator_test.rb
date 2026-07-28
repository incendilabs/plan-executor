require_relative '../test_helper'
require 'fileutils'
require 'tmpdir'

class FHIRStructureGeneratorTest < Test::Unit::TestCase
  ROOT = File.expand_path('../..', __dir__).freeze
  FIXTURE_ROOT = File.join(ROOT, 'test', 'fixtures', 'fhir_structure_generator').freeze
  R4B_FIXTURE = File.join(FIXTURE_ROOT, 'r4b-definitions.zip').freeze
  R5_FIXTURE = File.join(FIXTURE_ROOT, 'r5-definitions.zip').freeze
  R4B_FIXTURE_SHA256 = '06e07c0fca9d1b566868ce0deda6c883d40d3bc49f69e59bc6f44bb2edc54c58'.freeze
  R5_FIXTURE_SHA256 = 'eabbde6f4c1e83c54ed7f958a2b7a48acfe21d7aa1f79d66262006bd8637dbc4'.freeze

  def setup
    @tmpdir = Dir.mktmpdir('fhir-structure-generator')
    @template_path = File.join(@tmpdir, 'template.json')
    File.write(@template_path, JSON.pretty_generate(template))
  end

  def teardown
    FileUtils.remove_entry(@tmpdir)
  end

  def test_r4b_configuration_is_complete_and_immutable
    configuration = Crucible::FHIRStructureGenerator::CONFIGURATIONS.fetch(:r4b)

    assert_equal :r4b, configuration.version
    assert_equal 'R4B', configuration.label
    assert_equal 'https://www.hl7.org/fhir/R4B/definitions.json.zip', configuration.source_url
    assert_equal 'a2793a06853c2d4540db8a72fc1c6d972528b01d113c2bb70ae2d80dc062e963',
                 configuration.sha256
    assert_equal 'definitions.json/profiles-resources.json', configuration.archive_entry
    assert_equal File.join(ROOT, 'lib', 'FHIR_structure_r4.json'), configuration.template_path
    assert_equal File.join(ROOT, 'lib', 'FHIR_structure_r4b.json'), configuration.output_path
    assert_predicate configuration, :frozen?
    assert_predicate configuration.category_overrides, :frozen?
    assert_predicate Crucible::FHIRStructureGenerator::CONFIGURATIONS, :frozen?
    assert_raise(FrozenError) do
      configuration.category_overrides['Citation'] = 'Specialized.Other'
    end
  end

  def test_reads_the_exact_nested_r4b_archive_entry
    structure = Crucible::FHIRStructureGenerator.from_archive(r4b_fixture_configuration, R4B_FIXTURE)

    assert_equal ['citation', 'research definition'], generated_resource_names(structure)
  end

  def test_reads_the_exact_zip_root_r5_archive_entry
    structure = Crucible::FHIRStructureGenerator.from_archive(r5_fixture_configuration, R5_FIXTURE)

    assert_equal ['account'], generated_resource_names(structure)
  end

  def test_rejects_an_incorrect_checksum_with_the_selected_version
    configuration = r5_fixture_configuration(sha256: '0' * 64)

    error = assert_raise(RuntimeError) do
      Crucible::FHIRStructureGenerator.from_archive(configuration, R5_FIXTURE)
    end

    assert_match(/Unexpected R5 definitions checksum/, error.message)
    assert_match(/expected #{'0' * 64}, got #{R5_FIXTURE_SHA256}/, error.message)
  end

  def test_rejects_a_missing_exact_entry_with_the_selected_version
    configuration = r4b_fixture_configuration(archive_entry: 'profiles/missing-resources.json')

    error = assert_raise(RuntimeError) do
      Crucible::FHIRStructureGenerator.from_archive(configuration, R4B_FIXTURE)
    end

    assert_match(/R4B archive entry profiles\/missing-resources.json/, error.message)
  end

  def test_rejects_a_malformed_category_with_the_selected_version
    malformed = definitions
    malformed['entry'].first['resource']['extension'].first['valueString'] = 'Specialized'

    error = assert_raise(RuntimeError) do
      Crucible::FHIRStructureGenerator.generate(r5_fixture_configuration, malformed, template)
    end

    assert_match(/Invalid R5 resource category for Citation: Specialized/, error.message)
  end

  def test_rejects_a_missing_resource_category_with_the_selected_version
    uncategorized = definitions
    uncategorized['entry'].first['resource']['extension'] = []

    error = assert_raise(RuntimeError) do
      Crucible::FHIRStructureGenerator.generate(r5_fixture_configuration, uncategorized, template)
    end

    assert_match(/No R5 resource category for Citation/, error.message)
  end

  def test_generation_is_deterministic
    configuration = r4b_fixture_configuration

    Crucible::FHIRStructureGenerator.write_from_archive(configuration, R4B_FIXTURE)
    first_generation = File.binread(configuration.output_path)
    Crucible::FHIRStructureGenerator.write_from_archive(configuration, R4B_FIXTURE)

    assert_equal first_generation, File.binread(configuration.output_path)
  end

  def test_official_r4b_archive_regenerates_the_checked_in_artifact
    archive_path = ENV.fetch(
      'R4B_DEFINITIONS_ARCHIVE',
      File.join(ROOT, 'r4b-definitions.json.zip')
    )
    omit("Set R4B_DEFINITIONS_ARCHIVE to the pinned R4B definitions archive") unless File.exist?(archive_path)

    configuration = duplicate_configuration(
      Crucible::FHIRStructureGenerator::CONFIGURATIONS.fetch(:r4b),
      output_path: File.join(@tmpdir, 'FHIR_structure_r4b.json')
    )
    Crucible::FHIRStructureGenerator.write_from_archive(configuration, archive_path)

    assert_equal File.binread(File.join(ROOT, 'lib', 'FHIR_structure_r4b.json')),
                 File.binread(configuration.output_path)
  end

  def test_generates_resource_categories_from_structure_definitions
    structure = Crucible::FHIRStructureGenerator.generate(
      r4b_fixture_configuration,
      definitions,
      template
    )
    resources = structure.fetch('children').find { |child| child['name'] == 'RESOURCES' }
    evidence = resources.fetch('children').first.fetch('children').first

    assert_equal 'Evidence-Based & Medicine', evidence['name']
    assert_equal ['citation', 'research definition'], evidence.fetch('children').map { |child| child['name'] }
  end

  def test_does_not_modify_the_template
    original = JSON.generate(template)

    Crucible::FHIRStructureGenerator.generate(r4b_fixture_configuration, definitions, template)

    assert_equal original, JSON.generate(template)
  end

  private

  def r4b_fixture_configuration(**overrides)
    configuration(
      version: :r4b,
      label: 'R4B',
      sha256: R4B_FIXTURE_SHA256,
      archive_entry: 'definitions.json/profiles-resources.json',
      category_overrides: {
        'ResearchDefinition' => 'Specialized.Evidence-Based &amp; Medicine'
      },
      **overrides
    )
  end

  def r5_fixture_configuration(**overrides)
    configuration(
      version: :r5,
      label: 'R5',
      sha256: R5_FIXTURE_SHA256,
      archive_entry: 'profiles-resources.json',
      category_overrides: {},
      **overrides
    )
  end

  def configuration(version:, label:, sha256:, archive_entry:, category_overrides:, **overrides)
    attributes = {
      version: version,
      label: label,
      source_url: "https://example.test/fhir/#{label}/definitions.json.zip",
      sha256: sha256,
      archive_entry: archive_entry,
      category_overrides: category_overrides,
      template_path: @template_path,
      output_path: File.join(@tmpdir, "FHIR_structure_#{version}.json")
    }.merge(overrides)
    Crucible::FHIRStructureGenerator::Configuration.new(**attributes)
  end

  def duplicate_configuration(configuration, output_path:)
    Crucible::FHIRStructureGenerator::Configuration.new(
      version: configuration.version,
      label: configuration.label,
      source_url: configuration.source_url,
      sha256: configuration.sha256,
      archive_entry: configuration.archive_entry,
      category_overrides: configuration.category_overrides,
      template_path: configuration.template_path,
      output_path: output_path
    )
  end

  def generated_resource_names(structure)
    resources = structure.fetch('children').find { |child| child['name'] == 'RESOURCES' }
    resources.fetch('children').flat_map do |section|
      section.fetch('children').flat_map do |category|
        category.fetch('children').map { |resource| resource.fetch('name') }
      end
    end
  end

  def template
    {
      'name' => 'FHIR',
      'children' => [
        {
          'name' => 'RESOURCES',
          'children' => [
            {
              'name' => 'Specialized',
              'children' => [
                { 'name' => 'Evidence-Based & Medicine', 'children' => [{ 'name' => 'old resource' }] }
              ]
            }
          ]
        }
      ]
    }
  end

  def definitions
    {
      'entry' => [
        {
          'resource' => {
            'name' => 'Citation',
            'kind' => 'resource',
            'derivation' => 'specialization',
            'abstract' => false,
            'extension' => [
              {
                'url' => Crucible::FHIRStructureGenerator::CATEGORY_URL,
                'valueString' => 'Specialized.Evidence-Based &amp; Medicine'
              }
            ]
          }
        },
        {
          'resource' => {
            'name' => 'ResearchDefinition',
            'kind' => 'resource',
            'derivation' => 'specialization',
            'abstract' => false,
            'extension' => []
          }
        },
        {
          'resource' => {
            'name' => 'Resource',
            'kind' => 'resource',
            'derivation' => 'specialization',
            'abstract' => true,
            'extension' => []
          }
        }
      ]
    }
  end
end
