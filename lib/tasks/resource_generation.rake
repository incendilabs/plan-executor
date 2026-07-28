namespace :crucible do
  desc 'Audit repeated generation of every concrete FHIR R5 resource'
  task :audit_r5_resource_generation,
       [:output_dir, :seed, :iterations, :resource, :depth, :iteration] do |_task, args|
    options = {}
    options[:output_dir] = args.output_dir if args.output_dir
    options[:seed] = Integer(args.seed) if args.seed
    options[:iterations] = Integer(args.iterations) if args.iterations
    options[:resources] = [args.resource] if args.resource
    options[:depths] = [Integer(args.depth)] if args.depth
    options[:iteration_indices] = [Integer(args.iteration)] if args.iteration

    result = Crucible::Tests::R5ResourceGenerationAudit.new(**options).run
    puts result.summary
    result.failures.each { |failure| $stderr.puts failure.summary }
    raise "#{result.failures.length} R5 resource generation case(s) failed" unless result.success?
  end
end
