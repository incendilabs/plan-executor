require_relative '../test_helper'

class SupportedVersionsTest < Test::Unit::TestCase
  R4B_CAPABLE_SUITE_CLASSES = %w[
    ConsentSearchByPatientReferenceTest
    ElementsSearchParameterTest
    FhirPathPatchTest
    FormatTest
    HistoryTest
    ReadTest
    ResourceTest
    RobustSearchTest
    SearchTest
    SprinklerSearchTest
    TransactionAndBatchTest
    UnknownSearchParameterTest
  ].freeze

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

  def test_r5_compatibility_inventory_matches_the_complete_r4b_suite_set
    r4b_suite_classes = Crucible::Tests::SuiteEngine.new.tests
                                               .select { |suite| suite.supported_versions.include?(:r4b) }
                                               .map { |suite| suite.class.name.demodulize }
                                               .sort

    assert_equal R4B_CAPABLE_SUITE_CLASSES, r4b_suite_classes
  end

  def test_r5_is_not_enabled_for_any_suite_yet
    suites = Crucible::Tests::SuiteEngine.new.tests

    assert_true suites.none? { |suite| suite.supported_versions.include?(:r5) }
  end

  def test_r5_listing_and_execution_eligibility_are_both_empty_before_an_audit
    suites = Crucible::Tests::SuiteEngine.new.tests
    r5_executable_suites = suites.select { |suite| suite.supported_versions.include?(:r5) }
    r5_listed_tests = Crucible::Tests::SuiteEngine.list_all.values.select do |metadata|
      metadata.fetch('supported_versions', []).include?(:r5)
    end

    assert_empty r5_executable_suites
    assert_empty r5_listed_tests
  end

  def test_testscripts_remain_explicitly_stu3_only
    testscripts = Crucible::Tests::TestScriptEngine.new.tests

    assert_not_empty testscripts
    assert_true testscripts.all? { |testscript| testscript.supported_versions == [:stu3] }
  end
end
