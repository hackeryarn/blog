---
title: Type safe Django app, Part 3
date: 2019-02-11
categories: [Python]
tags: [django, python, types]
published: false
---

In [Part 2](https://hackeryarn.com/post/django-returns-2/) we got a taste of
using ~returns~ and create some simple model methods.

In this part, we will build out views that interact with databases and learn
how to combine ~returns~ containers. This composition of containers is the key
to effectively using types and where we will really see the benefit.

# Writ views that actually do something

The first view, introduced in the tutorial actually does a couple things which
we will split up into individual functions. Writing individual functions will
help us give names to the actions that we take, and allow us to more clearly
see how we can compose small functions with ~returns~.

The first part gets the 5 latest questions:

```python
@impure_safe
def _latest_question_list(model: Model) -> QuerySet[Model]:
    return model.objects.order_by("-pub_date")[:5]
```

As we saw before, this operation is impure and unsafe because it reaches out
to the database.

The next part extracts the text from each question.

```python
@impure_safe
def _questions_text(questions_list: QuerySet[Question]) -> list[str]:
    return [q.question_text for q in questions_list]
```

Somewhat surprisingly, this simple function is also impure and unsafe. We need
To mark it as unsafe because it will take a `QuerySet` and actually execute
the actions on it. When the action gets executed, Django will hit the database,
unless we have retrieved the data before.

Surprisingly, this function might also hit the database despite us only
accessing a property. Django tries to optimize `QuerySet`s as much as possible
so it delays running the query until it's really needed and then caches the
results. This means that we have no real way of knowing if this function will
hit the database or not, so we will err on the side of caution and mark it as
`impure_safe`.

Finally we can create our display string from the list of strings:

``` python
def _list_to_string(list_of_strings: list[str]) -> str:
    return ", ".join(list_of_strings)
```

This function is both pure, safe, and straight forward.

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

That's a lot of new functions. Let's take it step by step.

`flow` composes any number single argument functions. The first argument must
have the same type as the argument of the first function in `flow`. That
function must return the same type of argument as expected by the next function
and so on.

This process helps clearly show a pipeline of the transformations our data goes
through. We can easily see each step and modify or update them as we need to.

`bind` is a little trickier. If we carefully inspect the types of the functions
that we're trying to use in `flow` we will notice that something doesn't quite
line up. `_latest_question_list` returns a
`IOResultE[QuerySet[Question]]` but `_questions_text` expects a
`QuerySet[Question]`. ~bind~ will check our ~Result~ type, and if it's
successful, unwrap the IO so that `_questions_text` can get the
actual value. If the ~Result~ is a failure, then `questions_text` will never
run.

`map_` also unwraps the `IOResultE` wrapper from what `_questions_text` returns
but then it wraps it back up in the exact same layers that `_questions_text`
had.

`bind` and `_map` are closely related. Some languages/libraries even call
`bind` `flat_map`. The reason for this is that `bind` does the same thing
as `_map` but removes one of the layers.

If we ran `_map(_questions_text)` instead of `bind_questions_text` we would
have ended up with a return value of `IOResultE[IOResultE[...]]`.

The general rule is if the functions work inside the same context (return
the same container type), use `bind`. If the functions work in a different
context, and the latter function is pure and safe, use `_map`.

Finally we follow the same process as before to unwrap our new value and
return it as an `HttpResponse`.

This process took a lot of new concepts, but we will use them again and again.
Soon enough, they will become second nature.

## Using a template

Using a template introduces a new challenge. We can no longer use `flow` since
`template.render` requires two arguments. Let's see how we can make this work
without unwrapping twice.

First we create a small wrapper around `loader.get_template`:

```python
@impure_safe
def _get_template(path: str) -> Template:
    return loader.get_template(path)
```

This simply ensure that we get back the correct type. Since loading a template
require IO, we need to mark it as `impure_safe`.

Now we have all the pieces that we need to create our template:

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

First we get the two arguments we need to pass to `template.render` and both
are wrapped in an `IOResultE`. All our wrapper types also have methods
corresponding to the helper functions we've used in `flow`. Here we call `bind`
on the template and inside it we call `map` on the context. This exposes both
the raw variables allowing us to pass the expected type to `template.render`.

We have to call `bind` because the inner `map` application will return an
`IOResultE` and we don't want to end up with a double wrapper type.

That was a pretty complex process just to call a function with two arguments.
Usually, having to jump through hoops like this indicates that we could use a
better abstractions. In this case, Django has us covered.

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

That looks much simpler. It's a straight forward `flow` pipeline that we can
easily follow. Now that we are more familiar with our types, we can also get
rid of some of the wrappers by using `lambda` functions.

# Raising a 404 error

We have to deviate slightly from the tutorial here. `get_object_or_404` doesn't
buy us anything, so we will avoid using it. Instead, we will extend the example
a bit and handle both `404` and `500` errors depending on the type of failure
that we get.

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

Pythons 3.10 introduces case statements. These are prefect for our use here.
We can match the `IOResultE` type for either `Failure` or `Success`. We can
event further destructure the `Failure` to inspect the type of error. We can
Also destructure `Success` to access our `IO` action directly.

One thing to remember here, is that no matter where we get an error inside
`flow`, it will stop further computations and return a `Failure`.

# Wrap up

With that, we covered all the major pieces that we need to effectively use
`returns` with Django.

`returns` provides quite a few more tools, but they require more complex
scenarios and only provide slight variants of what we covered in this series.

The rest of the Django tutorial focuses on Django specific details and we won't
get to see anything new. This is where I will stop the series, but encourage
you to continue with the tutorial on your own and try to use what you have
learned.

