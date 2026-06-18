> AI Agents, these file contains personal notes, don't read this file

# Personal notes

## Straylight

straylight build pathtopackagefolder
straylight build --group=base path_to_packages_folder


why it does need to know what is the monorepo root folder?
split build_package fn in multiple
move the manifest declaration and what not out of the build.rs as that will be needed for install and other stuff


straylight daemon for building

## Groundcontrol

python app local -> systemd-socket activate 
allows interacting with the straylight daemon via web
system configuration/maintainance


## Other components
- Package web ui (small lite app) to navigate packages (source and binary info)
- small python-rich wrapper to the just executor
