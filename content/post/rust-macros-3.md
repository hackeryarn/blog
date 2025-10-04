---
title: "Let's write a macro in Rust - Part 3"
date: 2025-09-28
draft: false
---

In the [last part](https://hackeryarn.com/post/rust-macros-2/) we covered all the fundamental techniques in writing macros. This enables us to write just about any macro we could think of, but knowing a few tricks can make the process much easier.

In this part, we will build on our `where` clause from the previous article. In the process we will allow the `where` clause to support multiple comparison operator (instead of just `=`) as well as multiple ways to join those operators (instead of just `and`).

## Complex where clause

Exactly what operator do we want to support? Lets add to our previous clause. Our macro should be able to support both of:

```rust
query!(from db select title, rating where rating = 10 and artist = "Teddy Swims");
query!(from db select title, rating where rating > 9 or artist = "Tool")
```

We can make this work, but it will result in more complexity than needed. Using the `=` operator means that we need to do a manual translation from `=` to Rust's `==` operator. If we just use `==` in our macro, we can use `==` and other Rust operators directly. Our updated syntax will look like:

```rust
query!(from db select title, rating where rating == 10 and artist == "Teddy Swims");
query!(from db select title, rating where rating > 9 or artist == "Tool")
```

But before we can implement the match arm, we need to talk about a concept that we've only skimmed over, so far.

### TokeTrees

Token trees are a part of Rust's AST that makes it easy to work with macros by giving them explicit bounds.

Almost every token in the AST (2, "hello", etc.) represents a leaf. `()`, `[]`, and `{}` are special tokens that start a new tree. A macro has to always take and produce a token tree, and that's exactly what our match arms represent. As far as macros care, all of the tree operators are interchangeable. So we could write our match arm as:

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

And the compiler is perfectly happy. Although, readers of your code might not be.

This is all interesting background, but how will it help us write our macro? Token trees are one of the fragment-specifiers that we can match, and we can take advantage of that to write a very concise macro definition.

### Matching complex where clause

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

We use a repeating capture of `tt` (TokenTree) to capture every TokenTree that follows the word `where`. Since every token is either a leaf or separator, `tt` will capture everything. One important caveat here is that macros can't look ahead or behind, so if we use a repeating `tt` capture, we will capture the rest of the macro. There is no breaking out of a repeating `tt` capture.

We then use a helper macro, `where_clause`, to process the captured token tree. We also pass through `i` using an arbitrary separator `;` that will make the implementation a little clearer. Using helper macros is a common technique that reduces the number of match arms a single macro would need to implement.

Now let's look at the `where_clause` macro that we need to implement. This will need a few clauses, and we will implement them one by one. We start with matching a single where clause with no `and` or `or`:

```rust
#[macro_export]
macro_rules! where_clause {
    ( $i:ident; $test_field:ident $comp:tt $value:literal ) => {
        $i.$test_field $comp $value
    };
}
```

That's a lot of captures. The only literal in there is `;`. But we've seen all this before. The most surprising thing here is that to capture and use the comparison operator, `$comp`, we have to use `tt`. It took me more time than I care to admit to figure out that operators are not identifiers so we can't use `ident` or any other fragment-specifier to capture it.

### Incremental TT muncher

To implement the other cases, we must use recursion. The arm we just implemented becomes the base case, and the other arms continuously all `where_clause`:

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

The next two captures only differ in the separator (`or` and `and`). They both capture all the parts of a single comparison expression and the next set of expressions as a repeating `tt`, just like we did in our original `where` clause. Then we can put together our conditional from the captures and join it, using `&&` or `||`, with another call to `where_clause!`. This is safe to do because we know that every arm of `where_clause!` will produce a valid conditional expression.


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

## Conclusion

With all these techniques under your belt, you should have no problem figuring out an implementing most declarative macros. There are still more techniques that can help, see [patterns](https://lukaswirth.dev/tlborm/decl-macros/patterns.html)
