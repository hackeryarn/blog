---
title: When DRY goes wrong
date: 2023-06-10
published: true
---

DRY has become a mantra throughout the industry. Any time repetitive code shows up, DRY gets applied as a cure all. If you even start to question DRYing up a piece of code, you are viewed as a heretic to the entire industry.

Ok, maybe it's not that bad, but many times DRY gets applied without much thought. This careless application of DRY leads to brittle code, making even simple changes scary because they could have a huge ripple effect.

In this article I hope to show how this happens and cover different ways to look for abstractions. I will even make an argument that duplication is good in the right setting.

## An example

First off, to keep things simple, we are just going to work with functions. I am not going to cover how these concepts work when using classes, typeclasses, traits, or interfaces. I know how tempting it will be to use a cleaner form of abstraction, but doing that would lead us down a whole new set of rabbit holes.

Our example will consist of an application to calculate salaries of employees at different levels. We start out with two types of employees, and right away we notice repetition creeping up:

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

If we want to run a simulation that shows the impacts of different bonus structures we currently have to introduce levels into it, but levels should not be taken into consideration when simulating bonus structures. This kills DRY's promise of re-usability.

These are some serious issues, but not all is lost. Let's look at a way that we can identify and fix these problems.

## Abstraction Barriers

A better approach to breaking up functions comes form a concept significantly older than DRY. Abstraction barriers were first formally introduced in [Structure and Interpretation of Computer Programs](https://sarabander.github.io/sicp/html/2_002e1.xhtml#g_t2_002e1_002e2), published in 1984.

I encourage you to read the section linked above if you're not afraid of too many parentheses. But for the purpose of this article I can sum up this concept as: build abstractions in well defined layers.

Without reading the linked section, you might wonder what constitutes a layer. The most basic layer that every program has is the language itself. All the built-in functions and operators create an abstraction layer over the machine code that executes the program. We would almost never want to go below the level of our language, so it is the bottom of our layers stack.

The next most common layer is made up of the libraries that we import. They provide further abstraction over the language and allow working in terms of the library's domain.

The layers that we build should work in a similar manner to libraries. Each one providing a clear and encapsulated domain.

When we started our program, we were working in a layer that dealt with employees and their levels. By extracting our function, we unintentionally introduced a new layer. Because we didn’t put much thought into the extraction past DRYing up the code, the layer looked like it only dealt with calculating bonuses but that is too narrow. If we take a closer look, we can see that we started on a layer for financial calculations.

If you prefer to think of it in terms of domains: The first layer belongs to the HR domain. It deals with employees and what their levels entail.

The second layer belongs to the accounting domain: It deals with the details that go into calculating certain financial concepts – bonuses being one of them.

If we need clarification on terminology or functionality, this distinction points us towards the right group to talk to. It also keeps our code closely aligned with how the real world works – something our programs should emulate.

## Applying Abstraction Barriers

After identifying these layers, it becomes easy to see that our terminology doesn't quite match. `calculate_bonus` should use terminology that only relates to the financial domain. Levels don’t belong here.

Let's fix our terminology now:

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

Using a boolean was permissible when the layers were intertwined. Once we separated them, however, we can clearly see that the bonus amount is tied to the level. This refactor flows naturally when we start thinking of these concepts independently.

Some of you might have seen this from the beginning. As people progress in their careers, they tend to develop a "smell" for these types of abstractions. Some even say that you can only develop these skills through enough experience. But I believe that thinking in abstraction barriers provides a shortcut seeing the right abstractions.

Even if you already developed this 6th sense for good abstraction, having abstraction barriers in your toolbox can help you spot these refactors in a more disciplined way.

## Taking it further

We covered the basics of abstraction barriers, but there are a few more guiding principles that pair nicely with abstraction barriers to make them even more powerful.

### Seeing your code as a tree

Each layer we create builds on top of the one before it. And each layer consists of multiple modules at the same relative level of abstraction. This creates a tree like relationship between the modules.

To make things easy to follow and understand, just like with trees in code, layers should only talk to the layers below them. Ideally, each layer should also follow [The Law of Demeter](https://en.m.wikipedia.org/wiki/Law_of_Demeter) and only communicate to the layer immediately below itself. But most of the time simply keeping the communication unidirectional is good enough.

If we stray from this rule and allow a middle layer to talk to any layer, we suddenly find ourselves in a hard to follow mess. To make things worse, we might even introduce circular dependencies that prevent higher layers from even importing some lower layers.

So any time that we see a need for a layer to use one above or adjacent to it, we should ask ourselves if we are missing a layer further up the stack which can compose the necessary functionality.

### Building complete layers

In the original example, we left comments for more calculation that happened before and after the duplicate code. The fact that they are called calculations should flag that they are happening in the wrong layer.

We might already have helpers for some of these. In that case, we should review these helper functions for any bleed over of details. If we find concepts like the `clevel` for the bonus calculation, we should move them to the correct layers.

Other parts, however, might be implemented inline with the rest of the level logic. We should carefully review these and make the relevant parts stand alone calculations. Yes, even if we don't see them being reused, we should still move them to the calculations layer.

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

Simplifying this function means that we greatly reduce the possibility of mistakes , and ease future modifications. Whether we need to add, remove, or re-order the calculations, we can quickly identify where to make the change and confidently apply it without worrying about breaking something else.

### Prefer small functions

The above solution is much clearer, but it's still not perfect. Any time a function takes an optional argument, it should raise a red flag.

This might be controversial since many standard libraries have functions with tons of optional arguments. Python's `print`, as an example, takes 4 optional arguments just to output some text. But I would argue that having multiple functions for each of the scenarios that require flags would make things much clearer.

Let's first look at our example and see if we can spot the issue. `calculate_bonus` is the only function that takes multiple arguments and one of them is optional. It's calculating the standard bonus and a yearly bonus. If you have to use an `and` while describing the purpose a function, it mean that it's doing too much.

The solution, as you might expect, is to introduce another function. With which our final version of `calculate_clevel_compnsation` will look like this:

```python
def calculate_clevel_compensation(employee):
    salary = 0
    salary += calculate_monthly_salary(employee)
    salary += calculate_bonus(employee)
    salary += calculate_yearly_increase_bonus(employee, 2000)
    salary += calculate_overtime(employee)
    return salary
```

This version makes it even easier to see all the steps. We can now clearly see that there is no interaction between the two functions, and we could even add another step in-between them without going into a different function.

Let's bring a little more focus to the point just mentioned because it is the biggest source of issues with optional arguments. If a function takes multiple optional arguments, it hides how their interactions with each other.

If we go back to our original version, with multiple arguments, and add another argument to set a maximum bonus, it addition raises all kinds of questions: Do we cap the bonus amount before or after the yearly increase? Should we change the maximum bonus amount if a yearly increase is present? etc. And we can't answer these questions without looking into `calculate_bonus`. That puts us back at keeping track of multiple functions just to understand how a single function works.

If we keep our functions small, on the other hand, we can easily see where a `cap_bonus` function gets applied. And we can understand the interaction without the need to dive into another function.

## Repetition has to go somewhere

I mentioned before that if you have to use an `and` to describe what a function does, than it is doing too much. If we stuck to this axiom everywhere, our programs wouldn't do a whole lot. We have to combine all our functions somewhere. But because repetition complicates our programs, we should strive to minimize where we use it.

The right place for repetition is at the top most layer of our program. In our case, that's the `calculate_x_compoenstion` functions. If you look back, you might feel a strong urge to DRY these up. After all, their bodies will look mostly the same. But you must resist this urge.

If we continue to view the program as a tree, having a single place of control keeps the tree flat. The flatter we keep the tree, the less likely it is that modifications to lower layer will have a ripple effect throughout the higher levels.

Have you ever upgraded a base library to a new major version? Or worse, upgraded your language? It's a huge pain that haunts you for the rest of your career. Keeping your code flat makes sure that you don't create the same pain in your code base.

Repetition at the top layer also has a use. It provides flexibility. By having the full operation outlined in one place, even if it's very similar to other implementations, leaves it open for modification. This is important as we get closer to the actual business domain.

While some low level concepts are as solid as our universe (I don't expect how we calculate averages to change any time soon). Our business domain changes all the time. If we aren't flexible in adopting to these needs, then any change to our program becomes a huge ordeal.

In order to keep this flexibility, we also need to stay mindful of which parts change the most often. If we start noticing a lower layer changing frequently, we need to look at ways to move the parts that changes closer to the top of the layer stack. Doing this will ensure that we can continue to respond to changing requirements quickly.

So to thumb up the high level direction of the codebase: the lowest layers should have functions so fundamental that they almost never change and require the absolute minimum amount of dependencies. The highest layers, on the other hand, should have functions that clearly and fully outline how lower layers get combined, while having very little custom logic. In-between these two extremes, we should have a spectrum of layers that tries to stay closer to the lowest layers and leave most of the gluing to the top layers.

## In conclusion

The next time you see a concept repeating, try to go beyond just extracting common functionality. Take the time to put it into the appropriate layer, make it smaller, and make sure that any related concepts get extracted with it. That way every change you make will make your code base easier to maintain instead of harder.
