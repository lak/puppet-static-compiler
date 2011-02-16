# Download a specified file into the local filebucket.
Puppet::Interface::File.action :download do |*args|

  sum = args.shift or raise "Must specify checksum"

  if sum =~ /^puppet:\/\// # it's a puppet url
    require 'puppet/file_serving'
    require 'puppet/file_serving/content'
    Puppet.info "Downloading content from URL"
    raise "Could not find metadata for #{sum}" unless content = Puppet::FileServing::Content.find(sum)
    file = Puppet::FileBucket::File.new(content.content)
  else
    Puppet.info "Downloading content via checksum"
    Puppet::FileBucket::File.indirection.terminus_class = :rest

    tester = Object.new
    tester.extend(Puppet::Util::Checksums)

    type = tester.sumtype(sum)
    sum = tester.sumdata(sum)

    raise "Could not download content for '#{sum}'" unless file = Puppet::FileBucket::File.indirection.find("#{type}/#{sum}")
  end

  Puppet::FileBucket::File.indirection.terminus_class = :file
  Puppet::FileBucket::File.indirection.save file
end

