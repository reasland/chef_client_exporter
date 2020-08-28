require 'chef/handler'
require 'chef/handler/error_report'
require 'prometheus/client'
require 'prometheus/client/formats/text'

class PrometheusHandler < Chef::Handler::ErrorReport
  attr_reader :textfile, :prometheus

  JOB = 'chef_client'

  def initialize(textfile)
    @textfile = textfile
    @prometheus = Prometheus::Client.registry
  end

  def report
    labels = { chef_environment: node.chef_environment || 'unknown' }
    puts "Starting Metrics Gathering"

    collect_time_metrics(labels)
    collect_node_roles(labels)
    collect_node_tags(labels)
    collect_node_runlist(labels)
    exception ? collect_error_metrics(labels) : collect_resource_metrics(labels)

    if textfile
      File.write(textfile, Prometheus::Client::Formats::Text.marshal(prometheus))
    end
  rescue => ex
    Chef::Log.error("PrometheusHandler: #{ex.inspect}")
  end

  private

  def collect_time_metrics(labels)
    puts "Getting Chef Client run Metrics"
    chef_client_duration_ms = Prometheus::Client::Gauge.new(:chef_client_duration_ms, docstring: 'duration of chef_client run in ms', labels: [:chef_environment])
    chef_client_duration_ms.set(run_status.elapsed_time * 1e+3, labels: labels)
    prometheus.register(chef_client_duration_ms)

    chef_client_last_run_timestamp_seconds = Prometheus::Client::Gauge.new(:chef_client_last_run_timestamp_seconds, docstring: 'time in epoch since the last chef_client run', labels: [:chef_environment])
    chef_client_last_run_timestamp_seconds.set(run_status.end_time.to_i, labels: labels)
    prometheus.register(chef_client_last_run_timestamp_seconds)
  end

  def collect_error_metrics(labels)
    puts "Chef Client error; capturing errors"
    chef_client_errors_count = Prometheus::Client::Gauge.new(:chef_client_errors_count, docstring: 'Total count of chef_client run errors', labels: [:chef_environment])
    chef_client_errors_count.set(1, labels: labels)
    prometheus.register(chef_client_errors_count)
  end

  def collect_resource_metrics(labels)
    puts "Capturing Chef Resource Data"
    chef_client_resources_count = Prometheus::Client::Gauge.new(:chef_client_resources_count, docstring: 'Total amount of resources', labels: [:chef_environment])
    chef_client_resources_count.set(run_status.all_resources.size, labels: labels)
    prometheus.register(chef_client_resources_count)

    chef_client_updated_resources_count = Prometheus::Client::Gauge.new(:chef_client_updated_resources_count, docstring: 'Total amount of resources updated in 1 chef_client run', labels: [:chef_environment])
    chef_client_updated_resources_count.set(run_status.updated_resources.size, labels: labels)
    prometheus.register(chef_client_updated_resources_count)
  end

  def collect_node_roles(labels)
    puts "Capturing Chef Node Roles"
    chef_client_roles = Prometheus::Client::Gauge.new(:chef_client_roles, docstring: 'Chef Client Roles', labels: [:role, :chef_environment])
    node['roles'].each do |role|
      chef_client_roles.set(1, labels: {role: role }.merge(labels))
    end
    prometheus.register(chef_client_roles)
  end

  def collect_node_tags(labels)
    puts "Capturing Chef Node Tags"
    chef_client_tags = Prometheus::Client::Gauge.new(:chef_client_tags, docstring: 'Chef Client Tags', labels: [:tag, :chef_environment])
    node['tags'].each do |tag|
      chef_client_tags.set(1, labels: {tag: tag }.merge(labels))
    end
    prometheus.register(chef_client_tags)
  end

  def collect_node_runlist(labels)
    puts "Capturing Chef Runlist"
    chef_client_runlist = Prometheus::Client::Gauge.new(:chef_client_runlist, docstring: 'Capture Chef Client runlist cookbooks and versions', labels: [:runlist, :chef_environment])
    cookbooks = run_context.cookbook_collection
    cookbooks.keys.each do |cookbook|
      chef_client_runlist.set(1, labels: {runlist: "#{cookbook.to_s}::#{cookbooks[cookbook].version}" }.merge(labels))
    end
    prometheus.register(chef_client_runlist)
  end
end
