namespace :crucible do
  desc 'Generate the R4B FHIR structure index from the official definitions archive'
  task :generate_r4b_structure, [:definitions_archive] do |_task, args|
    unless args.definitions_archive
      raise 'Usage: rake "crucible:generate_r4b_structure[path/to/r4b-definitions.json.zip]"'
    end

    root = File.expand_path('../..', __dir__)
    Crucible::FHIRStructureGenerator.write_from_archive(
      File.expand_path(args.definitions_archive),
      File.join(root, 'lib', 'FHIR_structure_r4.json'),
      File.join(root, 'lib', 'FHIR_structure_r4b.json')
    )
  end
end
