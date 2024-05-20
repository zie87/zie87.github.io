---
layout: 'post'
title: 'GNU Guix: A home for Neovim'
date: '2024-03-30 14:00:00'
categories: ['Guix' ]
tags: ['guix', 'gnu', 'functional', 'scheme', 'guile', 'neovim', 'nvim', 'lua', 'lsp', 'dap']
---


* home service setup
* LSP
* formatter (conform)
* linter (nvim-lint)
* DAP

### vim motions / breaking habits

* [Habit breaking, habit making](http://vimcasts.org/blog/2013/02/habit-breaking-habit-making/)
* [VIM hard mode (disable backspace and arrows)](https://www.mailslurp.com/blog/vim-hard-mode/)
* plugins:
  * [hardmode](https://github.com/wikitopian/hardmode)
  * [vim-hardtime](https://github.com/takac/vim-hardtime)
  * [hardtim.nvim](https://github.com/m4xshen/hardtime.nvim)



## References

### Blogs

* `lsp-zero.nvim`: [You might not need lsp-zero](https://lsp-zero.netlify.app/v3.x/blog/you-might-not-need-lsp-zero.html)
* Heiker Curiel: [A guide on Neovim's LSP client](https://vonheikemen.github.io/devlog/tools/neovim-lsp-client-guide/)
* Andreas Schneider: [neovim, dap and gdb 14.1](https://blog.cryptomilk.org/2024/01/02/neovim-dap-and-gdb-14-1/) ([dotfiles](https://git.cryptomilk.org/users/asn/dotfiles.git/tree/dot_config/nvim))

### Distributions

[`kickstart.nvim`][1]
: A launch point for your personal nvim configuration

[LunarVim](https://www.lunarvim.org/)
: An IDE layer for Neovim with sane defaults. Completely free and community driven.

[`Nyoom.nvim`](https://github.com/nyoom-engineering/nyoom.nvim) 
: A Neovim framework and doom emacs alternative for the stubborn martian hacker. Powered by fennel and the oxocarbon theme

## Footnotes

[1]: https://github.com/nvim-lua/kickstart.nvim
[2]: https://microsoft.github.io/debug-adapter-protocol/
[3]: https://sourceware.org/gdb/current/onlinedocs/gdb.html/Debugger-Adapter-Protocol.html
