---
title: "What async really mean for your python web app?"
date: 2025-11-27
draft: false
---

The Python community is a buzz with excitement about better async support. If you have an existing service, you might wonder if you're missing out. Benchmarks show higher throughput and promise the ability to handle more requests with less hardware. So will this be a free lunch for your existing service?

As often happens, the reality differs from expectations. Unless you run in a highly distributed environment and your service is the bottleneck, needing 10 instances just to keep up with all the traffic, you probably won't see the benefits that most async benchmarks promise. In fact, you might see worse performance with the switch.


## Benchmarking method
The disconnect with 80% of services and async benchmarks comes from the general design of the small to medium sized service. These service will talk directly to a database and as traffic increases, the load on the database grows much faster than the load on the web service. This load distribution shifts the bottleneck from the service to the database. To see the implications of async under these conditions, we need to look at benchmarks that mirror the same configuration.

> If your service runs in a highly distributed environment, and you have sophisticated caching and event sourcing systems setup which makes the service the bottleneck, these benchmarks won't matter as much to you.

The setup for these benchmarks involves Django with a PostgreSQL database. Django is one of the most popular web frameworks in the world, and it gives us the ability to easily switch between sync and async configurations. While PostgreSQL is one of the most popular databases and gives realistic characteristics for the different types of load we want to simulate.

For another point of comparison, the benchmarks also include FastAPI. It's a newer framework built form the ground up for the async era.

To get a full range of service conditions, I will test three scenarios:
- Static content: Runs the service with a database setup but no hits to the database.
- Database read I/O: Queries the database to read data and uses that data to generate a response.
- Database update I/O: Creates high contention in the database by using `SELECT FOR UPDATE` and locking the table for an update, and use the results to generate a response.

