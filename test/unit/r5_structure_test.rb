require_relative '../test_helper'
require 'rake'
require 'tmpdir'

load File.expand_path('../../lib/tasks/fhir_structure.rake', __dir__)

class R5StructureTest < Test::Unit::TestCase
  ROOT = File.expand_path('../..', __dir__).freeze
  ABSTRACT_RESOURCES = %w[
    Resource
    DomainResource
    CanonicalResource
    MetadataResource
  ].freeze
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
  EXPECTED_CATEGORIES = [
    'Foundation.Conformance',
    'Foundation.Terminology',
    'Foundation.Security',
    'Foundation.Documents',
    'Foundation.Other',
    'Base.Individuals',
    'Base.Entities',
    'Base.Workflow',
    'Base.Management',
    'Clinical.Summary',
    'Clinical.Diagnostics',
    'Clinical.Medications',
    'Clinical.Care Provision',
    'Clinical.Request & Response',
    'Financial.Support',
    'Financial.Billing',
    'Financial.Payment',
    'Financial.General',
    'Specialized.Public Health & Research',
    'Specialized.Definitional Artifacts',
    'Specialized.Evidence-Based Medicine',
    'Specialized.Quality Reporting & Testing',
    'Specialized.Medication Definition'
  ].freeze

  def setup
    @structure = Crucible::FHIRStructure.get(:r5)
    @resource_root = @structure.fetch('children').find { |child| child['name'] == 'RESOURCES' }
  end

  def test_index_contains_exactly_the_concrete_r5_model_resources
    expected = (FHIR::R5::RESOURCES - ABSTRACT_RESOURCES).map { |resource| normalize(resource) }

    assert_equal expected.sort, resource_names.map { |resource| normalize(resource) }.sort
  end

  def test_index_contains_158_resources_once_each
    assert_equal 158, resource_names.length
    assert_equal resource_names.length, resource_names.uniq.length
  end

  def test_index_contains_representative_r5_only_resources
    normalized_resources = resource_names.map { |resource| normalize(resource) }

    R5_ONLY_RESOURCES.each do |resource|
      assert_include normalized_resources, normalize(resource)
    end
  end

  def test_index_excludes_resources_removed_after_r4b
    normalized_resources = resource_names.map { |resource| normalize(resource) }

    REMOVED_R4B_RESOURCES.each do |resource|
      assert_not_include normalized_resources, normalize(resource)
    end
  end

  def test_index_contains_only_valid_decoded_categories
    assert_equal EXPECTED_CATEGORIES.sort, category_paths.sort
    assert_true categories.all? { |category| category.fetch('children').any? }
    assert_no_match(/&[a-zA-Z]+;/, JSON.generate(@structure))
    assert_include category_paths, 'Clinical.Request & Response'
    assert_include category_paths, 'Specialized.Public Health & Research'
    assert_include category_paths, 'Specialized.Quality Reporting & Testing'
  end

  def test_r5_generation_task_is_registered_and_requires_an_archive
    assert_true Rake::Task.task_defined?('crucible:generate_r5_structure')

    task = Rake::Task['crucible:generate_r5_structure']
    task.reenable
    error = assert_raise(RuntimeError) { task.invoke }

    assert_match(/crucible:generate_r5_structure/, error.message)
  end

  def test_pinned_archive_repeatedly_regenerates_the_checked_in_artifact
    archive_path = ENV.fetch(
      'R5_DEFINITIONS_ARCHIVE',
      File.join(ROOT, 'tmp', 'task-5c', 'r5-definitions.json.zip')
    )
    omit('Set R5_DEFINITIONS_ARCHIVE to the pinned R5 definitions archive') unless File.exist?(archive_path)

    Dir.mktmpdir('fhir-r5-structure') do |tmpdir|
      configuration = configuration_with_output(File.join(tmpdir, 'FHIR_structure_r5.json'))
      Crucible::FHIRStructureGenerator.write_from_archive(configuration, archive_path)
      first_generation = File.binread(configuration.output_path)
      Crucible::FHIRStructureGenerator.write_from_archive(configuration, archive_path)

      assert_equal File.binread(File.join(ROOT, 'lib', 'FHIR_structure_r5.json')), first_generation
      assert_equal first_generation, File.binread(configuration.output_path)
    end
  end

  private

  def resource_names
    categories.flat_map do |category|
      category.fetch('children').map { |resource| resource.fetch('name') }
    end
  end

  def categories
    @resource_root.fetch('children').flat_map { |section| section.fetch('children') }
  end

  def category_paths
    @resource_root.fetch('children').flat_map do |section|
      section.fetch('children').map do |category|
        "#{section.fetch('name')}.#{category.fetch('name')}"
      end
    end
  end

  def normalize(resource)
    resource.downcase.delete(' ')
  end

  def configuration_with_output(output_path)
    configuration = Crucible::FHIRStructureGenerator::CONFIGURATIONS.fetch(:r5)
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
end
