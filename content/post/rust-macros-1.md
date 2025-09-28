---
title: "Let's write a macro in Rust - Part 1"
date: 2025-08-17
draft: false
---
Macros are required to do some very helpful things in Rust, but this isn't an article about any of those things.

I became ennamored with macros many years ago when I read [Practical Common Lisp](https://gigamonkeys.com/book/) and saw the implementation of a SQL DSL that works with built in data structures. The whole implementation took less than a screen of code and absolutely blew away my expectations of what it took to create DSLs.

In this article, I will try to share some of that excitement with you while using Rust's macro system. Will this be the most practical and useful macro you can write? Absolutely not. I only hope to show you some possibilities of this powerful tool.

## Prior art

Rust's macros build on top of a long legacy of syntax macros primarily seen in the Lisp language family. Unlige Go, C, and Assembly macros, which work as a pre-processor step on raw strings, Rust's macros work dircectly on the AST ([Abstract Syntax Tree](https://en.wikipedia.org/wiki/Abstract_syntax_tree)). This means that Tokenization and AST parsing has already occurred, so you can be sure that the what you work with is at least shaped like hypothetican Rust code.

Unlike the Lisp family of languages, Rust had some additional challenges to overcome with their macro implementation.

Lisp has a syntax that's basically an AST, so it is extremely easy to consume and produce an AST, because it looks like normar code. Rust, on the other hand, looks nothing like Lisp or an AST, so it needs a way to elegantly handle these conversion steps. That's where the `macro_rules!` macro comes in, which will be the focus of this article.

The other challenge within `macro_rules!` comes from Rust's goal to provide as much help and correctness as possible. Rust actually supports types (technically fragment-specifiers) in macros. We will see more of this later, but it goes towards making macros easier to write, reason about, and maintain.

Without further ado, let's jump into using `macro_rules!` and declerative macros.

## Macro design process

Since every time we write a macro, we creat a DSL it's important to keep some rules and processes in mind. With that in mind, these are the typical steps that we should follow when writing macros:

- Evaluate if you need a macro
- Design the simplest possible invocation first (determine what your DSL looks like)
- Try to implement a match arms and adjust the invocation as needed
- Work one match arm at a time
- Write sub macros where possible

Some of these steps might not mean much to you yet, but we will walk through them a few times while designing our final macro.

### Don't write macros

Before we start writing a macro, we should always evaluate if it is the best choice for the problem in hand. I know this is an odd step to start with for an article about writing macros, but macros get frequently abused, and we should strive to use all our tools well.

Macros bring a lot of complexity in writing and debugging them. You are introducing another compilation step in your code, and often times erasing some of Rust's ability to help you write correct code. On top of all this, making code generic enough for macros can lead to far more complex types than you could accomplish with a little more boilerplate.

Because of this overhead, you have to really consider the tradeoffs that you're making. Rust is a powerful language with lots of abstractions. Often times, the existing tools can get you to your goal without resorting to macros.

In our case, we are writing the macro for practice, so these concerns don't apply here.

## The simplest query! macro

Lets jump right to the second step and design our invocation:

```rust
query!(from db select title)
```

`db` will be the data structure that we want to query. We will start with supporting a single argument `select` for picking a field from the items in the data structure. Working in the abstract makes it really hard to reason about how we want this structure to work, so let's put together some sample data.

We will borrow the domain from Practical Common Lisp and work with a list of songs. A song is a simple structure:

```rust
struct Song {
  title: String,
  artist: String,
  rating: i64,
}
```

And to make a database of songs, we can just throw a bunch of songs into a vector:

```rust
let db = vec![
  Song::new("Hate Me".to_string(), "Blue October".to_string(), 9),
  Song::new("Not Like Us".to_string(), "Kendrick Lamar".to_string(), 10),
  Song::new("Bad Dreams".to_string(), "Teddy Swims".to_string(), 10),
  Song::new(
    "Rockin' the Suburbs".to_string(),
    "Ben Folds".to_string(),
    6,
  ),
  Song::new("Lateralus".to_string(), "Tool".to_string(), 8),
  Song::new("Lose Control".to_string(), "Teddy Swims".to_string(), 9),
  Song::new("Come as you are".to_string(), "Nirvana".to_string(), 9),
];
```

Now if we come back to our invocation, we can fill in the desired output:

```rust
query!(from db select title)
// > ["Hate Me", "Not Like Us", "Bad Dreams", "Rockin' the Suburbs", "Lateralus", "Lose Control", "Come as you are"]
```

### Our first match arm

Now that we know what we want our dsl to look like and what it should output, we can start working on our macro. Let's look at the implementation and fill in the gaps from there:

```rust
#[macro_export]
macro_rules! query {
  ( from $db:ident select $field:ident ) => { };
}
```

> If you want to follow along, remember that macros need to be declared in their own module.

The basic syntax is `($matcher) => {$expansion}`. If you squint, it looks just like a `match` statement, and that's what makes these types of macros so easy to work with.

Just about everything in the matcher is treated as a literal. `$` denotes a variable for what we actually want to capture. Everything that we capture must also have a fragment-specifier (you can think of it as a type). There are 14 possible fragment-specifiers that we could capture, see [Metavariables](https://doc.rust-lang.org/reference/macros-by-example.html#metavariables) for a full list, but in our case we are only capturing `ident`.

`ident` denotes an actual identifier or keyword declared somewhere outside the macro. We capture two identifiers. One for the database what we want to query, and one for the field that we want to extract.

We can run this declaration to make sure it executes without any error, but we won't see any result a until we implement the expansion.

### Implementing single field select

Now that we have a match, we need to put it to use.

  ```rust
  #[macro_export]
  macro_rules! query {
      ( from $db:ident select $field:ident ) => {
        $db.into_iter().map(|i| i.$field).collect()
      };
  }
```

This is the part where we get to make the decisions of how our macro works. I am choosing to use `into_iter` so that our macro can work with anything that implements the `Iterator` trait. This is great for flexibility and an intuitive choice. But, it reveals a weakness of macros. We have no way to help the user know that they need to provide an `Iterator`. They would need to read the docs or guess correctly.

You can also see the flexibility of the `ident` fragment specifier. We are using it for a variable and a struct field name.

With this implementation we can actually run our macro, and get the expected output:

```rust
let results: Vec<String> = query!(from db select title);
// > ["Hate Me", "Not Like Us", "Bad Dreams", "Rockin' the Suburbs", "Lateralus", "Lose Control", "Come as you are"]
```

And if we mistype the field name, we get a very helpful error message:

```rust
let results: Vec<String> = query!(from db select titles);
// > no field `titles` on type `Song`
```

## Conclusion... for now

This article sets up the groundwork for the macro that we want to build. Our goal is to get to macro like:

```rust
query!(from db select title, rating where rating > 9 or artist == "Tool");
```

In the next part we will make progress toward that goal and explore some more advanced macro techniques.
