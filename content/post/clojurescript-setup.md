---
title: ClojureScript Setup for Leiningen Project With Emacs
date: 2017-07-15
draft: false
tags:
    - clojure
    - tutorial
    - emacs
keywords:
    - clojurescript
    - clojure
    - leiningen
    - emacs
    - tutorial
---

A good development environment will boost your productivity in any language. A good Clojure development environment will make you 10x more productive.

This tutorial is focused on a [ClojureScript](https://clojurescript.org/) environment for a [Leiningen](https://leiningen.org/) based
project being developed in [Emacs](https://www.gnu.org/software/emacs/).


# Why Emacs?

Emacs has a great setup for most programming languages but really shines when it
comes to Lisps, including Clojure. [Cider](https://cider.readthedocs.io/en/latest/) is the powerful package that allows easy
interaction with the Clojure REPL and many IDE like features. In combination with
[clj-refactor](https://github.com/clojure-emacs/clj-refactor.el), you get one of the most powerful toolkits out there.


# Why Leiningen?

Leiningen is still the most widely used way to run Clojure applications. I also
prefer the data driven approach to managing configurations that Leiningen take.


# Why is This Guide Needed?

If you have a Clojure project, you can just run `cider-jack-in` and you are
ready to go. That is not the case with ClojureScript. A few extra tweaks are
required to get everything running smoothly.


# Setting up ClojureScript With Cider

The first thing you need is  to include two packages and setup a new
`nreple-middleware`. I always put these configurations into my dev profile.
because they are not needed in production.

You will need to add the following to your `project.clj`:

    :profiles
    {:dev {:dependencies [[com.cemerick/piggieback "0.2.1"]
                          [figwheel-sidecar "0.5.0-2"]]
           :repl-options {:nrepl-middleware [cemerick.piggieback/wrap-cljs-repl]}}}

With your `project.clj` updated, you can to run `cider-jack-in-clojurescript`
(`C-c M-J`) to start up your clojurescript REPL.

Inside the new REPL session, you can start [Figwheel](https://github.com/bhauman/lein-figwheel) with:

    (use 'fighweel-sidecar.repl-api)
    (start-figwheel!)
    (cljs-repl)

These commands will start up a new ClojureScript REPL. You now have two REPL
session running. One for Clojure and one for ClojureScript.

The above is a nice way to get started but gets tedious very quickly, took me
two start-ups took 2 start-ups. Therefore I recommend you add the following to your Emacs
config:

    (setq cider-cljs-lein-repl "(do (use 'figwheel-sidecar.repl-api) (start-figwheel!) (cljs-repl))")

As you can see this is just a wrapper for the commands you were running
by hand. Now, every time you execute `cider-jack-in-clojurescript`, these commands are run
and you will have your two REPLs setup.


# Other Options

If you are using boot or any other setup, please take a look at the great
[Cider documentation](https://cider.readthedocs.io/en/latest/up_and_running/#clojurescript-usage) on this topic. It covers everything here and more.
