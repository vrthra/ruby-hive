Traits are specific groups of actions that can be performed by the hive clients. Each trait has a specific file in the hiveclient/traits directory and these can be added and removed dynamically The traits are loaded on the first invocation.
The current traits and what they do.

## Common ##

### actions: ###
inspect version echo trace status help


  * action:inspect:
prints out the supported actions.

  * action:version:
version of the trait.

  * action:status:
prints the status of the trait.

  * action:echo:
echoes back the arguments.

  * action:trace:
echoes back the command and arguments.

  * action:help:
prints helpful information on the trait.


## Traits ##

[i](i.md) [me](i.md) [my](i.md)

[env](env.md)

[fetch](fetch.md)

[pat](pat.md)

[sys](sys.md)

[file](file.md)

[remote](remote.md)

[echo](echo.md)

[exec](exec.md)

[mail](mail.md)

## [Watchers](Watchers.md) ##

[cron](cron.md)

[mailwatch](mailwatch.md)

[watch](watch.md)

[fswatch](fswatch.md)

[urlwatch](urlwatch.md)

You can use these commands to obtain information.

### get version of trait ###
eg: $<|trait|>:version
```
  !do $cron:version
```

### get trait help ###
```
  !do $<|trait|>:help
```

### get all actions exposed by trait ###
```
  !do $<|trait|>:inspect
```

You can use these commands to manage traits.

### get the loaded traits ###
```
  !do $my:traits
```

### reload the trait ###
```
  !do $me:reload[<|trait|>]
```