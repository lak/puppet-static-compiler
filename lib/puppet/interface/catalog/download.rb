require 'puppet/interface/file'

# Download a new catalog, with one new behavior:
# make sure all of the specified files are also
# downloaded.
Puppet::Interface::Catalog.action :download do |*args|
  Puppet::Resource::Catalog.indirection.terminus_class = :rest

  host = args.shift or raise "Must specify hostname"
  raise "Could not download catalog for '#{host}'" unless catalog = Puppet::Resource::Catalog.indirection.find(host)

  bucket = Puppet::Interface::File.new

  # For every checksum mentioned in the catalog, make sure they're in our local filebucket.
  catalog.resources.find_all { |res| res.type == "File" }.each do |resource|
    next unless resource[:content] and resource[:content] =~ /^\{\w+\}/

    checksum = resource[:content]

    Puppet.notice "Downloading content for #{resource} from '#{checksum}'"
    bucket.download(checksum)
  end

  Puppet::Resource::Catalog.indirection.terminus_class = :yaml
  Puppet::Resource::Catalog.indirection.save catalog
end
