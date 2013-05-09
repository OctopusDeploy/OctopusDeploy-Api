## Links

All resources returned by the API contain links to other resources. The idea is that instead of memorizing or hard-coding URL's when using the API, you should start with the root API resource and use links to navigate. 

For example, a `GET` request to `/api` returns a resource that looks like:
  
    {
      "Application": "Octopus",
      "Version": "2.0.9.0",
      "ApiVersion": "3.0.0",
      "Links": {
        "Self": "/api",
        "Environments": "/api/environments{?nonStale,skip}",
        "Machines": "/api/machines{?nonStale,skip}",
        "Projects": "/api/projects{?nonStale,skip}",
        "Feeds": "/api/feeds{?nonStale,skip}",
        "Tasks": "/api/tasks{?nonStale,skip}",
        "Web": "/"
      }
    }

You can follow the links in the result to navigate around the API; for example, by following the "Projects" link, you'll find a list of the projects on your Octopus server. 

Since the format and structure of links may change, it's important that clients avoid hardcoding URL's to resources, and instead rely on starting at `/api` and navigating from there. 

### URI Templates

Some links (mainly to collections) use URI templates as defined in [RFC 6570](http://tools.ietf.org/html/rfc6570). If in doubt, a client should assume that any link is a URI template.

### Collections

Collections of resources also include links. For example, following the `Environments` link above will give you a list of environments. 

    {
      "ItemType": "Environment",
      "IsStale": false,
      "TotalResults": 40,
      "Items": [
        // ... a list of environments ...
      ],
      "Links": {
        "Self": "/api/environments",
        "Template": "/api/environments{?nonStale,skip}"
        "Page.Next": "/api/environments?skip=10"
      }
    }

The links at the bottom of the resource allow you to traverse the pages of results. Again, instead of hard-coding query string parameters, you can look for a `Page.Next` link and follow that instead. 

### Non-stale results

Octopus Deploy uses RavenDB, a document database, as its backing store. One of the many features of RavenDB is that it performs indexing asynchronously in the background in an **eventually consistent** model. This means that when the Octopus Deploy server queries RavenDB, it might be looking at stale results; an item may have been added or deleted, but it may not have appeared in the index yet. 

API requests that return a collection based on a RavenDB query will return a flag indicating whether the results are stale (`IsStale` above). The link template also specifies that the `nonStale` query string parameter can be passed. 

**By default, all query API requests will be allowed to return stale results.** We do this so that most requests can be served quickly. Requesting non-stale results will cause the Octopus Server to wait until the RavenDB indexes have been updated before the results are returned. If a scenario requires non-stale results, you will need to specify `nonStale` explicitly.  
