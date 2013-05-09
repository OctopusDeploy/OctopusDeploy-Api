## Links

All resources returned by the API contain links to other resources. The idea is that instead of memorizing or hard-coding URL's when using the API, you should start with the root API resource and use links to navigate. 

For example, a `GET` request to `/api` returns a resource that looks like:
  
    {
      "Application": "Octopus",
      "Version": "2.0.9.0",
      "ApiVersion": "3.0.0",
      "Links": {
        "Self": "/api",
        "Environments": "/api/environments",
        "Machines": "/api/machines",
        "Projects": "/api/projects",
        "Feeds": "/api/feeds",
        "Tasks": "/api/tasks"
      }
    }

You can follow the links in the result to navigate around the API; for example, by following the "Projects" link, you'll find a list of the projects on your Octopus server. 

Since the format and structure of links may change, it's important that clients avoid hardcoding URL's to resources, and instead rely on starting at `/api` and navigating from there. 

### Pagination

Collections of resources also include links. For example, following the `Environments` link above will give you a list of environments. 

    {
      "ItemType": "Environment",
      "IsStale": false,
      "TotalResults": 30,
      "Items": [
        // ... a list of environments ...
      ],
      "Links": {
        "Self": "/api/environments",
        "NonStale": "/api/environments?nonStale=True",
        "Page.First": "/api/environments?skip=0",
        "Page.Next": "/api/environments?skip=10",
        "Page.0": "/api/environments?skip=0",
        "Page.1": "/api/environments?skip=10",
        "Page.2": "/api/environments?skip=20",
        "Page.Specific": "/api/environments?skip={skip}",
        "Page.Last": "/api/environments?skip=20"
      }
    }

The links at the bottom of the resource allow you to traverse the pages of results. Again, instead of hard-coding query string parameters, you can look for a `Page.Next` link and follow that instead. 

### Non-stale results

Octopus Deploy uses RavenDB, a document database, as its backing store. One of the many features of RavenDB is that it performs indexing asynchronously in the background in an **eventually consistent** model. This means that when the Octopus Deploy server queries RavenDB, it might be looking at stale results; an item may have been added or deleted, but it may not have appeared in the index yet. 

API requests that return a collection based on a RavenDB query will return a flag indicating whether the results are stale (`IsStale` above), as well as a link to fetch the non-stale results of the same (`NonStale`). 

By default, all requests to the Octopus Deploy API will return stale results, which means we can serve requests quickly.  Requesting the non-stale results will cause the Octopus Server to wait until the RavenDB indexes have been updated before the results are returned. 
