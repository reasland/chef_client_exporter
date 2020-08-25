require 'chef/handler'
require 'prometheus/client'
require 'prometheus/client/formats/text'

class PrometheusHandler < Chef::Handler
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

    chef_client_last_run_timestamp_seconds = Prometheus::Client::Gauge.new(:chef_client_last_run_timestamp_seconds, docstring: '...', labels: [:chef_environment])
    chef_client_last_run_timestamp_seconds.set(run_status.end_time.to_i, labels: labels)
    prometheus.register(chef_client_last_run_timestamp_seconds)
  end

  def collect_error_metrics(labels)
    puts "Chef Client error; capturing errors"
    chef_client_errors_count = Prometheus::Client::Gauge.new(:chef_client_errors_count, docstring: '...', labels: [:chef_environment])
    chef_client_errors_count.set(1, labels: labels)
    prometheus.register(chef_client_errors_count)
  end

  def collect_resource_metrics(labels)
    puts "Capturing Chef Resource Data"
    chef_client_resources_count = Prometheus::Client::Gauge.new(:chef_client_resources_count, docstring: '...', labels: [:chef_environment])
    chef_client_resources_count.set(run_status.all_resources.size, labels: labels)
    prometheus.register(chef_client_resources_count)

    chef_client_updated_resources_count = Prometheus::Client::Gauge.new(:chef_client_updated_resources_count, docstring: '...', labels: [:chef_environment])
    chef_client_updated_resources_count.set(run_status.updated_resources.size, labels: labels)
    prometheus.register(chef_client_updated_resources_count)
  end
end