To run the benchmarks, I use the same method as [the article](https://blog.baro.dev/p/the-future-of-python-web-services-looks-gil-free) (which pushed me to write this post):
- [Granian](https://github.com/emmett-framework/granian) as the server since it can run using threads or processes.
    - Using the command `granian --interface <asgi or wsgi> --workers <1 or 2> --blocking-threads 32 --port 3000 <application>`.
    - I wanted to include free-threads benchmarks here, but `psycopg` cannot run with free-threads, yet. Once support lands and stabilizes, I will make a follow up article that includes free-thread benchmarks.
- [rewrk](https://github.com/lnx-search/rewrk) to run the load test. 
    - Using the command `rewrk -d 30s -c 64 --host <host with route>`.
- System76 Darter Pro as the laptop for test execution
  - NixOS unstable
  - 12th Gen Intel® Core™ i7-1260P × 16
  - 64 GiB of RAM
  - Python 3.14
  - PostgreSQL 18

I will show the most relevant code snippets throughout the article, but the curious can find all the code [here].

## Results
The results include four different project configurations:
- Sync Django: Default Django setting running with WSGI.
- Sync Django Pooled: The same as Sync Django, but using a pooled database connection.
    - While setting up the load tests, I found out that Django does not pool connections by default, but it does require pooled connections to run in async mode. This configuration closes the configuration gap between the sync and async setups.
- Async Django: Default Django settings for async mode running with ASGI.
- FastAPI: Default setting for both FastAPI and SqlAlchemy.
    - I chose to use the JSON output here, despite the Django benchmarks not using JSON, since it's the most likely use case when running FastAPI in production.

> WSGI and ASGI are the production grade web servers suggested by most python web frameworks including Django. WSGI handles synchronous services while ASGI handles asynchronous services.

### Static content
Getting a baseline of static content gives us an upper bound of what each configuration can do without the database to slow down the server.

The sync and async Django views look almost identical. We only need to add the `async` keyword to make the async version work:

```python
async def index(request):
    return HttpResponse("Hello, world. This is the index.")
```

The FastAPI implementation is just as straight forward:
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

The most obvious thing here is that FastAPI far outperform Django across all metrics. The developers behind FastAPI worked hard to make sure it performs well under these exacts conditions, and it shows. Now that we addressed the elephant in the room, let's focus on the more nuanced Django benchmarks.

The RPS (Requests per second) metric had a couple surprises. Async Django performed an order of magnitude slower than Sync Django. Async isn't free, but this massive difference is surprising. Conversely, the async version starts making up ground with smoother scaling than the Sync Django version. As we add workers, we see a modest increase in throughput for Sync Django, but a doubling throughput for Async Django.

When it comes to latency, we start to see an advantage of async request handling. Async Django has no outliers and a median close to the average. Sync Django, on the other hand, saw massive difference in tail latency. The slowest requests took over 100x longer than the average.

The latency metrics shows and important tradeoff between the two configurations. When we use async, we trade average performance for consistency. In many scenarios we should make this tradeoff, but with a 10x slow down with Async Django, we have to weigh the option carefully. 

### Database reads
Although the previous section gives us some baseline, even the simplest app, unless you're building a static site, will need to connect to a database. So let's connect to a database and perform some reads as part of our load test.

I won't provide all the code here, but I am setting up two table for all the applications. An `Author` table that will contain the names of peoples, and a `Quote` table that will contain quotes by the `Author`s. This is a very simple layout, but it makes sure that we not only test a database hit but also a relationship traversal.

The Sync Django view looks like:
```python
def quote(request):
    quote = Quote.objects.order_by("?").select_related("author").first()

    return HttpResponse(f"{quote.quote_text}\n\n--{quote.author.name}")
```

The Async Django view just needs to sprinkle in a few async specific operator:
```python
async def quote(request):
    quote = await Quote.objects.order_by("?").select_related("author").afirst()

    return HttpResponse(f"{quote.quote_text}\n\n--{quote.author.name}")
```

And the FastAPI view fully relies on SqlAlchemy to perform the search and returns the results as JSON:
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

One thing that I came across while setting this up is that Django does not pool database connections by default. But if we are going to run Django in async mode, it needs to pool the connections. So to make comparison a little more apples to apples, I included benchmarks for Sync Django pooled along side the previous benchmarks.

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

While looking at these benchmarks, we have to keep in mind that to a large degree we are load testing the database. It's the limiting factor here the differences we see in the benchmarks come from the overhead of our application and the different approaches to waiting for data to come back.

Remember how before I said that async was not free. We really get to see that in these results. When we have fast database calls, even FastAPI quickly shows the overhead of managing async. Both Sync Django version easily outperform the async versions. You might argue that this is only due to the queries being so fast to return, but I encourage you to benchmark your app and see how many queries come back sub 100ms. This would be a similar performance characteristic for almost all of the requests depending on those queries.

The other thing to note here is the massive performance improvement that we see with pooled database connections. The two worker Sync Django Pooled more than doubles any other service versions.

The latency for all of these mostly evens out. Since we are just waiting on the DB and Postgres is a battle tested database, we see very even latency across all benchmarks.

### Contentious database writes
Reads are fairly easy to reason about and generally run quickly. They make a realistic and simple performance sample set. One of the worst situation for a web app, on the other hand, is when we see highly contentious writes.

To re-create this situation, we can add a new `views` field to the `Quote` table. This field will store a count of how many times the specific quote was viewed. Since we have multiple workers and threads trying to write to this field at the same time, we need to use a database transaction with a `SELECT FOR UPDATE` to make sure that we always have consistent data in this column.

In a real application, we could avoid this in a many ways and would definitely want to do so, but there are rare instances when it is unavoidable and it gives a great way to test contention for an extremely limited resource. Since only one out of the many requests can update `views` at a time, we are creating an even more severe bottleneck than before.

The Sync Django code is pretty straight forward. We wrap the whole thing in a transaction, use `select_for_update`, and update the `views` field before returning the results to the user:
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

The Async Django code follows the same general pattern, but we had to split out the transaction because Django does not support async transactions at the moment:
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

FastAPI tries to do the same thing, but I failed to get it to run without deadlocks. I tried multiple methods including manual retries after hitting the deadlock, but nothing seemed to avoid it. The core of the issue is that FastAPI just hammers the table way too quickly. I am not going to provide the code here since it did not run, but if you are a FastAPI or SqlAlchemy expert, I would love to fix this scenario and run the benchmarks. [PRs are welcome]().

| Server type   | workers | RPS  | Latency avg | Latency max | Median |
| ------------- | ------- | ---- | ----------- | ----------- | ------ |
| Sync Django   | 1       | 170 | 376ms       | 2144ms      | 542ms  |
| Sync Django   | 2       | 170 | 375ms       | 5168ms      | 620ms  |
| Sync Django Pooled   | 1       | 149  | 429ms       | 576ms       | 460ms  |
| Sync Django Pooled   | 2       | 160  | 401ms       | 951ms       | 584ms  |
| Async Django  | 1       | 156 | 408ms       | 542ms       | 427ms  |
| Async Django  | 2       | 169 | 378ms       | 824ms       | 518ms  |

All of the configuration performed very close to each other. But because the table lock only allows a singe process to write to the table at a time, we see that Sync Django comes out ahead of any of the other configurations. It has the least overhead for this scenario and there fore can process the requests the fastest.

Since we are creating contention, the more processes try to access the resource at once, the worse the overall latency becomes. This is why we are seeing the latency max and median grow as we add workers. Despite this growth, having a pooled or async connection, which can grab the connections concurrently and be ready to go right away, we see much better max patency and median performance over all.

## Conclusion
All in all, you should be judicious with your use of async. It's new in the eco system and many of the libraries and frameworks have been optimized for the sync flow. There are definitely cases where async makes sense, but your web app might now be one of those. By the time that processing takes long enough to make up for the async overhead (1s+ processing time), you probably need to address the performance in a different way than just being able to process more long running end points. Even big application should have few in any endpoint that take over 1s to complete.

If you take one thing away from this article its that: you should always use a pooled database connection. Across all the tests, that one thing made the biggest difference with no negative side effects. Even the tail latency (slow 1% of requests) became much better when we added pooling. The only cost you pay is the memory cost of keeping multiple connections open, but if you look at what you gain, the hardware cost is well worth it. 
