---
title: Efficient CSV Imports in Rails
draft: false
date: 2017-06-11
categories: [Ruby, Rails]
tags: [guide]
---
Rails has great capabilities for working CSV files. However, like with many
things, the most obvious way is not the most efficient.

We noticed this when our server had major fluctuations in memory consumption.
After digging through metrics, made easy thanks to
[Prometheus](https://prometheus.io) and [Grafana](https://grafana.com). We noticed that the spikes were due to our CSV
uploads. 

# Examining CSV Import

Our processor is responsible for bringing in coordinates
from legacy systems and ones that cannot support our API.

The original code:

    require 'csv'
    
    class CsvProcessor
      def self.import_locations(file)
        CSV.parse(file.read) do |row|
          Location.create(
            name: row['Name'],
            lat: row['Lat'],
            lon: row['Lon']
          )
        end
      end
    end

Looking at this code, I quickly came to the assumption that
`read` was storing the entire file in memory before parsing.
Which sent me on a search for a more efficient parsing method.

# Better Parsing Method

Through my search, I came across an amazingly detailed [article](https://dalibornasevic.com/posts/68-processing-large-csv-files-with-ruby) on how to get the
most memory efficient reads possible. It turns out, we were using the least
efficient method to parse CSV files. I won't put all the statistics here because
the original article does a great deep dive on all the possibilities.
I will only include the most efficient method, and the one we used.

Efficient read code:

    require 'csv'
    
    class CsvProcessor
      def self.import_locations(file)
        CSV.foreach(file) do |row|
          Location.create(
            name: row['Name'],
            lat: row['Lat'],
            lon: row['Lon']
          )
        end
      end
    end

The change was minor. I had to use `CSV.foreach` instead of `CSV.parse` which
performs a line by line streaming traversal of the file. When working with files
it is beneficial to have a stream. Streams only stores as much information as 
needed during each cycle. In this case, it only needs one line.

I also got to eliminate the manual read. This cleaned up my code a bit, and I was
more than happy to let `CSV.foreach` handle the reading for me.

This one change eliminated our memory spikes. Making CSV imports a
minor event for the server.

# Reducing the Number of Creates

However, while looking a the metrics around CSV imports I also noticed that it
took a long time to import a CSV. The most glaring suspect was the `create` on
every row.

Rails libraries come to the rescue! There is a great library,
[activerecord-import](https://github.com/zdennis/activerecord-import), which allows for a singe database transaction for multiple
creates and doesn't complicate the code much.

I eagerly tried to insert all the records in a single transaction. Although this
had some speed improvement, it shot up our memory consumption again. So I started
experimenting with intervals. With some trial and error, I arrived at 200
records per transaction. It didn't consume too much memory and was actually the
fastest. Anything below 200 created too many transactions and the efficiency
dropped. Anything above 200 was creating too large of transactions for them to
be efficiently saved.

My final code:

    require 'csv'
    
    class CsvProcessor
      def self.import_locations(file)
        locations = []
        CSV.foreach(file) do |row|
          locations << Location.new(
            name: row['Name'],
            lat: row['Lat'],
            lon: row['Lon']
          )
    
          if locations.length > 200
            Location.import locations
            locations = []
          end
        end
    
        Location.import locations
      end
    end

This change required a bit more code. I had to maintain a list of locations to
import. Which I checked for the appropriate length, 200, every
iteration.

Once the file read was complete. I performed a final import to save
any remaining locations. If the list was empty, it would
result in no import.

This final change improved our import time over 10x and made this small project
much more worth it!


