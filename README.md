# fluent-plugin-config_reloader

reload child plugin's config plugin.

## Output Plugin

```
  config_file child.conf
  reload_file reload.txt
  reload_file_watch_interval 5
```
- config_file: child conf file path
 - Require 1 `match` directive in this file
- reload_file: reload file path(reload when touch this file)
- reload_file_watch_interval (optional): reload file watch interval sec(default 1)

## example

```
<match example.**>
  type config_reloader
  config_file conf/child.conf
  reload_file reload.txt
</match>
```

### conf/child.conf

```
<match>
  type stdout
</match>
```

### Use out_copy...

```
<store>
  type copy
  <store>
    type stdout
  </store>
  <store>
    type null
  </store>
</store>
```
