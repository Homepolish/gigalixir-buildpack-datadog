This [buildpack][1] installs the Datadog Agent in your Gigalixir container to collect system metrics,
custom application metrics, and traces. To collect custom application metrics or traces, include the language 
appropriate [DogStatsD or Datadog APM library][2] in your application.

## Installation

To add this buildpack to your project, as well as set the required environment variables:

```shell
cd <GIGALIXIR_PROJECT_ROOT_FOLDER>

# If this is a new Gigalixir project
# Add the appropriate language-specific buildpack. For example:
cat > .buildpacks <<EOF
https://github.com/gigalixir/gigalixir-buildpack-clean-cache.git
https://github.com/HashNuke/heroku-buildpack-elixir
https://github.com/gjaldon/heroku-buildpack-phoenix-static
https://github.com/gigalixir/gigalixir-buildpack-distillery.git
EOF

# Add this buildpack and set your Datadog API key
ex -sc '1i|https://github.com/Homepolish/gigalixir-buildpack-datadog.git' -cx .buildpacks
gigalixir config:set DD_API_KEY=<DATADOG_API_KEY> -a <APPLICATION_NAME>

# Deploy to Gigalixir
git push gigalixir master
```

Replace `<DATADOG_API_KEY>` with your [Datadog API key][3].

Once complete, the Datadog Agent is started automatically when each replica starts.

The Datadog Agent provides a listening port on `8125` for statsd/dogstatsd metrics and events. 
Traces are collected on port `8126`.

### Distillery

