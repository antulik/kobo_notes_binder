require_relative 'runner'
require 'optparse'

class KoboNotesBinder::Cli
  def start(argv)
    argv = argv.dup
    defaults = {
      kobo_device_path: '/Volumes/KOBOeReader',
      output_folder: '~/Desktop',

      # Dev data
      # tmp_dir: '/Users/anton/projects/kobo_notes_binder/tmp/tmp_dir',
      # local_kobo_db_path: '/Users/anton/projects/ank/tmp/tmp_dir/KoboReader.sqlite',
      # local_original_epub_path: '/Users/anton/projects/ank/tmp/tmp_dir/Nine Lies About Work_ A Freethinking Leader’s Guide to the Real World.kepub.epub',
      # volume_url: "file:///mnt/onboard/kepub/Nine Lies About Work_ A Freethinking Leader’s Guide to the Real World.kepub.epub"
    }
    options = parse(argv, defaults)
    puts options

    runner = KoboNotesBinder::Runner.new(options, kobo_device_path: options[:kobo_device_path])
    tmp_epub_path = runner.execute

    puts 'Moving book to desktop'

    new_epub_path = File.expand_path(options[:output_folder]) + '/' + File.basename(tmp_epub_path)
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

      opts.on("-kPATH", "--kobo=PATH",
        "Path to kobo device. Default: #{options[:kobo_device_path]}") do |v|
        options[:kobo_device_path] = v
      end
      opts.on("-oPATH", "--output=PATH", "Output folder. Default: #{options[:output_folder]}") do |v|
        options[:output_folder] = v
      end
      opts.on("-p", "--open", "Open file at the end") do |v|
        options[:open] = v
      end
      opts.on("-aNAME", "--application=NAME", "Application name to open epub") do |v|
        options[:application_name] = v
      end
      opts.on("-d", "--debug", "Enable debug mode") do |v|
        options[:debug_mode] = v
      end
      opts.on("-v", "--[no-]verbose", "Run verbosely") do |v|
        options[:verbose] = v
      end
    end.parse!(argv)

    options
  end

end
