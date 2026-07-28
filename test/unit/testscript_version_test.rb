require_relative '../test_helper'
require 'rake'

load File.expand_path('../../lib/tasks/tasks.rake', __dir__)

class TestScriptVersionTest < Test::Unit::TestCase
  def test_stu3_testscript_execution_remains_supported
    assert_equal :stu3, resolve_testscript_fhir_version(:stu3)
  end

  def test_r5_testscript_execution_is_rejected
    error = assert_raise(Crucible::FHIRVersion::UnsupportedVersionError) do
      resolve_testscript_fhir_version(:r5)
    end

    assert_equal 'FHIR TestScripts require STU3, got r5', error.message
  end
end
