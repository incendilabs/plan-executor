require 'cgi'
require 'digest'
require 'json'
require 'open3'

module Crucible
  class FHIRStructureGenerator
    ROOT = File.expand_path('../..', __dir__).freeze
    CATEGORY_URL = 'http://hl7.org/fhir/StructureDefinition/structuredefinition-category'.freeze

    class Configuration
      attr_reader :version, :label, :source_url, :sha256, :archive_entry,
                  :category_overrides, :template_path, :output_path

      def initialize(version:, label:, source_url:, sha256:, archive_entry:,
                     category_overrides:, template_path:, output_path:)
        @version = version.to_sym
        @label = immutable_string(label)
        @source_url = immutable_string(source_url)
        @sha256 = immutable_string(sha256)
        @archive_entry = immutable_string(archive_entry)
        @category_overrides = category_overrides.each_with_object({}) do |(resource, category), overrides|
          overrides[immutable_string(resource)] = immutable_string(category)
        end.freeze
        @template_path = immutable_string(File.expand_path(template_path))
        @output_path = immutable_string(File.expand_path(output_path))
        freeze
      end

      private

      def immutable_string(value)
        value.to_s.dup.freeze
      end
    end

    R4B_CONFIGURATION = Configuration.new(
      version: :r4b,
      label: 'R4B',
      source_url: 'https://www.hl7.org/fhir/R4B/definitions.json.zip',
      sha256: 'a2793a06853c2d4540db8a72fc1c6d972528b01d113c2bb70ae2d80dc062e963',
      archive_entry: 'definitions.json/profiles-resources.json',
      category_overrides: {
        # These base definitions omit the category extension in the official archive.
        'ResearchDefinition' => 'Specialized.Evidence-Based Medicine',
        'ResearchElementDefinition' => 'Specialized.Evidence-Based Medicine'
      },
      template_path: File.join(ROOT, 'lib', 'FHIR_structure_r4.json'),
      output_path: File.join(ROOT, 'lib', 'FHIR_structure_r4b.json')
    )
    CONFIGURATIONS = { r4b: R4B_CONFIGURATION }.freeze

    def self.from_archive(configuration, archive_path)
      checksum = Digest::SHA256.file(archive_path).hexdigest
      unless checksum == configuration.sha256
        raise "Unexpected #{configuration.label} definitions checksum: " \
              "expected #{configuration.sha256}, got #{checksum}"
      end

      profiles_json = read_exact_archive_entry(configuration, archive_path)
      template = JSON.parse(File.read(configuration.template_path))
      generate(configuration, JSON.parse(profiles_json), template)
    end

    def self.generate(configuration, structure_definitions, template)
      result = JSON.parse(JSON.generate(template))
      resource_root = result.fetch('children').find { |child| child['name'] == 'RESOURCES' }
      raise 'FHIR structure template has no RESOURCES branch' unless resource_root

      categories = reset_resource_categories(resource_root)
      concrete_resources(structure_definitions).each do |resource|
        category_path = resource_category(configuration, resource)
        category = categories[category_path] ||
                   add_category(configuration, resource_root, categories, resource, category_path)
        category.fetch('children') << { 'name' => humanize(resource.fetch('name')) }
      end
      result
    end

    def self.write_from_archive(configuration, archive_path)
      structure = from_archive(configuration, archive_path)
      File.write(configuration.output_path, serialize(structure))
    end

    def self.read_exact_archive_entry(configuration, archive_path)
      entries, list_status = Open3.capture2e('unzip', '-Z1', archive_path)
      unless list_status.success?
        raise "Unable to list #{configuration.label} definitions archive #{archive_path}"
      end

      unless entries.lines(chomp: true).count(configuration.archive_entry) == 1
        raise "Unable to read #{configuration.label} archive entry " \
              "#{configuration.archive_entry} from #{archive_path}"
      end

      contents, extract_status = Open3.capture2e(
        'unzip',
        '-p',
        archive_path,
        configuration.archive_entry
      )
      unless extract_status.success?
        raise "Unable to read #{configuration.label} archive entry " \
              "#{configuration.archive_entry} from #{archive_path}"
      end

      contents
    end
    private_class_method :read_exact_archive_entry

    def self.serialize(structure)
      json = JSON.pretty_generate(structure)
      json = json.gsub(/^(\s*)"children": \[\]$/) do
        indentation = Regexp.last_match(1)
        "#{indentation}\"children\": [\n\n#{indentation}]"
      end
      "#{json}\n"
    end
    private_class_method :serialize

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

    def self.resource_category(configuration, resource)
      extension = resource.fetch('extension', []).find { |item| item['url'] == CATEGORY_URL }
      category = extension && extension['valueString']
      category ||= configuration.category_overrides[resource.fetch('name')]
      unless category
        raise "No #{configuration.label} resource category for #{resource.fetch('name')}"
      end

      CGI.unescapeHTML(category)
    end
    private_class_method :resource_category

    def self.add_category(configuration, resource_root, categories, resource, category_path)
      section_name, category_name = category_path.split('.', 2)
      if section_name.to_s.empty? || category_name.to_s.empty?
        raise "Invalid #{configuration.label} resource category for " \
              "#{resource.fetch('name')}: #{category_path}"
      end

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
