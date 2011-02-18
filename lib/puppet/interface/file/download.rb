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

    tester = Object.new
    tester.extend(Puppet::Util::Checksums)

    type = tester.sumtype(sum)
    sumdata = tester.sumdata(sum)

    key = "#{type}/#{sumdata}"

    Puppet::FileBucket::File.indirection.terminus_class = :file
    if Puppet::FileBucket::File.find(key)
      Puppet.info "Content for '#{sum}' already exists"
      return
    end

    Puppet::FileBucket::File.indirection.terminus_class = :rest
    raise "Could not download content for '#{sum}'" unless file = Puppet::FileBucket::File.indirection.find(key)
  end


  Puppet::FileBucket::File.indirection.terminus_class = :file
  Puppet::FileBucket::File.indirection.save file
end

