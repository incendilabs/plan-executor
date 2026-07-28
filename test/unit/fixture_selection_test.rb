require_relative '../test_helper'
require 'tmpdir'

class FixtureSelectionTest < Test::Unit::TestCase
  def test_selects_version_specific_fixture_from_the_fixture_root
    with_fixture_helper(:r4b) do |resources, directory|
      write_patient(directory, 'patient.json', 'base')
      write_patient(directory, 'patient.r4b.json', 'r4b')

      patient = resources.load_fixture('patient', :json)

      assert_instance_of FHIR::R4B::Patient, patient
      assert_equal 'r4b', patient.id
    end
  end

  def test_falls_back_to_the_base_fixture
    with_fixture_helper(:r4b) do |resources, directory|
      write_patient(directory, 'patient.json', 'base')

      patient = resources.load_fixture('patient', :json)

      assert_instance_of FHIR::R4B::Patient, patient
      assert_equal 'base', patient.id
    end
  end

  def test_selects_r5_json_override
    with_fixture_helper('R5') do |resources, directory|
      write_patient(directory, 'patient.json', 'base')
      write_patient(directory, 'patient.r5.json', 'r5-json')

      patient = resources.load_fixture('patient', :json)

      assert_instance_of FHIR::R5::Patient, patient
      assert_equal 'r5-json', patient.id
    end
  end

  def test_selects_r5_xml_override
    with_fixture_helper(:r5) do |resources, directory|
      write_patient_xml(directory, 'patient.xml', 'base')
      write_patient_xml(directory, 'patient.r5.xml', 'r5-xml')

      patient = resources.load_fixture('patient', :xml)

      assert_instance_of FHIR::R5::Patient, patient
      assert_equal 'r5-xml', patient.id
    end
  end

  def test_r5_base_fallback_is_parsed_through_r5
    with_fixture_helper(:r5) do |resources, directory|
      write_patient(directory, 'patient.json', 'base')

      patient = resources.load_fixture('patient', :json)

      assert_instance_of FHIR::R5::Patient, patient
      assert_equal 'base', patient.id
    end
  end

  def test_r4b_override_is_not_selected_for_r5
    with_fixture_helper(:r5) do |resources, directory|
      write_patient(directory, 'patient.json', 'base')
      write_patient(directory, 'patient.r4b.json', 'r4b')

      patient = resources.load_fixture('patient', :json)

      assert_instance_of FHIR::R5::Patient, patient
      assert_equal 'base', patient.id
    end
  end

  def test_invalid_r5_json_fixture_reports_validation_errors
    with_fixture_helper(:r5) do |resources, directory|
      File.write(
        File.join(directory, 'patient.r5.json'),
        JSON.generate(resourceType: 'Patient', gender: 'invalid')
      )

      error = assert_raise(Crucible::Generator::Resources::InvalidFixtureError) do
        resources.load_fixture('patient', :json)
      end

      assert_match(/Invalid R5 JSON fixture/, error.message)
      assert_match(/Patient\.gender: invalid codes/, error.message)
    end
  end

  def test_malformed_r5_json_fixture_reports_parsing_errors
    with_fixture_helper(:r5) do |resources, directory|
      File.write(File.join(directory, 'patient.r5.json'), '{')

      error = assert_raise(Crucible::Generator::Resources::InvalidFixtureError) do
        resources.load_fixture('patient', :json)
      end

      assert_match(/Invalid R5 JSON fixture/, error.message)
      assert_match(/line 1 column 2/, error.message)
    end
  end

  def test_invalid_r5_xml_fixture_reports_schema_errors
    with_fixture_helper(:r5) do |resources, directory|
      File.write(
        File.join(directory, 'patient.r5.xml'),
        '<Patient xmlns="http://hl7.org/fhir"><birthDate value="not-date"/></Patient>'
      )

      error = assert_raise(Crucible::Generator::Resources::InvalidFixtureError) do
        resources.load_fixture('patient', :xml)
      end

      assert_match(/Invalid R5 XML fixture/, error.message)
      assert_match(/birthDate/, error.message)
      assert_match(/not-date/, error.message)
    end
  end

  def test_unknown_fixture_version_is_rejected
    error = assert_raise(Crucible::FHIRVersion::UnsupportedVersionError) do
      Crucible::Generator::Resources.new(:r6)
    end

    assert_match(/Unsupported FHIR version 'r6'/, error.message)
    assert_match(/dstu2, stu3, r4, r4b, r5/, error.message)
  end

  private

  def with_fixture_helper(version)
    Dir.mktmpdir do |directory|
      resources = Crucible::Generator::Resources.new(version)
      resources.define_singleton_method(:fixture_path) { directory }
      yield resources, directory
    end
  end

  def write_patient(directory, filename, id)
    File.write(
      File.join(directory, filename),
      JSON.generate(resourceType: 'Patient', id: id)
    )
  end

  def write_patient_xml(directory, filename, id)
    File.write(
      File.join(directory, filename),
      %(<Patient xmlns="http://hl7.org/fhir"><id value="#{id}"/></Patient>)
    )
  end
end
