require_relative '../test_helper'

class SupportedVersionsTest < Test::Unit::TestCase
  def test_base_suite_does_not_grant_implicit_version_support
    assert_empty Crucible::Tests::BaseSuite.new(nil).supported_versions
  end

  def test_every_executable_suite_declares_supported_versions
    suites = Crucible::Tests::SuiteEngine.new.tests

    assert_true suites.all? { |suite| suite.supported_versions.any? }
  end

  def test_resource_suites_preserve_their_existing_version_support
    expected = [:dstu2, :stu3, :r4, :r4b]

    assert_equal expected, Crucible::Tests::ResourceTest.new(nil).supported_versions
    assert_equal expected, Crucible::Tests::SearchTest.new(nil).supported_versions
  end

  def test_every_r4_suite_advertises_r4b
    suites = Crucible::Tests::SuiteEngine.new.tests
    r4_suites = suites.select { |suite| suite.supported_versions.include?(:r4) }
    r4b_suites = suites.select { |suite| suite.supported_versions.include?(:r4b) }

    assert_equal r4_suites.map(&:class).sort_by(&:name), r4b_suites.map(&:class).sort_by(&:name)
  end
end
