---
title: Go Lamdas
date: {}
draft: true
categories:
  - Go
  - Golang
  - Lambda
  - Serverless
tags:
  - opinion
  - guide
published: false
---

Serverless function are a great replacement for many of the light tasks that
traditionally required a server. They can be used to run purposeful actions,
they reduce cost by letting to pay only for what you use, and they require far
less maintenance than managing your own server or Kubernetes cluster.

However, the single function per lamba approach can become too granular. When
this happens it becomes hard to keep shared logic grouped, other than a naming
convention, and it leads to difficulty to abstract. Do you really need
a library just to some common logic between lambda functions?

I tend to side with [Sandy
Metz](https://www.sandimetz.com/blog/2016/1/20/the-wrong-abstraction) in that
"duplication is far cheaper than the wrong abstraction". But that doesn't mean
you should give up the search for the right abstraction.

## The Right Abstractions

I think having a single action per lambda function is too granular. It also
gets rid of all the tooling built around handling web requests and routing. Instead,
I suggest you create lambdas that are responsible for a resource. Let a single
lambda handle all the actions on a single REST endpoint. Your function should
know how to handle a Create, Read, Update, Delete, along with any specialty
methods you may need for your resource.

The problem you run into right away is that there isn't a great mechanism for
handling multiple action in the context of a single lambda. Luckily, the Apex
project has us covered with a great gateway implementation.

This gateway translates the requests intended for a lambda into requests that
can be handlied by a router. With this approach, you don't have to leave behing
the many great router implementation Go has, such as mux. And you get to handle
multiple routes from a single lambda.

## Creating a Multi-Route Lambda

There isn't much complexity in using the the Apex gateway. You create your
router as normal, and then use the gateway to start your server. Everything
else is already taken care of.

```go
package main

import (
	"log"

	"github.com/apex/gateway"
	"github.com/gorilla/mux"
)

func main() {
	r := mux.NewRouter()

	r.HandleFunc("/sample", handler)

	log.Fatal(gateway.ListenAndServe(":8080", nil))
}
```

With that small wrapper in place, you can write the rest of your handler logic
like you would in any traditional server. This approach combines the ease of
working with lambdas with the robustness of a tranditional micro service.

## The Benefits

You avoid managing your own infrustructre because the lambda is fully managed
by Amazon. They are only run when needed. Since we are using go, they will spin
up quickly and run for a short amount of time.

Having the lambda handle all the actions of a resource even has an advantage.
Users are likely to perform multiple actions on the same resource in a short
timeframe. Since the lambda will be warmed up on the first request, the users
are likely to see better performance on subsequent actions.

The best part is that majority of your app can still follow the same pattern as
a microservice. This means that if you need to move to a traditional server,
because the lambda is constantly running or other reasons, the only thing you
need to change is the `gateway.ListenAndServe` wrapper.

Lambdas give you great power. But you need to use the propperly to take full
advantage of it. An abstraction that adds to your code portability and
usability is the right kind of abstraction to have.
