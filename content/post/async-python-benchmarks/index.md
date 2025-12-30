---
title: "What async really means for your python web app?"
date: 2025-12-30
draft: false
keywords:
    - python
    - async
    - benchmarks
    - web
    - django
tags:
    - python
    - django
    - benchmarks
description: Python continues to get better async support and with that comes pressure to switch. See the realistic effects that switching to async would have on your web servers.
---

The Python community is abuzz with excitement about better async support. If you have an existing service, you might wonder if you're missing out. Benchmarks show higher throughput and promise the ability to handle more requests with less hardware. Will a switch to async be a free lunch for your existing service?

As often happens, the reality differs from expectations. Unless you run in a highly distributed environment and your service is the bottleneck, needing 10 instances just to keep up with all the traffic, you probably won't see the benefits that most benchmarks promise. In fact, you might see worse performance by switching.


## Benchmarking method
The disconnect with 80% of services and async benchmarks comes from the general design of the small to medium sized services. The most common services talk directly to a database and as traffic increases, the load on the database grows much faster than the load on the web service. This load distribution shifts the bottleneck from the service to the database. To see the implications of async under these conditions, we need to examine benchmarks that mirror the same configuration.

The setup for these benchmarks involves Django with a PostgreSQL database. Both are the some of the most popular technologies in the world. Django gives us the ability to easily switch between sync and async configurations. While PostgreSQL gives realistic characteristics for the different types of load we want to simulate.

For another point of comparison, the benchmarks also include FastAPI. It's a newer framework built from the ground up for the async era.

To get a full range of service conditions, I test three scenarios:
- Static content: Runs the service with a database setup but no hits to the database.
- Database read I/O: Queries the database to read data and uses that data to generate a response.
- Database update I/O: Creates high contention in the database by using `SELECT FOR UPDATE` and locking the table for an update, and use the results to generate a response.

