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
end
