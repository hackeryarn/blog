---
title: Making Redux Easy
date: 2019-02-11
categories:
  - JavaScript
  - React
  - Redux
tags:
  - opinion
  - experiment
  - guide
published: true
---

(React)[https://reactjs.org/] and (Redux)[https://redux.js.org/] are a top choice for front end projects. (React)[https://reactjs.org/] provides fast
performance, easy ways to create shared components, and a plethora of
libraries. (Redux)[https://redux.js.org/] lets you simplify state management in your
application, but it has serious drawbacks.

In large projects, (Redux)[https://redux.js.org/] bloat your project with repetitive code. To
support a single store update, you need to create a reducer that handles an
action type which is dispatched from an action called inside a component. If
that process sounds tedious and confusing, that's because it is. You end up
with tons of simple actions and reducers that all look alike.

People went to great lengths to combat this problem. Suggestions range from using
a new state management library, such as Mobx, to abandoning
(React)[https://reactjs.org/] completely for
something like Vue. These suggestions are like throwing the baby out
with the bath water. That's why I was happy to find
(Redux-Easy)[https://github.com/mvolkmann/redux-easy] which didn't make me
leave these libraries behind.

# Enter Redux-Easy

(Redux-Easy)[https://github.com/mvolkmann/redux-easy] doesn't try to replace (Redux)[https://redux.js.org/] or (React)[https://reactjs.org/]. Instead, it removes the boilerplate and provides helper functions. You don't need to replace your entire code base. You can incrementally integrate (Redux-Easy)[https://github.com/mvolkmann/redux-easy]

To see how well it delivered on these promises, I decided to try it with the
classic Todo MVC application. The (Redux)[https://redux.js.org/] library even comes with an idiomatic
example, which I used as a starting point.

## Reducing Boilerplate Code

(Redux-Easy)[https://github.com/mvolkmann/redux-easy] simplifies the creation of the store. Instead of manually creating
the store, passing it to the `Provider`, and wrapping your app in the
`Provider`. You use `reduxSetup` to do all those steps for you:

```
import React from 'react';
import {reduxSetup} from 'redux-easy';
import App from './App';
import './reducers'; // described next

const initialState = {
  user: {firstName: ''}
};

// The specified component is rendered in the element with
// id "root" unless the "target" option is specified.
reduxSetup({component: <App />, initialState});
```

You no longer manually group the actions handled by the reducer, nor combine
the reducers into to a single root reducer. Instead, you use `addReducer`. It
manages the root reducer for you, and you can add the handler from anywhere:

```
import {addReducer} from 'redux-easy';

// Call addReducer once for each action type, giving it the
// function to be invoked when that action type is dispatched.
// These functions must return the new state
// and cannot modify the existing state.
addReducer('addToAge', (state, years) => {
  const {user} = state;
  return {
    ...state,
    user: {
      ...user,
      age: user.age + years
    }
  };
});
```

In vanilla (Redux)[https://redux.js.org/], you have to use `mapDispatchToProps` and
`mapStateToProps` to pass in the dispatch actions and state.
(Redux-Easy)[https://github.com/mvolkmann/redux-easy]
provides helpers that interact directly with the store.

Instead of `mapDispatchToProps`, you use the provided `dispatch` function
to fire off action:

```
onFirstNameChange = event => {
  // assumes value comes from an input
  const {value} = event.target;
  dispatch('setFirstName', value);

  // If the setFirstName action just sets a value in the state,
  // perhaps user.firstName, the following can be used instead.
  // There is no need to implement simple reducer functions.
  dispatchSet('user.firstName', value);
};
```

Instead of `mapStateToProps`, you wrap your component in a `watch`
function. This functions lets you map object from the state using the state
path:

```
// The second argument to watch is a map of property names
// to state paths where path parts are separated by periods.
// For example, zip: 'user.address.zipCode'.
// When the value for a prop comes from a top-level state property
// with the same name, the path can be an empty string, null, or
// undefined and `watch` will use the prop name as the path.
export default watch(MyComponent, {
  user: '' // path will be 'user'
});
```

These tools provide a way to reduce the setup of
(Redux)[https://redux.js.org/]. However, (Redux-Easy)[https://github.com/mvolkmann/redux-easy]
doesn't stop there.

## Helpers for Common Actions

(Redux-Easy)[https://github.com/mvolkmann/redux-easy] provided `dispatchSet`, `dispatchTransform`, and `dispatchDelete`.
These are simple and flexible ways to manage simple modifications to your
state. For actions dealing with arrays, there are `dispatchPush`,
`dispatchFilter`, and `dispatchMap`.

These helpers do what you would expect. They cover 80% of the actions
you need to perform on the store.

With actions like `completeTodo`, I reduced the traditional flow,
spread cross 4 files, to a single function defined on the component using it:

```
completeTodo = (id) => {
  dispatchMap('todos', todo =>
    todo.id === id ?
      { ...todo, completed: !todo.completed } :
      todo
  )
}
```

`completeTodo` is an example of modifying an array. It takes the store path
and a function. Then it maps the function over the array pulled from the path.
The dispatch, action, and reducer are all taken care of by
(Redux-Easy)[https://github.com/mvolkmann/redux-easy]

# Conclusion

(Redux-Easy)[https://github.com/mvolkmann/redux-easy] delivered on its promise of making (Redux)[https://redux.js.org/] development shorter and
simpler. Using it, I removed 5 out of 7 action handlers. I reduce the lines of
code by 10% from 503 to 447, and the number of files by 30% from 20 to 14.

Most importantly, organize the code became simpler. The state logic is
closer to where it's being used and is easier to follow.
