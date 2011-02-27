require 'puppet/interface'

Puppet::Interface.new :plugin do
  # Download all plugins.
  Puppet::Interface::Plugin.action :download do |*args|
    require 'puppet/configurer/downloader'
    Puppet::Configurer::Downloader.new("plugin", Puppet[:plugindest], Puppet[:pluginsource], Puppet[:pluginsignore]).evaluate

    nil
  end
end
