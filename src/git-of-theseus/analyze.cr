require "json"

module GitOfTheseus
  alias HItem = Hash(Tuple(String, String), Int32)

  class Analyzer
    def initialize(@repo : Git::Repo, interval, branch)
      data_commits = Array(Git::Commit).new
      master_commits = Array(Git::Commit).new

      @commit2cohort = Hash(String, String).new
      @commit2timestamp = Hash(String, Int64).new

      @curves_set = Set(Tuple(String, String)).new
      @curves = Hash(Tuple(String, String), Array(Int32)).new

      branch_head = @repo.branches[branch].target_id

      puts "Listing all commits"
      walker = Git::RevWalk.new(@repo)
      walker.push(branch_head)
      walker.each do |commit|
        epoch_time = commit.epoch_time
        cohort = Time.epoch(epoch_time).year.to_s
        sha = commit.sha
        @commit2cohort[sha] = cohort
        @curves_set.add({"cohort", cohort})
        @curves_set.add({"author", commit.author.name})
        if commit.parent_count == 1
          data_commits.push(commit)
          @commit2timestamp[sha] = epoch_time
        end
      end

      puts "Backtracking the master branch"
      i, commit = 0, @repo.head.target.as(Git::Commit)
      last_time = nil
      while true
        parents = commit.parent_count
        break if parents == 0

        epoch_time = commit.epoch_time
        if last_time.nil? || epoch_time < last_time - interval
          master_commits.push(commit)
          last_time = epoch_time
        end
        i, commit = i + 1, commit.parent
      end

      puts "Filtering and counting total entries to analyze"
      entries_ok = Hash(String, Bool).new
      entries_total = 0
      master_commits.reverse.each do |commit|
        commit.tree.walk_blobs do |root, e|
          ignore = ignore_entry(e)
          entries_ok[root + e.name] = !ignore

          if !ignore
            ext = File.extname(e.name)
            @curves_set.add({"ext", ext})

            entries_total += 1
          end

          false
        end
      end
      puts "Total entries: #{entries_total}"

      @ts = [] of Time
      last_commit_tree = nil
      file_histograms = Hash(String, HItem).new
      @commit_history = Hash(String, Array(Tuple(Int64, Int32))).new

      puts "Analyzing commit history"
      master_commits.reverse.each do |commit|
        @ts.push(commit.time)

        changed_files = Set(String).new
        commit.tree.diff(last_commit_tree).each_delta do |delta|
          changed_files.add(delta.old_file.path) if delta.old_file
          changed_files.add(delta.new_file.path) if delta.new_file
        end
        last_commit_tree = commit.tree

        histogram = Hash(Tuple(String, String), Int32).new
        commit.tree.walk_blobs do |root, e|
          path = root + e.name
          if entries_ok[path]
            if changed_files.includes?(path) || !file_histograms.has_key?(path)
              file_histograms[path] = get_file_histogram(commit, path)
            end
            file_histograms[path].each do |key, count|
              histogram[key] = histogram.fetch(key, 0) + count
            end
          end
          false
        end

        histogram.each do |key, count|
          key_type, key_item = key
          if key_type == "sha"
            if @commit_history.has_key?(key_item)
              val = @commit_history[key_item]
            else
              val = Array(Tuple(Int64, Int32)).new
            end
            val.push({commit.epoch_time, count})
            @commit_history[key_item] = val
          end
        end

        @curves_set.each do |key|
          @curves[key] = [] of Int32 if !@curves.has_key?(key)
          @curves[key].push(histogram.fetch(key, 0))
        end
      end
    end

    def get_file_histogram(commit : Git::Commit, path : String)
      h = HItem.new

      begin
        Git::Blame.new(@repo, path, newest_commit: commit.oid).each do |hunk|
          orig_commit_id = hunk.orig_commit_id.to_s
          cohort = @commit2cohort.fetch(orig_commit_id, "MISSING")
          orig_commit = @repo.lookup_commit(hunk.orig_commit_id)
          keys = [{"cohort", cohort}, {"ext", File.extname(path)}, {"author", orig_commit.author.name}]
          keys.push({"sha", orig_commit_id}) if @commit2timestamp.has_key?(orig_commit_id)

          keys.each do |key|
            h[key] = h.fetch(key, 0) + hunk.lines_in_hunk
          end
        end
      rescue ex
        puts ex.message
      end

      h
    end

    def ignore_entry(entry : Git::TreeEntry)
      @repo.lookup_blob(entry.oid).is_binary
    end

    def make_json(key_type : String)
      if key_type == "survival"
        @commit_history.to_json
      else
        key_items = @curves_set.select { |t, k| t == key_type }.map { |t, k| k }.sort
        JSON.build do |json|
          json.object do
            json.field "y", key_items.map { |key_item| @curves[{key_type, key_item}] }
            json.field "ts", @ts.map(&.to_rfc3339)
            json.field "labels", key_items
          end
        end
      end
    end
  end
end
