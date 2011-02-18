require 'puppet/node'
require 'puppet/resource/catalog'
require 'puppet/indirector/code'

class Puppet::Resource::Catalog::StaticCompiler < Puppet::Indirector::Code
  def compiler
    @compiler ||= indirection.terminus(:compiler)
  end

  def find(request)
    return nil unless catalog = compiler.find(request)

    raise "Did not get catalog back" unless catalog.is_a?(model)

    catalog.resources.find_all { |res| res.type == "File" }.each do |resource|
      next unless source = resource[:source]
      next unless source =~ /^puppet:/

      file = resource.to_ral
      if file.recurse?
        add_children(catalog, resource, file)
      else
        find_and_replace_metadata(resource, file)
      end
    end

    catalog
  end

  def find_and_replace_metadata(resource, file)
    raise "Could not get metadata for #{resource[:source]}" unless metadata = file.parameter(:source).metadata

    add_metadata(resource, metadata)
  end

  def replace_metadata(resource, metadata)
    Puppet.notice "Adding metadata for #{resource} from #{resource[:source]}"

    [:mode, :owner, :group].each do |param|
      resource[param] ||= metadata.send(param)
    end

    resource[:ensure] = metadata.ftype
    if metadata.ftype == "file"
      unless resource[:content]
        resource[:content] = metadata.checksum
        resource[:checksum] = metadata.checksum_type
      end
    end

    store_content(resource) if resource[:ensure] == "file"
    resource.delete(:source)
  end

  def add_children(catalog, resource, file)
    file = resource.to_ral

    children = get_child_resources(catalog, resource, file)

    remove_existing_resources(children, catalog)

    children.each do |name, res|
      catalog.add_resource res
      catalog.add_edge(resource, res)
    end
  end

  def get_child_resources(catalog, resource, file)
    sourceselect = file[:sourceselect]
    children = {}

    source = resource[:source]

    # This is largely a copy of recurse_remote in File
    total = file[:source].collect do |source|
      next unless result = file.perform_recursion(source)
      return if top = result.find { |r| r.relative_path == "." } and top.ftype != "directory"
      result.each { |data| data.source = "#{source}/#{data.relative_path}" }
      break result if result and ! result.empty? and sourceselect == :first
      result
    end.flatten

    # This only happens if we have sourceselect == :all
    unless sourceselect == :first
      found = []
      total.reject! do |data|
        result = found.include?(data.relative_path)
        found << data.relative_path unless found.include?(data.relative_path)
        result
      end
    end

    total.each do |meta|
      # This is the top-level parent directory
      if meta.relative_path == "."
        replace_metadata(resource, meta)
        next
      end
      children[meta.relative_path] ||= Puppet::Resource.new(:file, File.join(file[:path], meta.relative_path))

      # I think this is safe since it's a URL, not an actual file
      children[meta.relative_path][:source] = source + "/" + meta.relative_path
      replace_metadata(children[meta.relative_path], meta)
    end

    children
  end

  def remove_existing_resources(children, catalog)
    existing_names = catalog.resources.collect { |r| r.to_s }

    both = (existing_names & children.keys).inject({}) { |hash, name| hash[name] = true; hash }
    
    both.each { |name| children.delete(name) }
  end

  def store_content(resource)
    @summer ||= Object.new
    @summer.extend(Puppet::Util::Checksums)

    type = @summer.sumtype(resource[:content])
    sum = @summer.sumdata(resource[:content])

    if Puppet::FileBucket::File.find("#{type}/#{sum}")
      Puppet.info "Content for '#{resource[:source]}' already exists"
    else
      Puppet.info "Storing content for source '#{resource[:source]}'"
      content = Puppet::FileServing::Content.find(resource[:source])
      Puppet::FileBucket::File.new(content.content).save
    end
  end
end
