require 'yaml'

module SyncSpecFiles
  include BuildMatrixParser

  def rewrite_travis_content(content, current_file_list, &block)
    ignore_specs = get_ignored_specs(content)
    current_file_list = current_file_list.reject { |file_path| ignore_specs.include?(file_path) }
    env_matrix = BuildMatrixParser.parse_env_matrix(content)
    original = extract_spec_files(env_matrix)
    after_removed = delete_removed_files(original, current_file_list)
    after_added = add_new_files(original, after_removed, current_file_list)

    env_matrix.each do |var_hash|
      if var_hash.has_key?('TEST_SUITE')
        test_bucket = after_added.shift

        var_hash['TEST_SUITE'] = "#{test_bucket.join(' ')}"
      end
    end

    content['env']['matrix'] = BuildMatrixParser.format_matrix(env_matrix)

    block.call(content, original, current_file_list) if block
  end

  module_function :rewrite_travis_content

  def self.get_ignored_specs(content)
    ignore_specs = []
    content['env']['global'].each do |row|
      # Input: IGNORE_SPECS="spec/a.rb spec/b.rb"
      # Output: ['spec/a.rb spec/b.rb']
      matches = row.match(/IGNORE_SPECS="\s*([^"]+)"/)
      ignore_specs << matches[1].split(' ') unless matches.nil?
    end
    ignore_specs.flatten
  end

  private

    def self.extract_spec_files(env_matrix)
      test_suites = env_matrix.map do |var_hash|
        var_hash.has_key?('TEST_SUITE') ? var_hash['TEST_SUITE'].gsub('"', '').split(' ') : nil
      end
      test_suites.compact
    end

    def self.delete_removed_files(original, current_file_list)
      deleted_files = deleted_files(original, current_file_list)

      original.map do |bucket|
        bucket.reject { |spec_file| deleted_files.include?(spec_file) }
      end
    end

    def self.add_new_files(original, buckets, current_file_list)
      buckets_clone = buckets.map(&:dup)

      added_files(original, current_file_list).each do |spec_file|
        buckets_clone.last << spec_file
      end

      buckets_clone
    end

    def self.deleted_files(original, current_file_list)
      original.flatten - current_file_list
    end

    def self.added_files(original, current_file_list)
      current_file_list - original.flatten
    end

    def self.file_diff(original, current_file_list)
      removed_files = deleted_files(original, current_file_list).sort
      removed = removed_files.empty? ? 'No spec files removed' : removed_files

      added_files = added_files(original, current_file_list).sort
      added = added_files.empty? ? 'No spec files added' : added_files

      "  Removed: #{removed}\n  Added:   #{added}\n\n"
    end
end