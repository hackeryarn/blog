---
title: When DRY goes wrong
date: 2023-02-20
published: false
---

DRY has become a mantra throughout the industry. Any time repetitive code shows up, DRY gets applied as a cure all. If you even start to question drying up a piece of code, you are viewed as a heretic to the entire industry.

Ok, maybe it's not that bad, but many times DRY gets applied without much thought. This careless application of DRY leads to brittle code, making even simple changes scary because they could have a huge ripple effect.

In this article I hope to show how this happens and cover different ways to look for abstractions. I will even make an argument that duplication is good in the right setting.

## An example

First off, to keep things simple, we are only going to just work with functions. I am not going to cover how these concepts work when using classes, typeclasses, traits, or interfaces. I know how tempting it will be to use a cleaner form of abstraction, but doing that would lead us down a whole new set of rabbit holes.

Our example will consist of an application to calculate salaries of employees at different levels. We start out with two types of employees. And right away we notice repetition creeping up:

```python
def calculate_ic_compensation(employee):
    salary = 0
    # some calculations before...
    if employee.bonus:
      salary += employee.bonus / 12
    # more calculations after...

def calculate_manager_compensation(employee):
    salary = 0
    # some calculations before...
    if employee.bonus:
      salary += employee.bonus / 12
    # more calculations after...
```

Now, would you want to extract this code into its own function? I know I would. And is the repetition a good enough reason for the extraction?

I think that this is absolutely the right case for extraction, but not because of the repetition. There is a more subtle reason why we should extract this code, which we will get to later.

For now, let's proceed with extracting the repetitive code:

```python
def calculate_bonus(employee):
    if employee.bonus:
        return employee.bonus / 12
    return 0

def calculate_ic_compensation(employee):
    salary = 0
    # some calculations before...
    salary += calculate_bonus(employee)
    # more calculations after...

def calculate_manager_compensation(employee):
    salary = 0
    # some calculations before...
    salary += calculate_bonus(employee)
    # more calculations after...
```

When we extract this code, we create a clean separation of concerns. We have a single place that deals with bonus calculations and functions that use the bonus calculation when calculating the employee's compensation.

Everything looks great so far.

## How problems arise

As our code lives for a few weeks or months, it grows. And more functions start using `calculate_bonus`. Calculations for directors and VPs also started using this same function. This company is all about equality, so everyone has the same bonus structure.

But we just got a requirement to handle C-Level employee's compensations, and their bonus structure is a little different. For every year that they were with the company, they get an additional $2,000 bonus.

How would you handle this situation?

We have two reasonable options. We can add this logic into the new `calculate_clevel_compensation`, or we can expand `calculate_bonus`.

Adding this logic into `calculate_clevel_compensation` doesn't quite feel right. We already isolated the concept of bonus calculation into its own function. Putting the calculation here would just spread our bonus calculation logic across multiple functions.

That leaves us with keeping all the bonus calculating logic together. Here is how we might expand `calculate_bonus` to handle the new requirement:

```python
# If a second argument is not passed in, we set it to False
def calculate_bonus(employee, clevel=False):
    bonus = 0 

    if employee.bonus:
        bonus += employee.bonus / 12

    if clevel:
        bonus += 2000 * employee.years_worked

    return bonus
```

On the surface this looks like a good solution. By providing a default value for `clevel` we avoid having to update the old function invocations, and our new function just has to provide one flag.

Now, what would happen if another position gets a different bonus structure? We could just add another flag, add another `if`, and make sure all the right places use the right flags.

And what if there is some shared logic between two of those flags? Or what if multiple flags need to interact with each other in some special way? You can see how this innocent function can quickly get out of hand.

These problem arise because this solution has two serious problems.

First off, it introduces a new option named `clevel` which has nothing to do with the concept of a bonus calculation. It's related to the role which should be fully encapsulated by the function calling `calculate_bonus`.

This bleeding over of concepts makes code significantly harder to follow. Because `clevel` tells us nothing about how it might impact the bonus calculation, we have to read two functions and keep track of the related parts in our minds. And if we have more of these "helper" functions, we end up having to keep a lot of information in our head just to understand the flow of a single calculation.

