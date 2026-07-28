require_relative '../test_helper'

class FHIRStructureTest < Test::Unit::TestCase
  COMMITTED_STRUCTURE_VERSIONS = [:dstu2, :stu3, :r4, :r4b, :r5].freeze
  ABSTRACT_RESOURCES = %w[Resource DomainResource].freeze
  R5_ABSTRACT_RESOURCES = %w[Resource DomainResource CanonicalResource MetadataResource].freeze

  def test_fhir_starburst_root
    structure = Crucible::FHIRStructure.get(:r4)
    assert_equal 'FHIR', structure['name']
  end

  def test_fhir_starburst_root_r4b
    structure = Crucible::FHIRStructure.get(:r4b)
    assert_equal 'FHIR', structure['name']
  end

  def test_fhir_starburst_root_r5
    structure = Crucible::FHIRStructure.get(:r5)
    assert_equal 'FHIR', structure['name']
  end

  def test_fhir_starburst_stu3
    structure = Crucible::FHIRStructure.get(:stu3)
    assert_equal 'FHIR', structure['name']
  end

  def test_fhir_starburst_root_dstu2
    structure = Crucible::FHIRStructure.get(:dstu2)
    assert_equal 'FHIR', structure['name']
  end

  def test_no_duplicate_names_in_starburst
    COMMITTED_STRUCTURE_VERSIONS.each do |version|
      structure = Crucible::FHIRStructure.get(version)
      names = all_names(structure)

      assert names.uniq.length == names.length
    end
  end

  def fhir_resources(fhir_version)
    resources = Crucible::FHIRVersion.namespace(fhir_version).const_get(:RESOURCES)
    abstract_resources = fhir_version == :r5 ? R5_ABSTRACT_RESOURCES : ABSTRACT_RESOURCES
    resources.reject { |resource| abstract_resources.include?(resource) }
  end

  def test_no_missing_resources_in_starburst

    COMMITTED_STRUCTURE_VERSIONS.each do |version|
      structure = Crucible::FHIRStructure.get(version)
      resource_subset = structure['children'].select{|c| c['name'] == 'RESOURCES'}.first
      structure_resources = all_names(resource_subset, true).map{|e| e.downcase.delete(' ')}
      model_resources = fhir_resources(version).map(&:downcase)

      missing_resources = model_resources - structure_resources
      extra_resources = structure_resources - model_resources

      assert(missing_resources.length == 0, "Missing these resources from the FHIRStructure #{version.to_s}: #{missing_resources.join(', ')}")
      assert(extra_resources.length == 0, "Unknown resources in the FHIRStructure #{version.to_s}: #{extra_resources.join(', ')}")
    end

  end

  def test_no_unknown_requires_in_tests
    metadata = Crucible::Tests::SuiteEngine.list_all(true)
    requires_and_validates = metadata.map{|k,v| [v['validates'].map{|k2,v2| v2}, v['requires'].map{|k2,v2| v2}]}.flatten.reject(&:nil?)
    keys = requires_and_validates.map{|r| [r[:resource], r[:methods], r[:profiles], r[:extensions]]}.flatten.reject(&:nil?).uniq
    keys.map! {|k| k.downcase.delete(' ')}

    names = []

    COMMITTED_STRUCTURE_VERSIONS.each do |version|
      structure = Crucible::FHIRStructure.get(version)
      names.concat(all_names(structure).map{|e| e.downcase.delete(' ')})
    end

    extra_keys = keys - names

    assert(extra_keys.length == 0, "Unknown keys in requires and validates: #{extra_keys.join(', ')}")

  end

  private

  def all_names(hash, leaves_only = false)

    names = []
  
    names << hash['name'] if (hash['children'].nil? || !leaves_only)

    names << hash['children'].map {|child| all_names(child, leaves_only)} unless hash["children"].nil?

    names.flatten

  end

end
