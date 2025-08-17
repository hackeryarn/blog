---
title: "Let's write a macro in Rust"
date: 2025-07-30
draft: true
---

Macros are required to do some very helpful things in Rust, but this isn't an article about any of those things.

I became ennamored with macros many years ago when I read [Pracctical Common Lisp](https://gigamonkeys.com/book/) and saw the implementation of a database DSL to work with built in data structures. The whole implementation took less than a screen of code and absolutely blew away my expectations of what it took to create DSLs.

In this article, I will try to share some of that excitement with you while using Rust's macro system. Will this be the most practical and useful macro you can write? Absolutely not. I only hope to show you some possibilities of this powerful tool.

## Brief history

Macros have a rich history across many decades and languages.

This first and most basic macros designed were simple text substitution macros. As the name implies, they work with text directly and provide very little help in making sure what you generate makes sense in the language. Assembler, C, and even Go implement these types of macros as a pre-processor layer in the compiler. You can forget about these right away. Rust has no suppors or use for these.

The Lisp family of languages took this concept further and introduced syntax macros. These macros worked at the AST ([Abstract Syntax Tree](https://en.wikipedia.org/wiki/Abstract_syntax_tree)) level, although in lisp it's hard to tell since lisp syntax is essentially its AST. These macros provided ways to work with the values present in the language and eliminated the need to manually parse data. Rust supports syntax macros as procedural macros.

Scheme, a subset of the Lisp family of languages, took syntax macros even further by introducing the concept of fully hygienic macros. To accomplish this, scheme added more syntax for how macros were declared. This new syntax made writing the most common types of macros much clearer, and most importatly ensured that many of the problems around leaking identifiers were no longer possible. This became the `macro_rules!` declarative macro syntax in Rust.

For a long time it seemed like these features might cover everything developers needed from macros. The creators of [Racket](https://racket-lang.org/), however, had different ideas. They are actively working to push macros to their absolute limit. Using Racket you can create entire macro based languages, with IDE support and beautiful error messages. If you are interested in seeing how far the rabbit hole goes [Beautiful Racket](https://beautifulracket.com/) makes for a great entry point.

## Back to Rust

After that bit of history, let's get back to our topic. Out of all the possible ways to write macros in Rust, we will focus on declarative macros. They are the most advanced and easiest to work with out of the different macro styles that Rust offers.

Declarative macros are implemented as a special macro (`macro_rules!`), and provide a `match` like DSL. This DSL makes it possible to write conscise macros without working with the AST or TokenStreams directly.

## Macro design process

Since every time we write a macro, we creat a DSL it's important to keep some rules and processes in mind. With that in mind, these are the rough steps that we should follow when writing macros:

- Evaluate if you need a macro
- Design the simplest possible invocation first (determine what your DSL looks like)
- Try to implement a match arms and adjust the invocation as needed
- Work one match arm at a time
- Write sub macros where possibl

### Don't write macros

The very first, and very counterintuitive, thing you must do is evaluate if you need a macro.

Macros bring a lot of complexity in writing and debugging with them. You are introducing another compilation step in your code, and often times erasing some of Rust's ability to help you write correct code. On top of all this, making code generic enough for macros can lead to far more complex types -- just look at `serde`.

Because of this overhead, you have to really evaluate if you even need a macro. Rust is a powerful language with lots of abstractions. You should always see if those abstraction can lead to a simpler and more maintainable solution, even if it means a little more boilerplate for your end user.

## The simplest query! macro

Since we decided to write a macro for practice, lets jump right to the second step and design our invocation:

```rust
query!(from db select title)
```

`db` will be the data structure that we want to query. And we will support `select` for picking a field from the items in the data structure. Working in the abstract makes it really hard to reason about how we want this structure to work, so let's put together some data.

We will borrow the domain from Practical Common lisp and work with a list of songs. A song will be a simple structure:

```rust
struct Song {
  title: String,
  artist: String,
  rating: i64,
}
```

And to make a database of songs, we will just throw a bunch of songs into a vector:

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

Now that we know what we want our dsl to look like and what it should output, we can start working on our macro. Let's jump right in and explain the details as we go:

```rust
#[macro_export]
macro_rules! query {
  ( from $db:ident select $field:ident ) => { };
}
```

> If you want to follow along, remember that macros need to be declared in their own module.

The basic syntax is `($matcher) => {$expansion}`. If you squint, it looks just like a `match` statement, and that's what makes these types of macros so easy to work with.

Just about everything in the matcher -- we will see a couple exception later -- is treated as a literal. `$` denotes a variable for what we actually want to capture. Everything that we capture must also have a fragment-specifier (you can think of it as a type). There are 14 possible fragment-specifiers that we could capture, see [Metavariables](https://doc.rust-lang.org/reference/macros-by-example.html#metavariables) for a full list, but in our case we are only capturing `ident`.

We capture two identifiers. One for the database what we want to query, and one for the field that we want to extract. The identifiers provide a lot of flexibility as we will see shortly.

With this match arm declaration, we can write our macoro without any errors, but without any result either.

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

This is the part where we get to make the decisions of how our macro works. I am choosing to use `into_iter` so that our macro can work with an `Iterator` trait. This is great for flexibility and an intuitive choice. But, it reveals a weakness of macros. We have no way to help the user know that they need to provide an `Iterator`. They would need to read the docs or, hopefully, guess correctly.
l
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

## Multi-field select

After being able to select one field, the immediate next thing that comes to mind is selecting multiple fields. As always, lets start with our invocation syntax:

```rust
query!(from db select title, rating)
```

Just like in SQL, it would be great if we could just provide our fields separated by commas. Luckily this is not only possible, but idiomatic rust macro syntax.

### Matching multi-field select

`macro_rule!` has the exact thing we need for repeating fields:

```rust
  #[macro_export]
  macro_rules! query {
      ( from $db:ident select $( $field:ident ),+ ) => {
          ...
      };
  }
```

That's quite a bit of new syntax, but if you are familiar with regex, it shouldn't be too hard to descipher.

### Repetition match syntax

The general shape for matching repetition looks like:

```text
$ ( ... ) sep rep => {
  ...
  $ ( ... ) rep
  ...
}
```

We need to wrap a nested match expression in a `$()`, add a separator (a comma in our case), and finish it with a repetition operator. The repetition operators take inspiration form regex:

- `?` for zero or one
- `*` for zero or more
- `+` for one or more

I chose to use `+` because a blank select makes no sense.

Once we have the repeating match, we can use it in the expression with an almost identical syntax. We wrap the usage in `$()` and use the same repetition operator that we applied in the matcher.

### Implementing multi-field select

Let's use the our knowledge of the match syntax to implement the full expression:

```rust
  #[macro_export]
  macro_rules! query {
      ( from $db:ident select $( $field:ident ),+ ) => {
          $db.into_iter().map( |i| ($( i.$field, )+) ).collect()
      };
  }
```

That might look a little surprising. You might have noticed the extra set of parentheses around the repetition usage. This extra set of parentheses wraps the repetition in a tuple.

Because we have to return mupltiple fields, we had to create some kind of container. Since we can have fields of multiple types, a vector is out of the question. We could lean on `serde` and require a serializer instance, but that introduces a lot of overhead. A tuple gives us a simple wrapper that's easy to destructure and allows us to handle any number of fields with any mix of types.

The careful reader might have also noticed the comma inside the repetition expression: `$( i.$field, )`. That is a literal comma. Since the items in a tuple, and other data structures, need to be comma separated, Rust's repetition syntax makes it easy to add those separators. If we put literals inside the parentheses, we will get the separator after every item. If we put them outside the parentheses, right before the repetition operator, we will get the separator after every item except the last. With tuples, there is no difference.

And with that, we can execute our query with a multi select:

```rust
let results: Vec<(String, i64)> = query!(from db select title, rating);
// > [("Hate Me", 9), ("Not Like Us", 10), ("Bad Dreams", 10), ("Rockin' the Suburbs", 6), ("Lateralus", 8), ("Lose Control", 9), ("Come as you are", 9)]
```

We have to specify the type here, but if you were to use the values later, the Rust's compiler can often infer the type.

### Debugging macros

With the repetition operators the macro gets hard to follow, and it's only going to get more complicated. This would be the perfect time to look at how we can debug macros.

Rust comes with everything we need built it. To see what marocs expand to, we can run `RUSTFLAGS="-Ztrace_macros" cargo run` (note that you will need nightly rust version). This gets pretty noisy, however, since rust will expand all the macros in the entire program. To limit what expands, we can use `trace_macros!` macro:

```rust
trace_macros!(true);
let results: Vec<(String, i64)> = query!(from db select title, rating);
trace_macros!(false);
```

This gives us the exact output of what the macro expands to. Even including the trailing comma:

```text
// = note: expanding `query! { from db select title, rating }`
// = note: to `db.into_iter().map(| i | (i.title, i.rating,)).collect()`
```
 
## Where clause

So far we only have a `select` macro without much querying. Now it's time to change that by adding a where clause:

```rust
query!(from db select title, rating where rating = 10 and artist = "Teddy Swims");
```

We actually have all the tools we need to jump a couple steps and supporst a where clause with `=` for comparison and multiple parameters with `and`. We will see later how we can support more operators.

### Matching where clause

```rust
#[macro_export]
macro_rules! query {
    ...

    ( from $db:ident select $( $field:ident ),+ where $($test_field:ident = $value:literal) and + ) => { };
}
```

We can leave our match arm for the select only syntax and just create a new arm. This one captures multiple parameter, and uses `and` as the separator. Surprisingly separators don't have to be a single character and can be full words or evele parameter, as we will see later.

### Implementing where clause

```rust
#[macro_export]
macro_rules! query {
    ...

    ( from $db:ident select $( $field:ident ),+ where $($test_field:ident = $value:literal) and + ) => {
        $db.into_iter()
            .filter( |i| ($( i.$test_field == $value )&&+ )
            .map( |i| ($( i.$field, )+) ).collect()
    };
}
```

The only new thing in our emplementation is the use of a new fragment-specifier. The `literal` specifier lets us use the value passed in exactly as it is. A sting will be a string, a number will be a number, etc. This is perfect since we need a value to compare to our field.

 To do the comparison, we add a call to `.filter` that will only select matching items. One thing to note is that we had to put the `&&` outside the repetitin parentheses. Unlike the tuple syntax, we can't have a dangling `&&` at the end of our conditional and putting it outside the parentheses will skip adding it to the last item.

With this arm implemented our previous select should continue to work and we can put the new `where` syntax to work:

```rust
let results: Vec<(String, i64)> =
    query!(from db select title, rating where rating = 10 and artist = "Teddy Swims");
// [("Bad Dreams", 10)]
```

As expected, we only get one item. As an additional sanity check, we can expand the macro again with `trace_macos!`:

```rust
db.into_iter()
    .filter(| i | i.rating == 10 && i.artist == "Teddy Swims")
    .map(| i | (i.title, i.rating,)).collect()
```

And we get the exact result we would expect. Both the condition appear in the `filter` expression, and they are separated by an `&&`.

The final step will be to support more operators in our `where` clause. But before we can get to that, we need to look at a concept that we've been using all along but have not talked about.

## Complex where clause

Let's continue with our process from before and use the token trees shortly. To start, here is the syntax that we want:

```rust
query!(from db select title, rating where rating > 9 or artist = "Tool")
```

And we can make that work, but it will result in some more complexity than needed. We can actually reduce the complexity by switching our equality operator to Rust's `==` instead of `=`. I know this because I implemented this macro, and it came as a natural choice. I am just trying to save us some time, so we won't go through the long version here. Our final syntax will be:

```rust
query!(from db select title, rating where rating > 9 or artist == "Tool")
```

But before we can implement the match arm, we need to talk about a concept that we've skimmed over so far.

### TokeTrees

Token trees are a concept in Rust's AST that makes it easy to work with macros and know what they cover.

Almost every token in the AST (2, "hello", etc.) represents a leaf. `()`, `[]`, and `{}` are special tokens that start a new tree. A macro has to always take and produce a token tree, and that's exactly what our match arms represent. And as far as macros care, all of these are interchangeable. So we could write our match arm as:

```rust
{ from $db:ident select $( $field:ident ),+ where $($test_field:ident = $value:literal) and + } => (
    $db.into_iter()
        .filter( |i| ($( i.$test_field == $value )&&+ )
        .map( |i| ($( i.$field, )+) ).collect()
);
```

Or call our macro as:

```rust
    query![from db select title, rating where rating = 10 and artist = "Teddy Swims"];
```

And the compiler is perfectly happy.

This is all neat to know, but for our purpose, token trees have a very important property. They are one of the fragment-specifiers that we can match, and we can put that to great use.

### Matching complex where clause

As promised, we will use TokenTrees right away in our match clause. We will also implement this right away since we have some experience and it will make things easier to talk about:

```rust
#[macro_export]
macro_rules! query {
    ...

    ( from $db:ident select $( $field:ident ),+ where $($where_tree:tt)+ ) => {
        $db.into_iter()
            .filter( |i| where_clause!(i; $($where_tree)+) )
            .map( |i| ($( i.$field, )+) ).collect()
    };
}
```

We use a repeating capture of `tt` (TokenTree) to capture every TokenTree that follows the word `where`. Since every token is either a leaf or separator, `tt` will capture everything. One important caviate here is that macros can't look ahead or behind, so it we use a repeating `tt` capture, we will capture everything. There is no breaking out of a repeating `tt` capture.

We then use a helper macro, `where_clause`, to process the captured token tree. We also pass through `i` using an arbitrary separator `;` that will make the implementation a little clearer. Using helper macros is a common technique that reduces the number of match arms and the complexity of those arms.

Now let's look at the `where_clause` macro that we need to implement. This will need a few clauses, and we will implement them one by one. We will start with matching a single where clause with no `and` or `or`:

```rust
#[macro_export]
macro_rules! where_clause {
    ( $i:ident; $test_field:ident $comp:tt $value:literal ) => {
        $i.$test_field $comp $value
    };
}
```

That's a lot of captures. The only literal there is `;`. But we've seen all this before. The most surprising thing here is that to capture and use the comparison operator, `$comp`, we have to use `tt`. It took me more time than I care to admit to figure out that operators are not identifiers so we can't use `ident` or any other fragment-specifier to capture it.

### Incremental TT muncher

Then we can implement the other cases in a recursive fashino that works down to the match arm we just implemented:

```rust
#[macro_export]
macro_rules! where_clause {
    ( $i:ident; $test_field:ident $comp:tt $value:literal ) => {
        $i.$test_field $comp $value
    };

    ( $i:ident; $test_field:ident $comp:tt $value:literal and $($tail:tt)+ ) => {
        $i.$test_field $comp $value && where_clause!($i; $($tail)+)
    };

    ( $i:ident; $test_field:ident $comp:tt $value:literal or $($tail:tt)+ ) => {
        $i.$test_field $comp $value || where_clause!($i; $($tail)+)
    };
}
```

This shows a common technique in Rust known as the incremental TT muncher. We use the same technique as in our `query` macro to capture everything following an `or` or an `and`. Then we pass that remainder back to `where_clause` and let it continue processing the input. Each time we go through `where_clause`, we produce a valid condition so we know that we can continue to connect them with `&&` and `||` as needed.

### Stepping through complex expansions

That was a lot of abstract code. Luckily, we can use the debugging tools to get a clearer image of how all of this evaluates:

```rust
let results: Vec<(String, i64)> =
    query!(from db select title, rating where rating > 9 or artist == "Tool");
// [("Not Like Us", 10), ("Bad Dreams", 10), ("Lateralus", 8)]

// Expands to:
// = note: expanding `query! { from db select title, rating where rating > 9 or artist == "Tool" }`
// = note: to `db.into_iter().filter(| i | where_clause!
//         (i; rating > 9 or artist == "Tool")).map(| i | (i.title, i.rating,)).collect()`
// = note: expanding `where_clause! { i; rating > 9 or artist == "Tool" }`
// = note: to `i.rating > 9 || where_clause! (i; artist == "Tool")`
// = note: expanding `where_clause! { i; artist == "Tool" }`
// = note: to `i.artist == "Tool"` 
```

The expansion becomes quite a bit more complex because we used helper macros, but it still clearly lists out all the steps. I usually have to read these types of expansions in a multi step process:

1. Scan everything from top to bottom to get the general idea of the expansion
2. Start back from the bottom with the last line
3. Take the line I am on (`i.artist == "Tool"`)
4. Look at the expansion above it (`i.rating > 9 || where_clause! (i; artist == "Tool")`)
5. Substitute the line we started on into this expansion (`i.rating > 9 || i.artist == "Tool"`)
6. If there are more lines above, go back to step 3 using the substituted expansion from step 5, and repeat this until I am on the last (top most) line

By following this process I can get a clear picture of exactly what each step in the expansion does.
