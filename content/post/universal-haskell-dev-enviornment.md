---
title: Easy universal Haskell development environment
date: 2016-02-06
draft: false
categories: [Haskell]
tags: [setup, guide]
---

Haskell is notoriously difficult to setup, which probably led to many people being scared away from ever getting started. However, there has been a lot of work done to address these short comings. And there is a way to setup a very pleasant environment thanks to the hard work of many projects.

Traditional methods included:

* Installing [The Haskell Platform](https://www.haskell.org/platform/), which was a great project in it's time but always seems to lag a few GHC versions behind.
* Required using a text editor like [Vim](http://www.vim.org/) or [Emacs](https://www.gnu.org/software/emacs/). These are incredible tools and productivity boosters, if you take the time to learn them. Which is a pretty major time commitment in itself *I do suggest you learn one of these eventually, or use the vim/emacs mode of another tool.*
* Complex package management through [Cabal-Install](https://wiki.haskell.org/Cabal-Install). This tool caused either version hell from everything being installed globally or caused you to have to re-install all your dependencies for every project.

## Tools of the trade
We will be using these tools to solve the above problems and make the installation completely system agnostic. That's right, this installation process with work on any platform OS X, Linux, and even Windows.

1. [Stack](http://docs.haskellstack.org/) is probably the single biggest win for Haskell in the last year. It makes everything from freshly installing Haskell to creating and building new projects a no brainer.
2. [Atom](https://atom.io/) has become one of my favorite text editors and has great support for Haskell.

Those are the two major tools you will need to install and everything else is done through packages for them. Go ahead and install these from their respective websites.

## The setup
Now let's crack open the terminal and configure our environment. All the commands will remain the same regardless of your operating system. 

Let's start by installing Haskell, or GHC to be more specific. Stack does not come GHC but it does come with an easy way to install it.

```bash
$ stack setup
```
Now you have a working version of GHC and you can drop into the repl at any time. Feel free to try this out with `stack repl`. 

Next let's install all our atom packages. Which is just one line! These packages include everything you would expect. Syntax highlights, code completion, linting, and even some auto formatting.

```bash
$ apm install language-haskell haskell-ghc-mod ide-haskell-cabal ide-haskell autocomplete-haskell
```

**You must be outside of any stack project to run this command!** This installs the binaries using your global configuration and not project specific setup. Which will make updating things in the future a little easier.

```bash
$ stack install ghc-mod stylish-haskell
```

`ghc-mod` will do all heavy lifting for your setup. It's the backend for all the auto completion, linting, code validation, etc. While `stylish-haskell` will prettify your code. 

At this point you need to check the output from stack to ensure that the binary install location has been added to your path. If it hasn't you will see a message instructing you on the exact folder that needs to be added.

That's it. This is all you need to have a working Haskell setup on any machine. If you want to try it out, go ahead and run `stack new MyProject`. This will create a fresh stack project and give you a few small sample file. If you try to define your own functions you should see code help and debug information just like you would expect.


Happy hacking on your new setup!

