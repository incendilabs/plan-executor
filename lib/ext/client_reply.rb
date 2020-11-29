module FHIR
  class ClientReply

    def response_format
      doc = Nokogiri::XML(self.body)
      if doc.errors.empty?
        return FHIR::Formats::ResourceFormat::RESOURCE_XML if fhir_version != :dstu2
        return FHIR::Formats::ResourceFormat::RESOURCE_XML_DSTU2 if fhir_version == :dstu2
      else
        begin
          JSON.parse(self.body)
          return FHIR::Formats::ResourceFormat::RESOURCE_JSON if fhir_version != :dstu2
          return FHIR::Formats::ResourceFormat::RESOURCE_JSON_DSTU2 if fhir_version == :dstu2
        rescue JSON::ParserError => e
          raise "Failed to detect response format: #{self.body}"
        end
      end
    end

  end
end
