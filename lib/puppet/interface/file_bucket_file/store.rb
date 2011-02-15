# Store a specified file in our filebucket.
Puppet::Interface::File_bucket_file.action :store do |*args|
  path = args.shift or raise "Must specify file"

  file = Puppet::FileBucket::File.new(File.read(path))

  Puppet::FileBucket::File.indirection.terminus_class = :file
  Puppet::FileBucket::File.indirection.save file
  file.checksum
end
