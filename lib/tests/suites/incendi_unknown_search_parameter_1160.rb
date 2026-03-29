module Crucible
  module Tests
    class UnknownSearchParameterTest < BaseSuite

      def id
        'UnknownSearchParameterTest'
      end

      def description
        'Searching with an unknown search parameter should return a searchset Bundle that includes an OperationOutcome entry with search.mode=outcome (FHIR issue #1160)'
      end

      def initialize(client1, client2 = nil)
        super(client1, client2)
        @tags.append('incendilabs')
        @category = { id: 'incendilabs', title: 'Incendilabs' }
        @supported_versions = [:stu3, :r4]
      end

      def setup
        questionnaire_response = ResourceGenerator.generate(version_namespace.const_get(:QuestionnaireResponse))
        reply = @client.create(questionnaire_response)
        assert_response_ok(reply)
        @questionnaire_response_id = reply.id
      end

      def teardown
        @client.destroy(version_namespace.const_get(:QuestionnaireResponse), @questionnaire_response_id) unless @questionnaire_response_id.nil?
      end

      # basedOn (camelCase) is not a registered search parameter for QuestionnaireResponse.
      # The correct name is based-on (with hyphen). Using basedOn therefore exercises the
      # unknown-parameter code path regardless of the reference value supplied.
      # Returns a new hash each call because the FHIR client mutates the options hash.
      def unknown_param_options
        {
          search: {
            compartment: nil,
            parameters: {
              'basedOn' => 'CarePlan/1'
            }
          }
        }
      end

      def unknown_param_options_post
        {
          search: {
            flag: true,
            compartment: nil,
            parameters: {
              'basedOn' => 'CarePlan/1'
            }
          }
        }
      end

      test 'I1160A', 'Unknown search parameter: server returns HTTP 200 (lenient behaviour)' do
        metadata {
          links "#{BASE_SPEC_LINK}/search.html#errors"
          links "#{REST_SPEC_LINK}#search"
          links 'https://github.com/FirelyTeam/spark/issues/1160'
          validates resource: 'QuestionnaireResponse', methods: ['search']
        }

        reply = @client.search(version_namespace.const_get(:QuestionnaireResponse), unknown_param_options)

        assert_response_ok(reply)
        assert_bundle_response(reply)
      end

      test 'I1160B', 'Unknown search parameter: Bundle includes an OperationOutcome entry with search.mode=outcome' do
        metadata {
          links "#{BASE_SPEC_LINK}/search.html#errors"
          links "#{REST_SPEC_LINK}#search"
          links 'https://github.com/FirelyTeam/spark/issues/1160'
          validates resource: 'QuestionnaireResponse', methods: ['search']
        }

        reply = @client.search(version_namespace.const_get(:QuestionnaireResponse), unknown_param_options)
        assert_response_ok(reply)
        assert_bundle_response(reply)

        outcome_entries = reply.resource.entry.select do |e|
          e.resource.is_a?(version_namespace.const_get(:OperationOutcome)) &&
            e.search&.mode == 'outcome'
        end

        assert(
          outcome_entries.any?,
          'Expected the searchset Bundle to contain at least one OperationOutcome entry with search.mode=outcome for the unknown parameter "basedOn"',
          reply.body
        )
      end

      test 'I1160C', 'Unknown search parameter: OperationOutcome issue severity is warning' do
        metadata {
          links "#{BASE_SPEC_LINK}/search.html#errors"
          links "#{REST_SPEC_LINK}#search"
          links 'https://github.com/FirelyTeam/spark/issues/1160'
          validates resource: 'QuestionnaireResponse', methods: ['search']
        }

        reply = @client.search(version_namespace.const_get(:QuestionnaireResponse), unknown_param_options)
        assert_response_ok(reply)
        assert_bundle_response(reply)

        outcome_entry = reply.resource.entry.find do |e|
          e.resource.is_a?(version_namespace.const_get(:OperationOutcome)) &&
            e.search&.mode == 'outcome'
        end

        assert(outcome_entry, 'No OperationOutcome entry with search.mode=outcome found in the Bundle', reply.body)

        issue = outcome_entry.resource.issue.first
        assert(issue, 'OperationOutcome has no issues', reply.body)
        assert(
          issue.severity == 'warning',
          "Expected OperationOutcome issue severity to be 'warning' but was '#{issue.severity}'",
          reply.body
        )
      end

      test 'I1160D', 'Unknown search parameter via POST _search: server returns HTTP 200 (lenient behaviour)' do
        metadata {
          links "#{BASE_SPEC_LINK}/search.html#errors"
          links "#{REST_SPEC_LINK}#search"
          links 'https://github.com/FirelyTeam/spark/issues/1160'
          validates resource: 'QuestionnaireResponse', methods: ['search']
        }

        reply = @client.search(version_namespace.const_get(:QuestionnaireResponse), unknown_param_options_post)

        assert_response_ok(reply)
        assert_bundle_response(reply)
      end

      test 'I1160E', 'Unknown search parameter via POST _search: Bundle includes an OperationOutcome entry with search.mode=outcome' do
        metadata {
          links "#{BASE_SPEC_LINK}/search.html#errors"
          links "#{REST_SPEC_LINK}#search"
          links 'https://github.com/FirelyTeam/spark/issues/1160'
          validates resource: 'QuestionnaireResponse', methods: ['search']
        }

        reply = @client.search(version_namespace.const_get(:QuestionnaireResponse), unknown_param_options_post)
        assert_response_ok(reply)
        assert_bundle_response(reply)

        outcome_entries = reply.resource.entry.select do |e|
          e.resource.is_a?(version_namespace.const_get(:OperationOutcome)) &&
            e.search&.mode == 'outcome'
        end

        assert(
          outcome_entries.any?,
          'Expected the searchset Bundle to contain at least one OperationOutcome entry with search.mode=outcome for the unknown parameter "basedOn"',
          reply.body
        )
      end

      test 'I1160F', 'Unknown search parameter via POST _search: OperationOutcome issue severity is warning' do
        metadata {
          links "#{BASE_SPEC_LINK}/search.html#errors"
          links "#{REST_SPEC_LINK}#search"
          links 'https://github.com/FirelyTeam/spark/issues/1160'
          validates resource: 'QuestionnaireResponse', methods: ['search']
        }

        reply = @client.search(version_namespace.const_get(:QuestionnaireResponse), unknown_param_options_post)
        assert_response_ok(reply)
        assert_bundle_response(reply)

        outcome_entry = reply.resource.entry.find do |e|
          e.resource.is_a?(version_namespace.const_get(:OperationOutcome)) &&
            e.search&.mode == 'outcome'
        end

        assert(outcome_entry, 'No OperationOutcome entry with search.mode=outcome found in the Bundle', reply.body)

        issue = outcome_entry.resource.issue.first
        assert(issue, 'OperationOutcome has no issues', reply.body)
        assert(
          issue.severity == 'warning',
          "Expected OperationOutcome issue severity to be 'warning' but was '#{issue.severity}'",
          reply.body
        )
      end

    end
  end
end
