---
title: Picking a Linux Distro
published: 2023-02-20
tags:
  - discussion
  - linux
keywords:
  - discussion
  - linux
  - micros
  - opensuse
---

I recently started a new job that gave me the chance to run whatever Linux distribution would make me the most productive. In the face of complete freedom, I decided to re-evaluate my daily driver and see if there was a distribution that would give me the most up-to-date software while maintaining a stable system. The results of my search surprised even me.

## Background
I have ran Ubuntu on my home lab server for over a decade, and used it a daily driver from 2009 to 2014. I switched from Ubuntu because their package release cycle, even on the latest version, is too slow for my liking. At around the same time, rolling release distros were gaining popularity. So I jumped on the Arch train.

Throughout the years I ran vanilla Arch, Manjaro, and most recently EndeavourOS. All these flavours of Arch had their own trade offs, but none of them felt quite stable enough. No matter which one I used, a few times a year an update would go so badly that I had to restore my entire system from backup. This made my backup practices much better, but didn't make me excited to use any of them for work.

In the search for stability, I also tried running NixOS in-between the Arch distros. NixOS had built-in snapshots for easy restores, and the base system was overall more stable. Unfortunately, there were still times when I had multiple packages break and I would be stuck not updating my system because the system update process was an all or nothing choice.

The biggest thing that made me stop using NixOS, however, was that they do things too differently from other Linux distros. NixOS requires most packages to have special configurations to work around the immutable file system, and all system changes need to be declared. This can definitely be an advantage, but it got too much for me when I just wanted things to work.

Although I got my setup to be good, I had a nagging feeling that there had to be a better way. A way that would give me the best of both world. And now that I had a chance to really look, I was determined to find it.

## The criteria for a new distro

In this search for a new distribution, I had 3 main criteria:

1. A stable base system. I didn't want to have to re-install my base system multiple times per year.
2. A rolling release cycle. I still believe that rolling releases are essential to running a solid system and keeping software up-to-date. After all, nobody wants to build 10 packages from source just to get a critical update working.
3. The ability to easily build fresh software and run packages. I did not want to jump through extra hoops to try out a new package or get obscure programs running.

## Eliminating the distros

Arch and NixOS were quickly eliminated. Arch lacked the stability, and NixOS required extra steps to build and run anything.

Ubuntu and many of the other stable distros were also eliminated because of the lack of rolling releases. Fedora came close with their Rawhide releases, but that turned out to be more of a testing branch and less of a true rolling release process. Rawhide makes weaker stability claims than Arch, and therefore would not make a good work daily driver.

While looking at Fedora, however, I noticed that they had a version called SilverBlue. This version ran an immutable file system (similar to NixOS), but promised to avoid the added overhead of NixOS.

## Enter the immutable distros

SilverBlue made strong stability promises. In fact, stability was a core value of the entire project. But with my previous experience with NixOS, I had to wonder if SilverBlue would succumb to the same complexity trap of building on top of an immutable file system.

Turns out, that SilverBlue takes quite a different approach from NixOS. Instead of encouraging the users to always update the base image and install packages at the base of the system, SilverBlue discourages any updates to the base system and instead uses `flatpak` for GUI tools and `toolbox` for development tools.

`flatpak` should be familiar to anyone that has used a Mac or a smartphone. It allows installing Apps on the system. These apps will run on any Linux system, they ship with their dependencies, and you get to decide what access they get to your system. This the right way to run GUIs on any system, especially proprietary GUIs.

`toolbox` was a more radical idea. It completely changed the way I thought about running my development environment. Instead of setting up your development environment on the machine you're using, `toolbox` uses containers to create an environment that won't impact the rest of the system (similar to what `flatpak` does for GUI apps). The container still gets access to the user's home directory, the user's permissions, and even graphical sessions. So the whole experience doesn't feel like it's running in a container while providing all the benefits of container isolation.

With these features, it seemed like I found the distro of my dreams. But it was still missing true rolling releases.

## MicroOS

That's when I noticed a distro very close to SilverBlue: MicroOS by OpenSUSE. It had all the same ideas behind an immutable OS running most applications through `flatpak`, but it used `distrobox` instead of `toolbox`.

`distrobox` takes the ideas behind `toolbox` a step further. It allows creating a development environment using any Linux distribution. This means that if you have that one package on Arch that you just need to run, no problem, just spin up a new `distrobox` running Arch and install your package. If you need another close to production environment running Rocky Linux, no problem, just spin it up and test things there. You get the idea.

Finally, and most importantly, OpenSUSE and MicroOS have a strong rolling release distro (tumbleweed). The packages released to this distro are backed by an amazing testing suite of OpenQA, so I can get the latest packages with a high level of confidence that they won't break my system. And if they do, MicroOS will use the built-in snapshots to roll back transactionally. That means no time wasted trying to rebuild my system and no time wasted configuring software just to run on this system.

And speaking of not wasting any time. MicroOS will automatically install updates to your base system every night. This won't effect any of the things running on the system, but the next time you reboot, you will get the latest MicroOS release automatically.

So with this long journey, I landed on a distribution I never even heard of, with ideas I haven't considered. But all put together, this was the perfect distro for my use case.

## TLDR

Give MicroOS a try. And even if you don't use it, start utilizing `flatpak` and `distrobox` to increase your system's stability and keep it from getting bloated with one-off packages.