The other problem is closely related to the first, but more insidious. Having the level as part of the bonus calculation tightly couples this function to the concept of levels. We lose all ability to apply this function in different contexts.

If we want to run a simulation that shows the impacts of different bonus structures, we have to introduce levels into this simulations even though we don't care about levels when simulating bonus structures. This kills DRY's promise of re-usability.

These are some serious issue, but not all is lost. Let's look at a way that we can identify and fix these problems.

## Abstraction Barriers

A better approach to breaking up functions comes form a concept significantly older than DRY. Abstraction barriers were first formally introduced in [Structure and Interpretation of Computer Programs](https://sarabander.github.io/sicp/html/2_002e1.xhtml#g_t2_002e1_002e2), published in 1984.

I encourage you to read the section linked above if you're not afraid of too many parentheses. But for the purpose of this article I can sum up this concept as: build abstractions in well defined layers.

Without reading the linked section, you might wonder what constitutes a layer. The most basic layer that every program has is the language itself. All the builtin functions and operators create an abstraction layer over the machine code that executes the program. We would almost never want to go below the level of our language, so it is the bottom of our layers stack.

The next most common layer is made up of the libraries that we import. They usually provide further abstraction over the language that allows us to work in terms of the library's domain.

The layers that we build should work in almost the same way as libraries. Each one providing a clear and encapsulated domain.

When we started our program, we were working in a layer that deals with employees and their levels. By extracting our function, we unintentionally introduced a new layer. This made the layer look like it was for calculating bonuses, but that's too narrow. We created a layer for financial calculations.

If you prefer to think of it in terms of domains: The first layer belongs to the HR domain. It deals with employees, and what their levels entail.

The second layer belongs to the accounting domain. It deals with the details that go into calculating certain financial concepts -- bonuses being one of them.

If we need clarification on terminology or functionality, this distinction points us towards the right group to talk to. It also keeps our code closely align to how the real world works. And this is a good thing because our programs emulate the real world.

## Applying Abstraction Barriers

After identifying these layers, it becomes easy to see that our terminology doesn't quite match. We should switch `calculate_bonus` to use terminology that only relates to calculations. Let's do this now:

```python
def calculate_bonus(employee, yearly_increase=0):
    bonus = 0 

    if employee.bonus:
        bonus += employee.bonus / 12

    if clevel:
        bonus += yearly_increase * employee.years_worked

    return bonus
```

We did two things here. We renamed the variable to `yearly_increase`, which relates to the calculation in any context. And we switched from passing a boolean to passing a number.

Using a boolean was permissible when the layers were intertwined. But once we separated them, we can clearly see that the amount of the bonus was tied to the level. This refactor flows naturally when we start thinking of these concepts in independent layers.

Some of you might have seen this from the beginning. As people progress in their careers, they tend to develop a "smell" for these types of abstractions. Some even say that you can only develop these skills through enough experience. But I believe that thinking in abstraction barriers provides a shortcut to get there.

Even if you already developed this 6th sense for good abstraction, having abstraction barriers in your toolbox can help you spot these refactors in a more disciplined way.

## Taking it further

We covered the basics of abstraction barriers, but there are a few more guiding principles that pair nicely with abstraction barriers to make them even more powerful.

### Seeing your code as a tree

Each layer we create builds on top of the one before it, and some layers consist of multiple concepts at the same relative level of abstraction. This creates a kind of tree between different layers of abstractions. 

To make things easy to follow and understand, just like with trees in our code, we can only have each layer talk to the layers below it.

If we stray from this rule and allow a middle layer to talk to any other layer, we all of a sudden create a mess that requires a completely different way of thinking about the relationship. To make things worse, we might even introduce circular dependencies that prevent a higher level from using a lower level.

So any time that we see a need for a lower level to call up, we should ask ourselves if we are missing a layer further up the stack that can combine the calls from the lower levels.

### Build complete layers

You might have noticed the comments, in the original example, about more calculations before and after our repetitive code. So what should we do with all these other calculations?

We might already have helpers for some of these. In that case, we should review these helper function for any concept sharing, like our `clevel` for the bonus calculation,  and pull them into our calculations domain.

Other parts, however, might be implemented inline with the rest of the level logic. We should carefully review these and make the relevant parts stand alone calculations. Yes, even if we are not re-using them, we should put them in the appropriate abstraction layer.

Let's look at what a final function might look like before we talk about the advantages of having everything related to calculations in its own layer.

```python
def calculate_clevel_compensation(employee):
    salary = 0
    salary += calculate_monthly_salary(employee)
    salary += calculate_bonus(employee, yearly_increase=2000)
    salary += calculate_overtime(employee)
    return salary
```

When building functions this way, we simplify the work of our higher level functions. This function no longer needs to worry about any complex logic. It only needs to know which calculations to call and how to combine them.

Simplifying this function means that we greatly reduce the mistakes we could make. And when we need to make a change, we can easily spot the right place to jump to.

### Prefer small functions

The above solution is much clearer, but it's still not perfect. Any time a function takes an optional argument, it should raise a red flag.

This might be controversial since many standard libraries have functions with tons of optional arguemnts. Python's `print` takes 4 optional arguments just to output some text. But I would argue that it would be better to have multiple functions for the different scenarios instead of having all those options in one overloaded function.

If we look at our example now, `calculate_bonus` is doing too much. It's calculating the standard bonus and a yearly bonus. Additional requirements could quickly morph this functions into a behemoth.

The solution, as you might expect, is to introduce another function. Our final version of `calculate_clevel_compnsation` will look like this:

```python
def calculate_clevel_compensation(employee):
    salary = 0
    salary += calculate_monthly_salary(employee)
    salary += calculate_bonus(employee)
    salary += calculate_yearly_increase_bonus(employee, 2000)
    salary += calculate_overtime(employee)
    return salary
```

This version makes it even easier to see what we are calculating.

A final reason to avoid optional arguments, is that they tend to hide interactions between those different arguments.

Let's say that we get a requirement for a maximum bonus amount. If we use our old version and add another argument to set a maximum bonus, we end up raising all kinds of questions: Do we cap the bonus amount before or after the yearly increase? Should we change the max amount if a yearly increase is present? etc. And we can't answer these questions without looking into `calcualte_bonus`. That puts us back and needing to keep multiple functions in our head.

If we keep our functions small, on the other hand, we can easily see where a `cap_bonus` function gets applied. And we can understand the interaction without the need to dive into another function.

## Repetition has to go somewhere

At this point, you might read all our `calculate_x_compensations` and think that we could dry those up too. After all, some steps repeat in every function. But you must resist this urge.

Repetition is a part of building programs. We can try to split up or even generate it, but it all ends up somewhere. Instead of fighting with it, we should embrace this reality and stop it from spreading all over our code base by isolating it to the top level of our business logic.

This means that if we have a really complex top level function, it might be a 100 line long function that calls out bunch of helpers. And that is actually OK.

If we continue to view our program like a tree, keeping all the calls at the top level helps us keep the tree flat. The flatter we keep our tree, the less ripple effects changing code at lower levels has.

Have you ever upgraded a base library to a new major version? Or worse, upgraded your language? It's a huge pain that haunts you for the rest of your career. Keeping your code flat makes sure that you don't create the same pain in your code base.

Repetition at the top level also has a use. It gives flexibility. By having higher level concepts repeated, we leave the door open to easily modify the steps for each one. This is important as we get closer to the actual business domain.

While some low level concepts are as solid as our universe (I don't expect how we calculate averages to change any time soon). Our business domain changes all the time. If we are not flexible in meetings these business needs, then any change to our program becomes a huge ordeal.

So if we have a lower level that changes often, we need to look at ways to extract the changing parts or move the whole layer higher in our hierarchy. Doing this will ensure that we can continue to respond to changing requirements quickly.

So to thumb this up. We want the lowest levels to have functions that are so fundamental that they rarely change, while keeping their dependencies to an absolute minimum. At the highest level, on the other hand, we want functions that clearly outline how all of our lower levels of abstraction get combined, while having very little custom logic.

## In conclusion

The next time you see a concept repeating, try to go beyond just extracting common functionality. Take the time to put it into the appropriate layer, make it smaller, and make sure that any related concepts get extracted with it. So with every change your code base becomes easier to work with instead of harder.
