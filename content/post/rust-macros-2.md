---
title: "Let's write a macro in Rust - Part 2"
date: 2025-08-24
draft: false
---

In the [last part](https://hackeryarn.com/post/rust-macros-1/) we covered the very basics of macros and implemented a single argument query select. This was a good start, but only scratched the surface of what macros can do.

In this part we will implement multi-field select and a basic `where` calause. That will make our query macro far more useful.

## Multi-field select

After being able to select one field, the immediate next thing that comes to mind is selecting multiple fields. Just like before, lets start with the invocation syntax:

```rust
query!(from db select title, rating)
```

Continuing to draw inspiratino from SQL, we use a comma separated list of fields. Using a separator, like a comma, turns out to be idiomatic Rust macro syntax for handling multiple value, so we are in luck with our choice.

### Matching multi-field select

```rust
  #[macro_export]
  macro_rules! query {
      ( from $db:ident select $( $field:ident ),+ ) => {
          ...
      };
  }
```

That's quite a bit of new syntax, but it all breaks down to a single new matching construct.

### Repetition match syntax

The general shape for matching repetition looks like:

```text
$ ( ... ) sep rep => {
  ...
  $ ( ... ) rep
  ...
}
```

We need to wrap the repeating match expression in `$()`, add a separator (a comma in our case), and finish it with a repetition operator. The repetition operator should look familiar as they draw inspiration from regex:

- `?` for zero or one
- `*` for zero or more
- `+` for one or more

I chose to use `+` because a blank select makes no sense.

The matcher and expansion connect through the captured variable names, and repeat the same number of times. Everything inside the expansion parentheses (`$()`) repeats, so we need to be careful about any literals that we put into the expression.

Once we have the repeating match, we can use it in the expression.

### Implementing multi-field select

```rust
  #[macro_export]
  macro_rules! query {
      ( from $db:ident select $( $field:ident ),+ ) => {
          $db.into_iter().map( |i| ($( i.$field, )+) ).collect()
      };
  }
```

You might be suprprised by the extra set of parentheses around the repetition parts. This is actually just a plain tuple.

Because we can return multiple fields, we have to create some kind of container. Since we can have fields of multiple types, a vector is out of the question. We could lean on `serde` and require a serializer instance, but that introduces a lot of overhead. A tuple gives us a simple wrapper that's easy to destructure and allows us to handle any number of fields with any mix of types.

And with that, we can execute our query with a multi select:

```rust
let results: Vec<(String, i64)> = query!(from db select title, rating);
// > [("Hate Me", 9), ("Not Like Us", 10), ("Bad Dreams", 10), ("Rockin' the Suburbs", 6), ("Lateralus", 8), ("Lose Control", 9), ("Come as you are", 9)]
```

We have to specify the type here, but if you were to use the values later, Rust's compiler can often infer the type.

### Debugging macros

With the repetition operators the macro gets hard to follow, and it will only get more complicated. This would be the perfect time to look at how we can debug macros.

Rust comes with everything we need to accomplish this built in. To see what macros expand to, we can run `RUSTFLAGS="-Ztrace_macros" cargo run` (note that you will need to use a nightly Rust version). This gets pretty noisy, however, since it expands _all_ macros in the entire program. To limit what expands, we can use a macro `trace_macros!`:

```rust
trace_macros!(true);
let results: Vec<(String, i64)> = query!(from db select title, rating);
trace_macros!(false);
```

This limits the scope to only what we want to analyze and returns the the expected output:

```text
// = note: expanding `query! { from db select title, rating }`
// = note: to `db.into_iter().map(| i | (i.title, i.rating,)).collect()`
```

The one odd thing about our debug output is the trailing comma in the tuple. Remember how I said that everything in the expansion `$()` repeats? We had a literal comma inside the repetition expansion so it gets included every time. Tuples and other collections allow trailing commas, but we will see some places, shortly, that do not.

## Where clause

So far we only have a `select` macro which is not much of a query. Let's make our macro more useful:

```rust
query!(from db select title, rating where rating = 10 and artist = "Teddy Swims");
```

We use `=` for comparison, and `and` as a way to support multiple comparisons. Just like with `select` we will start by only supporting these two operators and work up to supporting others.

### Matching where clause

We actually already have all the tools we need to match this new syntax:

```rust
#[macro_export]
macro_rules! query {
    ...

    ( from $db:ident select $( $field:ident ),+ where $($test_field:ident = $value:literal) and + ) => { };
}
```

We will leave our earlier `select` without `where` arm as is, and start a new arm that includes `where`. This should look very familiar although slightly expanded. Our second repetition matcher captures two values (`$test_field` and `$value`) and uses a multi-character separator (` and `) before the repetition operator. Both of these demonstrate the power and flexibility of macro matchers.

The only thing we have not seen yet is the use of a new fragment-specifier. The `literal` specifier lets us use the value exactly as it is. A string will be a string, a number a number, etc.

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

To do the comparison, we add a call to `.filter` that will run the comparison based on the field identifier and the literal. This shows that the `ident` fragment-specifier works for a lot more identifiers than just variables.

One thing to note is that we had to put the `&&` outside the repetition parentheses. Unlike the tuple syntax, we can't have a dangling `&&` at the end of our conditional and putting it outside the parentheses will skip adding it to the last item.

With this arm implemented, our previous select should continue to work and we can put the new `where` syntax to work:

```rust
let results: Vec<(String, i64)> =
    query!(from db select title, rating where rating = 10 and artist = "Teddy Swims");
// [("Bad Dreams", 10)]
```

As expected, we only get one item. As an additional sanity check, we can expand the macro again with `trace_macros!`:

```rust
db.into_iter()
    .filter(| i | i.rating == 10 && i.artist == "Teddy Swims")
    .map(| i | (i.title, i.rating,)).collect()
```

And we get the exact result we would expect. Both the condition appear in the `filter` expression, and they are separated by an `&&`.

## Conclusion

This part expands the macro functionality to far more scenarios. It also covers all the major concepts of declarative macros. With these tools, you should be able to write a wide range of declarative macros.

In the next part we will look at handling multiple operators in our `where` clause. This will push our tools to their limit and we will need to use one of the most powerful pattern for declarative macros.
