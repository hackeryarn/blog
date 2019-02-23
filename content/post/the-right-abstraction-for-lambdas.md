---
title: The Right Abstraction for Lambdas
date: {}
draft: true
categories:
  - Go
  - Golang
  - JS
  - JavaScript
  - Nodejs
  - Node
  - Express
  - Lambda
  - Serverless
tags:
  - opinion
  - guide
published: false
---

Serverless function are a great alternative for many light tasks that would
traditionally required a server. They allow you to split up the work across
mutiple small function. They reduce the cost by letting you only pay
for what you use. And they require less maintenance than managing your own
server or Kubernetes cluster.

However, the single function per lambda approach can become too granular. Shared
functionality becomes hard to group together. Your are left with a hard to
envforce naming convention for lambdas that really belong together. Then
comes the problem of sharing code between lamdas. Do you need a library just to
share a few common functions?

I side with [Sandy
Metz](https://www.sandimetz.com/blog/2016/1/20/the-wrong-abstraction) in that
"duplication is far cheaper than the wrong abstraction". But that doesn't mean
you should give up the search for the right abstraction.

[The Serverless Framework](https://serverless.com/) addresses some of these issues by letting you share code in the
same project. However, it requires you to completely change how you process
requests. You can't rely on the same set of battle tested libraries that you
use everywhere else. If you later decide to switch to a microservice
architecture, you need to change large portions of your handlers. [The Serverless 
Framework](https://serverless.com/) alone isn't enough.

## The Right Abstractions

I think having a single action per lambda function is too granular. It
gets rid of all the tooling built around handling web requests and routing. Instead,
Let a single lambda handle all the actions on a single resource. The
function should know how to handle a Create, Read, Update, Delete, along with
any specialty methods.

With this in place, you share the most appropriate logic without needless
indirection. It creates a great place to break up your code. The actions that
deal with the same resource are together in one package. Everything else is
either with its resource or abstracted into a general package.

## Other Benefits

Having a single lambda handle all the actions of a resource has a hidden
performance advantage. Users are likely to perform multiple actions on the same
resource in a short time frame. Since the lambda will be warmed up on the first
request, the users are likely to see better performance on subsequent actions.

The best part is that majority of your app can still follow the same pattern as
a microservice. If you need to move to a traditional server,
because the lambda is constantly running or other reasons, the only thing you
need to change is a small wrapper around your router.

Lambdas give you great power. But you need to use them correctly to take
full advantage of it. An abstraction that adds to your code portability and
usability is the right kind of abstraction to have.

## Creating a Multi-Route Lambdas

You will run into a problem when trying to create lambdas that handle multiple
routes. There isn't a built in mechanism for handling multiple actions in the
context of a lambda. Luckily, there are many efforts in the community to make
this process easier.

No matter the language you use, these gateways work in a similar fashion.
They translate the requests intended for a lambda into requests
that can be handled by a router. You get to use the router and handlers
approach you are used to while running your code in a lambda.

The following section shows how to apply this technique across Go and Node.js
servers.

### Go

If you want to use this technique with Go, [Apex gateway](https://github.com/apex/gateway) provides an easy way to
translate lambda bound requests. You create your router as normal, pass the
router to `http.Handle`, and use the gateway to start your server. Everything
else is taken care of by the library.

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

  http.Handle("/", r)
	log.Fatal(gateway.ListenAndServe(":8080", nil))
}
```

### Node.js and Express

For Express, there is the [aws-serverless-express](https://github.com/awslabs/aws-serverless-express) library. It allows you to wrap
your normal express app is a server, and proxy it from a serverless
handler.

```javascript
const express = require('express')
const awsServerlessExpress = require('aws-serverless-express');

const app = express()

app.get('/sample', handler)

const server = awsServerlessExpress.createServer(app);

exports.handler = (event,context) => {
  awsServerlessExpress.proxy(server, event, context)
}
```
