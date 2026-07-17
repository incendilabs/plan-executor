require_relative '../test_helper'

class FHIRStructureGeneratorTest < Test::Unit::TestCase
  def test_generates_resource_categories_from_structure_definitions
    structure = Crucible::FHIRStructureGenerator.generate(definitions, template)
    resources = structure.fetch('children').find { |child| child['name'] == 'RESOURCES' }
    evidence = resources.fetch('children').first.fetch('children').first

    assert_equal 'Evidence-Based Medicine', evidence['name']
    assert_equal ['citation', 'research definition'], evidence.fetch('children').map { |child| child['name'] }
  end

  def test_does_not_modify_the_template
    original = JSON.generate(template)

    Crucible::FHIRStructureGenerator.generate(definitions, template)

    assert_equal original, JSON.generate(template)
  end

  def test_rejects_uncategorized_resources_without_an_explicit_override
    uncategorized = definitions
    uncategorized['entry'].first['resource']['extension'] = []

    assert_raise(RuntimeError) do
      Crucible::FHIRStructureGenerator.generate(uncategorized, template)
    end
  end

  private

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
                { 'name' => 'Evidence-Based Medicine', 'children' => [{ 'name' => 'old resource' }] }
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
                'valueString' => 'Specialized.Evidence-Based Medicine'
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
