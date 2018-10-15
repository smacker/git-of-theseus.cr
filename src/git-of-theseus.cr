require "option_parser"
require "git"
require "./git-of-theseus/*"

# defaults
interval = 7*24*60*60
outdir = "."
branch = "refs/heads/master"
path = ""

OptionParser.parse! do |parser|
  parser.banner = "Usage: git-of-theseus.cr [repo]"
  parser.on("--interval=INT", "Min difference between commits to analyze (default: #{interval})") { |v| interval = v.to_i }
  parser.on("--outdir=PATH", "Output directory to store results (default: #{outdir})") { |v| outdir = v }
  parser.on("--branch=NAME", "Branch to track (default: #{branch})") { |v| branch = v }
  parser.on("-h", "--help", "Show this help") { puts parser }
  parser.unknown_args do |before_dash, after_dash|
    if before_dash.size == 1
      path = before_dash[0]
    else
      puts parser
      raise ArgumentError.new("incorrect arguments")
    end
  end
end

module GitOfTheseus
  repo = Git::Repo.open(path)
  a = Analyzer.new(repo, interval, branch)

  Dir.mkdir_p(outdir)

  ["cohort", "author", "ext"].each do |name|
    File.write(File.join(outdir, "#{name}s.json"), a.make_json(name))
  end

  File.write(File.join(outdir, "survival.json"), a.make_json("survival"))
end
