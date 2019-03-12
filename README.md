# Slot Manager
### A command line tool for easily managing a list of servers over IPMI 

**Official Repo:** https://github.com/privex/slotmgr

`slotmgr` is a tool developed at [Privex Inc.](https://www.privex.io) by @someguy123 for controlling multiple servers over IPMI in a more convenient way.

    +===================================================+
    |                 © 2019 Privex Inc.                |
    |               https://www.privex.io               |
    +===================================================+
    |                                                   |
    |        Originally Developed for internal use      |
    |        at Privex Inc                              |
    |                                                   |
    |        Core Developer(s):                         |
    |                                                   |
    |          (+)  Chris (@someguy123) [Privex]        |
    |                                                   |
    +===================================================+



# Dependencies

`slotmgr` has just two dependencies: **bash**, and **ipmitool**. The former is the default shell of most Linux distributions, and several BSDs (including macOS).

You can find `ipmitool` in your OS's package manager.

**Ubuntu / Debian**

```sh
apt install -y ipmitool
```

**CentOS / RHEL / Fedora**

```sh
yum install ipmitool
```

**macOS (OSX) via Homebrew**

```sh
brew install ipmitool
```

# Install

Once you've installed `ipmitool`, simply clone the repo, and optionally copy `slotmgr.sh` into a binary directory such as `/usr/local/bin` for easy access.

```sh
$ git clone https://github.com/privex/slotmgr.git
$ cd slotmgr
# Install slotmgr into local bin directory so you can simply type `slotmgr` to run it.
# The `install` command is present on most *nix systems, it will copy the file and automatically
# set the correct owner/group (root) and permissions (755).
$ sudo install slotmgr.sh /usr/local/bin/slotmgr
```

# Configuration

The slot config file is used to define the servers you want to manage. By default, `slotmgr` will attempt to load the slot config from `/etc/pvxslotcfg` - you can change this by editing the variable `$FILE` inside of slotmgr.

It's format is a very basic CSV:

 - Do not quote values (e.g. `"some value","other value"`)
 - No spaces around commas (e.g. `1, myserver, 1.2.3.4` - the name would be read as `' myserver'`)
 - One server per line specifying:
     - The rack slot number of the server (or any unique numeric ID)
     - A simple alias name for the server, e.g. `dbserver` or `vpsnode5`
     - The IPv4 address for the server's BMC (IPMI) interface 
     - The username to use when connecting via IPMI
     - The password for the specified user

**CSV Row Format:** `slot,name,bmc_ip,user,pass`


To use the default `$USERNAME` and `$PASSWORD` defined in the `slotmgr` script, just enter `none` as the user/pass

Example:

    1,dbserver,10.1.2.3,none,none
    4,webserver,10.1.5.5,john,secretpass

# Basic Usage

#### Power status of all servers

`slotmgr [options] list`

After you've filled out the configuration file, you can now see the status of an entire server rack simply by typing:

    $ slotmgr list
    
       Slot    Name        IP          Status
       1       dbserver    10.1.0.2    On
       2       webserver   10.1.0.3    Off
       On: 1   Off: 1      Dead: 0

#### Basic power control

`slotmgr [options] power [host] [action]`

 - `host` - The name (alias) of the host, or the slot number if the option `-s` is specified.
 - `action` - One of the following actions: `status`, `on`, `off`, `cycle`, `reset`

Thanks to the aliases in the config file, there's no need to remember the IPMI IP or the rack slot number to access basic functions such as power control and Serial-over-LAN

    $ slotmgr power dbserver cycle

#### Using Serial over LAN

`slotmgr [options] sol [host]`

 - `host` - The name (alias) of the host, or the slot number if the option `-s` is specified.

Using the IPMI feature Serial-over-LAN is extremely useful for managing servers that don't offer a built-in KVM. It allows SSH-like remote access to a server's BIOS, as well as a Linux tty (when configured properly).

However, by default, ipmitool's serial-over-lan (SOL) escape key `~` conflicts with SSH - meaning if you try to close a SOL session while connected over SSH, you'll simply disconnect your current SSH session instead, which is extremely frustrating. 

To solve this, we set the default escape character to `!` (exclamation mark).

    $ slotmgr sol dbserver
      Escape command is '!', use <enter>!. (newline exclaim dot) to exit.
      [SOL Session operational.  Use !? for help]
       
      root@dbserver # poweroff

After the console stops responding (e.g. after shutting down a server), you'll find that the serial console doesn't exit, and will not respond to `CTRL-C` / `CTRL-D`

To close an IPMI SOL connection, simply press these three keys in order: `<CR>!.` (enter, exclaim, dot)

# Contributing

We're very happy to accept pull requests, and work on any issues reported to us. 

Here's some important information:

**Reporting Issues:**

 - We do not develop `ipmitool`. If you experience the same problem when running the `ipmitool` commands directly, then you should [report it to the ipmitool repo on Github](https://github.com/ipmitool/ipmitool/issues)
 - For bug reports, you should include the following information:
     - Git revision number that the issue was tested on - `git log -n1`
     - Your ipmitool version - `ipmitool -V`
     - Your bash version - `bash --version`
     - Your operating system and OS version (e.g. Ubuntu 18.04, Debian 7)
 - For feature requests / changes
     - Please avoid suggestions that require new dependencies. This tool is designed to be highly portable so that it can be installed across many servers with minimal effort.
     - Clearly explain the feature/change that you would like to be added
     - Explain why the feature/change would be useful to us, or other users of the tool
     - Be aware that features/changes that are complicated to add, or we simply find un-necessary for our internal use of the tool may not be added (but we may accept PRs)
    
**Pull Requests:**

 - We'll happily accept PRs that only add code comments or README changes
 - Use 4 spaces, not tabs when contributing to the code
 - You can use Bash 4.4+ features such as associative arrays (dictionaries)
    - Features that require a Bash version that has not yet been released for the latest stable release
      of Ubuntu Server LTS (at this time, Ubuntu 18.04 Bionic) will not be accepted. 
 - Clearly explain the purpose of your pull request in the title and description
     - What changes have you made?
     - Why have you made these changes?
 - Please make sure that code contributions are appropriately commented - we won't accept changes that involve uncommented, highly terse one-liners.

**Legal Disclaimer for Contributions**

Nobody wants to read a long document filled with legal text, so we've summed up the important parts here.

If you contribute content that you've created/own to projects that are created/owned by Privex, such as code or documentation, then you might automatically grant us unrestricted usage of your content, regardless of the open source license that applies to our project.

If you don't want to grant us unlimited usage of your content, you should make sure to place your content
in a separate file, making sure that the license of your content is clearly displayed at the start of the file (e.g. code comments), or inside of it's containing folder (e.g. a file named LICENSE). 

You should let us know in your pull request or issue that you've included files which are licensed
separately, so that we can make sure there's no license conflicts that might stop us being able
to accept your contribution.

If you'd rather read the whole legal text, it should be included as `privex_contribution_agreement.txt`.

# License

This project is licensed under the **X11 / MIT** license. See the file **LICENSE** for full details.

Here's the important bits:

 - You must include/display the license & copyright notice (`LICENSE`) if you modify/distribute/copy
   some or all of this project.
 - You can't use our name to promote / endorse your product without asking us for permission.
   You can however, state that your product uses some/all of this project.



# Thanks for reading!

**If this project has helped you, consider [grabbing a VPS or Dedicated Server from Privex](https://www.privex.io) - prices start at as little as US$8/mo (we take cryptocurrency!)**