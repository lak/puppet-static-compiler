require 'puppet/node'
require 'puppet/resource/catalog'
require 'puppet/indirector/code'

class Puppet::Resource::Catalog::Newcompiler < Puppet::Indirector::Code
  def compiler
    @compiler ||= indirection.terminus(:compiler)
  end

  def find(request)
    return nil unless catalog = compiler.find(request)

    raise "Did not get catalog back" unless catalog.is_a?(model)

    catalog.resources.find_all { |res| res.type == "File" }.each do |resource|
      replace_metadata(resource)
    end

    catalog
  end

  def replace_metadata(resource)
    return unless source = resource[:source]
    return unless source =~ /^puppet:/

    file = resource.to_ral

    raise "Could not get metadata for #{source}" unless metadata = file.parameter(:source).metadata

    Puppet.notice "Adding metadata for #{resource} from #{source}"

    [:mode, :owner, :group].each do |param|
      resource[param] ||= metadata.send(param)
    end
    unless file[:content]
      resource[:content] = metadata.checksum
      resource[:checksum] = metadata.checksum_type
    end

    resource.delete(:source)
  end
end
