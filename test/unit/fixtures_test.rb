require_relative '../test_helper'

class FixturesTest < Test::Unit::TestCase

  ERROR_DIR = File.join('tmp', 'errors', 'FixturesTest')
  # Create a blank folder for the errors
  FileUtils.rm_rf(ERROR_DIR) if File.directory?(ERROR_DIR)
  FileUtils.mkdir_p ERROR_DIR

  fixtures = File.join('fixtures','**','*.xml')
  json_fixtures = File.join('fixtures','**','*.json')
  raise 'No Fixture Files Found' if Dir[fixtures].empty? && Dir[json_fixtures].empty?

  def self.fixture_version(file)
    directory_version = file.match(/fixtures\/([^\/]+)/)[1].to_sym
    filename = File.basename(file, File.extname(file))
    filename_version = filename.split('.').last.to_sym

    Crucible::FHIRVersion::KNOWN.include?(filename_version) ? filename_version : directory_version
  end

  # Define test methods to validate example JSON
  Dir.glob(fixtures).each do | file |    
    basename = File.basename(file,'.xml')
    next if basename.start_with?('ccda')

    version = fixture_version(file)
    xml = File.open(file, 'r:bom|UTF-8', &:read)

    define_method("test_fixture_validation_#{basename}_#{version}") do
      run_validate(basename, xml, version.to_sym)
    end
  end
  Dir.glob(json_fixtures).each do | file |
    basename = File.basename(file,'.json')
    json = File.open(file, 'r:bom|UTF-8', &:read)

    version = fixture_version(file)
    define_method("test_json_fixture_validation_#{basename}_#{version}") do
      run_json_validate(basename, json, version.to_sym)
    end
  end

  def xml_namespace(fhir_version)
    Crucible::FHIRVersion.namespace(fhir_version).const_get(:Xml)
  end

  def json_namespace(fhir_version)
    Crucible::FHIRVersion.namespace(fhir_version).const_get(:Json)
  end

  def test_r5_fixture_validation_uses_r5_format_namespaces
    assert_same FHIR::R5::Xml, xml_namespace(:r5)
    assert_same FHIR::R5::Json, json_namespace(:r5)
  end

  def test_unknown_fixture_validation_version_is_rejected
    error = assert_raise(Crucible::FHIRVersion::UnsupportedVersionError) do
      json_namespace(:r6)
    end

    assert_match(/Unsupported FHIR version 'r6'/, error.message)
    assert_match(/dstu2, stu3, r4, r4b, r5/, error.message)
  end

  def run_validate(fixture, xml, version)
    assert(fixture && xml)
    xml_namespace = xml_namespace(version)

    r = xml_namespace.from_xml(xml)
    assert(!r.nil?,"XML fixture does not deserialize.")
    
    errors = xml_namespace.validate(xml)
    if !errors.empty?
      File.open("#{ERROR_DIR}/#{version}_#{fixture}.err", 'w:UTF-8') do |file|
        file.write "#{version}_#{fixture}: #{errors.length} errors\n\n"
        errors.each do |error|
          file.write(sprintf("%-8d  %s\n", error.line, error.message))
        end
      end
      File.open("#{ERROR_DIR}/#{version}_#{fixture}.xml", 'w:UTF-8') { |file| file.write(xml) }
    end

    assert(errors.empty?,"XML fixture does not conform to schema.")
  end

  def run_json_validate(fixture,json,version)
    assert(fixture && json)

    json_namespace = json_namespace(version)

    r = json_namespace.from_json(json)
    assert(!r.nil?,"JSON fixture does not deserialize.")

    errors = r.validate
    if !errors.empty?
      File.open("#{ERROR_DIR}/#{version}_#{fixture}.err", 'w:UTF-8') do |file|
        file.write "#{version}_#{fixture}: #{errors.length} errors\n\n"
        errors.each do |error|
          file.write(sprintf("%-8d  %s\n", error.line, error.message))
        end
      end
      File.open("#{ERROR_DIR}/#{version}_#{fixture}.json", 'w:UTF-8') { |file| file.write(json) }
    end

    assert(errors.empty?,"JSON fixture does not conform to definition.")
  end

end
