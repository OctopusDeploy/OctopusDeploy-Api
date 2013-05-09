## Errors

The Octopus API could of course return any valid HTTP status code for a response, but there's only a few we actually use. They are:

### HTTP 401: Unauthorized  

Will be returned if no API key or other credentials have been provided. The body will be a JSON document that looks like:

    { 
      "ErrorMessage": "Either your API key is invalid, or your account has been disabled. Please contact your Octopus administrator." 
    }

### HTTP 403: Forbidden

Will be returned if you try to perform an action and don't have permission to. While the 401 indicates that you need to provide credentials, this error means that your credentials are fine, but the Octopus permissions prevent your account from being able to perform that action. 

Many actions in Octopus can only be performed by an Octopus Administrator, such as deleting projects. And other actions can be limited by an administrator; for example, you may be able to view projects, but not create releases for them. The response will be a JSON document that looks like:

    {
      "ErrorMessage": "You do not have permission to perform this action. Please see your Octopus administrator."
    }

### HTTP 404: Not found

You are attempting to fetch or do something with a resource that doesn't exist. 

    {
      "ErrorMessage": "The resource was not found.."
    }

### HTTP 400: Bad request

A validation error. You probably attempted to change a resource, but something was wrong with the data you provided. Details about what was wrong can be found in the response, an example of which is below:

    {
      "ErrorMessage": "There was a problem with your request.",
      "Errors": [ "The name field is required", "The email address field is required" ] 
    }

### HTTP 500: Internal server error

An unexpected exception occurred on the Octopus Server when processing your request. The response will be:

    {
      "ErrorMessage": "There was a problem with your request.",
      "FullException": "System.DivideByZeroException: An attempt was made to divide by zero.\r\n  at Foo.cs:38\r\n  at:...."
    }

In addition, details about error will be logged on the Octopus Server in the Windows event viewer. 
