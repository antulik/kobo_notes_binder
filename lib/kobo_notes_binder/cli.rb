require_relative 'runner'
require 'optparse'

class KoboNotesBinder::Cli
  def start(argv)
    argv = argv.dup
    defaults = {
      kobo_device_path: '/Volumes/KOBOeReader',
    }
    puts 'Parsing options'
    options = parse(argv, defaults)
    puts options

    runner = KoboNotesBinder::Runner.new(options, kobo_device_path: options[:kobo_device_path])
    tmp_epub_path = runner.execute

    puts 'Moving book to desktop'
    new_epub_path = File.expand_path('~/Desktop') + '/' + File.basename(tmp_epub_path)
    FileUtils.mv tmp_epub_path, new_epub_path

    if options[:open]
      cmd_args = ['open']

      if options[:application_name]
        cmd_args += ['-a', options[:application_name]]
      end

      puts 'Opening file'
      system *cmd_args, new_epub_path
    end
  end

  def parse(argv, defaults)
    options = {}.merge defaults
    OptionParser.new do |opts|
      opts.banner = "Usage: kobo_notes_binder [options]"

      opts.on("-kPATH", "--kobo=PATH", "Path to kobo device") do |v|
        options[:kobo_device_path] = v
      end
      opts.on("-o", "--open", "Open file at the end") do |v|
        options[:open] = v
      end
      opts.on("-aNAME", "--application=NAME", "Application name to open epub") do |v|
        options[:application_name] = v
      end
      opts.on("-v", "--[no-]verbose", "Run verbosely") do |v|
        options[:verbose] = v
      end
    end.parse!(argv)

    options
  end

end
