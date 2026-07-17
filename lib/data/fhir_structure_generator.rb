require 'cgi'
require 'digest'
require 'open3'

module Crucible
  class FHIRStructureGenerator
    DEFINITIONS_URL = 'https://www.hl7.org/fhir/R4B/definitions.json.zip'
    DEFINITIONS_SHA256 = 'a2793a06853c2d4540db8a72fc1c6d972528b01d113c2bb70ae2d80dc062e963'
    PROFILES_ENTRY = 'definitions.json/profiles-resources.json'
    CATEGORY_URL = 'http://hl7.org/fhir/StructureDefinition/structuredefinition-category'
    # These two base definitions omit the category extension in the official archive.
    CATEGORY_OVERRIDES = {
      'ResearchDefinition' => 'Specialized.Evidence-Based Medicine',
      'ResearchElementDefinition' => 'Specialized.Evidence-Based Medicine'
    }.freeze

    def self.from_archive(archive_path, template_path)
      checksum = Digest::SHA256.file(archive_path).hexdigest
      raise "Unexpected R4B definitions checksum: #{checksum}" unless checksum == DEFINITIONS_SHA256

      profiles_json, status = Open3.capture2('unzip', '-p', archive_path, PROFILES_ENTRY)
      raise "Unable to read #{PROFILES_ENTRY} from #{archive_path}" unless status.success?

      generate(JSON.parse(profiles_json), JSON.parse(File.read(template_path)))
    end

    def self.generate(structure_definitions, template)
      result = JSON.parse(JSON.generate(template))
      resource_root = result.fetch('children').find { |child| child['name'] == 'RESOURCES' }
      raise 'FHIR structure template has no RESOURCES branch' unless resource_root

      categories = reset_resource_categories(resource_root)
      concrete_resources(structure_definitions).each do |resource|
        category_path = resource_category(resource)
        category = categories[category_path] || add_category(resource_root, categories, category_path)
        category.fetch('children') << { 'name' => humanize(resource.fetch('name')) }
      end
      result
    end

    def self.write_from_archive(archive_path, template_path, output_path)
      structure = from_archive(archive_path, template_path)
      File.write(output_path, "#{JSON.pretty_generate(structure)}\n")
    end

    def self.reset_resource_categories(resource_root)
      resource_root.fetch('children').each_with_object({}) do |section, categories|
        section.fetch('children').each do |category|
          category['children'] = []
          categories["#{section.fetch('name')}.#{category.fetch('name')}"] = category
        end
      end
    end
    private_class_method :reset_resource_categories

    def self.concrete_resources(structure_definitions)
      structure_definitions.fetch('entry').map { |entry| entry.fetch('resource') }
        .select { |resource| resource['kind'] == 'resource' && resource['derivation'] == 'specialization' }
        .reject { |resource| resource['abstract'] == true }
    end
    private_class_method :concrete_resources

    def self.resource_category(resource)
      extension = resource.fetch('extension', []).find { |item| item['url'] == CATEGORY_URL }
      category = extension && extension['valueString']
      category ||= CATEGORY_OVERRIDES[resource.fetch('name')]
      raise "No R4B resource category for #{resource.fetch('name')}" unless category

      CGI.unescapeHTML(category)
    end
    private_class_method :resource_category

    def self.add_category(resource_root, categories, category_path)
      section_name, category_name = category_path.split('.', 2)
      raise "Invalid R4B resource category: #{category_path}" unless category_name

      section = resource_root.fetch('children').find { |child| child['name'] == section_name }
      unless section
        section = { 'name' => section_name, 'children' => [] }
        resource_root.fetch('children') << section
      end
      category = { 'name' => category_name, 'children' => [] }
      section.fetch('children') << category
      categories[category_path] = category
    end
    private_class_method :add_category

    def self.humanize(name)
      name.gsub(/([a-z\d])([A-Z])/, '\\1 \\2').downcase
    end
    private_class_method :humanize
  end
end
