---
title: You don't need a map for that
published: 2024-01-01
tags:
  - discussion
  - development
keywords:
  - discussion
  - development
  - map
  - patterns
---
One of the most misused data structures is the humble map; hashmap,
dictionary, hash table, etc.

It\'s a great data structure for quick storage and access of key value
pairs. Unfortunately, because of its ease and availability, it becomes
pervasive at jobs it has no business doing. The problem grows most
visible in dynamically typed languages that make the map a first class
citizen (Python, Ruby, Clojure, etc.), but it can creep up in any
language.

## Passing around data

This is the most common case where the map might tempt us. Let\'s play
out a common scenario.

We have a some values that we need to pass to multiple functions. We
don\'t want to make all these functions take 5 new arguments, so what
can we do?

We can stick the values in a data structure. We could put them in a
list, but keeping the order and retrieving the value at the right
location would quickly become error prone.

Instead, we can give each value a short name and stick it in a map. Then
each function can retrieve exactly what it needs and we don\'t have to
worry about order. Everything works nicely.

After a couple weeks, we decide to reuse one of the functions that takes
a map. But what keys did the function need from the map? That\'s easy
enough to figure out. We pop open the source and take a peek. We see a
couple keys used, but then the map gets passed to another function. Time
to look at the source of that function as well. We see 3 new keys here
and 1 key used in the previous function. That make 4 keys total. Great!

Time to... what were we doing before we started spelunking down this
call stack? Was the first key we saw `integration` or `integrations`?
And was the value of that last key a string or a boolean?

## The problem with using a map

A myriad of problems comes up as soon as we need to work with code that
relies on maps:

- We have to read the source to figure out the expected keys
- We can easily make the mistake of mistyping or forgetting the name of
  a key
- We have no way to know the types of value a map expects, unless we
  know ahead of time that all the values require the same type

These are not problems with a map structure itself; these are problems
with how we are using the map.

## One simple rule

To remedy most cases of map misuse, we can follow one simple rule. If we
know the keys of a map, we should not use a map. Instead, we should use
a struct, TypedDict, object, or any of the other abstraction that allow
us to specify the expected keys and, hopefully, value types.

By using these other methods of specification, we enable:

- Easy lookup of keys
- Static checks of the key names and value types
- Informative error messages if we make a mistake
- Editor assistance with supplying the right values

Just by following this rule we can save our future self from frustration
and reserve maps for what they are really meant for: storing large
numbers of key value pairs for fast lookup.
