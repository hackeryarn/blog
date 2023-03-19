---
title: When DRY goes wrong
date: 2023-02-20
published: false
---

DRY has become a mantra for a certain set of developers. Any time that they see some repeating code, they want to extract it into its own function so that it can be modified together and encapsulate a single purpose. This practice does wonders for libraries and at certain levels of abstraction, but it harms general application code.

## An example

Lets say we have some application code that calculates the salaries of employees. We start out with two types of employees, and as we look over the code we notice some repetition:

```python
def calculate_ic_compensation(employee):
    salary = 0
    # some code before...
    if employee.bonus:
      salary += employee.bonus / 12
    # more code after...

def calculate_manager_compensation(employee):
    salary = 0
    # some code before...
    if employee.bonus:
      salary += employee.bonus / 12
    # more code after...
```

Now, who would want to extract this code into its own function? And what if it was 5-6 more lines to calculate the bonus?

I think this is a good idea to break up into its own function, but not because it keeps the code DRY. We will see later a much better heuristic to use for function extraction.

```python
def calculate_bonus(employee):
    if employee.bonus:
        return employee.bonus / 12
    return 0

def calculate_ic_compensation(employee):
    salary = 0
    # some code before...
    salary += calculate_bonus(employee)
    # more code after...

def calculate_manager_compensation(employee):
    salary = 0
    # some code before...
    salary += calculate_bonus(employee)
    # more code after...
```

So far this makes complete sense. We extracted some common logic, made both the functions shorter, and we even gave it a nice descriptive name.

## How problems arise

So let's say that this code has lived for a few weeks or a few months, and as code does, it grew. We have a few more functions using `calculate_bonus`. We are also using this to calculate compensations for directs, VPs. This company is all about equality, so everyone so far has the same bonus structure.

But we just got a requirement to handle C-Level compensations, and their bonus structure is a little different. For every year that they have been with the company they get an additional $2,000 bonus.

How would you handle this situation?

With the way the code is written right now, we have two options. We can add this logic into the to be written `calculate_clevel_compensation`, or we can expand `calculate_bonus`. Since we want to keep our logic organized, let's expand `calculate_bonus` as follows:

```python
def calculate_bonus(employee, clevel=False):
    bonus = 0 

    if employee.bonus:
        bonus += employee.bonus / 12

    if clevel:
        bonus += 2000 * employee.years_worked

    return bonus
```

On the surface this looks like a good solution. By providing a default value for `clevel` we avoid having to update the our old functions, and our new function just has to provide one flag.

So what would happen if another position gets a different bonus structure? We can just add another flag, right? And what if there is some shared logic between two of those flags? That seems like it could quickly get out of hand. That's because this solution has two serious drawbacks.

First off, it introduces a new options named `clevel` into the bonus calculation. The level doesn't actually have anything to do with the calculation. The yearly increase is a type of calculation that happens when calculating a bonus, but that's a separate concept from the level.

The other problem is closely related to the first, but is more insidious. Having the level as part of the bonus calculation tightly couples it to the level structure. It keeps this function from being reusable in other contexts. Say we wanted to simulate having different bonus structures at different levels to determine the most optimal bonus structure. To actually understand what we are simulating, we would have to read the internals of this functions and figure out what each level represents and try to decipher if we can combine those level flags in any meaningful way. This really kills DRY's promise of re-usability.

Let's look at a way that we can identify and eliminate this problem.

## Abstraction Barriers

The way to do this actually comes form a concept significantly older than DRY. Abstraction barriers were first formally introduced in [Structure and Interpretation of Computer Programs](https://sarabander.github.io/sicp/html/2_002e1.xhtml#g_t2_002e1_002e2), first published in 1984. Unfortunately, you hear about DRY far more often than about abstraction barriers.

I encourage you to read the section linked above, if you're not afraid of too many parentheses, but for the purpose of this article I can sum up the concept as developing in layers. Each layer works at a similar abstraction that deals with related concepts. This is very similar to domain driven design, but not limited to specific business domains.

If we go back to our example, we have one layer that deals with the different layers in the company. It should know what types of calculations belong to each level of employee. We then have a second layer that has to do with the actual calculations that need to happen for different scenarios. If you prefer to think of it in domains. The first layer, having to do with level, is related to HR. The second layer, having to do with calculations, is related to accounting.

Identifying these specific layers means that we understand that they need to use different terminology. And since the programs we write model the real world, we can borrow this terminology from the domain experts. We can get rid of the level in our calculation layer and instead call it something more appropriate:


```python
def calculate_bonus(employee, yearly_increase=0):
    bonus = 0 

    if employee.bonus:
        bonus += employee.bonus / 12

    if clevel:
        bonus += yearly_increase * employee.years_worked

    return bonus
```

We did two things here. We renamed the variable to something that makes more sense in the concept of calculations, and we went from a boolean to passing an integer. This is a change that I didn't mention, but it often happens more naturally when working across abstraction barriers. When we have to make a concept part of domain, we can more quickly notice that the amount that we had hard coded before has nothing to do in the calculation concept. We can clearly see that it belongs outside and we simply need to know how to use it.

There is one more key to abstraction barriers that keeps things decoupled and reusable. Each layer can only talk to the layers below it. This means that we shouldn't have random helper functions that spread the knowledge of a concept across multiple places. Instead, if we see something repeating, we should spend the time identifying what kind of concept it represents, and what domain in might belong to. This leads to a far more reusable and resilient code in the long run.

## In conclusion

The next time you see a concept repeating, try to go beyond just extracting common functionality. Take the time to put it into the appropriate module, rename any options to concepts that belong at the correct abstraction layer, and make your future self grateful to the you of today.
