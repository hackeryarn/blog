---
title: "Universally testable dependencies in JavaScript"
date: 2018-06-01
draft: true
categories: [JavaScript, Testing]
tags: [guide, testing]
---

JavaScript dependencies are notoriously hard to mock and test across framework
and environments. However, [Dependency Injection](https://en.wikipedia.org/wiki/Dependency_injection<Paste>)(DI) ensures testability. It
is common in statically typed languages, like Java or Go, but is also useful in
dynamic languages, like JavaScript.

This article will guide you through a simple technique that can be applied
to any JavaScript code base, frontend or backend, independent of frameworks
and libraries.

The technique I am going to demonstrate is arguably not true DI since the
dependencies are still managed by the module using them. However, it
solves the dependency problem for testing which is the focus of this
article.

# Why do you need DI?
At the most basic level, you need DI to avoid testing your dependencies.
Not testing dependencies is a good idea for two reasons:

Your dependencies should already be tested. This applies to dependencies
external and from your own project. If an external dependency doesn't have
good testing, you probably shouldn't be using it or you should help them and
add some tests!

Dependencies can do too much for a test. Since dependencies exist outside of
your module's control, they can do things that your module shouldn't have to
deal with. Like save data, make web requests, or just plain be algorithmically
heavy.

Because of these reasons. Avoiding testing dependencies will make your
tests less complicated and ensure they are running fast.

# Setting up your code to enable DI
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

That's all you need to do to make your dependencies testable in any context!

Without too much extra code, you have the same level of testability across
node application using `require` syntax and front end application using
ES6 `import` syntax.

# Using the `deps` object in your tests
Now that your module using and exporting all the dependencies. Your tests have
easy access to mock or completely replace anything in the `deps` object.

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

In the example we are using [Jest's built in mock](https://facebook.github.io/jest/docs/en/mock-functions.html) `jest.fn()`
which let's us do a couple neat things. We can return a
mock value to verify that it is being returned correctly. And we can ensure
the function is called with the expected arguments.

The best part about testing in this way is that we don't have to worry about
the libraries spying functions staying up to date with the JavaScript
specifications, too often spies don't work the same for all module syntaxes. 
In fact, we don't have to use the mocks at all! We could write our
own function with custom validators and pass it in as
`deps.longRunningFunction`.

# Wrapping up
This technique helped me greatly when maintaining long running or large
JavaScript projects. It provides a minimal code approach that is easy to
follow even if you are brand new to the code base.

I hope that you found this approach useful and less complicated than other 
DI approaches. Happy testing!

