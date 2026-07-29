module Crucible
  module Tests
    class SearchTest < BaseSuite

      R5_SEARCH_RESULT_PARAMETERS = ['_summary'].freeze

      attr_accessor :resource_class
      attr_accessor :conformance
      attr_accessor :searchParams
      attr_reader   :canSearchById

      def execute(resource_class=nil)
        if resource_class
          @resource_class = resource_class
          {"SearchTest_#{@resource_class.name.demodulize}" => execute_test_methods}
        else
          results = {}
          fhir_resources.each do | klass |
            @resource_class = klass
            results.merge!({"SearchTest_#{@resource_class.name.demodulize}" => execute_test_methods})
          end
          results
        end
      end

      def id
        suffix = resource_class
        suffix = resource_class.name.demodulize if !resource_class.nil?
        "SearchTest_#{suffix}"
      end

      def description
        "Execute suite of searches for #{resource_class.name.demodulize} resources."
      end

      def category
        resource = @resource_class.nil? ? "Uncategorized" : resource_category(@resource_class)
        {id: "search_#{resource.parameterize}", title: "#{resource} Search"}
      end

      def initialize(client1, client2=nil)
        super(client1, client2)
        @supported_versions = [:dstu2, :stu3, :r4, :r4b, :r5]
      end

      # this allows results to have unique ids for resource based tests
      def result_id_suffix
        resource_class.name.demodulize
      end

      def supplement_test_description(desc)
        "#{desc} #{resource_class.name.demodulize}"
      end

      #
      # Search Test
      # 1. First, get the conformance statement.
      # 2. Lookup the allowed search parameters for each resource.
      # 3. Perform suite of tests against each resource.
      #
      def setup
        @conformance = @client.conformance_statement if @conformance.nil?

        @canSearchById = false

        unless @conformance.nil?
          @conformance.rest.each do |rest|
            rest.resource.each do |resource|
              @searchParams = resource.searchParam if(resource.type.downcase == "#{@resource_class.name.demodulize.downcase}" )
            end
          end
        end

        index = @searchParams.find_index {|item| item.name=="_id" } if !@searchParams.nil?
        @canSearchById = !index.nil?
      end

      test 'S000', 'Compare supported search parameters with specification' do
        metadata {
          define_metadata('search')
        }
        if fhir_version == :r5
          expected_params = r5_search_parameter_definitions
          expected_by_name = expected_params.each_with_object({}) do |search_param, definitions|
            definitions[search_param['code']] = search_param
          end
          advertised_params = @searchParams || []
          allowed_params = expected_by_name.keys + R5_SEARCH_RESULT_PARAMETERS
          unknown_params = advertised_params.map(&:name) - allowed_params

          assert unknown_params.empty?,
                 "The server advertises search parameters not defined by R5: #{unknown_params.join(', ')}."

          advertised_params.each do |search_param|
            next if R5_SEARCH_RESULT_PARAMETERS.include?(search_param.name)

            expected = expected_by_name.fetch(search_param.name)
            assert_equal expected['type'], search_param.type,
                         "The server advertises #{search_param.name} as #{search_param.type}, " \
                         "but R5 defines it as #{expected['type']}."
          end
        else
          search_param_names = []
          search_param_names = @searchParams.map(&:name) unless @searchParams.nil?
          search_params_diff = @resource_class::SEARCH_PARAMS - search_param_names
          assert (search_params_diff.size <= 0),
                 "The server does not support the following params: #{search_params_diff.join(', ')}."
        end
      end

      #
      # Test the extent of the search capabilities supported.
      # x  no criteria [SE01]
      # x  limit by _count [S003]
      # x  non-existing resource [SE02]
      # x  id [S001,S002]
      # x  parameters [SE03,SE04]
      # x  parameters [SE24,SE25]
      # parameter modifiers (
      # x  :missing, [SE23]
      # :exact,
      # :text,
      # :[type])
      # x  numbers (= >= significant-digits) [SE21,SE22]
      # date (all of the permutations?)
      # token
      # x  quantities [SE21,SE22]
      # x  references [SE05]
      # chained parameters
      # composite parameters
      # text search logical operators
      # tags [TA08], profile, security label
      # _filter parameter
      # result relevance
      # result sorting (_sort parameter)
      # result paging
      # x  _include parameter [SE06]
      # _summary parameter
      # result server conformance (report params actually used)
      # advanced searching with "Query" or _query param (valueset 'expand' and 'validate' queries should be standard)
      #

      # Parameters for all resources
      #   _id
      #   _lastUpdated
      #   _tag
      #   _profile
      #   _security
      #   _text
      #   _content
      #   _list
      #   _query
      # Search result parameters
      #   _sort
      #   _count
      #   _include
      #   _revinclude
      #   _summary
      #   _elements
      #   _contained
      #   _containedType
      
    [true,false].each do |flag|  
      action = 'GET'
      action = 'POST' if flag

      test "S001#{action[0]}", "Search by ID (#{action})" do
        metadata {
          define_metadata('search')
        }
        options = {
          :search => {
            :flag => flag,
            :compartment => nil,
            :parameters => {
              '_id' => '0'
            }
          }
        }
        reply = @client.search(@resource_class, options)
        assert_response_ok(reply)
        assert_bundle_response(reply)
      end

      test "S003#{action[0]}", "Search limit by _count (#{action})" do
        metadata {
          define_metadata('search')
        }
        options = {
          :search => {
            :flag => flag,
            :compartment => nil,
            :parameters => {
              '_count' => '1'
            }
          }
        }
        reply = @client.search(@resource_class, options)
        assert_response_ok(reply)
        assert_bundle_response(reply)
        assert (1 >= reply.resource.entry.size), 'The server did not return the correct number of results.'
      end

      # ********************************************************* #
      # _____________________Sprinkler Tests_____________________ #
      # ********************************************************* #

      test "SE01#{action[0]}", "Search without criteria (#{action})" do
        metadata {
          links "#{BASE_SPEC_LINK}/#{resource_class.name.demodulize.downcase}.html"
          links "#{REST_SPEC_LINK}#search"
          links "#{REST_SPEC_LINK}#read"
          validates resource: resource_class.name.demodulize, methods: ['read', 'search']
        }
        options = {
          :search => {
            :flag => flag,
            :compartment => nil,
            :parameters => nil
          }
        }
        reply = @client.search(@resource_class, options)
        assert_response_ok(reply)
        assert_bundle_response(reply)

        replyB = @client.read_feed(@resource_class)

        # AuditEvent
        if resource_class == get_resource(:AuditEvent)
          count = (reply.resource.total-replyB.resource.total).abs
          assert (count <= 1), 'Searching without criteria did not return all the results.'
        else
          assert !replyB.resource.nil?, 'Searching without criteria did not return any results.'
          assert !reply.resource.nil?, 'Searching without criteria did not return any results.'
          assert !replyB.resource.total.nil?, 'Search bundle returned does not report a total entry count.'
          assert !reply.resource.total.nil?, 'Search bundle returned does not report a total entry count.'
          assert_equal replyB.resource.total, reply.resource.total, 'Searching without criteria did not return all the results.'
        end
      end
    end

      def define_metadata(method)
        links "#{REST_SPEC_LINK}##{method}"
        links "#{BASE_SPEC_LINK}/#{resource_class.name.demodulize.downcase}.html"
        validates resource: resource_class.name.demodulize, methods: [method]
      end

      def r5_search_parameter_definitions
        resource_name = @resource_class.name.demodulize
        FHIR::R5::Definitions.send(:search_params).select do |search_param|
          (search_param.fetch('base', []) & [resource_name, 'Resource']).any?
        end
      end

    end
  end
end