To run the benchmarks, I use the same method as [the article](https://blog.baro.dev/p/the-future-of-python-web-services-looks-gil-free) (which pushed me to write this post):
- [Granian](https://github.com/emmett-framework/granian) as the server since it can run using threads or processes.
    - Using the command `granian --interface <asgi or wsgi> --workers <1 or 2> --blocking-threads 32 --port 3000 <application>`.
    - I wanted to include free-threaded benchmarks here, but `psycopg` cannot run with free-threaded, yet. Once support lands and stabilizes, I will make a follow-up article that includes free-threaded benchmarks.
- [rewrk](https://github.com/lnx-search/rewrk) to run the load test. 
    - Using the command `rewrk -d 30s -c 64 --host <host with route>`.
- System76 Darter Pro as the laptop for test execution
  - NixOS unstable
  - 12th Gen Intel® Core™ i7-1260P × 16
  - 64 GiB of RAM
  - Python 3.14
  - PostgreSQL 18

I show the most relevant code snippets in the article, but the curious can find [all the code here].

## Results
The results include four different project configurations:
- Sync Django: Default Django setting running with WSGI.
- Sync Django Pooled: The same as Sync Django, but using a pooled database connection.
    - While setting up the load tests, I found out that Django does not pool connections by default, but it does require pooled connections to run in async mode. This configuration closes the configuration gap between the sync and async setups.
- Async Django: Default Django settings for async mode running with ASGI.
- FastAPI: Default setting for both FastAPI and SQLAlchemy.
    - I chose to use the JSON output here, despite the Django benchmarks not using JSON, since it's the most likely use case when running FastAPI in production.

> WSGI and ASGI are the production-grade web servers suggested by most python web frameworks including Django. WSGI handles synchronous services, while ASGI handles asynchronous services.

### Static content
Getting a baseline of static content gives us an upper bound of what each configuration can do without the database to slowdown the server.

The sync and async Django views look almost identical. We only need to add the `async` keyword to make the async version work:

```python
async def index(request):
    return HttpResponse("Hello, world. This is the index.")
```

The FastAPI implementation is just as straightforward:
```python
@app.get("/")
async def read_root():
    return {"Hello": "World"}
```

| Server type   | workers | RPS  | Latency avg | Latency max | Median |
| ------------- | ------- | ---- | ----------- | ----------- | ------ |
| Sync Django   | 1       | 5032 | 13ms        | 7162ms      | 20ms   |
| Sync Django   | 2       | 6614 | 10ms        | 802ms       | 15ms   |
| Async Django  | 1       | 551  | 116ms       | 193ms       | 129ms  |
| Async Django  | 2       | 1120 | 57ms        | 133ms       | 72ms   |
| FastAPI       | 1       | 26287 | 2.43ms      | 9.38ms      | 2.72ms |
| FastAPI       | 2       | 37353 | 1.71ms      | 7.25ms      | 2.43ms |

> This table does not include Sync Django Pooled because it makes no difference when we don't hit the database.

The most obvious thing here is that FastAPI far outperforms Django across all metrics. The developers behind FastAPI worked hard to make sure it performs well under these exact conditions, and it shows. Now that we addressed the elephant in the room, let's focus on the more nuanced Django benchmarks.

The RPS (Requests per second) metric has a couple surprises. Async Django performs an order of magnitude slower than Sync Django. Async isn't free, but this massive difference is surprising.

The async version starts making up ground with smoother scaling than the Sync Django version. As we add workers, we see a modest increase in throughput for Sync Django, but a doubling throughput for Async Django. This shows how async can queue up work in a more consistent manner and start catching up with many service instances.

When it comes to latency, we start to see an advantage of async request handling. Async Django has no outliers and a median close to the average. Sync Django, conversely, sees massive tail latency slowdown. The slowest requests take over 100x longer than the average.

The latency metrics shows an important tradeoff between the two configurations. When we use async, we trade average performance for consistency. In many scenarios, we should make this tradeoff, but with a 10x slowdown from Sync Django to Async Django, we have to weigh the option carefully.

### Database reads
Now that we have a baseline for each configuration with no bottleneck, let's connect to a database and perform some reads.

For the testing schema we will set up two table: an `Author` table that will contain the names of people, and a `Quote` table that will contain quotes by the authors. This gives us a straightforward layout, but makes the queries more realistic by adding a relationship traversal to every request.

The Sync Django view looks like:
```python
def quote(request):
    quote = Quote.objects.order_by("?").select_related("author").first()

    return HttpResponse(f"{quote.quote_text}\n\n--{quote.author.name}")
```

The Async Django view just needs a sprinkle of a few async operators:
```python
async def quote(request):
    quote = await Quote.objects.order_by("?").select_related("author").afirst()

    return HttpResponse(f"{quote.quote_text}\n\n--{quote.author.name}")
```

The FastAPI view fully relies on SQLAlchemy to perform the search and returns the results as JSON:
```python
@app.get("/quote")
async def quote(db: AsyncSession = Depends(get_db)):
    statement = (
        select(Quote).order_by(func.random()).options(selectinload(Quote.author))
    )
    result = await db.execute(statement)
    quote = result.scalar()

    return {
        "quote": quote.quote_text,
        "author": quote.author.name,
    }
```

After introducing database operations, the metrics include both pooled and non-pooled Sync Django configurations:

| Server type   | workers | RPS  | Latency avg | Latency max | Median |
| ------------- | ------- | ---- | ----------- | ----------- | ------ |
| Sync Django   | 1       | 456 | 140ms       | 262ms       | 153ms  |
| Sync Django   | 2       | 669 | 96ms        | 262ms       | 132ms  |
| Sync Django Pooled   | 1       | 569  | 112ms       | 171ms       | 117ms  |
| Sync Django Pooled   | 2       | 1822 | 35ms        | 98ms        | 50ms   |
| Async Django  | 1       | 205 | 312ms       | 467ms       | 331ms  |
| Async Django  | 2       | 541 | 118ms       | 304ms       | 196ms  |
| FastAPI       | 1       | 236 | 271ms       | 372ms       | 287ms  |
| FastAPI       | 2       | 409 | 156ms       | 433ms       | 224ms  |

While looking at these benchmarks, we have to remember that to a large degree we are load testing the database. The difference in benchmarks comes from the overhead of each framework and the different approaches to waiting for data to come back.

These benchmarks show much more interesting results. The overhead of managing async requests and async database calls really starts to show. Sync performance ends up far outperforming either of the async benchmarks. Even FastAPI starts to lag behind when we introduce a database.

We also see a massive performance improvement by making sure we pool the database connections. The two worker Sync Django Pooled more than doubles the RPS performance of any other configuration.

The latency evens out across the board. Since PostgreSQL becomes the bottleneck, we don't have to worry about the bad latency characteristics that we saw in Sync Django. PostgreSQL, and most popular database engines, are battle tested across many scenarios so we can rely on good performance characteristics.

### Contentious database writes
While database reads run quickly and predictably, they do not show the worst case scenario for databases. A DBA's worst performance nightmare comes in the form of contentious writes. These happen when an application needs to lock rows or an entire table and ends up having transactions that wait for other transactions before they can run.

When improperly managed, this situation can lead to dead locks and whole transactions erroring out. In fact, we will not see benchmarks for FastAPI in this section because, despite my best efforts, I could not get the application to run in async mode without deadlocking. Flipping FastAPI to sync mode seemed to go against the spirit of the rest of the benchmarks, so I wanted to avoid that path. If you can figure out how to get this running, I would love to get a PR and update this article with those benchmarks.

To create contentious writes, we will add a `views` field to the `Quote` table. This field will store a count of how many views the quote gets. Every call to the endpoint will increment the views count before returning a result. To ensure that the field value stays consistent, we need to lock the row with `SELECT FOR UPDATE`. Due to many requests running at the same time, we will end up with requests waiting for other requests to complete before they can update the `views` field.

To implement this, we wrap the whole view in a transaction, use `select_for_update`, and update the `views` field before returning the results to the user:
```python
@transaction.atomic
def quote_views(request):
    quote = (
        Quote.objects.select_for_update().order_by("?").select_related("author").first()
    )
    quote.views += 1
    quote.save()

    return HttpResponse(f"{quote.quote_text}\n\n--{quote.author.name}")
```

The Async Django code follows the same general pattern, but we have to split out the transaction because Django does not support async transactions at the moment:
```python
@sync_to_async
@transaction.atomic()
def get_and_increment_views():
    quote = (
        Quote.objects.select_for_update().order_by("?").select_related("author").first()
    )
    quote.views += 1
    quote.save()

    return quote


async def quote_views(request):
    quote = await get_and_increment_views()

    return HttpResponse(f"{quote.quote_text}\n\n--{quote.author.name}")
```

| Server type   | workers | RPS  | Latency avg | Latency max | Median |
| ------------- | ------- | ---- | ----------- | ----------- | ------ |
| Sync Django   | 1       | 170 | 376ms       | 2144ms      | 542ms  |
| Sync Django   | 2       | 170 | 375ms       | 5168ms      | 620ms  |
| Sync Django Pooled   | 1       | 149  | 429ms       | 576ms       | 460ms  |
| Sync Django Pooled   | 2       | 160  | 401ms       | 951ms       | 584ms  |
| Async Django  | 1       | 156 | 408ms       | 542ms       | 427ms  |
| Async Django  | 2       | 169 | 378ms       | 824ms       | 518ms  |

This benchmark turns out to be the great equalizer. All the benchmarks have almost the same RPS. Even when we add more workers, the contention prevents us from processing more requests.

Also, our latency problem with Sync Django came back. Compared to async, Sync Django has much higher tail latency. The interesting part came from Sync Django Pooled. Introducing database pooling solved the sync latency problem without the need for any code changes. This puts the sync configuration on equal footing with the async configuration without any code changes.

## Conclusion
These benchmarks show just how much optimization for sync web services Django and the Python has. Sync Django Pooled outperforms or matches all other configurations. Even FastAPI only performs better when it's the sole bottleneck.

If your service talks to a database directly, it is unlikely that your service is the bottleneck. To get the best performance you should stick with a sync webserver and ensure that you pool your database connections. As the ecosystem stands, async introduces too much overhead to make sense. This will shift as async support continues to improve, but for now you probably don't need to go changing your web server.
