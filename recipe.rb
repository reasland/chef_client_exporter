directory "/usr/lib/node_exporter-#{node['dvo_user']['monitor']['linux']['version']}.linux-amd64/collector" do
  owner 'nobody'
  recursive true
  action :create
end

file "/usr/lib/node_exporter-#{node['dvo_user']['monitor']['linux']['version']}.linux-amd64/collector/chef-client.prom" do
  owner 'nobody'
  action :create
end


remote_file "#{Chef::Config[:file_cache_path]}/node_exporter.tar.gz" do
  source "https://github.com/prometheus/node_exporter/releases/download/v#{node['dvo_user']['monitor']['linux']['version']}/node_exporter-#{node['dvo_user']['monitor']['linux']['version']}.linux-amd64.tar.gz"
  action :create
  not_if { Dir.exist?("/usr/lib/node_exporter-#{node['dvo_user']['monitor']['linux']['version']}.linux-amd64") }
end

execute 'install node_exporter' do
  command 'tar -C /usr/lib/ -xzvf node_exporter.tar.gz'
  cwd Chef::Config[:file_cache_path]
  action :run
  not_if { Dir.exist?("/usr/lib/node_exporter-#{node['dvo_user']['monitor']['linux']['version']}.linux-amd64") }
end

systemd_unit 'node_exporter.service' do
  content(
  Unit: {
    Description: 'Prometheus Node Exporter Service',
    After: 'network.target',
  },
  Service: {
    Type: 'simple',
    ExecStart: "/usr/lib/node_exporter-#{node['dvo_user']['monitor']['linux']['version']}.linux-amd64/node_exporter --collector.textfile.directory=/usr/lib/node_exporter-#{node['dvo_user']['monitor']['linux']['version']}.linux-amd64/collector",
  },
  Install: {
    WantedBy: 'multi-user.target',
  })
  action [:delete, :create, :enable, :start]
end

chef_gem 'prometheus-client' do
  compile_time true
  action :install
end

path = "#{Chef::Config[:file_cache_path]}/prometheus_handler.rb"
textfile = "/usr/lib/node_exporter-#{node['dvo_user']['monitor']['linux']['version']}.linux-amd64/collector/chef-client.prom"

cookbook_file path do
  source 'prometheus_handler.rb'
  mode '0755'
  action :create
end

chef_handler 'PrometheusHandler' do
  source path
  arguments [textfile]
  action :enable
end
