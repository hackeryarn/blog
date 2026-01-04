---
title: Type safe Django app, Part 3
date: 2022-04-16
published: 2022-04-16
draft: false
tags:
  - django
  - python
  - tutorial
keywords:
  - django
  - python
  - tutorial
  - returns
---

In [Part 2](https://hackeryarn.com/post/django-returns-2/) we got a taste of
using `returns` and created our first model methods.

In this part, we will build out views that interact with databases and learn how to combine returns containers. This composition is the key to effectively using container types and where we will see the benefits of all our work.

# Writ views that actually do something

The first view introduced in the official tutorial performs multiple actions which we will split up into individual functions. Writing individual functions will help us give names to the actions that we take, bring the types to the forefront, and clearly demonstrate how to compose small functions.

First off the view needs to get the last 5 questions:

```python
@impure_safe
def _latest_question_list(model: Model) -> QuerySet[Model]:
    return model.objects.order_by("-pub_date")[:5]
```

As we’ve seen before, this operation is impure and unsafe because it reaches out to the database.


The next action extracts the text from each question.

```python
@impure_safe
def _questions_text(questions_list: QuerySet[Question]) -> list[str]:
    return [q.question_text for q in questions_list]
```

Surprisingly, this simple function is also impure and unsafe. We need to mark it as unsafe because it will take a `QuerySet` and execute a lookup on it for `question_text`. When the lookup gets executed, Django will hit the database, unless we have retrieved the data before. Since, we have no way to know if we have the data already, it’s safer to mark it as impure and unsafe.

Lastly, we create a display string from the list of strings retrieved by _question_text:

``` python
def _list_to_string(list_of_strings: list[str]) -> str:
    return ", ".join(list_of_strings)
```

This function is pure, safe, and straight forward.

With the individual pieces working, we can combine them:

```python
def index(request: HttpRequest) -> HttpResponse:
    questions_string: IOResultE[str] = flow(
        Question,
        _latest_question_list,
        bind(_questions_text),
        map_(_list_to_string),
    )

    output = questions_string.value_or("No questions found.")
    response = unsafe_perform_io(output)
    return HttpResponse(response)
```

That’s a lot of new functions. Let’s break them down one by one.

`flow` composes any number single argument functions. The first argument must have the same type as the argument of the next function, which must return the same type as the argument of the function following it, and so on.

This process helps clearly show a pipeline of the transformations our data goes through. If we need to add or remove a step, we only modify one line and we’re done.

`bind` is a little trickier. If we carefully inspect the types of the functions that we’re trying to use in `flow`, we will notice that something doesn’t quite line up with our earlier observation o how `flow` works. `_latest_question_list` returns a `IOResultE[QuerySet[Question]]` but `_questions_text` expects `QuerySet[Question]`; the types don’t match.

`bind` handles this exact scenario. When applied to `IOResultE`, it will check the output. If the result is a `Success`, `bind` will unwrap `IOResultE` and pass it’s contents to `_questions_text`. If the `Result` is a `Failure,` `bind` will skip calling `questions_text` and move on to the next step in the pipeline.

`map_` performs the same steps as `bind`. It unwraps `IOResultE` and passes the value to `_list_to_string`, but instead of returning the value that `_list_to_string` returns, it wraps the value from `_list_to_string` in the `IOResultE` container (or `Success` to be more exact.)

`bind` and `_map` are closely related. Some languages/libraries even call `bind` `flat_map`. It’s often called `flat_map` because it does the same thing as `_map` but removes one of the layers.

If we ran `_map(_questions_text)` instead of `bind(_questions_text)`, we would ended up with a return value of `IOResultE[IOResultE[...]]`. This happens because both `_last_question_list` and `_questions_text` return a value wrapped in a `IOResultE`. Since this type communicates success or failure, we don’t need to know or care about how many times it had to succeed. We only care that all the action succeeded, which a single `Success` can communicate as well as 2 `Success` wrappers.

We can follow a general rule on when to use `bind` vs. `_map`. If both functions work inside the same context (return the same container type), use `bind`. If the functions work in a different context, and the latter function is pure and safe, use `_map`.

To wrap up the view function, we unwrap the value and return it as an `HttpResponse`.

This process required learning a lot of new concepts, but we will use them again and again. Soon enough, they will become second nature.

## Using a template

Using a template introduces a new challenge. We can no longer use `flow` since
`template.render` requires two arguments.

Let's see how we can make this work without unwrapping twice.

First we create a small wrapper around `loader.get_template`:

```python
@impure_safe
def _get_template(path: str) -> Template:
    return loader.get_template(path)
```

This simply ensure that we get back the correct type. Since loading a template
require IO, we need to mark it as `impure_safe`.

This gives us all the pieces that we need to create the template:

```python
def index(request: HttpRequest) -> HttpResponse:
    context: IOResultE[IndexContext] = flow(
        Question,
        _latest_question_list,
        map_(lambda lql: {"latest_question_list": lql})
    )
    template: IOResultE[Template] = _get_template("polls/index.html")
    template_string: IOResultE[str] = template.bind(
        lambda template: context.map(
            lambda context: template.render(context, request)
        ))

    output = template_string.value_or("No questions found.")
    response = unsafe_perform_io(output)
    return HttpResponse(response)
```

First we get the two arguments we need to pass to `template.render`. Both of these values are wrapped in an `IOResultE`. Luckily, all the wrapper types also have methods corresponding to the helper functions we’ve used in `flow`.

We can get the raw value by calling `bind` on the template and inside it calling `map` on the context. Then we just pass both the values to `template.render`.

We have to call `bind` because the inner `map` application will return an `IOResultE` and we don’t want to end up with a double wrapper type. If we had to unwrap more layers, we would call `bind` on all the layers except the last.

That was a pretty complex process just to call a function with two arguments. Usually, having to jump through this many hoops indicates that we could use a better abstractions. In this case, Django has us covered.

## A shortcut: render()

```python
def index(request: HttpRequest) -> HttpResponse:
    template_string: IOResultE[str] = flow(
        Question,
        _latest_question_list,
        map_(lambda lql: {"latest_question_list": lql}),
        map_(lambda context: render(request, 'polls/index.html', context))
    )

    output = template_string.value_or("No questions found.")
    response = unsafe_perform_io(output)
    return HttpResponse(response)
```

That looks much simpler. It’s a straight forward `flow` pipeline that we can easily follow. We can also start using lambdas instead of explicit helper functions as we become more comfortable with abstractions.

This example provides a more realistic example of how using `returns` looks likes.
# Raising a 404 error

We have to deviate slightly from the official tutorial here. `get_object_or_404` doesn’t buy us anything, so we will avoid using it. Instead, we will extend the example a bit and handle both 404 and 500 errors depending on the type of failure that we get:

```python
def detail(request: HttpRequest, question_id: int) -> HttpResponse:
    template_string: IOResultE[str] = flow(
        question_id,
        _get_question,
        map_(lambda question: {"question": question}),
        map_(lambda context: render(request, "polls/detail.html", context))
    )

    match template_string:
        case Failure(Question.DoesNotExist):
            return Http404("Question does not exist")
        case Failure(_):
            return Http500("Trouble getting the question")
        case Success(output):
            response = unsafe_perform_io(output)
            return render(request, "polls/detail.html", {"question": question})
```

The `flow` pipeline remains the same, we only add a new case statement to handle the final output. If you’ve never seen case statements in python, that’s to be expected.

Pythons 3.10 introduces case statements. These are prefect for our use case. We can match the `IOResultE` type for either `Failure` or `Success`. We can event further destructure the `Failure` to inspect the type of error, and `Success` to access the `IO` action directly.

One thing to remember here, is that no matter where we get an error inside `flow`, it will stop further computations and return that `Failure`. This gives us the ability only worry about the happy path inside `flow` and offload all the error handling to a single place.

# Wrap up

With that, we covered all the major pieces needed to effectively use `returns` with Django.

`returns` provides quite a few more tools, but they require more complex scenarios and only provide slight variants of what we covered in this series.

The rest of the Django tutorial focuses on Django specific details and we won’t get to see anything new. Therefore, this is where I will stop the series. But I encourage you to continue with the tutorial on your own and try to use what you learned here.
