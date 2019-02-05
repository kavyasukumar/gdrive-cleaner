require 'google/apis/drive_v3'
require './lib/base_cli'
require 'dotenv'
require 'pry'
require 'json'
require 'active_support/all'

Drive = Google::Apis::DriveV3
Dotenv.load

@drive = Drive::DriveService.new
@cli = BaseCli.new
@drive.authorization = @cli.user_credentials_for(Drive::AUTH_DRIVE)
REVIEWED_FOLDER = '1BPxfAOhM_-PJ3bl7IbeAtRMa26ieRKBh'
FIELDS = 'id, name, shared, permissions, owners, webViewLink, originalFilename,mimeType, parents'
QUERY = "trashed=false and 'me' in owners and mimeType != 'application/vnd.google-apps.folder'"

@mime_map = JSON.parse(File.read('./exportmimes.json'))
@extension_map = JSON.parse(File.read('./exportextension.json'))

def list(query)
  files = []
  page_token = nil
  limit = 1000
  begin
    result = @drive.list_files(q: query,
                              page_size: [limit, 100].min,
                              page_token: page_token,
                              fields: "files(#{FIELDS}),next_page_token")

    files += result.files
    limit -= result.files.length
    if result.next_page_token
      page_token = result.next_page_token
    else
      page_token = nil
    end
  end while !page_token.nil? && limit > 0
  files
end

def delete_file(file_id)
  @drive.delete_file(file_id)
end

def export_mime(file_mime)
  @mime_map[file_mime] || 'application/zip'
end

def export_extension(file_mime)
  @extension_map[file_mime] || 'zip'
end

def download_file(file)
  dest_folder = './downloaded/'

  if file.original_filename
    name = file.original_filename
    dest = dest_folder + name
    i = 0
    while File.exist? dest
      i += 1
      dest = dest_folder + name + i
    end
    @drive.get_file(file_id, download_dest: dest)
    @cli.say "Downloaded file to #{dest}"
  else
    mime = export_mime file.mime_type
    ext = export_extension file.mime_type
    dest = dest_folder + file.name.parameterize + '.' + ext
    i = 0
    while File.exist? dest
      i += 1
      dest = dest_folder + file.name.parameterize + '.' + ext
    end
    output = File.open(dest, 'w') do |output|
      @drive.export_file(file.id, mime, download_dest: output)
    end
  end
end

def print_deets(file)
  @cli.say "\n------------------\n"
  @cli.say "Name: #{file.name}"
  @cli.say "Shared: #{file.shared}"
  @cli.say "Link: #{file.web_view_link}"
  if file.shared
    @cli.say "Owners: #{file.owners.map {|a| a.display_name}.join(',')}"
    permissions = file.permissions.
   map { |a|"#{a.display_name} | #{a.role}" }
   .join("\n")
   @cli.say "Permissions: #{file.permissions.count} permissions \n #{permissions}"
 end
 @cli.say "\n------------------\n"
end



def ask_options
  @cli.say "OPTIONS"
  @cli.say "-------"
  @cli.say "1. Keep"
  @cli.say "2. Delete"
  @cli.say "3. Download"
  @cli.say "4. Show details"
  @cli.ask "What do you want to do?"
end

# list all files created by me but now shared with anyone else
files = list(QUERY)
total = files.count
files.each do |file|
  next if file.parents.include? REVIEWED_FOLDER
  exit_loop = false
  print_deets(file)
  while !exit_loop do
    opt = ask_options

    case opt
    when '1'
      exit_loop = true
    when '2'
      delete_file(file.id)
      exit_loop = true
    when '3'
      download_file(file)
    when '4'
      print_deets(file)
    else
      @cli.say "not a valid option"
    end
    @drive.update_file(file.id, add_parents: REVIEWED_FOLDER) if exit_loop && opt != '2'
  end
end