This buildpack is meant to be used with Distillery and requires configuration of the release. This includes
the use of the [Datadog Distillery Plugin](https://github.com/Homepolish/datadog_distillery_plugin).

Make sure to add the plugin to your `mix.exs` file.

```elixir
def deps do
  [
    {:distillery, "~> 2.0"},
    {:datadog_distillery_plugin, "~> 0.1.0"}
  ]
end
```

Set the following in the `rel/config.exs`:

```elixir
environment :prod do
  # The plugin for recompiling the slug with the Datadog agent
  plugin(Mix.Releases.DatadogPlugin)

  set(
    overlays: [
      # The app datadog dir; used for configuration of integrations
      {:copy, "datadog", "datadog"},
      # The datadog agent script
      # This cannot be run until after the web process is started
      {:copy, ".profile.d/datadog.sh", "datadog/run"},
      # Set up environment for running `$ agent` from cli
      {:copy, ".profile.d/agent_pre.sh", ".profile.d/agent_pre.sh"}
    ]
  )
end
```

The last piece is to start the agent. This is best achieved from a pre-start hook, again in `rel/config.exs`.

```elixir
environment :prod do
  set(pre_start_hooks: "rel/hooks/pre_start.d")
end
```

**rel/hooks/pre_start.d/01.datadog.sh**
```bash
#!/usr/bin/env bash

set -e

echo "==> Starting Datadog agent"
"${RELEASE_ROOT_DIR}"/datadog/run
```

## Configuration

In addition to the environment variables shown above, there are a number of others you can set:

| Setting                      | Description|
| ---------------------------- | ------------------------------ |
| `DD_API_KEY`                 | *Required.* Your API key is available from the [Datadog API Integrations][4] page. Note that this is the *API* key, not the application key.|
| `DD_HOSTNAME`                | *Optional.* **WARNING**: Setting the hostname manually may result in metrics continuity errors. It is recommended that you do *not* set this variable. Because process hosts are ephemeral it is recommended that you monitor based on the tags `psname` or `appname`.|
| `DD_DYNO_HOST`               | *Optional.* Set to `true` to use the process name (e.g. `web.1`) as the hostname. See the [hostname section](#hostname) below for more information. Defaults to `false`|
| `DD_TAGS`                    | *Optional.* Sets additional tags provided as a space-delimited string. For example, `gigalixir config:set DD_TAGS="simple-tag-0 tag-key-1:tag-value-1"`. The buildpack automatically adds the tags `ps` and `pstype` which represent the Dyno name (e.g. web.1) and (e.g. web) respectively. The tag `appname` (e.g. my_app) will also be set if present. See the ["Guide to tagging"][5] for more information.|
| `DD_HISTOGRAM_PERCENTILES`   | *Optional.* Optionally set additional percentiles for your histogram metrics. See [How to graph percentiles][6].|
| `DISABLE_DATADOG_AGENT`      | *Optional.* When set, the Datadog Agent does not run.|
| `DD_APM_ENABLED`             | *Optional.* Trace collection is enabled by default. Set this to `false` to disable trace collection.|
| `DD_PROCESS_AGENT`           | *Optional.* The Datadog Process Agent is disabled by default. Set this to `true` to enable the Process Agent.|
| `DD_SITE`                    | *Optional.* If you use the app.datadoghq.eu service, set this to `datadoghq.eu`. Defaults to `datadoghq.com`.|
| `DD_AGENT_VERSION`           | *Optional.* By default, the buildpack installs the latest version of the Datadog Agent available in the package repository. Use this variable to install older versions of the Datadog Agent (note that not all versions of the Agent may be available).|
| `DD_DISABLE_HOST_METRICS`    | *Optional.* By default, the buildpack reports system metrics for the host machine running the process. Set this to `true` to disable system metrics collection.|

For additional documentation, refer to the [Datadog Agent documentation][9].

## Hostname

Gigalixir containers are ephemeral—they can move to different host machines whenever new code is deployed, configuration changes are made, or resouce needs/availability changes. This makes Gigalixir flexible and responsive, but can potentially lead to a high number of reported hosts in Datadog. Datadog bills on a per-host basis, and the buildpack default is to report actual hosts, which can lead to higher than expected costs.

Depending on your use case, you may want to set your hostname so that hosts are aggregated and report a lower number.  To do this, Set `DD_DYNO_HOST` to `true`. This will cause the Agent to report the hostname as the app and Dyno name (e.g. `appname.1.service`) and your host count will closely match your Dyno usage. One drawback is that you may see some metrics continuity errors whenever an application is cycled.

## File locations

- The Datadog Agent is installed at `/app/.apt/opt/datadog-agent`
- The Datadog Agent configuration files are at `/app/.apt/etc/datadog-agent`
- The Datadog Agent logs are at `/app/.apt/var/log/datadog`

## Enabling integrations

You can enable Datadog Agent integrations by including an appropriately named YAML file inside a `datadog/conf.d` directory in the root of your application.

For example, to enable the [PostgreSQL integration][10], create a file `/datadog/conf.d/postgres.yaml` in your application containing:

```
init_config:

instances:
  - host: <YOUR HOSTNAME>
    port: <YOUR PORT>
    username: <YOUR USERNAME>
    password: <YOUR PASSWORD>
    dbname: <YOUR DBNAME>
    ssl: True
```

During the dyno start up, your YAML files are copied to the appropriate Datadog Agent configuration directories.

## Limiting Datadog's console output

In some cases, you may want to limit the amount of logs the Datadog buildpack is writing to the console.

To limit the log output of the buildpack, set the `DD_LOG_LEVEL` environment variable to one of the following: `TRACE`, `DEBUG`, `INFO`, `WARN`, `ERROR`, `CRITICAL`, `OFF`.

```
gigalixir config:set DD_LOG_LEVEL=ERROR -a <APPLICATION_NAME>
```

## Gigalixir Log Collection

### Collect Gigalixir logs
**This log integration is currently in public beta**

Gigalixir provides 3 types of logs:

- App Logs: output from the application you pushed on the platform.
- System Logs: messages about actions taken by the Gigalixir platform infrastructure on behalf of your app.
- API Logs: administrative questions implemented by you and other developers working on your app.

Gigalixir’s HTTP/S drains buffer log messages and submit batches of messages to an HTTPS endpoint via a POST request.
The POST body contains Syslog formatted messages, framed using the Syslog TCP protocol octet counting framing method.
The Datadog HTTP API implements and understands the Logplex standard defined by the content-header application/logplex-1.

To send all these logs to Datadog:

- Connect to your Gigalixir project.
- Set up the HTTPS drain with the following command:

**US Site**
```
gigalixir drains:add 'https://http-intake.logs.datadoghq.com/v1/input/<DD_API_KEY>?ddsource=gigalixir&service=<SERVICE>&host=<HOST>' -a <APPLICATION_NAME>
```

**EU Site**
```
gigalixir drains:add 'https://http-intake.logs.datadoghq.eu/v1/input/<DD_API_KEY>?ddsource=gigalixir&service=<SERVICE>&host=<HOST>' -a <APPLICATION_NAME>
```

- Replace `<DD_API_KEY>` with your Datadog API Key.
- Replace `<SERVICE>` with your service name (i.e. the Elixir application name).
- Replace `<APPLICATION_NAME>` and `<HOST>` with your Gigalixir application name.

> Note: Per the host section, metrics and traces set the default host name to `$(hostname)`. 

It is not yet possible to dynamically set the host name as the process hostname for logs. For now, to correlate between metrics, traces, and logs the `procid` tag can be used.

> Note: Tags can be added using the `ddtags` attribute; i.e. `&ddtags=env:staging`

#### Custom attributes

Add custom attributes to logs from your application by appending the URL in the drain as follows: `&attribute_name=<VALUE>`

## Prerun script

In addition to all of the configurations above, you can include a prerun script, `/datadog/prerun.sh`, in your application. The prerun script will run after all of the standard configuration actions and immediately before starting the Datadog Agent. This allows you to modify the environment variables, perform additional configurations, or even disable the Datadog Agent programmatically.

The example below demonstrates a few of the things you can do in the `prerun.sh` script:

```shell
#!/usr/bin/env bash

# Update the Postgres configuration from above using the Gigalixir application environment variable
if [ -n "$DATABASE_URL" ]; then
  POSTGREGEX='^postgres://([^:]+):([^@]+)@([^:]+):([^/]+)/(.*)$'
  if [[ $DATABASE_URL =~ $POSTGREGEX ]]; then
    sed -i "s/<YOUR HOSTNAME>/${BASH_REMATCH[3]}/" "$DD_CONF_DIR/conf.d/postgres.d/conf.yaml"
    sed -i "s/<YOUR USERNAME>/${BASH_REMATCH[1]}/" "$DD_CONF_DIR/conf.d/postgres.d/conf.yaml"
    sed -i "s/<YOUR PASSWORD>/${BASH_REMATCH[2]}/" "$DD_CONF_DIR/conf.d/postgres.d/conf.yaml"
    sed -i "s/<YOUR PORT>/${BASH_REMATCH[4]}/" "$DD_CONF_DIR/conf.d/postgres.d/conf.yaml"
    sed -i "s/<YOUR DBNAME>/${BASH_REMATCH[5]}/" "$DD_CONF_DIR/conf.d/postgres.d/conf.yaml"
  fi
fi
```

## Support

When support is required, Datadog will often request some action be done with the `agent` command. To facilitate these requests
the agent can be accessed from an SSH session.

The ENV vars `$DD_PYTHONPATH` and `$DATADOG_CONF` are exported for convenience.

```
$ gigalixir ps:ssh -a <APPLICATION_NAME>
$ PYTHONPATH=$DD_PYTHONPATH agent <RUN_COMMAND> -c $DATADOG_CONF
```

## Unsupported

Gigalixir buildpacks cannot be used with Docker images. To build a Docker image with Datadog, reference the [Datadog Agent docker files][12].

## Contributing

[See the contributing documentation to learn how to open an issue or PR to the gigalixir-buildpack-datadog repository][13]

## History

This has been ported from the [DataDog heroku-buildpack-datadog project][16]. It has been adapted for the Gigalixir platform.

Earlier versions of this project were forked from the [miketheman heroku-buildpack-datadog project][14]. It was largely rewritten for Datadog's Agent version 6. Changes and more information can be found in the [changelog][15].

[1]: https://devcenter.heroku.com/articles/buildpacks
[2]: https://docs.datadoghq.com/libraries
[3]: https://app.datadoghq.com/account/settings#api
[4]: https://app.datadoghq.com/account/settings#api
[5]: https://docs.datadoghq.com/tagging
[6]: /graphing/faq/how-to-graph-percentiles-in-datadog
[8]: https://docs.datadoghq.com/tracing/setup/?tab=agent630#trace-search
[9]: https://docs.datadoghq.com/agent
[10]: https://docs.datadoghq.com/integrations/postgres
[12]: https://github.com/DataDog/datadog-agent/tree/master/Dockerfiles
[13]: https://github.com/Homepolish/gigalixir-buildpack-datadog/blob/master/CONTRIBUTING.md
[14]: https://github.com/miketheman/heroku-buildpack-datadog
[15]: https://github.com/Homepolish/gigalixir-buildpack-datadog/blob/master/CHANGELOG.md
[16]: https://github.com/DataDog/heroku-buildpack-datadog
