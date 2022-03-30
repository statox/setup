This role install a nerdfont containing icons.

The files were downloaded from https://www.nerdfonts.com/font-downloads

Once the files are in `~/.local/share/fonts` we need to refresh the font cache (this role does it).

Then we need to configure gnome terminal to use this font (it's done in the role `user/dconf`)

After that no need to install more things, in neovim the icons work properly
