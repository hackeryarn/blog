---
title: Clojure GitHub Actions
published: 2023-10-26
tags:
  - tutorial
  - clojure
  - automation
keywords:
  - tutorial
  - github actions
  - clojure
  - automation
  - ci/cd
---
I recently took over the maintenance of an open source Clojure project.
One of the first things I noticed was the lack CI or CD. These are
things that aren't required but can save a lot of work, especially for
a public project.

The CI portion helps make sure that all pull requests pass tests and
conform to the project\'s coding style. The CD portion helps with
deploying the project. And these parts become especially important if
the project is in maintenance mode.

Unlike a project under active development where all the details are
fresh in my mind and I am working on it almost daily, a project in
maintenance mode might not need any work for weeks or months. In that
time, I am likely to forget a step and cause things to get messy or
worse, cause a regression. CI and CD provide a safety net against things
slipping.

So with that reasoning in mind, I dove into CI/CD GitHub actions for
Clojure.

# Ground work

Every GitHub action needs some setup to get the correct environment
started. Luckily, Clojure has a [setup
action](https://github.com/DeLaGuardo/setup-clojure) that makes it
trivial to get started with the most common dependencies. The project I
took over is a Leiningen project, so that will be the focus here, but
these pieces should translate easily into other systems. See the [setup
action repo](https://github.com/DeLaGuardo/setup-clojure) for details on
how to setup other systems.

My Leiningen setup ended up like this:

``` yaml
# This will go in as part of later actions.
    steps:
      # Checkout the project repository.
      - name: Checkout
        uses: actions/checkout@v3
      # Install the desired Java version.
      - name: Prepare java
        uses: actions/setup-java@v3
        with:
          distribution: "zulu"
          java-version: "17"
      # Setup Leiningen. Also supports setting up other commonly used tools.
      - name: Install clojure tools
        uses: DeLaGuardo/setup-clojure@12.1
        with:
          lein: 2.9.1
      # Enable cache so our actions run faster.
      - name: Cache clojure dependencies
        uses: actions/cache@v3
        with:
          path: |
            ~/.m2/repository
            ~/.gitlibs
            ~/.deps.clj
          key: cljdeps-${{ hashFiles('project.clj') }}
          restore-keys: cljdeps-
```

This does all the basics that I needed for a Clojure action. All the
steps after this can proceed with Clojure fully setup.

# Lint and test

The most basic, but probably most important action, is linting and
testing on every push or pull request. These are the steps that everyone
should run locally before making a push, but often forget.

To get both linting and tests running only required two short steps:

``` yaml
# ./.github/workflows/test.yaml
name: Test

# This will run the action on any push or pull request. GitHub also supports other
# options here, and you will see one of them later.
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      # The ground work setup goes before these steps ...
      - name: Lint
        run: lein clj-kondo
      - name: Test
        run: lein test
```

To get linting to work, I had to add
[lein-clj-kondo](https://github.com/clj-kondo/lein-clj-kondo) to the
project dependencies.

The testing portion didn\'t require any other setup besides following
the regular Clojure testing conventions.

# Deployment

Once you have linting and testing running, the next step is to make
deployment easier. The most reasonable way to automate this is to use
tags. That way, when I create a new tag, it becomes automatically
available in Clojars.

``` yaml
# ./.github/workflows/deploy.yaml
name: Deploy

on:
  # Run this workflow any time that the test workflow completes.
  workflow_run:
    workflows: [Test]
    types: [completed]

jobs:
  deploy-clojars:
    # Only run this part if it is running on a tag that starts with `v` (e.g. v1.0.1).
    if: startsWith(github.ref, 'refs/tags/v')
    runs-on: ubuntu-latest
    steps:
      # The ground work setup goes before these steps ...
      - name: Deploy
        env:
          # Provide environment variables used to deploy.
          CLOJARS_USERNAME: ${{ secrets.CLOJARS_USERNAME }}
          CLOJARS_PASSWORD: ${{ secrets.CLOJARS_PASSWORD }}
        run: lein deploy clojars

```

Besides providing the credentials as environment variables (see [Using
secrets in GitHub
Actions](https://docs.github.com/en/actions/security-guides/using-secrets-in-github-actions)
for how to make these available), I needed to do one more thing to make
this project deployable in an actions.

By default, Clojars requires signing of all releases. I don\'t see a
major benefit in this since it\'s a publicly hosted repository that has
a lot of safeguard as it is. So instead of fiddling with providing a gpg
key to a github action and extracting the release hash, I just disabled
signing in my `project.clj`.

``` clojure
:deploy-repositories [["clojars" {:url "https://clojars.org/repo"
                                  ;; Uses the environment variables that we set in the action.
                                  :username :env/clojars_username
                                  :password :env/clojars_password
                                  ;; Disables signing
                                  :sign-releases false}]]
```

With that, I had a fully working CI/CD pipeline for the project that I
took over.
