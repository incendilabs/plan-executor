namespace :crucible do

  FHIR_SERVERS = [
    # DSTU1
    # 'http://fhir.healthintersections.com.au/open',
    # 'http://bonfire.mitre.org:8080/fhir',
    # 'http://spark.furore.com/fhir',
    # 'http://nprogram.azurewebsites.net',
    # 'https://fhir-api.smartplatforms.org',
    # 'https://fhir-open-api.smartplatforms.org',
    # 'https://fhir.orionhealth.com/blaze/fhir',
    # 'http://worden.globalgold.co.uk:8080/FHIR_a/farm/cobalt',
    # 'http://worden.globalgold.co.uk:8080/FHIR_a/farm/bronze',
    # 'http://fhirtest.uhn.ca/base'

    # DSTU2
    'https://fhir-api-dstu2.smarthealthit.org',
    'http://fhirtest.uhn.ca/baseDstu2',
    'http://bp.oridashi.com.au',
    'http://md.oridashi.com.au',
    'http://zm.oridashi.com.au',
    'http://wildfhir.aegis.net/fhir2',
    'http://fhir-dev.healthintersections.com.au/open'
  ]

  desc 'console'
  task :console, [] do |t, args|
    FHIR.logger = Logger.new("logs/plan_executor.log", 10, 1024000)
    binding.pry
  end

  desc 'execute all'
  task :execute_all, [:url, :fhir_version, :output] do |t, args|
    FHIR.logger = Logger.new("logs/plan_executor.log", 10, 1024000)
    fhir_version = resolve_fhir_version(args.fhir_version)
    require 'benchmark'
    result = {}
    b = Benchmark.measure {
      client = FHIR::Client.new(args.url)
      client.use_fhir_version(fhir_version)
      client.setup_security
      result = execute_all(args.url, client, args.output)
    }
    puts "Execute All completed in #{b.real} seconds."
    process_summary(result, args.url, args.output)
    fail_on_error(result)
  end

  desc 'execute all test scripts'
  task :execute_all_testscripts, [:url, :output] do |t, args|
    FHIR.logger = Logger.new("logs/plan_executor.log", 10, 1024000)
    require 'benchmark'
    b = Benchmark.measure {
      client = FHIR::Client.new(args.url)
      client.setup_security
      results = Crucible::Tests::TestScriptEngine.new(client).execute_all
      process_results(results, args.url, args.output)
    }
    puts "Execute All completed in #{b.real} seconds."
  end

  desc 'execute testscript and get testreport'
  task :testreport, [:url, :test, :filename] do |t, args|
    FHIR.logger = Logger.new("logs/plan_executor.log", 10, 1024000)
    require 'benchmark'
    b = Benchmark.measure {
      client = FHIR::Client.new(args.url)
      client.setup_security
      engine = Crucible::Tests::TestScriptEngine.new(client)
      script = engine.find_test(args.test)
      if script.nil?
        puts "Unable to find TestScript #{args.test}"
      else
        results = script.execute
        if args.filename
          f = File.open(args.filename,'w:UTF-8')
          f.write(results.values.first.to_json)
          f.close
        end
        puts results.values.first.to_json
      end
    }
    puts "TestReport completed in #{b.real} seconds."
  end

  desc 'execute'
  task :execute, [:url, :fhir_version, :test, :resource, :output] do |t, args|
    FHIR.logger = Logger.new("logs/plan_executor.log", 10, 1024000)
    fhir_version = resolve_fhir_version(args.fhir_version)
    require 'benchmark'
    result = {}
    b = Benchmark.measure {
      client = FHIR::Client.new(args.url)
      client.use_fhir_version(fhir_version)
      client.setup_security
      result = execute_test(args.url, client, args.test, args.resource, args.output)
    }
    puts "Execute #{args.test} completed in #{b.real} seconds."
    process_summary(result, args.url, args.output)
    fail_on_error(result)
  end

  desc 'metadata'
  task :metadata, [:test] do |t, args|
    FHIR.logger = Logger.new("logs/plan_executor.log", 10, 1024000)
    require 'benchmark'
    b = Benchmark.measure { puts JSON.pretty_unparse(Crucible::Tests::Executor.new(nil).extract_metadata_from_test(args.test)) }
    puts "Metadata #{args.test} completed in #{b.real} seconds."
  end

  def process_summary(result, url, output = nil)
    output_formats = []
    output_formats = output.split('|').map{|str| str.downcase} if output
    totals = Hash.new(0)
    result.each do |(_, v)|
      v.map { |t| t["status"] }.each_with_object(totals) { |n, h| h[n] += 1 }
    end unless result.nil?
    output_summary(totals) if output_formats.include?("stdout")
    save_json_summary(totals, url) if output_formats.include?("json")
  end

  def output_summary(totals)
    totals.each do |(status, count)|
      puts "#{status.upcase}: #{count}"
    end
  end

  def save_json_summary(totals, url)
    FileUtils::mkdir_p("json_results")
    output_file = output_file_name(url, "_summary", ".json")
    File.write("json_results/#{output_file}", totals.to_json)
  end

  def fail_on_error(result)
    if !result.nil? && result.values.any? { |v|
      v.any? { |t|
        t['status'] == "error" ||
            t['status'] == "fail" ||
            (t['status'] == "skip" && !t['message']&.include?("TODO"))
      }
    }
      exit(1)
    end
  end

  def resolve_fhir_version(version_string)
    fhir_version = :r4
    fhir_version = :stu3 if version_string.to_s.downcase == 'stu3'
    fhir_version = :dstu2 if version_string.to_s.downcase == 'dstu2'
    fhir_version
  end

  def execute_test(url, client, key, resourceType=nil, output=nil)
    executor = Crucible::Tests::Executor.new(client)
    test = executor.find_test(key)
    if test.nil? || (test.is_a?(Array) && test.empty?)
      puts "Unable to find test: #{key}"
      return
    end
    if !test.supported_versions.include?(client.fhir_version)
      puts "Test #{key} does not support fhir version #{client.fhir_version}"
      return
    end
    if !resourceType.nil? && test.respond_to?(:resource_class=) && !Crucible::Tests::BaseSuite.valid_resource?(client.fhir_version, resourceType)
      puts "No such resource #{resourceType} in fhir version #{client.fhir_version}"
      return
    end
    results = nil
    if !resourceType.nil? && test.respond_to?(:resource_class=) && Crucible::Tests::BaseSuite.valid_resource?(client.fhir_version, resourceType)
      results = test.execute(Crucible::Tests::BaseSuite.get_resource(client.fhir_version, resourceType))
    end
    results = executor.execute(test) if results.nil?
    process_results(results, url, output)
  end

  def execute_all(url, client, output=nil)
    executor = Crucible::Tests::Executor.new(client)
    all_results = {}
    executor.tests.each do |test|
      next if test.multiserver
      next if !test.supported_versions.include?(client.fhir_version)
      results = executor.execute(test)
      all_results.merge! process_results(results, url, output)
    end
    all_results
  end

  def process_results(results, url, output = nil)
    results = convert_results(results)
    output_formats = []
    output_formats = output.split('|').map{|str| str.downcase} if output
    unless output.nil?
      generate_html_summary(url, results) if output == "true" || output_formats.include?("html") # old param syntax support
      output_json(url, results) if output_formats.include?("json")
      output_results(results) if output_formats.include?("stdout")
    end
    results
  end

  def convert_results(results)
    converted = {}
    results.each do |(k, v)|
      v = convert_testreport_to_testresults(v) if v.is_a?(FHIR::TestReport)
      converted[k] = v
    end
    converted
  end

  def output_results(results, metadata_only=false)
    require 'ansi'
    results.keys.each do |suite_key|
      puts suite_key
      suite = results[suite_key]
      suite.each do |test|
        puts write_result(test['status'], test[:test_method], test['message'])
        if test['status'].upcase=='ERROR' && test['data']
          puts " "*12 + "-"*40
          puts " "*12 + "#{test['data'].gsub("\n","\n"+" "*12)}"
          puts " "*12 + "-"*40
        end
        if (metadata_only==true)
          # warnings
          puts (test['warnings'].map { |w| "#{(' '*10)}WARNING: #{w}" }).join("\n") if test['warnings']
          # metadata
          puts (test['links'].map { |w| "#{(' '*10)}Link: #{w}" }).join("\n") if test['links']
          puts (test['requires'].map { |w| "#{(' '*10)}Requires: #{w[:resource]}: #{w[:methods]}" }).join("\n") if test['requires']
          puts (test['validates'].map { |w| "#{(' '*10)}Validates: #{w[:resource]}: #{w[:methods]}" }).join("\n") if test['validates']
          # data
          puts (' '*10) + test['data'] if test['data']
        end
      end
    end
    results
  end

  def convert_testreport_to_testresults(testreport)
    results = []

    if testreport.setup
      statuses = Hash.new(0)
      message = nil
      testreport.setup.action.each do |action|
        if action.operation
          statuses[action.operation.result] += 1
          message = action.operation.message if ['fail','error','skip'].include?(action.operation.result) && message.nil? && action.operation.message
        elsif action.assert
          statuses[action.assert.result] += 1
          message = action.assert.message if ['fail','error','skip'].include?(action.assert.result) && message.nil? && action.assert.message
        end
      end
      if statuses['error'] > 0
        status = 'error'
      elsif statuses['fail'] > 0
        status = 'fail'
      elsif statuses['skip'] > 0
        status = 'skip'
      else
        status = 'pass'
      end
      results << Crucible::Tests::TestResult.new('SETUP', 'Setup for TestScript', status, message, nil).to_hash
      results.last[:test_method] = 'SETUP'
    end

    testreport.test.each do |test|
      statuses = Hash.new(0)
      message = nil
      test.action.each do |action|
        if action.operation
          statuses[action.operation.result] += 1
          message = action.operation.message if ['fail','error','skip'].include?(action.operation.result) && message.nil? && action.operation.message
        elsif action.assert
          statuses[action.assert.result] += 1
          message = action.assert.message if ['fail','error','skip'].include?(action.assert.result) && message.nil? && action.assert.message
        end
      end
      if statuses['error'] > 0
        status = 'error'
      elsif statuses['fail'] > 0
        status = 'fail'
      elsif statuses['skip'] > 0
        status = 'skip'
      else
        status = 'pass'
      end
      results << Crucible::Tests::TestResult.new(test.name, test.description, status, message, nil).to_hash
      results.last[:test_method] = test.name
    end
    results
  end

  def generate_html_summary(url, results)
    require 'erb'
    require 'tilt'
    require 'fileutils'
    include ERB::Util
    FileUtils::mkdir_p("html_summaries")
    results.each do |(k, v)|
      totals = Hash.new(0)
      metadata = Hash.new(0)
      v.map{|t| t["status"]}.each_with_object(totals) { |n, h| h[n] += 1}
      v.map{|t| {k: t["id"], v: t["validates"], s: t["status"]}}.each_with_object(metadata) do |n, h|
        n[:v].each do |val|
          resource = val[:resource].try(:titleize).try(:downcase)
          test_key = n[:k]
          h[resource] = {pass: [], fail: [], error: [], skip: []} unless h.keys.include?(resource)
          h[resource][n[:s].to_sym] << test_key
          val[:methods].each do |meth|
            h[meth] = {pass: [], fail: [], error: [], skip: []} unless h.keys.include?(meth)
            h[meth][n[:s].to_sym] << test_key
          end if val[:methods]
          val[:formats].each do |format|
            h[format] = {pass: [], fail: [], error: [], skip: []} unless h.keys.include?(format)
            h[format][n[:s].to_sym] << test_key
          end if val[:formats]
        end if n[:v]
      end
      template = Tilt.new(File.join(File.dirname(__FILE__), "templates", "summary.html.erb"))
      timestamp = Time.now
      summary = template.render(self, {:results => {k => v}, :timestamp => timestamp.strftime("%D %r"), :totals => totals, :url => url, :metadata => metadata})
      summary_file = output_file_name(url, k, ".html")
      File.write("html_summaries/#{summary_file}", summary)
    end
  end

  def output_json(url, results)
    FileUtils::mkdir_p("json_results")
    results.each do |(k, v)|
      output_file = output_file_name(url, k, ".json")
      File.write("json_results/#{output_file}", v.to_json)
    end
  end

  def output_file_name(url, k, suffix)
    timestamp = Time.now
    "#{k}_#{url.gsub(/[^a-z0-9]/,'-')}_#{timestamp.strftime("%m-%d-%y_%H-%M-%S")}#{suffix}"
  end

  desc 'execute custom'
  task :execute_custom, [:test, :fhir_version, :resource_type, :output] do |t, args|
    FHIR.logger = Logger.new("logs/plan_executor.log", 10, 1024000)
    require 'benchmark'
    fhir_version = resolve_fhir_version(args.fhir_version)

    puts "# #{args.test}"
    puts

    seconds = 0.0

    FHIR_SERVERS.each do |url|
      puts "## #{url}"
      puts "```"
      b = Benchmark.measure {
        client = FHIR::Client.new(url)
        client.use_fhir_version(fhir_version)
        client.setup_security
        execute_test(url, client, args.test, args.resource_type, args.output)
      }
      seconds += b.real
      puts "```"
      puts
    end
    puts "Execute Custom #{args.test} completed for #{FHIR_SERVERS.length} servers in #{seconds} seconds."
  end

  desc 'execute all custom'
  task :execute_all_custom, [:fhir_version, :output] do |t, args|
    FHIR.logger = Logger.new("logs/plan_executor.log", 10, 1024000)
    require 'benchmark'
    fhir_version = resolve_fhir_version(args.fhir_version)

    puts "# #{args.test}"
    puts

    seconds = 0.0

    FHIR_SERVERS.each do |url|
      puts "## #{url}"
      puts "```"
      b = Benchmark.measure {
        client = FHIR::Client.new(url)
        client.use_fhir_version(fhir_version)
        client.setup_security
        results = execute_all(url, client, output)
      }
      seconds += b.real
      puts "```"
      puts
    end
    puts "Execute All Custom #{args.test} completed for #{FHIR_SERVERS.length} servers in #{seconds} seconds."
  end

  desc 'list all'
  task :list_all, [:fhir_version] do |t, args|
    require 'benchmark'
    b = Benchmark.measure do 
      tests = Crucible::Tests::Executor.list_all

      tests = tests.select{|k,t| t['supported_versions'].include?(resolve_fhir_version(args.fhir_version))} if !args.fhir_version.nil?

      tests.each do |k, v| 
        puts "#{k} (#{v['supported_versions'].join(',')})"; 
        v['tests'].each{|t| puts "\t#{t.to_s}"}
      end
    end

    puts "List all tests completed in #{b.real} seconds."
  end

  desc 'list names of test suites'
  task :list_suites, [:fhir_version] do |t, args|
    require 'benchmark'
    b = Benchmark.measure do
      suites = Crucible::Tests::Executor.list_all
      suite_names = []
      suites.each do |key,value|
        suite_names << value['author'].split('::').last if !key.start_with?('TS') && (args.fhir_version.nil? || value['supported_versions'].include?(resolve_fhir_version(args.fhir_version)))
      end
      suite_names.uniq!
      suite_names.each {|x| puts "  #{x}"}
    end
    puts "List all suites completed in #{b.real} seconds."
  end

  desc 'list all test scripts'
  task :list_testscripts do
    require 'benchmark'
    b = Benchmark.measure { puts Crucible::Tests::TestScriptEngine.list_all.keys }
    puts "List all tests completed in #{b.real} seconds."
  end

  desc 'execute with requirements'
  task :execute_w_requirements, [:url, :fhir_version, :test, :resource, :html_summary] do |t, args|
    FHIR.logger = Logger.new("logs/plan_executor.log", 10, 1024000)
    require 'ansi'
    fhir_version = resolve_fhir_version(args.fhir_version)

    module Crucible
      module Tests
        class BaseTest

          alias execute_test_method_orig execute_test_method

          def execute_test_method(test_method)
            r = execute_test_method_orig(test_method)
            @@requirements ||= {}
            @@requirements[self.class.name] ||= {}
            @@requirements[self.class.name][test_method] = @client.requirements
            @client.clear_requirements
            r
          end

        end
      end
    end

    client = FHIR::Client.new(args.url)
    client.use_fhir_version(fhir_version)
    client.setup_security
    client.monitor_requirements
    test = args.test.to_sym
    execute_test(args.url, client, test, args.resource, args.html_summary)
    pp Crucible::Tests::BaseTest.class_variable_get :@@requirements
  end

  def write_result(status, test_name, message)
    tab_size = 10
    "#{' '*(tab_size - status.length)}#{colorize(status)} #{test_name}: #{message}"
  end

  def colorize(status)
    case status.upcase
    when 'PASS'
      ANSI.green{ status.upcase }
    when 'SKIP'
      ANSI.blue{ status.upcase }
    when 'FAIL'
      ANSI.red{ status.upcase }
    else
      ANSI.white_on_red{ status.upcase }
    end
  end

  desc 'update fixtures from spec'
  task :update_fixtures, [:publish_folder] do |t, args|

    # open publish folder
    # open fixtures
    # go through each folder within fixtures
    # if file exists in publish folder, replace it

    root = File.expand_path '../..', File.dirname(File.absolute_path(__FILE__))
    fixtures = File.join(root, 'fixtures')
    publish = File.join(args.publish_folder)

    files = Dir.glob(File.join(fixtures, '**', '*.xml'))
    files.each do |file|
      basename = File.basename(file)
      updated_file = File.join(publish, basename)
      if File.exists?(updated_file)
        puts "Updating Fixture: #{basename}..."
        FileUtils.copy updated_file, file 
      else
        puts "Unable to update fixture: #{basename}"
      end
    end

  end

end
