# chef_client_exporter
Export to Chef Client metrics to Prometheus via handler

About

This shows how to create a metrics file for the textfile collector at the end of a chef-client run, and collect some metrics. The approach is to register a report handler with Chef, which gets executed after everything else.
Status

This uses Chef 14 which includes chef_handler resource. The handler goes into files/default/, the recipe into recipes/. Adapt the recipe to how and where you install Node Exporter.
