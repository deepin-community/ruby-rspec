require 'fileutils'

$AUTOPKGTEST = ENV.include?("AUTOPKGTEST_TMP")

def banner(title, c = '∙')
  puts
  puts c * (title.length + 4)
  puts "%s %s %s" % [c, title, c]
  puts c * (title.length + 4)
  puts
end

def maybe_move_away(path)
  if $AUTOPKGTEST
    FileUtils::Verbose.mv(path, path + '.off')
    begin
      yield
    ensure
      FileUtils::Verbose.mv(path + '.off', path)
    end
  else
    yield
  end
end

def run(cmd)
  puts(cmd)
  maybe_move_away('lib') do
    system(cmd)
  end
end

arch = `dpkg --print-architecture`.strip

LIBS = %w{rspec-core rspec-expectations rspec-mocks rspec-support}

if $AUTOPKGTEST
  excludes_pattern = "debian/tests/excludes/{all,autopkgtest,%s}" % arch
else
  excludes_pattern = "debian/tests/excludes/{all,%s}" % arch

  ENV["PATH"] = [File.expand_path("rspec-core/exe"), ENV["PATH"]].join(':')
  puts "PATH=#{ENV['PATH']}"
  #  ________________________________________________________________________
  # /                                                                        \
  # | ALL THIS CAN BE REMOVED AFTER THE PREVIOUS VERSION OF RSPEC USING THE  |
  # | VENDOR LAYOUT IS NO LONGER THERE.                                      |
  # |                                                                        |
  rubylib = ENV.fetch('RUBYLIB', 'debian')
  LIBS.each do |lib|
    rubylib += ":" + File.expand_path(File.join(lib, 'lib'))
  end
  puts "RUBYLIB=#{rubylib}"
  ENV['RUBYLIB'] = rubylib
  # |                                                                        |
  # \________________________________________________________________________/



end

ENV['NO_COVERAGE'] = 'yes'
# disable for now error highlighting with ruby3.1 (#1019664)
if RUBY_VERSION.to_f >= 3.1
  ENV['RUBYOPT'] = "#{ENV['RUBYOPT']} --disable-error_highlight"
end

failed = []
LIBS.each do |lib|
  excludes = []
  Dir.glob(File.join(excludes_pattern, lib)).each do |f|
    excludes += File.readlines(f).map(&:strip)
  end
  banner lib

  FileUtils::Verbose.chdir(lib) do
    files = Dir['spec/**/*_spec.rb'] - excludes
    testcmd = '%s -S rspec %s' % [RbConfig.ruby, files.join(' ')]
    failed << lib unless run(testcmd)
  end
end

unless failed.empty?
  puts "Failed: %s" % failed.join(', ')
  exit(1)
end
