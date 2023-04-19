# vim-infoboard
This plugin is created by ChatGPT (and me)

This plugin aims to provide a public information board for other plugins to show their info messages to user.
Other plugins can register to the infoboard and get an independent tab of the infoboard, which will be used for
the registered plugin to display their messages.

![image](./infoboard3.gif)

## installation
Just put the `infoboard.vim` to your `~/.vim/plugin/infoboard/` directory

## usage
In your plugin needed to display message to infoboard, first get the infoboard proxy:
```vim
" you should do it at least after VimEnter event
let l:infoboard = GetInfoboardAgent()
```
Second, your plugin need to register to it before display anything:
```vim
call l:infoboard.RegisterInfoSource('your_plugin_name')
```
Infoboard provide three interface to update your information tab:
```vim
" clear your information tab
call l:infoboard.ClearInfoboard('your_plugin_name')
" set line content of you information tab
call l:infoboard.SetLine('your_plugin_name', lineno, msg)
" insert line after a specific line number
call l:infoboard.InsertLine('your_plugin_name', lineno, msg)
```
You can also unregister from infoboard, after which your tab will be removed from infoboard:
```vim
call l:infoboard.UnRegisterInfoSource('your_plugin_name')
```

## note
+ If you want to register to infoboard as soon as the plugin is loaded, do it after VimEnter event
