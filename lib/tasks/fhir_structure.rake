namespace :crucible do
  desc 'Generate the R4B FHIR structure index from the official definitions archive'
  task :generate_r4b_structure, [:definitions_archive] do |_task, args|
    unless args.definitions_archive
      raise 'Usage: rake "crucible:generate_r4b_structure[path/to/r4b-definitions.json.zip]"'
    end

    Crucible::FHIRStructureGenerator.write_from_archive(
      Crucible::FHIRStructureGenerator::CONFIGURATIONS.fetch(:r4b),
      File.expand_path(args.definitions_archive)
    )
  end

  desc 'Generate the R5 FHIR structure index from the official definitions archive'
  task :generate_r5_structure, [:definitions_archive] do |_task, args|
    unless args.definitions_archive
      raise 'Usage: rake "crucible:generate_r5_structure[path/to/r5-definitions.json.zip]"'
    end

    Crucible::FHIRStructureGenerator.write_from_archive(
      Crucible::FHIRStructureGenerator::CONFIGURATIONS.fetch(:r5),
      File.expand_path(args.definitions_archive)
    )
  end
end
