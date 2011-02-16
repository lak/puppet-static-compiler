# Download a specified file into the local filebucket.
Puppet::Interface::File.action :download do |*args|
  Puppet::FileBucket::File.indirection.terminus_class = :rest

  sum = args.shift or raise "Must specify checksum"

  tester = Object.new
  tester.extend(Puppet::Util::Checksums)

  type = tester.sumtype(sum)
  sum = tester.sumdata(sum)

  raise "Could not download content for '#{sum}'" unless file = Puppet::FileBucket::File.indirection.find("#{type}/#{sum}")

  Puppet::FileBucket::File.indirection.terminus_class = :file
  Puppet::FileBucket::File.indirection.save file
end

