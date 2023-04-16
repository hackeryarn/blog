---
title: When DRY goes wrong
date: 2023-02-20
published: false
---

DRY has become a mantra throughout the industry. Any time that some developers see repetitive code, they want to extract it into its own function. It has become almost robotic to extract code and few people give a second thought to whether it makes sense all the time.

Unfortunately, poor application of DRY can lead to brittle code where it's scary to change functionality because it could have a huge ripple effect on the rest of the code base. In this article I hope to show how this happens and cover other ways to look for abstractions. And even make an argument that duplication of good is good in the right setting.

## An example

First off, let's ignore other forms of abstractions like classes, typeclasses, traits, or interfaces. I know how tempting it will be to use a cleaner form of abstraction throughout this article, but doing that would send us down a whole new set of rabbit holes.

We will stick to using plain functions so that things are easy to reason about and apply more broadly. After all, functions are the common denominator among just about every programming language out there. 

Our example will consist of an application to calculate salaries of employees at different levels. We start out with two types of employees. And even with this little code, we already notice repetition creeping up:

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

I think that this is absolutely the right case for extraction, but not because of the repetition. There is a more subtle reason why we should extract this code, that we will get to later.

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

When we extract this code, we create a clean separation of concerns. We have a single place that deals with bonus calculations and helper functions that use the bonus calculation in their calculation for employee's compensation.

## How problems arise

As our code lives for a few weeks or months, and as code does, it grows. We have a few more functions using `calculate_bonus`. Calculations for directors and VPs also started using this same function. This company is all about equality, so everyone so far has the same bonus structure.

But we just got a requirement to handle C-Level employee compensations, and their bonus structure is a little different. For every year that they were with the company, they get an additional $2,000 bonus.

How would you handle this situation?

We have two options. We can add this logic into the new `calculate_clevel_compensation`, or we can expand `calculate_bonus`.

Adding this logic into `calculate_clevel_compensation` doesn't quite feel right. We've isolated our concept of bonus calculation into its own nice little function, so it only make sense to keep all the bonus calculating logic together. Here is how we might expand `calculate_bonus` to handle the new requirement:

```python
def calculate_bonus(employee, clevel=False):
    bonus = 0 

    if employee.bonus:
        bonus += employee.bonus / 12

    if clevel:
        bonus += 2000 * employee.years_worked

    return bonus
```

On the surface this looks like a good solution. By providing a default value for `clevel` we avoid having to update the old function invocations, and our new function just has to provide one flag.

So what would happen if another position gets a different bonus structure? We could just add another flag, add another `if`, and make sure all the right places use the right flags.

And what if there is some shared logic between two of those flags? Or what if multiple flags signal some kind of other special condition? You can see how this innocent function can quickly get out of hand.

This solution has two serious drawbacks.

First off, it introduces a new options named `clevel` which has nothing to do with the concept of a bonus calculation. It's related to the role which should be fully encapsulated by the function that calls `calculate_bonus`.

This bleeding over of concepts makes code significantly harder to follow. Because `clevel` tells us nothing about how it might impact the bonus calculation, we have to read two functions and keep track of the related parts in our minds. And if we have more of these types of "helper" functions, we end up having to keep a lot of information in our head while trying to understand a single function.

The other problem is closely related to the first, but is more insidious. Having the level as part of the bonus calculation tightly couples this function to working with only functions that deal with levels. We simply can't re-use this function in a context that does not know about employee levels.

So if we want to run a simulation that shows the impacts of different bonus structures, we have to introduce levels into this simulations even though we don't care about levels when simulating optimal bonus structures. This really kills DRY's promise of re-usability.

These are some serious issue, but not all is lost. Let's look at a way that we can identify and fix these types of problems.

## Abstraction Barriers

