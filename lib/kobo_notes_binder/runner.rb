require "active_record"

class KoboNotesBinder::Runner
  class Bookmark < ActiveRecord::Base
    self.table_name = :Bookmark
  end

  class Content < ActiveRecord::Base
    self.table_name = :content

    has_many :bookmarks, primary_key: :ContentID, foreign_key: :VolumeID
  end

  attr_accessor :kobo_device_path
  attr_accessor :tmp_dir
  attr_accessor :local_kobo_db_path
  attr_accessor :local_original_epub_path
  attr_accessor :volume_url
  attr_accessor :debug_mode

  def initialize(opts = {}, kobo_device_path:)
    @kobo_device_path = kobo_device_path
    @local_kobo_db_path = opts[:local_kobo_db_path]
    @local_original_epub_path = opts[:local_original_epub_path]
    @volume_url = opts[:volume_url]
    @tmp_dir = opts[:tmp_dir]
    @debug_mode = opts[:debug_mode]

    require "sqlite3"
    require "tty-prompt"
    require 'nokogiri'
    require 'fileutils'

    begin
      require 'pry-byebug'
    rescue LoadError
    end

    if tmp_dir.nil?
      puts 'Creating temporary folder'
      @tmp_dir = Dir.mktmpdir
      puts '  ' + tmp_dir
      at_exit do
        puts 'Cleaning up'
        FileUtils.remove_entry(tmp_dir)
      end
    end
  end

  def execute
    puts 'Device path ' + kobo_device_path

    if local_kobo_db_path.nil?
      puts 'Copying kobo database'
      local_kobo_db_path = copy_db kobo_device_path, dir: tmp_dir
    end

    puts 'Connecting to database'
    ActiveRecord::Base.establish_connection(
      adapter: 'sqlite3',
      database: local_kobo_db_path,
    )

    if local_original_epub_path.nil?
      book = pick_book
      puts 'Copying selected book'
      local_original_epub_path = copy_book(book, dir: tmp_dir, kobo_device_path: kobo_device_path)
    end

    puts 'Extracting book content'
    raw_epub_folder = extract_epub(local_original_epub_path, dir: tmp_dir)

    volume_url ||= book.ContentID
    puts "Notes volume id: #{volume_url}"

    puts 'Searching for book notes'
    notes = Bookmark.where(VolumeID: volume_url)
    puts "  Found #{notes.size} notes"

    if debug_mode
      puts 'Cloning raw folder'
      clone_raw_epub_folder = File.dirname(raw_epub_folder) + '/raw_original'
      FileUtils.rm_rf clone_raw_epub_folder
      FileUtils.cp_r raw_epub_folder, clone_raw_epub_folder
    end

    puts 'Embedding notes'
    notes.each do |note|
      process_note note, raw_epub_folder: raw_epub_folder
    end

    puts 'Binding book'
    new_epub_path = compile(volume_url: volume_url, tmp_dir: tmp_dir, raw_epub_folder: raw_epub_folder)

    puts 'Book is bound'
    new_epub_path
  end

  def file_path(note)
    volume_url = note.VolumeID

    # /mnt/onboard/kepub/Title.kepub.epub!OEBPS!17_Chapter.xhtml
    volume_path = volume_url.sub('file://', '')

    content_id = note.ContentID

    path = content_id.sub volume_path, ''
    path.gsub('!', '/').split('#', 2)[0]
  end

  def pick_book
    book_list = Content.joins(:bookmarks).group(:Title).order('Max(Bookmark.DateCreated) DESC')

    prompt = TTY::Prompt.new
    prompt.on(:keyescape) { exit }
    book = prompt.select(
      "What book would you like to export?", per_page: 7, filter: true
    ) do |menu|
      book_list.each do |book|
        menu.choice book.Title, book
      end
    end

    book
  end

  def copy_book(book, dir:, kobo_device_path:)
    volume_url = book.ContentID
    file_path = dir + "/" + File.basename(volume_url)
    FileUtils.cp(kobo_device_path + volume_url.sub('file:///mnt/onboard', ''), file_path)
    file_path
  end

  def extract_epub(path, dir:)
    raw_epub_folder = dir + '/raw'
    FileUtils.rm_rf raw_epub_folder
    system 'unzip', path, '-d', raw_epub_folder
    raw_epub_folder
  end

  def highlight_node(node)
    # wrap only when has content
    if node.content[/\S/]
      node.wrap("<span style='background-color: #FDE383;' class='kobo-notes-binder-highlight'></span>")
      node.parent
    else
      node
    end
  end

  def process_note(note, raw_epub_folder:)
    debug do
      puts
      puts 'processing note: '
      pp note
      nil
    end

    # Looks like `note.StartContainerChildIndex != -99` is for page bookmarks
    # We can skip them for now
    if note.StartContainerChildIndex != -99 || note.EndContainerChildIndex != -99
      debug { '  Skipping note' }
      return
    end

    xml_path = raw_epub_folder + file_path(note)
    xml_string = File.read(xml_path)

    doc = Nokogiri::XML(xml_string)
    start_node = doc.at_css note.StartContainerPath
    end_node = doc.at_css note.EndContainerPath

    # Find parent that includes both start and end
    parent = start_node
    loop do
      match = parent.to_enum(:traverse).find do |node|
        node == end_node
      end
      break if match
      parent = parent.parent
    end

    nodes = parent.to_enum(:traverse).to_a
    selected_nodes = nodes[nodes.index(start_node)...nodes.index(end_node)]

    # Append start text node, as it will be skipped
    selected_nodes = start_node.to_enum(:traverse).to_a + selected_nodes

    selected_nodes.select(&:text?).each do |node|
      # special case when the note is duplicate and was already changed
      next if node.previous_sibling && node.previous_sibling['class'] == 'kobo-notes-binder-highlight'

      at_start = node.parent == start_node
      at_end = node.parent == end_node

      start_offset = note.StartOffset
      end_offset = note.EndOffset

      content = node.content

      if at_start && at_end
        text_before = content[0...start_offset]
        text_highlight = content[start_offset...end_offset]
        text_after = content[end_offset..-1]
      elsif at_start
        text_before = content[0...start_offset]
        text_highlight = content[start_offset..-1]
        text_after = ''
      elsif at_end
        text_before = ''
        text_highlight = content[0...end_offset]
        text_after = content[end_offset..-1]
      else
        text_before = ''
        text_highlight = content
        text_after = ''
      end

      if note.BookmarkID == 'ee31725b-d579-4a69-972c-f0bdb740bcb1'
        # binding.pry
      end

      node.content = text_highlight

      if text_highlight.size > 0
        # need to be wrapped first, so sibling Text nodes won't be merged
        node = highlight_node(node)
      end

      if text_before.size > 0
        node.add_previous_sibling doc.create_text_node(text_before)
      end

      if text_after.size > 0
        node.add_next_sibling doc.create_text_node(text_after)
      end
    end

    File.write xml_path, doc.to_xhtml
  end

  def copy_db(kobo_device_path, dir:)
    kobo_db_path = kobo_device_path + '/.kobo/KoboReader.sqlite'
    db_path = dir + '/KoboReader.sqlite'
    FileUtils.rm_rf db_path
    puts "  Coping from " + kobo_db_path
    puts "  Coping to " + db_path
    FileUtils.cp(kobo_db_path, db_path)
    db_path
  end

  def compile(volume_url:, tmp_dir:, raw_epub_folder:)
    epub_file = tmp_dir + '/' + File.basename(volume_url).sub('.', '.highlights.')

    files = *Dir[raw_epub_folder + '/*']

    # move mimetype to be first
    mime_path = files.find { |path| File.basename(path) == 'mimetype' }
    files.delete mime_path
    files.unshift mime_path

    files = files.map { |path| Pathname.new(path).relative_path_from(raw_epub_folder).to_s }

    FileUtils.cd raw_epub_folder do
      system 'zip', '-rX', epub_file, *files
    end

    epub_file
  end

  def debug
    if debug_mode
      result = yield
      if result === String
        puts result
      end
    end
  end
end



