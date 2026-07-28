require_relative '../test_helper'

class R5TerminologyGenerationTest < Test::Unit::TestCase
  ITEM_TYPE_URI = 'http://hl7.org/fhir/ValueSet/item-type'.freeze
  LANGUAGE_URI = 'http://hl7.org/fhir/ValueSet/all-languages'.freeze
  BCP47_URI = 'http://tools.ietf.org/html/bcp47'.freeze

  def setup
    clear_generator_code_caches
  end

  def test_r5_required_bindings_generate_locally_selectable_codes
    item_codes = generator.selectable_valid_codes(
      FHIR::R5::Questionnaire::Item::METADATA.fetch('type'),
      'FHIR::R5'
    )
    language_codes = generator.selectable_valid_codes(
      FHIR::R5::Patient::Communication::METADATA.fetch('language'),
      'FHIR::R5'
    )

    assert_not_include item_codes.fetch('http://hl7.org/fhir/item-type'),
                       'question'
    assert_include item_codes.fetch('http://hl7.org/fhir/item-type'), 'string'
    assert_include language_codes.fetch('urn:ietf:bcp:47'), 'en'

    [
      FHIR::R5::Binary,
      FHIR::R5::Patient::Communication,
      FHIR::R5::SampledData
    ].each do |klass|
      resource = generator.generate(klass, 2)
      assert_empty resource.validate, "#{klass}: #{resource.validate}"
    end
  end

  def test_nested_abstract_and_inactive_expansion_entries_are_not_selectable
    entries = [
      {
        'system' => 'http://example.test/codes',
        'code' => 'selectable',
        'contains' => [
          { 'code' => 'nested-selectable' },
          { 'code' => 'nested-abstract', 'abstract' => true },
          { 'code' => 'nested-inactive', 'inactive' => true }
        ]
      },
      {
        'system' => 'http://example.test/codes',
        'code' => 'abstract',
        'abstract' => true
      },
      {
        'system' => 'http://example.test/codes',
        'code' => 'inactive',
        'inactive' => true
      }
    ]

    codes = generator.collect_selectable_expansion_codes(entries, {})

    assert_equal(
      {
        'http://example.test/codes' => %w[
          selectable
          nested-selectable
        ]
      },
      codes
    )
  end

  def test_versioned_and_unversioned_canonicals_resolve_the_same_expansion
    metadata = FHIR::R5::Questionnaire::Item::METADATA.fetch('type')
    versioned = metadata.deep_dup
    versioned.fetch('binding')['uri'] = "#{ITEM_TYPE_URI}|5.0.0"

    assert_equal(
      generator.selectable_valid_codes(metadata, 'FHIR::R5'),
      generator.selectable_valid_codes(versioned, 'FHIR::R5')
    )
  end

  def test_cache_results_are_isolated_by_namespace_canonical_and_field_subset
    r4b_codes = generator.selectable_valid_codes(
      required_binding(ITEM_TYPE_URI),
      'FHIR::R4B'
    )
    r5_codes = generator.selectable_valid_codes(
      required_binding(ITEM_TYPE_URI),
      'FHIR::R5'
    )
    string_only = generator.selectable_valid_codes(
      required_binding(
        "#{ITEM_TYPE_URI}|5.0.0",
        'http://hl7.org/fhir/item-type' => ['string']
      ),
      'FHIR::R5'
    )

    assert_include r4b_codes.fetch('http://hl7.org/fhir/item-type'), 'choice'
    assert_not_include r4b_codes.fetch('http://hl7.org/fhir/item-type'), 'coding'
    assert_include r5_codes.fetch('http://hl7.org/fhir/item-type'), 'coding'
    assert_not_include r5_codes.fetch('http://hl7.org/fhir/item-type'), 'choice'
    assert_equal(
      { 'http://hl7.org/fhir/item-type' => ['string'] },
      string_only
    )
  end

  def test_legacy_binding_fallbacks_and_mixed_system_keys_remain_supported
    dstu2_languages = generator.selectable_valid_codes(
      required_binding(BCP47_URI),
      'FHIR::DSTU2'
    )
    mixed_valid_codes = {
      nil => [],
      'http://example.test/codes' => ['selectable']
    }
    mixed_systems = generator.selectable_valid_codes(
      required_binding(
        'http://example.test/ValueSet/mixed-systems',
        mixed_valid_codes
      ),
      'FHIR::STU3'
    )

    assert_equal(
      { 'urn:ietf:bcp:47' => ['en-US'] },
      dstu2_languages
    )
    assert_equal mixed_valid_codes, mixed_systems
  end

  def test_optional_external_required_binding_without_codes_is_omitted
    resource = generator.generate(
      FHIR::R5::MolecularSequence::Relative,
      2
    )

    assert_not_nil resource.startingSequence
    assert_nil resource.startingSequence.chromosome
  end

  private

  def generator
    Crucible::Tests::ResourceGenerator
  end

  def clear_generator_code_caches
    %i[
      @selectable_expansion_codes_cache
      @selectable_valid_codes_cache
    ].each do |name|
      generator.remove_instance_variable(name) if
        generator.instance_variable_defined?(name)
    end
  end

  def required_binding(uri, valid_codes = nil)
    metadata = {
      'type' => 'code',
      'min' => 1,
      'max' => 1,
      'binding' => {
        'strength' => 'required',
        'uri' => uri
      }
    }
    metadata['valid_codes'] = valid_codes if valid_codes
    metadata
  end
end