A better approach of extracting pieces of code comes form a concept significantly older than DRY. Abstraction barriers were first formally introduced in [Structure and Interpretation of Computer Programs](https://sarabander.github.io/sicp/html/2_002e1.xhtml#g_t2_002e1_002e2), published in 1984.

I encourage you to read the section linked above, if you're not afraid of too many parentheses. But for the purpose of this article I can sum up this as: build abstractions in well defined layers.

Without reading the linked section of SICP, you might wonder what constitutes a layer. The most basic layer that every program has is the language itself. All the built in functions and operators create an abstraction layer over the machine code that executes the program. We would almost never want to go down below this level, although there are some times when we must.

The next most common layer is made up by the libraries that we import. They usually provide further abstraction over the language allowing us to describe our intent in terms that belong to the domain of the library. The layers in our applications should work in almost the same way.

When we started our program, we were working in a layer that deals with employees and their levels. By extracting our function, we unintentionally introduced a new layer. The unintentional extraction made this layer look like it was for calculating bonuses, but that's too narrow. We created a layer for working with financial calculations. 

If you prefer to think of it in terms of domains: The first layer belongs to the HR domain. It deals with levels, and what those levels entail. The second layer belongs to the accounting domain. It deals with the details that go into calculating certain financial concepts -- bonuses being one of them. If we need clarification on terminology or functionality, this distinction points us towards the right group to talk to.

## Apply Abstraction Barriers

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

We did two things here. We renamed the variable to something that makes more sense in the concept of calculations, and we went from a boolean to passing an integer.

Using a boolean was permissible when the layers were intertwined. But once we separated them, we can see that the amount of the bonus was tied to the level and had nothing to do with the calculation.

With this separation, we can freely use `calculate_bonus` for any position. We can even use it in our simulation without adding more concerns, and gaining more control over the `yearly_increase` value.

Some of you might have seen this from the beginning. As people progress in their careers, they tend to develop a "smell" for these types of abstractions. Some even say that it's just something you have to gain through enough experience and enough reading of code. But I believe that thinking in abstraction barriers provides a shortcut to get there. And even if you already developed this 6th sense, having abstraction barriers in your toolbox can help you spot these types of refactors more often.

## Taking it further

We covered the basics of abstraction barriers, but there are a few more guiding principles that make abstraction barriers even more powerful.

### Layers create trees

As you might expect, the layers we build each build on top of each other. When working in this way, we need to keep in mind that each layer should only talk to the layers below it. Because creating layers builds out a natural tree, we should respect that with our calls.

Keeping calls always flowing down makes the data flow in our application easy to reason about. But if a middle layer starts calling anywhere it wants, all of a sudden we create a tangled ball of yarn. We might even run into a situation where a higher layer needs to use a lower level but it can't because we've created circular dependencies.

So any time that we see a need for a lower level to call up, we should ask our selves if we are missing a layer that needs to be shared.

### Build complete layers

You might have noticed the comments in the original example that stated that each role had more calculations before and after. But our bonus calculation was the first function to get extracted into the calculations layer. So what should we do with all these other calculations?

Well, we might already have helpers for some of these. In that case, we should review these helper function for any concept sharing and pull them into our calculations domain.

Other parts, however, might be entangled with level logic. We should carefully review these and make the relevant parts stand alone calculations. Yes, even if we are not re-using them we should put them in the appropriate abstraction layer.

Let's look at what a final function might look like before we talk about the advantages of having everything related to calculations in its own layer.

```python
def calculate_clevel_compensation(employee):
    salary = 0
    salary += calculate_monthly_salary(employee)
    salary += calculate_bonus(employee, yearly_increase=2000)
    salary += calculate_overtime(employee)
    return salary
```

We no longer need to comb through logic to get a general understanding of what each calculation is doing. We created a clean data pipeline that builds up the salary one calculation at a time. All our level function needs to do is determine what calculations it needs and how to combine them.

Simplifying this function means that we greatly reduce the mistakes we could make. We can also easily read through it and jump to the right area if issues arise.

### Prefer small functions

The above solution is much clearer, but it's still not perfect. Any time a function takes an optional argument, it should raise a red flag.

This might be controversial since many standard libraries have functions with tons of flags. Python's `print` takes 4 optional arguments just to output some text. But I would argue that it would be better to have multiple functions for the different scenarios instead of having all those options.

If we look at our example now, `calculate_bonus` is doing too much. It's calculating the standard bonus and a yearly bonus, only if we pass in the flag. If we get additional requirements, it could quickly start morphing this function into a complex mess that we were trying to avoid.

So the solution is to just introduce another function, making our final version of `calculate_clevel_compnsation` looks like this:

```python
def calculate_clevel_compensation(employee):
    salary = 0
    salary += calculate_monthly_salary(employee)
    salary += calculate_bonus(employee)
    salary += calculate_yearly_increase_bonus(employee, 2000)
    salary += calculate_overtime(employee)
    return salary
```

A final reason to avoid flags, is that they tend to hide interactions that multiple flags might have with each other. Let's say that we get a requirement for a maximum bonus amount. If we encode this into our old `calculate_bonus`, we end up not even seeing that a maximum bonus is a possibility when we look at the level functions. And if we do know about it, we have to look inside that function to answer questions like: Does the `yearly_increase` factor into the maximum bonus?

If we keep nice small functions at the top, on the other hand, we can easily see where a `cap_bonus` function gets applied.

## Repetition has to go somewhere

At this point, you might read all our `calculate_x_compensations` and think that we could dry those up too. After all some steps repeat in every function. But you must resist this urge.

Repetition is a part of building programs. We can try to move it around, but it all ends up somewhere. We should embrace this reality and stop it from spreading all over our code base by isolating it to the top level of our business logic.

This means that if we have a really complex top level function, it might be a 100 line long function that calls out to a bunch of different levels. And that is actually OK.

If we continue to view our program like a tree, keeping all the calls at the top level helps us keep the tree flat. The flatter we keep our tree, the less ripple effects changing code at lower levels has.

Have you ever upgraded a base library to a new version that introduced incompatibilities? Or worse, upgraded your language? It's a huge pain that haunts you for the rest of your career. Keeping your code flat makes sure that you don't create the same type of situation in your code base.

Repetition at the top level also has a use. It gives flexibility. By having higher level concepts repeated, we leave the door open to easily modify the steps for each one. This is important as we get closer to the actual business domain.

While some low level concepts are as solid as our universe (I don't how we calculate averages to change any time soon). Our business domain changes all the time. If we are not flexible in meetings these business needs, then any change to our program becomes a huge ordeal.

So if we have a lower level that changes often, we need to look at ways to extract those parts or move the whole layer higher in our hierarchy. Doing this will ensure that we can continue to response to changing requirements quickly.

So to thumb this up. We want the lowest levels to have functions that are so fundamental that they rarely change. And at our highest level, we want functions built almost completely out of lower level abstractions, so they are easy to change, even if they end up being 100 lines of code.

## In conclusion

The next time you see a concept repeating, try to go beyond just extracting common functionality. Take the time to put it into the appropriate module, make it smaller if you can, and make sure that any other related concepts get extracted with it, and be make life a little easier for your future self.
