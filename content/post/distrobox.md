---
title: Distrobox in practice
date: 2023-09-17
tags:
  - tutorial
  - linux
  - containers
keywords:
  - tutorial
  - linux
  - distrobox
  - containers
  - docker
  - podman
published: 2023-09-17
---

[Distrobox](https://distrobox.privatedns.org/) is the single piece of software that completely changed the way I work. If you've hear of or used [Vagrant](https://www.vagrantup.com/) and thought it was a great idea but implemented in a really heavy handed manner, then Distrobox is exactly what you've been looking for.

Within a month Distrobox became my primary dev environment and that hasn't changed for over a year. In this post I hope to share how I use Distrobox and give you some tips for making the experience even better. 

## What is Distrobox?

Distrobox is a wrapper around [Docker](https://www.docker.com/) or [Podman](https://podman.io/) that give access to any Linux distro from any other Linux distro.

> Personally, I prefer Podman. So the rest of the article will only mention Podman, but everything also applies to Docker.

At this point, you might be thinking "But can't I already use Podman to run any Linux distro locally?" Well yes you can, but Distrobox takes this a step further.

## The shared environment

The main benefit of Distrobox, over just using Containers on their own, is the integration with the base system. A Distrobox container will have access to your home directory, devices, and a few other things which combine to make it feel like you are working natively.

But despite feeling like home, all the packages that you install remain safely i the container. The downside is that that you need to install all your dependencies in every environment. But, thanks to image layering, you can make this fairly efficient (more on this later).

## Don't containers already provide isolation?

If you've only recently started using Podman, you might think that having a project run in a Podman container is enough to provide isolation. If you've done this for a while, however, you've probably run into issues with tools that you need for development.

Linters, debuggers, completion servers, even the languages themselves can all require project specific versions. This puts you right back at needing to manage multiple versions of packages and languages in your development environment. And there are tools that try to solve this, but each only works with a part of your stack, and most don't even try to address the issue of system packages (NixOS and Guix are notable exceptions).

In fact, I find this dev environment isolation so important that I spin up a new Distrobox container for every project.

## Making per project containers efficient

Having a container for every project might sound wasteful and time consuming, but you can actually make it pretty quick and efficient. This efficiency is possible thanks to image layering done by Podman.

> I will not cover how layering works, but if you are curious, refer to [the Docker documentation on layers](https://docs.docker.com/build/guide/layers/).

Because underneath Distrobox just uses containers, you can easily create a base containers that has all the common tools for your dev environment. My base container looks something like this:

```yaml
FROM archlinux:latest

# Update locale
RUN echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen && locale-gen

# Update package repository
RUN pacman -Syu

# Install dev tools
RUN pacman -S --noconfirm git base-devel neovim zellij exa zoxide fd bat ripgrep stow rust nodejs go starship fzf wl-clipboard lazygit kubectl go-yq jq rsync man-db unzip plocate glibc python nodejs npm

# Use the host install of podman
RUN ln -s /usr/bin/distrobox-host-exec /usr/local/bin/podman
```

> You might have noticed the last line in that file. That line avoids the whole problem of running containers in containers by allowing our dev environment to use the hosts Podman runtime. So you can continue to use Podman like normal while working inside a running container.

This all gets saved into a single layer and referenced by every projects specific environment. For example, my `Django` environment looks like this:

```yaml
FROM dev:latest

# Required dependencies
RUN pacman -S --noconfirm imagemagick ghostscript postgresql chromium
```

Then I link everything together with a small script to build the containers in order:

```bash
# Create my base container named `dev` from the file `dev.Dockerfile`
podman build -t dev -f dev.Dockerfile
# Create a more specific container based `dev` from the file `django.Dockerfile`
podman build -t django -f django.Dockerfile
```

If I need to run an update, I just execute the above script and I have a fresh set of containers.

## Using graphical applications from Distrobox

Another critical features, if you use graphical applications (such as vscode) as part of your dev environmen, is running those applications natively.

The above setup might seem like it wouldn't work for for this. After all, wouldn't it take a bunch of configurations to get a graphical application from a container to display and work on the host? In most cases, it would, but Distrobox takes care of all this.

To start up vscode, you can just run `code` inside your Distrobox terminal and everything work. You will be actually running a graphical tool from inside your container without any extra steps. Better yet, as far as that instance of vscode is concerned, it's running in the environment of the container and uses all the packages available there.

This is a great start. But Distrobox takes it even further. If going through a terminal seems like an extra burden, you can run `distrobox-export --app code` to make the `.desktop` file available on your base system (with the distrobox name prefixed). Then you don't even have to open a terminal and can get your whole environment, including the app, running right from your desktop.

It's really amazing for just how many things this process works. I even have a container that runs QEMU VMs.

## Distrobox makes an immutable OS practical

I won't go on soap box about immutable OSes for too long. You can read about why I use one [here](https://hackeryarn.com/post/picking-a-linux-distro/). But I will say that they keep your system more secure, more stable, and easier to maintain. The two biggest ones out there are [Fedora Silverblue](https://fedoraproject.org/silverblue/) and [OpenSUSE MicroOS](https://microos.opensuse.org/).

Without Distrobox, it really doesn't makes sense to use one of these systems for development. Luckily Distrobox makes it easy to experiment and work in a container, while never breaking the base system.

### Conclusion

Distrobox can do many more interesting things, but having a set of per-project containers is the biggest thing that took Distrobox from a neat tool to something practical that I use every day across multiple systems.

I hope this gives you some ideas of how you can improve your dev setup with Distrobox.
