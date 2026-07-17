module Crucible
  module FHIRVersion
    DEFAULT = :r4
    NAMESPACES = {
      dstu2: 'FHIR::DSTU2',
      stu3: 'FHIR::STU3',
      r4: 'FHIR',
      r4b: 'FHIR::R4B'
    }.freeze
    KNOWN = NAMESPACES.keys.freeze

    class UnsupportedVersionError < ArgumentError; end

    def self.resolve(value = nil)
      normalized = value.to_s.strip.downcase
      return DEFAULT if normalized.empty?

      version = normalized.to_sym
      return version if KNOWN.include?(version)

      raise UnsupportedVersionError,
            "Unsupported FHIR version '#{value}'. Supported versions: #{KNOWN.join(', ')}"
    end

    def self.namespace(value = nil)
      namespace_name(value).split('::').inject(Object) do |parent, name|
        parent.const_get(name)
      end
    end

    def self.namespace_name(value = nil)
      NAMESPACES.fetch(resolve(value))
    end

    def self.for_class(value)
      class_name = value.is_a?(Module) ? value.name : value.class.name
      version = NAMESPACES.sort_by { |_key, name| -name.length }.find do |_key, name|
        class_name == name || class_name.start_with?("#{name}::")
      end
      return version.first if version

      raise UnsupportedVersionError, "Unable to determine FHIR version for #{class_name}"
    end
  end
end
