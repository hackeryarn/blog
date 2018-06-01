---
title: How Lodash worked itself out of a job
date: 2017-06-25
draft: false
categories: [JavaScript]
tags: [opinion]
---

I really loved lodash. It brough the joy of compact functional code to
JavaScript. Especially 6 years ago when I first embraced it. It was a wonderful library.
Back then, there was no ES6, no Babel, and terrible browser incompatabilities
ran rampant. Lodash along with jQuery were the saving light of that time.

I gravitated towards using Lodash because the first language I learned was
Scheme. It had functional programing at it's core, and highly influanced how I
think about code to this day.

I was a major advocate of Lodash for a long time. However, as my team 
embraced ES6 with Babel, I am at a point where I have to
discurage the use of Lodash instead of promote it. This might seem like a
drastic change but it is a well grounded one. It's also not just ES6 and Babel
that are taking my attention away from Lodash. There are libraries like [Ramda](http://ramdajs.com/) that provide the better functionality(but more on that later).

# ES6 vs Lodash

I will outline some of the benefits I saw in using pure ES6 instead of Lodash.
The main stumbling point in this transition can be browser support but most teams use
transpilers such as Babel, so this isn't a concern anymore.

## Library size

This should come as no surprise, but Lodash is a big library. In fact, if you
modularize your application, chances are it's bigger than your codebase. However, you can import only the modules you need if you have the propper plugins setup, such as [babel-plugin-lodash](https://github.com/lodash/babel-plugin-lodash) or [lodash-webpack-plugin](https://github.com/lodash/lodash-webpack-plugin). 

ES6, on the other hand, won't add much bloat by default. It's efficiently transpiled into your code and only slightly increases transpiled size, plus chances are you have to use it
anyways to gain other ownderful features.

## Clean code

Clean code is a big one. Let's take a look at what Lodash provides:

    // We will be using this data for all exaples so I won't repeat it.
    var teamRanking = [
      {
        school: 'alabama',
        rank: 1
      },
      {
        school: 'clemons',
        rank: 2
      },
      {
        school: 'ohio state',
        rank: 3
      },
      {
        school: 'washington',
        rank: 4
      },
    ];
    
    
    // We are extracting the top two teams and uppercasing the names
    var topTwo = _.map(_.filter(teamRanking, (team) => {
        return team.rank <= 2;
      }), (team) => {
      return _.update(team, 'school', _.toUpper);
    })

Now who has written ugly code like that in the past? I know I have. Of course
we can imporove it, this is just to show how bad things can get.

    var topTwo = _.filter(teamRanking, (team) => {
      return team.rank <= 2;
    })
    
    var prettyTopTwo = _.map(topTwo, (team) => {
      return _.update(team, 'school', _.toUpper);
    })

This code is more organized. We can clearely see the two transformations, and
the data produced has descriptive names. 

This is a coding practice I have seen a lot. Although it makes the code
easier to read. It also demonstrates the weaknes of these abstractions. All we
wanted was the final transformation. Instead we have an extra pice of data,
\`topTwo\`, which has no use or reuse.

Let's take a look at ES6 code to do the same thing.

    const topTwo = teamRanking
      .filter((team) => (team.rank <= 2))
      .map((team) => {...team, school: team.school.toUpperCase()})

This time we get rid of the intermedieate value and the code is more compact.
It's clear what's going on and we don't have functions wrapping everything.

This example barely scratches the surface of what's available with a transpiler
and ES6. Much of the functionaly of Lodash is present in ES6. Please
take a look at the standard [Array](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Array) and [Object](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Object) methods available for more. 

# Where lodash is still ahead

I can't go without saying that the nested object manipulation which Lodash
provides is far superior to what's available in ES6. The problem is that
we need to import the entirity of Lodash's core in order to get just a portion
of the functionality that we will use. However, there is a solution.

# Don't pick a side

You might be thinking that you have a hard choice to make here. Well the good
news is, there is a middle ground that can yield the best of both worlds!

I hope you remember Ramda from earlier. Well, Ramda doesn't have a
bloated core that Lodash does. It lets you build your own version of
Ramda with only the functions you need. Such as the object manipulation code.

*It has been brought up that Lodash is also modular. However, the size is only marginaly reduced due to how the core is used. In my experience, Ramda's size was greately reduced when only specific modules are used.*

Let's see our example with Ramda.

    const topTwo = R.filter((team) => {
      return team.rank <= 2;
    }, teamRanking);
    
    const prettyTopTwo = R.map((team) => {
      return R.assoc('school', R.toUpper(team.school), team);
    }, topTwo);

That looks really similar to the Lodash code. Ramda can do just
about everything Lodash can, but it can also do more.

If you payed close attention, you might have noticed that the arguments to the functions are
reversed, from Lodash. Ramda encurages a different style of programing. It's one
that can lead to better code quality and composability, but there are other great articles that
go into all the features. Just take a look at the [Ramda homepage](http://ramdajs.com/) for some great introductions.

I will just show a small refactor.

    const topTwo = R.filter((team) => {
      return team.rank <= 2;
    });
    
    const prettySchool = R.map((team) => {
      return R.assoc('school', R.toUpper(team.school), team);
    });
    
    R.compose(prettySchool, topTwo)(teamRanking)

This leaves us with two functions that do exactly one thing. We
are able to compose these functions and apply them one by one to the data.
\`compose\` makes this applcation even easier.

This has huge benefits compared to working with data like the previous examples.
We are able to resue the two functions for other team array, and can build them
more generically to allow for more reuse.

As it has been mentioned in the comments, much of the functionality of Ramda is actually available in Lodash through the recen addition of [lodash-fp](https://github.com/lodash/lodash/wiki/FP-Guide). I think both options are fine choices to imporove code reuse.

# Consider your options

I don't mean to say that you should ditch Lodash and runaway from it like you
probably should with jQuery. What I want to bring to light is that there are
many alternatives. So you should consider your options next time you are looking
for a library like Lodash.

I also want to praise Lodash. It moved JavaScript forward in a major way and
without all the concepts it introduced I don't think ES6 or Ramda would look the
same. Lodash is the giant that influanced much of moder JavaScript and it's
libraries. It accomplished what many of us strive to do. Lodash worked itself out of
a job.
