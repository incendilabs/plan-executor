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
      NAMESPACES.fetch(resolve(value)).split('::').inject(Object) do |parent, name|
        parent.const_get(name)
      end
    end
  end
end
