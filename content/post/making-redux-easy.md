---
title: Making Redux Easy
date: 2019-01-19
draft: true
categories: [JavaScript, React, Redux]
tags: [opinion, experiment, guide]
---

React and Redux have become most popular choice for front end projects. They
bring a lot to the table. React provide fast application, easy ways to create
shared components, and a plethora of libraries. Redux built on the Elm and Flux
architecture to create a clear and simple way to manage state. However, Redux
has its drawbacks.

In large projects, Redux can bloat your code and become very repetative
quickly. To support a single store update, you need to create a reducer that's
triggered by an action called from your component. This doesn't sound too
complex at first glance. But with a well thought out store, you end up with
really simple actions and reducers. They all seem to be simple updates, maps,
or filters.

I've seen some attempts to combat this. Suggesting range from moving to
a new state management library like Mobx, to moving to a whole new framework
like Vue. I think these types of suggestions to solve a problem with verbosity
is like throwing the baby out with the bath water. That's why I was happy to
find redux-easy.

# Enter redux-easy

Redux-easy doesn't try to replace Redux. Instead, it removes some of the boiler
plate and provides helper functions for the many common actions you might want
to do on your store. The beauty of building on top of Redux is that if you
already have an existing app, you can incrementally integrate redux-easy.

To see how well it delivered on these promises, I decided to try it out in an
app. I chose to use redux-easy on the Todo MVC example provided in the official
Redux repo.

## Reducing Boilerplate Code

Right from the start you can notice the goal of reducing boilerplate.
Redux-easy simplifies the creation of the store. Instead of manually creating
the store, passing it to the `Provider`, and wrapping your app in the
`Provider`. You can use `reduxSetup` to do all this for you:

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

The next area where you get to simplify your code is in the reducer creation.
Instead of manually grouping all the actions handled by the reducer, and adding
all the reducer to a single root reducer. You can use `addReducer` which
manages the root reducer for you and adds the declared handlers no matter where you define them:

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

Finally, you get to simplify wiring up state and dispatch setup for your
components. In vanilla Redux, you have to use `mapDispatchToProps` and
`mapStateToProps` to pass in the dispatch actions and state. Redux-easy
provides helpers for you to do this.

Instead of `mapDispatchToProps`, you can use the provided `dispatch` function
to fire off your action:

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

And instead of `mapStateToProps`, you can wrap your component in a `watch`
function. This allows you to fetch object from the state using the state path:

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

## Helpers for Common Actions

Redux-easy also provide many dispatch helpers that allow you to transform the
state without ever writing a reducer. For simple actions dealing with an single
entry, you can use `dispatchSet`, `dispatchTransform`, and `dispatchDelete`.
For actions dealing with arrays, you can use `dispatchPush`, `dispatchFilter`,
and `dispatchMap`. These act as you would expect and cover 80% of the actions
you would want to perform on your store.

In the Todo MVC application, these helpers let me remove 5 out of 7 action
handlers. I was able to keep the code closer to where it was being used,
complete remove action creators, and be more explicit about what that action was doing.

With actions like `completeTodo`, I was able to reduce the traditional flow
spread cross 4 files to a single function defined on the component using it:

```
completeTodo = (id) => {
  dispatchMap('todos', todo =>
    todo.id === id ?
      { ...todo, completed: !todo.completed } :
      todo
  )
}
```

## Conclusion

Redux-easy delivered on it's promise of making redux development easier and
simpler. Using it I was able to reduce the lines of code by 10% from 503 to
447, and reduce the number of files by 30% from 20 to 14. Most importantly, it
made it simpler to reason about the application. I could follow the flow of the
data much easier and reduce the repetition of similar action handlers.
