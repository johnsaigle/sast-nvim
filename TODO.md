# TODO


## bug: error about 'userdata value'

From `:messages`
```
Error executing vim.schedule lua callback: .../share/nvim/lazy/sast-nvim/lua/sast-nvim/diagnostics.lua:35: attempt to index local 'results' (a userdata value)
stack traceback:
        .../share/nvim/lazy/sast-nvim/lua/sast-nvim/diagnostics.lua:35: in function 'transform_results'
        .../.local/share/nvim/lazy/sast-nvim/lua/sast-nvim/init.lua:56: in function 'callback'
        ...local/share/nvim/lazy/sast-nvim/lua/sast-nvim/runner.lua:53: in function <...local/share/nvim/lazy/sast-nvim/lua/sast-nvim/runner.lua:52>
```
