---
title: "Universally Testable Dependencies in JavaScript"
date: 2018-06-01
draft: true
categories: [JavaScript, Testing]
tags: [guide, testing]
---

JavaScript dependencies are notoriously hard to mock and test across framework
and environments. However, Dependency Injection(DI) ensures testability. It
is common in statically typed languages, like Java or Go, but is also useful in
dynamic languages, like JavaScript.

This article will guide you through a simple technique that can be applied
to any JavaScript code base, frontend or backend, independent of frameworks
and libraries.

## Why do you need DI?
At the most basic level, you need DI to avoid testing your dependencies.
Not testing dependencies is a good idea for two reasons:

Your dependencies should already be tested. This applies to both external
dependencies and dependencies from your own project. If an external
dependency doesn't have good testing, you probably shouldn't be using it or
you could help them and add some tests!

Dependencies can do too much for a test. Since dependencies exist outside of
your module's control, they can do things that your module shouldn't have to
deal with. Like save data, make web requests, or just plain be algorithmically
heavy.

Because of these reasons. Avoiding testing dependencies will make your
tests less complicated and ensure they are running fast.

## Setting up your code to enable DI
*I am using ES6 and Jest throughout this guide. However, you can easily
adapt this technique to any JavaScript setup.*

To start off, put all dependencies which should not execute during
a test into an exported `deps` object.

```javascript
import longRunningFunction from 'longRunningFunctions';

export const deps = {
    longRunningFunction
}

```

Once you have the `deps` object defined, you no longer reference the dependency
directly. Instead, you call the appropriate dependency on the `deps` object.

```javascript
export default (x, y) => {
    deps.longRunningFunction(x, y)
}
```

That's all you need to do to make your dependencies testable in any context!

Without too much extra code, you have the same level of testability across
node application using `require` syntax and front end application using
ES6 `import` syntax.

## Using the `deps` object in your tests

## Wrapping up
