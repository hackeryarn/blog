---
title: "Universally Testable Dependencies in JavaScript"
date: 2018-06-01
tags:
    - tutorial
    - javascript
    - testing
keywords:
    - tutorial
    - javascript
    - testing
---

JavaScript dependencies are notoriously hard to mock and test across framework
and environments. However, [Dependency Injection](https://en.wikipedia.org/wiki/Dependency_injection<Paste>) (DI) ensures testability. It
is common in statically typed languages, like Java or Go, but is also useful in
dynamic languages like JavaScript.

This article will guide you through a simple technique that can apply
to any JavaScript code base, frontend or backend, independent of frameworks
and libraries.

The technique I am going to demonstrate is arguably not true DI, since the
dependencies are still managed by the module using them. However, it
solves the dependency problem for testing which is the focus of this
article.

## Why Do You Need DI?
At the most basic level, you need DI to avoid testing your dependencies.
Not testing dependencies is a good idea for two reasons:

Your dependencies should already be tested. This applies to both external dependencies as well as from your own project. If an external dependency doesn't have good testing, you probably shouldn't be using it or you should help them and add some tests!

Dependencies can do too much. Since dependencies exist outside of
your module's control, they can perform actions your module shouldn't be concerned with such as saving data, making web requests, or being algorithmically heavy.

Your tests will be less complicated and faster if you avoid tesing dependencies because of the reasons mentioned above.

## Setting Up Your Code to Enable DI
*I am using [Babel](https://babeljs.io/) and
[Jest](https://facebook.github.io/jest/) throughout this guide. However,
you can easily adapt this technique to any JavaScript setup.*

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
    return deps.longRunningFunction(x, y)
}
```

That's all you need to make your dependencies testable in any context!

You will have the same level of testability across
node application using the `require` syntax, and front end application using
the ES6 `import` syntax without extra code.

## Using the `deps` Object in Your Tests
With your module exporting all of its dependencies, your tests can
easily mock or replace anything in the `deps` object.

```javascript
import * as myModule from './myModule';

const deps = myModule.deps;
const result = 4

describe('myModule', () => {
    let got;

    beforeAll(() => {
        deps.longRunningFunction = jest.fn().mockReturnValue(result);
        got = myModule.default(2, 2);
    });

    it('calls longRunningFunction with correct arguments', () => {
        expect(deps.longRunningFunction).toBeCalledWith(2, 2);
    });

    it('returns the correct result', () => {
        expect(got).toEqual(result);
    });
});
```

The `beforeAll` block is the most important piece of code. Because
we are using functions from the `deps` object in our module code, we can
just replace `deps.longRunningFunction` with anything we want before invoking
the module's default function.

In this example, we are using [Jest's built in mock](https://facebook.github.io/jest/docs/en/mock-functions.html) `jest.fn()`.
It can produce a mock value to verify that our function returns the correct value and is called with the expected arguments.

The best part about testing this way is that we don't have to worry about
any library's spying functions staying up to date with the JavaScript
specifications. Often times, spies don't work the same for all module syntaxes.
In fact, we don't have to use the mocks at all! We could write our
own function with custom validators and set it as
`deps.longRunningFunction`.

## Wrapping Up
This technique helped me immensely when maintaining long running or large
JavaScript projects. It provided a minimal code approach that is easy to
follow even when you are brand new to the code base. I hope you found this
approach useful and less complicated than other DI approaches.

Happy testing!
