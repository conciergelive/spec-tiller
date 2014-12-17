namespace :spec_tiller do
  desc 'Compares spec files in travis.yml to current list of spec files, and syncs accordingly'
  task :sync do
    require "spec_tiller"
    content = YAML::load(File.open('.travis.yml'))
    current_file_list = Dir.glob('spec/**/*_spec.rb').map { |file_path| file_path.slice(/(spec\/\S+$)/) }
    puts "\nSyncing list of spec files..."
    if content["env"]["matrix"]
      SyncSpecFiles.rewrite_travis_content(content, current_file_list) do |content, original, current_file_list|
        File.open('.travis.yml', 'w') { |file| file.write(content.to_yaml(:line_width => -1)) }
        puts SyncSpecFiles.file_diff(original, current_file_list)
      end
    end
  end

  desc 'Runs whole test suite and redistributes spec files across builds according to file run time'
  task :redistribute => :environment do
    require "spec_tiller"
    travis_yml_file = YAML::load(File.open('.travis.yml'))
    file_path = "spec/log/rspec_profile_output.txt"
    `rm -f #{file_path}`
    `touch #{file_path}`
    `bundle exec rspec --profile 1000000000 > #{file_path}`
    profile_results = open(file_path).read
    TravisBuildMatrix::SpecDistributor.new(travis_yml_file, profile_results) do |content|
      File.open('.travis.yml', 'w') { |file| file.write(content.to_yaml(:line_width => -1)) }
    end
  end
end