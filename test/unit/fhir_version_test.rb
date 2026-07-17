require_relative '../test_helper'

class FHIRVersionTest < Test::Unit::TestCase
  def test_omitted_version_defaults_to_r4
    assert_equal :r4, Crucible::FHIRVersion.resolve
    assert_equal :r4, Crucible::FHIRVersion.resolve('')
    assert_equal :r4, Crucible::FHIRVersion.resolve('  ')
  end

  def test_known_versions_are_resolved_explicitly
    assert_equal :dstu2, Crucible::FHIRVersion.resolve(:dstu2)
    assert_equal :stu3, Crucible::FHIRVersion.resolve('STU3')
    assert_equal :r4, Crucible::FHIRVersion.resolve(:r4)
    assert_equal :r4b, Crucible::FHIRVersion.resolve('R4B')
  end

  def test_known_versions_are_listed_in_one_registry
    assert_equal [:dstu2, :stu3, :r4, :r4b], Crucible::FHIRVersion::KNOWN
  end

  def test_known_versions_resolve_to_explicit_model_namespaces
    assert_same FHIR::DSTU2, Crucible::FHIRVersion.namespace(:dstu2)
    assert_same FHIR::STU3, Crucible::FHIRVersion.namespace(:stu3)
    assert_same FHIR, Crucible::FHIRVersion.namespace(:r4)
    assert_same FHIR::R4B, Crucible::FHIRVersion.namespace(:r4b)
  end

  def test_model_classes_resolve_to_their_owning_version
    assert_equal :dstu2, Crucible::FHIRVersion.for_class(FHIR::DSTU2::Patient)
    assert_equal :stu3, Crucible::FHIRVersion.for_class(FHIR::STU3::Patient)
    assert_equal :r4, Crucible::FHIRVersion.for_class(FHIR::Patient)
    assert_equal :r4b, Crucible::FHIRVersion.for_class(FHIR::R4B::Patient)
  end

  def test_unknown_version_fails_instead_of_falling_back_to_r4
    error = assert_raise(Crucible::FHIRVersion::UnsupportedVersionError) do
      Crucible::FHIRVersion.resolve('r5')
    end

    assert_match(/Unsupported FHIR version 'r5'/, error.message)
    assert_match(/dstu2, stu3, r4, r4b/, error.message)
  end

  def test_unknown_fhir_4_version_fails_instead_of_falling_back_to_r4
    assert_raise(Crucible::FHIRVersion::UnsupportedVersionError) do
      Crucible::FHIRVersion.resolve('4.1.0')
    end
  end
end
