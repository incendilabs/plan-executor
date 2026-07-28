module Crucible
  class FHIRStructure
    def self.get(fhir_version)
      version = Crucible::FHIRVersion.resolve(fhir_version)
      root = File.expand_path File.join('..','..'), File.dirname(File.absolute_path(__FILE__))
      JSON.parse(File.read(File.join(root, 'lib', "FHIR_structure_#{version}.json")))
    end

    def self.for_resource(resource)
      get(Crucible::FHIRVersion.for_class(resource))
    end
  end
end
